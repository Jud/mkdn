import AppKit
import mkdnLib
import SwiftUI

// MARK: - SwiftUI App (no @main)

struct MkdnApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appSettings = AppSettings()

    var body: some Scene {
        WindowGroup(for: URL.self) { $fileURL in // swiftlint:disable:this unused_parameter
            DocumentWindow(fileURL: fileURL)
                .environment(appSettings)
        }
        .handlesExternalEvents(matching: [])
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
// See: .rp1/work/issues/file-arg-no-window/investigation_report.md

// Check for --test-harness before CLI parsing to avoid argument parser conflicts.
// The flag activates the in-process test harness server for automated UI testing.
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
    MkdnApp.main()
} else if let envFile = ProcessInfo.processInfo.environment["MKDN_LAUNCH_FILE"] {
    unsetenv("MKDN_LAUNCH_FILE")
    let urls = envFile.split(separator: "\n").map { path in
        URL(fileURLWithPath: String(path)).standardized.resolvingSymlinksInPath()
    }
    LaunchContext.fileURLs = urls
    MkdnApp.main()
} else {
    do {
        let cli = try MkdnCLI.parse()

        if !cli.files.isEmpty {
            var validURLs: [URL] = []
            for filePath in cli.files {
                do {
                    let url = try FileValidator.validate(path: filePath)
                    validURLs.append(url)
                } catch let error as CLIError {
                    FileHandle.standardError.write(
                        Data("mkdn: error: \(error.localizedDescription)\n".utf8)
                    )
                }
            }

            guard !validURLs.isEmpty else {
                Foundation.exit(1)
            }

            let pathString = validURLs.map(\.path).joined(separator: "\n")
            setenv("MKDN_LAUNCH_FILE", pathString, 1)
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
