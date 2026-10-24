class_name WeaponDefinition
extends Resource

## Where every weapon lives, in one place.
##
## Two other places need this list, and they are not the same list: `player.tscn`
## authors `WeaponController.weapon_definitions` from these files (that array is
## what actually fires), and the front end's WEAPON screen prints its numbers
## from them. When each side kept its own copy, a card could quote one file
## while the controller loaded another -- a screen that states 18 damage for a
## gun that fires 20. `data_source_smoke.gd` asserts both sides still resolve to
## the same resource, so a fourth weapon added to one list and not the other
## fails the suite instead of failing silently in somebody's HUD.
const DEFINITION_PATHS := {
	&"pulse_rifle": "res://resources/weapons/pulse_rifle.tres",
	&"nova_launcher": "res://resources/weapons/nova_launcher.tres",
	&"arc_shooter": "res://resources/weapons/arc_shooter.tres",
}

## Stable iteration order for the registry (GDScript dictionaries keep
## insertion order, but a named list is what a screen should read).
const DEFINITION_IDS: Array[StringName] = [
	&"pulse_rifle",
	&"nova_launcher",
	&"arc_shooter",
]

## The weapon a fresh profile equips, and the one `ProgressionService` falls
## back to when a save names an id that no longer exists. It is read from here
## rather than typed again in the service so that deleting a weapon from the
## registry cannot leave a default pointing at nothing.
const DEFAULT_WEAPON_ID := &"pulse_rifle"

@export var weapon_id: StringName = &""
@export var display_name: String = ""
@export_multiline var role_description: String = ""
## The mesh the player holds, declared here so the WEAPON showcase and
## `player.tscn` cannot disagree. All three definitions currently point at the
## same `rifle.glb`, which is the truth of this build: there is one weapon mesh.
## The showcase shows that mesh and does not pretend each weapon has its own
## silhouette; `showcase_smoke.gd` asserts every definition's model is the exact
## resource the player scene instantiates.
@export var model_scene: PackedScene
@export var projectile_scene: PackedScene
@export_range(0.1, 20.0, 0.1) var fire_rate: float = 5.0
@export_range(1, 100, 1) var magazine_size: int = 24
@export_range(0.2, 5.0, 0.05) var reload_seconds: float = 1.35
@export_range(1.0, 500.0, 1.0) var damage: float = 18.0
@export_range(0.0, 100.0, 1.0) var projectile_speed: float = 42.0
@export_range(1.0, 100.0, 1.0) var max_range: float = 45.0
@export_flags_3d_physics var collision_mask: int = 3
@export_range(0.0, 1000.0, 1.0) var splash_damage: float = 0.0
@export_range(0.0, 20.0, 0.1) var splash_radius: float = 0.0
@export_range(0, 5, 1) var chain_count: int = 0
@export_range(0.0, 20.0, 0.1) var chain_radius: float = 0.0
@export_range(0.0, 1.0, 0.05) var chain_damage_multiplier: float = 0.7


func is_valid_definition() -> bool:
	return (
		weapon_id != &""
		and not display_name.strip_edges().is_empty()
		and is_instance_valid(projectile_scene)
		# A weapon with no mesh cannot be held in gameplay or shown in the
		# selection screen, so the registry would be selling a statistic.
		and is_instance_valid(model_scene)
		and fire_rate > 0.0
		and magazine_size > 0
		and reload_seconds > 0.0
		and damage > 0.0
		and projectile_speed >= 0.0
		and max_range > 0.0
		and splash_damage >= 0.0
		and splash_radius >= 0.0
		and (splash_damage <= 0.0 or splash_radius > 0.0)
		and chain_count >= 0
		and chain_radius >= 0.0
		and (chain_count <= 0 or chain_radius > 0.0)
		and chain_damage_multiplier >= 0.0
		and chain_damage_multiplier <= 1.0
		and (chain_count <= 0 or chain_damage_multiplier > 0.0)
	)


static func load_definition(weapon_id: StringName) -> WeaponDefinition:
	if not DEFINITION_PATHS.has(weapon_id):
		return null
	return load(DEFINITION_PATHS[weapon_id]) as WeaponDefinition


## Canonical order: the registry's, not a second hand-written one.
static func load_all_definitions() -> Array[WeaponDefinition]:
	var out: Array[WeaponDefinition] = []
	for weapon_id in DEFINITION_PATHS:
		var definition := load_definition(weapon_id)
		if definition != null:
			out.append(definition)
	return out
