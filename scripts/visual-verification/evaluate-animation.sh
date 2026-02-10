#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# evaluate-animation.sh -- Evaluate animation frame sequences via LLM vision.
#
# Usage:
#   scripts/visual-verification/evaluate-animation.sh [--dry-run]
#       [--batch-size N] [--force-fresh] [--frames-per-sequence N]
#
# Reads manifest.json produced by AnimationVisionCaptureTests, groups
# frame sequences by fixture, selects representative frames (~8-10 per
# sequence), assembles prompts with the animation PRD context, and
# invokes Claude Code for vision evaluation.
#
# Output:
#   Evaluation report at .rp1/work/verification/reports/{timestamp}-animation-evaluation.json
#   Cache entry at .rp1/work/verification/cache/{cacheKey}.json
#   Audit trail appended to .rp1/work/verification/audit.jsonl
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
VERIFICATION_DIR="${PROJECT_ROOT}/.rp1/work/verification"
CAPTURES_DIR="${VERIFICATION_DIR}/captures/animation"
CACHE_DIR="${VERIFICATION_DIR}/cache"
REPORTS_DIR="${VERIFICATION_DIR}/reports"
PROMPTS_DIR="${SCRIPT_DIR}/prompts"
MANIFEST="${CAPTURES_DIR}/manifest.json"
AUDIT_FILE="${VERIFICATION_DIR}/audit.jsonl"

DRY_RUN=false
BATCH_SIZE=4
FORCE_FRESH=false
FRAMES_PER_SEQ=10

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TIMESTAMP_COMPACT=$(date -u +"%Y%m%d-%H%M%S")
EVAL_ID="anim-eval-$(date -u +"%Y-%m-%d-%H%M%S")"

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

# Select representative frame indices from a sequence.
# Strategy: first frame, frames at ~0.1s intervals through 1.5s, final frame.
# Args: $1 = total frame count, $2 = fps, $3 = max frames to select
select_representative_frames() {
    local total="$1"
    local fps="$2"
    local max_frames="$3"

    if [ "${total}" -le "${max_frames}" ]; then
        seq 0 $((total - 1))
        return
    fi

    local -a indices=()
    # First frame
    indices+=(0)

    # Frames at 0.1s intervals from 0.1s to 1.5s
    for ms in 100 200 300 400 500 700 1000 1500; do
        local frame_idx=$(( (ms * fps) / 1000 ))
        if [ "${frame_idx}" -ge "${total}" ]; then
            frame_idx=$((total - 1))
        fi
        indices+=("${frame_idx}")
    done

    # Final frame
    indices+=("$((total - 1))")

    # Deduplicate and sort, then take up to max_frames
    printf '%s\n' "${indices[@]}" | sort -n -u | head -n "${max_frames}"
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
        --frames-per-sequence)
            shift
            FRAMES_PER_SEQ="${1:-10}"
            shift
            ;;
        --help|-h)
            echo "Usage: evaluate-animation.sh [--dry-run] [--batch-size N] [--force-fresh] [--frames-per-sequence N]"
            echo ""
            echo "Flags:"
            echo "  --dry-run                Assemble prompts and report what would be evaluated"
            echo "  --batch-size N           Max sequences per evaluation batch (default: 4)"
            echo "  --force-fresh            Bypass cache even for unchanged inputs"
            echo "  --frames-per-sequence N  Representative frames per sequence (default: 10)"
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

info "Starting animation evaluation (${EVAL_ID})"

if [ ! -f "${MANIFEST}" ]; then
    error "manifest.json not found at ${MANIFEST}. Run AnimationVisionCaptureTests first."
fi

command -v jq > /dev/null 2>&1 || error "jq is required but not found"

mkdir -p "${CACHE_DIR}" "${REPORTS_DIR}"

# ---------------------------------------------------------------------------
# Phase 1: Read manifest
# ---------------------------------------------------------------------------

info "Reading animation manifest"

SEQUENCE_COUNT=$(jq '.sequences | length' "${MANIFEST}")
info "  ${SEQUENCE_COUNT} sequences in manifest"

# ---------------------------------------------------------------------------
# Phase 2: Compute cache key
# ---------------------------------------------------------------------------

