import Foundation
import Testing

@testable import mkdnLib

@Suite("DefaultHandlerService")
struct DefaultHandlerServiceTests {
    @Test("isDefault returns Bool without crashing")
    @MainActor func isDefaultReturnsBool() {
        let result = DefaultHandlerService.isDefault()
        #expect(result == true || result == false)
    }

    @Test("registerAsDefault returns Bool without crashing")
    @MainActor func registerAsDefaultReturnsBool() {
        let result = DefaultHandlerService.registerAsDefault()
        #expect(result == true || result == false)
    }
}
