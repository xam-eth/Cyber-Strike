class_name StationKit
extends RefCounted

## The three primitives every room of the station is built from: place one
## imported module by its measured footprint, give it a collider that agrees with
## what is drawn, and mount a sign at a stated width.
##
## These went looking for a home of their own when the composer filled the
## repo's file-length ceiling for the second time. They are the part of the world
## that must stay honest — the placements are only as good as the measurement
## they are centred on — so they are worth reading without four rooms around them.

const SIGN_WIDTH := {"word": 3.4, "sign": 1.8, "num": 0.7}

## One imported module, centred on its own measured footprint.
##
## `ScifiBayBuilder.place` positions a module by the pack's own origin, which for
## most pieces is a corner: a placed console floats 0.74 m above the deck and a
## placed wall sits a metre off its collider. This wrapper puts a pivot at `at`,
## turns it, and offsets the model by `-(min + size / 2)` inside that pivot, so
## "at" means the centre of the thing — and the collider, which is built from the
## same box, agrees with what is drawn.
##
## `collide` is `""` for scenery, `"box"` for anything the player bumps into, and
## `"floor"` for deck plates, which get a thin box under the origin so the player
## stands on the surface rather than inside a 6 m tall block.
## A sign, decal or numeral, sized by what it is for rather than by a scale
## someone typed.
##
## The pack's word decals are authored enormous — `Word_Zone` is 21.9 m long and
## `Word_Warning` 37 m — because they are meant to be stretched along a hangar
## wall. Placed at a numeric scale they became 14 m flat panels with text on
## them, which is what the second capture of the hall was mostly made of. Here
## each one is scaled to a stated width in metres.


static func sign(
	parent: Node3D, key: String, node_name: String, at: Vector3, yaw: float, room: String
) -> Node3D:
	var family := "word"
	if key.begins_with("sign_"):
		family = "sign"
	elif key.begins_with("num_"):
		family = "num"
	var target: float = SIGN_WIDTH[family]
	var size: Vector3 = ScifiKitLibrary.size(key)
	var longest := maxf(size.z, maxf(size.x, 0.01))
	var scale := target / longest
	return place(parent, key, node_name, at, yaw, scale, "", Vector3.ONE, room)


static func place(
	parent: Node3D,
	key: String,
	node_name: String,
	at: Vector3,
	yaw: float = 0.0,
	scale: float = 1.0,
	collide: String = "box",
	size_scale: Vector3 = Vector3.ONE,
	room: String = ""
) -> Node3D:
	var scene := ScifiKitLibrary.model(key)
	if scene == null:
		return null
	var box: Vector3 = ScifiKitLibrary.size(key) * scale * size_scale
	var min_corner: Vector3 = ScifiKitLibrary.min_corner(key) * scale * size_scale

	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = at
	pivot.rotation_degrees.y = yaw
	if room != "":
		pivot.set_meta("station_room", room)
	parent.add_child(pivot)

	var model := scene.instantiate() as Node3D
	model.name = "Mesh"
	model.add_to_group(&"uploaded_fbx_visual")
	ScifiKitLibrary.apply_palette(model, key)
	model.position = Vector3(
		-(min_corner.x + box.x * 0.5), -min_corner.y, -(min_corner.z + box.z * 0.5)
	)
	model.scale = Vector3.ONE * scale * size_scale
	pivot.add_child(model)

	if collide != "":
		add_collider(pivot, box, collide)
	return pivot


static func add_collider(pivot: Node3D, box: Vector3, mode: String) -> void:
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	if mode == "floor":
		# The deck's top face is the pivot's own Y; the box hangs below it.
		shape.size = Vector3(box.x, 0.4, box.z)
		body.position = Vector3(0.0, -0.2, 0.0)
	elif mode == "portal":
		# A door frame is a hole with metal around it. One solid box across a 5 m
		# doorway is a wall the player cannot walk through, which is what the first
		# run of the station test found: every route stopped at the threshold.
		add_portal(pivot, box)
		return
	else:
		shape.size = Vector3(maxf(box.x, 0.2), maxf(box.y, 0.2), maxf(box.z, 0.2))
		body.position = Vector3(0.0, box.y * 0.5, 0.0)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	pivot.add_child(body)


## Two jambs and a lintel, so the opening in a door frame is actually open.
## The pack's frame module is 5 m wide and 4 m tall; the walkable gap is 4 m by
## 2.9 m, which is what its own visual suggests.
static func add_portal(pivot: Node3D, box: Vector3) -> void:
	var gap := minf(box.x * 0.8, 4.0)
	var head := minf(2.9, box.y - 0.6)
	var jamb := (box.x - gap) * 0.5
	var parts := [
		[Vector3(-(gap * 0.5 + jamb * 0.5), box.y * 0.5, 0.0), Vector3(jamb, box.y, box.z)],
		[Vector3(gap * 0.5 + jamb * 0.5, box.y * 0.5, 0.0), Vector3(jamb, box.y, box.z)],
		[Vector3(0.0, head + (box.y - head) * 0.5, 0.0), Vector3(gap, box.y - head, box.z)],
	]
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	for part in parts:
		var shape := BoxShape3D.new()
		shape.size = part[1]
		var collision := CollisionShape3D.new()
		collision.shape = shape
		collision.position = part[0]
		body.add_child(collision)
	pivot.add_child(body)


func _light(
	parent: Node3D, node_name: String, at: Vector3, color: Color, energy: float, reach: float
) -> void:
	var omni := OmniLight3D.new()
	omni.name = node_name
	omni.position = at
	omni.light_color = color
	omni.light_energy = energy
	omni.omni_range = reach
	omni.shadow_enabled = false
	parent.add_child(omni)
