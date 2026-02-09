#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# evaluate.sh -- Assemble evaluation context, check cache, invoke Claude Code
# for vision-based design evaluation of mkdn screenshots, and write reports.
#
# Usage:
#   scripts/visual-verification/evaluate.sh [--dry-run] [--batch-size N]
#                                           [--force-fresh]
#
# Reads manifest.json produced by capture.sh, assembles evaluation prompts
# from charter + PRD excerpts + evaluation criteria + output schema, groups
# captures into batches by fixture, and invokes Claude Code for vision
# evaluation.
#
# Output:
#   Evaluation report at .rp1/work/verification/reports/{timestamp}-evaluation.json
#   Cache entry at .rp1/work/verification/cache/{cacheKey}.json
#   Audit trail appended to .rp1/work/verification/audit.jsonl
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
VERIFICATION_DIR="${PROJECT_ROOT}/.rp1/work/verification"
CAPTURES_DIR="${VERIFICATION_DIR}/captures"
CACHE_DIR="${VERIFICATION_DIR}/cache"
REPORTS_DIR="${VERIFICATION_DIR}/reports"
PROMPTS_DIR="${SCRIPT_DIR}/prompts"
MANIFEST="${CAPTURES_DIR}/manifest.json"
AUDIT_FILE="${VERIFICATION_DIR}/audit.jsonl"

CHARTER_FILE="${PROJECT_ROOT}/.rp1/context/charter.md"

DRY_RUN=false
BATCH_SIZE=4
FORCE_FRESH=false

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TIMESTAMP_COMPACT=$(date -u +"%Y%m%d-%H%M%S")
EVAL_ID="eval-$(date -u +"%Y-%m-%d-%H%M%S")"

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

# Extract a markdown section by heading (## Title -> next ## or EOF)
extract_section() {
    local file="$1"
    local heading="$2"
    sed -n "/^## ${heading}/,/^## /{ /^## ${heading}/d; /^## /d; p; }" "${file}"
}

# Map fixture stem to PRD context file
fixture_prd_context() {
    local stem="$1"
    case "${stem}" in
        canonical)             echo "prd-context-spatial.md" ;;
        theme-tokens)          echo "prd-context-visual.md" ;;
        mermaid-focus)         echo "prd-context-mermaid.md" ;;
        geometry-calibration)  echo "prd-context-spatial.md" ;;
        *)                     echo "prd-context-spatial.md" ;;
    esac
}

# ---------------------------------------------------------------------------
# Parse flags
# ---------------------------------------------------------------------------

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --batch-size)
            shift
            BATCH_SIZE="${1:-4}"
            shift
            ;;
        --force-fresh)
            FORCE_FRESH=true
            shift
            ;;
        --help|-h)
            echo "Usage: evaluate.sh [--dry-run] [--batch-size N] [--force-fresh]"
            echo ""
            echo "Flags:"
            echo "  --dry-run       Assemble prompts and report what would be evaluated"
            echo "  --batch-size N  Max images per evaluation batch (default: 4)"
            echo "  --force-fresh   Bypass cache even for unchanged inputs"
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

info "Starting evaluation (${EVAL_ID})"

if [ ! -f "${MANIFEST}" ]; then
    error "manifest.json not found at ${MANIFEST}. Run capture.sh first."
fi

command -v jq > /dev/null 2>&1 || error "jq is required but not found"

mkdir -p "${CACHE_DIR}" "${REPORTS_DIR}"

# ---------------------------------------------------------------------------
# Phase 1: Read manifest
# ---------------------------------------------------------------------------

info "Reading manifest"

CAPTURE_COUNT=$(jq '.captures | length' "${MANIFEST}")
info "  ${CAPTURE_COUNT} captures in manifest"

# ---------------------------------------------------------------------------
# Phase 2: Compute cache key
# ---------------------------------------------------------------------------

info "Computing cache key"

# Image hashes from manifest (sorted)
IMAGE_HASHES=$(jq -r '.captures[].imageHash' "${MANIFEST}" | sort)