info "Computing cache key"

# Hash representative frame hashes from manifest
FRAME_HASHES=$(jq -r '.sequences[].frameHashes[]' "${MANIFEST}" | sort | head -100)

# Hash prompt template and animation PRD context
PROMPT_FILES_HASH=$(shasum -a 256 \
    "${PROMPTS_DIR}/evaluation-prompt.md" \
    "${PROMPTS_DIR}/output-schema.json" \
    "${PROMPTS_DIR}/prd-context-animation.md" \
    2>/dev/null | awk '{print $1}' | sort | tr '\n' ' ')

CACHE_INPUT="${FRAME_HASHES} ${PROMPT_FILES_HASH}"
CACHE_KEY=$(echo "${CACHE_INPUT}" | shasum -a 256 | awk '{print $1}')
CACHE_FILE="${CACHE_DIR}/${CACHE_KEY}.json"

info "  Cache key: ${CACHE_KEY:0:16}..."

# ---------------------------------------------------------------------------
# Phase 3: Check cache
# ---------------------------------------------------------------------------

if [ "${FORCE_FRESH}" = false ] && [ -f "${CACHE_FILE}" ]; then
    info "Cache hit -- returning cached evaluation"

    REPORT_FILE="${REPORTS_DIR}/${TIMESTAMP_COMPACT}-animation-evaluation.json"
    jq '.evaluation' "${CACHE_FILE}" > "${REPORT_FILE}"

    append_audit "$(jq -cn \
        --arg type "animation-evaluation" \
        --arg ts "${TIMESTAMP}" \
        --arg eid "${EVAL_ID}" \
        --arg ph "sha256:${CACHE_KEY}" \
        --argjson count "${SEQUENCE_COUNT}" \
        '{type: $type, timestamp: $ts, evaluationId: $eid, promptHash: $ph, sequenceCount: $count, cached: true}')"

    info "Report written to ${REPORT_FILE}"
    exit 0
fi

info "Cache miss -- proceeding with evaluation"

# ---------------------------------------------------------------------------
# Phase 4: Group sequences into batches by fixture
# ---------------------------------------------------------------------------

info "Grouping sequences into batches by fixture"

FIXTURE_STEMS=$(jq -r '.sequences[].fixture' "${MANIFEST}" | \
    sed 's/\.md$//' | sort -u)

declare -a BATCH_FIXTURES=()
declare -a BATCH_SEQ_IDS=()
declare -a BATCH_FRAME_DIRS=()

BATCH_NUM=0
for stem in ${FIXTURE_STEMS}; do
    SEQ_IDS=$(jq -r --arg fx "${stem}.md" \
        '.sequences[] | select(.fixture == $fx) | .id' "${MANIFEST}" | tr '\n' ',')
    SEQ_IDS="${SEQ_IDS%,}"

    FRAME_DIRS=$(jq -r --arg fx "${stem}.md" \
        '.sequences[] | select(.fixture == $fx) | .frameDir' "${MANIFEST}" | tr '\n' '|')
    FRAME_DIRS="${FRAME_DIRS%|}"

    SEQS_IN_BATCH=$(echo "${SEQ_IDS}" | tr ',' '\n' | wc -l | tr -d ' ')

    BATCH_FIXTURES+=("${stem}")
    BATCH_SEQ_IDS+=("${SEQ_IDS}")
    BATCH_FRAME_DIRS+=("${FRAME_DIRS}")

    info "  Batch $((BATCH_NUM + 1)): ${stem} (${SEQS_IN_BATCH} sequences)"
    BATCH_NUM=$((BATCH_NUM + 1))
done

