extends RefCounted

## Visible in-world wayfinding for the Aetherfall operation.
##
## The player used to spawn on a bare deck tile with no indication of where to
## go: `mission_world` only created invisible Marker3D "wayfinders". This builds
## the missing guidance layer from REAL mission data only:
##
## * an arrival pad + briefing pillar at `WorldDefinition.player_spawn`, labelled
##   with the actual first objective's display name,
## * ground chevron arrows along the route between the recovery caches, yellow
##   for the active leg (spawn -> primary cache) and cyan for the following legs,
## * every waypoint is a `RecoveryCacheDefinition.position` from the world
##   definition -- no invented coordinates or fake objectives.
##
## Everything here is presentation-only: no colliders, no gameplay state, so
## guidance can never block movement or occlude the hero for the visibility
## checks.

const DECK_Y := 0.26
const PAD_RADIUS := 1.7
const CHEVRON_GAP := 2.4
const COLOR_ACTIVE := Color(1.0, 0.82, 0.2, 1.0)
const COLOR_ROUTE := Color(0.3, 0.85, 1.0, 1.0)
const COLOR_PANEL := Color(0.06, 0.2, 0.26, 1.0)


static func install(parent: Node3D, definition: WorldDefinition) -> Dictionary:
	var stats := {"chevrons": 0, "signs": 0, "meshes": 0}
	if definition == null:
		return stats
	var spawn: Vector3 = definition.player_spawn
	var waypoints: Array[Vector3] = []
	var primary_name := ""
	var ordered: Array = []
	var primary: Array = []
	for cache in definition.recovery_caches:
		if cache == null or not bool(cache.is_valid_definition()):
			continue
		if String(cache.cache_id).contains("primary") and primary.is_empty():
			primary.append(cache)
		else:
			ordered.append(cache)
	for cache in primary + ordered:
		waypoints.append(Vector3(cache.position))
		if primary_name.is_empty():
			primary_name = String(cache.display_name)
	if waypoints.is_empty():
		return stats

	var root := Node3D.new()
	root.name = "WorldGuidance"
	parent.add_child(root)

	_build_arrival_pad(root, spawn, primary_name, stats)
	var route_start := Vector3(spawn.x, DECK_Y, spawn.z)
	for leg_index in range(waypoints.size()):
		var leg_from := route_start if leg_index == 0 else waypoints[leg_index - 1]
		var leg_to := waypoints[leg_index]
		var color := COLOR_ACTIVE if leg_index == 0 else COLOR_ROUTE
		_build_chevron_leg(root, leg_from, leg_to, color, stats)
	root.set_meta("chevrons", stats["chevrons"])
	root.set_meta("signs", stats["signs"])
	return stats


static func _build_arrival_pad(
	root: Node3D, spawn: Vector3, primary_name: String, stats: Dictionary
) -> void:
	var pad_center := Vector3(spawn.x, DECK_Y, spawn.z)

	var pad := MeshInstance3D.new()
	pad.name = "ArrivalPad"
	var disc := CylinderMesh.new()
	disc.top_radius = PAD_RADIUS
	disc.bottom_radius = PAD_RADIUS
	disc.height = 0.02
	pad.mesh = disc
	pad.material_override = _unshaded(COLOR_PANEL)
	pad.position = pad_center + Vector3(0.0, 0.01, 0.0)
	pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pad)
	stats["meshes"] = int(stats["meshes"]) + 1

	var ring := MeshInstance3D.new()
	ring.name = "ArrivalPadRing"
	var torus := TorusMesh.new()
	torus.inner_radius = PAD_RADIUS - 0.18
	torus.outer_radius = PAD_RADIUS
	ring.mesh = torus
	ring.material_override = _unshaded(COLOR_ACTIVE)
	ring.position = pad_center + Vector3(0.0, 0.02, 0.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	stats["meshes"] = int(stats["meshes"]) + 1

	# Briefing pillar: real mission text, billboarded so it reads from spawn.
	var post_x := pad_center.x + 1.35
	var post_z := pad_center.z - 1.35
	var post := MeshInstance3D.new()
	post.name = "BriefingPost"
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.14, 2.1, 0.14)
	post.mesh = post_mesh
	post.material_override = _unshaded(COLOR_PANEL)
	post.position = Vector3(post_x, DECK_Y + 1.05, post_z)
	post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(post)
	stats["meshes"] = int(stats["meshes"]) + 1

	var beacon := MeshInstance3D.new()
	beacon.name = "BriefingBeacon"
	var beacon_mesh := BoxMesh.new()
	beacon_mesh.size = Vector3(0.26, 0.26, 0.26)
	beacon.mesh = beacon_mesh
	beacon.material_override = _unshaded(COLOR_ACTIVE)
	beacon.position = Vector3(post_x, DECK_Y + 2.24, post_z)
	beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(beacon)
	stats["meshes"] = int(stats["meshes"]) + 1

	var label := Label3D.new()
	label.name = "BriefingLabel"
	label.text = "ARRIVAL OUTPOST\nSECURE %s" % primary_name
	label.font_size = 64
	label.pixel_size = 0.006
	label.modulate = Color(0.92, 0.98, 1.0, 1.0)
	label.outline_modulate = Color(0.02, 0.08, 0.12, 1.0)
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	label.position = Vector3(post_x, DECK_Y + 1.72, post_z)
	root.add_child(label)
	stats["signs"] = int(stats["signs"]) + 1


static func _build_chevron_leg(
	root: Node3D, from: Vector3, to: Vector3, color: Color, stats: Dictionary
) -> void:
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var distance := flat.length()
	if distance < 0.5:
		return
	var heading := flat.normalized()
	var yaw := atan2(-heading.x, -heading.z)
	var count := clampi(int(distance / CHEVRON_GAP), 1, 8)
	for step in range(1, count + 1):
		var t := float(step) / float(count + 1)
		var at := from.lerp(to, t)
		var chevron := Label3D.new()
		chevron.name = "Chevron%d" % step
		chevron.text = "▲"
		chevron.font_size = 140
		chevron.pixel_size = 0.004
		chevron.modulate = color
		chevron.outline_modulate = Color(0.02, 0.08, 0.12, 1.0)
		chevron.outline_size = 6
		chevron.rotation = Vector3(-PI / 2.0, yaw, 0.0)
		chevron.position = Vector3(at.x, DECK_Y + 0.02, at.z)
		root.add_child(chevron)
		stats["chevrons"] = int(stats["chevrons"]) + 1


static func _unshaded(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.roughness = 1.0
	return material
