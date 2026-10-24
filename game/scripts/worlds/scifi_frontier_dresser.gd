class_name ScifiFrontierDresser
extends RefCounted

## Extends the user's converted FBX SciFi Starter Kit outside the central bay.
## Perimeter collision remains a simple invisible gameplay boundary, but its
## visible surface and district landmarks are kit geometry, never KayKit.
## The existing procedural ground/ramps stay as collision and substructure.

const FENCE_LENGTH := 5.0
const TARGET_SEGMENT := 10.0


static func build_boundary(world: Node3D, width: float, depth: float, center_z: float) -> void:
	var root := Node3D.new()
	root.name = "SciFiFrontierBoundary"
	world.add_child(root)
	var half_w := width * 0.5
	var half_d := depth * 0.5
	var sides := [
		{
			"name": "North",
			"length": width,
			"yaw": 90.0,
			"center": Vector3(0.0, 0.0, center_z - half_d + 1.25),
			"along": Vector3.RIGHT,
			"core_at": Vector3(0.0, 5.0, center_z - half_d),
			"core_size": Vector3(width, 10.0, 2.0),
		},
		{
			"name": "South",
			"length": width,
			"yaw": 90.0,
			"center": Vector3(0.0, 0.0, center_z + half_d - 1.25),
			"along": Vector3.RIGHT,
			"core_at": Vector3(0.0, 5.0, center_z + half_d),
			"core_size": Vector3(width, 10.0, 2.0),
		},
		{
			"name": "West",
			"length": depth,
			"yaw": 0.0,
			"center": Vector3(-half_w + 1.25, 0.0, center_z),
			"along": Vector3.BACK,
			"core_at": Vector3(-half_w, 5.0, center_z),
			"core_size": Vector3(2.0, 10.0, depth),
		},
		{
			"name": "East",
			"length": depth,
			"yaw": 0.0,
			"center": Vector3(half_w - 1.25, 0.0, center_z),
			"along": Vector3.BACK,
			"core_at": Vector3(half_w, 5.0, center_z),
			"core_size": Vector3(2.0, 10.0, depth),
		},
	]
	for side in sides:
		var label: String = side["name"]
		var origin: Vector3 = side["center"]
		var along: Vector3 = side["along"]
		var length: float = side["length"]
		var yaw: float = side["yaw"]
		_add_collision_core(root, "%sBoundaryCore" % label, side["core_at"], side["core_size"])
		var segments := ceili(length / TARGET_SEGMENT)
		var step := length / float(segments)
		var scale := step / FENCE_LENGTH
		for index in range(segments):
			var at := origin + along * (-length * 0.5 + step * (float(index) + 0.5))
			ScifiBayBuilder.place(
				root, "fence", "SciFi%sFence_%02d" % [label, index], at, yaw, scale, true, false
			)
			if index % 4 == 1:
				# Irregular tall ribs break the outline of the long flat fence.
				ScifiBayBuilder.place(
					root,
					"column",
					"SciFi%sPylon_%02d" % [label, index],
					at,
					yaw,
					scale * 0.8,
					false,
					true
				)


static func _add_collision_core(root: Node3D, label: String, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.name = label + "CollisionShape"
	collision.shape = shape
	body.add_child(collision)
	root.add_child(body)
	# This is strictly physics; the visible fence is imported FBX geometry.
	body.visible = false


static func dress_districts(world: Node3D) -> void:
	var areas := [
		{"name": "Outpost", "at": Vector3(-59.0, 0.0, -23.0), "yaw": 90.0},
		{"name": "Landing", "at": Vector3(67.0, 0.0, 15.0), "yaw": 0.0},
		{"name": "Extraction", "at": Vector3(62.0, 0.0, -44.0), "yaw": 90.0},
		{"name": "Boss", "at": Vector3(0.0, 0.0, -82.0), "yaw": 90.0},
		{"name": "Wreck", "at": Vector3(-60.0, 0.0, 60.0), "yaw": 0.0},
	]
	for area in areas:
		var label: String = area["name"]
		var root := Node3D.new()
		root.name = "SciFi%sDistrict" % label
		root.position = area["at"]
		world.add_child(root)
		var yaw: float = area["yaw"]
		ScifiBayBuilder.place(
			root, "wall", "%sWestCladding" % label, Vector3(-9.0, 0.0, 0.0), yaw, 1.35, false, true
		)
		ScifiBayBuilder.place(
			root, "wall_b", "%sEastCladding" % label, Vector3(9.0, 0.0, 0.0), yaw, 1.35, false, true
		)
		ScifiBayBuilder.place(
			root, "doorway", "%sEntryFrame" % label, Vector3(0.0, 0.0, 7.0), yaw, 1.25, false, true
		)
		for crate_index in range(3):
			ScifiBayBuilder.place(
				root,
				"crate",
				"%sSupply_%02d" % [label, crate_index],
				Vector3(-5.5 + float(crate_index) * 2.1, 0.0, -6.0),
				float(crate_index) * 37.0,
				1.0,
				false,
				true
			)
		ScifiBayBuilder.place(
			root,
			"light_strip",
			"%sRouteLight" % label,
			Vector3(0.0, 2.6, 7.4),
			yaw,
			1.6,
			false,
			false
		)
	# Two sightline-safe gate markers guide the player out of the central bay.
	for direction in [-1, 1]:
		ScifiBayBuilder.place(
			world,
			"doorway",
			"SciFiRouteMarker_%s" % str(direction),
			Vector3(0.0, 0.0, float(direction) * 34.0),
			0.0,
			1.15,
			false,
			true
		)
