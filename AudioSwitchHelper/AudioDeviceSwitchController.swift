// Copyright 2018 Vincent Duvert.
// Distributed under the terms of the MIT License.

import Foundation

/// Class handling the switch between audio devices and presenting the UI
final class AudioDeviceSwitchController {
    let systemInterface: AudioDeviceSystemInterface
    let userInterface: SwitchUserInterfaceProtocol
    var currentDeviceUid: String
    
    init(systemInterface: AudioDeviceSystemInterface, userInterface: SwitchUserInterfaceProtocol, currentDeviceUid: String = "") {
        self.systemInterface = systemInterface
        self.userInterface = userInterface
        self.currentDeviceUid = currentDeviceUid
    }
    
    /// Switch to the next enabled and connected device in the list, displaying the switch UI.
    /// - Parameter deviceList: Current device list
    public func switchToNextDevice(in deviceList: [AudioDeviceListManager.DeviceInfo]) {
        let displayedText: String
        
        if let nextDevice = nextDevice(in: deviceList) {
            currentDeviceUid = nextDevice.uid
            displayedText = nextDevice.description
            systemInterface.switchTo(uid: currentDeviceUid)
        } else {
            displayedText = "<No Output>"
        }
        
        self.userInterface.display(text: displayedText)
    }
    
    /// Finds the next enabled and connected device after the current device UID.
    /// - Returns: The next device, or nil if no device is currently enabled and connected
    private func nextDevice(in deviceList: [AudioDeviceListManager.DeviceInfo]) -> AudioDeviceListManager.DeviceInfo? {
        var searchStartIndex: Int
        if let currentIndex = deviceList.firstIndex(where: { $0.uid == currentDeviceUid }) {
            searchStartIndex = deviceList.index(after: currentIndex)
            if searchStartIndex == deviceList.endIndex {
                searchStartIndex = deviceList.startIndex
            }
        } else {
            searchStartIndex = deviceList.startIndex
        }
        
        if let nextDeviceFound = deviceList[searchStartIndex ..< deviceList.endIndex].firstIndex(where: { $0.enabled && $0.connected }) {
            return deviceList[nextDeviceFound]
        }
        
        if searchStartIndex != deviceList.startIndex, let nextDeviceFound = deviceList.firstIndex(where: { $0.enabled && $0.connected}) {
            return deviceList[nextDeviceFound]
        }
        
        return nil
    }
}