# Hash prompt template and related files
PROMPT_FILES_HASH=$(shasum -a 256 \
    "${PROMPTS_DIR}/evaluation-prompt.md" \
    "${PROMPTS_DIR}/output-schema.json" \
    "${PROMPTS_DIR}/prd-context-spatial.md" \
    "${PROMPTS_DIR}/prd-context-visual.md" \
    "${PROMPTS_DIR}/prd-context-mermaid.md" \
    2>/dev/null | awk '{print $1}' | sort | tr '\n' ' ')

# Hash charter
CHARTER_HASH=""
if [ -f "${CHARTER_FILE}" ]; then
    CHARTER_HASH=$(shasum -a 256 "${CHARTER_FILE}" | awk '{print $1}')
fi

# Hash source PRD files (the authoritative specs)
PRD_DIR="${PROJECT_ROOT}/.rp1/work/prds"
PRD_HASHES=""
for prd in spatial-design-language.md terminal-consistent-theming.md \
           syntax-highlighting.md mermaid-rendering.md cross-element-selection.md; do
    if [ -f "${PRD_DIR}/${prd}" ]; then
        PRD_HASHES="${PRD_HASHES}$(shasum -a 256 "${PRD_DIR}/${prd}" | awk '{print $1}') "
    fi
done
PRD_HASHES_SORTED=$(echo "${PRD_HASHES}" | tr ' ' '\n' | sort | tr '\n' ' ')

CACHE_INPUT="${IMAGE_HASHES} ${PROMPT_FILES_HASH} ${CHARTER_HASH} ${PRD_HASHES_SORTED}"
CACHE_KEY=$(echo "${CACHE_INPUT}" | shasum -a 256 | awk '{print $1}')
CACHE_FILE="${CACHE_DIR}/${CACHE_KEY}.json"

info "  Cache key: ${CACHE_KEY:0:16}..."

# ---------------------------------------------------------------------------
# Phase 3: Check cache
# ---------------------------------------------------------------------------

if [ "${FORCE_FRESH}" = false ] && [ -f "${CACHE_FILE}" ]; then
    info "Cache hit -- returning cached evaluation"

    REPORT_FILE="${REPORTS_DIR}/${TIMESTAMP_COMPACT}-evaluation.json"
    jq '.evaluation' "${CACHE_FILE}" > "${REPORT_FILE}"

    append_audit "$(jq -cn \
        --arg type "evaluation" \
        --arg ts "${TIMESTAMP}" \
        --arg eid "${EVAL_ID}" \
        --arg ph "sha256:${CACHE_KEY}" \
        --argjson count "${CAPTURE_COUNT}" \
        '{type: $type, timestamp: $ts, evaluationId: $eid, promptHash: $ph, captureCount: $count, cached: true}')"

    info "Report written to ${REPORT_FILE}"
    exit 0
fi

info "Cache miss -- proceeding with evaluation"

# ---------------------------------------------------------------------------
# Phase 4: Assemble evaluation prompt
# ---------------------------------------------------------------------------

info "Assembling evaluation prompt"

ASSEMBLED_PROMPT="${VERIFICATION_DIR}/current-prompt.md"

# Extract charter design philosophy
CHARTER_PHILOSOPHY=""
if [ -f "${CHARTER_FILE}" ]; then
    CHARTER_PHILOSOPHY=$(extract_section "${CHARTER_FILE}" "Design Philosophy")
fi
if [ -z "${CHARTER_PHILOSOPHY}" ]; then
    CHARTER_PHILOSOPHY="(Charter design philosophy not available)"
fi

# Read output schema
OUTPUT_SCHEMA=$(cat "${PROMPTS_DIR}/output-schema.json")

# Read evaluation prompt template
EVAL_TEMPLATE=$(cat "${PROMPTS_DIR}/evaluation-prompt.md")

# Build the base prompt (without PRD excerpts and capture context -- those are per-batch)
# We save the template parts for batch-specific assembly
echo "${EVAL_TEMPLATE}" > "${ASSEMBLED_PROMPT}.template"

info "  Charter design philosophy extracted"
info "  Output schema loaded"
info "  Evaluation template loaded"

# ---------------------------------------------------------------------------
# Phase 5: Group captures into batches by fixture
# ---------------------------------------------------------------------------

info "Grouping captures into batches"

# Extract unique fixture stems from manifest
FIXTURE_STEMS=$(jq -r '.captures[].fixture' "${MANIFEST}" | \
    sed 's/\.md$//' | sort -u)

