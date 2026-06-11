#if os(macOS)
    import ArgumentParser
    import Foundation

    /// Headless comment access for agents and scripts: read a file's comment
    /// threads, append replies, and block until new feedback arrives — all
    /// without launching the app. `mkdnEntry` dispatches `mkdn comments …` here
    /// before any NSApplication exists, so no window is ever created. Output is
    /// JSON on stdout.
    public struct CommentsCommand: ParsableCommand {
        public static let configuration = CommandConfiguration(
            commandName: "comments",
            abstract: "Read and write a Markdown file's comments (headless, JSON output).",
            subcommands: [List.self, Reply.self, Wait.self]
        )

        public init() {}

        // MARK: - JSON projection

        /// The stable shape printed by every subcommand — the sidecar's
        /// re-anchoring internals (start/end/norm) stay private to the app.
        private struct CommentJSON: Codable {
            let id: String
            let author: String?
            let body: String
            let quote: String
            let prefix: String
            let suffix: String
            let replies: [ReplyJSON]
        }

        private struct ReplyJSON: Codable {
            let id: String
            let author: String?
            let body: String
        }

        private static func projected(_ entry: CommentSidecar.Entry) -> CommentJSON {
            CommentJSON(
                id: entry.id,
                author: entry.author,
                body: entry.body,
                quote: entry.quote,
                prefix: entry.prefix,
                suffix: entry.suffix,
                replies: (entry.replies ?? []).map { reply in
                    ReplyJSON(id: reply.id, author: reply.author, body: reply.body)
                }
            )
        }

        private static func printJSON(_ value: some Encodable) throws {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(value)
            guard let json = String(bytes: data, encoding: .utf8) else { return }
            print(json)
        }

        private static func entries(of url: URL) throws -> [CommentSidecar.Entry] {
            let raw = try String(contentsOf: url, encoding: .utf8)
            return CommentSidecar.decode(from: raw)?.entries ?? []
        }

        // MARK: - Subcommands

        struct List: ParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Print the file's comments and their reply threads as JSON."
            )

            @Argument(help: "Markdown file to read.")
            var file: String

            func run() throws {
                let url = try FileValidator.validate(path: file)
                let comments = try CommentsCommand.entries(of: url).map(CommentsCommand.projected)
                try CommentsCommand.printJSON(["comments": comments])
            }
        }

        struct Reply: ParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Append a reply to a comment's thread and save the file."
            )

            @Argument(help: "Markdown file to modify.")
            var file: String

            @Argument(help: "Id of the comment to reply to (from `comments list`).")
            var commentID: String

            @Argument(help: "Reply body.")
            var body: String

            @Option(help: "Name recorded as the reply's author (e.g. claude).")
            var author: String

            func run() throws {
                let url = try FileValidator.validate(path: file)
                let raw = try String(contentsOf: url, encoding: .utf8)
                guard let updated = CommentSidecar.addReply(
                    to: commentID, body: body, author: author, in: raw
                ) else {
                    throw ValidationError("no comment with id '\(commentID)' in \(url.path)")
                }
                try updated.raw.write(to: url, atomically: true, encoding: .utf8)
                try CommentsCommand.printJSON(["replyId": updated.replyID])
            }
        }

        struct Wait: ParsableCommand {
            static let configuration = CommandConfiguration(
                abstract: "Block until a new comment or reply appears in the file, then print it."
            )

            @Argument(help: "Markdown file to watch.")
            var file: String

            @Option(help: "Give up after this many seconds (exit code 1).")
            var timeout: Double?

            /// What `wait` prints on success: only what appeared since it started.
            private struct NewActivity: Codable {
                struct NewReply: Codable {
                    let commentId: String
                    let id: String
                    let author: String?
                    let body: String
                }

                let newComments: [CommentJSON]
                let newReplies: [NewReply]
            }

            func run() throws {
                let url = try FileValidator.validate(path: file)
                let deadline = timeout.map { Date(timeIntervalSinceNow: $0) }
                var known = try Self.ids(in: CommentsCommand.entries(of: url))
                var lastModified = Self.modificationDate(of: url)
                while true {
                    Thread.sleep(forTimeInterval: 0.5)
                    if let deadline, Date() > deadline {
                        FileHandle.standardError.write(
                            Data("mkdn: timed out waiting for a new comment\n".utf8)
                        )
                        throw ExitCode(1)
                    }
                    // Decode only when the file changed; a vanished or briefly
                    // unreadable file (mid-save) is retried on the next tick.
                    let modified = Self.modificationDate(of: url)
                    guard modified != lastModified else { continue }
                    lastModified = modified
                    guard let entries = try? CommentsCommand.entries(of: url) else { continue }

                    let newComments = entries.filter { !known.contains($0.id) }
                    let newReplies = entries.flatMap { entry in
                        (entry.replies ?? [])
                            .filter { !known.contains($0.id) }
                            .map { reply in
                                NewActivity.NewReply(
                                    commentId: entry.id,
                                    id: reply.id,
                                    author: reply.author,
                                    body: reply.body
                                )
                            }
                    }
                    guard !newComments.isEmpty || !newReplies.isEmpty else {
                        known = Self.ids(in: entries)
                        continue
                    }
                    try CommentsCommand.printJSON(NewActivity(
                        newComments: newComments.map(CommentsCommand.projected),
                        newReplies: newReplies
                    ))
                    return
                }
            }

            /// Every id in the sidecar — comments and replies alike — so any
            /// fresh id reads as new activity.
            private static func ids(in entries: [CommentSidecar.Entry]) -> Set<String> {
                Set(entries.map(\.id) + entries.flatMap { ($0.replies ?? []).map(\.id) })
            }

            private static func modificationDate(of url: URL) -> Date? {
                let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
                return attributes?[.modificationDate] as? Date
            }
        }
    }
#endif
