#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# heal-loop.sh -- Top-level orchestrator for the LLM visual verification
# workflow. Chains capture, evaluate, generate tests, fix (via /build --afk),
# and verify phases with bounded iteration.
#
# Usage:
#   scripts/visual-verification/heal-loop.sh [flags]
#
# Flags:
#   --feature-id ID     Feature ID for /build --afk invocation (required unless --dry-run)
#   --max-iterations N  Maximum heal iterations (default: 3)
#   --dry-run           Capture + evaluate only, no test generation or fixes
#   --attended          Interactive escalation (prompt instead of report file)
#   --skip-build        Skip initial swift build in capture phase
#
# Exit codes:
#   0  Clean (no issues) or all issues resolved
#   1  Unresolved issues after max iterations (escalation produced)
#   2  Infrastructure failure (capture, git, etc.)
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
VERIFICATION_DIR="${PROJECT_ROOT}/.rp1/work/verification"
REPORTS_DIR="${VERIFICATION_DIR}/reports"
REGISTRY_FILE="${VERIFICATION_DIR}/registry.json"
AUDIT_FILE="${VERIFICATION_DIR}/audit.jsonl"
LOOP_STATE="${VERIFICATION_DIR}/current-loop.json"
VISION_COMPLIANCE_DIR="${PROJECT_ROOT}/mkdnTests/UITest/VisionCompliance"

FEATURE_ID=""
MAX_ITERATIONS=3
DRY_RUN=false
ATTENDED=false
SKIP_BUILD=false
MANUAL_GUIDANCE=""
ESCALATION_ACTION=""

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TIMESTAMP_COMPACT=$(date -u +"%Y%m%d-%H%M%S")
LOOP_ID="loop-$(date -u +"%Y-%m-%d-%H%M%S")"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

info() {
    echo "==> $1"
}

error() {
    echo "ERROR: $1" >&2
    exit 2
}

warn() {
    echo "WARN: $1" >&2
}

append_audit() {
    local entry="$1"
    echo "${entry}" >> "${AUDIT_FILE}"
}

# Parse key=value output lines from child scripts.
# Usage: VALUE=$(parse_output "KEY" "$output")
parse_output() {
    local key="$1"
    local output="$2"
    echo "${output}" | grep -E "^${key}=" | head -1 | sed "s/^${key}=//"
}

# Extract total issue count (issues + qualitative findings) from evaluation report.
count_issues() {
    local report="$1"
    local issues qualitative
    issues=$(jq '.issues | length' "${report}" 2>/dev/null || echo "0")
    qualitative=$(jq '.qualitativeFindings | length' "${report}" 2>/dev/null || echo "0")
    echo $((issues + qualitative))
}

# Extract PRD references from evaluation report for commit messages.
extract_prd_refs() {
    local report="$1"
    local refs
    refs=$(jq -r '([.issues[].prdReference] + [.qualitativeFindings[].reference]) | unique | join(", ")' \
        "${report}" 2>/dev/null || echo "unknown")
    echo "${refs}"
}

# Initialize or reinitialize the loop state file.
init_loop_state() {
    jq -n \
        --arg lid "${LOOP_ID}" \
        --argjson max "${MAX_ITERATIONS}" \
        --argjson cur 0 \
        --arg ts "${TIMESTAMP}" \
        '{
            loopId: $lid,
            maxIterations: $max,
            currentIteration: $cur,
            startedAt: $ts,
            iterations: []
        }' > "${LOOP_STATE}"
}

# Append an iteration record to the loop state.
update_loop_state() {
    local iteration="$1"
    local eval_id="$2"
    local issues_detected="$3"
    local tests_generated="$4"
    local build_result="$5"
    local reverify_json="${6:-null}"

    local entry
    entry=$(jq -cn \
        --argjson iter "${iteration}" \
        --arg eid "${eval_id}" \
        --argjson iss "${issues_detected}" \
        --argjson tgen "${tests_generated}" \
        --arg br "${build_result}" \
        --argjson rv "${reverify_json}" \
        '{
            iteration: $iter,
            evaluationId: $eid,
            issuesDetected: $iss,
            testsGenerated: $tgen,
            buildResult: $br,
            reVerification: $rv
        }')

    local updated
    updated=$(jq \
        --argjson entry "${entry}" \
        --argjson cur "${iteration}" \
        '.currentIteration = $cur | .iterations += [$entry]' \
        "${LOOP_STATE}")
    echo "${updated}" > "${LOOP_STATE}"
}

# Write a clean report (no issues detected).
write_clean_report() {
    local report_file="${REPORTS_DIR}/${TIMESTAMP_COMPACT}-clean.json"
    jq -n \
        --arg lid "${LOOP_ID}" \
        --arg ts "${TIMESTAMP}" \
        --arg status "clean" \
        '{
            loopId: $lid,
            timestamp: $ts,
            status: $status,
            message: "No design issues detected. All captures comply with design specifications."
        }' > "${report_file}"

    info "Clean report written to ${report_file}"
    echo "${report_file}"
}

