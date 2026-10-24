class_name PlayerController
extends CharacterBody3D

signal shot_fired
signal weapon_changed(display_name: String)
signal health_changed(current: float, maximum: float)
signal damage_received(amount: float, current: float, maximum: float)
signal skill_used(targets_hit: int, cooldown_seconds: float)
signal skill_cooldown_changed(remaining_seconds: float, total_seconds: float)
signal defeated
signal aim_changed(aiming: bool)

const ThirdPersonCameraRigScript = preload("res://scripts/camera/camera_rig.gd")
const CharacterVisualScript = preload("res://scripts/player/character_visual.gd")
const WeaponControllerScript = preload("res://scripts/weapons/weapon_controller.gd")

@export_range(1.0, 15.0, 0.1) var move_speed: float = 6.0
@export_range(1.0, 60.0, 0.5) var move_acceleration: float = 24.0
## Holding sprint raises the top speed instead of adding a second, faster walk
## cycle: the avatar has one run clip and stretching it looks wrong.
@export_range(1.0, 2.5, 0.05) var sprint_multiplier: float = 1.45
@export_range(0.0, 12.0, 0.1) var jump_velocity: float = 5.2
@export_range(10.0, 100.0, 1.0) var aim_range: float = 55.0
@export_range(1.0, 500.0, 1.0) var max_health: float = 100.0
@export_range(6.0, 30.0, 0.5) var emp_pulse_cooldown: float = 12.0
@export_range(4.0, 20.0, 0.5) var emp_pulse_radius: float = 9.0
@export_range(1.0, 100.0, 1.0) var emp_pulse_damage: float = 18.0
## Small mobile-only cone: an actual finger covers more than 20 physical px.
## Never auto-fires, never selects a target behind cover, and leaves desktop
## precision untouched. The world line-of-sight and muzzle-cover checks remain.
@export_range(8.0, 48.0, 1.0) var touch_soft_lock_pixels: float = 32.0

var current_health: float = 0.0
var _skill_cooldown_remaining: float = 0.0
var _is_defeated: bool = false
var _touch_movement: Vector2 = Vector2.ZERO
var _touch_fire_pressed: bool = false
var _aiming: bool = false
var _touch_aim_hold: bool = false
var _walk_time: float = 0.0
var _reload_was_active: bool = false

@onready var camera_rig: ThirdPersonCameraRigScript = $CameraRig
@onready var aim_camera: Camera3D = $CameraRig/YawPivot/PitchPivot/SpringArm3D/Camera3D
@onready var visual_root: CharacterVisualScript = $VisualRoot
@onready var muzzle: Marker3D = $VisualRoot/WeaponSocket/Muzzle
@onready var muzzle_flash: MuzzleFlash = get_node_or_null("VisualRoot/WeaponSocket/MuzzleFlash")
@onready var weapon_controller: WeaponControllerScript = $WeaponController


func _ready() -> void:
	current_health = max_health
	weapon_controller.weapon_changed.connect(_on_weapon_changed)
	weapon_controller.ammo_changed.connect(_on_ammo_changed)
	health_changed.emit(current_health, max_health)


