#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# verify.sh -- Re-capture screenshots and re-evaluate after a fix, comparing
# against a previous evaluation to detect regressions and confirm resolutions.
#
# Performs two levels of regression detection:
#   Phase 3:  Previous-evaluation comparison (resolved/regression/remaining)
#   Phase 3b: Registry history scan (SA-3) -- detects issues that were
#             previously resolved in any historical evaluation but have
#             reappeared (reintroduced regressions)
#
# Usage:
#   scripts/visual-verification/verify.sh [previous-evaluation-path]
#
# If no path is provided, uses the most recent evaluation report in
# .rp1/work/verification/reports/.
#
# Output:
#   Re-verification report at .rp1/work/verification/reports/{timestamp}-reverification.json
#   Updated registry at .rp1/work/verification/registry.json
#   Audit trail entries appended to .rp1/work/verification/audit.jsonl
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
VERIFICATION_DIR="${PROJECT_ROOT}/.rp1/work/verification"
REPORTS_DIR="${VERIFICATION_DIR}/reports"
REGISTRY_FILE="${VERIFICATION_DIR}/registry.json"
AUDIT_FILE="${VERIFICATION_DIR}/audit.jsonl"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TIMESTAMP_COMPACT=$(date -u +"%Y%m%d-%H%M%S")

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

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------

PREV_EVAL=""

for arg in "$@"; do
    case "${arg}" in
        --help|-h)
            echo "Usage: verify.sh [previous-evaluation-path]"
            echo ""
            echo "Re-captures screenshots and re-evaluates after a fix."
            echo "Compares new evaluation against previous to detect"
            echo "regressions and confirm resolutions."
            echo ""
            echo "If no path is provided, uses the most recent evaluation"
            echo "report in .rp1/work/verification/reports/."
            exit 0
            ;;
        *)
            if [ -z "${PREV_EVAL}" ]; then
                PREV_EVAL="${arg}"
            else
                error "Unexpected argument: ${arg}"
            fi
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Resolve previous evaluation
# ---------------------------------------------------------------------------

