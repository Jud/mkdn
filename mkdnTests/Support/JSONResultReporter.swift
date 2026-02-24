import Foundation

// MARK: - TestStatus

enum TestStatus: String, Codable, Sendable {
    case pass
    case fail
}

// MARK: - TestResult

struct TestResult: Codable, Sendable {
    let name: String
    let status: TestStatus
    let prdReference: String
    let expected: String?
    let actual: String?
    let imagePaths: [String]
    let duration: TimeInterval
    let message: String?
}

// MARK: - TestReport

struct TestReport: Codable, Sendable {
    let timestamp: Date
    let totalTests: Int
    let passed: Int
    let failed: Int
    let results: [TestResult]
    let coverage: PRDCoverageReport
}

// MARK: - JSONResultReporter

/// Collects test results during suite execution and writes a structured
/// JSON report to disk.
///
/// Results accumulate via `record(_:)` and the report file is rewritten
/// after each recording, ensuring the on-disk report is always current
/// even if the test process terminates unexpectedly.
///
/// The report is written to `.build/test-results/mkdn-ui-test-report.json`
/// relative to the project root.
enum JSONResultReporter {
    private nonisolated(unsafe) static var results: [TestResult] = []

    static var defaultReportPath: String {
        reportPath("mkdn-ui-test-report.json")
    }

    static func record(_ result: TestResult) {
        results.append(result)
        try? writeReport(to: defaultReportPath)
    }

    static func writeReport(to path: String) throws {
        let snapshot = results

        let coverage = PRDCoverageTracker.generateReport(
            from: snapshot
        )

        let report = TestReport(
            timestamp: Date(),
            totalTests: snapshot.count,
            passed: snapshot.count(where: { $0.status == .pass }),
            failed: snapshot.count(where: { $0.status == .fail }),
            results: snapshot,
            coverage: coverage
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(report)
        let url = URL(fileURLWithPath: path)

        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url)
    }

    static func reset() {
        results = []
    }

    static var currentResults: [TestResult] {
        results
    }
}

// MARK: - Path Resolution

private func reportPath(_ filename: String) -> String {
    var url = URL(fileURLWithPath: #filePath)

    while url.path != "/" {
        url = url.deletingLastPathComponent()

        let marker = url.appendingPathComponent("Package.swift")

        if FileManager.default.fileExists(atPath: marker.path) {
            return url
                .appendingPathComponent(".build/test-results")
                .appendingPathComponent(filename)
                .path
        }
    }

    return "/tmp/mkdn-test-results/\(filename)"
}
