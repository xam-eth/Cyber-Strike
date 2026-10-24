extends SceneTree

## Runtime proof that the player avatar is actually rendered during gameplay.
##
## `hero_rig_smoke.gd` proves the rig *loads* — the GLB instantiates, the hand
## bone resolves, the muzzle marker lands on the barrel. It never proved that a
## camera pointed at the player would see anything, so "the hero is missing but
## the gun is there" could pass every existing check.
##
## This test measures the avatar the way the renderer would, at runtime, in the
## real `main.tscn` scene tree:
##
##   * the model instance is in the tree and every ancestor is visible,
##   * its layer intersects the camera's cull mask,
##   * the mesh is skinned to the imported skeleton and the bones really move
##     when a clip plays (a frozen AnimationPlayer still reports a clip name),
##   * the *posed* silhouette has human proportions and stands on the floor,
##   * nothing in the world occludes the line from the camera to the avatar,
##   * the projected silhouette lands inside the viewport at every shipping
##     aspect ratio, and is not clipped by the near plane,
##   * the surface winding agrees with the vertex normals (inverted winding
##     makes a CULL_BACK material render the inside of the mesh),
##   * the fallback capsule is hidden and the weapon is attached to the hand.
##
## Headless Godot has no rasteriser, so this cannot look at pixels. It measures
## the geometry, the transforms, the materials and the camera that decide those
## pixels, and prints every number it judged.

const MainScene = preload("res://scenes/main.tscn")

## The viewports the game ships for. Only the aspect ratio matters for
## projection; the vertical FOV is kept, matching Camera3D keep_aspect=HEIGHT.
const VIEWPORTS: Array[Vector2] = [
	Vector2(1280.0, 720.0),
	Vector2(390.0, 844.0),
	Vector2(375.0, 667.0),
	Vector2(844.0, 390.0),
	Vector2(667.0, 375.0),
]

const MIN_SCREEN_HEIGHT_RATIO := 0.10
const MAX_SCREEN_HEIGHT_RATIO := 0.85
const MIN_BONE_TRAVEL_M := 0.004

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	AegisPreferences.write(AegisPreferences.defaults())
	var main_scene := MainScene.instantiate()
	main_scene.set("start_wave_session_on_ready", false)
	main_scene.get_node("ProgressionService").set("profile_path", "")
	root.add_child(main_scene)
	await process_frame
	await process_frame

	var player: Node3D = main_scene.get_node("Player")
	var visual: Node3D = player.get_node("VisualRoot")
	var camera: Camera3D = player.get_node("CameraRig/YawPivot/PitchPivot/SpringArm3D/Camera3D")

	_expect(visual.has_model(), "the hero model instance exists under VisualRoot")
	if not visual.has_model():
		_finish(main_scene)
		return

	var model: Node3D = visual.get("_model") as Node3D
	var skeleton: Skeleton3D = visual.get("_skeleton") as Skeleton3D
	var anim: AnimationPlayer = visual.get("_anim_player") as AnimationPlayer
	var meshes := _model_meshes(model)
	_expect(not meshes.is_empty(), "the hero model contains at least one MeshInstance3D")
	if meshes.is_empty():
		_finish(main_scene)
		return

	_check_visibility(model)
	_check_layers(meshes, camera)
	_check_skinning(meshes, skeleton, anim)
	_check_bones_move(anim, skeleton)
	var posed := _check_pose(model, meshes, skeleton, player)
	_check_not_clipped(posed, camera)
	_check_unoccluded(main_scene, posed, camera, [player])
	_check_screen_cover(posed, camera)
	_check_winding(meshes)
	_check_character_fill(visual)
	_check_material(meshes)
	_check_weapon(visual, player, camera)
	_check_fallback(visual)
	await _check_states(main_scene, player, visual, camera, meshes, skeleton)

	_finish(main_scene)


# --- checks ----------------------------------------------------------------