# Write a success report (all issues resolved).
write_success_report() {
    local iteration="$1"
    local report_file="${REPORTS_DIR}/${TIMESTAMP_COMPACT}-success.json"

    jq -n \
        --arg lid "${LOOP_ID}" \
        --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --arg status "resolved" \
        --argjson iterations "${iteration}" \
        --argjson loopState "$(cat "${LOOP_STATE}")" \
        '{
            loopId: $lid,
            timestamp: $ts,
            status: $status,
            iterations: $iterations,
            message: "All detected design issues have been resolved.",
            loopState: $loopState
        }' > "${report_file}"

    info "Success report written to ${report_file}"
    echo "${report_file}"
}

# Write an escalation report (unresolved issues).
write_escalation_report() {
    local reason="$1"
    local eval_report="$2"
    local reverify_report="${3:-}"

    local report_file="${REPORTS_DIR}/${TIMESTAMP_COMPACT}-escalation.json"

    # Collect unresolved issues
    local unresolved_issues="[]"
    local low_confidence_issues="[]"

    if [ -f "${eval_report}" ]; then
        unresolved_issues=$(jq -c '[.issues[] | select(.confidence == "medium" or .confidence == "high")]' \
            "${eval_report}" 2>/dev/null || echo "[]")
        low_confidence_issues=$(jq -c '
            [.issues[] | select(.confidence == "low")] +
            [.qualitativeFindings[] | select(.confidence == "low")]' \
            "${eval_report}" 2>/dev/null || echo "[]")

        # If we have a reverification report, use remaining issues from there
        if [ -n "${reverify_report}" ] && [ -f "${reverify_report}" ]; then
            unresolved_issues=$(jq -c '.remainingIssues + .newRegressions' \
                "${reverify_report}" 2>/dev/null || echo "${unresolved_issues}")
        fi
    fi

    jq -n \
        --arg etype "${reason}" \
        --arg lid "${LOOP_ID}" \
        --argjson iters "${MAX_ITERATIONS}" \
        --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --argjson unresolvedIssues "${unresolved_issues}" \
        --argjson lowConfidenceIssues "${low_confidence_issues}" \
        --argjson loopState "$(cat "${LOOP_STATE}")" \
        '{
            escalationType: $etype,
            loopId: $lid,
            iterations: $iters,
            timestamp: $ts,
            unresolvedIssues: $unresolvedIssues,
            lowConfidenceIssues: $lowConfidenceIssues,
            loopState: $loopState,
            suggestedNextSteps: [
                "Review the unresolved issues and their PRD references",
                "Check if the design specifications need updating based on implementation constraints",
                "Manually inspect the screenshots in .rp1/work/verification/captures/",
                "Run individual phases for debugging: capture.sh, evaluate.sh, generate-tests.sh"
            ]
        }' > "${report_file}"

    info "Escalation report written to ${report_file}"
    echo "${report_file}"
}

# Handle escalation (report file or interactive depending on --attended).
# Sets ESCALATION_ACTION: "continue" (with guidance), "skip", or "quit".
# Sets MANUAL_GUIDANCE when ESCALATION_ACTION is "continue".
handle_escalation() {
    local reason="$1"
    local eval_report="$2"
    local reverify_report="${3:-}"

    ESCALATION_ACTION="quit"

    if [ "${ATTENDED}" = true ]; then
        info "ESCALATION (attended mode): ${reason}"
        echo ""
        echo "============================================================"
        echo "ESCALATION: ${reason}"
        echo "Loop ID: ${LOOP_ID}"
        echo "============================================================"
        echo ""

        if [ -f "${eval_report}" ]; then
            echo "Unresolved issues:"
            jq -r '.issues[] | "  - [\(.severity)/\(.confidence)] \(.prdReference): \(.observation)"' \
                "${eval_report}" 2>/dev/null || true
            jq -r '.qualitativeFindings[] | "  - [\(.severity)/\(.confidence)] \(.reference): \(.observation)"' \
                "${eval_report}" 2>/dev/null || true
        fi

        if [ -n "${reverify_report}" ] && [ -f "${reverify_report}" ]; then
            echo ""
            echo "Re-verification summary:"
            jq -r '"  Resolved: \(.summary.resolved), Regressions: \(.summary.regressions), Remaining: \(.summary.remaining)"' \
                "${reverify_report}" 2>/dev/null || true
        fi

        echo ""
        echo "Options:"
        echo "  [c] Continue with manual guidance"
        echo "  [s] Skip remaining issues"
        echo "  [q] Quit and write escalation report"
        echo ""
        read -r -p "Choice [q]: " choice
        choice="${choice:-q}"

        case "${choice}" in
            c|C)
                # SA-5: Read multi-line guidance from stdin
                local guidance_retries=0
                local max_guidance_retries=3
                local guidance_text=""

                while true; do
                    echo ""
                    echo "Enter your guidance for the next fix iteration."
                    echo "The text will be included verbatim in the build prompt."
                    echo "Finish with an empty line or Ctrl-D."
                    echo ""

                    guidance_text=""
                    while IFS= read -r line; do
                        if [ -z "${line}" ] && [ -n "${guidance_text}" ]; then
                            break
                        fi
                        if [ -n "${guidance_text}" ]; then
                            guidance_text="${guidance_text}
