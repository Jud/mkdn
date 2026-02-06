#!/usr/bin/env bash
set -euo pipefail

# Post-release smoke test for mkdn Homebrew distribution.
# Runs the FR-10 verification checklist and reports pass/fail for each step.

PASS_COUNT=0
FAIL_COUNT=0
TOTAL=7

pass() {
    echo "PASS: $1"
    PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
    echo "FAIL: $1"
    FAIL_COUNT=$((FAIL_COUNT + 1))
}

echo "--- Step 1/7: brew tap jud/mkdn ---"
if brew tap jud/mkdn 2>&1; then
    pass "brew tap jud/mkdn"
else
    fail "brew tap jud/mkdn"
fi

echo ""
echo "--- Step 2/7: brew install --cask mkdn ---"
if brew install --cask mkdn 2>&1; then
    pass "brew install --cask mkdn"
else
    fail "brew install --cask mkdn"
fi

echo ""
echo "--- Step 3/7: which mkdn ---"
if MKDN_PATH=$(which mkdn 2>&1); then
    echo "  Found at: ${MKDN_PATH}"
    pass "which mkdn"
else
    fail "which mkdn -- not found on PATH"
fi

echo ""
echo "--- Step 4/7: mkdn --help ---"
if HELP_OUTPUT=$(mkdn --help 2>&1); then
    echo "  Output: $(echo "${HELP_OUTPUT}" | head -1)"
    pass "mkdn --help"
else
    fail "mkdn --help -- command failed or produced no output"
fi

echo ""
echo "--- Step 5/7: open -a mkdn ---"
if open -a mkdn 2>&1; then
    sleep 3
    if pgrep -x mkdn > /dev/null 2>&1; then
        pass "open -a mkdn (process running)"
        pkill -x mkdn 2>/dev/null || true
    else
        fail "open -a mkdn -- process not found after launch"
    fi
else
    fail "open -a mkdn -- failed to launch"
fi

echo ""
echo "--- Step 6/7: brew uninstall --cask mkdn ---"
if brew uninstall --cask mkdn 2>&1; then
    pass "brew uninstall --cask mkdn"
else
    fail "brew uninstall --cask mkdn"
fi

echo ""
echo "--- Step 7/7: verify mkdn removed from PATH ---"
if which mkdn > /dev/null 2>&1; then
    fail "mkdn still found on PATH after uninstall"
else
    pass "mkdn removed from PATH"
fi

echo ""
echo "==============================="
echo "Smoke Test Summary"
echo "==============================="
echo "Passed: ${PASS_COUNT}/${TOTAL}"
echo "Failed: ${FAIL_COUNT}/${TOTAL}"
echo "==============================="

if [ "${FAIL_COUNT}" -gt 0 ]; then
    echo "RESULT: FAIL"
    exit 1
else
    echo "RESULT: PASS"
    exit 0
fi
