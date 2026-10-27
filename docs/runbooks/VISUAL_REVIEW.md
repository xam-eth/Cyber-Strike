# Visual Review and Regression Runbook

This runbook owns cross-platform **reference/current/diff comparison and reference approval**. Capture commands remain in [`WEB_PREVIEW.md`](WEB_PREVIEW.md) and [`ANDROID.md`](ANDROID.md); aesthetic direction remains in [`../ART_DIRECTION.md`](../ART_DIRECTION.md). Executed results belong in [`../VALIDATION.md`](../VALIDATION.md).

> **Implementation:** comparator and approval tooling are **IMPLEMENTED**. Initial visual coverage is **PARTIAL**: the manifest registers eight focused Web candidates, while approved references, deterministic TECH HUNT result states, and physical Android profiles remain pending. A capture or automated MATCH is not human aesthetic approval.

## 1. Evidence contract

Keep these states separate:

| State | Meaning | Does not mean |
|---|---|---|
| Captured | A real image/video exists and can be decoded | Correct state, good composition, or approved quality |
| `MATCH` | Pixel difference is inside the case's explicit tolerance | Human approval, cross-GPU equivalence, or animation quality |
| `REVIEW_REQUIRED` | Difference exceeds tolerance; it may be a regression or an intended change | Automatic failure diagnosis or permission to update the reference |
| `BASELINE_PENDING` | No approved reference exists | A passing comparison |
| `MISSING_CURRENT` / `ERROR` | Capture, decoding, or dimension contract failed | A visual regression measurement |

Never use historical images in `qa-evidence/` as a new baseline merely because they exist. A reference becomes golden only through the explicit reviewed approval path below.

## 2. Setup and manifest

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
npm ci --prefix tools
```

Pillow performs PNG decoding/comparison. The pinned browser tooling produces the Web captures.

[`../../tools/visual_review.json`](../../tools/visual_review.json) is the single review manifest. Each profile records its environment, current-capture root, focused cases, channel tolerance, maximum differing-pixel ratio, and review intent. References live under `qa-evidence/visual-goldens/<profile>/`; generated current captures and reports stay under ignored `exports/` paths.

Do not share a golden across different operating systems, browsers, renderers, viewports, or physical GPUs. Do not resize a mismatched image to force a comparison. Keep the matrix focused rather than generating thousands of weakly reviewed images.

## 3. Capture the current Web candidates

Use the committed Web payload for a review of that exact payload. After source changes, complete the Web export first; do not compare an old payload while describing it as the new source.

```bash
OUT=exports/visual-current/web-chromium-swiftshader-844x390

node tools/ui_shots.mjs --viewport 844x390 --out "$OUT"
node tools/web_qa.mjs --page /web/index.html --viewport 844x390 \
  --encounter-prep --tour --out "$OUT"
```

The first command captures opening, theatre hub, HERO, settings, and launch through the real shell. The second reaches actual gameplay, captures safe Explore and explicit Defense preparation, then uses the real WorldTour camera. Their existing behavioral gates must pass; a filename alone does not prove the state.

### Repeatability before the first approval

Run the same captures at least twice into separate A/B directories before promoting a new profile. Both capture commands must exit successfully and the A/B images should remain inside the proposed per-case tolerances. Record the executed result in [`../VALIDATION.md`](../VALIDATION.md); do not widen a tolerance merely to hide an unstable state.

The capture harness supports that contract: `ui_shots.mjs` waits for the active screen, required content, and the shell dock's `ok` readiness state. `web_qa.mjs --encounter-prep` requires unpaused safe Explore before sending B and does not label paused output as Defense preparation. A failed capture is diagnostic evidence, never a baseline candidate. Recheck stability after renderer, capture-timing, viewport, or runtime changes.

## 4. Compare without changing references

```bash
.venv/bin/python tools/visual_review.py compare \
  --profile web-chromium-swiftshader-844x390 \
  --out exports/visual-review/web-run-1 \
  --allow-pending
