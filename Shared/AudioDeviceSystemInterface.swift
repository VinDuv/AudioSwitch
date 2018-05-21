// Copyright 2018 Vincent Duvert.
// Distributed under the terms of the MIT License.

import Foundation
import CoreAudio
import Dispatch

/// Information about an audio device
struct AudioDeviceInfo {
    /// Unique system identifier for the audio device
    let uid: String
    /// System-attributed device name
    let name: String
}


extension AudioDeviceInfo: CustomStringConvertible, CustomDebugStringConvertible {
    var description: String { return "\(name)" }
    var debugDescription: String { return "\(name) \(uid)" }
}


/// Online sound device observer
protocol AudioDeviceObserver: AnyObject {
    /// Called when a new sound device is added to the system.
    /// When the observer is registered, this method will be called for every device currently online.
    /// - Parameters:
    ///   - info: Information about the added device
    func deviceAdded(info: AudioDeviceInfo)
    
    /// Called when a sound device is removed from the system.
    /// - Parameters:
    ///   - info: Information about the removed device
    func deviceRemoved(info: AudioDeviceInfo)
}


/// Retrieves info about online output sound devices and allows changing the currently selected one.
protocol AudioDeviceSystemInterface: AnyObject {
    /// Initialize the audio device system interface.
    /// - Parameters:
    ///   - observer: The observer to notify when a new device is connected or disconnected.
    ///   - queue: Queue to use for notifications
    init(observer: AudioDeviceObserver, queue: DispatchQueue)
    
    /// Deactivate the audio device system interface.
    /// The observer will not receive any notification after calling this function.
    func deactivate()
    
    /// Change the selected audio output.
    /// - Parameters:
    ///   - uid: The system identifier for the output.
    func switchTo(uid: String)
}


