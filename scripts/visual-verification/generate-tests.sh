#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# generate-tests.sh -- Read evaluation report, generate Swift Testing test
# files for each medium/high confidence issue, validate compilation and
# failure, and stage validated tests into VisionCompliance/.
#
# Usage:
#   scripts/visual-verification/generate-tests.sh [evaluation-report-path]
#
# If no path is provided, uses the most recent evaluation report in
# .rp1/work/verification/reports/.
#
# Output:
#   Validated test files in mkdnTests/UITest/VisionCompliance/
#   Audit trail entries appended to .rp1/work/verification/audit.jsonl
#   Generation summary printed to stdout
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
VERIFICATION_DIR="${PROJECT_ROOT}/.rp1/work/verification"
STAGING_DIR="${VERIFICATION_DIR}/staging"
REPORTS_DIR="${VERIFICATION_DIR}/reports"
PROMPTS_DIR="${SCRIPT_DIR}/prompts"
AUDIT_FILE="${VERIFICATION_DIR}/audit.jsonl"
VISION_COMPLIANCE_DIR="${PROJECT_ROOT}/mkdnTests/UITest/VisionCompliance"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

info() {
    echo "==> $1"
}

error() {
    echo "ERROR: $1" >&2
    exit 1
}

append_audit() {
    local entry="$1"
    echo "${entry}" >> "${AUDIT_FILE}"
}

# Convert a PRD reference like "spatial-design-language FR-3" to camelCase
# "spatialDesignLanguage"
prd_to_camel_case() {
    local prd_name="$1"
    # Take only the PRD name part (before the FR reference)
    local name_part="${prd_name%% FR*}"
    local name_part="${name_part%% fr*}"
    # Convert kebab-case to camelCase (perl for macOS compatibility)
    echo "${name_part}" | perl -pe 's/-([a-z])/uc($1)/ge'
}

# Extract the FR number from a PRD reference like "spatial-design-language FR-3"
extract_fr() {
    local prd_ref="$1"
    echo "${prd_ref}" | grep -oE 'FR-?[0-9]+' | sed 's/-//' || echo "FRx"
}

# Determine test template type from issue data
determine_test_type() {
    local suggested_type="$1"
    local prd_ref="$2"
    if [ -n "${suggested_type}" ] && [ "${suggested_type}" != "null" ]; then
        echo "${suggested_type}"
        return
    fi
    # Infer from PRD reference
    case "${prd_ref}" in
        *spatial*|*geometry*)      echo "spatial" ;;
        *theming*|*terminal*|*syntax*|*highlighting*) echo "visual" ;;
        *mermaid*)                 echo "visual" ;;
        *charter*|*qualitative*)   echo "qualitative" ;;
        *)                         echo "spatial" ;;
    esac
}

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------

EVAL_REPORT=""

for arg in "$@"; do
    case "${arg}" in
        --help|-h)
            echo "Usage: generate-tests.sh [evaluation-report-path]"
            echo ""
            echo "Reads an evaluation report and generates Swift test files"
            echo "for medium/high confidence issues."
            echo ""
            echo "If no path is provided, uses the most recent evaluation"
            echo "report in .rp1/work/verification/reports/."
            exit 0
            ;;
        *)
            if [ -z "${EVAL_REPORT}" ]; then
                EVAL_REPORT="${arg}"
            else
                error "Unexpected argument: ${arg}"
            fi
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Resolve evaluation report
# ---------------------------------------------------------------------------

