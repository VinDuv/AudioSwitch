// Copyright 2018 Vincent Duvert.
// Distributed under the terms of the MIT License.

import Foundation

class DebugObserver: AudioDeviceObserver {
    var nextIndex = 1
    var indexToUid = [Int:String]()
    var uidToIndex = [String:Int]()
    
    func deviceAdded(info: AudioDeviceInfo) {
        indexToUid[nextIndex] = info.uid
        uidToIndex[info.uid] = nextIndex
        
        print("Device added: [\(nextIndex)] \(info.debugDescription)")
        
        nextIndex += 1
    }
    
    func deviceRemoved(info: AudioDeviceInfo) {
        print("Device removed: \(info.debugDescription)")
        
        guard let index = uidToIndex.removeValue(forKey: info.uid) else {
            fatalError("UID should be registered!")
        }
        
        indexToUid[index] = nil
    }
    
    func uidMatching(input: String) -> String? {
        if let index = Int(input), let uid = indexToUid[index] {
            return uid
        }
        
        return nil
    }
}

let observer = DebugObserver()
let manager = AudioDeviceSystemInterfaceCoreAudio(observer: observer, queue: DispatchQueue.main)
let runLoop = CFRunLoopGetCurrent()!

let stdinSource = DispatchSource.makeReadSource(fileDescriptor: 0)
stdinSource.setEventHandler {
    guard let line = readLine(strippingNewline: true) else {
        stdinSource.cancel()
        return
    }
    
    if line.isEmpty {
        CFRunLoopStop(runLoop)
    } else if let uid = observer.uidMatching(input: line) {
        manager.switchTo(uid: uid)
    } else {
        print("Invalid input")
    }
}

let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT)
sigintSource.setEventHandler {
    CFRunLoopStop(runLoop)
}

signal(SIGINT, {_ in })

print("""
    Watching device events… Press Enter or ^C to quit.
    To switch to a device, type the number preceding its name, then Enter.
    """)
stdinSource.activate()
sigintSource.activate()

CFRunLoopRun()

print("Done")

manager.deactivate()
stdinSource.cancel()
sigintSource.cancel()
