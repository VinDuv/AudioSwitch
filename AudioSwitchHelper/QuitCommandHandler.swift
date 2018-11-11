// Copyright 2018 Vincent Duvert.
// Distributed under the terms of the MIT License.

import Foundation
import Darwin
import os

/// Handles quit requests from the main application.
final class QuitCommandHandler {
    private let fsChangeSource: DispatchSourceFileSystemObject
    
    init() {
        try! FileManager.default.createDirectory(at: QuitFlag.quitFlagDirPath, withIntermediateDirectories: true, attributes: [:])
        let fd = QuitFlag.quitFlagDirPath.withUnsafeFileSystemRepresentation { path in
            Darwin.open(path!, O_DIRECTORY | O_EVTONLY)
        }
        
        if (fd == -1) {
            fatalError("Unable to open the quit command directory: errno \(errno)")
        }
        
        fsChangeSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write], queue: .main)
        fsChangeSource.setCancelHandler {
            close(fd)
        }
        fsChangeSource.setEventHandler { [unowned self] in
            if self.checkAndDeleteQuitFlag() {
                DispatchQueue.main.async {
                    NSApp.terminate(nil)
                }
            }
        }
        
        // Remove a stale flag if it exists
        _ = checkAndDeleteQuitFlag()
        
        fsChangeSource.activate()
    }
    
    /// Check if the quit flag file exists, and deletes it if that’s the case.
    /// - Returns: true if the flag file existed, false if it wasn’t
    func checkAndDeleteQuitFlag() -> Bool {
        do {
            try FileManager.default.removeItem(at: QuitFlag.quitFlagFullPath)
        } catch {
            return false
        }
        
        return true
    }
}