${line}"
                        else
                            guidance_text="${line}"
                        fi
                    done

                    if [ -z "${guidance_text}" ]; then
                        guidance_retries=$((guidance_retries + 1))
                        if [ "${guidance_retries}" -ge "${max_guidance_retries}" ]; then
                            warn "Max guidance retries reached -- falling back to escalation report"
                            write_escalation_report "${reason}" "${eval_report}" "${reverify_report}"
                            ESCALATION_ACTION="quit"

                            append_audit "$(jq -cn \
                                --arg type "escalation" \
                                --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
                                --arg lid "${LOOP_ID}" \
                                --arg reason "${reason}" \
                                '{type: $type, timestamp: $ts, loopId: $lid, reason: $reason}')"
                            return
                        fi
                        warn "Empty guidance -- please provide guidance text"
                        continue
                    fi

                    break
                done

                # Show confirmation (preview first 5 lines)
                echo ""
                local guidance_lines
                guidance_lines=$(echo "${guidance_text}" | wc -l | tr -d ' ')
                info "Guidance captured (${#guidance_text} chars):"
                echo "${guidance_text}" | head -5
                if [ "${guidance_lines}" -gt 5 ]; then
                    echo "  ... (truncated in preview)"
                fi
                echo ""

                MANUAL_GUIDANCE="${guidance_text}"
                ESCALATION_ACTION="continue"

                # SA-5: Append manualGuidance audit entry (sanitized via jq --arg)
                append_audit "$(jq -cn \
                    --arg type "manualGuidance" \
                    --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
                    --arg lid "${LOOP_ID}" \
                    --argjson iter "${ITERATION}" \
                    --arg guidance "${guidance_text}" \
                    '{type: $type, timestamp: $ts, loopId: $lid, iteration: $iter, guidance: $guidance}')"

                return
                ;;
            s|S)
                info "Skipping remaining issues"
                ESCALATION_ACTION="skip"
                write_escalation_report "${reason}" "${eval_report}" "${reverify_report}"
                ;;
            *)
                ESCALATION_ACTION="quit"
                write_escalation_report "${reason}" "${eval_report}" "${reverify_report}"
                ;;
        esac
    else
        write_escalation_report "${reason}" "${eval_report}" "${reverify_report}"
    fi

    append_audit "$(jq -cn \
        --arg type "escalation" \
        --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --arg lid "${LOOP_ID}" \
        --arg reason "${reason}" \
        '{type: $type, timestamp: $ts, loopId: $lid, reason: $reason}')"
}

# ---------------------------------------------------------------------------
# Parse flags
# ---------------------------------------------------------------------------

while [ $# -gt 0 ]; do
    case "$1" in
        --feature-id)
            shift
            FEATURE_ID="${1:-}"
            shift
            ;;
        --max-iterations)
            shift
            MAX_ITERATIONS="${1:-3}"
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --attended)
            ATTENDED=true
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --help|-h)
            echo "Usage: heal-loop.sh [flags]"
            echo ""
            echo "Top-level orchestrator for the LLM visual verification workflow."
            echo "Chains capture, evaluate, generate tests, fix, and verify phases"
            echo "with bounded iteration."
            echo ""
            echo "Flags:"
            echo "  --feature-id ID     Feature ID for /build --afk (required unless --dry-run)"
            echo "  --max-iterations N  Maximum heal iterations (default: 3)"
            echo "  --dry-run           Capture + evaluate only, no fixes"
            echo "  --attended          Interactive escalation prompts"
            echo "  --skip-build        Skip initial swift build"
            echo ""
            echo "Exit codes:"
            echo "  0  Clean or all issues resolved"
            echo "  1  Unresolved issues (escalation produced)"
            echo "  2  Infrastructure failure"
            exit 0
            ;;
        *)
            error "Unknown flag: $1"
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------

info "Starting heal-loop (${LOOP_ID})"
info "  Feature ID: ${FEATURE_ID:-<not set>}"
info "  Max iterations: ${MAX_ITERATIONS}"
info "  Dry-run: ${DRY_RUN}"
info "  Attended: ${ATTENDED}"
info "  Skip-build: ${SKIP_BUILD}"

command -v jq > /dev/null 2>&1 || error "jq is required but not found"

# --feature-id is required when not in dry-run mode (needed for /build --afk invocation)
if [ "${DRY_RUN}" = false ] && [ -z "${FEATURE_ID}" ]; then
    error "--feature-id is required for the heal loop (needed to invoke /build --afk)"
fi

mkdir -p "${REPORTS_DIR}" "${VERIFICATION_DIR}/captures" \
         "${VERIFICATION_DIR}/cache" "${VERIFICATION_DIR}/staging"

