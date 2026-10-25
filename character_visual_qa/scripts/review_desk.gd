extends Node3D

## Interactive, rendered Godot review desk for character GLBs. Each asset is
## loaded as an imported PackedScene, previewed in the 3D viewport, and reviewed
## clip-by-clip before the approval gate accepts it.

const MANIFEST_PATH := "res://asset_manifest.json"
const RESULTS_PATH := "res://review_results.json"
const AUTO_ROTATION_SPEED := 0.18
const MIN_CAMERA_DISTANCE := 2.0
const MAX_CAMERA_DISTANCE := 12.0
const CHECK_DEFINITIONS := [
	{"id": "visual", "label": "Model visible; silhouette and shape look correct"},
	{"id": "materials", "label": "Materials, colors and textures look correct"},
	{"id": "scale_pose", "label": "Scale, facing direction and rest pose look correct"},
	{"id": "skin", "label": "Skeleton and skin deformation look correct"},
	{"id": "animations", "label": "Every required animation clip looks correct"},
	{"id": "import", "label": "No missing textures, broken parts or import warnings"},
]

var _assets: Array[Dictionary] = []
var _review_data: Dictionary = {}
var _sync_data: Dictionary = {}
var _asset_index: int = -1
var _current_asset: Dictionary = {}
var _current_hash: String = ""
var _current_instance: Node3D
var _fit_wrapper: Node3D
var _model_pivot: Node3D
var _orbit_pivot: Node3D
var _camera: Camera3D
var _base_model_yaw: float = 0.0
var _preview_height: float = 1.78
var _dragging: bool = false
var _auto_rotate: bool = true
var _pose_probe_active: bool = false
var _loading_controls: bool = false

var _animation_players: Array[AnimationPlayer] = []
var _skeletons: Array[Skeleton3D] = []
var _animation_records: Array[Dictionary] = []
var _available_clip_names: Array[String] = []
var _reviewed_clips: Array[String] = []
var _played_clip_names: Array[String] = []
var _automated_errors: Array[String] = []
var _automated_report: Dictionary = {}
var _mesh_count: int = 0
var _skin_mesh_count: int = 0
var _joint_count: int = 0

var _asset_list: VBoxContainer
var _tier_label: Label
var _tier_selector: OptionButton
var _asset_title: Label
var _asset_status: Label
var _asset_details: Label
var _automated_status: Label
var _checklist_container: VBoxContainer
var _check_boxes: Dictionary = {}
var _notes_edit: TextEdit
var _clip_selector: OptionButton
var _clip_progress: Label
var _play_button: Button
var _pose_button: Button
var _reset_pose_button: Button
var _mark_clip_button: Button
var _approve_button: Button
var _needs_fix_button: Button
var _reset_button: Button
var _camera_distance: float = 5.5
var _speed_scale: float = 1.0


func _ready() -> void:
	_create_stage()
	_load_manifest()
	_load_review_results()
	_load_sync_manifest()
	_create_interface()
	_refresh_asset_list()
	if not _assets.is_empty():
		await _load_asset(0)
	else:
		_show_missing_manifest()


func _process(delta: float) -> void:
	if _auto_rotate and is_instance_valid(_model_pivot):
		_model_pivot.rotate_y(delta * AUTO_ROTATION_SPEED)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if not mouse_event.pressed:
				_dragging = false
			elif _is_viewport_position(mouse_event.position):
				_dragging = true
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
		var focus_owner := get_viewport().gui_get_focus_owner()
		if focus_owner is LineEdit or focus_owner is TextEdit:
			return
		var key_event := event as InputEventKey
		match key_event.keycode:
			KEY_LEFT:
				_select_asset(maxi(_asset_index - 1, 0))
				get_viewport().set_input_as_handled()
			KEY_RIGHT:
				_select_asset(mini(_asset_index + 1, _assets.size() - 1))
				get_viewport().set_input_as_handled()
			KEY_R:
				_reset_view()
				get_viewport().set_input_as_handled()
			KEY_SPACE:
				_toggle_playback()
				get_viewport().set_input_as_handled()


func _create_stage() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#0b1520")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#8398aa")
	environment.ambient_light_energy = 0.55
	world.environment = environment
	add_child(world)

	var key_light := DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	key_light.light_color = Color("#e5f1ff")
	key_light.light_energy = 1.65
	key_light.shadow_enabled = true
	add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.name = "CoolFill"
	fill_light.rotation_degrees = Vector3(-18.0, 145.0, 0.0)
	fill_light.light_color = Color("#62c9ff")
	fill_light.light_energy = 0.42
	add_child(fill_light)

	var floor := MeshInstance3D.new()
	floor.name = "ReviewFloor"
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(80.0, 80.0)
	floor.mesh = floor_mesh
	floor.position.y = -0.025
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("#18232d")
	floor_material.roughness = 0.86
	floor.material_override = floor_material
	add_child(floor)
	_add_floor_grid()

	_model_pivot = Node3D.new()
	_model_pivot.name = "CharacterTurntable"
	add_child(_model_pivot)

	_orbit_pivot = Node3D.new()
	_orbit_pivot.name = "OrbitTarget"
	add_child(_orbit_pivot)
	_camera = Camera3D.new()
	_camera.name = "ReviewCamera"
	_camera.current = true
	_camera.fov = 39.0
	_orbit_pivot.add_child(_camera)
	_set_camera_distance(_camera_distance)


