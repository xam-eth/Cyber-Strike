# Web Loading and Recovery Validation

Date: 2026-10-24

Branch: `arena/0b0dc2fd-cyber-strike`

## Reported symptom and log interpretation

The player reported that DEPLOY stayed on loading and the world did not open while the repository root was served with `python3 -m http.server 8000 --bind 0.0.0.0`.

The supplied log proves that the shell, export HTML, PCK, and WASM were requested. It does **not** prove that either large response completed. `BrokenPipeError: [Errno 32]` means the browser/proxy closed a response connection; it can accompany an abort, reload, or failed download, but is not by itself a game-engine diagnosis. The `/favicon.ico` 404 is unrelated to engine startup.

## Verified defects

### 1. Rewritten asset paths lost their byte sizes — VERIFIED

The root shell changes `config.executable` to `./web/index`. Godot then looks up `./web/index.wasm` and `./web/index.pck` in `fileSizes`, while the export only supplied `index.wasm` and `index.pck`.

Browser instrumentation before the correction recorded many real byte events with `total = 0`. The shell correctly refused to invent a percentage from those events, but the visible bar therefore remained indeterminate. The shell now preserves the exported keys and adds the two rewritten paths.

After the correction, both recovery cases on final payload `b055f0d` reported one consistent total: **135,101,522 bytes** (39,514,754-byte WASM + 95,586,768-byte PCK).

### 2. WASM initialization failures never rejected `startGame()` — VERIFIED

A controlled aborted WASM request reproduced the indefinite **Menyiapkan dunia** state before the repair. Chromium reported `TypeError: Failed to fetch`, while the shell remained on loading.

Godot 4.7.2's generated `doInit()` accepts `reject` but did not forward failures from:

1. the WASM response Promise;
2. Godot module initialization;
3. filesystem initialization.

`tools/web_loader_patch.py` adds those three rejection handlers. `scripts/export_web_preview.sh` applies the exact, idempotent patch after every export and refuses to patch unrecognized exporter output. Thus `Engine.startGame()` now reaches its rejection handler instead of remaining pending.

## Player-facing behavior

- Loading shows real combined WASM + PCK bytes and the expected **135.1 MB** first-download total (about **128.8 MiB**), rather than an unexplained indefinite bar.
- A failed download or initialization produces a readable error and does not reveal the canvas.
- **Coba lagi** reloads the existing DEPLOY hand-off and retries the real assets. On the current root shell it must return to the selected theatre's real gameplay, not stop at WORLD or fabricate a ready state.
- Three minutes without byte/start progress produces an actionable stalled-loading error. Progress events reset that watchdog, so a slow but active download is not failed merely for exceeding a fixed total duration.
- The shell still reveals the canvas only after `startGame()` resolves.

The payload was not trimmed or recompressed in this repair. A first download through a slow network or forwarded port can still take substantial time.

## Automated browser evidence

Command:

```bash
node tools/web_loading_qa.mjs \
  --throughput-mbps 100 --timeout 150 \
  --out exports/integration-audit/loading-gate-final-b055f0d --json
```

Local ignored report on payload `b055f0d`: `exports/integration-audit/loading-gate-final-b055f0d/report.json`.

**PASS for both `index.wasm` and `index.pck`, with browser cache disabled:**

- the selected asset was actually interrupted;
- the error UI exposed retry and kept the canvas hidden;
- no unhandled page rejection occurred;
- retry downloaded to a final `135101522 / 135101522` callback;
- rendered progress was monotonic from 0 through 100;
- a fresh Godot banner and `FrontEnd: stage WORLD` appeared;
- the real canvas was revealed.

A separate pre-publication truncated-body diagnostic used a static server that declared the full content length, sent only 2 MiB, and closed the socket. Both WASM and PCK produced `ERR_CONTENT_LENGTH_MISMATCH`, then the readable **Koneksi dunia terputus** state with retry and a hidden canvas. After the server stopped truncating responses, retry reached `dunia siap`, a fresh Godot banner, WORLD, and the revealed canvas for both assets. Reports: `exports/integration-audit/loading-midstream-wasm-retry-2.json` and `loading-midstream-pck-retry.json`.

Additional pre-publication local regression evidence (CI repeated these gates on the final export):