# Ensure registry exists and is valid
if [ ! -f "${REGISTRY_FILE}" ] || ! jq . "${REGISTRY_FILE}" > /dev/null 2>&1; then
    warn "Registry missing or corrupt -- reinitializing"
    echo '{"version": 1, "entries": []}' > "${REGISTRY_FILE}"
fi

# Initialize loop state
init_loop_state

append_audit "$(jq -cn \
    --arg type "loopStarted" \
    --arg ts "${TIMESTAMP}" \
    --arg lid "${LOOP_ID}" \
    --argjson max "${MAX_ITERATIONS}" \
    --argjson dryRun "${DRY_RUN}" \
    '{type: $type, timestamp: $ts, loopId: $lid, maxIterations: $max, dryRun: $dryRun}')"

# ---------------------------------------------------------------------------
# Phase 1: Initial capture
# ---------------------------------------------------------------------------

info "Phase 1: Capture"

CAPTURE_FLAGS=()
if [ "${SKIP_BUILD}" = true ]; then
    CAPTURE_FLAGS+=("--skip-build")
fi

if ! "${SCRIPT_DIR}/capture.sh" "${CAPTURE_FLAGS[@]+"${CAPTURE_FLAGS[@]}"}"; then
    handle_escalation "captureFailure" "/dev/null"
    error "Capture phase failed"
fi

info "Capture phase complete"

# ---------------------------------------------------------------------------
# Phase 2: Initial evaluation
# ---------------------------------------------------------------------------

info "Phase 2: Evaluate"

EVAL_FLAGS=()
if [ "${DRY_RUN}" = true ]; then
    EVAL_FLAGS+=("--dry-run")
fi

if ! "${SCRIPT_DIR}/evaluate.sh" "${EVAL_FLAGS[@]+"${EVAL_FLAGS[@]}"}"; then
    handle_escalation "evaluationFailure" "/dev/null"
    error "Evaluation phase failed"
fi