func _physics_process(delta: float) -> void:
	if _is_defeated:
		velocity = Vector3.ZERO
		visual_root.update_pose(Vector3.ZERO, true, delta)
		return
	_update_movement(delta)
	if _skill_cooldown_remaining > 0.0:
		var previous_cooldown_bucket := ceili(_skill_cooldown_remaining)
		_skill_cooldown_remaining = maxf(_skill_cooldown_remaining - delta, 0.0)
		if ceili(_skill_cooldown_remaining) != previous_cooldown_bucket:
			skill_cooldown_changed.emit(_skill_cooldown_remaining, emp_pulse_cooldown)
	if Input.is_action_just_pressed("weapon_next"):
		select_next_weapon()
	elif Input.is_action_just_pressed("weapon_prev"):
		select_previous_weapon()
	var slots := ["weapon_1", "weapon_2", "weapon_3"]
	for slot in range(slots.size()):
		if Input.is_action_just_pressed(slots[slot]):
			select_weapon(slot)
	if Input.is_action_just_pressed("reload"):
		weapon_controller.request_reload()
	_update_aiming()
	var aim_point := _get_aim_point()
	camera_rig.set_aiming(_aiming)
	visual_root.set_aiming(_aiming)
	visual_root.update_facing(aim_point, velocity, _aiming, delta)
	_walk_time += delta
	visual_root.update_pose(velocity, is_on_floor(), delta)
	camera_rig.apply_walk_bob(visual_root.walk_intensity(), _walk_time)
	var desktop_fire := Input.is_action_pressed("fire") and not _is_pointer_over_ui()
	if desktop_fire or _touch_fire_pressed:
		# The real rifle must be shouldered *before* the first muzzle point is
		# sampled. Previously hip fire spent a round with the flash at the boot,
		# then animated into the correct shooting pose after the projectile left.
		if weapon_controller.get_current_ammo() > 0 and not weapon_controller.is_reloading():
			visual_root.prime_shot_pose()
		if weapon_controller.try_fire(self, muzzle, aim_point):
			if is_instance_valid(muzzle_flash):
				muzzle_flash.flash(_current_recoil_strength(), _current_flash_color())
			shot_fired.emit()
			visual_root.play_recoil(_current_recoil_strength())
			camera_rig.add_recoil_kick(_current_recoil_strength())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			set_aiming(true)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			set_aiming(false)
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_rig.apply_look_delta(event.relative)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func set_touch_movement(value: Vector2) -> void:
	_touch_movement = value.limit_length(1.0)


func apply_touch_look(delta: Vector2) -> void:
	camera_rig.apply_look_delta(delta)


func set_touch_fire_pressed(pressed: bool) -> void:
	_touch_fire_pressed = pressed


## Aim-down-sights, driven by the desktop right mouse button or the HUD AIM
## toggle. Zooming the camera and stilling the avatar is what makes aiming read
## on a small screen.
func set_aiming(value: bool) -> void:
	_aiming = value


func is_aiming() -> bool:
	return _aiming


## Heavier weapons kick harder; the order matches the weapon definitions.
func _current_recoil_strength() -> float:
	var kick_by_weapon := [0.7, 1.4, 0.95]
	return kick_by_weapon[clampi(weapon_controller.get_current_weapon_index(), 0, 2)]


func _current_flash_color() -> Color:
	var definition := weapon_controller.get_current_definition()
	if definition != null:
		match definition.weapon_id:
			&"pulse_rifle":
				return Color(0.28, 0.86, 1.0)
			&"nova_launcher":
				return Color(1.0, 0.46, 0.16)
			&"arc_shooter":
				return Color(0.64, 0.7, 1.0)
	return Color(1.0, 0.74, 0.4)


## The HUD AIM button holds aiming for as long as it is held; desktop right
## mouse aims through MOUSE_MODE_CAPTURED.
func set_touch_aim_held(pressed: bool) -> void:
	_touch_aim_hold = pressed


func _update_aiming() -> void:
	var previous := _aiming
	_aiming = _touch_aim_hold or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if _aiming != previous:
		aim_changed.emit(_aiming)


func activate_skill() -> bool:
	if _is_defeated or _skill_cooldown_remaining > 0.0:
		return false

	var targets_hit := 0
	var radius_squared := emp_pulse_radius * emp_pulse_radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node3D or not is_instance_valid(enemy):
			continue
		if enemy.has_method("is_defeated") and bool(enemy.call("is_defeated")):
			continue
		var offset: Vector3 = (enemy as Node3D).global_position - global_position
		offset.y = 0.0
		if offset.length_squared() > radius_squared or not enemy.has_method("apply_damage"):
			continue
		enemy.call("apply_damage", emp_pulse_damage, self)
		targets_hit += 1

	_skill_cooldown_remaining = emp_pulse_cooldown
	_spawn_emp_pulse_effect()
	skill_cooldown_changed.emit(_skill_cooldown_remaining, emp_pulse_cooldown)
	skill_used.emit(targets_hit, emp_pulse_cooldown)
	return true


func select_weapon(index: int) -> bool:
	return weapon_controller.select_weapon(index)


func select_next_weapon() -> bool:
	return weapon_controller.select_next_weapon()


func select_previous_weapon() -> bool:
	return weapon_controller.select_previous_weapon()


func get_current_weapon_name() -> String:
	return weapon_controller.get_current_weapon_name()


func _on_weapon_changed(display_name: String) -> void:
	weapon_changed.emit(display_name)