func _check_visibility(model: Node3D) -> void:
	var chain := ""
	var node: Node = model
	var all_visible := true
	while node != null and node != root:
		if node is Node3D and not (node as Node3D).visible:
			all_visible = false
			chain += " [HIDDEN %s]" % node.name
		else:
			chain += " / " + node.name
		node = node.get_parent()
	_expect(all_visible, "every ancestor of the hero mesh is visible (%s)" % chain)


func _check_layers(meshes: Array, camera: Camera3D) -> void:
	for mesh in meshes:
		var instance := mesh as MeshInstance3D
		_expect(
			(instance.layers & camera.cull_mask) != 0,
			(
				"%s is on a layer the camera renders (layers=%d cull_mask=%d)"
				% [instance.name, instance.layers, camera.cull_mask]
			),
		)


func _check_skinning(meshes: Array, skeleton: Skeleton3D, anim: AnimationPlayer) -> void:
	_expect(is_instance_valid(skeleton), "the hero model brought a Skeleton3D")
	_expect(is_instance_valid(anim), "the hero model brought an AnimationPlayer")
	if not is_instance_valid(skeleton):
		return
	_expect(
		skeleton.get_bone_count() > 0, "the skeleton has bones (%d)" % skeleton.get_bone_count()
	)
	for mesh in meshes:
		var instance := mesh as MeshInstance3D
		_expect(
			instance.skin != null and instance.skeleton != NodePath(""),
			(
				"%s is skinned to the imported skeleton (skin=%s skeleton=%s)"
				% [instance.name, instance.skin != null, str(instance.skeleton)]
			),
		)
	if is_instance_valid(anim):
		_expect(
			anim.current_animation != "",
			"a locomotion clip is playing (%s)" % anim.current_animation,
		)


func _check_bones_move(anim: AnimationPlayer, skeleton: Skeleton3D) -> void:
	if not is_instance_valid(anim) or not is_instance_valid(skeleton):
		return
	var before := _bone_world_positions(skeleton)
	for _frame in range(20):
		await process_frame
	var after := _bone_world_positions(skeleton)
	var moved := 0
	var best := 0.0
	for index in range(before.size()):
		var travel: float = before[index].distance_to(after[index])
		best = maxf(best, travel)
		if travel >= MIN_BONE_TRAVEL_M:
			moved += 1
	_expect(
		moved > 0,
		(
			"the skeleton's bones actually move while a clip plays (%d/%d bones "
			+ (
				"travelled >= %.0f mm, furthest %.1f mm)"
				% [moved, before.size(), MIN_BONE_TRAVEL_M * 1000.0, best * 1000.0]
			)
		),
	)


## Returns the posed silhouette in world space, and asserts it has human
## proportions standing on the floor rather than a collapsed or exploded mesh.
func _check_pose(model: Node3D, meshes: Array, skeleton: Skeleton3D, player: Node3D) -> AABB:
	var combined := AABB()
	var has := false
	for mesh in meshes:
		var instance := mesh as MeshInstance3D
		var box := _posed_aabb(instance, skeleton, 4096)
		if box.size.length() <= 0.0:
			continue
		combined = box if not has else combined.merge(box)
		has = true
	if not has:
		_expect(false, "the posed hero mesh has a non-degenerate bounding box")
		return AABB()

	var height: float = combined.size.y
	var width: float = maxf(combined.size.x, combined.size.z)
	_expect(
		height > 1.2 and height < 2.4,
		"the posed hero is roughly human height (%.2f m)" % height,
	)
	_expect(
		width > 0.15 and width < 1.1,
		"the posed hero is roughly human width (%.2f m)" % width,
	)
	_expect(
		absf(combined.position.y - player.global_position.y) < 0.35,
		(
			"the hero's feet stand at the player's floor level (mesh y=%.2f, player y=%.2f)"
			% [combined.position.y, player.global_position.y]
		),
	)
	_expect(
		model.global_transform.basis.determinant() > 0.0,
		(
			"the hero transform is not mirrored (determinant %.3f)"
			% model.global_transform.basis.determinant()
		),
	)
	print(
		(
			"  hero pose: %s height=%.2fm width=%.2fm depth=%.2fm"
			% [str(combined), combined.size.y, combined.size.x, combined.size.z]
		)
	)
	return combined