func _add_floor_grid() -> void:
	var grid_mesh := ImmediateMesh.new()
	grid_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for index in range(-24, 25):
		var coordinate := float(index) * 0.25
		grid_mesh.surface_add_vertex(Vector3(coordinate, 0.002, -6.0))
		grid_mesh.surface_add_vertex(Vector3(coordinate, 0.002, 6.0))
		grid_mesh.surface_add_vertex(Vector3(-6.0, 0.002, coordinate))
		grid_mesh.surface_add_vertex(Vector3(6.0, 0.002, coordinate))
	grid_mesh.surface_end()
	var grid_material := StandardMaterial3D.new()
	grid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid_material.albedo_color = Color("#34505f")
	grid_mesh.surface_set_material(0, grid_material)
	var grid := MeshInstance3D.new()
	grid.name = "FloorGrid"
	grid.mesh = grid_mesh
	add_child(grid)


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
	sidebar.name = "ReviewSidebar"
	sidebar.anchor_bottom = 1.0
	sidebar.offset_left = 16.0
	sidebar.offset_top = 16.0
	sidebar.offset_right = 376.0
	sidebar.offset_bottom = -16.0
	_style_panel(sidebar, Color(0.025, 0.045, 0.065, 0.94))
	screen.add_child(sidebar)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	sidebar.add_child(column)

	var title := _label("CHARACTER RIG + ANIMATION QA", 20, Color("#8ce6ff"))
	column.add_child(title)
	var subtitle := _label("GODOT-RENDERED · SKIN, SKELETON & CLIPS", 10, Color("#a7b8c5"))
	column.add_child(subtitle)

	_tier_label = _label("ONE HERO · UPGRADE TIER", 12, Color("#d9e7ef"))
	_tier_label.visible = false
	column.add_child(_tier_label)
	_tier_selector = OptionButton.new()
	_tier_selector.name = "HumanHeroTierSelector"
	_tier_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tier_selector.visible = false
	for asset_index in _assets.size():
		var entry: Dictionary = _assets[asset_index]
		if str(entry.get("upgrade_track_id", "")) != "human_operative":
			continue
		var tier := int(entry.get("upgrade_tier", 0))
		_tier_selector.add_item("T%d  ·  Human Hero Tier %d" % [tier, tier])
		_tier_selector.set_item_metadata(_tier_selector.item_count - 1, asset_index)
	_tier_selector.item_selected.connect(_on_tier_selected)
	column.add_child(_tier_selector)

	var asset_header := _label("CHARACTER / GLB", 13, Color("#d9e7ef"))
	column.add_child(asset_header)
	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(0.0, 188.0)
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(list_scroll)
	_asset_list = VBoxContainer.new()
	_asset_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_asset_list.add_theme_constant_override("separation", 5)
	list_scroll.add_child(_asset_list)

	var separator := HSeparator.new()
	column.add_child(separator)
	column.add_child(_label("RIG / ANIMATION / VISUAL REVIEW", 13, Color("#d9e7ef")))
	_checklist_container = VBoxContainer.new()
	_checklist_container.add_theme_constant_override("separation", 2)
	column.add_child(_checklist_container)

	column.add_child(_label("Reviewer notes", 12, Color("#a7b8c5")))
	_notes_edit = TextEdit.new()
	_notes_edit.custom_minimum_size = Vector2(0.0, 68.0)
	_notes_edit.placeholder_text = "Note skinning, clip, weapon-pose, texture, or import issues."
	_notes_edit.text_changed.connect(_on_notes_changed)
	column.add_child(_notes_edit)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 6)
	column.add_child(action_row)
	_approve_button = Button.new()
	_approve_button.text = "APPROVE"
	_approve_button.custom_minimum_size = Vector2(102.0, 38.0)
	_approve_button.pressed.connect(_mark_approved)
	action_row.add_child(_approve_button)
	_needs_fix_button = Button.new()
	_needs_fix_button.text = "NEEDS FIX"
	_needs_fix_button.custom_minimum_size = Vector2(102.0, 38.0)
	_needs_fix_button.pressed.connect(_mark_needs_fix)
	action_row.add_child(_needs_fix_button)
	_reset_button = Button.new()
	_reset_button.text = "RESET"
	_reset_button.custom_minimum_size = Vector2(74.0, 38.0)
	_reset_button.pressed.connect(_reset_review)
	action_row.add_child(_reset_button)

	_asset_status = _label("PENDING REVIEW", 14, Color("#ffd27a"))
	column.add_child(_asset_status)

	var info_panel := PanelContainer.new()
	info_panel.name = "AssetDiagnostics"
	info_panel.anchor_left = 1.0
	info_panel.anchor_right = 1.0
	info_panel.offset_left = -496.0
	info_panel.offset_right = -16.0
	info_panel.offset_top = 16.0
	info_panel.offset_bottom = 300.0
	_style_panel(info_panel, Color(0.025, 0.045, 0.065, 0.91))
	screen.add_child(info_panel)
	var info_column := VBoxContainer.new()
	info_column.add_theme_constant_override("separation", 6)
	info_panel.add_child(info_column)
	_asset_title = _label("Select a character", 20, Color("#ffffff"))
	info_column.add_child(_asset_title)
	_asset_details = _label("", 12, Color("#c3d0da"))
	_asset_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_column.add_child(_asset_details)
	_automated_status = _label("AUTOMATED CONTRACT: —", 12, Color("#ffd27a"))
	_automated_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_column.add_child(_automated_status)

	var animation_panel := PanelContainer.new()
	animation_panel.name = "AnimationReview"
	animation_panel.anchor_left = 0.0
	animation_panel.anchor_right = 1.0
	animation_panel.anchor_top = 1.0
	animation_panel.anchor_bottom = 1.0
	animation_panel.offset_left = 370.0
	animation_panel.offset_right = -16.0
	animation_panel.offset_top = -118.0
	animation_panel.offset_bottom = -16.0
	_style_panel(animation_panel, Color(0.025, 0.045, 0.065, 0.94))
	screen.add_child(animation_panel)
	var animation_column := VBoxContainer.new()
	animation_column.add_theme_constant_override("separation", 5)
	animation_panel.add_child(animation_column)
	animation_column.add_child(_label("RIG & ANIMATION CONTROLS", 13, Color("#d9e7ef")))
	_clip_progress = _label(
		"Choose a clip, play it, inspect the rigged mesh, then mark each required clip reviewed.",
		12,
		Color("#c3d0da")
	)
	animation_column.add_child(_clip_progress)
	var animation_row := HBoxContainer.new()
	animation_row.add_theme_constant_override("separation", 7)
	animation_column.add_child(animation_row)
	_clip_selector = OptionButton.new()
	_clip_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clip_selector.item_selected.connect(_on_clip_selected)
	animation_row.add_child(_clip_selector)
	_play_button = Button.new()
	_play_button.text = "PLAY / RESTART"
	_play_button.pressed.connect(_toggle_playback)
	animation_row.add_child(_play_button)
	var pause_button := Button.new()
	pause_button.text = "PAUSE"
	pause_button.pressed.connect(_pause_playback)
	animation_row.add_child(pause_button)
	var stop_button := Button.new()
	stop_button.text = "STOP"
	stop_button.pressed.connect(_stop_playback)
	animation_row.add_child(stop_button)
	_pose_button = Button.new()
	_pose_button.text = "TEST SKIN POSE"
	_pose_button.pressed.connect(_run_pose_probe)
	animation_row.add_child(_pose_button)
	_reset_pose_button = Button.new()
	_reset_pose_button.text = "RESET POSE"
	_reset_pose_button.pressed.connect(_reset_pose_probe)
	animation_row.add_child(_reset_pose_button)
	_mark_clip_button = Button.new()
	_mark_clip_button.text = "MARK CLIP REVIEWED"
	_mark_clip_button.pressed.connect(_mark_current_clip_reviewed)
	animation_row.add_child(_mark_clip_button)
	var speed_selector := OptionButton.new()
	speed_selector.custom_minimum_size = Vector2(88.0, 0.0)
	for speed in [0.5, 1.0, 1.5, 2.0]:
		speed_selector.add_item("%s x" % str(speed))
		speed_selector.set_item_metadata(speed_selector.item_count - 1, speed)
	speed_selector.select(1)
	speed_selector.item_selected.connect(_on_speed_selected.bind(speed_selector))
	animation_row.add_child(speed_selector)

	var view_controls := HBoxContainer.new()
	view_controls.add_theme_constant_override("separation", 6)
	column.add_child(view_controls)
	var previous_button := Button.new()
	previous_button.text = "← PREVIOUS"
	previous_button.pressed.connect(_select_relative.bind(-1))
	view_controls.add_child(previous_button)
	var next_button := Button.new()
	next_button.text = "NEXT →"
	next_button.pressed.connect(_select_relative.bind(1))
	view_controls.add_child(next_button)
	var reset_view_button := Button.new()
	reset_view_button.text = "RESET VIEW"
	reset_view_button.pressed.connect(_reset_view)
	view_controls.add_child(reset_view_button)
	var rotate_toggle := CheckButton.new()
	rotate_toggle.text = "Auto rotate"
	rotate_toggle.button_pressed = true
	rotate_toggle.toggled.connect(_on_auto_rotate_toggled)
	view_controls.add_child(rotate_toggle)