if [ -z "${PREV_EVAL}" ]; then
    info "No previous evaluation specified; finding most recent"
    PREV_EVAL=$(ls -t "${REPORTS_DIR}"/*-evaluation.json 2>/dev/null | head -1) || true
    if [ -z "${PREV_EVAL}" ] || [ ! -f "${PREV_EVAL}" ]; then
        error "No previous evaluation found in ${REPORTS_DIR}. Run evaluate.sh first."
    fi
fi

if [ ! -f "${PREV_EVAL}" ]; then
    error "Previous evaluation not found: ${PREV_EVAL}"
fi

command -v jq > /dev/null 2>&1 || error "jq is required but not found"

PREV_EVAL_ID=$(jq -r '.evaluationId' "${PREV_EVAL}")
info "Previous evaluation: ${PREV_EVAL_ID}"

# ---------------------------------------------------------------------------
# Phase 1: Re-capture screenshots (skip build -- already rebuilt by /build)
# ---------------------------------------------------------------------------

info "Phase 1: Re-capturing screenshots"

if ! "${SCRIPT_DIR}/capture.sh" --skip-build; then
    error "Re-capture failed"
fi

info "Re-capture complete"

# ---------------------------------------------------------------------------
# Phase 2: Re-evaluate (force fresh, bypass cache since images changed)
# ---------------------------------------------------------------------------

info "Phase 2: Re-evaluating"

if ! "${SCRIPT_DIR}/evaluate.sh" --force-fresh; then
    error "Re-evaluation failed"
fi

# Find the new evaluation report (most recent)
NEW_EVAL=$(ls -t "${REPORTS_DIR}"/*-evaluation.json 2>/dev/null | head -1) || true
if [ -z "${NEW_EVAL}" ] || [ ! -f "${NEW_EVAL}" ]; then
    error "Re-evaluation did not produce a report"
fi

NEW_EVAL_ID=$(jq -r '.evaluationId' "${NEW_EVAL}")
info "New evaluation: ${NEW_EVAL_ID}"

# ---------------------------------------------------------------------------
# Phase 3: Compare evaluations
# ---------------------------------------------------------------------------

info "Phase 3: Comparing evaluations"

# Extract issue IDs from previous evaluation
PREV_ISSUE_IDS=$(jq -r '[.issues[].issueId] | sort | .[]' "${PREV_EVAL}" 2>/dev/null || true)
PREV_FINDING_IDS=$(jq -r '[.qualitativeFindings[].findingId] | sort | .[]' "${PREV_EVAL}" 2>/dev/null || true)

# Extract issue IDs from new evaluation
NEW_ISSUE_IDS=$(jq -r '[.issues[].issueId] | sort | .[]' "${NEW_EVAL}" 2>/dev/null || true)
NEW_FINDING_IDS=$(jq -r '[.qualitativeFindings[].findingId] | sort | .[]' "${NEW_EVAL}" 2>/dev/null || true)

# Combine all IDs for comparison
# Note: We compare by PRD reference + aspect since issue IDs may differ
# between evaluations. Instead, compare by prdReference for concrete issues
# and by reference + observation keyword for qualitative findings.

# For concrete issues: key on prdReference
PREV_ISSUE_PRDS=$(jq -r '[.issues[].prdReference] | sort | unique | .[]' \
    "${PREV_EVAL}" 2>/dev/null || true)
NEW_ISSUE_PRDS=$(jq -r '[.issues[].prdReference] | sort | unique | .[]' \
    "${NEW_EVAL}" 2>/dev/null || true)

# Resolved: in previous but not in new
RESOLVED_ISSUES=()
while IFS= read -r prd; do
    [ -z "${prd}" ] && continue
    if ! echo "${NEW_ISSUE_PRDS}" | grep -qF "${prd}"; then
        RESOLVED_ISSUES+=("${prd}")
    fi
done <<< "${PREV_ISSUE_PRDS}"

# Regression: in new but not in previous
REGRESSION_ISSUES=()
while IFS= read -r prd; do
    [ -z "${prd}" ] && continue
    if ! echo "${PREV_ISSUE_PRDS}" | grep -qF "${prd}"; then
        REGRESSION_ISSUES+=("${prd}")
    fi
done <<< "${NEW_ISSUE_PRDS}"

# Remaining: in both previous and new
REMAINING_ISSUES=()
while IFS= read -r prd; do
    [ -z "${prd}" ] && continue
    if echo "${NEW_ISSUE_PRDS}" | grep -qF "${prd}"; then
        REMAINING_ISSUES+=("${prd}")
    fi
done <<< "${PREV_ISSUE_PRDS}"

# Also compare qualitative findings by reference field
PREV_QUAL_REFS=$(jq -r '[.qualitativeFindings[].reference] | sort | unique | .[]' \
    "${PREV_EVAL}" 2>/dev/null || true)
NEW_QUAL_REFS=$(jq -r '[.qualitativeFindings[].reference] | sort | unique | .[]' \
    "${NEW_EVAL}" 2>/dev/null || true)

RESOLVED_QUALITATIVE=()
while IFS= read -r ref; do
    [ -z "${ref}" ] && continue
    if ! echo "${NEW_QUAL_REFS}" | grep -qF "${ref}"; then
        RESOLVED_QUALITATIVE+=("${ref}")
    fi
done <<< "${PREV_QUAL_REFS}"

REGRESSION_QUALITATIVE=()
while IFS= read -r ref; do
    [ -z "${ref}" ] && continue
    if ! echo "${PREV_QUAL_REFS}" | grep -qF "${ref}"; then
        REGRESSION_QUALITATIVE+=("${ref}")
    fi
done <<< "${NEW_QUAL_REFS}"

REMAINING_QUALITATIVE=()
while IFS= read -r ref; do
    [ -z "${ref}" ] && continue
    if echo "${NEW_QUAL_REFS}" | grep -qF "${ref}"; then
        REMAINING_QUALITATIVE+=("${ref}")
    fi
done <<< "${PREV_QUAL_REFS}"

RESOLVED_COUNT=$(( ${#RESOLVED_ISSUES[@]} + ${#RESOLVED_QUALITATIVE[@]} ))
REGRESSION_COUNT=$(( ${#REGRESSION_ISSUES[@]} + ${#REGRESSION_QUALITATIVE[@]} ))
REMAINING_COUNT=$(( ${#REMAINING_ISSUES[@]} + ${#REMAINING_QUALITATIVE[@]} ))

info "  Resolved: ${RESOLVED_COUNT}"
info "  Regressions: ${REGRESSION_COUNT}"
info "  Remaining: ${REMAINING_COUNT}"

# ---------------------------------------------------------------------------
# Phase 3b: Registry-based regression detection (SA-3)
# ---------------------------------------------------------------------------

info "Phase 3b: Checking registry for historical regressions"

REINTRODUCED_REGRESSIONS=()
REINTRODUCED_DETAILS=()

if [ -f "${REGISTRY_FILE}" ] && jq . "${REGISTRY_FILE}" > /dev/null 2>&1; then
    REGISTRY_ENTRIES_COUNT=$(jq '.entries | length' "${REGISTRY_FILE}" 2>/dev/null || echo "0")

    if [ "${REGISTRY_ENTRIES_COUNT}" -gt 0 ]; then
        NEW_ISSUE_COUNT=$(jq '.issues | length' "${NEW_EVAL}" 2>/dev/null || echo "0")

        for i in $(seq 0 $((NEW_ISSUE_COUNT - 1))); do
            ISSUE_PRD=$(jq -r ".issues[$i].prdReference" "${NEW_EVAL}")
            ISSUE_CAPTURE=$(jq -r ".issues[$i].captureId" "${NEW_EVAL}")

            # Only check issues classified as regressions from previous-eval comparison.
            # Remaining issues have been continuously present -- not reintroduced.
            # Resolved issues are not in the new eval.
            is_regression=false
            for reg_prd in "${REGRESSION_ISSUES[@]+"${REGRESSION_ISSUES[@]}"}"; do
                if [ "${reg_prd}" = "${ISSUE_PRD}" ]; then
                    is_regression=true
                    break
                fi
            done
            if [ "${is_regression}" = false ]; then
                continue
            fi

            # Look up this captureId in the registry
            REGISTRY_ENTRY=$(jq -c --arg cid "${ISSUE_CAPTURE}" \
                '.entries[] | select(.captureId == $cid)' \
                "${REGISTRY_FILE}" 2>/dev/null) || true

            if [ -z "${REGISTRY_ENTRY}" ]; then
                continue
            fi

            # Scan all historical evaluations for this PRD reference with status "resolved"
            RESOLVED_MATCH=$(echo "${REGISTRY_ENTRY}" | jq -r \
                --arg prd "${ISSUE_PRD}" \
                '[.evaluations[].issues[] |
                 select(.prdReference == $prd and .status == "resolved")] |
                 sort_by(.resolvedAt) | last |
                 .resolvedAt // empty') || true

            if [ -n "${RESOLVED_MATCH}" ]; then
                info "  Reintroduced regression: ${ISSUE_PRD} (previously resolved at ${RESOLVED_MATCH})"

                # Extract current observation, severity, confidence from new eval
                CURRENT_OBS=$(jq -r --arg ref "${ISSUE_PRD}" \
                    '.issues[] | select(.prdReference == $ref) | .observation' \
                    "${NEW_EVAL}" | head -1)
                CURRENT_SEV=$(jq -r --arg ref "${ISSUE_PRD}" \
                    '.issues[] | select(.prdReference == $ref) | .severity' \
                    "${NEW_EVAL}" | head -1)
                CURRENT_CONF=$(jq -r --arg ref "${ISSUE_PRD}" \
                    '.issues[] | select(.prdReference == $ref) | .confidence' \
                    "${NEW_EVAL}" | head -1)

                REINTRODUCED_REGRESSIONS+=("${ISSUE_PRD}")
                REINTRODUCED_DETAILS+=("${ISSUE_PRD}|${RESOLVED_MATCH}|${CURRENT_OBS}|${CURRENT_SEV}|${CURRENT_CONF}")
            fi
        done
    fi
else
    info "  Registry missing or empty -- skipping historical regression check"
fi

# Reclassify: remove reintroduced regressions from REGRESSION_ISSUES
if [ ${#REINTRODUCED_REGRESSIONS[@]} -gt 0 ]; then
    NEW_REGRESSION_ISSUES=()
    for prd in "${REGRESSION_ISSUES[@]+"${REGRESSION_ISSUES[@]}"}"; do
        [ -z "${prd}" ] && continue
        is_reintroduced=false
        for reintro in "${REINTRODUCED_REGRESSIONS[@]}"; do
            if [ "${prd}" = "${reintro}" ]; then
                is_reintroduced=true
                break
            fi
        done
        if [ "${is_reintroduced}" = false ]; then
            NEW_REGRESSION_ISSUES+=("${prd}")
        fi
    done
    if [ ${#NEW_REGRESSION_ISSUES[@]} -eq 0 ]; then
        REGRESSION_ISSUES=()
    else
        REGRESSION_ISSUES=("${NEW_REGRESSION_ISSUES[@]}")
    fi
    REGRESSION_COUNT=$(( ${#REGRESSION_ISSUES[@]} + ${#REGRESSION_QUALITATIVE[@]} ))
fi

REINTRODUCED_COUNT=${#REINTRODUCED_REGRESSIONS[@]}

info "  Reintroduced regressions: ${REINTRODUCED_COUNT}"

# ---------------------------------------------------------------------------
# Phase 4: Build JSON arrays for the report
# ---------------------------------------------------------------------------

# Build resolved issues JSON
RESOLVED_JSON="["
first=true
for prd in "${RESOLVED_ISSUES[@]+"${RESOLVED_ISSUES[@]}"}"; do
    [ -z "${prd}" ] && continue
    if [ "${first}" = true ]; then first=false; else RESOLVED_JSON="${RESOLVED_JSON},"; fi
    RESOLVED_JSON="${RESOLVED_JSON}$(jq -cn --arg t "issue" --arg ref "${prd}" '{type: $t, reference: $ref}')"
done
for ref in "${RESOLVED_QUALITATIVE[@]+"${RESOLVED_QUALITATIVE[@]}"}"; do
    [ -z "${ref}" ] && continue
    if [ "${first}" = true ]; then first=false; else RESOLVED_JSON="${RESOLVED_JSON},"; fi
    RESOLVED_JSON="${RESOLVED_JSON}$(jq -cn --arg t "qualitative" --arg ref "${ref}" '{type: $t, reference: $ref}')"
done
RESOLVED_JSON="${RESOLVED_JSON}]"

# Build regression issues JSON
REGRESSION_JSON="["
first=true
for prd in "${REGRESSION_ISSUES[@]+"${REGRESSION_ISSUES[@]}"}"; do
    [ -z "${prd}" ] && continue
    if [ "${first}" = true ]; then first=false; else REGRESSION_JSON="${REGRESSION_JSON},"; fi
    # Get full issue details from new evaluation
    issue_detail=$(jq -c --arg ref "${prd}" '.issues[] | select(.prdReference == $ref) | {issueId, prdReference, observation, severity, confidence}' "${NEW_EVAL}" | head -1)
    REGRESSION_JSON="${REGRESSION_JSON}${issue_detail}"
done
for ref in "${REGRESSION_QUALITATIVE[@]+"${REGRESSION_QUALITATIVE[@]}"}"; do
    [ -z "${ref}" ] && continue
    if [ "${first}" = true ]; then first=false; else REGRESSION_JSON="${REGRESSION_JSON},"; fi
    finding_detail=$(jq -c --arg ref "${ref}" '.qualitativeFindings[] | select(.reference == $ref) | {findingId, reference, observation, severity, confidence}' "${NEW_EVAL}" | head -1)
    REGRESSION_JSON="${REGRESSION_JSON}${finding_detail}"
done
REGRESSION_JSON="${REGRESSION_JSON}]"

# Build remaining issues JSON
REMAINING_JSON="["
first=true
for prd in "${REMAINING_ISSUES[@]+"${REMAINING_ISSUES[@]}"}"; do
    [ -z "${prd}" ] && continue
    if [ "${first}" = true ]; then first=false; else REMAINING_JSON="${REMAINING_JSON},"; fi
    issue_detail=$(jq -c --arg ref "${prd}" '.issues[] | select(.prdReference == $ref) | {issueId, prdReference, observation, severity, confidence}' "${NEW_EVAL}" | head -1)
    REMAINING_JSON="${REMAINING_JSON}${issue_detail}"
done
for ref in "${REMAINING_QUALITATIVE[@]+"${REMAINING_QUALITATIVE[@]}"}"; do
    [ -z "${ref}" ] && continue
    if [ "${first}" = true ]; then first=false; else REMAINING_JSON="${REMAINING_JSON},"; fi
    finding_detail=$(jq -c --arg ref "${ref}" '.qualitativeFindings[] | select(.reference == $ref) | {findingId, reference, observation, severity, confidence}' "${NEW_EVAL}" | head -1)
    REMAINING_JSON="${REMAINING_JSON}${finding_detail}"
done
REMAINING_JSON="${REMAINING_JSON}]"

# Build reintroduced regressions JSON (SA-3)
REINTRODUCED_JSON="["
first=true
for detail in "${REINTRODUCED_DETAILS[@]+"${REINTRODUCED_DETAILS[@]}"}"; do
    [ -z "${detail}" ] && continue
    if [ "${first}" = true ]; then first=false; else REINTRODUCED_JSON="${REINTRODUCED_JSON},"; fi

    # Parse pipe-delimited detail: prdReference|previouslyResolvedAt|observation|severity|confidence
    ri_prd=$(echo "${detail}" | cut -d'|' -f1)
    ri_resolved_at=$(echo "${detail}" | cut -d'|' -f2)
    ri_observation=$(echo "${detail}" | cut -d'|' -f3)
    ri_severity=$(echo "${detail}" | cut -d'|' -f4)
    ri_confidence=$(echo "${detail}" | cut -d'|' -f5)

    REINTRODUCED_JSON="${REINTRODUCED_JSON}$(jq -cn \
        --arg prd "${ri_prd}" \
        --arg resolvedAt "${ri_resolved_at}" \
        --arg obs "${ri_observation}" \
        --arg sev "${ri_severity}" \
        --arg conf "${ri_confidence}" \
        '{prdReference: $prd, previouslyResolvedAt: $resolvedAt, currentObservation: $obs, severity: $sev, confidence: $conf}')"
done
REINTRODUCED_JSON="${REINTRODUCED_JSON}]"

# ---------------------------------------------------------------------------
# Phase 5: Write re-verification report
# ---------------------------------------------------------------------------

REVERIFY_REPORT="${REPORTS_DIR}/${TIMESTAMP_COMPACT}-reverification.json"

jq -n \
    --arg prevEvalId "${PREV_EVAL_ID}" \
    --arg newEvalId "${NEW_EVAL_ID}" \
    --arg ts "${TIMESTAMP}" \
    --argjson resolvedCount "${RESOLVED_COUNT}" \
    --argjson regressionCount "${REGRESSION_COUNT}" \
    --argjson remainingCount "${REMAINING_COUNT}" \
    --argjson reintroducedCount "${REINTRODUCED_COUNT}" \
    --argjson resolved "${RESOLVED_JSON}" \
    --argjson regressions "${REGRESSION_JSON}" \
    --argjson remaining "${REMAINING_JSON}" \
    --argjson reintroduced "${REINTRODUCED_JSON}" \
    '{
        previousEvaluationId: $prevEvalId,
        newEvaluationId: $newEvalId,
        timestamp: $ts,
        summary: {
            resolved: $resolvedCount,
            regressions: $regressionCount,
            remaining: $remainingCount,
            reintroducedRegressions: $reintroducedCount
        },
        resolvedIssues: $resolved,
        newRegressions: $regressions,
        remainingIssues: $remaining,
        reintroducedRegressions: $reintroduced
    }' > "${REVERIFY_REPORT}"

info "Re-verification report written to ${REVERIFY_REPORT}"

# ---------------------------------------------------------------------------
# Phase 6: Update registry
# ---------------------------------------------------------------------------

info "Updating registry"

# Ensure registry exists and is valid
if [ ! -f "${REGISTRY_FILE}" ] || ! jq . "${REGISTRY_FILE}" > /dev/null 2>&1; then
    info "  Registry missing or corrupt -- reinitializing"
    echo '{"version": 1, "entries": []}' > "${REGISTRY_FILE}"
fi

# Read new evaluation captures for imageHash lookup
MANIFEST="${VERIFICATION_DIR}/captures/manifest.json"

# Update registry entries for each capture in the new evaluation
if [ -f "${MANIFEST}" ]; then
    CAPTURE_COUNT=$(jq '.captures | length' "${MANIFEST}")
    for i in $(seq 0 $((CAPTURE_COUNT - 1))); do
        CAPTURE_ID=$(jq -r ".captures[$i].id" "${MANIFEST}")
        IMAGE_HASH=$(jq -r ".captures[$i].imageHash" "${MANIFEST}")

        # Determine issues for this capture
        CAPTURE_ISSUES=$(jq -c --arg cid "${CAPTURE_ID}" \
            '[.issues[] | select(.captureId == $cid) | {issueId, prdReference, severity}]' \
            "${NEW_EVAL}" 2>/dev/null || echo "[]")
        CAPTURE_FINDINGS=$(jq -c --arg cid "${CAPTURE_ID}" \
            '[.qualitativeFindings[] | select(.captureId == $cid) | {findingId, reference, severity}]' \
            "${NEW_EVAL}" 2>/dev/null || echo "[]")

        # Determine status for each issue (resolved, regressed, or remaining)
        ISSUES_WITH_STATUS="[]"
        for prd in "${RESOLVED_ISSUES[@]+"${RESOLVED_ISSUES[@]}"}"; do
            [ -z "${prd}" ] && continue
            ISSUES_WITH_STATUS=$(echo "${ISSUES_WITH_STATUS}" | jq -c \
                --arg prd "${prd}" --arg ts "${TIMESTAMP}" \
                --arg eid "${NEW_EVAL_ID}" \
                '. + [{prdReference: $prd, status: "resolved", resolvedAt: $ts, resolvedBy: $eid}]')
        done
        for prd in "${REMAINING_ISSUES[@]+"${REMAINING_ISSUES[@]}"}"; do
            [ -z "${prd}" ] && continue
            ISSUES_WITH_STATUS=$(echo "${ISSUES_WITH_STATUS}" | jq -c \
                --arg prd "${prd}" \
                '. + [{prdReference: $prd, status: "remaining"}]')
        done
        for prd in "${REGRESSION_ISSUES[@]+"${REGRESSION_ISSUES[@]}"}"; do
            [ -z "${prd}" ] && continue
            ISSUES_WITH_STATUS=$(echo "${ISSUES_WITH_STATUS}" | jq -c \
                --arg prd "${prd}" \
                '. + [{prdReference: $prd, status: "regressed"}]')
        done
        for prd in "${REINTRODUCED_REGRESSIONS[@]+"${REINTRODUCED_REGRESSIONS[@]}"}"; do
            [ -z "${prd}" ] && continue
            ISSUES_WITH_STATUS=$(echo "${ISSUES_WITH_STATUS}" | jq -c \
                --arg prd "${prd}" \
                '. + [{prdReference: $prd, status: "reintroduced"}]')
        done

        # Determine lastStatus based on new evaluation
        CAPTURE_ISSUE_COUNT=$(echo "${CAPTURE_ISSUES}" | jq 'length')
        CAPTURE_FINDING_COUNT=$(echo "${CAPTURE_FINDINGS}" | jq 'length')
        TOTAL_FOR_CAPTURE=$((CAPTURE_ISSUE_COUNT + CAPTURE_FINDING_COUNT))
        if [ "${TOTAL_FOR_CAPTURE}" -eq 0 ]; then
            LAST_STATUS="clean"
        else
            LAST_STATUS="issues"
        fi

        # Build the evaluation entry for this capture
        EVAL_ENTRY=$(jq -cn \
            --arg eid "${NEW_EVAL_ID}" \
            --arg ts "${TIMESTAMP}" \
            --argjson issues "${ISSUES_WITH_STATUS}" \
            '{evaluationId: $eid, timestamp: $ts, issues: $issues}')

        # Upsert into registry: find existing entry by captureId or create new
        EXISTING_IDX=$(jq --arg cid "${CAPTURE_ID}" \
            '[.entries[] | .captureId] | to_entries[] | select(.value == $cid) | .key' \
            "${REGISTRY_FILE}" 2>/dev/null | head -1) || true

        if [ -n "${EXISTING_IDX}" ]; then
            # Update existing entry
            REGISTRY_UPDATED=$(jq \
                --argjson idx "${EXISTING_IDX}" \
                --arg ih "${IMAGE_HASH}" \
                --argjson evalEntry "${EVAL_ENTRY}" \
                --arg ts "${TIMESTAMP}" \
                --arg status "${LAST_STATUS}" \
                '.entries[$idx].imageHash = $ih |
                 .entries[$idx].evaluations += [$evalEntry] |
                 .entries[$idx].lastEvaluated = $ts |
                 .entries[$idx].lastStatus = $status' \
                "${REGISTRY_FILE}")
            echo "${REGISTRY_UPDATED}" > "${REGISTRY_FILE}"
        else
            # Add new entry
            REGISTRY_UPDATED=$(jq \
                --arg ih "${IMAGE_HASH}" \
                --arg cid "${CAPTURE_ID}" \
                --argjson evalEntry "${EVAL_ENTRY}" \
                --arg ts "${TIMESTAMP}" \
                --arg status "${LAST_STATUS}" \
                '.entries += [{
                    imageHash: $ih,
                    captureId: $cid,
                    evaluations: [$evalEntry],
                    lastEvaluated: $ts,
                    lastStatus: $status
                }]' \
                "${REGISTRY_FILE}")
            echo "${REGISTRY_UPDATED}" > "${REGISTRY_FILE}"
        fi
    done
fi

info "Registry updated"

# ---------------------------------------------------------------------------
# Phase 7: Append audit trail
# ---------------------------------------------------------------------------

# Build resolved/regression/remaining/reintroduced ID arrays for audit
RESOLVED_IDS_JSON=$(echo "${RESOLVED_JSON}" | jq -c '[.[].reference]')
REGRESSION_IDS_JSON=$(echo "${REGRESSION_JSON}" | jq -c '[.[] | .prdReference // .reference]')
REMAINING_IDS_JSON=$(echo "${REMAINING_JSON}" | jq -c '[.[] | .prdReference // .reference]')
REINTRODUCED_IDS_JSON=$(echo "${REINTRODUCED_JSON}" | jq -c '[.[].prdReference]')

append_audit "$(jq -cn \
    --arg type "reVerification" \
    --arg ts "${TIMESTAMP}" \
    --arg prevEvalId "${PREV_EVAL_ID}" \
    --arg newEvalId "${NEW_EVAL_ID}" \
    --argjson resolvedIssues "${RESOLVED_IDS_JSON}" \
    --argjson newRegressions "${REGRESSION_IDS_JSON}" \
    --argjson remainingIssues "${REMAINING_IDS_JSON}" \
    --argjson reintroducedRegressions "${REINTRODUCED_IDS_JSON}" \
    '{type: $type, timestamp: $ts, previousEvaluationId: $prevEvalId, newEvaluationId: $newEvalId, resolvedIssues: $resolvedIssues, newRegressions: $newRegressions, remainingIssues: $remainingIssues, reintroducedRegressions: $reintroducedRegressions}')"

info "Audit trail entry appended"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

info "Re-verification complete"
echo "  Previous evaluation: ${PREV_EVAL_ID}"
echo "  New evaluation: ${NEW_EVAL_ID}"
echo "  Resolved: ${RESOLVED_COUNT}"
echo "  Regressions: ${REGRESSION_COUNT}"
echo "  Remaining: ${REMAINING_COUNT}"
echo "  Reintroduced regressions: ${REINTRODUCED_COUNT}"
echo "  Report: ${REVERIFY_REPORT}"

# Export key values for caller
echo ""
echo "RESOLVED=${RESOLVED_COUNT}"
echo "REGRESSIONS=${REGRESSION_COUNT}"
echo "REMAINING=${REMAINING_COUNT}"
echo "REINTRODUCED_REGRESSIONS=${REINTRODUCED_COUNT}"
echo "REVERIFICATION_REPORT=${REVERIFY_REPORT}"
echo "NEW_EVALUATION=${NEW_EVAL}"

# Exit with appropriate code
if [ "${REGRESSION_COUNT}" -gt 0 ] || [ "${REMAINING_COUNT}" -gt 0 ] || [ "${REINTRODUCED_COUNT}" -gt 0 ]; then
    exit 1
fi

exit 0
