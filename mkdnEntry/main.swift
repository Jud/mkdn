import AppKit
import mkdnLib
import SwiftUI

// MARK: - SwiftUI App (no @main)

struct MkdnApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appSettings = AppSettings()

    private var savedWindowWidth: CGFloat {
        let stored = UserDefaults.standard.double(forKey: "windowWidth")
        return stored > 0 ? stored : 800
    }

    private var savedWindowHeight: CGFloat {
        let stored = UserDefaults.standard.double(forKey: "windowHeight")
        return stored > 0 ? stored : 600
    }

    var body: some Scene {
        WindowGroup(for: LaunchItem.self) { $launchItem in // swiftlint:disable:this unused_parameter
            DocumentWindow(launchItem: launchItem)
                .environment(appSettings)
        }
        .handlesExternalEvents(matching: [])
        .defaultSize(width: savedWindowWidth, height: savedWindowHeight)
        .windowStyle(.hiddenTitleBar)
        .commands {
            MkdnCommands(appSettings: appSettings)
            OpenRecentCommands()
        }
    }
}

// MARK: - CLI Entry Point

//
// NSApplication interprets positional CLI arguments as kAEOpenDocuments
// AppleEvents, which suppresses default WindowGroup window creation.
// ProcessInfo.processInfo.arguments is cached from C argv before any Swift
// code runs, so CommandLine.arguments stripping is ineffective.
//
// Solution: when a file argument is detected, save the validated path to the
// MKDN_LAUNCH_FILE env var and execv() the binary without the file argument.
// The re-launched process reads the env var and proceeds with a clean argv.

/// Check for --test-harness before CLI parsing to avoid argument parser conflicts.
/// The flag activates the in-process test harness server for automated UI testing.
let rawArguments = CommandLine.arguments