func _style_panel(panel: PanelContainer, background: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = background
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


func _load_manifest() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_error("Character QA manifest is missing: %s" % MANIFEST_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary or not parsed.get("assets", []) is Array:
		push_error("Character QA manifest is not a valid JSON object with an assets array.")
		return
	for item in parsed.get("assets", []):
		if item is Dictionary:
			_assets.append(item)


func _load_review_results() -> void:
	if not FileAccess.file_exists(RESULTS_PATH):
		_review_data = {
			"schema_version": 1, "stage": "Pre-integration character visual review", "assets": {}
		}
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(RESULTS_PATH))
	if parsed is Dictionary and parsed.get("assets", {}) is Dictionary:
		_review_data = parsed
	else:
		_review_data = {
			"schema_version": 1, "stage": "Pre-integration character visual review", "assets": {}
		}


func _load_sync_manifest() -> void:
	var sync_path := "res://staged_assets.json"
	if not FileAccess.file_exists(sync_path):
		_sync_data = {}
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(sync_path))
	if parsed is Dictionary and parsed.get("assets", {}) is Dictionary:
		_sync_data = parsed
	else:
		_sync_data = {}


func _validate_sync_record(asset_id: String) -> void:
	var records: Dictionary = _sync_data.get("assets", {})
	var record: Dictionary = records.get(asset_id, {})
	if record.is_empty():
		_automated_errors.append(
			"No staged asset record; run character_visual_qa/tools/sync_assets.py."
		)
		return
	if str(record.get("staged_sha256", "")) != _current_hash:
		_automated_errors.append(
			"This staged GLB differs from staged_assets.json; run sync_assets.py."
		)
	if str(record.get("source_sha256", "")) != _current_hash:
		_automated_errors.append(
			"Staged GLB is not byte-identical to its declared source; sync it again."
		)


