import Foundation

// MARK: - PRDCoverageReport

/// Aggregated PRD coverage across all test suites.
struct PRDCoverageReport: Codable, Sendable {
    let prds: [PRDCoverage]
}

// MARK: - PRDCoverage

/// Coverage statistics for a single PRD.
struct PRDCoverage: Codable, Sendable {
    let prdName: String
    let totalFRs: Int
    let coveredFRs: Int
    let uncoveredFRs: [String]
    let coveragePercent: Double
}

// MARK: - PRDCoverageTracker

/// Maps test results to PRD functional requirements and generates
/// coverage reports.
///
/// Each test result's `prdReference` field is parsed to extract the
/// PRD name and FR identifier. The tracker compares covered FRs
/// against a registry of known PRD functional requirements to
/// calculate coverage percentages.
///
/// PRD reference format: `"{prd-name} {FR-id}"`
/// Examples:
///   - `"spatial-design-language FR-3"`
///   - `"automated-ui-testing AC-004a"`
enum PRDCoverageTracker {
    // MARK: - Registry

    /// Known PRDs and their complete set of functional requirements.
    ///
    /// This registry defines the "total" against which coverage is
    /// measured. PRDs not listed here will still appear in the report
    /// if tests reference them, but with totalFRs derived from the
    /// tests themselves.
    static let registry: [String: [String]] = [
        "spatial-design-language": [
            "FR-1", "FR-2", "FR-3", "FR-4", "FR-5", "FR-6",
        ],
        "automated-ui-testing": [
            "AC-004a", "AC-004b", "AC-004c", "AC-004d",
            "AC-004e", "AC-004f",
            "AC-005a", "AC-005b", "AC-005c", "AC-005d",
            "AC-005e", "AC-005f",
        ],
        "animation-design-language": [
            "FR-1", "FR-2", "FR-3", "FR-4", "FR-5",
        ],
    ]

    // MARK: - Report Generation

    /// Generates a PRD coverage report from accumulated test results.
    ///
    /// - Parameter results: All test results recorded during the run.
    /// - Returns: A coverage report listing each known PRD with its
    ///   coverage statistics.
    static func generateReport(
        from results: [TestResult]
    ) -> PRDCoverageReport {
        let coveredByPRD = extractCoverage(from: results)

        var prds: [PRDCoverage] = registry.map { prdName, allFRs in
            let covered = coveredByPRD[prdName] ?? Set()
            let uncovered = allFRs.filter { !covered.contains($0) }
            let registryCovered = allFRs.filter { covered.contains($0) }

            let percent = allFRs.isEmpty
                ? 0.0
                : (Double(registryCovered.count) / Double(allFRs.count))
                * 100.0

            return PRDCoverage(
                prdName: prdName,
                totalFRs: allFRs.count,
                coveredFRs: registryCovered.count,
                uncoveredFRs: uncovered.sorted(),
                coveragePercent: (percent * 10).rounded() / 10
            )
        }

        for (prdName, coveredFRs) in coveredByPRD
            where registry[prdName] == nil
        {
            let frList = coveredFRs.sorted()
            prds.append(PRDCoverage(
                prdName: prdName,
                totalFRs: frList.count,
                coveredFRs: frList.count,
                uncoveredFRs: [],
                coveragePercent: 100.0
            ))
        }

        prds.sort { $0.prdName < $1.prdName }
        return PRDCoverageReport(prds: prds)
    }

    // MARK: - Reference Parsing

    /// Parses a PRD reference string into its components.
    ///
    /// Expected format: `"{prd-name} {FR-id}"` where prd-name is
    /// kebab-case and FR-id is the functional requirement identifier.
    ///
    /// - Parameter reference: The raw PRD reference string.
    /// - Returns: A tuple of (prd name, FR identifier), or nil if
    ///   the format does not match.
    static func parsePRDReference(
        _ reference: String
    ) -> (prd: String, fr: String)? {
        let parts = reference.split(
            separator: " ",
            maxSplits: 1
        )
        guard parts.count == 2 else { return nil }
        return (prd: String(parts[0]), fr: String(parts[1]))
    }

    // MARK: - Private

    private static func extractCoverage(
        from results: [TestResult]
    ) -> [String: Set<String>] {
        var coverage: [String: Set<String>] = [:]

        for result in results {
            guard let parsed = parsePRDReference(
                result.prdReference
            )
            else { continue }

            coverage[parsed.prd, default: []].insert(parsed.fr)
        }

        return coverage
    }
}