declare -a BATCH_FIXTURES=()
declare -a BATCH_CAPTURE_IDS=()
declare -a BATCH_IMAGE_PATHS=()
declare -a BATCH_PRD_CONTEXTS=()

BATCH_NUM=0
for stem in ${FIXTURE_STEMS}; do
    # Get capture IDs and image paths for this fixture
    CAPTURE_IDS=$(jq -r --arg fx "${stem}.md" \
        '.captures[] | select(.fixture == $fx) | .id' "${MANIFEST}" | tr '\n' ',')
    CAPTURE_IDS="${CAPTURE_IDS%,}"  # trim trailing comma

    IMAGE_PATHS=$(jq -r --arg fx "${stem}.md" \
        '.captures[] | select(.fixture == $fx) | .imagePath' "${MANIFEST}" | tr '\n' '|')
    IMAGE_PATHS="${IMAGE_PATHS%|}"  # trim trailing pipe

    IMAGES_IN_BATCH=$(echo "${CAPTURE_IDS}" | tr ',' '\n' | wc -l | tr -d ' ')

    PRD_CTX=$(fixture_prd_context "${stem}")

    BATCH_FIXTURES+=("${stem}")
    BATCH_CAPTURE_IDS+=("${CAPTURE_IDS}")
    BATCH_IMAGE_PATHS+=("${IMAGE_PATHS}")
    BATCH_PRD_CONTEXTS+=("${PRD_CTX}")

    info "  Batch $((BATCH_NUM + 1)): ${stem} (${IMAGES_IN_BATCH} images, PRD: ${PRD_CTX})"
    BATCH_NUM=$((BATCH_NUM + 1))
done

TOTAL_BATCHES=${#BATCH_FIXTURES[@]}
info "  ${TOTAL_BATCHES} batches total"

# ---------------------------------------------------------------------------
# Phase 6: Dry-run mode
# ---------------------------------------------------------------------------

if [ "${DRY_RUN}" = true ]; then
    info "Dry-run mode -- no evaluation calls will be made"

    DRY_REPORT="${REPORTS_DIR}/${TIMESTAMP_COMPACT}-dryrun.json"

    # Build batch composition JSON array
    BATCH_JSON="["
    for i in $(seq 0 $((TOTAL_BATCHES - 1))); do
        IFS=',' read -ra IDS <<< "${BATCH_CAPTURE_IDS[$i]}"
        CAPTURES_JSON=$(printf '"%s",' "${IDS[@]}")
        CAPTURES_JSON="[${CAPTURES_JSON%,}]"

        if [ "$i" -gt 0 ]; then BATCH_JSON="${BATCH_JSON},"; fi
        BATCH_JSON="${BATCH_JSON}{\"batchId\":$((i + 1)),\"fixture\":\"${BATCH_FIXTURES[$i]}\",\"captures\":${CAPTURES_JSON},\"prdContext\":\"${BATCH_PRD_CONTEXTS[$i]}\",\"cached\":false}"
    done
    BATCH_JSON="${BATCH_JSON}]"

    # Extract first 500 chars of prompt template for preview
    PROMPT_PREVIEW=$(head -c 500 "${PROMPTS_DIR}/evaluation-prompt.md" | tr '\n' ' ' | tr '"' "'")

    jq -n \
        --argjson dryRun true \
        --argjson capturesProduced "${CAPTURE_COUNT}" \
        --argjson batchComposition "${BATCH_JSON}" \
        --argjson estimatedApiCalls "${TOTAL_BATCHES}" \
        --argjson cachedBatches 0 \
        --arg promptPreview "${PROMPT_PREVIEW}" \
        '{
            dryRun: $dryRun,
            capturesProduced: $capturesProduced,
            batchComposition: $batchComposition,
            estimatedApiCalls: $estimatedApiCalls,
            cachedBatches: $cachedBatches,
            promptPreview: $promptPreview
        }' > "${DRY_REPORT}"

    info "Dry-run report written to ${DRY_REPORT}"
    exit 0
fi

# ---------------------------------------------------------------------------
# Phase 7: Vision evaluation (per batch)
# ---------------------------------------------------------------------------

command -v claude > /dev/null 2>&1 || \
    error "claude CLI not found. Install Claude Code to perform vision evaluation."

