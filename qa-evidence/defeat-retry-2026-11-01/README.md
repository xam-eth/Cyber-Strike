# Defeat / Retry — executed WebGL evidence

**Date:** 2026-11-01  
**Scope:** Website / Godot WebGL 2, supported **844×390 touch landscape**. This is executed evidence, not a design proposal or human/device approval.

## Exact runtime boundary

- Generated payload: `19852d7447cae0cca1419e98bdd97f9693fbc334`.
- PCK: 90,719,636 bytes; SHA-256 `11e50265ccc1f479013438203dad2eb35543d1eddd332afc00d7eb2bc6f6a25b`.
- WASM SHA-256: `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0`.
- The served PCK and the Git blob were hashed directly and match.
- Payload CI `41213150955` passed Static, 38/38 Headless, Web export, and all registered browser gates.
- No gameplay/runtime source changed for this follow-up; the change extends the browser QA runner and preserves its output.

See [`manifest.json`](manifest.json) for the runner and report hashes.

## Executed route and result

**PASS — 5 checks, 23 preserved frames, 0 Godot/browser errors.**

1. A real touchscreen tap starts Defense. No health, enemy, reward, or profile state is injected.
2. Real Runner attacks reduce VITALS from 100/100 to 0/100. Four death-clip samples include a lowered head bone.
3. Eighteen compositor frames preserve the authored collapse before Results replaces the play HUD. The chronological sequence is visible in [`contact-death-compositor.png`](contact-death-compositor.png).
4. Results reports **+0 BP BANKED**, honestly reflecting a no-KO defeat. Exactly one `Progression: banked +0 BP · wallet 0 · best 0` event occurs.
5. Keyboard Enter activates the real, focused **RETRY DEFENSE** button. The runner requires new Returned to Explore and Preparation events, then a second actual Defense start.
6. Retry creates no second bank and does not reopen stale Results. [`04-retry-preparing.png`](04-retry-preparing.png) and [`05-retry-defense.png`](05-retry-defense.png) show restored **100/100** vitals, **24/24** ammo, and a fresh Wave 01.

All five main frames and all eighteen compositor frames were inspected. [`contact-main.png`](contact-main.png) is derived only from the five main frames; no unsupported-orientation or failed-startup capture is included.

## Orientation boundary

The ordinary product shell is intentionally landscape-only and displays **ROTATE DEVICE** in portrait. This runner therefore uses 844×390. An initial direct-engine 390×844 attempt bypassed that product contract and was rejected as unsupported; it is not presented as a supported-layout defect or as final evidence.

## Reproduce

From a self-contained checkout containing the committed Web payload:

```bash
python3 -m http.server 800 --bind 0.0.0.0
npm ci --prefix tools
node tools/qa_death_touch.mjs --url=http://127.0.0.1:800/web/
```

The runner adds `qa_stage=GAMEPLAY&qa_camera`, uses a fresh browser profile, and writes `exports/qa-death-touch/report.json` plus frames. The preserved report and images here come from one green execution.

## Limits

- This focused route does not repeat the complete Recovery/adaptation/persistence playthrough; that separate evidence remains in [`../recovery-adaptation-2026-10-31/`](../recovery-adaptation-2026-10-31/).
- Software-WebGL automation does not verify physical-phone feel, representative GPU performance, or human animation-quality approval.
- Human audibility remains **UNKNOWN**. APK/native validation remains paused.