- `node tools/web_qa.mjs --timeout 120`: **4/4 PASS** for `/` and `/web/index.html` at 844×390 and 667×375; report `exports/integration-audit/loading-final-basic-report.json`.
- Strict DEPLOY → WORLD → measured Vanguard selection: **PASS**, including `FrontEnd: world selected vanguard_station` and `VanguardStation: 421 kit modules, 17 omnis, 4 rooms`; report `exports/integration-audit/loading-final-vanguard-report.json`.
- `scripts/dev_check.sh`: **0 failed steps**; 75 GDScripts, project doctor 0 FAIL/30 WARN, 40 tooling tests, 28-test inventory intact. Local Godot/preset checks remained skipped because Godot is unavailable locally.
- JavaScript syntax and export-script shell syntax: **PASS**.

CI run [40103458382](https://github.com/xam-eth/Cyber-Strike/actions/runs/40103458382) on source `eac21bfce04d230a3ecc3c44d9b3b6b24af03e5d` completed **SUCCESS** and published payload `b055f0dca4f35fcc0d67a7f4485ff8494c36548e`. Its check-runs confirm 28/28 import-OK Godot 4.7.2 tests, four Chromium boots, `Loading recovery: index.wasm PASS | index.pck PASS`, static delivery, and the WORLD → Vanguard contract. The recovery gate runs before the WORLD-selection contract in `web-preview`.

## Remaining limits and player action

- The exact browser/proxy that produced the player's BrokenPipe was not available for direct inspection. The reproduced loader defects are verified, but this document does not claim they prove every possible cause of that specific connection close.
- No Android, physical touch-device, mobile-performance, full-run, or final visual acceptance claim is added.
- Pull the corrected branch, serve the repository root as before, and use a fresh normal `/` page. If a previous failed download is reported, use **Coba lagi** and keep the tab active while the byte count advances.
- If failure recurs, record the new on-screen title/detail plus the browser console and the exact asset in the Network panel. That evidence distinguishes delivery failure from engine initialization/start failure; suppressing BrokenPipe logs or hiding the loading overlay would not repair either one.

## 2026-10-25 addendum: painted UI and direct selected-theatre recovery

The `b055f0d` evidence above is historical and remains valid for that payload only. The latest UI merge changed the root handoff: theatre selection now happens on the shell carousel, then DEPLOY enters that theatre's gameplay directly. It no longer stops at engine WORLD.

- Merge source: `b1528e6c3ea306659f06670310de50e9a14d7d22`; final generated payload: `ad586eb1ab78e1ad9da484b2680afe9c456b704e`.
- The new painted launch screen retains the `fileSizes` path remap, real combined bytes, watchdog, network-error detail, boot-only rejection fallback, and **Coba lagi** control. The post-export loader patch remains in the CI pipeline.
- Current payload sizes are **39,514,754-byte WASM + 98,188,988-byte PCK = 137,703,742 bytes**. The PCK contains 887 files and passed the payload audit.
- CI [40155061418](https://github.com/xam-eth/Cyber-Strike/actions/runs/40155061418) passed export, four normal browser boots, both interrupted-asset recovery cases, and strict shell Vanguard selection after the change.

The final local command was:

```bash
node tools/web_loading_qa.mjs \
  --throughput-mbps 100 --timeout 150 \
  --out exports/integration-audit/ui-final-loading-ad586eb1 --json
```

**VERIFIED PASS for both assets on payload `ad586eb1`:**

- the requested asset was interrupted and produced **Koneksi dunia terputus**, a hidden canvas, and visible retry;
- retry emitted one consistent nonzero total and monotonic intermediate progress ending at exactly `137703742 / 137703742`;
- the fresh engine accepted `FrontEnd: qa_world selected neon_frontier` and reached `Encounter: Explore safe`;
- no `FrontEnd: stage WORLD` or unhandled initialization rejection was observed.

Strict final-payload Vanguard QA independently passed with the real shell card selection and `VanguardStation: 421 kit modules, 17 omnis, 4 rooms`; report `exports/integration-audit/ui-final-vanguard-ad586eb1.json`.

These are automated headless results, not physical-device/network coverage. The exact original proxy failure, Android, physical touch performance, a complete human run, and final visual acceptance remain open.
