#!/usr/bin/swift

import Foundation

struct Version: Equatable, CustomStringConvertible, Comparable {
	let major: Int
	let minor: Int
	
	private static let matcher = try! NSRegularExpression(pattern: "^(\\d+)\\.(\\d+)$") 
	
	init?(_ value: String) {
		let nsValue = value as NSString
		
		guard let match = Version.matcher.firstMatch(in: value, range: NSRange(location:0, length: nsValue.length)) else {
			return nil
		}		
		
		self.major = Int(nsValue.substring(with: match.range(at: 1)))!
		self.minor = Int(nsValue.substring(with: match.range(at: 2)))!
	}
	
	public static func < (lhs: Version, rhs: Version) -> Bool {
		return lhs.major < rhs.major || (lhs.major == rhs.major && lhs.minor < rhs.minor)	
	}
	
	var description: String {
		return "\(major).\(minor)"
	}
}


class InfoPlist {
	let filePath: URL
	private let propertyList: NSMutableDictionary
	
	init(in directory: String) {
		filePath = URL(fileURLWithPath:directory, isDirectory: true).appendingPathComponent("Info.plist", isDirectory: false)
		
		guard let inputStream = InputStream(url: filePath) else {
			fatalError("Unable to find Info.plist in \(directory) directory")
		}
		inputStream.open()
		defer { inputStream.close() }
		
		var format = PropertyListSerialization.PropertyListFormat.xml
		
		propertyList = try! PropertyListSerialization.propertyList(with: inputStream, options: .mutableContainersAndLeaves, format: &format) as! NSMutableDictionary
	}
	
	var version: Version {
		get {
			return Version(propertyList["CFBundleShortVersionString"]! as! String)!
		}
		
		set {
			propertyList["CFBundleShortVersionString"] = newValue.description
		}
	}
	
	var revision: Int {
		get {
			return Int(propertyList["CFBundleVersion"]! as! String)!
		}
		
		set {
			// This must be a string; if it’s written as an integer in the bundle, some system components will crash
			propertyList["CFBundleVersion"] = String(newValue)
		}
	}
	
	func save() {
		guard let outputStream = OutputStream(url: filePath, append: false) else {
			fatalError("Unable to open \(filePath)")
		}
		outputStream.open()
		defer { outputStream.close() }
		
		let err: ErrorPointer = nil
		if PropertyListSerialization.writePropertyList(propertyList, to: outputStream, format: .xml, options: 0, error: err) == 0 {
			fatalError("Failed to write property list to \(filePath)")
		}
		
	}
}

func runCmd(_ cmdPath: String, _ args: [String]) {
	let cmdUrl = URL(fileURLWithPath: cmdPath)
	let process = try! Process.run(cmdUrl, arguments: args)
	process.waitUntilExit()
	guard process.terminationStatus == 0 else {
		fatalError("\(cmdPath) failed with exit code \(process.terminationStatus)")
	}
}

func runCmd(_ cmdPath: String, _ args: String...) {
	runCmd(cmdPath, args)
}

func runGit(_ args: String...) {
	runCmd("/usr/bin/git", args)
}


let args = CommandLine.arguments
let progName = args[0]

guard args.count == 2, let newVersion = Version(args[1]) else {
	print("Usage: \(progName) <new version>")
	exit(1)
}

let infoPlists = [InfoPlist(in: "AudioSwitchPrefs"), InfoPlist(in: "AudioSwitchHelper")]

guard newVersion > infoPlists[0].version else {
	print("New version \(newVersion) must be greater than previous version \(infoPlists[0].version)")
	exit(1)
}

let newRevision = infoPlists[1].revision + 1

print("New version: \(newVersion), new revision: \(newRevision)")

infoPlists.forEach { info in
	info.version = newVersion
	info.revision = newRevision
	info.save()
}

let cachePath = try! FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
let buildSuffix = ProcessInfo().globallyUniqueString
let buildPathUrl = cachePath.appendingPathComponent("net.duvert.ADBuild.\(buildSuffix)", isDirectory: true)
defer {
	do {
		try FileManager.default.removeItem(at: buildPathUrl)
	} catch {
		print("Warning, removing the build directory failed: \(error)")
	}
}

runCmd("/usr/bin/xcodebuild", "-configuration", "Release", "-scheme", "AudioSwitch Preferences", "CONFIGURATION_BUILD_DIR=\(buildPathUrl.path)")

let outputArchivePath = URL(fileURLWithPath: "AudioSwitch_v\(newVersion).zip").path

do {
	let cwd = FileManager.default.currentDirectoryPath
	defer { FileManager.default.changeCurrentDirectoryPath(cwd) }
	
	FileManager.default.changeCurrentDirectoryPath(buildPathUrl.path)
	runCmd("/usr/bin/zip", "-r", outputArchivePath, "AudioSwitch Preferences.app")
}

infoPlists.forEach { info in
	runGit("add", info.filePath.path)
}

runGit("commit", "-m", "Release v\(newVersion)")
runGit("tag", "-a", "v\(newVersion)", "-m", "Release v\(newVersion)")