func _on_ammo_changed(_remaining: int, _capacity: int, reloading: bool) -> void:
	if reloading and not _reload_was_active:
		visual_root.play_reload(weapon_controller.current_reload_remaining())
	elif not reloading and _reload_was_active:
		visual_root.finish_reload()
	_reload_was_active = reloading


func can_take_damage() -> bool:
	return not _is_defeated


func apply_damage(amount: float, _source: Node = null) -> void:
	if _is_defeated or amount <= 0.0:
		return

	var applied_damage := minf(amount, current_health)
	current_health = maxf(current_health - applied_damage, 0.0)
	damage_received.emit(applied_damage, current_health, max_health)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		_is_defeated = true
		visual_root.play_death()
		Sfx.play_ui(&"player_hurt")
		_touch_fire_pressed = false
		_touch_movement = Vector2.ZERO
		defeated.emit()
	else:
		visual_root.play_hit()


func is_defeated() -> bool:
	return _is_defeated


func reset_player() -> void:
	_is_defeated = false
	_aiming = false
	_touch_aim_hold = false
	current_health = max_health
	_skill_cooldown_remaining = 0.0
	velocity = Vector3.ZERO
	_touch_movement = Vector2.ZERO
	_touch_fire_pressed = false
	weapon_controller.reset_ammo()
	_reload_was_active = false
	visual_root.reset_action_state()
	health_changed.emit(current_health, max_health)
	skill_cooldown_changed.emit(0.0, emp_pulse_cooldown)


func _spawn_emp_pulse_effect() -> void:
	# An opaque 9m torus crossed the third-person camera after ~0.3s and
	# painted a broad cyan bar across the REAL landscape EMP screenshot. Keep
	# the 9m damage radius, but draw a hairline ground trace + spaced dashes;
	# this reads as a wave without masking the floor, hero or touch controls.
	var pulse := Node3D.new()
	pulse.name = "EmpPulseEffect"
	pulse.position = Vector3(0.0, 0.14, 0.0)
	pulse.scale = Vector3.ONE * 0.12
	add_child(pulse)

	var trace_mesh := TorusMesh.new()
	trace_mesh.inner_radius = 0.986
	trace_mesh.outer_radius = 1.0
	trace_mesh.rings = 48
	trace_mesh.ring_segments = 6
	var trace_material := StandardMaterial3D.new()
	trace_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trace_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trace_material.albedo_color = Color(0.18, 0.83, 1.0, 0.22)
	trace_material.emission_enabled = true
	trace_material.emission = Color(0.08, 0.45, 0.9)
	trace_material.emission_energy_multiplier = 0.35
	var trace := MeshInstance3D.new()
	trace.name = "GroundTrace"
	trace.mesh = trace_mesh
	trace.material_override = trace_material
	trace.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pulse.add_child(trace)

	var dash_mesh := BoxMesh.new()
	dash_mesh.size = Vector3(0.12, 0.015, 0.028)
	var dashes := MultiMesh.new()
	dashes.transform_format = MultiMesh.TRANSFORM_3D
	dashes.mesh = dash_mesh
	dashes.instance_count = 20
	for index in range(dashes.instance_count):
		var angle := TAU * float(index) / float(dashes.instance_count)
		var radial := Vector3(sin(angle), 0.0, cos(angle))
		var tangent := Vector3(cos(angle), 0.0, -sin(angle))
		dashes.set_instance_transform(
			index, Transform3D(Basis(tangent, Vector3.UP, radial), radial)
		)
	var dash_material := trace_material.duplicate() as StandardMaterial3D
	dash_material.albedo_color = Color(0.25, 0.9, 1.0, 0.75)
	dash_material.emission_energy_multiplier = 1.1
	var marks := MultiMeshInstance3D.new()
	marks.name = "PulseDashes"
	marks.multimesh = dashes
	marks.material_override = dash_material
	marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pulse.add_child(marks)

	var pulse_tween := create_tween()
	var pulse_tweener := pulse_tween.tween_property(
		pulse, "scale", Vector3.ONE * emp_pulse_radius, 0.45
	)
	pulse_tweener.set_trans(Tween.TRANS_QUAD)
	pulse_tweener.set_ease(Tween.EASE_OUT)
	pulse_tween.tween_callback(pulse.queue_free)