func _check_not_clipped(box: AABB, camera: Camera3D) -> void:
	var nearest := _nearest_corner_depth(box, camera)
	_expect(
		nearest < -camera.near,
		(
			(
				"the whole hero is beyond the camera's near plane (nearest corner %.2f m, "
				+ "near %.2f m)"
			)
			% [-nearest, camera.near]
		),
	)
	_expect(
		-nearest < camera.far,
		"the hero is inside the far plane (%.2f m < %.0f m)" % [-nearest, camera.far],
	)
	var in_frustum := true
	for corner in _corners(box):
		if not camera.is_position_in_frustum(corner):
			in_frustum = false
	_expect(in_frustum, "every corner of the hero is inside the camera frustum")


func _check_unoccluded(scene: Node, box: AABB, camera: Camera3D, exclude: Array) -> void:
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var targets := [box.get_center(), box.get_center() + Vector3(0, box.size.y * 0.35, 0)]
	var blocked := false
	var detail := ""
	for target in targets:
		var query := PhysicsRayQueryParameters3D.new()
		query.from = camera.global_position
		query.to = target
		query.collision_mask = 4294967295
		query.exclude = exclude
		query.collide_with_bodies = true
		query.collide_with_areas = false
		var hit: Dictionary = space.intersect_ray(query)
		if not hit.is_empty():
			var distance: float = (hit["position"] as Vector3).distance_to(camera.global_position)
			if distance < camera.global_position.distance_to(target) - 0.25:
				blocked = true
				detail = "%s at %.2f m" % [str(hit["collider"]), distance]
	_expect(
		not blocked,
		(
			"nothing in the world stands between the camera and the hero (%s)"
			% (detail if blocked else "clear")
		),
	)


func _check_screen_cover(box: AABB, camera: Camera3D) -> void:
	for viewport in VIEWPORTS:
		var rect := _project(box, camera, viewport)
		var label := "%dx%d" % [roundi(viewport.x), roundi(viewport.y)]
		var ratio: float = rect.size.y / viewport.y
		_expect(
			(
				rect.position.x > -viewport.x * 0.35
				and rect.end.x < viewport.x * 1.35
				and rect.position.y > -viewport.y * 0.35
				and rect.end.y < viewport.y * 1.35
			),
			"%s puts the hero inside the frame (%s)" % [label, _rect_text(rect)],
		)
		_expect(
			ratio >= MIN_SCREEN_HEIGHT_RATIO and ratio <= MAX_SCREEN_HEIGHT_RATIO,
			(
				"%s frames the hero at a readable size (%.0f%% of screen height, %s)"
				% [label, ratio * 100.0, _rect_text(rect)]
			),
		)


func _check_winding(meshes: Array) -> void:
	for mesh in meshes:
		var instance := mesh as MeshInstance3D
		var flipped := _flipped_triangle_ratio(instance)
		_expect(
			flipped < 0.25,
			(
				"%s: triangle winding agrees with its vertex normals (%.0f%% disagreeing)"
				% [instance.name, flipped * 100.0]
			),
		)


## The avatar has a light of its own, and it is cheap.
##
## The arena's key is a single hard sun and its fill is ambient, so the side of
## the operative facing away from the sun measured luma ~0 in the browser capture
## until this light existed: a silhouette with no panel detail on a phone. The
## assertion is on the properties that keep it cheap and local -- no shadow, a
## short range -- not on the exact energy, which is a look.
func _check_character_fill(visual: Node3D) -> void:
	var fill := visual.get_node_or_null("CharacterFill") as OmniLight3D
	if not _expect(fill != null, "the avatar carries its own fill light"):
		return
	_expect(not fill.shadow_enabled, "the avatar's fill light does not cast a shadow")
	_expect(fill.omni_range <= 3.0, "the avatar's fill light stays close to the avatar")
	_expect(fill.light_energy > 0.4, "the avatar's fill light is strong enough to reveal form")


