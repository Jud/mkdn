# Field Notes: LLM Visual Verification

## 2026-02-09: Capture Hash Non-Determinism (T14)

**Context**: SA-1 runtime verification ran `swift test --filter VisionCapture` twice consecutively to check REQ-SA1-002 (capture stability).

**Finding**: All 8 image hashes differ between consecutive runs. File sizes are within a few hundred bytes of each other (e.g., canonical-solarizedDark: 564717 vs 565015 bytes), indicating sub-pixel rendering variations rather than structural differences.

**Root Cause**: macOS text rendering via Core Text and Mermaid diagram rendering via WKWebView are not bitwise deterministic across process launches. CGWindowListCreateImage captures the window buffer which includes these sub-pixel variations.

**Impact**: Low. The LLM visual verification workflow uses Claude Code's vision capabilities for evaluation, not hash comparison. Sub-pixel variations are imperceptible to the vision model. The evaluation cache uses image content hashes, so cache hits will not occur across separate capture runs even if the visual content is identical -- but this is acceptable because cache is primarily useful within a single heal-loop iteration (capture once, evaluate, re-evaluate same images).

**Recommendation**: REQ-SA1-002 can be considered a known limitation. If bitwise determinism is needed in the future, options include: (1) normalizing PNG output through a canonical encoder, (2) using perceptual hashing instead of SHA-256, or (3) comparing images via pixel-level tolerance rather than hash equality.
