## How the Neon Frontier builds a surface.
##
## `neon_frontier_world.gd` and `neon_frontier_asset.gd` each carried their own
## copy of these factories, and the copies had drifted: the emissive base was
## metallic 0.25 / roughness 0.3 in one and 0.28 / 0.28 in the other, so the
## same-looking call produced a different surface depending on which file it
## sat in. One kit now defines how a surface behaves.
##
## The *palettes* stay where they are — `_create_materials()` in each builder.
## Palettes are content and genuinely differ (the world has ground and rock
## tones, the components have reactor and emerald tones); the factories were
## plumbing, and plumbing is what belongs in one place.
class_name NeonFrontierMaterialKit
extends RefCounted


static func make_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


## `metallic` and `roughness` default to the world builder's old values; the
## asset builder passes its own (0.28 / 0.28) so both keep looking as they do.
static func make_emissive(
	color: Color, strength: float, metallic: float = 0.25, roughness: float = 0.3
) -> StandardMaterial3D:
	var material := make_material(color, metallic, roughness)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = strength
	return material


static func make_translucent(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := make_material(color, metallic, roughness)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return material