info "Starting vision evaluation (${TOTAL_BATCHES} batches)"

BATCH_RESULTS_DIR=$(mktemp -d)
trap "rm -rf '${BATCH_RESULTS_DIR}'" EXIT

for i in $(seq 0 $((TOTAL_BATCHES - 1))); do
    BATCH_IDX=$((i + 1))
    FIXTURE_STEM="${BATCH_FIXTURES[$i]}"
    PRD_CTX_FILE="${BATCH_PRD_CONTEXTS[$i]}"

    info "Evaluating batch ${BATCH_IDX}/${TOTAL_BATCHES}: ${FIXTURE_STEM}"

    # Read PRD context for this batch
    PRD_EXCERPTS=$(cat "${PROMPTS_DIR}/${PRD_CTX_FILE}")

    # Build capture context (which images are in this batch)
    IFS='|' read -ra IMG_PATHS <<< "${BATCH_IMAGE_PATHS[$i]}"
    IFS=',' read -ra CAP_IDS <<< "${BATCH_CAPTURE_IDS[$i]}"

    CAPTURE_CONTEXT="This batch evaluates the **${FIXTURE_STEM}** fixture across themes."
    CAPTURE_CONTEXT="${CAPTURE_CONTEXT}\n\nCaptures in this batch:"
    for j in "${!CAP_IDS[@]}"; do
        REL_PATH="${IMG_PATHS[$j]}"
        ABS_PATH="${PROJECT_ROOT}/${REL_PATH}"
        CAPTURE_CONTEXT="${CAPTURE_CONTEXT}\n- **${CAP_IDS[$j]}**: \`${ABS_PATH}\`"
    done

    # Assemble the full batch prompt by replacing placeholders
    BATCH_PROMPT=$(cat "${PROMPTS_DIR}/evaluation-prompt.md")
    BATCH_PROMPT="${BATCH_PROMPT//\{charter_design_philosophy\}/${CHARTER_PHILOSOPHY}}"
    BATCH_PROMPT="${BATCH_PROMPT//\{prd_excerpts\}/${PRD_EXCERPTS}}"
    BATCH_PROMPT="${BATCH_PROMPT//\{output_schema\}/${OUTPUT_SCHEMA}}"
    BATCH_PROMPT="${BATCH_PROMPT//\{capture_context\}/$(echo -e "${CAPTURE_CONTEXT}")}"

    # Determine output path for this batch
    BATCH_OUTPUT="${BATCH_RESULTS_DIR}/batch-${BATCH_IDX}.json"

    # Write the evaluation task file
    BATCH_TASK="${BATCH_RESULTS_DIR}/batch-${BATCH_IDX}-task.md"
    cat > "${BATCH_TASK}" <<TASK_EOF
You are performing a vision-based design evaluation of mkdn screenshots.

## Instructions

1. Read each of the following image files (they are PNG screenshots):
$(for j in "${!CAP_IDS[@]}"; do
    echo "   - ${PROJECT_ROOT}/${IMG_PATHS[$j]}"
done)

2. Evaluate the screenshots against the design specifications below.

3. Write your evaluation result as a single JSON object to this file:
   ${BATCH_OUTPUT}

   The JSON must conform to the output schema in the evaluation prompt below.
   Write ONLY valid JSON to that file -- no markdown fences, no commentary.

4. Use evaluationId: "${EVAL_ID}"

5. For the captures array, use these capture IDs and image hashes from the manifest:
$(for j in "${!CAP_IDS[@]}"; do
    CAP_ID="${CAP_IDS[$j]}"
    IMG_HASH=$(jq -r --arg cid "${CAP_ID}" '.captures[] | select(.id == $cid) | .imageHash' "${MANIFEST}")
    echo "   - captureId: \"${CAP_ID}\", imageHash: \"${IMG_HASH}\""
done)

## Evaluation Prompt

${BATCH_PROMPT}
TASK_EOF

    # Invoke Claude Code for vision evaluation
    if ! claude -p "$(cat "${BATCH_TASK}")" --allowedTools "Read,Write" > /dev/null 2>&1; then
        error "Claude Code evaluation failed for batch ${BATCH_IDX} (${FIXTURE_STEM})"
    fi

    # Verify output was produced
    if [ ! -f "${BATCH_OUTPUT}" ]; then
        error "Vision evaluation did not produce output for batch ${BATCH_IDX} (${FIXTURE_STEM})"
    fi

    # Validate JSON
    if ! jq . "${BATCH_OUTPUT}" > /dev/null 2>&1; then
        error "Vision evaluation output is not valid JSON for batch ${BATCH_IDX} (${FIXTURE_STEM})"
    fi

    info "  Batch ${BATCH_IDX} evaluation complete"
