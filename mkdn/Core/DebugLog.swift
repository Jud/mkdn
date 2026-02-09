import Foundation

/// Temporary debug logger that writes to /tmp/mkdn-debug.log.
/// Remove this file after diagnosing the mermaid rendering issue.
func debugLog(_ message: String) {
    let line = "[\(Date())] \(message)\n"
    let path = "/tmp/mkdn-debug.log"
    if let handle = FileHandle(forWritingAtPath: path) {
        handle.seekToEndOfFile()
        handle.write(Data(line.utf8))
        handle.closeFile()
    } else {
        FileManager.default.createFile(atPath: path, contents: Data(line.utf8))
    }
}