func _show_missing_manifest() -> void:
	_asset_title.text = "No QA assets found"
	_asset_details.text = "Check character_visual_qa/asset_manifest.json."
	_automated_status.text = "No characters are available to review."


func _refresh_asset_list() -> void:
	for child in _asset_list.get_children():
		child.queue_free()
	for index in _assets.size():
		var entry: Dictionary = _assets[index]
		var result := _result_for(str(entry.get("id", "")))
		var button := Button.new()
		button.text = (
			"%s\n%s  ·  %s"
			% [
				entry.get("label", entry.get("id", "Asset")),
				entry.get("glb_label", "unknown.glb"),
				result.get("status", "PENDING"),
			]
		)
		button.tooltip_text = (
			"%s\n%s" % [entry.get("glb_label", "unknown.glb"), entry.get("source", "")]
		)
		button.custom_minimum_size = Vector2(0.0, 54.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_select_asset.bind(index))
		_asset_list.add_child(button)


func _select_asset(index: int) -> void:
	if index < 0 or index >= _assets.size():
		return
	if index == _asset_index and is_instance_valid(_current_instance):
		return
	await _load_asset(index)


func _select_relative(offset: int) -> void:
	if _assets.is_empty():
		return
	_select_asset(posmod(_asset_index + offset, _assets.size()))


func _on_tier_selected(option_index: int) -> void:
	if _tier_selector == null or option_index < 0 or option_index >= _tier_selector.item_count:
		return
	_select_asset(int(_tier_selector.get_item_metadata(option_index)))


func _load_asset(index: int) -> void:
	_asset_index = index
	_current_asset = _assets[index]
	var is_human_hero := str(_current_asset.get("upgrade_track_id", "")) == "human_operative"
	if _tier_label != null:
		_tier_label.visible = is_human_hero
	if _tier_selector != null:
		_tier_selector.visible = is_human_hero
		if is_human_hero:
			for tier_index in _tier_selector.item_count:
				if int(_tier_selector.get_item_metadata(tier_index)) == index:
					_tier_selector.select(tier_index)
					break
	_current_hash = ""
	_automated_errors.clear()
	_automated_report.clear()
	_animation_records.clear()
	_animation_players.clear()
	_skeletons.clear()
	_available_clip_names.clear()
	_reviewed_clips.clear()
	_played_clip_names.clear()
	if _clip_selector != null:
		_clip_selector.clear()
	if _play_button != null:
		_play_button.disabled = true
	if _mark_clip_button != null:
		_mark_clip_button.disabled = true
	_mesh_count = 0
	_skin_mesh_count = 0
	_joint_count = 0
	_pose_probe_active = false
	if is_instance_valid(_current_instance):
		_current_instance.queue_free()
		_current_instance = null
	if is_instance_valid(_fit_wrapper):
		_fit_wrapper.queue_free()
		_fit_wrapper = null
	if is_instance_valid(_model_pivot):
		_model_pivot.queue_free()
		_model_pivot = null

	var asset_id := str(_current_asset.get("id", ""))
	var file_path := "res://%s" % str(_current_asset.get("qa_file", ""))
	if not FileAccess.file_exists(file_path):
		_asset_title.text = str(_current_asset.get("label", asset_id))
		_asset_details.text = (
			"\n"
			. join(
				[
					"GLB: %s" % _current_asset.get("glb_label", "unknown.glb"),
					"Staged asset is missing: %s" % file_path,
					"",
					"Run from the repository root:",
					"python character_visual_qa/tools/sync_assets.py",
				]
			)
		)
		_automated_status.text = "AUTOMATED CONTRACT: BLOCKED — asset not staged"
		_asset_status.text = "PENDING · SYNC REQUIRED"
		_asset_status.add_theme_color_override("font_color", Color("#ffd27a"))
		_clip_selector.clear()
		_clip_progress.text = "No staged GLB. Sync assets before opening this project."
		for child in _checklist_container.get_children():
			child.queue_free()
		_check_boxes.clear()
		_loading_controls = true
		_notes_edit.text = ""
		_loading_controls = false
		_play_button.disabled = true
		_mark_clip_button.disabled = true
		_approve_button.disabled = true
		_needs_fix_button.disabled = true
		_reset_button.disabled = true
		_pose_button.disabled = true
		_reset_pose_button.disabled = true
		return

	_current_hash = FileAccess.get_sha256(file_path)
	_validate_sync_record(asset_id)
	var saved_result := _result_for(asset_id)
	var previous_hash := str(saved_result.get("asset_sha256", ""))
	if not previous_hash.is_empty() and previous_hash != _current_hash:
		var invalidated := _empty_result(_current_hash)
		invalidated["notes"] = "Asset content changed since the previous review; review must be repeated."
		var result_assets: Dictionary = _review_data.get("assets", {})
		result_assets[asset_id] = invalidated
		_review_data["assets"] = result_assets
		_save_review_file()

	_asset_title.text = str(_current_asset.get("label", asset_id))
	_preview_height = float(_current_asset.get("preview_height_m", 1.78))
	_base_model_yaw = deg_to_rad(float(_current_asset.get("preview_yaw_degrees", 180.0)))
	var packed := ResourceLoader.load(file_path) as PackedScene
	if packed == null:
		_automated_errors.append("Godot could not import the GLB as a PackedScene.")
		_asset_details.text = (
			"GLB: %s\nImport resource failed: %s"
			% [
				_current_asset.get("glb_label", "unknown.glb"),
				file_path,
			]
		)
		_update_automated_report()
		_restore_review_controls()
		return

	var instance := packed.instantiate()
	if not instance is Node3D:
		_automated_errors.append("Imported scene root is not Node3D.")
		instance.queue_free()
		_update_automated_report()
		_restore_review_controls()
		return

	_model_pivot = Node3D.new()
	_model_pivot.name = "CharacterTurntable"
	add_child(_model_pivot)
	_fit_wrapper = Node3D.new()
	_fit_wrapper.name = "FitAndCenter"
	_model_pivot.add_child(_fit_wrapper)
	_current_instance = instance
	_current_instance.name = "ReviewedGLB"
	_fit_wrapper.add_child(_current_instance)
	await get_tree().process_frame

	_fit_character()
	_inspect_instance()
	_build_animation_controls()
	_update_automated_report()
	_restore_review_controls()
	_refresh_asset_list()