done

# ---------------------------------------------------------------------------
# Phase 8: Merge batch results
# ---------------------------------------------------------------------------

info "Merging batch results"

PROMPT_HASH="sha256:${CACHE_KEY}"

# Merge all batch results into a single evaluation
# Collect all captures, issues, and qualitative findings across batches
ALL_CAPTURES="[]"
ALL_ISSUES="[]"
ALL_QUALITATIVE="[]"

for i in $(seq 1 "${TOTAL_BATCHES}"); do
    BATCH_FILE="${BATCH_RESULTS_DIR}/batch-${i}.json"

    BATCH_CAPTURES=$(jq -c '.captures // []' "${BATCH_FILE}" 2>/dev/null || echo "[]")
    BATCH_ISSUES=$(jq -c '.issues // []' "${BATCH_FILE}" 2>/dev/null || echo "[]")
    BATCH_QUALITATIVE=$(jq -c '.qualitativeFindings // []' "${BATCH_FILE}" 2>/dev/null || echo "[]")

    ALL_CAPTURES=$(echo "${ALL_CAPTURES}" "${BATCH_CAPTURES}" | jq -s 'add')
    ALL_ISSUES=$(echo "${ALL_ISSUES}" "${BATCH_ISSUES}" | jq -s 'add')
    ALL_QUALITATIVE=$(echo "${ALL_QUALITATIVE}" "${BATCH_QUALITATIVE}" | jq -s 'add')
done

# Count totals
TOTAL_CAPTURES_EVAL=$(echo "${ALL_CAPTURES}" | jq 'length')
TOTAL_ISSUES=$(echo "${ALL_ISSUES}" | jq 'length')
TOTAL_QUALITATIVE=$(echo "${ALL_QUALITATIVE}" | jq 'length')

# Count by severity and confidence
SEV_CRITICAL=$(echo "${ALL_ISSUES}" "${ALL_QUALITATIVE}" | jq -s 'add | map(select(.severity == "critical")) | length')
SEV_MAJOR=$(echo "${ALL_ISSUES}" "${ALL_QUALITATIVE}" | jq -s 'add | map(select(.severity == "major")) | length')
SEV_MINOR=$(echo "${ALL_ISSUES}" "${ALL_QUALITATIVE}" | jq -s 'add | map(select(.severity == "minor")) | length')
CONF_HIGH=$(echo "${ALL_ISSUES}" "${ALL_QUALITATIVE}" | jq -s 'add | map(select(.confidence == "high")) | length')
CONF_MEDIUM=$(echo "${ALL_ISSUES}" "${ALL_QUALITATIVE}" | jq -s 'add | map(select(.confidence == "medium")) | length')
CONF_LOW=$(echo "${ALL_ISSUES}" "${ALL_QUALITATIVE}" | jq -s 'add | map(select(.confidence == "low")) | length')

# Build the merged evaluation report
REPORT_FILE="${REPORTS_DIR}/${TIMESTAMP_COMPACT}-evaluation.json"

jq -n \
    --arg eid "${EVAL_ID}" \
    --arg ph "${PROMPT_HASH}" \
    --argjson captures "${ALL_CAPTURES}" \
    --argjson issues "${ALL_ISSUES}" \
    --argjson qualitative "${ALL_QUALITATIVE}" \
    --argjson totalCaptures "${TOTAL_CAPTURES_EVAL}" \
    --argjson issuesDetected "${TOTAL_ISSUES}" \
    --argjson qualitativeCount "${TOTAL_QUALITATIVE}" \
    --argjson sevCritical "${SEV_CRITICAL}" \
    --argjson sevMajor "${SEV_MAJOR}" \
    --argjson sevMinor "${SEV_MINOR}" \
    --argjson confHigh "${CONF_HIGH}" \
    --argjson confMedium "${CONF_MEDIUM}" \
    --argjson confLow "${CONF_LOW}" \
    '{
        evaluationId: $eid,
        promptHash: $ph,
        captures: $captures,
        issues: $issues,
        qualitativeFindings: $qualitative,
        summary: {
            totalCaptures: $totalCaptures,
            issuesDetected: $issuesDetected,
            qualitativeFindings: $qualitativeCount,
            bySeverity: {
                critical: $sevCritical,
                major: $sevMajor,
                minor: $sevMinor
            },
            byConfidence: {
                high: $confHigh,
                medium: $confMedium,
                low: $confLow
            }
        }
    }' > "${REPORT_FILE}"