func _update_movement(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if _touch_movement.length_squared() > 0.0001:
		input_vector = _touch_movement

	var camera_basis := camera_rig.get_yaw_basis()
	var forward := -camera_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := camera_basis.x
	right.y = 0.0
	right = right.normalized()
	var move_direction := (right * input_vector.x - forward * input_vector.y).limit_length(1.0)
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var sprinting := Input.is_action_pressed("sprint") and input_vector.length() > 0.2
	var target_speed := move_speed * (sprint_multiplier if sprinting else 1.0)
	var desired_velocity := move_direction * target_speed
	horizontal_velocity = horizontal_velocity.move_toward(
		desired_velocity, move_acceleration * delta
	)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
		if Input.is_action_just_pressed("jump") and jump_velocity > 0.0:
			velocity.y = jump_velocity
	else:
		velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity")) * delta
	move_and_slide()


func _is_pointer_over_ui() -> bool:
	return is_instance_valid(get_viewport().gui_get_hovered_control())


func _get_aim_point() -> Vector3:
	var viewport_size := aim_camera.get_viewport().get_visible_rect().size
	var screen_center := viewport_size * 0.5
	var ray_origin := aim_camera.project_ray_origin(screen_center)
	var ray_direction := aim_camera.project_ray_normal(screen_center)
	var ray_end := ray_origin + ray_direction * aim_range
	var excluded_rids: Array[RID] = [get_rid()]
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 3, excluded_rids)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var collider := hit.get("collider") as CollisionObject3D
	if (
		collider != null
		and (collider.is_in_group("runner_enemies") or collider.is_in_group("shooter_enemies"))
	):
		if _touch_fire_pressed or _touch_aim_hold:
			var hud := get_parent().get_node_or_null("HUD/TouchControls")
			if hud != null and bool(hud.call("is_touch_mode")):
				hud.set("_soft_lock", true)
		return hit.get("position", ray_end)
	# In a 390 px viewport the avatar and thumb obscure precise sight alignment.
	# A Runner may be 18 px from the centre even while visually under the optic;
	# snap the *shot direction* a few pixels only when FIRE/ADS is held on touch.
	var assisted := _touch_assisted_aim_point(screen_center)
	if assisted != Vector3.ZERO:
		return assisted
	if not hit.is_empty():
		var hit_position: Vector3 = hit.get("position", ray_end)
		return hit_position
	return ray_end


func _touch_assisted_aim_point(screen_center: Vector2) -> Vector3:
	if not (_touch_fire_pressed or _touch_aim_hold):
		return Vector3.ZERO
	var hud := get_parent().get_node_or_null("HUD/TouchControls")
	if hud == null or not bool(hud.call("is_touch_mode")):
		return Vector3.ZERO
	var viewport_size := aim_camera.get_viewport().get_visible_rect().size
	var physical_width := float(get_window().size.x)
	var scale := physical_width / maxf(viewport_size.x, 1.0)
	if physical_width < 200.0:
		scale = 1.0  # a 64 px headless dummy window is not a phone
	var radius := touch_soft_lock_pixels / maxf(scale, 0.01)
	var max_squared := radius * radius
	var chosen := Vector3.ZERO
	for candidate in get_tree().get_nodes_in_group("enemies"):
		var enemy := candidate as CollisionObject3D
		if (
			enemy == null
			or (
				not enemy.is_in_group("runner_enemies") and not enemy.is_in_group("shooter_enemies")
			)
		):
			continue
		if enemy.has_method("is_defeated") and bool(enemy.call("is_defeated")):
			continue
		var point := enemy.global_position + Vector3.UP
		if aim_camera.is_position_behind(point):
			continue
		var squared := aim_camera.unproject_position(point).distance_squared_to(screen_center)
		if squared > max_squared:
			continue
		# Use a visibility ray to reject enemies hidden by the user's FBX world,
		# and don't permit a soft lock on a target behind the avatar or another
		# enemy. WeaponController still validates the barrel's own cover ray.
		var from := aim_camera.project_ray_origin(screen_center)
		var query := PhysicsRayQueryParameters3D.create(from, point, 3, [get_rid()])
		var visible := get_world_3d().direct_space_state.intersect_ray(query)
		if visible.get("collider") != enemy:
			continue
		max_squared = squared
		chosen = point
	hud.set("_soft_lock", chosen != Vector3.ZERO)
	return chosen
