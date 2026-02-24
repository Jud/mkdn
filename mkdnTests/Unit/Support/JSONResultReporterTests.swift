import Foundation
import Testing
@testable import mkdnLib

// MARK: - TestResult Codable

@Suite("JSONResultReporter", .serialized)
struct JSONResultReporterTests {
    @Test("TestResult encodes and decodes with all fields")
    func resultRoundTrip() throws {
        let result = TestResult(
            name: "spatial-design-language FR-2: documentMargin left",
            status: .pass,
            prdReference: "spatial-design-language FR-2",
            expected: "32.0pt",
            actual: "31.5pt",
            imagePaths: ["/tmp/capture-001.png"],
            duration: 1.25,
            message: nil
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(result)
        let decoded = try decoder.decode(
            TestResult.self, from: data
        )

        #expect(decoded.name == result.name)
        #expect(decoded.status == .pass)
        #expect(decoded.prdReference == result.prdReference)
        #expect(decoded.expected == "32.0pt")
        #expect(decoded.actual == "31.5pt")
        #expect(decoded.imagePaths == ["/tmp/capture-001.png"])
        #expect(decoded.duration == 1.25)
        #expect(decoded.message == nil)
    }

    @Test("TestResult encodes failure with message")
    func resultFailureRoundTrip() throws {
        let msg = "spatial-design-language FR-3: headingSpaceAbove(H1) expected 48.0pt, measured 24.0pt"

        let result = TestResult(
            name: "spatial-design-language FR-3: headingSpaceAbove(H1)",
            status: .fail,
            prdReference: "spatial-design-language FR-3",
            expected: "48.0pt",
            actual: "24.0pt",
            imagePaths: [],
            duration: 0.5,
            message: msg
        )

        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(
            TestResult.self, from: data
        )

        #expect(decoded.status == .fail)
        #expect(decoded.message != nil)
        #expect(decoded.message?.contains("expected 48.0pt") == true)
    }

    @Test("TestReport encodes with coverage")
    func reportRoundTrip() throws {
        let results = makeTestResults()
        let coverage = PRDCoverageTracker.generateReport(
            from: results
        )

        let report = TestReport(
            timestamp: Date(),
            totalTests: 2,
            passed: 1,
            failed: 1,
            results: results,
            coverage: coverage
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(report)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(
            TestReport.self, from: data
        )

        #expect(decoded.totalTests == 2)
        #expect(decoded.passed == 1)
        #expect(decoded.failed == 1)
        #expect(decoded.results.count == 2)
        #expect(!decoded.coverage.prds.isEmpty)
    }

    @Test("writeReport creates file at specified path")
    func writeReportCreatesFile() throws {
        JSONResultReporter.reset()

        JSONResultReporter.record(makePassResult(
            name: "test_spatialDesignLanguage_FR2_margin",
            prdRef: "spatial-design-language FR-2"
        ))

        let tmpDir = FileManager.default.temporaryDirectory
        let path = tmpDir
            .appendingPathComponent("mkdn-test-\(UUID().uuidString).json")
            .path

        try JSONResultReporter.writeReport(to: path)

        let data = try Data(contentsOf: URL(fileURLWithPath: path))

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let report = try decoder.decode(
            TestReport.self, from: data
        )

        #expect(report.totalTests == 1)
        #expect(report.passed == 1)
        #expect(report.failed == 0)

        try FileManager.default.removeItem(atPath: path)
        JSONResultReporter.reset()
    }

    @Test("record accumulates results")
    func recordAccumulatesResults() {
        JSONResultReporter.reset()

        JSONResultReporter.record(makePassResult(
            name: "test1",
            prdRef: "prd FR-1"
        ))

        JSONResultReporter.record(makeFailResult(
            name: "test2",
            prdRef: "prd FR-2"
        ))

        let results = JSONResultReporter.currentResults

        #expect(results.count == 2)
        #expect(results[0].status == .pass)
        #expect(results[1].status == .fail)

        JSONResultReporter.reset()
    }

    // MARK: - Helpers

    private func makeTestResults() -> [TestResult] {
        [
            makePassResult(
                name: "test1",
                prdRef: "spatial-design-language FR-2"
            ),
            makeFailResult(
                name: "test2",
                prdRef: "spatial-design-language FR-3"
            ),
        ]
    }

    private func makePassResult(
        name: String,
        prdRef: String
    ) -> TestResult {
        TestResult(
            name: name,
            status: .pass,
            prdReference: prdRef,
            expected: "32.0pt",
            actual: "32.0pt",
            imagePaths: [],
            duration: 0,
            message: nil
        )
    }

    private func makeFailResult(
        name: String,
        prdRef: String
    ) -> TestResult {
        TestResult(
            name: name,
            status: .fail,
            prdReference: prdRef,
            expected: "48.0pt",
            actual: "24.0pt",
            imagePaths: [],
            duration: 0,
            message: "mismatch"
        )
    }
}

// MARK: - PRDCoverageTracker

@Suite("PRDCoverageTracker")
struct PRDCoverageTrackerTests {
    @Test("parsePRDReference extracts prd name and FR id")
    func parsePRDReference() {
        let result = PRDCoverageTracker.parsePRDReference(
            "spatial-design-language FR-3"
        )
        #expect(result?.prd == "spatial-design-language")
        #expect(result?.fr == "FR-3")
    }

    @Test("parsePRDReference handles AC-style references")
    func parsePRDReferenceAC() {
        let result = PRDCoverageTracker.parsePRDReference(
            "automated-ui-testing AC-004a"
        )
        #expect(result?.prd == "automated-ui-testing")
        #expect(result?.fr == "AC-004a")
    }

    @Test("parsePRDReference returns nil for invalid format")
    func parsePRDReferenceInvalid() {
        #expect(
            PRDCoverageTracker.parsePRDReference("nospace") == nil
        )
        #expect(
            PRDCoverageTracker.parsePRDReference("") == nil
        )
    }