func _fit_character() -> void:
	var bounds := _measure_bounds(_current_instance)
	if bounds.size.length() < 0.001 or bounds.size.y < 0.001:
		_automated_errors.append("No measurable 3D mesh bounds were found.")
		return
	var native_height := bounds.size.y
	var factor := _preview_height / native_height
	_fit_wrapper.scale = Vector3.ONE * factor
	_fit_wrapper.position = -bounds.get_center() * factor
	_model_pivot.position = Vector3(0.0, _preview_height * 0.5, 0.0)
	_model_pivot.rotation = Vector3(0.0, _base_model_yaw, 0.0)
	_orbit_pivot.position = _model_pivot.position
	_camera_distance = _preview_height * 3.2
	_camera.position = Vector3(0.0, _preview_height * 0.12, _camera_distance)
	_camera.look_at(_orbit_pivot.global_position, Vector3.UP)


func _measure_bounds(root: Node3D) -> AABB:
	var mesh_nodes: Array[Node] = []
	if root is MeshInstance3D:
		mesh_nodes.append(root)
	mesh_nodes.append_array(root.find_children("*", "MeshInstance3D", true, false))
	var found := false
	var bounds := AABB()
	for node in mesh_nodes:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var world_bounds := _transform_bounds(
			mesh_instance.global_transform, mesh_instance.get_aabb()
		)
		if not found:
			bounds = world_bounds
			found = true
		else:
			bounds = bounds.merge(world_bounds)
	return bounds if found else AABB()


func _transform_bounds(transform: Transform3D, source: AABB) -> AABB:
	var start := source.position
	var finish := source.position + source.size
	var corners := [
		Vector3(start.x, start.y, start.z),
		Vector3(finish.x, start.y, start.z),
		Vector3(start.x, finish.y, start.z),
		Vector3(finish.x, finish.y, start.z),
		Vector3(start.x, start.y, finish.z),
		Vector3(finish.x, start.y, finish.z),
		Vector3(start.x, finish.y, finish.z),
		Vector3(finish.x, finish.y, finish.z),
	]
	var first_point: Vector3 = transform * corners[0]
	var result := AABB(first_point, Vector3.ZERO)
	for index in range(1, corners.size()):
		result = result.expand(transform * corners[index])
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
			_skin_mesh_count += 1
	var skeleton_nodes := _current_instance.find_children("*", "Skeleton3D", true, false)
	for node in skeleton_nodes:
		var skeleton := node as Skeleton3D
		if skeleton != null:
			_joint_count += skeleton.get_bone_count()
			_skeletons.append(skeleton)
	var player_nodes := _current_instance.find_children("*", "AnimationPlayer", true, false)
	for node in player_nodes:
		var player := node as AnimationPlayer
		if player == null:
			continue
		_animation_players.append(player)
		for animation_name in player.get_animation_list():
			var clip_name := str(animation_name)
			var animation := player.get_animation(animation_name)
			var duration := animation.length if animation != null else 0.0
			(
				_animation_records
				. append(
					{
						"player": player,
						"player_name": str(player.name),
						"clip": clip_name,
						"duration": duration,
					}
				)
			)
			if not _available_clip_names.has(clip_name):
				_available_clip_names.append(clip_name)

	var expected_joints := int(_current_asset.get("expected_joint_count", 0))
	if _mesh_count == 0:
		_automated_errors.append("Imported scene contains no MeshInstance3D.")
	if bool(_current_asset.get("requires_skin", false)) and _skin_mesh_count == 0:
		_automated_errors.append(
			"Manifest requires a skinned mesh but no MeshInstance3D has a Skin."
		)
	if expected_joints > 0 and _joint_count != expected_joints:
		_automated_errors.append(
			"Skeleton bone count is %d; manifest expects %d." % [_joint_count, expected_joints]
		)
	var expected_clips: Array = _current_asset.get("expected_animation_names", [])
	for clip_name in expected_clips:
		if not _available_clip_names.has(str(clip_name)):
			_automated_errors.append("Required animation clip is missing: %s." % str(clip_name))

	var source_path := str(_current_asset.get("source", ""))
	var clip_summary := "No clips (static asset expected)"
	if not _available_clip_names.is_empty():
		clip_summary = (
			"%d clip(s): %s"
			% [
				_available_clip_names.size(),
				", ".join(_available_clip_names),
			]
		)
	var detail_lines: Array[String] = [
		"GLB: %s" % _current_asset.get("glb_label", "unknown.glb"),
		"Category: %s" % _current_asset.get("category", "CHARACTER"),
		"Runtime source: %s" % source_path,
	]
	var original_source := str(_current_asset.get("original_source", ""))
	if not original_source.is_empty():
		detail_lines.append("Original source: %s" % original_source)
	var rig_profile := str(_current_asset.get("rig_profile", ""))
	if not rig_profile.is_empty():
		detail_lines.append("Rig profile: %s" % rig_profile)
	(
		detail_lines
		. append_array(
			[
				"",
				"Meshes: %d  ·  Skinned meshes: %d" % [_mesh_count, _skin_mesh_count],
				"Skeleton joints: %d / %d expected" % [_joint_count, expected_joints],
				"Animation players: %d" % _animation_players.size(),
				clip_summary,
				"",
				"Preview fit: %.2f m high" % _preview_height,
			]
		)
	)
	_asset_details.text = "\n".join(detail_lines)


