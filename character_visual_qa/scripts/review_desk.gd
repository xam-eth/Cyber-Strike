extends Node3D

## Small standalone reviewer for staged character GLBs.
## It reports imported rig/clip structure and provides a rendered viewport.

const MANIFEST_PATH := "res://asset_manifest.json"
const HUMAN_TRACK_ID := "human_operative"
const AUTO_ROTATION_SPEED := 0.18
const MIN_CAMERA_DISTANCE := 1.5
const MAX_CAMERA_DISTANCE := 14.0

var _assets: Array[Dictionary] = []
var _tier_asset_indices: Array[int] = []
var _other_asset_indices: Array[int] = []
var _asset_index := -1
var _current_asset: Dictionary = {}
var _current_instance: Node3D
var _fit_wrapper: Node3D
var _model_pivot: Node3D
var _orbit_pivot: Node3D
var _camera: Camera3D
var _preview_height := 1.78
var _camera_distance := 5.7
var _auto_rotate := true
var _dragging := false
var _pose_probe_active := false
var _playback_speed := 1.0

var _animation_players: Array[AnimationPlayer] = []
var _animation_records: Array[Dictionary] = []
var _available_clip_names: Array[String] = []
var _skeletons: Array[Skeleton3D] = []
var _mesh_count := 0
var _skinned_mesh_count := 0
var _joint_count := 0

var _tier_row: HBoxContainer
var _tier_buttons: Array[Button] = []
var _other_selector: OptionButton
var _asset_title: Label
var _asset_details: Label
var _contract_status: Label
var _clip_selector: OptionButton
var _clip_status: Label
var _play_button: Button
var _pause_button: Button
var _stop_button: Button
var _pose_button: Button
var _reset_pose_button: Button


func _ready() -> void:
	_create_stage()
	_load_manifest()
	_create_interface()
	if _assets.is_empty():
		_show_empty_project()
		return
	var first_asset := _tier_asset_indices[0] if not _tier_asset_indices.is_empty() else 0
	await _load_asset(first_asset)


func _process(delta: float) -> void:
	if _auto_rotate and is_instance_valid(_model_pivot):
		_model_pivot.rotate_y(delta * AUTO_ROTATION_SPEED)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mouse_event.pressed and _is_viewport_position(mouse_event.position)
		elif mouse_event.pressed and _is_viewport_position(mouse_event.position):
			if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_set_camera_distance(_camera_distance - 0.35)
			elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_set_camera_distance(_camera_distance + 0.35)
	elif event is InputEventMouseMotion and _dragging and is_instance_valid(_orbit_pivot):
		var motion := event as InputEventMouseMotion
		_orbit_pivot.rotate_y(-motion.relative.x * 0.006)
		_orbit_pivot.rotation.x = clampf(
			_orbit_pivot.rotation.x - motion.relative.y * 0.005, -1.1, 1.1
		)
	elif event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		match key_event.keycode:
			KEY_LEFT:
				_select_relative(-1)
				get_viewport().set_input_as_handled()
			KEY_RIGHT:
				_select_relative(1)
				get_viewport().set_input_as_handled()
			KEY_R:
				_reset_view()
				get_viewport().set_input_as_handled()
			KEY_SPACE:
				_play_selected_clip()
				get_viewport().set_input_as_handled()


func _create_stage() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#0b1520")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#8398aa")
	environment.ambient_light_energy = 0.65
	world.environment = environment
	add_child(world)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	key_light.light_color = Color("#e5f1ff")
	key_light.light_energy = 1.6
	key_light.shadow_enabled = true
	add_child(key_light)

	var floor_instance := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(32.0, 32.0)
	floor_instance.mesh = floor_mesh
	floor_instance.position.y = -0.025
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("#18232d")
	floor_material.roughness = 0.86
	floor_instance.material_override = floor_material
	add_child(floor_instance)

	_model_pivot = Node3D.new()
	_model_pivot.name = "ModelTurntable"
	add_child(_model_pivot)

	_orbit_pivot = Node3D.new()
	_orbit_pivot.name = "CameraOrbit"
	add_child(_orbit_pivot)
	_camera = Camera3D.new()
	_camera.name = "ReviewCamera"
	_camera.current = true
	_camera.fov = 39.0
	_orbit_pivot.add_child(_camera)
	_orbit_pivot.position = Vector3(0.0, _preview_height * 0.5, 0.0)
	_set_camera_distance(_camera_distance)