TOTAL_BATCHES=${#BATCH_FIXTURES[@]}
info "  ${TOTAL_BATCHES} batches total"

# ---------------------------------------------------------------------------
# Phase 5: Dry-run mode
# ---------------------------------------------------------------------------

if [ "${DRY_RUN}" = true ]; then
    info "Dry-run mode -- no evaluation calls will be made"

    DRY_REPORT="${REPORTS_DIR}/${TIMESTAMP_COMPACT}-animation-dryrun.json"

    BATCH_JSON="["
    for i in $(seq 0 $((TOTAL_BATCHES - 1))); do
        IFS=',' read -ra IDS <<< "${BATCH_SEQ_IDS[$i]}"
        SEQS_JSON=$(printf '"%s",' "${IDS[@]}")
        SEQS_JSON="[${SEQS_JSON%,}]"

        if [ "$i" -gt 0 ]; then BATCH_JSON="${BATCH_JSON},"; fi
        BATCH_JSON="${BATCH_JSON}{\"batchId\":$((i + 1)),\"fixture\":\"${BATCH_FIXTURES[$i]}\",\"sequences\":${SEQS_JSON},\"cached\":false}"
    done
    BATCH_JSON="${BATCH_JSON}]"

    jq -n \
        --argjson dryRun true \
        --argjson sequencesProduced "${SEQUENCE_COUNT}" \
        --argjson batchComposition "${BATCH_JSON}" \
        --argjson estimatedApiCalls "${TOTAL_BATCHES}" \
        --argjson framesPerSequence "${FRAMES_PER_SEQ}" \
        '{
            dryRun: $dryRun,
            sequencesProduced: $sequencesProduced,
            batchComposition: $batchComposition,
            estimatedApiCalls: $estimatedApiCalls,
            framesPerSequence: $framesPerSequence
        }' > "${DRY_REPORT}"

    info "Dry-run report written to ${DRY_REPORT}"
    exit 0
fi

# ---------------------------------------------------------------------------
# Phase 6: Vision evaluation (per batch)
# ---------------------------------------------------------------------------

command -v claude > /dev/null 2>&1 || \
    error "claude CLI not found. Install Claude Code to perform vision evaluation."

info "Starting animation vision evaluation (${TOTAL_BATCHES} batches)"

BATCH_RESULTS_DIR=$(mktemp -d)
trap "rm -rf '${BATCH_RESULTS_DIR}'" EXIT

# Read PRD context and output schema once
PRD_CONTEXT=$(cat "${PROMPTS_DIR}/prd-context-animation.md")
OUTPUT_SCHEMA=$(cat "${PROMPTS_DIR}/output-schema.json")
EVAL_TEMPLATE=$(cat "${PROMPTS_DIR}/evaluation-prompt.md")