func _build_animation_controls() -> void:
	_clip_selector.clear()
	for index in _animation_records.size():
		var record: Dictionary = _animation_records[index]
		var clip_name := str(record.get("clip", ""))
		var player_name := str(record.get("player_name", "AnimationPlayer"))
		var duration := float(record.get("duration", 0.0))
		var label := _clip_display_name(clip_name)
		if _animation_players.size() > 1:
			label = "%s / %s" % [player_name, label]
		_clip_selector.add_item("%s  ·  %.2f s" % [label, duration])
		_clip_selector.set_item_metadata(index, index)
	var expected: Array = _current_asset.get("expected_animation_names", [])
	var is_animation_asset := not expected.is_empty()
	_clip_selector.disabled = _animation_records.is_empty()
	_play_button.disabled = _animation_records.is_empty()
	_pose_button.disabled = _skeletons.is_empty()
	_reset_pose_button.disabled = _skeletons.is_empty()
	_mark_clip_button.disabled = not is_animation_asset or _animation_records.is_empty()
	if _animation_records.is_empty():
		_clip_progress.text = "STATIC CHARACTER · no animation clips expected for this asset."
	else:
		if not expected.is_empty():
			_clip_progress.text = (
				"Required clips reviewed: %d / %d. Play each clip, inspect it, then mark it reviewed."
				% [
					_reviewed_clip_count(expected),
					expected.size(),
				]
			)
		else:
			_clip_progress.text = "Animation clips are present but none are required by this manifest entry."
		var default_index := 0
		for index in _animation_records.size():
			if str(_animation_records[index].get("clip", "")) == "idle":
				default_index = index
				break
		_clip_selector.select(default_index)
		_on_clip_selected(default_index)
	_update_action_state()


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


func _update_automated_report() -> void:
	_automated_report = {
		"passed": _automated_errors.is_empty(),
		"mesh_count": _mesh_count,
		"skinned_mesh_count": _skin_mesh_count,
		"joint_count": _joint_count,
		"animation_clips": _available_clip_names.duplicate(),
		"errors": _automated_errors.duplicate(),
	}
	if _automated_errors.is_empty():
		_automated_status.text = (
			"AUTOMATED CONTRACT: PASS  ·  mesh, skin, skeleton " + "and required clips found"
		)
		_automated_status.add_theme_color_override("font_color", Color("#86e0a5"))
	else:
		_automated_status.text = "AUTOMATED CONTRACT: BLOCKED\n• " + "\n• ".join(_automated_errors)
		_automated_status.add_theme_color_override("font_color", Color("#ff8a84"))


func _restore_review_controls() -> void:
	var result := _result_for(str(_current_asset.get("id", "")))
	var saved_checks: Dictionary = result.get("checklist", {})
	_loading_controls = true
	for child in _checklist_container.get_children():
		child.queue_free()
	_check_boxes.clear()
	var required: Array = _current_asset.get("required_checks", [])
	for definition in CHECK_DEFINITIONS:
		var check_id := str(definition["id"])
		var box := CheckBox.new()
		box.text = str(definition["label"])
		box.add_theme_font_size_override("font_size", 11)
		var applicable := required.has(check_id)
		box.disabled = not applicable
		if not applicable:
			box.text += "  ·  N/A"
		box.button_pressed = bool(saved_checks.get(check_id, false)) if applicable else true
		if applicable:
			box.toggled.connect(_on_check_toggled.bind(check_id))
		_checklist_container.add_child(box)
		_check_boxes[check_id] = box
	_reviewed_clips.clear()
	for clip in result.get("reviewed_clips", []):
		_reviewed_clips.append(str(clip))
	_notes_edit.text = str(result.get("notes", ""))
	_loading_controls = false
	var status := str(result.get("status", "PENDING"))
	if (
		status == "PASS"
		and (
			not _automated_errors.is_empty()
			or not _manual_checks_complete()
			or not _all_expected_clips_reviewed()
		)
	):
		status = "PENDING"
		result["status"] = status
		_save_review_file()
	_update_status_label(status)
	_update_clip_progress()
	_update_action_state()