func _load_manifest() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_error("Character QA manifest is missing: %s" % MANIFEST_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		push_error("Character QA manifest must be a JSON object.")
		return
	var entries: Variant = parsed.get("assets", [])
	if not entries is Array:
		push_error("Character QA manifest must contain an assets array.")
		return
	for entry in entries:
		if entry is Dictionary:
			_assets.append(entry)
	for index in range(_assets.size()):
		var entry: Dictionary = _assets[index]
		var identity: Dictionary = entry.get("asset_identity", {})
		var is_game_runtime_preview := str(entry.get("qa_group", "")) == "game_runtime_preview"
		if (
			not is_game_runtime_preview
			and (
				str(identity.get("role", "")) == "hero"
				or str(entry.get("upgrade_track_id", "")) == HUMAN_TRACK_ID
			)
		):
			_tier_asset_indices.append(index)
		else:
			_other_asset_indices.append(index)
	_tier_asset_indices.sort_custom(_sort_tier_indices)


func _sort_tier_indices(left: int, right: int) -> bool:
	var left_identity: Dictionary = _assets[left].get("asset_identity", {})
	var right_identity: Dictionary = _assets[right].get("asset_identity", {})
	var left_tier := int(left_identity.get("tier_number", _assets[left].get("upgrade_tier", 0)))
	var right_tier := int(right_identity.get("tier_number", _assets[right].get("upgrade_tier", 0)))
	return left_tier < right_tier


func _create_interface() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ReviewInterface"
	add_child(layer)
	var screen := Control.new()
	screen.name = "Screen"
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(screen)

	var sidebar := PanelContainer.new()
	sidebar.name = "SelectionPanel"
	sidebar.anchor_bottom = 1.0
	sidebar.offset_left = 16.0
	sidebar.offset_top = 16.0
	sidebar.offset_right = 316.0
	sidebar.offset_bottom = -16.0
	_style_panel(sidebar)
	screen.add_child(sidebar)
	var sidebar_column := VBoxContainer.new()
	sidebar_column.add_theme_constant_override("separation", 10)
	sidebar.add_child(sidebar_column)

	sidebar_column.add_child(_label("CHARACTER QA", 22, Color("#8ce6ff")))
	sidebar_column.add_child(
		_label("Rendered GLB · rig and animation checks", 11, Color("#a7b8c5"))
	)
	sidebar_column.add_child(_label("HUMAN HERO · ONE TRACK", 12, Color("#d9e7ef")))
	_tier_row = HBoxContainer.new()
	_tier_row.add_theme_constant_override("separation", 5)
	sidebar_column.add_child(_tier_row)
	for asset_index in _tier_asset_indices:
		var identity: Dictionary = _assets[asset_index].get("asset_identity", {})
		var tier := int(identity.get("tier_number", _assets[asset_index].get("upgrade_tier", 0)))
		var button := Button.new()
		button.text = "T%d" % tier
		button.tooltip_text = str(_assets[asset_index].get("label", "Tier %d" % tier))
		button.custom_minimum_size = Vector2(46.0, 36.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.set_meta("asset_index", asset_index)
		button.pressed.connect(_select_asset.bind(asset_index))
		_tier_row.add_child(button)
		_tier_buttons.append(button)
	if _tier_asset_indices.is_empty():
		_tier_row.add_child(_label("No T1–T5 entries in the manifest.", 11, Color("#a7b8c5")))

	sidebar_column.add_child(HSeparator.new())
	sidebar_column.add_child(_label("OTHER MODELS", 12, Color("#d9e7ef")))
	_other_selector = OptionButton.new()
	_other_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_other_selector.add_item("Select an enemy or source…")
	_other_selector.set_item_metadata(0, -1)
	for asset_index in _other_asset_indices:
		var entry: Dictionary = _assets[asset_index]
		var label := str(entry.get("label", entry.get("id", "Character")))
		_other_selector.add_item(label)
		_other_selector.set_item_metadata(_other_selector.item_count - 1, asset_index)
	_other_selector.select(0)
	_other_selector.item_selected.connect(_on_other_asset_selected)
	sidebar_column.add_child(_other_selector)
	_other_selector.disabled = _other_asset_indices.is_empty()

	var view_row := HBoxContainer.new()
	view_row.add_theme_constant_override("separation", 6)
	sidebar_column.add_child(view_row)
	var reset_view_button := Button.new()
	reset_view_button.text = "RESET VIEW"
	reset_view_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_view_button.pressed.connect(_reset_view)
	view_row.add_child(reset_view_button)
	var rotate_toggle := CheckButton.new()
	rotate_toggle.text = "Rotate"
	rotate_toggle.button_pressed = true
	rotate_toggle.toggled.connect(_on_auto_rotate_toggled)
	view_row.add_child(rotate_toggle)

	sidebar_column.add_child(HSeparator.new())
	sidebar_column.add_child(
		_label(
			"Drag to orbit · wheel to zoom\n← / → changes model · R resets view",
			11,
			Color("#a7b8c5")
		)
	)
	var sidebar_spacer := Control.new()
	sidebar_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar_column.add_child(sidebar_spacer)
	sidebar_column.add_child(
		_label("Original enemy GLBs are listed as review-only sources.", 10, Color("#8195a3"))
	)

	var info_panel := PanelContainer.new()
	info_panel.name = "AssetInfo"
	info_panel.anchor_left = 1.0
	info_panel.anchor_right = 1.0
	info_panel.offset_left = -386.0
	info_panel.offset_right = -16.0
	info_panel.offset_top = 16.0
	info_panel.offset_bottom = 300.0
	_style_panel(info_panel)
	screen.add_child(info_panel)
	var info_column := VBoxContainer.new()
	info_column.add_theme_constant_override("separation", 7)
	info_panel.add_child(info_column)
	_asset_title = _label("Select a model", 20, Color("#ffffff"))
	info_column.add_child(_asset_title)
	_asset_details = _label("", 12, Color("#c3d0da"))
	_asset_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_column.add_child(_asset_details)
	_contract_status = _label("STRUCTURE CHECK: —", 12, Color("#ffd27a"))
	_contract_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_column.add_child(_contract_status)

	var animation_panel := PanelContainer.new()
	animation_panel.name = "RigAndAnimationControls"
	animation_panel.anchor_left = 0.0
	animation_panel.anchor_right = 1.0
	animation_panel.anchor_top = 1.0
	animation_panel.anchor_bottom = 1.0
	animation_panel.offset_left = 332.0
	animation_panel.offset_right = -16.0
	animation_panel.offset_top = -142.0
	animation_panel.offset_bottom = -16.0
	_style_panel(animation_panel)
	screen.add_child(animation_panel)
	var animation_column := VBoxContainer.new()
	animation_column.add_theme_constant_override("separation", 7)
	animation_panel.add_child(animation_column)
	animation_column.add_child(_label("RIG & ANIMATION", 12, Color("#d9e7ef")))

	var clip_row := HBoxContainer.new()
	clip_row.add_theme_constant_override("separation", 6)
	animation_column.add_child(clip_row)
	_clip_selector = OptionButton.new()
	_clip_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clip_selector.item_selected.connect(_on_clip_selected)
	clip_row.add_child(_clip_selector)
	_play_button = Button.new()
	_play_button.text = "PLAY"
	_play_button.pressed.connect(_play_selected_clip)
	clip_row.add_child(_play_button)
	_pause_button = Button.new()
	_pause_button.text = "PAUSE"
	_pause_button.pressed.connect(_pause_playback)
	clip_row.add_child(_pause_button)
	_stop_button = Button.new()
	_stop_button.text = "STOP"
	_stop_button.pressed.connect(_stop_playback)
	clip_row.add_child(_stop_button)
	var speed_selector := OptionButton.new()
	speed_selector.custom_minimum_size = Vector2(84.0, 0.0)
	for speed in [0.5, 1.0, 1.5, 2.0]:
		speed_selector.add_item("%s×" % str(speed))
		speed_selector.set_item_metadata(speed_selector.item_count - 1, speed)
	speed_selector.select(1)
	speed_selector.item_selected.connect(_on_speed_selected.bind(speed_selector))
	clip_row.add_child(speed_selector)

	var rig_row := HBoxContainer.new()
	rig_row.add_theme_constant_override("separation", 6)
	animation_column.add_child(rig_row)
	_pose_button = Button.new()
	_pose_button.text = "TEST SKIN POSE"
	_pose_button.pressed.connect(_run_pose_probe)
	rig_row.add_child(_pose_button)
	_reset_pose_button = Button.new()
	_reset_pose_button.text = "RESET POSE"
	_reset_pose_button.pressed.connect(_reset_pose_probe)
	rig_row.add_child(_reset_pose_button)
	_clip_status = _label("Choose a clip to inspect, or test the skin pose.", 11, Color("#a7b8c5"))
	_clip_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rig_row.add_child(_clip_status)
	_update_control_state()


func _style_panel(panel: PanelContainer) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.065, 0.94)
	style.border_color = Color(0.10, 0.35, 0.46, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12.0
	style.content_margin_top = 10.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)


func _label(text: String, size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	return result


func _show_empty_project() -> void:
	_asset_title.text = "No QA assets"
	_asset_details.text = "Check character_visual_qa/asset_manifest.json."
	_contract_status.text = "Run character_visual_qa/tools/sync_assets.py after adding assets."
	_clip_status.text = "No model loaded."
	_update_control_state()


func _on_other_asset_selected(option_index: int) -> void:
	if option_index < 0 or option_index >= _other_selector.item_count:
		return
	var asset_index := int(_other_selector.get_item_metadata(option_index))
	if asset_index >= 0:
		await _load_asset(asset_index)


func _select_asset(index: int) -> void:
	if index < 0 or index >= _assets.size():
		return
	if index == _asset_index and is_instance_valid(_current_instance):
		return
	await _load_asset(index)


func _select_relative(offset: int) -> void:
	if _assets.is_empty():
		return
	var next_index := posmod(_asset_index + offset, _assets.size())
	await _load_asset(next_index)


func _load_asset(index: int) -> void:
	if index < 0 or index >= _assets.size():
		return
	_asset_index = index
	_current_asset = _assets[index]
	_update_selection_controls()
	_clear_loaded_model()
	_asset_title.text = str(_current_asset.get("label", _current_asset.get("id", "Character")))
	_asset_details.text = "Loading staged GLB…"
	_contract_status.text = "STRUCTURE CHECK: RUNNING"
	_contract_status.add_theme_color_override("font_color", Color("#ffd27a"))
	_clip_status.text = "Reading imported model…"

	var qa_file := str(_current_asset.get("qa_file", ""))
	if qa_file.is_empty():
		_show_asset_error("Manifest entry has no qa_file path.")
		return
	var file_path := "res://%s" % qa_file
	if not FileAccess.file_exists(file_path):
		var sync_hint := "Run python3 character_visual_qa/tools/sync_assets.py from the repository root."
		_show_asset_error("Staged GLB is missing: %s\n%s" % [file_path, sync_hint])
		return

	var packed_scene := ResourceLoader.load(file_path) as PackedScene
	if packed_scene == null:
		_show_asset_error("Godot could not import this GLB as a PackedScene: %s" % file_path)
		return
	var instance := packed_scene.instantiate()
	if not instance is Node3D:
		instance.queue_free()
		_show_asset_error("Imported GLB root is not a Node3D.")
		return

	_fit_wrapper = Node3D.new()
	_fit_wrapper.name = "PreviewFit"
	_model_pivot.add_child(_fit_wrapper)
	_current_instance = instance as Node3D
	_current_instance.name = "ReviewedGLB"
	_fit_wrapper.add_child(_current_instance)
	await get_tree().process_frame
	if not _fit_model():
		_show_asset_error("No usable mesh bounds were found in this GLB.")
		return
	_inspect_instance()
	_build_clip_selector()
	_update_structure_report()
	_update_control_state()


func _clear_loaded_model() -> void:
	_stop_playback()
	_reset_pose_probe()
	if is_instance_valid(_fit_wrapper):
		_fit_wrapper.queue_free()
	_fit_wrapper = null
	_current_instance = null
	_model_pivot.position = Vector3.ZERO
	_model_pivot.rotation = Vector3.ZERO
	_orbit_pivot.position = Vector3(0.0, _preview_height * 0.5, 0.0)
	_orbit_pivot.rotation = Vector3.ZERO
	_animation_players.clear()
	_animation_records.clear()
	_available_clip_names.clear()
	_skeletons.clear()
	_mesh_count = 0
	_skinned_mesh_count = 0
	_joint_count = 0
	_pose_probe_active = false
	if _clip_selector != null:
		_clip_selector.clear()
	_clip_status.text = "Choose a clip to inspect, or test the skin pose."
	_update_control_state()


func _show_asset_error(message: String) -> void:
	_asset_details.text = message
	_contract_status.text = "STRUCTURE CHECK: CANNOT LOAD"
	_contract_status.add_theme_color_override("font_color", Color("#ff8a84"))
	_clip_status.text = "No model loaded."
	_update_control_state()


func _fit_model() -> bool:
	var bounds := _measure_bounds(_current_instance)
	if bounds.size.y <= 0.001:
		return false
	_preview_height = float(_current_asset.get("preview_height_m", 1.78))
	var scale_factor := _preview_height / bounds.size.y
	_fit_wrapper.scale = Vector3.ONE * scale_factor
	_fit_wrapper.position = -bounds.get_center() * scale_factor
	_model_pivot.position = Vector3(0.0, _preview_height * 0.5, 0.0)
	_model_pivot.rotation = Vector3(0.0, _base_yaw(), 0.0)
	_orbit_pivot.position = _model_pivot.position
	_set_camera_distance(_preview_height * 3.2)
	return true


func _base_yaw() -> float:
	return deg_to_rad(float(_current_asset.get("preview_yaw_degrees", 0.0)))


func _measure_bounds(root: Node3D) -> AABB:
	var mesh_nodes: Array[Node] = []
	if root is MeshInstance3D:
		mesh_nodes.append(root)
	mesh_nodes.append_array(root.find_children("*", "MeshInstance3D", true, false))
	var has_bounds := false
	var bounds := AABB()
	for node in mesh_nodes:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var mesh_bounds := _transform_bounds(
			mesh_instance.global_transform, mesh_instance.get_aabb()
		)
		if not has_bounds:
			bounds = mesh_bounds
			has_bounds = true
		else:
			bounds = bounds.merge(mesh_bounds)
	return bounds if has_bounds else AABB()


func _transform_bounds(transform: Transform3D, source: AABB) -> AABB:
	var start := source.position
	var finish := source.position + source.size
	var first_point := transform * start
	var result := AABB(first_point, Vector3.ZERO)
	for x in [start.x, finish.x]:
		for y in [start.y, finish.y]:
			for z in [start.z, finish.z]:
				result = result.expand(transform * Vector3(x, y, z))
	return result


func _inspect_instance() -> void:
	var mesh_nodes: Array[Node] = []
	if _current_instance is MeshInstance3D:
		mesh_nodes.append(_current_instance)
	mesh_nodes.append_array(_current_instance.find_children("*", "MeshInstance3D", true, false))
	_mesh_count = mesh_nodes.size()
	for node in mesh_nodes:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance != null and mesh_instance.get("skin") != null:
			_skinned_mesh_count += 1

	var skeleton_nodes: Array[Node] = []
	if _current_instance is Skeleton3D:
		skeleton_nodes.append(_current_instance)
	skeleton_nodes.append_array(_current_instance.find_children("*", "Skeleton3D", true, false))
	for node in skeleton_nodes:
		var skeleton := node as Skeleton3D
		if skeleton != null:
			_skeletons.append(skeleton)
			_joint_count += skeleton.get_bone_count()

	var player_nodes: Array[Node] = []
	player_nodes.append_array(_current_instance.find_children("*", "AnimationPlayer", true, false))
	for node in player_nodes:
		var player := node as AnimationPlayer
		if player == null:
			continue
		_animation_players.append(player)
		for animation_name in player.get_animation_list():
			var clip_name := str(animation_name)
			var animation := player.get_animation(animation_name)
			(
				_animation_records
				. append(
					{
						"player": player,
						"player_name": str(player.name),
						"clip": clip_name,
						"duration": animation.length if animation != null else 0.0,
					}
				)
			)
			if not _available_clip_names.has(clip_name):
				_available_clip_names.append(clip_name)


func _build_clip_selector() -> void:
	_clip_selector.clear()
	var default_index := 0
	for index in range(_animation_records.size()):
		var record: Dictionary = _animation_records[index]
		var clip_name := str(record.get("clip", ""))
		var duration := float(record.get("duration", 0.0))
		_clip_selector.add_item("%s · %.2f s" % [_clip_display_name(clip_name), duration])
		_clip_selector.set_item_metadata(index, index)
		if clip_name == "idle":
			default_index = index
	if _animation_records.is_empty():
		_clip_status.text = "No animation clips in this model."
		return
	_clip_selector.select(default_index)
	_on_clip_selected(default_index)


func _clip_display_name(clip_name: String) -> String:
	var names := {
		"idle": "Idle / Breathing",
		"walk": "Walk",
		"run": "Run",
		"raise_weapon": "Raise Weapon",
		"aim": "Aim / Ready",
		"aim_walk": "Aim Walk",
		"aim_run": "Aim Run",
		"fire": "Fire / Recoil",
		"reload": "Reload",
		"hit": "Hit Reaction",
		"death": "Death",
		"lower_weapon": "Lower Weapon",
	}
	return str(names.get(clip_name, clip_name.replace("_", " ").capitalize()))


func _update_structure_report() -> void:
	var errors: Array[String] = []
	var expected_joints := int(_current_asset.get("expected_joint_count", 0))
	var expected_clips: Array = _current_asset.get("expected_animation_names", [])
	if _mesh_count == 0:
		errors.append("no mesh")
	if bool(_current_asset.get("requires_skin", false)) and _skinned_mesh_count == 0:
		errors.append("no skinned mesh")
	if expected_joints > 0 and _joint_count != expected_joints:
		errors.append("skeleton should have %d joints" % expected_joints)
	var missing_clips: Array[String] = []
	for clip_name in expected_clips:
		if not _available_clip_names.has(str(clip_name)):
			missing_clips.append(str(clip_name))
	if not missing_clips.is_empty():
		errors.append("missing clips: %s" % ", ".join(PackedStringArray(missing_clips)))

	var identity: Dictionary = _current_asset.get("asset_identity", {})
	var identity_id := str(identity.get("asset_id", ""))
	var identity_role := str(identity.get("role", ""))
	var identity_species := str(identity.get("species", ""))
	var asset_kind := str(_current_asset.get("asset_kind", ""))
	if identity_id.is_empty():
		errors.append("missing canonical role/tier identity")
	else:
		var expected_glb_name := (
			"%s.glb" % identity_id if asset_kind == "runtime" else "%s_source.glb" % identity_id
		)
		if str(_current_asset.get("glb_label", "")) != expected_glb_name:
			errors.append("GLB name does not match canonical asset identity")
		if identity_role == "hero":
			var identity_tier := int(identity.get("tier_number", 0))
			if identity_species != "human":
				errors.append("player hero identity must be human")
			if str(_current_asset.get("upgrade_track_id", "")) != HUMAN_TRACK_ID:
				errors.append("human tiers must share the human_operative progression track")
			if (
				int(_current_asset.get("upgrade_tier", 0)) != identity_tier
				or identity_tier < 1
				or identity_tier > 5
			):
				errors.append("selected human model and canonical T1–T5 identity do not match")
		elif identity_role == "enemy":
			if identity_species != "robot":
				errors.append("robot character identity must remain an enemy")
			if (
				_current_asset.get("upgrade_track_id") != null
				or _current_asset.get("upgrade_tier") != null
			):
				errors.append("enemy model must not use the human hero progression track")
			if identity_id == "enemy_robot_common":
				if (
					identity.get("tier_number") != null
					or str(identity.get("rarity", "")) != "common"
				):
					errors.append("Robot Common must stay Common; do not infer T1")
		else:
			errors.append("identity role must be hero or enemy")

	var source := str(_current_asset.get("source", ""))
	var details := [
		"Identity: %s · %s" % [identity_role.to_upper(), identity_species.to_upper()],
		"Asset kind: %s" % asset_kind.replace("_", " ").to_upper(),
		"GLB: %s" % _current_asset.get("glb_label", "unknown.glb"),
		"Category: %s" % _current_asset.get("category", "CHARACTER"),
		"Source: %s" % source,
		"Meshes: %d · skinned: %d" % [_mesh_count, _skinned_mesh_count],
	]
	if identity_role == "hero":
		details.append(
			(
				"Progression: Human Operative · %s of 5"
				% str(identity.get("tier_label", "Unknown tier"))
			)
		)
	elif identity_role == "enemy":
		var enemy_tier_label := str(identity.get("tier_label", ""))
		if not enemy_tier_label.is_empty():
			details.append("Enemy tier / rarity: %s" % enemy_tier_label)
		else:
			details.append(
				"Enemy class: %s" % str(identity.get("enemy_class", "unspecified")).capitalize()
			)
		if str(identity.get("animation_reference_for", "")) == HUMAN_TRACK_ID:
			details.append("Animation reference for: Human Operative player hero")
	if expected_joints > 0:
		details.append("Skeleton: %d / %d joints" % [_joint_count, expected_joints])
	else:
		details.append("Skeleton: %d joints · none required" % _joint_count)
	if expected_clips.is_empty():
		details.append("Animation clips: %d · none required" % _available_clip_names.size())
	else:
		details.append(
			(
				"Required clips found: %d / %d"
				% [expected_clips.size() - missing_clips.size(), expected_clips.size()]
			)
		)
	if bool(_current_asset.get("review_only", false)):
		details.append("Review-only asset")
	var original_source := str(_current_asset.get("original_source", ""))
	if not original_source.is_empty():
		details.append("Original source: %s" % original_source)
	var rig_profile := str(_current_asset.get("rig_profile", ""))
	if not rig_profile.is_empty():
		details.append("Rig profile: %s" % rig_profile)
	_asset_details.text = "\n".join(PackedStringArray(details))

	if errors.is_empty():
		_contract_status.text = "STRUCTURE CHECK: OK · visual review still required"
		_contract_status.add_theme_color_override("font_color", Color("#86e0a5"))
	else:
		_contract_status.text = (
			"STRUCTURE CHECK: CHECK\n• %s" % "\n• ".join(PackedStringArray(errors))
		)
		_contract_status.add_theme_color_override("font_color", Color("#ff8a84"))


func _update_selection_controls() -> void:
	for button in _tier_buttons:
		var button_index := int(button.get_meta("asset_index", -1))
		button.button_pressed = button_index == _asset_index
	if _other_selector == null:
		return
	for option_index in range(1, _other_selector.item_count):
		if int(_other_selector.get_item_metadata(option_index)) == _asset_index:
			_other_selector.select(option_index)
			return
	_other_selector.select(0)


func _on_clip_selected(index: int) -> void:
	if index < 0 or index >= _animation_records.size():
		return
	_stop_playback()
	var record: Dictionary = _animation_records[index]
	var clip_name := str(record.get("clip", ""))
	_clip_status.text = (
		"Selected: %s · %.2f s"
		% [
			_clip_display_name(clip_name),
			float(record.get("duration", 0.0)),
		]
	)


func _play_selected_clip() -> void:
	if _clip_selector == null or _clip_selector.selected < 0:
		return
	var record: Dictionary = _animation_records[_clip_selector.selected]
	var player := record.get("player") as AnimationPlayer
	if player == null:
		return
	if _pose_probe_active:
		_reset_pose_probe()
	_stop_playback()
	player.speed_scale = _playback_speed
	player.play(str(record.get("clip", "")))
	_clip_status.text = "Playing: %s" % _clip_display_name(str(record.get("clip", "")))


func _pause_playback() -> void:
	for player in _animation_players:
		if player.is_playing():
			player.pause()
	_clip_status.text = "Paused. Press PLAY to restart the selected clip."


func _stop_playback() -> void:
	for player in _animation_players:
		player.stop()
	if (
		_clip_status != null
		and _clip_selector != null
		and not _animation_records.is_empty()
		and _clip_selector.selected >= 0
	):
		_clip_status.text = (
			"Selected: %s" % str(_clip_selector.get_item_text(_clip_selector.selected))
		)


func _on_speed_selected(index: int, selector: OptionButton) -> void:
	if index < 0:
		return
	_playback_speed = float(selector.get_item_metadata(index))
	for player in _animation_players:
		player.speed_scale = _playback_speed


func _run_pose_probe() -> void:
	if _skeletons.is_empty():
		return
	_stop_playback()
	var changed_bones := 0
	for skeleton in _skeletons:
		skeleton.reset_bone_poses()
		changed_bones += int(_pose_bone(skeleton, "L_Upperarm", Vector3.FORWARD, -38.0))
		changed_bones += int(_pose_bone(skeleton, "R_Upperarm", Vector3.FORWARD, 38.0))
		changed_bones += int(_pose_bone(skeleton, "L_Forearm", Vector3.RIGHT, -42.0))
		changed_bones += int(_pose_bone(skeleton, "R_Forearm", Vector3.RIGHT, 42.0))
		changed_bones += int(_pose_bone(skeleton, "L_Thigh", Vector3.RIGHT, -18.0))
		changed_bones += int(_pose_bone(skeleton, "R_Thigh", Vector3.RIGHT, 18.0))
	_pose_probe_active = changed_bones > 0
	if _pose_probe_active:
		_clip_status.text = (
			"Skin pose test active (%d bones). Inspect bends, then reset." % changed_bones
		)
	else:
		_clip_status.text = "No compatible arm/leg bones found for the pose test."


func _pose_bone(skeleton: Skeleton3D, bone_name: String, axis: Vector3, degrees: float) -> bool:
	var bone_index := skeleton.find_bone(bone_name)
	if bone_index < 0:
		return false
	var current_rotation := skeleton.get_bone_pose_rotation(bone_index)
	var test_rotation := Quaternion(axis.normalized(), deg_to_rad(degrees))
	skeleton.set_bone_pose_rotation(bone_index, current_rotation * test_rotation)
	return true


func _reset_pose_probe() -> void:
	for skeleton in _skeletons:
		skeleton.reset_bone_poses()
	_pose_probe_active = false
	if _clip_status != null and not _skeletons.is_empty():
		_clip_status.text = "Skin pose reset."


func _update_control_state() -> void:
	var has_model := is_instance_valid(_current_instance)
	var has_clips := not _animation_records.is_empty()
	var has_skeleton := not _skeletons.is_empty()
	if _clip_selector != null:
		_clip_selector.disabled = not has_clips
	if _play_button != null:
		_play_button.disabled = not has_clips
	if _pause_button != null:
		_pause_button.disabled = not has_clips
	if _stop_button != null:
		_stop_button.disabled = not has_clips
	if _pose_button != null:
		_pose_button.disabled = not has_model or not has_skeleton
	if _reset_pose_button != null:
		_reset_pose_button.disabled = not has_model or not has_skeleton


func _reset_view() -> void:
	if is_instance_valid(_orbit_pivot):
		_orbit_pivot.rotation = Vector3.ZERO
	if is_instance_valid(_model_pivot):
		_model_pivot.rotation = Vector3(0.0, _base_yaw(), 0.0)
	_set_camera_distance(_preview_height * 3.2)


func _set_camera_distance(distance: float) -> void:
	_camera_distance = clampf(distance, MIN_CAMERA_DISTANCE, MAX_CAMERA_DISTANCE)
	if not is_instance_valid(_camera):
		return
	_camera.position = Vector3(0.0, _preview_height * 0.12, _camera_distance)
	if is_instance_valid(_orbit_pivot):
		_camera.look_at(_orbit_pivot.global_position, Vector3.UP)


func _on_auto_rotate_toggled(enabled: bool) -> void:
	_auto_rotate = enabled


func _is_viewport_position(position: Vector2) -> bool:
	var window_size := get_viewport().get_visible_rect().size
	return (
		position.x > 320.0
		and position.x < window_size.x - 390.0
		and position.y > 300.0
		and position.y < window_size.y - 150.0
	)