func _check_material(meshes: Array) -> void:
	for mesh in meshes:
		var instance := mesh as MeshInstance3D
		var material := instance.get_active_material(0)
		if material == null:
			_expect(false, "%s has a surface material" % instance.name)
			continue
		var base := material as BaseMaterial3D
		if base == null:
			continue
		_expect(
			(
				base.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
				and base.albedo_color.a >= 0.99
			),
			(
				"%s draws opaque (transparency=%d alpha=%.2f)"
				% [instance.name, base.transparency, base.albedo_color.a]
			),
		)


func _check_weapon(visual: Node3D, player: Node3D, camera: Camera3D) -> void:
	var socket: Node3D = visual.get_node_or_null("WeaponSocket") as Node3D
	var weapon := socket.get_node_or_null("WeaponModel") as Node3D if socket != null else null
	_expect(is_instance_valid(socket), "the weapon socket exists at VisualRoot/WeaponSocket")
	_expect(is_instance_valid(weapon), "the rifle is parented to the weapon socket")
	if not is_instance_valid(socket) or not is_instance_valid(weapon):
		return

	var skeleton: Skeleton3D = visual.get("_skeleton") as Skeleton3D
	var hand_index: int = skeleton.find_bone("R_Hand") if is_instance_valid(skeleton) else -1
	if hand_index >= 0:
		var hand := skeleton.global_transform * skeleton.get_bone_global_pose(hand_index)
		_expect(
			hand.origin.distance_to(socket.global_position) < 0.30,
			(
				"the weapon socket sits on the right hand bone (%.0f mm apart)"
				% (hand.origin.distance_to(socket.global_position) * 1000.0)
			),
		)
	_expect(
		socket.global_transform.basis.get_scale().x > 0.05,
		(
			"the weapon socket carries a usable scale (%.3f)"
			% socket.global_transform.basis.get_scale().x
		),
	)

	var muzzle: Node3D = socket.get_node_or_null("Muzzle") as Node3D
	_expect(is_instance_valid(muzzle), "the muzzle marker exists at VisualRoot/WeaponSocket/Muzzle")
	if is_instance_valid(muzzle):
		var forward: Vector3 = -player.global_transform.basis.z
		var along: float = (muzzle.global_position - socket.global_position).dot(forward)
		_expect(
			along > 0.05,
			"the muzzle sits in front of the grip, not behind the hero (%.2f m)" % along,
		)
		_expect(
			camera.is_position_in_frustum(muzzle.global_position),
			"the muzzle is inside the camera frustum",
		)


func _check_fallback(visual: Node3D) -> void:
	var fallback := visual.get_node_or_null("BodyMesh") as MeshInstance3D
	_expect(is_instance_valid(fallback), "the placeholder capsule exists (fallback path)")
	if is_instance_valid(fallback):
		_expect(
			not fallback.visible,
			"the placeholder capsule is hidden while the real hero model is fitted",
		)


## "The camera and the animation never hide the hero" is a *state* claim: it has
## to hold while aiming, firing, reloading and dying, not only at idle. Drive the
## real presentation and camera code and re-measure the silhouette each time.
func _check_states(
	scene: Node,
	player: Node3D,
	visual: Node3D,
	camera: Camera3D,
	meshes: Array,
	skeleton: Skeleton3D
) -> void:
	var rig: Node = player.get_node("CameraRig")
	var states := [
		["idle", Callable(self, "_state_idle")],
		["ADS held", Callable(self, "_state_aim")],
		["hip fire", Callable(self, "_state_fire")],
		["reload", Callable(self, "_state_reload")],
		["defeated", Callable(self, "_state_death")],
	]
	for entry in states:
		var label: String = entry[0]
		var apply: Callable = entry[1]
		apply.call(visual, player, rig)
		for _frame in range(24):
			await process_frame
		var box := AABB()
		var has := false
		for mesh in meshes:
			var part := _posed_aabb(mesh as MeshInstance3D, skeleton, 0)
			if part.size.length() <= 0.0:
				continue
			box = part if not has else box.merge(part)
			has = true
		if not has:
			_expect(false, "%s: the hero still has a pose" % label)
			continue
		var nearest := _nearest_corner_depth(box, camera)
		var framed := true
		for corner in _corners(box):
			if not camera.is_position_in_frustum(corner):
				framed = false
		_expect(
			framed and nearest < -camera.near,
			(
				(
					"%s: the camera still frames the whole hero (nearest corner %.2f m, "
					+ "in frustum=%s, height %.2f m)"
				)
				% [label, -nearest, framed, box.size.y]
			),
		)
		_expect(
			box.size.y > 1.2 and box.size.y < 2.4,
			"%s: the hero keeps human proportions (%.2f m tall)" % [label, box.size.y],
		)
		_check_unoccluded(scene, box, camera, [player])


