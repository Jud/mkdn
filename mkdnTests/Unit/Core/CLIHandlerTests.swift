import Foundation
import Testing

@testable import mkdnLib

@Suite("CLIHandler")
struct CLIHandlerTests {

    @Test("Returns nil when no arguments")
    func returnsNilForNoArgs() {
        // CLIHandler.fileURLFromArguments() reads CommandLine.arguments,
        // which we cannot override in tests. This test documents the
        // expected behavior: the test runner executable is the first arg,
        // so with no additional .md arguments, it returns nil.
        let result = CLIHandler.fileURLFromArguments()
        #expect(result == nil)
    }
}
