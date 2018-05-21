// Copyright 2018 Vincent Duvert.
// Distributed under the terms of the MIT License.


/// Manages a list of devices with an order, an enable status, and a custom name.
/// The associated state can be saved or loaded as needed.
///
/// Any changes done to the list are lost when loading.
final class AudioDeviceListManager: AudioDeviceObserver {
    /// Persistent info on an audio device
    struct PersistentDeviceInfo {
        /// Unique system identifier for the audio device
        let uid: String
        /// User-attributed device name. May be blank to use the system-attributed name.
        let title: String
        /// Indicates if the user wants to enable (show in the switch interface) the device
        let enabled: Bool
    }
    
    /// Runtime information on a connected device
    struct DeviceInfo: Equatable {
        /// Unique system identifier for the audio device
        let uid: String
        /// Indicates if the device is currently connected
        var connected: Bool
        /// System-attributed device name. May be blank if the device is currently disconnected.
        var name: String
        /// User-attributed device name. May be blank to use the system-attributed name.
        var title: String
        /// Indicates if the user wants to enable (show in the switch interface) the device
        var enabled: Bool
    }
    
    /// Device list
    var devices = [DeviceInfo]()
    
    /// Device list change callback
    var changeCallback: (() -> Void)?
    
    /// Load from persistent state and synchronize it with currently known devices
    /// - Parameters:
    ///   - state: Device state from persistent storage
    func load(state: [PersistentDeviceInfo]) {
        // Keep information about currently connected devices so we can add them to the list
        // if they are not in the loaded state. Their order is kept, so loading an incomplete state and
        // then receiving add notifications for unknown devices is equivalent to first receiving the
        // notifications and then loading the state.
        
        let connectedDevicesMap = devices.lazy.filter { $0.connected }.enumerated().map { (position, device) in
            (device.uid, (name:device.name, position:position))
        }
        
        var unknownConnectedDevices = Dictionary(uniqueKeysWithValues: connectedDevicesMap)
        
        devices = state.map { info in
            let connected: Bool
            let name: String
            if let connectedDevice = unknownConnectedDevices.removeValue(forKey: info.uid) {
                connected = true
                name = connectedDevice.name
            } else {
                connected = false
                name = ""
            }
            
            let device = DeviceInfo(uid: info.uid, connected: connected, name: name, title: info.title, enabled: info.enabled)
            
            return device
        }
        
        let unknownConnectedDevicesSorted = unknownConnectedDevices.lazy.sorted {
            $0.value.position < $1.value.position
        }
            
        let remainingConnectedDevices = unknownConnectedDevicesSorted.map { arg -> DeviceInfo in
            let (uid, (name:name, position:_)) = arg
            return DeviceInfo(uid: uid, connected: true, name: name, title: "", enabled: false)
        }
        
        devices.append(contentsOf: remainingConnectedDevices)
        
        changeCallback?()
    }
    
    /// Adds the device to the list, or update its info if it’s already present
    func deviceAdded(info: AudioDeviceInfo) {
        if let index = devices.index(where: { $0.uid == info.uid }) {
            var device = devices[index]
            
            device.connected = true
            device.name = info.name
            
            devices[index] = device
        } else {
            let device = DeviceInfo(uid: info.uid, connected: true, name: info.name, title: "", enabled: false)
            
            devices.append(device)
        }
        
        changeCallback?()
    }
    
    /// Marks the device as disconnected
    func deviceRemoved(info: AudioDeviceInfo) {
        guard let index = devices.index(where: { $0.uid == info.uid }) else { return }
        devices[index].connected = false
        
        changeCallback?()
    }
}