if rawArguments.contains("--test-harness") {
    TestHarnessMode.isEnabled = true
    if let socketIdx = rawArguments.firstIndex(of: "--socket-path"),
       socketIdx + 1 < rawArguments.count
    {
        TestHarnessMode.socketPath = rawArguments[socketIdx + 1]
    }
    if let ppidStr = ProcessInfo.processInfo.environment["MKDN_PARENT_PID"],
       let ppid = Int32(ppidStr)
    {
        TestHarnessMode.parentPID = ppid
        TestHarnessMode.startWatchdog()
    }
    // Positional arguments (after --) cause NSApplication to interpret them as
    // kAEOpenDocuments, suppressing window creation. Use the same execv() strategy
    // as the CLI branch: save paths to env vars and re-exec without them.
    let nonFlagArgs = rawArguments.dropFirst().filter { !$0.hasPrefix("-") }
    if !nonFlagArgs.isEmpty {
        var fileURLs: [URL] = []
        var dirURLs: [URL] = []
        for arg in nonFlagArgs {
            var isDir: ObjCBool = false
            let resolved = URL(fileURLWithPath: arg).standardized.resolvingSymlinksInPath()
            if FileManager.default.fileExists(atPath: resolved.path, isDirectory: &isDir) {
                if isDir.boolValue {
                    dirURLs.append(resolved)
                } else {
                    fileURLs.append(resolved)
                }
            }
        }
        if !fileURLs.isEmpty {
            setenv("MKDN_LAUNCH_FILE", fileURLs.map(\.path).joined(separator: "\n"), 1)
        }
        if !dirURLs.isEmpty {
            setenv("MKDN_LAUNCH_DIR", dirURLs.map(\.path).joined(separator: "\n"), 1)
        }
        // Re-exec with only flags (no positional args that NSApplication would consume)
        var relaunchArgs = [rawArguments[0], "--test-harness"]
        if let socketIdx = rawArguments.firstIndex(of: "--socket-path"),
           socketIdx + 1 < rawArguments.count
        {
            relaunchArgs += ["--socket-path", rawArguments[socketIdx + 1]]
        }
        let cArgs: [UnsafeMutablePointer<CChar>?] = relaunchArgs.map { strdup($0) } + [nil]
        cArgs.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            _ = execv(rawArguments[0], baseAddress)
        }
        perror("execv")
        Foundation.exit(1)
    }
    // Second launch (no positional args): read paths from env vars
    if let envDir = ProcessInfo.processInfo.environment["MKDN_LAUNCH_DIR"] {
        unsetenv("MKDN_LAUNCH_DIR")
        LaunchContext.directoryURLs = envDir.split(separator: "\n").map { path in
            URL(fileURLWithPath: String(path)).standardized.resolvingSymlinksInPath()
        }
    }
    if let envFile = ProcessInfo.processInfo.environment["MKDN_LAUNCH_FILE"] {
        unsetenv("MKDN_LAUNCH_FILE")
        LaunchContext.fileURLs = envFile.split(separator: "\n").map { path in
            URL(fileURLWithPath: String(path)).standardized.resolvingSymlinksInPath()
        }
    }
    MkdnApp.main()
} else if ProcessInfo.processInfo.environment["MKDN_LAUNCH_FILE"] != nil
    || ProcessInfo.processInfo.environment["MKDN_LAUNCH_DIR"] != nil
{
    if let envFile = ProcessInfo.processInfo.environment["MKDN_LAUNCH_FILE"] {
        unsetenv("MKDN_LAUNCH_FILE")
        let urls = envFile.split(separator: "\n").map { path in
            URL(fileURLWithPath: String(path)).standardized.resolvingSymlinksInPath()
        }
        LaunchContext.fileURLs = urls
    }
    if let envDir = ProcessInfo.processInfo.environment["MKDN_LAUNCH_DIR"] {
        unsetenv("MKDN_LAUNCH_DIR")
        let urls = envDir.split(separator: "\n").map { path in
            URL(fileURLWithPath: String(path)).standardized.resolvingSymlinksInPath()
        }
        LaunchContext.directoryURLs = urls
    }
    MkdnApp.main()
} else {
    do {
        let cli = try MkdnCLI.parse()

        if !cli.files.isEmpty {
            var validFileURLs: [URL] = []
            var validDirURLs: [URL] = []
            for argPath in cli.files {
                let resolved = FileValidator.resolvePath(argPath)
                var isDir: ObjCBool = false
                let exists = FileManager.default.fileExists(
                    atPath: resolved.path, isDirectory: &isDir
                )
                if exists, isDir.boolValue {
                    do {
                        let url = try DirectoryValidator.validate(path: argPath)
                        validDirURLs.append(url)
                    } catch let error as CLIError {
                        FileHandle.standardError.write(
                            Data("mkdn: error: \(error.localizedDescription)\n".utf8)
                        )
                    }
                } else if !exists, argPath.hasSuffix("/") {
                    do {
                        let url = try DirectoryValidator.validate(path: argPath)
                        validDirURLs.append(url)
                    } catch let error as CLIError {
                        FileHandle.standardError.write(
                            Data("mkdn: error: \(error.localizedDescription)\n".utf8)
                        )
                    }
                } else {
                    do {
                        let url = try FileValidator.validate(path: argPath)
                        validFileURLs.append(url)
                    } catch let error as CLIError {
                        FileHandle.standardError.write(
                            Data("mkdn: error: \(error.localizedDescription)\n".utf8)
                        )
                    }
                }
            }

            guard !validFileURLs.isEmpty || !validDirURLs.isEmpty else {
                Foundation.exit(1)
            }

            if !validFileURLs.isEmpty {
                let pathString = validFileURLs.map(\.path).joined(separator: "\n")
                setenv("MKDN_LAUNCH_FILE", pathString, 1)
            }
            if !validDirURLs.isEmpty {
                let pathString = validDirURLs.map(\.path).joined(separator: "\n")
                setenv("MKDN_LAUNCH_DIR", pathString, 1)
            }
            let execPath = ProcessInfo.processInfo.arguments[0]
            let cArgs: [UnsafeMutablePointer<CChar>?] = [strdup(execPath), nil]
            cArgs.withUnsafeBufferPointer { buffer in
                guard let baseAddress = buffer.baseAddress else { return }
                _ = execv(execPath, baseAddress)
            }
            perror("execv")
            Foundation.exit(1)
        }

        MkdnApp.main()
    } catch let error as CLIError {
        FileHandle.standardError.write(
            Data("mkdn: error: \(error.localizedDescription)\n".utf8)
        )
        Foundation.exit(error.exitCode)
    } catch {
        MkdnCLI.exit(withError: error)
    }
}