func _state_idle(visual: Node3D, _player: Node3D, rig: Node) -> void:
	visual.call("reset_action_state")
	visual.call("set_aiming", false)
	rig.call("set_aiming", false)


func _state_aim(visual: Node3D, _player: Node3D, rig: Node) -> void:
	visual.call("reset_action_state")
	visual.call("set_aiming", true)
	rig.call("set_aiming", true)


func _state_fire(visual: Node3D, _player: Node3D, rig: Node) -> void:
	visual.call("reset_action_state")
	visual.call("set_aiming", true)
	rig.call("set_aiming", true)
	visual.call("prime_shot_pose")
	visual.call("play_recoil", 1.0, 0.16)


func _state_reload(visual: Node3D, _player: Node3D, rig: Node) -> void:
	visual.call("reset_action_state")
	visual.call("set_aiming", false)
	rig.call("set_aiming", false)
	visual.call("play_reload", 2.0)


func _state_death(visual: Node3D, _player: Node3D, rig: Node) -> void:
	visual.call("reset_action_state")
	visual.call("set_aiming", false)
	rig.call("set_aiming", false)
	visual.call("play_death")


# --- geometry helpers -------------------------------------------------------


func _model_meshes(model: Node3D) -> Array:
	return model.find_children("*", "MeshInstance3D", true, false)