func _on_check_toggled(_pressed: bool, _check_id: String) -> void:
	if _loading_controls:
		return
	_save_draft()
	if str(_result_for(str(_current_asset.get("id", ""))).get("status", "PENDING")) == "PASS":
		if not _manual_checks_complete() or not _all_expected_clips_reviewed():
			_set_status("PENDING")
	_update_action_state()


func _on_notes_changed() -> void:
	if _loading_controls or _asset_index < 0:
		return
	_save_draft()


func _save_draft() -> void:
	if _asset_index < 0:
		return
	var result := _result_for(str(_current_asset.get("id", "")))
	var checklist := {}
	for check_id in _check_boxes:
		var box := _check_boxes[check_id] as CheckBox
		if box != null and not box.disabled:
			checklist[check_id] = box.button_pressed
	result["checklist"] = checklist
	result["reviewed_clips"] = _reviewed_clips.duplicate()
	result["asset_sha256"] = _current_hash
	result["notes"] = _notes_edit.text
	result["automated"] = _automated_report.duplicate(true)
	_save_review_file()


func _mark_approved() -> void:
	_save_draft()
	if not _can_approve():
		return
	var result := _result_for(str(_current_asset.get("id", "")))
	result["status"] = "PASS"
	result["reviewed_at"] = Time.get_datetime_string_from_system(true, true)
	result["asset_sha256"] = _current_hash
	_save_review_file()
	_update_status_label("PASS")
	_refresh_asset_list()
	_update_action_state()


func _mark_needs_fix() -> void:
	_save_draft()
	var result := _result_for(str(_current_asset.get("id", "")))
	result["status"] = "NEEDS_FIX"
	result["reviewed_at"] = Time.get_datetime_string_from_system(true, true)
	_save_review_file()
	_update_status_label("NEEDS_FIX")
	_refresh_asset_list()


func _reset_review() -> void:
	if _asset_index < 0:
		return
	var asset_id := str(_current_asset.get("id", ""))
	var result_assets: Dictionary = _review_data.get("assets", {})
	result_assets[asset_id] = _empty_result(_current_hash)
	_review_data["assets"] = result_assets
	_reviewed_clips.clear()
	_played_clip_names.clear()
	_loading_controls = true
	_notes_edit.text = ""
	for check_id in _check_boxes:
		var box := _check_boxes[check_id] as CheckBox
		if box != null and not box.disabled:
			box.button_pressed = false
	_loading_controls = false
	_save_review_file()
	_update_status_label("PENDING")
	_update_clip_progress()
	_update_action_state()
	_refresh_asset_list()


func _mark_current_clip_reviewed() -> void:
	var record := _selected_animation_record()
	if record.is_empty():
		return
	var clip_name := str(record.get("clip", ""))
	var expected: Array = _current_asset.get("expected_animation_names", [])
	if not expected.has(clip_name):
		_clip_progress.text = "This clip is not required by the current manifest entry."
		return
	if not _played_clip_names.has(clip_name):
		_clip_progress.text = (
			"Play %s in the rendered viewport before marking it reviewed." % clip_name
		)
		return
	if not _reviewed_clips.has(clip_name):
		_reviewed_clips.append(clip_name)
	_save_draft()
	_update_clip_progress()
	_update_action_state()


func _on_clip_selected(index: int) -> void:
	if index < 0 or index >= _animation_records.size():
		return
	var record: Dictionary = _animation_records[index]
	var clip_name := str(record.get("clip", ""))
	var expected_clips: Array = _current_asset.get("expected_animation_names", [])
	if _pose_probe_active:
		_reset_pose_probe()
	for player in _animation_players:
		player.stop()
	_play_button.text = "PLAY / RESTART"
	_update_clip_progress()
	if _reviewed_clips.has(clip_name):
		_clip_progress.text += "  ·  reviewed: %s" % clip_name
	elif expected_clips.has(clip_name):
		_clip_progress.text += "  ·  press Play, inspect, then mark %s reviewed" % clip_name


func _run_pose_probe() -> void:
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
		_clip_progress.text = (
			"SKIN POSE PROBE active (%d bones). Inspect bending, then Reset Pose." % changed_bones
		)
	else:
		_clip_progress.text = "No compatible arm/leg bones found for the temporary pose probe."


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
	_update_clip_progress()


func _toggle_playback() -> void:
	if _pose_probe_active:
		_reset_pose_probe()
	var record := _selected_animation_record()
	if record.is_empty():
		return
	var player := record.get("player") as AnimationPlayer
	var clip_name := str(record.get("clip", ""))
	if player == null:
		return
	player.speed_scale = _speed_scale
	player.play(clip_name)
	if not _played_clip_names.has(clip_name):
		_played_clip_names.append(clip_name)
	_play_button.text = "RESTART CLIP"