if [ -z "${EVAL_REPORT}" ]; then
    info "No evaluation report specified; finding most recent"
    EVAL_REPORT=$(ls -t "${REPORTS_DIR}"/*-evaluation.json 2>/dev/null | head -1) || true
    if [ -z "${EVAL_REPORT}" ] || [ ! -f "${EVAL_REPORT}" ]; then
        error "No evaluation report found in ${REPORTS_DIR}. Run evaluate.sh first."
    fi
fi

if [ ! -f "${EVAL_REPORT}" ]; then
    error "Evaluation report not found: ${EVAL_REPORT}"
fi

info "Reading evaluation report: ${EVAL_REPORT}"

command -v jq > /dev/null 2>&1 || error "jq is required but not found"
command -v claude > /dev/null 2>&1 || \
    error "claude CLI not found. Install Claude Code to generate tests."

EVAL_ID=$(jq -r '.evaluationId' "${EVAL_REPORT}")
info "  Evaluation ID: ${EVAL_ID}"

# ---------------------------------------------------------------------------
# Phase 1: Filter issues by confidence (medium or high)
# ---------------------------------------------------------------------------

info "Filtering issues by confidence"

# Concrete issues with medium/high confidence
ISSUES_JSON=$(jq -c '[.issues[] | select(.confidence == "medium" or .confidence == "high")]' \
    "${EVAL_REPORT}" 2>/dev/null || echo "[]")
ISSUE_COUNT=$(echo "${ISSUES_JSON}" | jq 'length')

# Qualitative findings are subjective quality impressions (both positive and
# negative) that don't translate well into automated failing tests. Concrete
# issues already capture specific, measurable PRD deviations. Qualitative
# findings are preserved in the evaluation report for human review only.
QUALITATIVE_JSON="[]"
QUALITATIVE_COUNT=0
QUALITATIVE_TOTAL=$(jq '[.qualitativeFindings[] | select(.confidence == "medium" or .confidence == "high")] | length' \
    "${EVAL_REPORT}" 2>/dev/null || echo "0")

# Count low-confidence items for reporting
LOW_ISSUES=$(jq '[.issues[] | select(.confidence == "low")] | length' \
    "${EVAL_REPORT}" 2>/dev/null || echo "0")
LOW_TOTAL="${LOW_ISSUES}"

TOTAL_ACTIONABLE="${ISSUE_COUNT}"

info "  ${ISSUE_COUNT} concrete issues (medium/high confidence)"
info "  ${QUALITATIVE_TOTAL} qualitative findings skipped (human review only)"
info "  ${LOW_TOTAL} low-confidence issues skipped (flagged for human review)"

if [ "${TOTAL_ACTIONABLE}" -eq 0 ]; then
    info "No medium/high confidence issues to generate tests for"
    echo "GENERATED_TESTS=0"
    echo "SKIPPED_LOW_CONFIDENCE=${LOW_TOTAL}"
    exit 0
fi

# ---------------------------------------------------------------------------
# Phase 2: Prepare staging directory
# ---------------------------------------------------------------------------

info "Preparing staging directory"
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"
mkdir -p "${VISION_COMPLIANCE_DIR}"

# ---------------------------------------------------------------------------
# Phase 3: Generate test files for concrete issues
# ---------------------------------------------------------------------------

GENERATED_COUNT=0
DISCARDED_COMPILE=0
DISCARDED_PASSES=0
GENERATED_PATHS=()

generate_test_for_issue() {
    local idx="$1"
    local source_type="$2"  # "issue" or "qualitative"

    local issue_id prd_ref spec_excerpt observation deviation
    local suggested_type aspect fixture theme

    if [ "${source_type}" = "issue" ]; then
        issue_id=$(echo "${ISSUES_JSON}" | jq -r ".[$idx].issueId")
        prd_ref=$(echo "${ISSUES_JSON}" | jq -r ".[$idx].prdReference")
        spec_excerpt=$(echo "${ISSUES_JSON}" | jq -r ".[$idx].specificationExcerpt")
        observation=$(echo "${ISSUES_JSON}" | jq -r ".[$idx].observation")
        deviation=$(echo "${ISSUES_JSON}" | jq -r ".[$idx].deviation")
        suggested_type=$(echo "${ISSUES_JSON}" | jq -r ".[$idx].suggestedAssertion.type // empty")
        aspect=$(echo "${ISSUES_JSON}" | jq -r ".[$idx].suggestedAssertion.metric // empty")
        local capture_id
        capture_id=$(echo "${ISSUES_JSON}" | jq -r ".[$idx].captureId")

        # Derive fixture and theme from captureId (e.g., canonical-solarizedDark-previewOnly)
        fixture=$(echo "${capture_id}" | sed -E 's/-[a-zA-Z]+-[a-zA-Z]+$//' | sed 's/$/.md/')
        theme=$(echo "${capture_id}" | sed -E 's/^[a-z0-9-]+-([a-zA-Z]+)-[a-zA-Z]+$/\1/')
    else
        issue_id=$(echo "${QUALITATIVE_JSON}" | jq -r ".[$idx].findingId")
        prd_ref=$(echo "${QUALITATIVE_JSON}" | jq -r ".[$idx].reference")
        spec_excerpt=""
        observation=$(echo "${QUALITATIVE_JSON}" | jq -r ".[$idx].observation")
        deviation=$(echo "${QUALITATIVE_JSON}" | jq -r ".[$idx].assessment")
        suggested_type="qualitative"
        aspect=""
        local capture_id
        capture_id=$(echo "${QUALITATIVE_JSON}" | jq -r ".[$idx].captureId")

        fixture=$(echo "${capture_id}" | sed -E 's/-[a-zA-Z]+-[a-zA-Z]+$//' | sed 's/$/.md/')
        theme=$(echo "${capture_id}" | sed -E 's/^[a-z0-9-]+-([a-zA-Z]+)-[a-zA-Z]+$/\1/')
    fi

    # Determine test type and template
    local test_type
    test_type=$(determine_test_type "${suggested_type}" "${prd_ref}")
    local template_file="${PROMPTS_DIR}/test-template-${test_type}.md"
    if [ ! -f "${template_file}" ]; then
        template_file="${PROMPTS_DIR}/test-template-spatial.md"
        test_type="spatial"
    fi

    # Generate aspect name if not provided
    if [ -z "${aspect}" ] || [ "${aspect}" = "null" ]; then
        # Create a camelCase aspect from the deviation description
        aspect=$(echo "${issue_id}" | tr '[:upper:]' '[:lower:]' | sed 's/-/_/g')
        aspect="${aspect}_detected"
    fi

    # Build file name
    local prd_camel
    prd_camel=$(prd_to_camel_case "${prd_ref}")
    local fr_id
    fr_id=$(extract_fr "${prd_ref}")

    local test_file_name
    if [ "${source_type}" = "qualitative" ]; then
        test_file_name="VisionDetected_qualitative_${aspect}.swift"
    else
        test_file_name="VisionDetected_${prd_camel}_${fr_id}_${aspect}.swift"
    fi

    local staging_path="${STAGING_DIR}/${test_file_name}"
    local target_path="${VISION_COMPLIANCE_DIR}/${test_file_name}"
    local generation_date
    generation_date=$(date -u +"%Y-%m-%d")

    info "  Generating test: ${test_file_name} (${test_type})"

    # Read template content
    local template_content
    template_content=$(cat "${template_file}")

    # Write task file for Claude Code to generate the test
    local task_file="${STAGING_DIR}/${test_file_name}.task.md"
    cat > "${task_file}" <<TASK_EOF
You are generating a Swift Testing test file that encodes a vision-detected design issue.

## Issue Details

- **Issue ID**: ${issue_id}
- **Evaluation ID**: ${EVAL_ID}
- **PRD Reference**: ${prd_ref}
- **Specification**: ${spec_excerpt}
- **Observation**: ${observation}
- **Deviation**: ${deviation}
- **Fixture**: ${fixture}
- **Theme**: ${theme}
- **Test Type**: ${test_type}
- **Aspect**: ${aspect}
- **PRD CamelCase**: ${prd_camel}
- **FR ID**: ${fr_id}
- **Date**: ${generation_date}

## Template

The test template below shows the pattern to follow. You must fill in the
measurement/assertion logic based on the issue details. The test must:

1. Currently FAIL (it encodes a deviation that exists in the current rendering)
2. Compile successfully with \`swift build\`
3. Follow the template pattern exactly for structure (imports, @Suite, @Test, doc comment)
4. Use existing test infrastructure (VisionComplianceHarness, visionFixturePath, etc.)
5. Include concrete measurement and assertion logic (not commented-out placeholders)

${template_content}

## Output

Write the complete Swift test file to:
${staging_path}

Write ONLY the Swift source code to that file. No markdown fences, no commentary.
The file must be a valid, compilable Swift source file.
TASK_EOF

    # Invoke Claude Code to generate the test
    if ! claude -p "$(cat "${task_file}")" --allowedTools "Read,Write" > /dev/null 2>&1; then
        info "    Claude Code generation failed for ${issue_id}"
        append_audit "$(jq -cn \
            --arg type "testGeneration" \
            --arg ts "${TIMESTAMP}" \
            --arg iid "${issue_id}" \
            --arg tf "${test_file_name}" \
            --argjson compiled false \
            --argjson currentlyFails false \
            '{type: $type, timestamp: $ts, issueId: $iid, testFile: $tf, compiled: $compiled, currentlyFails: $currentlyFails, reason: "claude generation failed"}')"
        return 1
    fi

    # Verify the file was produced
    if [ ! -f "${staging_path}" ]; then
        info "    No test file produced for ${issue_id}"
        append_audit "$(jq -cn \
            --arg type "testGeneration" \
            --arg ts "${TIMESTAMP}" \
            --arg iid "${issue_id}" \
            --arg tf "${test_file_name}" \
            --argjson compiled false \
            --argjson currentlyFails false \
            '{type: $type, timestamp: $ts, issueId: $iid, testFile: $tf, compiled: $compiled, currentlyFails: $currentlyFails, reason: "no output file produced"}')"
        return 1
    fi

    # Validate: file must be non-empty
    if [ ! -s "${staging_path}" ]; then
        info "    Empty test file produced for ${issue_id} -- discarding"
        rm -f "${staging_path}"
        append_audit "$(jq -cn \
            --arg type "testGeneration" \
            --arg ts "${TIMESTAMP}" \
            --arg iid "${issue_id}" \
            --arg tf "${test_file_name}" \
            --argjson compiled false \
            --argjson currentlyFails false \
            '{type: $type, timestamp: $ts, issueId: $iid, testFile: $tf, compiled: $compiled, currentlyFails: $currentlyFails, reason: "empty output file"}')"
        return 1
    fi

    # Copy to VisionCompliance/ for compilation check
    cp "${staging_path}" "${target_path}"

    # Validate compilation
    info "    Validating compilation"
    if ! swift build 2>&1 | tail -5; then
        info "    Compilation FAILED for ${test_file_name} -- discarding"
        rm -f "${target_path}"
        DISCARDED_COMPILE=$((DISCARDED_COMPILE + 1))
        append_audit "$(jq -cn \
            --arg type "testGeneration" \
            --arg ts "${TIMESTAMP}" \
            --arg iid "${issue_id}" \
            --arg tf "${test_file_name}" \
            --argjson compiled false \
            --argjson currentlyFails false \
            '{type: $type, timestamp: $ts, issueId: $iid, testFile: $tf, compiled: $compiled, currentlyFails: $currentlyFails, reason: "compilation failed"}')"
        return 1
    fi

    # Extract test filter name from the file
    # Look for @Suite("...") pattern to get the suite name
    local suite_name
    suite_name=$(grep -oE '@Suite\("VisionDetected_[^"]*"' "${target_path}" | \
        sed 's/@Suite("//;s/"//' | head -1) || true

    if [ -z "${suite_name}" ]; then
        suite_name="VisionDetected"
    fi

    # Validate the test currently fails
    info "    Validating test failure (swift test --filter ${suite_name})"
    if swift test --filter "${suite_name}" 2>&1 | tail -5; then
        info "    Test PASSES (false positive) for ${test_file_name} -- discarding"
        rm -f "${target_path}"
        DISCARDED_PASSES=$((DISCARDED_PASSES + 1))
        append_audit "$(jq -cn \
            --arg type "testGeneration" \
            --arg ts "${TIMESTAMP}" \
            --arg iid "${issue_id}" \
            --arg tf "${test_file_name}" \
            --argjson compiled true \
            --argjson currentlyFails false \
            '{type: $type, timestamp: $ts, issueId: $iid, testFile: $tf, compiled: $compiled, currentlyFails: $currentlyFails, reason: "test passes (false positive)"}')"
        return 1
    fi

    # Test fails as expected -- this is what we want
    info "    Test correctly FAILS -- validated"
    GENERATED_COUNT=$((GENERATED_COUNT + 1))
    GENERATED_PATHS+=("${target_path}")

    append_audit "$(jq -cn \
        --arg type "testGeneration" \
        --arg ts "${TIMESTAMP}" \
        --arg iid "${issue_id}" \
        --arg tf "${test_file_name}" \
        --argjson compiled true \
        --argjson currentlyFails true \
        '{type: $type, timestamp: $ts, issueId: $iid, testFile: $tf, compiled: $compiled, currentlyFails: $currentlyFails}')"

    return 0
}

# ---------------------------------------------------------------------------
# Phase 3a: Process concrete issues
# ---------------------------------------------------------------------------

if [ "${ISSUE_COUNT}" -gt 0 ]; then
    info "Processing ${ISSUE_COUNT} concrete issues"
    for i in $(seq 0 $((ISSUE_COUNT - 1))); do
        generate_test_for_issue "$i" "issue" || true
    done
fi

# Phase 3b: Qualitative findings are skipped (human review only).
# See Phase 1 comment for rationale.

# ---------------------------------------------------------------------------
# Phase 4: Clean up staging
# ---------------------------------------------------------------------------

rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

info "Test generation complete"
echo "  Evaluation: ${EVAL_ID}"
echo "  Total actionable issues: ${TOTAL_ACTIONABLE}"
echo "  Tests generated: ${GENERATED_COUNT}"
echo "  Discarded (compile failure): ${DISCARDED_COMPILE}"
echo "  Discarded (false positive): ${DISCARDED_PASSES}"
echo "  Low-confidence skipped: ${LOW_TOTAL}"

echo ""
echo "GENERATED_TESTS=${GENERATED_COUNT}"
echo "DISCARDED_COMPILE=${DISCARDED_COMPILE}"
echo "DISCARDED_PASSES=${DISCARDED_PASSES}"
echo "SKIPPED_LOW_CONFIDENCE=${LOW_TOTAL}"

if [ "${GENERATED_COUNT}" -gt 0 ]; then
    echo "GENERATED_FILES:"
    for path in "${GENERATED_PATHS[@]}"; do
        echo "  ${path}"
    done
fi

exit 0