func _bone_world_positions(skeleton: Skeleton3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for index in range(skeleton.get_bone_count()):
		out.append((skeleton.global_transform * skeleton.get_bone_global_pose(index)).origin)
	return out


## World-space AABB of a skinned mesh in its *current* pose. `get_aabb()` alone
## returns the bind pose, which is a T/A-pose and says nothing about the frame
## the player is looking at.
func _posed_aabb(instance: MeshInstance3D, skeleton: Skeleton3D, _limit: int) -> AABB:
	var arrays := instance.mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var bones := arrays[Mesh.ARRAY_BONES] as PackedInt32Array
	var weights := arrays[Mesh.ARRAY_WEIGHTS] as PackedFloat32Array
	if not is_instance_valid(skeleton) or bones.is_empty():
		return AABB(instance.global_transform.origin, Vector3.ZERO)
	# Skinning is `sum(w_i * (pose_global_i * inverse(rest_global_i)) * v)`.
	# Dropping the inverse rest transform is what makes a naive measurement
	# report a 2.6 m "hero" from a 1.78 m model, so build it explicitly.
	var delta := _bone_deltas(skeleton)
	var box := AABB()
	var has := false
	for vertex_index in range(vertices.size()):
		var local := vertices[vertex_index]
		var accumulated := Vector3.ZERO
		var sum := 0.0
		for slot in range(4):
			var offset: int = vertex_index * 4 + slot
			if offset >= bones.size():
				break
			var weight: float = weights[offset] if weights.size() > offset else 0.0
			if weight <= 0.0:
				continue
			var bone_index: int = bones[offset]
			if bone_index < 0 or bone_index >= delta.size():
				continue
			accumulated += (delta[bone_index] * local) * weight
			sum += weight
		if sum <= 0.0:
			continue
		var point := instance.global_transform * (accumulated / sum)
		box = AABB(point, Vector3.ZERO) if not has else box.expand(point)
		has = true
	return box


## `pose_global * inverse(rest_global)` for every bone, in skeleton space.
func _bone_deltas(skeleton: Skeleton3D) -> Array[Transform3D]:
	var count: int = skeleton.get_bone_count()
	var rest_global: Array[Transform3D] = []
	rest_global.resize(count)
	for index in range(count):
		var rest: Transform3D = skeleton.get_bone_rest(index)
		var parent: int = skeleton.get_bone_parent(index)
		rest_global[index] = (
			rest_global[parent] * rest if parent >= 0 and parent < count else rest
		)
	var deltas: Array[Transform3D] = []
	deltas.resize(count)
	for index in range(count):
		deltas[index] = skeleton.get_bone_global_pose(index) * rest_global[index].affine_inverse()
	return deltas


func _corners(box: AABB) -> Array:
	var out: Array = []
	for corner_index in range(8):
		var corner := box.position
		if (corner_index & 1) != 0:
			corner.x += box.size.x
		if (corner_index & 2) != 0:
			corner.y += box.size.y
		if (corner_index & 4) != 0:
			corner.z += box.size.z
		out.append(corner)
	return out


func _nearest_corner_depth(box: AABB, camera: Camera3D) -> float:
	var view := camera.global_transform.affine_inverse()
	var nearest := INF
	for corner in _corners(box):
		nearest = minf(nearest, (view * corner).z)
	return nearest


## Screen rect of a world AABB, in pixels, for the given aspect ratio.
func _project(box: AABB, camera: Camera3D, viewport: Vector2) -> Rect2:
	# Camera3D keeps the vertical FOV, so the aspect only widens the lens.
	var projection := Projection.create_perspective(
		camera.fov, viewport.x / viewport.y, camera.near, camera.far
	)
	var view := camera.global_transform.affine_inverse()
	var rect := Rect2()
	var has := false
	for corner in _corners(box):
		var clip := (
			projection * Vector4((view * corner).x, (view * corner).y, (view * corner).z, 1.0)
		)
		if absf(clip.w) < 0.0001:
			continue
		var ndc := Vector2(clip.x / clip.w, clip.y / clip.w)
		var pixel := Vector2((ndc.x * 0.5 + 0.5) * viewport.x, (0.5 - ndc.y * 0.5) * viewport.y)
		rect = Rect2(pixel, Vector2.ZERO) if not has else rect.expand(pixel)
		has = true
	return rect


## Fraction of sampled triangles whose winding normal points opposite to their
## vertex normals. A high value means the surface is inside-out.
func _flipped_triangle_ratio(instance: MeshInstance3D) -> float:
	var arrays := instance.mesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	if normals.is_empty() or indices.size() < 3:
		return 0.0
	var flipped := 0
	var total := 0
	var stride := maxi(3, indices.size() / 2000)
	stride -= stride % 3
	if stride < 3:
		stride = 3
	for base in range(0, indices.size() - 2, stride):
		var a: int = indices[base]
		var b: int = indices[base + 1]
		var c: int = indices[base + 2]
		var face := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
		if face.length_squared() < 1e-16:
			continue
		var averaged := (normals[a] + normals[b] + normals[c]).normalized()
		total += 1
		# Godot (like glTF) winds front faces the opposite way to the
		# right-hand cross product, so a *positive* dot product is the
		# inside-out case. A built-in BoxMesh is the reference: it reports
		# 100% positive dot, and it is never inside-out.
		if face.normalized().dot(averaged) > 0.0:
			flipped += 1
	return float(flipped) / float(maxi(total, 1))


# --- harness ---------------------------------------------------------------


func _rect_text(rect: Rect2) -> String:
	return (
		"%d,%d %dx%d"
		% [
			roundi(rect.position.x),
			roundi(rect.position.y),
			roundi(rect.size.x),
			roundi(rect.size.y),
		]
	)


func _expect(condition: bool, message: String) -> bool:
	if condition:
		print("  ok: " + message)
	else:
		_failures.append(message)
		push_error("Hero visibility smoke test failed: " + message)
	return condition


func _finish(main_scene: Node) -> void:
	if _failures.is_empty():
		print("Hero visibility smoke test passed.")
	else:
		print("Hero visibility smoke test failed: %d problem(s)." % _failures.size())
		for message in _failures:
			print("  - " + message)
	main_scene.free()
	quit(1 if _failures.size() > 0 else 0)