func _pause_playback() -> void:
	for player in _animation_players:
		if player.is_playing():
			player.pause()
	_play_button.text = "RESUME / RESTART"


func _stop_playback() -> void:
	for player in _animation_players:
		player.stop()
	_play_button.text = "PLAY / RESTART"


func _selected_animation_record() -> Dictionary:
	if (
		_clip_selector == null
		or _clip_selector.selected < 0
		or _clip_selector.selected >= _animation_records.size()
	):
		return {}
	return _animation_records[_clip_selector.selected]


func _on_speed_selected(index: int, selector: OptionButton) -> void:
	if index < 0:
		return
	_speed_scale = float(selector.get_item_metadata(index))
	for player in _animation_players:
		player.speed_scale = _speed_scale


func _update_clip_progress() -> void:
	if _current_asset.is_empty():
		return
	var expected: Array = _current_asset.get("expected_animation_names", [])
	if expected.is_empty():
		_clip_progress.text = "STATIC CHARACTER · no animation clips expected for this asset."
		_mark_clip_button.disabled = true
	else:
		_clip_progress.text = (
			"Required clips reviewed: %d / %d. Play each clip, inspect it, then mark it reviewed."
			% [
				_reviewed_clip_count(expected),
				expected.size(),
			]
		)
		_mark_clip_button.disabled = _animation_records.is_empty()


func _reviewed_clip_count(expected: Array) -> int:
	var count := 0
	for clip_name in expected:
		if _reviewed_clips.has(str(clip_name)):
			count += 1
	return count


func _all_expected_clips_reviewed() -> bool:
	var expected: Array = _current_asset.get("expected_animation_names", [])
	return _reviewed_clip_count(expected) == expected.size()


func _manual_checks_complete() -> bool:
	var required: Array = _current_asset.get("required_checks", [])
	for check_id in required:
		var box := _check_boxes.get(str(check_id)) as CheckBox
		if box == null or not box.button_pressed:
			return false
	return true


func _can_approve() -> bool:
	return (
		_asset_index >= 0
		and not _current_hash.is_empty()
		and _automated_errors.is_empty()
		and _manual_checks_complete()
		and _all_expected_clips_reviewed()
	)


func _update_action_state() -> void:
	if _approve_button == null:
		return
	_approve_button.disabled = not _can_approve()
	_needs_fix_button.disabled = _asset_index < 0 or _current_hash.is_empty()
	_reset_button.disabled = _asset_index < 0 or _current_hash.is_empty()
	_pose_button.disabled = _skeletons.is_empty()
	_reset_pose_button.disabled = _skeletons.is_empty()
	var expected_clips: Array = _current_asset.get("expected_animation_names", [])
	_mark_clip_button.disabled = _animation_records.is_empty() or expected_clips.is_empty()


func _update_status_label(status: String) -> void:
	_asset_status.text = status.replace("_", " ")
	var color := Color("#ffd27a")
	if status == "PASS":
		color = Color("#86e0a5")
	elif status == "NEEDS_FIX":
		color = Color("#ff8a84")
	_asset_status.add_theme_color_override("font_color", color)


func _set_status(status: String) -> void:
	var result := _result_for(str(_current_asset.get("id", "")))
	result["status"] = status
	_save_review_file()
	_update_status_label(status)
	_refresh_asset_list()


func _result_for(asset_id: String) -> Dictionary:
	var assets_result: Dictionary = _review_data.get("assets", {})
	if not assets_result.has(asset_id):
		assets_result[asset_id] = _empty_result("")
		_review_data["assets"] = assets_result
	return assets_result[asset_id]


func _empty_result(asset_hash: String) -> Dictionary:
	return {
		"status": "PENDING",
		"asset_sha256": asset_hash,
		"reviewed_clips": [],
		"checklist": {},
		"notes": "",
		"automated": {},
	}


func _save_review_file() -> void:
	var file := FileAccess.open(RESULTS_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Unable to save review results. Check that character_visual_qa is writable.")
		return
	file.store_string(JSON.stringify(_review_data, "\t") + "\n")
	file.close()


func _refresh_status_label_from_result() -> void:
	if _asset_index < 0:
		return
	_update_status_label(
		str(_result_for(str(_current_asset.get("id", ""))).get("status", "PENDING"))
	)


func _reset_view() -> void:
	_orbit_pivot.rotation = Vector3.ZERO
	if is_instance_valid(_model_pivot):
		_model_pivot.rotation = Vector3(0.0, _base_model_yaw, 0.0)
	_set_camera_distance(_preview_height * 3.2)


func _set_camera_distance(distance: float) -> void:
	_camera_distance = clampf(distance, MIN_CAMERA_DISTANCE, MAX_CAMERA_DISTANCE)
	if is_instance_valid(_camera):
		_camera.position.z = _camera_distance
		_camera.position.y = _preview_height * 0.12
		if is_instance_valid(_orbit_pivot):
			_camera.look_at(_orbit_pivot.global_position, Vector3.UP)


func _on_auto_rotate_toggled(enabled: bool) -> void:
	_auto_rotate = enabled


func _is_viewport_position(position: Vector2) -> bool:
	var window_size := get_viewport().get_visible_rect().size
	return position.x > 390.0 and position.y > 240.0 and position.y < window_size.y - 130.0
