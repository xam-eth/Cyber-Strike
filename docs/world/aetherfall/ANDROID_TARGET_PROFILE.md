# Aetherfall — Android target profile (draft)

**Platform decision:** Android is the production baseline selected for Aetherfall.

## Verified project configuration

`project.godot` currently declares Godot Mobile rendering, a 1280 × 720 viewport, and anisotropic filtering level 2. These are repository settings, **not** a device-performance result.

## Platform constraints researched before authoring

Godot documents the Mobile renderer as a newer/higher-end mobile path requiring RenderingDevice support (Vulkan on Android); Compatibility is the fallback for older/low-end hardware. Therefore the current Mobile setting is a shipping-risk decision until it is tested on named devices. See [Godot renderer guidance](https://github.com/godotengine/godot-docs/blob/master/tutorials/rendering/renderers.rst).

For the art pipeline, the relevant constraints are evidence, not guesses:

- Godot notes that mobile GPUs are typically limited to 4096 × 4096 textures and that some do not repeat non-power-of-two textures correctly. The 21 existing NPOT warnings in the connected-expanse GLBs must be reviewed as an Android compatibility issue—not globally resized without checking their material use. [Source](https://github.com/godotengine/godot-docs/blob/master/tutorials/3d/3d_rendering_limitations.rst)
- Mobile GPUs are tile-based; concentrated tiny geometry, excessive texture reads, and transparent overlap cost disproportionately. This affects High-Poly bake design, `LP_` topology, VFX, material layering, and LOD decisions. [Source](https://github.com/godotengine/godot-docs/blob/master/tutorials/performance/gpu_optimization.rst)
- Godot recommends considering baked lighting for mobile because real-time lights, shadows, and global illumination may be expensive. That is a look-dev decision to validate in the actual Aetherfall scene, not permission to bake lighting now. [Source](https://github.com/godotengine/godot-docs/blob/master/tutorials/performance/optimizing_3d_performance.rst)

## Deliberately unresolved — do not invent budgets

The following decisions are still needed before Retopology, texture-resolution, LOD, draw-call, or export acceptance can receive a numeric budget:

- minimum Android version and graphics API/render backend policy;
- representative low/mid/high Android devices or an explicit one-device shipping target;
- native resolution, dynamic-resolution/render-scale policy, and target frame rate;
- memory, thermal-duration, texture-memory, draw-call, and frame-time budget;
- whether the current Mobile renderer settings are the intended shipping configuration.

Until those are selected and tested, the asset ledger must retain `performance_budget: unresolved`. This prevents a false “mobile optimized” claim.

## Implication for Gate 01

Hero-destination briefs can establish function, silhouette, physical material allocation, and scale requirements now. They cannot assign final triangle/texture/material limits yet. Those numbers are a Gate 05/10 technical-art decision based on this profile and real target-device captures.