for i in $(seq 0 $((TOTAL_BATCHES - 1))); do
    BATCH_IDX=$((i + 1))
    FIXTURE_STEM="${BATCH_FIXTURES[$i]}"

    info "Evaluating batch ${BATCH_IDX}/${TOTAL_BATCHES}: ${FIXTURE_STEM}"

    # Build capture context with representative frames for each sequence
    IFS='|' read -ra DIR_PATHS <<< "${BATCH_FRAME_DIRS[$i]}"
    IFS=',' read -ra SEQ_IDS <<< "${BATCH_SEQ_IDS[$i]}"

    CAPTURE_CONTEXT="This batch evaluates the **${FIXTURE_STEM}** animation fixture across themes."
    CAPTURE_CONTEXT="${CAPTURE_CONTEXT}\n\nFrame sequences in this batch:"

    FRAME_FILE_LIST=""

    for j in "${!SEQ_IDS[@]}"; do
        SEQ_ID="${SEQ_IDS[$j]}"
        REL_DIR="${DIR_PATHS[$j]}"
        ABS_DIR="${PROJECT_ROOT}/${REL_DIR}"

        # Get sequence metadata from manifest
        FRAME_COUNT=$(jq -r --arg sid "${SEQ_ID}" \
            '.sequences[] | select(.id == $sid) | .frameCount' "${MANIFEST}")
        SEQ_FPS=$(jq -r --arg sid "${SEQ_ID}" \
            '.sequences[] | select(.id == $sid) | .fps' "${MANIFEST}")

        CAPTURE_CONTEXT="${CAPTURE_CONTEXT}\n- **${SEQ_ID}**: ${FRAME_COUNT} frames at ${SEQ_FPS}fps in \`${ABS_DIR}\`"

        # Select representative frames
        REP_INDICES=$(select_representative_frames "${FRAME_COUNT}" "${SEQ_FPS}" "${FRAMES_PER_SEQ}")

        CAPTURE_CONTEXT="${CAPTURE_CONTEXT}\n  Representative frames (indices):"
        for idx in ${REP_INDICES}; do
            FRAME_NUM=$((idx + 1))
            FRAME_FILE=$(printf "frame_%04d.png" "${FRAME_NUM}")
            FRAME_PATH="${ABS_DIR}/${FRAME_FILE}"
            TIME_SEC=$(echo "scale=3; ${idx} / ${SEQ_FPS}" | bc 2>/dev/null || echo "0")
            CAPTURE_CONTEXT="${CAPTURE_CONTEXT}\n  - Frame ${idx} (t=${TIME_SEC}s): \`${FRAME_PATH}\`"
            FRAME_FILE_LIST="${FRAME_FILE_LIST}   - ${FRAME_PATH}\n"
        done
    done

    # Assemble the full batch prompt
    BATCH_PROMPT="${EVAL_TEMPLATE}"
    BATCH_PROMPT="${BATCH_PROMPT//\{charter_design_philosophy\}/(See animation PRD context below)}"
    BATCH_PROMPT="${BATCH_PROMPT//\{prd_excerpts\}/${PRD_CONTEXT}}"
    BATCH_PROMPT="${BATCH_PROMPT//\{output_schema\}/${OUTPUT_SCHEMA}}"
    BATCH_PROMPT="${BATCH_PROMPT//\{capture_context\}/$(echo -e "${CAPTURE_CONTEXT}")}"

    BATCH_OUTPUT="${BATCH_RESULTS_DIR}/batch-${BATCH_IDX}.json"

    # Build sequence hash info for the task file
    SEQ_HASH_INFO=""
    for j in "${!SEQ_IDS[@]}"; do
        SEQ_ID="${SEQ_IDS[$j]}"
        FIRST_HASH=$(jq -r --arg sid "${SEQ_ID}" \
            '.sequences[] | select(.id == $sid) | .frameHashes[0] // "unknown"' "${MANIFEST}")
        SEQ_HASH_INFO="${SEQ_HASH_INFO}   - sequenceId: \"${SEQ_ID}\", firstFrameHash: \"${FIRST_HASH}\"\n"
    done

    BATCH_TASK="${BATCH_RESULTS_DIR}/batch-${BATCH_IDX}-task.md"
    cat > "${BATCH_TASK}" <<TASK_EOF
You are performing a vision-based animation evaluation of mkdn frame sequences.

## Instructions

1. Read each of the following image files (they are PNG frames from animation captures):
$(echo -e "${FRAME_FILE_LIST}")

2. Evaluate the frame sequences against the animation design specifications below.
   Focus on: fade-in opacity transitions, stagger cascade visibility, code block
   cover layer color correctness, and animation completion timing.

3. Write your evaluation result as a single JSON object to this file:
   ${BATCH_OUTPUT}

   The JSON must conform to the output schema in the evaluation prompt below.
   Write ONLY valid JSON to that file -- no markdown fences, no commentary.

4. Use evaluationId: "${EVAL_ID}"

5. For the captures array, use these sequence IDs:
$(echo -e "${SEQ_HASH_INFO}")

## Evaluation Prompt

${BATCH_PROMPT}
TASK_EOF

    if ! claude -p "$(cat "${BATCH_TASK}")" --allowedTools "Read,Write" > /dev/null 2>&1; then
        error "Claude Code evaluation failed for batch ${BATCH_IDX} (${FIXTURE_STEM})"
    fi

    if [ ! -f "${BATCH_OUTPUT}" ]; then
        error "Vision evaluation did not produce output for batch ${BATCH_IDX} (${FIXTURE_STEM})"
    fi

    if ! jq . "${BATCH_OUTPUT}" > /dev/null 2>&1; then
        error "Vision evaluation output is not valid JSON for batch ${BATCH_IDX} (${FIXTURE_STEM})"
    fi

    info "  Batch ${BATCH_IDX} evaluation complete"
done

# ---------------------------------------------------------------------------
# Phase 7: Merge batch results
# ---------------------------------------------------------------------------

info "Merging batch results"

