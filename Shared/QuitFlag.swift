// Copyright 2018 Vincent Duvert.
// Distributed under the terms of the MIT License.

/// Constants for the quit command feature
enum QuitFlag {
    /// Path to the directory that will contain the flag file
    static let quitFlagDirPath: URL = {
        guard let appGroup = Bundle.main.object(forInfoDictionaryKey: "AppGroup") as? String else {
            fatalError("AppGroup missing in info plist")
        }
        
        guard let location = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            fatalError("No container URL for app group")
        }
        
        return location.appendingPathComponent("Library").appendingPathComponent("Application Support").appendingPathComponent("Quit")
    }()
    
    /// Quit flag file full path
    static let quitFlagFullPath: URL = {
       return quitFlagDirPath.appendingPathComponent("quit")
    }()
}
