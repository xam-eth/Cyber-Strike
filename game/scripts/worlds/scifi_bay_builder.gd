class_name ScifiBayBuilder
extends RefCounted

## Builds the playable interior out of the uploaded SciFi Starter Kit.
##
## The layout follows the blockout it replaces: the arena is 38 x 38 m with the
## four route lanes leaving through the middle of each side, so each wall run
## stops 3 m either side of its lane and a door frame fills the opening.
##
## Two details matter more than the layout:
##
## * **Orientation.** `Wall_Simple_01_Long` is 2 m thick, 6 m long along its own
##   Z axis. A wall running east-west therefore needs a 90° turn; without it the
##   tiles stand like fins and the arena never closes.
## * **Material policy.** Every model in the pack shares a material literally
##   named "Orange" (floors included), so the palette is resolved per model in
##   `ScifiKitLibrary.surface_color_key`, not per material name.
##
## Node names are `SciFiBay*` and the whole bay lives under one `SciFiBay` node;
## the world smoke test counts floor tiles, wall pieces and gates.

# Flush with the old deck's panel tops (0.071): below that the plates z-fight
# with the seam strips and the floor reads as dark patches, above it the player
# visibly sinks into the new floor.
const FLOOR_Y := 0.075
const TILE := 6.0
const WALL_LINE := 20.0
const WALL_TILE := 6.0
const WALL_HEIGHT_SCALE := 0.66


