// Copyright 2018 Vincent Duvert.
// Distributed under the terms of the MIT License.

import Foundation
import os

/// Class handling the switch between audio devices and presenting the UI
final class AudioDeviceSwitchController {
    private let systemInterface: AudioDeviceSystemInterface
    private let userInterface: SwitchUserInterfaceProtocol
    
    init(systemInterface: AudioDeviceSystemInterface, userInterface: SwitchUserInterfaceProtocol) {
        self.systemInterface = systemInterface
        self.userInterface = userInterface
    }
    
    /// Switch to the next (relative to the given UID) enabled and connected device in the list, displaying the switch UI.
    /// - Parameter deviceList: Current device list
    /// - Parameter afterUid: The device after this UID will be selected
    public func switchToNextDevice(in deviceList: [AudioDeviceListManager.DeviceInfo], afterUid uid: String = "") {
        let displayedText: String
        
        if let nextDevice = nextDevice(in: deviceList, afterUid: uid) {
            os_log("Switching to output device: %s", type: .info, nextDevice.description)
            displayedText = nextDevice.description
            systemInterface.switchTo(uid: nextDevice.uid)
        } else {
            os_log("Not switching outputs because none are available", type: .info)
            displayedText = NSLocalizedString("<No Output>", comment: "Output switch pane")
        }
        
        self.userInterface.display(text: displayedText)
    }
    
    /// Finds the next enabled and connected device after the given UID
    /// - Parameter deviceList: Current device list
    /// - Parameter afterUid: The device after this UID will be returned
    /// - Returns: The next device, or nil if no device is currently enabled and connected
    private func nextDevice(in deviceList: [AudioDeviceListManager.DeviceInfo], afterUid currentDeviceUid: String) -> AudioDeviceListManager.DeviceInfo? {
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
