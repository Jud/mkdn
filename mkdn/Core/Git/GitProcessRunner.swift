#if os(macOS)
    import Foundation

    /// Runs git commands via Foundation `Process` and returns results asynchronously.
    ///
    /// Stateless enum following the ``DirectoryScanner`` pattern — all methods
    /// are static, no instance state.
    public enum GitProcessRunner {
        // MARK: - Errors

        public enum GitProcessError: Error, Sendable {
            case timeout
            case processFailure(Int32, String)
            case notGitRepository
        }

        // MARK: - Git Discovery

        /// Resolved path to the git executable, or nil if git is not installed.
        /// Checks `/usr/bin/git` (macOS CLT shim) and Homebrew paths.
        private static let gitExecutable: URL? = {
            let candidates = [
                "/usr/bin/git",
                "/opt/homebrew/bin/git",
                "/usr/local/bin/git",
            ]
            for path in candidates {
                let url = URL(fileURLWithPath: path)
                guard FileManager.default.isExecutableFile(atPath: path) else { continue }
                // Verify it actually works (macOS shim without CLT pops a dialog)
                let process = Process()
                process.executableURL = url
                process.arguments = ["--version"]
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice
                do {
                    try process.run()
                    process.waitUntilExit()
                    if process.terminationStatus == 0 { return url }
                } catch {
                    continue
                }
            }
            return nil
        }()

        // MARK: - High-Level Commands

        /// Returns the root of the git repository containing `directory`, or `nil`
        /// if the path is not inside a git repo or git is not installed.
        public static func repoRoot(for directory: URL) async -> URL? {
            guard gitExecutable != nil else { return nil }
            guard let output = try? await run(
                arguments: ["rev-parse", "--show-toplevel"],
                in: directory
            )
            else {
                return nil
            }
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return URL(fileURLWithPath: trimmed)
        }

        /// Returns the current branch name, or `nil` on detached HEAD.
        public static func branchName(in directory: URL) async -> String? {
            guard let output = try? await run(
                arguments: ["symbolic-ref", "--short", "HEAD"],
                in: directory
            )
            else {
                return nil
            }
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        /// Returns raw `--porcelain=v1 -z` status data for parsing.
        ///
        /// Uses `--untracked-files=all` so new directories are expanded into
        /// individual file entries, enabling per-file badges and ancestor dots.
        public static func status(in directory: URL) async throws -> Data {
            try await runData(
                arguments: ["status", "--porcelain=v1", "-z", "--untracked-files=all"],
                in: directory
            )
        }

        // MARK: - Process Execution

        /// Run a git command and return stdout as a `String`.
        static func run(
            arguments: [String],
            in directory: URL,
            timeout: Duration = .seconds(10)
        ) async throws -> String {
            let data = try await runData(arguments: arguments, in: directory, timeout: timeout)
            return String(bytes: data, encoding: .utf8) ?? ""
        }

        /// Run a git command and return raw stdout `Data`.
        static func runData(
            arguments: [String],
            in directory: URL,
            timeout: Duration = .seconds(10)
        ) async throws -> Data {
            let context = ProcessContext(directory: directory, arguments: arguments)

            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    executeProcess(context, timeout: timeout, continuation: continuation)
                }
            } onCancel: {
                if context.process.isRunning {
                    context.process.terminate()
                }
            }
        }

        private static func executeProcess(
            _ ctx: ProcessContext,
            timeout: Duration,
            continuation: CheckedContinuation<Data, any Error>
        ) {
            // Read pipes concurrently to prevent deadlock on >64KB output
            let readGroup = DispatchGroup()

            readGroup.enter()
            DispatchQueue.global().async {
                ctx.output.stdout = ctx.stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                readGroup.leave()
            }

            readGroup.enter()
            DispatchQueue.global().async {
                ctx.output.stderr = ctx.stderrPipe.fileHandleForReading.readDataToEndOfFile()
                readGroup.leave()
            }

            nonisolated(unsafe) let timeoutWork = DispatchWorkItem {
                if ctx.process.isRunning {
                    ctx.process.terminate()
                }
            }

            ctx.process.terminationHandler = { process in
                timeoutWork.cancel()
                readGroup.notify(queue: .global()) {
                    if process.terminationStatus == 0 {
                        continuation.resume(returning: ctx.output.stdout)
                    } else {
                        let stderr = String(bytes: ctx.output.stderr, encoding: .utf8) ?? ""
                        continuation.resume(
                            throwing: GitProcessError.processFailure(
                                process.terminationStatus, stderr
                            )
                        )
                    }
                }
            }

            DispatchQueue.global().asyncAfter(
                deadline: .now() + timeoutSeconds(timeout),
                execute: timeoutWork
            )

            do {
                try ctx.process.run()
            } catch {
                timeoutWork.cancel()
                ctx.process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }

        // MARK: - Private

        private static func timeoutSeconds(_ duration: Duration) -> Double {
            let (seconds, attoseconds) = duration.components
            return Double(seconds) + Double(attoseconds) / 1e18
        }

        /// Sendable box for pipe read results, avoiding captured-var concurrency errors.
        private final class PipeOutput: @unchecked Sendable {
            var stdout = Data()
            var stderr = Data()
        }

        /// Bundles process, pipes, and output box for passing into helper methods.
        private final class ProcessContext: @unchecked Sendable {
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            let output = PipeOutput()

            init(directory: URL, arguments: [String]) {
                process.executableURL = gitExecutable
                process.arguments = arguments
                process.currentDirectoryURL = directory
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe
            }
        }
    }
#endif