```

`--allow-pending` is only for bootstrapping missing references. It **does not** ignore mismatches, missing current files, invalid images, or dimension errors. Remove it after the profile has approved references so a deleted/missing baseline blocks the run.

Every report directory contains:

| File | Purpose |
|---|---|
| `index.html` | Side-by-side reference/current/diff review in a browser |
| `report.md` | Compact case status, metrics, notes, and artifact links |
| `visual-review.json` | Machine-readable evidence and the input used by explicit approval |
| `cases/<id>/reference.png` | Exact reviewed reference copy, when one exists |
| `cases/<id>/current.png` | Exact reviewed current copy |
| `cases/<id>/diff.png` | Red pixels beyond tolerance, yellow changes within tolerance, faded unchanged context |

The metric is deliberately simple: a pixel is different when its maximum RGBA channel delta exceeds `channel_tolerance`; `diff_ratio` must be at most `max_diff_ratio`. This is not a perceptual or semantic score. Bootstrap tolerances must be checked against repeated captures in the same environment and adjusted only through reviewed manifest changes.

To serve the report, run `python3 tools/serve_preview.py --port 800` from the repository root and open `/exports/visual-review/web-run-1/` on the same development machine.

## 5. Human review and explicit approval

For each case, inspect the actual three images and confirm:

1. the intended game/UI state and correct profile/environment;
2. composition, clipping, typography, HUD, World/material/lighting, character attachment, and relevant effects;
3. whether the difference is a defect to fix or an intended change to accept;
4. dynamic regions and tolerance are not hiding a real regression.

Then approve **only named cases from that exact report**:

```bash
REPORT=exports/visual-review/web-run-1/visual-review.json
# Record the digest of the exact file inspected above.
REPORT_SHA="$(sha256sum "$REPORT" | cut -d' ' -f1)"

.venv/bin/python tools/visual_review.py approve \
  --report "$REPORT" \
  --report-sha256 "$REPORT_SHA" \
  --case shell-opening \
  --reviewer "Nama reviewer" \
  --note "Reviewed opening reference/current/diff; current composition is intended"
```

Repeat `--case` only for other images actually reviewed. The command verifies the exact report digest and that its current image still has the recorded hash, confines the target to the report's profile, then writes the reference and updates `qa-evidence/visual-goldens/<profile>/approvals.json` with reviewer, note, timestamp, hashes, dimensions, and comparison status. It does not approve other cases, commit files, or rewrite the old report. If either hash changes, stop and review the new artifact rather than recomputing past an unexpected change.

After an intended change, rerun `compare` without `--allow-pending`. Review the golden and approval-ledger diff in Git and commit them with the related reviewed change. Git history is the previous-reference backup. CI and agents must not auto-approve or auto-update goldens.

## 6. Android profiles and native captures

Use [`ANDROID.md`](ANDROID.md) §5 for Remote Debug and native capture. Do **not** compare Android output against the Web golden.

After a physical device produces repeatable states, register a device-specific profile with its model/OS/renderer/output dimensions and its own reference directory. A current capture can then be mapped explicitly without renaming the evidence:

```bash
.venv/bin/python tools/visual_review.py compare \
  --profile android-DEVICE-PROFILE \
  --current gameplay-explore=artifacts/android/visual/RUN/screen.png \
  --out exports/visual-review/android-run-1
```

That example becomes usable only after `android-DEVICE-PROFILE` and its cases are actually defined. Native screen dimensions do not prove internal 3D render resolution. Keep physical GPU/OS profiles separate, use a focused device matrix, and retain human review for material/lighting differences that a tolerance cannot explain.

## 7. Motion and transitions

The manifest's `motion_review` checklist covers idle/run, aim/fire, move/fire, reload, hit/death, and hero entrance/celebration. Capture actual sequences:

```bash
# Native Android, installed app; see the Android runbook.
./scripts/android_visual.sh record --seconds 30 --label animation-review

# Web diagnostic video; not physical-device timing or quality evidence.
node tools/qa_motion_touch.mjs --record
```

Watch the transition, pose continuity, hand/weapon alignment, effect timing, and return to the next state. A single still, clip-name trace, or successful video container does not approve animation. Do not run video recording concurrently with FPS/thermal measurement.

## 8. Current coverage and CI boundary

The initial eight static cases cover opening, HERO, theatre hub, settings, launch, safe Explore HUD, Defense preparation, and one WorldTour camera. The manifest explicitly lists pending TECH HUNT Secure/Extract/Results, high-load/damage/reward states, device variants, and Android profiles. Do not claim full gameplay or full visual coverage from this starter matrix.

The comparison is not yet a blocking CI visual gate because no references have been approved. After reviewed references exist, CI may run `compare` **without** `--allow-pending` and upload the report, but it must never promote images. Web CI remains Web-only evidence; Android acceptance still requires physical devices.

## 9. Evidence limits

- Synthetic comparator tests prove metrics/control flow, not game appearance.
- Automated Chromium/SwiftShader output is not Android rendering or representative mobile performance.
- Pixel MATCH does not prove the intended state, good art, readability, animation, audio, touch, or fun.
- A human approval applies to the named image, reviewer, environment, and note in the ledger; it does not approve every later change or device.
- Record current physical/human outcomes in [`../VALIDATION.md`](../VALIDATION.md) rather than turning this reusable procedure into a dated report.
