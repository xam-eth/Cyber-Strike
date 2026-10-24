# WebAssembly visual QA — 18 October 2026

Payload `374cdd3` (source `97fc2c8`), root `index.html`, Chromium software-rendered, 390×844. These frames are evidence for review, **not aesthetic approval or Android-device testing**.

- `01-root-explore.png`: neutralized FBX floor and localized reactor fill. Compare with `../combat-touch-v2/01-explore.png` (earlier payload, same entry point and initial camera). The floor ROI x230–310, y475–575 changes from average sRGB **(46, 91, 141)** to **(75, 82, 89)**. The average saturation of x0–390, y210–560 changes from **0.710 to 0.503** (ImageMagick HSB channel). These are measured colors, not a visual-quality grade.
- `02-first-contact.png`: Wave 01 first Runner visible; the idle Explore practice dummy is absent during Defense.
- `03-ads-held.png`–`06-run-fire-held.png`: actual Blender hero and rifle in the WASM game while ADS, FIRE and keyboard-forward movement are held. The opt-in camera trace reached `aim=true`, `fire=true clip=fire`, and `fire=true clip=aim_run`; Pulse rounds were consumed. Still frames cannot judge motion timing or full impact quality.
- `07-nova-fired.png`, `full-wave-log.txt`: actual touch wave clear (+120 BP), Nova purchase/equip and one spent Nova round on replay; log and visual evidence do **not** show a Nova target hit.

Reactor shapes still dominate the center, and flat blue/teal background geometry and weapon silhouette need human art review. The exact renderer/device should be taken into account; SwiftShader is not physical mobile performance.