info "Evaluation report written to ${REPORT_FILE}"

# ---------------------------------------------------------------------------
# Phase 9: Populate cache
# ---------------------------------------------------------------------------

info "Populating cache"

IMAGE_HASHES_JSON=$(jq -c '[.captures[].imageHash]' "${MANIFEST}")
PROMPT_TEMPLATE_HASH=$(shasum -a 256 "${PROMPTS_DIR}/evaluation-prompt.md" | awk '{print $1}')
PRD_CONTENT_HASHES_JSON="["
PRD_FIRST=true
for prd in spatial-design-language.md terminal-consistent-theming.md \
           syntax-highlighting.md mermaid-rendering.md cross-element-selection.md; do
    if [ -f "${PRD_DIR}/${prd}" ]; then
        H=$(shasum -a 256 "${PRD_DIR}/${prd}" | awk '{print $1}')
        if [ "${PRD_FIRST}" = true ]; then PRD_FIRST=false; else PRD_CONTENT_HASHES_JSON="${PRD_CONTENT_HASHES_JSON},"; fi
        PRD_CONTENT_HASHES_JSON="${PRD_CONTENT_HASHES_JSON}\"sha256:${H}\""
    fi
done
PRD_CONTENT_HASHES_JSON="${PRD_CONTENT_HASHES_JSON}]"

jq -n \
    --arg ck "sha256:${CACHE_KEY}" \
    --arg ts "${TIMESTAMP}" \
    --argjson images "${IMAGE_HASHES_JSON}" \
    --arg promptTemplate "sha256:${PROMPT_TEMPLATE_HASH}" \
    --argjson prdContents "${PRD_CONTENT_HASHES_JSON}" \
    --argjson evaluation "$(cat "${REPORT_FILE}")" \
    '{
        cacheKey: $ck,
        createdAt: $ts,
        inputHashes: {
            images: $images,
            promptTemplate: $promptTemplate,
            prdContents: $prdContents
        },
        evaluation: $evaluation
    }' > "${CACHE_FILE}"

info "  Cached as ${CACHE_KEY:0:16}..."

# ---------------------------------------------------------------------------
# Phase 10: Append audit trail
# ---------------------------------------------------------------------------

CAPTURE_IDS_JSON=$(jq -c '[.captures[].id]' "${MANIFEST}")
TOTAL_ISSUE_COUNT=$((TOTAL_ISSUES + TOTAL_QUALITATIVE))

append_audit "$(jq -cn \
    --arg type "evaluation" \
    --arg ts "${TIMESTAMP}" \
    --arg eid "${EVAL_ID}" \
    --arg ph "${PROMPT_HASH}" \
    --argjson captureIds "${CAPTURE_IDS_JSON}" \
    --argjson issueCount "${TOTAL_ISSUE_COUNT}" \
    --argjson cached false \
    '{type: $type, timestamp: $ts, evaluationId: $eid, promptHash: $ph, captureIds: $captureIds, issueCount: $issueCount, cached: $cached}')"

info "Audit trail entry appended"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

info "Evaluation complete"
echo "  Evaluation ID: ${EVAL_ID}"
echo "  Captures: ${TOTAL_CAPTURES_EVAL}"
echo "  Issues: ${TOTAL_ISSUES}"
echo "  Qualitative findings: ${TOTAL_QUALITATIVE}"
echo "  Severity: ${SEV_CRITICAL} critical, ${SEV_MAJOR} major, ${SEV_MINOR} minor"
echo "  Confidence: ${CONF_HIGH} high, ${CONF_MEDIUM} medium, ${CONF_LOW} low"
echo "  Report: ${REPORT_FILE}"

exit 0