/// Device system interface implementation using CoreAudio
final class AudioDeviceSystemInterfaceCoreAudio: AudioDeviceSystemInterface {
    weak var observer: AudioDeviceObserver?
    let notifyQueue: DispatchQueue
    var devicesPropertyAddress = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMaster)
    var streamConfigurationAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration, mScope: kAudioObjectPropertyScopeOutput, mElement: kAudioObjectPropertyElementMaster)
    var onlineDevices = [AudioDeviceID: AudioDeviceInfo?]() // nil value for non-output devices
    var deviceIds = [String: AudioDeviceID]()
    
    let systemObject = AudioObjectID(kAudioObjectSystemObject)
    
    init(observer: AudioDeviceObserver, queue: DispatchQueue) {
        self.observer = observer
        self.notifyQueue = queue
    
        guard AudioObjectAddPropertyListenerBlock(systemObject, &devicesPropertyAddress, self.notifyQueue, self.handleDevicesChange) == kAudioHardwareNoError else {
            fatalError("AudioObjectAddPropertyListenerBlock failed")
        }
        
        queue.async {
            self.handleDevicesChange()
        }
    }
    
    deinit {
        deactivate()
    }
    
    func deactivate() {
        guard self.observer != nil else { return; }
        
        self.observer = nil
        
        guard AudioObjectRemovePropertyListenerBlock(systemObject, &devicesPropertyAddress, self.notifyQueue, self.handleDevicesChange) == kAudioHardwareNoError else {
            fatalError("AudioObjectRemovePropertyListenerBlock failed")
        }
    }
    
    func switchTo(uid: String) {
        guard let deviceId = deviceIds[uid] else {
            return
        }
        
        let size = UInt32(MemoryLayout<AudioDeviceID>.stride)
        var outputId =  deviceId
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMaster)
        
        guard AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, size, &outputId) == kAudioHardwareNoError else {
            fatalError("AudioObjectSetPropertyData failed (default)")
        }
        
        address.mSelector = kAudioHardwarePropertyDefaultSystemOutputDevice
        guard AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, size, &outputId) == kAudioHardwareNoError else {
            fatalError("AudioObjectSetPropertyData failed (system)")
        }
    }
    
    /// Property listener block for device change notifications.
    private func handleDevicesChange(_: UInt32, _: UnsafePointer<AudioObjectPropertyAddress>) {
        handleDevicesChange()
    }
    
    /// Called on the queue when the device list changes. Determines the added/removed devices and sends the appropriate notifications.
    private func handleDevicesChange() {
        var byteSize: UInt32 = 0
        
        guard AudioObjectGetPropertyDataSize(systemObject, &devicesPropertyAddress, 0, nil, &byteSize) == kAudioHardwareNoError else {
            fatalError("AudioObjectGetPropertyDataSize failed")
        }
        
        let rawBuffer = UnsafeMutableRawPointer.allocate(byteCount: Int(byteSize), alignment: MemoryLayout<AudioDeviceID>.alignment)
        defer { rawBuffer.deallocate() }
        
        guard AudioObjectGetPropertyData(systemObject, &devicesPropertyAddress, 0, nil, &byteSize, rawBuffer) == kAudioHardwareNoError else {
            fatalError("AudioObjectGetPropertyData failed")
        }
        
        let (count, remainder) = Int(byteSize).quotientAndRemainder(dividingBy: MemoryLayout<AudioDeviceID>.stride)
        assert(remainder == 0)
        
        let newDevicesPointer = rawBuffer.bindMemory(to: AudioDeviceID.self, capacity: count)
        var newOnlineDevices = Set(UnsafeMutableBufferPointer(start: newDevicesPointer, count: count))
        
        onlineDevices = onlineDevices.filter({ (deviceId, deviceInfo) -> Bool in
            // Check if the previously known device is in the new devices set. Also remove it from the new devices set if that’s the case
            if newOnlineDevices.remove(deviceId) != nil {
                return true
            }
            
            // If this device had outputs, notify the observer
            if let outputDeviceInfo = deviceInfo {
                deviceIds[outputDeviceInfo.uid] = nil
                observer?.deviceRemoved(info: outputDeviceInfo)
            }
            
            return false
        })
        
        // newOnlineDevices now only contains devices which were not in onlineDevices. Add them.
        for newDeviceId in newOnlineDevices {
            let deviceInfo = getInfo(deviceId: newDeviceId)
            onlineDevices[newDeviceId] = deviceInfo
            
            if let outputDeviceInfo = deviceInfo {
                deviceIds[outputDeviceInfo.uid] = newDeviceId
                observer?.deviceAdded(info: outputDeviceInfo)
            }
        }        
    }
    
    /// Get information on the specified CoreAudio device ID.
    /// - Parameters:
    ///   - deviceId: The device ID
    /// - Returns: The device info, or nil if it’s not an output device
    private func getInfo(deviceId: AudioDeviceID) -> AudioDeviceInfo? {
        guard getOutputCount(deviceId: deviceId) > 0 else {
            return nil
        }
        
        let uid = getProperty(deviceId: deviceId, selector: kAudioDevicePropertyDeviceUID)
        let name = getProperty(deviceId: deviceId, selector: kAudioDevicePropertyDeviceNameCFString)
        
        return AudioDeviceInfo(uid: uid, name: name)
    }
    
    /// Get the specified property from a CoreAudio device ID.
    /// - Parameters:
    ///   - deviceId: The device ID
    ///   - selector: The property selector
    /// - Returns: The string value of the property
    private func getProperty(deviceId: AudioDeviceID, selector: AudioObjectPropertySelector) -> String {
        var outRef : Unmanaged<CFString>? = nil
        var outSize = UInt32(MemoryLayout.size(ofValue: outRef))
        
        var propertyAddress = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeOutput, mElement: kAudioObjectPropertyElementMaster)
        
        guard AudioObjectGetPropertyData(deviceId, &propertyAddress, 0, nil, &outSize, &outRef) == kAudioHardwareNoError else {
            fatalError("AudioObjectGetPropertyData failed")
        }
        
        return outRef!.takeRetainedValue() as String
    }
    
    /// Get the number of audio outputs from a CoreAudio device ID.
    /// - Parameters:
    ///   - deviceId: The device ID
    /// - Returns: The audio output count
    private func getOutputCount(deviceId: AudioDeviceID) -> UInt32 {
        var byteSize: UInt32 = 0
        
        guard AudioObjectGetPropertyDataSize(deviceId, &streamConfigurationAddress, 0, nil, &byteSize) == kAudioHardwareNoError else {
            fatalError("AudioObjectGetPropertyDataSize failed")
        }
        
        let rawPointer = UnsafeMutableRawPointer.allocate(byteCount: Int(byteSize), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { rawPointer.deallocate() }
        
        guard AudioObjectGetPropertyData(deviceId, &streamConfigurationAddress, 0, nil, &byteSize, rawPointer) == kAudioHardwareNoError else {
            fatalError("AudioObjectGetPropertyData failed")
        }
        
        let bufferListPointer = rawPointer.bindMemory(to: AudioBufferList.self, capacity: 1)
        
        var count: UInt32 = 0
        for index in 0 ..< Int(bufferListPointer.pointee.mNumberBuffers) {
            withUnsafePointer(to: &bufferListPointer.pointee.mBuffers) { mBuffers in
                count += mBuffers[index].mNumberChannels
            }
        }
        
        return count
    }
}