PROMPT_HASH="sha256:${CACHE_KEY}"

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

TOTAL_CAPTURES_EVAL=$(echo "${ALL_CAPTURES}" | jq 'length')
TOTAL_ISSUES=$(echo "${ALL_ISSUES}" | jq 'length')
TOTAL_QUALITATIVE=$(echo "${ALL_QUALITATIVE}" | jq 'length')

SEV_CRITICAL=$(echo "${ALL_ISSUES}" "${ALL_QUALITATIVE}" | jq -s 'add | map(select(.severity == "critical")) | length')
SEV_MAJOR=$(echo "${ALL_ISSUES}" "${ALL_QUALITATIVE}" | jq -s 'add | map(select(.severity == "major")) | length')
SEV_MINOR=$(echo "${ALL_ISSUES}" "${ALL_QUALITATIVE}" | jq -s 'add | map(select(.severity == "minor")) | length')
CONF_HIGH=$(echo "${ALL_ISSUES}" "${ALL_QUALITATIVE}" | jq -s 'add | map(select(.confidence == "high")) | length')
CONF_MEDIUM=$(echo "${ALL_ISSUES}" "${ALL_QUALITATIVE}" | jq -s 'add | map(select(.confidence == "medium")) | length')
CONF_LOW=$(echo "${ALL_ISSUES}" "${ALL_QUALITATIVE}" | jq -s 'add | map(select(.confidence == "low")) | length')

REPORT_FILE="${REPORTS_DIR}/${TIMESTAMP_COMPACT}-animation-evaluation.json"

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
# Phase 8: Populate cache
# ---------------------------------------------------------------------------

info "Populating cache"

FRAME_HASHES_JSON=$(jq -c '[.sequences[] | .frameHashes[0]]' "${MANIFEST}")
PROMPT_TEMPLATE_HASH=$(shasum -a 256 "${PROMPTS_DIR}/prd-context-animation.md" | awk '{print $1}')

jq -n \
    --arg ck "sha256:${CACHE_KEY}" \
    --arg ts "${TIMESTAMP}" \
    --argjson frames "${FRAME_HASHES_JSON}" \
    --arg promptTemplate "sha256:${PROMPT_TEMPLATE_HASH}" \
    --argjson evaluation "$(cat "${REPORT_FILE}")" \
    '{
        cacheKey: $ck,
        createdAt: $ts,
        inputHashes: {
            frames: $frames,
            promptTemplate: $promptTemplate
        },
        evaluation: $evaluation
    }' > "${CACHE_FILE}"

info "  Cached as ${CACHE_KEY:0:16}..."

# ---------------------------------------------------------------------------
# Phase 9: Append audit trail
# ---------------------------------------------------------------------------

SEQ_IDS_JSON=$(jq -c '[.sequences[].id]' "${MANIFEST}")
TOTAL_ISSUE_COUNT=$((TOTAL_ISSUES + TOTAL_QUALITATIVE))

append_audit "$(jq -cn \
    --arg type "animation-evaluation" \
    --arg ts "${TIMESTAMP}" \
    --arg eid "${EVAL_ID}" \
    --arg ph "${PROMPT_HASH}" \
    --argjson sequenceIds "${SEQ_IDS_JSON}" \
    --argjson issueCount "${TOTAL_ISSUE_COUNT}" \
    --argjson cached false \
    '{type: $type, timestamp: $ts, evaluationId: $eid, promptHash: $ph, sequenceIds: $sequenceIds, issueCount: $issueCount, cached: $cached}')"

info "Audit trail entry appended"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

info "Animation evaluation complete"
echo "  Evaluation ID: ${EVAL_ID}"
echo "  Sequences: ${SEQUENCE_COUNT}"
echo "  Issues: ${TOTAL_ISSUES}"
echo "  Qualitative findings: ${TOTAL_QUALITATIVE}"
echo "  Severity: ${SEV_CRITICAL} critical, ${SEV_MAJOR} major, ${SEV_MINOR} minor"
echo "  Confidence: ${CONF_HIGH} high, ${CONF_MEDIUM} medium, ${CONF_LOW} low"
echo "  Report: ${REPORT_FILE}"

exit 0