# Find the evaluation report (most recent)
EVAL_REPORT=$(ls -t "${REPORTS_DIR}"/*-evaluation.json 2>/dev/null | head -1) || true

# In dry-run mode, the output is a dryrun report, not an evaluation report
if [ "${DRY_RUN}" = true ]; then
    DRY_REPORT=$(ls -t "${REPORTS_DIR}"/*-dryrun.json 2>/dev/null | head -1) || true
    info "Dry-run complete"
    if [ -n "${DRY_REPORT}" ]; then
        info "Dry-run report: ${DRY_REPORT}"
        jq . "${DRY_REPORT}"
    fi

    append_audit "$(jq -cn \
        --arg type "loopCompleted" \
        --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --arg lid "${LOOP_ID}" \
        --arg result "dryRun" \
        '{type: $type, timestamp: $ts, loopId: $lid, result: $result}')"

    info "Heal-loop complete (dry-run mode)"
    exit 0
fi

# Validate we have an evaluation report
if [ -z "${EVAL_REPORT}" ] || [ ! -f "${EVAL_REPORT}" ]; then
    error "No evaluation report produced"
fi

EVAL_ID=$(jq -r '.evaluationId' "${EVAL_REPORT}")
ISSUE_COUNT=$(count_issues "${EVAL_REPORT}")

info "Initial evaluation: ${EVAL_ID}"
info "  Issues detected: ${ISSUE_COUNT}"

# ---------------------------------------------------------------------------
# Phase 2b: Check for zero issues
# ---------------------------------------------------------------------------

if [ "${ISSUE_COUNT}" -eq 0 ]; then
    info "No issues detected -- all captures comply with design specifications"

    CLEAN_REPORT=$(write_clean_report)

    update_loop_state 0 "${EVAL_ID}" 0 0 "n/a" "null"

    append_audit "$(jq -cn \
        --arg type "loopCompleted" \
        --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --arg lid "${LOOP_ID}" \
        --arg result "clean" \
        '{type: $type, timestamp: $ts, loopId: $lid, result: $result}')"

    info "Heal-loop complete (clean)"
    exit 0
fi

# ---------------------------------------------------------------------------
# Heal iteration loop
# ---------------------------------------------------------------------------

ITERATION=0
CURRENT_EVAL_REPORT="${EVAL_REPORT}"
CURRENT_EVAL_ID="${EVAL_ID}"
LATEST_REVERIFY_REPORT=""
LOOP_BREAK=""

while true; do  # outer loop: allows extension via "continue" at maxIterationsExhausted

while [ "${ITERATION}" -lt "${MAX_ITERATIONS}" ]; do
    ITERATION=$((ITERATION + 1))
    info "=========================================="
    info "Heal iteration ${ITERATION} of ${MAX_ITERATIONS}"
    info "=========================================="

    # ------------------------------------------------------------------
    # Step 1: Generate failing tests
    # ------------------------------------------------------------------

    info "Step 1: Generate tests from evaluation"

    GEN_OUTPUT=$("${SCRIPT_DIR}/generate-tests.sh" "${CURRENT_EVAL_REPORT}" 2>&1) || true
    GENERATED_TESTS=$(parse_output "GENERATED_TESTS" "${GEN_OUTPUT}")
    GENERATED_TESTS="${GENERATED_TESTS:-0}"

    info "  Tests generated: ${GENERATED_TESTS}"

    if [ "${GENERATED_TESTS}" -eq 0 ]; then
        info "No valid tests generated (all discarded or low-confidence)"

        update_loop_state "${ITERATION}" "${CURRENT_EVAL_ID}" "${ISSUE_COUNT}" 0 "skipped" "null"

        handle_escalation "noTestsGenerated" "${CURRENT_EVAL_REPORT}" "${LATEST_REVERIFY_REPORT}"

        append_audit "$(jq -cn \
            --arg type "loopCompleted" \
            --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
            --arg lid "${LOOP_ID}" \
            --arg result "escalated" \
            --arg reason "noTestsGenerated" \
            '{type: $type, timestamp: $ts, loopId: $lid, result: $result, reason: $reason}')"

        info "Heal-loop complete (escalated -- no tests generated)"
        exit 0
    fi

    # ------------------------------------------------------------------
    # Step 2: Commit generated tests
    # ------------------------------------------------------------------

    info "Step 2: Commit generated tests"

    PRD_REFS=$(extract_prd_refs "${CURRENT_EVAL_REPORT}")
    COMMIT_MSG="test: vision-detected failing tests for ${PRD_REFS}"

    # Stage VisionCompliance test files (including newly generated ones)
    if ! git -C "${PROJECT_ROOT}" add "${VISION_COMPLIANCE_DIR}/" 2>&1; then
        warn "git add failed -- attempting cleanup"
        git -C "${PROJECT_ROOT}" reset HEAD "${VISION_COMPLIANCE_DIR}/" 2>/dev/null || true
        handle_escalation "gitFailure" "${CURRENT_EVAL_REPORT}"
        error "git add failed for generated tests"
    fi

    # Check if there is anything to commit
    if git -C "${PROJECT_ROOT}" diff --cached --quiet "${VISION_COMPLIANCE_DIR}/" 2>/dev/null; then
        info "  No new files to commit"
    else
        if ! git -C "${PROJECT_ROOT}" commit -m "${COMMIT_MSG}" 2>&1; then
            warn "git commit failed -- cleaning up staged files"
            git -C "${PROJECT_ROOT}" reset HEAD "${VISION_COMPLIANCE_DIR}/" 2>/dev/null || true
            handle_escalation "gitFailure" "${CURRENT_EVAL_REPORT}"
            error "git commit failed for generated tests"
        fi
        COMMIT_SHA=$(git -C "${PROJECT_ROOT}" rev-parse HEAD)
        info "  Committed: ${COMMIT_SHA:0:8} -- ${COMMIT_MSG}"
    fi

    # ------------------------------------------------------------------
    # Step 3: Invoke /build --afk to fix the failing tests
    # ------------------------------------------------------------------

    info "Step 3: Invoke /build --afk"

    # Collect generated test file paths from generate-tests.sh output.
    # The output format is "GENERATED_FILES:" followed by indented paths.
    TEST_PATHS=""
    IN_FILES=false
    while IFS= read -r line; do
        if echo "${line}" | grep -q "^GENERATED_FILES:"; then
            IN_FILES=true
            continue
        fi
        if [ "${IN_FILES}" = true ]; then
            trimmed=$(echo "${line}" | xargs)
            if [ -z "${trimmed}" ]; then
                IN_FILES=false
                continue
            fi
            if [ -f "${trimmed}" ]; then
                TEST_PATHS="${TEST_PATHS} ${trimmed}"
            fi
        fi
    done <<< "${GEN_OUTPUT}"

    # Convert space-separated TEST_PATHS to array for iteration
    TEST_PATHS_ARRAY=()
    for tp in ${TEST_PATHS}; do
        TEST_PATHS_ARRAY+=("${tp}")
    done

    # SA-2: Record HEAD before build for file diff (design section 3.5.2)
    PRE_BUILD_HEAD=$(git -C "${PROJECT_ROOT}" rev-parse HEAD 2>/dev/null) || PRE_BUILD_HEAD=""

    # SA-2: Build structured multi-test prompt (design section 3.5.1)
    # Each failing test gets a section with file path, PRD reference,
    # specification excerpt, and observation from the evaluation report.
    FAILING_TESTS_SECTION=""
    TEST_NUM=0

    for tp in "${TEST_PATHS_ARRAY[@]+"${TEST_PATHS_ARRAY[@]}"}"; do
        TEST_NUM=$((TEST_NUM + 1))
        tp_basename=$(basename "${tp}")

        # Extract PRD reference from the test file content
        ISSUE_PRD=""
        ISSUE_PRD=$(grep -oE '[a-z][-a-z]* FR-[0-9]+' "${tp}" 2>/dev/null | head -1) || true
        if [ -z "${ISSUE_PRD}" ]; then
            ISSUE_PRD=$(grep -oE 'charter:[a-z-]+' "${tp}" 2>/dev/null | head -1) || true
        fi

        # Look up issue details from evaluation report by PRD reference
        ISSUE_SPEC=""
        ISSUE_OBS=""
        if [ -n "${ISSUE_PRD}" ]; then
            ISSUE_SPEC=$(jq -r --arg prd "${ISSUE_PRD}" \
                '([.issues[] | select(.prdReference == $prd)])[0].specificationExcerpt // ""' \
                "${CURRENT_EVAL_REPORT}" 2>/dev/null) || true
            ISSUE_OBS=$(jq -r --arg prd "${ISSUE_PRD}" \
                '([.issues[] | select(.prdReference == $prd)])[0].observation // ""' \
                "${CURRENT_EVAL_REPORT}" 2>/dev/null) || true
            # Try qualitative findings if no match in concrete issues
            if [ -z "${ISSUE_OBS}" ] || [ "${ISSUE_OBS}" = "null" ]; then
                ISSUE_OBS=$(jq -r --arg ref "${ISSUE_PRD}" \
                    '([.qualitativeFindings[] | select(.reference == $ref)])[0].observation // ""' \
                    "${CURRENT_EVAL_REPORT}" 2>/dev/null) || true
                ISSUE_SPEC=$(jq -r --arg ref "${ISSUE_PRD}" \
                    '([.qualitativeFindings[] | select(.reference == $ref)])[0].assessment // ""' \
                    "${CURRENT_EVAL_REPORT}" 2>/dev/null) || true
            fi
        fi

        FAILING_TESTS_SECTION="${FAILING_TESTS_SECTION}
### Test ${TEST_NUM}: ${tp_basename}
- **File**: ${tp}
- **PRD Reference**: ${ISSUE_PRD:-See evaluation report}
- **Specification**: ${ISSUE_SPEC:-See evaluation report for details}
- **Issue**: ${ISSUE_OBS:-See evaluation report for details}
"
    done

    # SA-5: Include manual guidance section if set (from T16)
    GUIDANCE_SECTION=""
    if [ -n "${MANUAL_GUIDANCE}" ]; then
        GUIDANCE_SECTION="
## Developer Guidance

${MANUAL_GUIDANCE}"
    fi

    # SA-2: Structured multi-test prompt with iteration instructions
    BUILD_PROMPT="/build ${FEATURE_ID} AFK=true

## Task

Fix the following vision-detected design compliance test failures.
These tests encode visual deviations detected by LLM visual verification.

## Failing Tests
${FAILING_TESTS_SECTION}
## Iteration Instructions

Fix all failing tests listed above. After making changes:

1. Run \`swift test --filter VisionDetected\` to check which tests now pass.
2. If any tests still fail, analyze the failure and make additional fixes.
3. Repeat until all listed tests pass or you determine a test cannot be fixed
   without changing the specification.
4. Report which tests you fixed and which remain failing.

## Evaluation Report

${CURRENT_EVAL_REPORT}
${GUIDANCE_SECTION}"

    BUILD_RESULT="unknown"
    if command -v claude > /dev/null 2>&1; then
        info "  Invoking /build ${FEATURE_ID} AFK=true"
        if claude -p "${BUILD_PROMPT}" 2>&1; then
            BUILD_RESULT="success"
            info "  /build --afk completed successfully"
        else
            BUILD_RESULT="failure"
            warn "  /build --afk reported failure"
        fi
    else
        BUILD_RESULT="skipped"
        warn "  claude CLI not found -- skipping /build --afk"
    fi

    # SA-2: Capture files modified after build (design section 3.5.2)
    FILES_MODIFIED="[]"
    if [ -n "${PRE_BUILD_HEAD}" ]; then
        POST_BUILD_HEAD=$(git -C "${PROJECT_ROOT}" rev-parse HEAD 2>/dev/null) || POST_BUILD_HEAD=""
        if [ -n "${POST_BUILD_HEAD}" ] && [ "${PRE_BUILD_HEAD}" != "${POST_BUILD_HEAD}" ]; then
            FILES_MODIFIED=$(git -C "${PROJECT_ROOT}" diff --name-only "${PRE_BUILD_HEAD}" HEAD 2>/dev/null | \
                jq -R . | jq -s . 2>/dev/null) || FILES_MODIFIED="[]"
        fi
    fi

    # SA-2: Check which tests now pass vs still fail (design section 3.5.2)
    TESTS_FIXED=()
    TESTS_REMAINING=()
    for tp in "${TEST_PATHS_ARRAY[@]+"${TEST_PATHS_ARRAY[@]}"}"; do
        suite_name=$(grep -oE '@Suite\("VisionDetected_[^"]*"' "${tp}" 2>/dev/null | \
            sed 's/@Suite("//;s/"//' | head -1) || true
        if [ -n "${suite_name}" ]; then
            if swift test --filter "${suite_name}" 2>&1 | tail -1 | grep -q "passed"; then
                TESTS_FIXED+=("${suite_name}")
            else
                TESTS_REMAINING+=("${suite_name}")
            fi
        fi
    done

    info "  Tests fixed: ${#TESTS_FIXED[@]}"
    info "  Tests remaining: ${#TESTS_REMAINING[@]}"
    info "  Files modified: $(echo "${FILES_MODIFIED}" | jq 'length' 2>/dev/null || echo 0)"

    # Convert arrays to JSON for audit and loop state (T18 will enhance the audit entry)
    TEST_PATHS_JSON=$(printf '%s\n' "${TEST_PATHS_ARRAY[@]+"${TEST_PATHS_ARRAY[@]}"}" | \
        sed "s|${PROJECT_ROOT}/||" | grep -v '^$' | jq -R . | jq -s . 2>/dev/null || echo "[]")
    TESTS_FIXED_JSON=$(printf '%s\n' "${TESTS_FIXED[@]+"${TESTS_FIXED[@]}"}" | \
        grep -v '^$' | jq -R . | jq -s . 2>/dev/null || echo "[]")
    TESTS_REMAINING_JSON=$(printf '%s\n' "${TESTS_REMAINING[@]+"${TESTS_REMAINING[@]}"}" | \
        grep -v '^$' | jq -R . | jq -s . 2>/dev/null || echo "[]")

    append_audit "$(jq -cn \
        --arg type "buildInvocation" \
        --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --arg lid "${LOOP_ID}" \
        --argjson iter "${ITERATION}" \
        --arg result "${BUILD_RESULT}" \
        --arg prds "${PRD_REFS}" \
        --argjson testPaths "${TEST_PATHS_JSON}" \
        --argjson filesModified "${FILES_MODIFIED}" \
        --argjson testsFixed "${TESTS_FIXED_JSON}" \
        --argjson testsRemaining "${TESTS_REMAINING_JSON}" \
        '{type: $type, timestamp: $ts, loopId: $lid, iteration: $iter,
         result: $result, prdRefs: $prds, testPaths: $testPaths,
         filesModified: $filesModified, testsFixed: $testsFixed,
         testsRemaining: $testsRemaining}')"

    if [ "${BUILD_RESULT}" = "failure" ]; then
        update_loop_state "${ITERATION}" "${CURRENT_EVAL_ID}" "${ISSUE_COUNT}" \
            "${GENERATED_TESTS}" "failure" "null"

        handle_escalation "buildFailure" "${CURRENT_EVAL_REPORT}" "${LATEST_REVERIFY_REPORT}"

        append_audit "$(jq -cn \
            --arg type "loopCompleted" \
            --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
            --arg lid "${LOOP_ID}" \
            --arg result "escalated" \
            --arg reason "buildFailure" \
            '{type: $type, timestamp: $ts, loopId: $lid, result: $result, reason: $reason}')"

        info "Heal-loop halted (build failure -- escalated)"
        exit 1
    fi

    # ------------------------------------------------------------------
    # Step 4: Re-verify
    # ------------------------------------------------------------------

    info "Step 4: Re-verify"

    VERIFY_OUTPUT=$("${SCRIPT_DIR}/verify.sh" "${CURRENT_EVAL_REPORT}" 2>&1) || true
    RESOLVED=$(parse_output "RESOLVED" "${VERIFY_OUTPUT}")
    REGRESSIONS=$(parse_output "REGRESSIONS" "${VERIFY_OUTPUT}")
    REMAINING=$(parse_output "REMAINING" "${VERIFY_OUTPUT}")
    REVERIFY_REPORT=$(parse_output "REVERIFICATION_REPORT" "${VERIFY_OUTPUT}")
    NEW_EVAL_PATH=$(parse_output "NEW_EVALUATION" "${VERIFY_OUTPUT}")

    RESOLVED="${RESOLVED:-0}"
    REGRESSIONS="${REGRESSIONS:-0}"
    REMAINING="${REMAINING:-0}"

    info "  Resolved: ${RESOLVED}"
    info "  Regressions: ${REGRESSIONS}"
    info "  Remaining: ${REMAINING}"

    # Build re-verification JSON for loop state
    REVERIFY_JSON="null"
    if [ -n "${REVERIFY_REPORT}" ] && [ -f "${REVERIFY_REPORT}" ]; then
        RESOLVED_IDS=$(jq -c '[.resolvedIssues[].reference // empty]' "${REVERIFY_REPORT}" 2>/dev/null || echo "[]")
        REGRESSION_IDS=$(jq -c '[.newRegressions[] | .prdReference // .reference // empty]' "${REVERIFY_REPORT}" 2>/dev/null || echo "[]")
        REMAINING_IDS=$(jq -c '[.remainingIssues[] | .prdReference // .reference // empty]' "${REVERIFY_REPORT}" 2>/dev/null || echo "[]")

        REVERIFY_JSON=$(jq -cn \
            --argjson resolved "${RESOLVED_IDS}" \
            --argjson regressions "${REGRESSION_IDS}" \
            --argjson remaining "${REMAINING_IDS}" \
            '{resolvedIssues: $resolved, newRegressions: $regressions, remainingIssues: $remaining}')
    fi

    update_loop_state "${ITERATION}" "${CURRENT_EVAL_ID}" "${ISSUE_COUNT}" \
        "${GENERATED_TESTS}" "${BUILD_RESULT}" "${REVERIFY_JSON}"

    LATEST_REVERIFY_REPORT="${REVERIFY_REPORT}"

    # Check if all issues are resolved
    TOTAL_OUTSTANDING=$((REGRESSIONS + REMAINING))

    if [ "${TOTAL_OUTSTANDING}" -eq 0 ]; then
        info "All issues resolved after ${ITERATION} iteration(s)"

        write_success_report "${ITERATION}"

        append_audit "$(jq -cn \
            --arg type "loopCompleted" \
            --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
            --arg lid "${LOOP_ID}" \
            --arg result "resolved" \
            --argjson iterations "${ITERATION}" \
            '{type: $type, timestamp: $ts, loopId: $lid, result: $result, iterations: $iterations}')"

        info "Heal-loop complete (all resolved)"
        exit 0
    fi

    # Prepare for next iteration: use the new evaluation as the current one
    if [ -n "${NEW_EVAL_PATH}" ] && [ -f "${NEW_EVAL_PATH}" ]; then
        CURRENT_EVAL_REPORT="${NEW_EVAL_PATH}"
        CURRENT_EVAL_ID=$(jq -r '.evaluationId' "${CURRENT_EVAL_REPORT}" 2>/dev/null || echo "unknown")
    fi

    ISSUE_COUNT="${TOTAL_OUTSTANDING}"

    # Clear manual guidance (BR-4: single-iteration scope)
    MANUAL_GUIDANCE=""

    # SA-5: If attended and issues remain, prompt for guidance
    if [ "${ATTENDED}" = true ]; then
        ESCALATION_ACTION=""
        handle_escalation "unresolvedIssues" "${CURRENT_EVAL_REPORT}" "${LATEST_REVERIFY_REPORT}"

        case "${ESCALATION_ACTION}" in
            continue)
                info "  Continuing with manual guidance for next iteration"
                ;;
            skip)
                LOOP_BREAK="skip"
                break
                ;;
            *)
                LOOP_BREAK="quit"
                break
                ;;
        esac
    fi

    info "  ${TOTAL_OUTSTANDING} issue(s) remain -- continuing to next iteration"
done

# Check if inner loop was broken by user action (attended mode)
if [ -n "${LOOP_BREAK}" ]; then
    break
fi

# ---------------------------------------------------------------------------
# Max iterations exhausted
# ---------------------------------------------------------------------------

info "Max iterations exhausted (${MAX_ITERATIONS}) with ${ISSUE_COUNT} issue(s) remaining"

MANUAL_GUIDANCE=""
ESCALATION_ACTION=""
handle_escalation "maxIterationsExhausted" "${CURRENT_EVAL_REPORT}" "${LATEST_REVERIFY_REPORT}"

# SA-5: Allow continuation if user provides guidance at maxIterationsExhausted
if [ "${ESCALATION_ACTION}" = "continue" ]; then
    MAX_ITERATIONS=$((MAX_ITERATIONS + 1))
    info "Extending max iterations to ${MAX_ITERATIONS}"
    continue  # re-enter outer loop -> inner while loop runs one more iteration
fi

break

done  # outer while true: allows extension via "continue" at maxIterationsExhausted

# ---------------------------------------------------------------------------
# Post-loop exit handling
# ---------------------------------------------------------------------------

case "${LOOP_BREAK}" in
    skip)
        write_escalation_report "userSkipped" "${CURRENT_EVAL_REPORT}" "${LATEST_REVERIFY_REPORT}"

        append_audit "$(jq -cn \
            --arg type "loopCompleted" \
            --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
            --arg lid "${LOOP_ID}" \
            --arg result "skipped" \
            '{type: $type, timestamp: $ts, loopId: $lid, result: $result}')"

        info "Heal-loop complete (user skipped remaining issues)"
        exit 0
        ;;
    quit)
        append_audit "$(jq -cn \
            --arg type "loopCompleted" \
            --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
            --arg lid "${LOOP_ID}" \
            --arg result "escalated" \
            --arg reason "userQuit" \
            '{type: $type, timestamp: $ts, loopId: $lid, result: $result, reason: $reason}')"

        info "Heal-loop complete (user quit)"
        exit 1
        ;;
esac

# Max iterations exhausted (quit or non-attended at maxIterationsExhausted)
append_audit "$(jq -cn \
    --arg type "loopCompleted" \
    --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    --arg lid "${LOOP_ID}" \
    --arg result "escalated" \
    --arg reason "maxIterationsExhausted" \
    --argjson iterations "${MAX_ITERATIONS}" \
    '{type: $type, timestamp: $ts, loopId: $lid, result: $result, reason: $reason, iterations: $iterations}')"

info "Heal-loop complete (escalated -- max iterations exhausted)"
exit 1