static func build(world: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "SciFiBay"
	world.add_child(root)
	var stats := {}
	stats["floor"] = _build_floor(root)
	stats["walls"] = _build_walls(root)
	stats["gates"] = _build_gateways(root)
	stats["props"] = _build_props(root)
	stats["lights"] = _build_lights(root)
	stats["retired"] = retire_legacy_deck(world)
	return stats


## The old arena drew its floor detail as thin boxes: panel tiles, seam strips,
## orange conduits and edge stripes. They sit between 1 mm and 8.5 cm above the
## new plates, so they poked through the SciFi floor as bright bands — the orange
## conduit in particular read as a wall when the camera was near the ground.
## They are hidden rather than deleted: the world smoke test asserts that the
## components still exist, and flipping one flag is a cheaper revert than
## re-adding geometry.
static func retire_legacy_deck(world: Node3D) -> int:
	var prefixes := [
		"ArenaPanel_",
		"ArenaPanelSeam",
		"ArenaOrangeConduit",
		"ArenaCrossChannel",
		"ArenaEnergyChannel",
		"ArenaEdgeStripe",
		"ArenaCornerWarningPanel",
		"ArenaCornerPiece",
	]
	var retired := 0
	for child in world.get_children():
		if not (child is MeshInstance3D):
			continue
		var node_name := str(child.name)
		var matches := false
		for prefix in prefixes:
			if node_name.begins_with(prefix):
				matches = true
				break
		if not matches:
			continue
		(child as MeshInstance3D).visible = false
		retired += 1
	return retired


## Seven tiles of 5.4 m are 37.8 m, which covers the 38 m deck without a lip and
## without overhanging the edge into thin air.
static func _build_floor(root: Node3D) -> int:
	var count := 0
	for ix in range(-3, 4):
		for iz in range(-3, 4):
			var key := "floor"
			if (ix * 5 + iz * 3) % 4 == 0:
				key = "floor_alt"
			place(
				root,
				key,
				"SciFiBayFloor_%d_%d" % [ix + 3, iz + 3],
				Vector3(float(ix) * TILE, FLOOR_Y, float(iz) * TILE),
				90.0,
				0.995,
				false,
				false
			)
			count += 1
	return count


## Four wall runs of six tiles each, with the middle 6 m left open for the lane.
static func _build_walls(root: Node3D) -> int:
	var count := 0
	var sides := [
		{"name": "North", "at": Vector3(0.0, 0.0, -WALL_LINE), "yaw": 90.0},
		{"name": "South", "at": Vector3(0.0, 0.0, WALL_LINE), "yaw": 90.0},
		{"name": "West", "at": Vector3(-WALL_LINE, 0.0, 0.0), "yaw": 0.0},
		{"name": "East", "at": Vector3(WALL_LINE, 0.0, 0.0), "yaw": 0.0},
	]
	for side in sides:
		var origin: Vector3 = side["at"]
		var yaw: float = side["yaw"]
		# The model is long on Z; after the yaw it runs along the wall line.
		var along := Vector3(sin(deg_to_rad(yaw)), 0.0, cos(deg_to_rad(yaw)))
		for index in range(-3, 4):
			if index == 0:
				continue
			var key: String = ["wall", "wall_b", "wall_c"][abs(index) % 3]
			var at := origin + along * (float(index) * WALL_TILE)
			place(
				root,
				key,
				"SciFiBayWall_%s_%d" % [side["name"], index + 3],
				at,
				yaw,
				1.0,
				true,
				true,
				Vector3(1.0, WALL_HEIGHT_SCALE, 1.0)
			)
			count += 1
			# A low plate in front of the side tiles gives the arena waist-high
			# cover that a 2.6 m wall cannot.
			if abs(index) == 2:
				place(
					root,
					"wall_low",
					"SciFiBayCover_%s_%d" % [side["name"], index + 3],
					at + _inward(origin) * 1.6,
					yaw,
					1.0,
					true,
					true
				)
				count += 1
	return count


static func _inward(origin: Vector3) -> Vector3:
	var direction := Vector3(0.0, 0.0, 0.0) - Vector3(origin.x, 0.0, origin.z)
	if direction.length_squared() < 0.001:
		return Vector3.ZERO
	return direction.normalized()


## A door frame on each lane, facing into the arena. No collider: it is an
## opening, and a box the size of its mesh would seal the lane the traversal test
## walks.
static func _build_gateways(root: Node3D) -> int:
	var gates := [
		{"name": "North", "at": Vector3(0.0, 0.0, -WALL_LINE), "yaw": 0.0},
		{"name": "South", "at": Vector3(0.0, 0.0, WALL_LINE), "yaw": 0.0},
		{"name": "West", "at": Vector3(-WALL_LINE, 0.0, 0.0), "yaw": 90.0},
		{"name": "East", "at": Vector3(WALL_LINE, 0.0, 0.0), "yaw": 90.0},
	]
	for gate in gates:
		place(
			root,
			"doorway",
			"SciFiBayGate_%s" % gate["name"],
			gate["at"],
			float(gate["yaw"]),
			1.22,
			false,
			true
		)
	return gates.size()


## Pillars on the diagonals, crates as cover, consoles against the walls and
## pipe stacks in the corners. Nothing stands inside a 6 m lane.
static func _build_props(root: Node3D) -> int:
	var count := 0
	for index in range(8):
		var angle := deg_to_rad(22.5 + 45.0 * float(index))
		var at := Vector3(cos(angle), 0.0, sin(angle)) * 15.5
		place(
			root, "pillar", "SciFiBayPillar_%02d" % index, at, -rad_to_deg(angle), 1.0, true, true
		)
		count += 1
		if index % 2 == 0:
			place(
				root,
				"crate",
				"SciFiBayCrate_%02d" % index,
				at + Vector3(cos(angle), 0.0, sin(angle)) * 3.2,
				-rad_to_deg(angle) + 90.0,
				1.1,
				true,
				true
			)
			count += 1
	for side in range(4):
		var angle := deg_to_rad(90.0 * float(side))
		var tangent := Vector3(-sin(angle), 0.0, cos(angle))
		for offset in [-1, 1]:
			var at := (
				Vector3(cos(angle), 0.0, sin(angle)) * (WALL_LINE - 1.9)
				+ tangent * (float(offset) * 9.0)
			)
			place(
				root,
				"console",
				"SciFiBayConsole_%d_%d" % [side, offset + 1],
				at,
				-rad_to_deg(angle) + 180.0,
				0.9,
				true,
				true
			)
			count += 1
		# Pipes bundle in the corner behind the console: reads as services.
		place(
			root,
			"pipes",
			"SciFiBayPipes_%02d" % side,
			Vector3(cos(angle + 0.62), 0.0, sin(angle + 0.62)) * 17.6,
			-rad_to_deg(angle),
			1.0,
			true,
			true
		)
		count += 1
	return count


## Emissive strips around the wall line. These are unshaded geometry rather than
## lights: the Compatibility renderer used on the web pays for every real light
## on every surface it touches.
static func _build_lights(root: Node3D) -> int:
	var count := 0
	for side in range(4):
		var angle := deg_to_rad(90.0 * float(side))
		var along := Vector3(-sin(angle), 0.0, cos(angle))
		for step in range(-2, 3):
			if step == 0:
				continue
			var at := (
				Vector3(cos(angle), 0.0, sin(angle)) * (WALL_LINE - 1.02)
				+ along * (float(step) * WALL_TILE)
			)
			place(
				root,
				"light_strip",
				"SciFiBayStrip_%d_%d" % [side, step + 3],
				at + Vector3(0.0, 2.2, 0.0),
				-rad_to_deg(angle) + 90.0,
				2.2,
				false,
				false
			)
			count += 1
	return count


## One placement helper for the whole bay. The visual model and the collider are
## separate nodes on purpose: the model carries rotation, a non-uniform height
## scale and a base offset, and scaling a CollisionShape3D through a rotated,
## non-uniformly scaled parent is how colliders end up in the wrong plane.
static func place(
	parent: Node3D,
	key: String,
	node_name: String,
	at: Vector3,
	yaw: float,
	scale: float = 1.0,
	collide: bool = true,
	shadow: bool = true,
	size_scale: Vector3 = Vector3.ONE
) -> Node3D:
	var scene := ScifiKitLibrary.model(key)
	if scene == null:
		return null
	var instance := scene.instantiate() as Node3D
	instance.name = node_name
	ScifiKitLibrary.apply_palette(instance, key)
	instance.position = at + Vector3(0.0, ScifiKitLibrary.base_offset(key) * scale, 0.0)
	instance.rotation_degrees.y = yaw
	instance.scale = Vector3.ONE * scale * size_scale
	for child in instance.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		mesh.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if shadow
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
	parent.add_child(instance)
	if collide:
		var size: Vector3 = ScifiKitLibrary.size(key) * scale * size_scale
		_add_box_collider(parent, node_name + "Body", at, yaw, size)
	return instance


static func _add_box_collider(
	parent: Node3D, node_name: String, at: Vector3, yaw: float, size: Vector3
) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = at + Vector3(0.0, size.y * 0.5, 0.0)
	body.rotation_degrees.y = yaw
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