    @Test("generateReport calculates coverage correctly")
    func generateReport() throws {
        let results = makeSpatialResults()
        let report = PRDCoverageTracker.generateReport(
            from: results
        )

        let prd = try #require(
            report.prds.first { entry in
                entry.prdName == "spatial-design-language"
            }
        )

        #expect(prd.totalFRs == 6)
        #expect(prd.coveredFRs == 2)
        #expect(prd.uncoveredFRs.contains("FR-1"))
        #expect(prd.uncoveredFRs.contains("FR-4"))
        #expect(prd.uncoveredFRs.contains("FR-5"))
        #expect(prd.uncoveredFRs.contains("FR-6"))
        #expect(!prd.uncoveredFRs.contains("FR-2"))
        #expect(!prd.uncoveredFRs.contains("FR-3"))
    }

    @Test("generateReport includes unregistered PRDs")
    func generateReportUnregistered() throws {
        let results = [
            makeResult(prdRef: "custom-prd FR-1"),
        ]

        let report = PRDCoverageTracker.generateReport(
            from: results
        )

        let prd = try #require(
            report.prds.first { entry in
                entry.prdName == "custom-prd"
            }
        )

        #expect(prd.totalFRs == 1)
        #expect(prd.coveredFRs == 1)
        #expect(prd.uncoveredFRs.isEmpty)
        #expect(prd.coveragePercent == 100.0)
    }

    @Test("generateReport with empty results shows zero coverage")
    func generateReportEmpty() throws {
        let report = PRDCoverageTracker.generateReport(from: [])

        let prd = try #require(
            report.prds.first { entry in
                entry.prdName == "spatial-design-language"
            }
        )

        #expect(prd.coveredFRs == 0)
        #expect(prd.coveragePercent == 0.0)
        #expect(prd.uncoveredFRs.count == 6)
    }

    @Test("duplicate FR references count once")
    func duplicateFRCountsOnce() throws {
        let results = [
            makeResult(prdRef: "spatial-design-language FR-2"),
            makeResult(prdRef: "spatial-design-language FR-2"),
            makeResult(prdRef: "spatial-design-language FR-2"),
        ]

        let report = PRDCoverageTracker.generateReport(
            from: results
        )

        let prd = try #require(
            report.prds.first { entry in
                entry.prdName == "spatial-design-language"
            }
        )

        #expect(prd.coveredFRs == 1)
    }

    // MARK: - Helpers

    private func makeSpatialResults() -> [TestResult] {
        [
            makeResult(prdRef: "spatial-design-language FR-2"),
            makeResult(prdRef: "spatial-design-language FR-3"),
            TestResult(
                name: "t3",
                status: .fail,
                prdReference: "spatial-design-language FR-3",
                expected: nil,
                actual: nil,
                imagePaths: [],
                duration: 0,
                message: nil
            ),
        ]
    }

    private func makeResult(prdRef: String) -> TestResult {
        TestResult(
            name: "t",
            status: .pass,
            prdReference: prdRef,
            expected: nil,
            actual: nil,
            imagePaths: [],
            duration: 0,
            message: nil
        )
    }
}
