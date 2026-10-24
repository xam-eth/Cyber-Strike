class_name ShowcaseViewport
extends SubViewportContainer

## A live 3D viewport that can sit inside a 2D menu screen.
##
## The selection screens used to show a painted portrait and a plate of key art.
## The hero a player picks is a rigged GLB that gameplay instantiates, so the
## screen that sells it should show *that model* -- same file, same skeleton,
## lit for a showcase. This node owns the camera, the lights and the isolated
## `SubViewport` that make that possible without touching the gameplay scene:
##
##   * it never writes to a global material, skeleton or animation resource, so
##     the avatar in `main.tscn` is unaffected;
##   * it instantiates its own copy of the model, so a showcase clip cannot move
##     the player's limbs, consume ammo or change combat state;
##   * the viewport is transparent, so the stage's own 2D backdrop and panels
##     compose around the model instead of being replaced by a 3D sky.
##
## Fitting is `ModelFitter`, the same code the player avatar and the enemies use,
## so a model that reads correctly here reads correctly in the arena.
const ModelFitterScript = preload("res://scripts/visual/model_fitter.gd")

## Milliseconds between showcase beats. Long enough that a player reading the
## stats is not distracted, short enough that the screen is never static.
const BEAT_SECONDS := 4.5

var _viewport: SubViewport
var _camera: Camera3D
## Everything that is presented lives under this node; clearing it clears the
## model without rebuilding the camera or the lights.
var _rig: Node3D
var _pivot: Node3D = null
var _model: Node3D = null
var _anim: AnimationPlayer = null
var _model_path := ""
var _clip_names: Array[String] = []
var _current_clip := ""
var _camera_distance := 2.6
var _camera_height := 0.55
var _look_target := Vector3.ZERO
## When set, the camera is reframed from the model's measured size every time the
## container changes size. 0 means "the caller frames it with `frame_model`".
var _fill := 0.0
## Camera height above the model's centre, as a fraction of its height. A hero is
## looked at nearly level; a rifle is looked down on, because a metre-long object
## seen edge-on is a line.
var _elevation := 0.0
var _framed_view := Vector2i(-1, -1)

## Showcase choreography: the clips to walk through while the screen is open.
## Empty means "hold the first clip", which is what a static model gets.
var _cycle: Array[String] = []
var _cycle_index := 0
var _cycle_remaining := 0.0
var _breath := 0.0


func _ready() -> void:
	stretch = true
	# The viewport is decoration: every tap has to reach the carousel and the
	# buttons layered over it, not be swallowed by the 3D surface.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_viewport()
	_build_camera()
	_build_lighting()
	# The container has no size while the screen is being built -- the viewport
	# measured 2 x 2 px when the first model was presented -- so a framing decided
	# then is a guess. `_process` watches the real box and reframes when it
	# changes; the `resized` signal alone fires before the SubViewport has taken
	# its new size.
	resized.connect(_on_resized)


# --- public surface --------------------------------------------------------- #


## Instantiates `scene` on its own, fits it and returns true when a model is on
## screen. `options` accepts:
##   fit_axis: 1 height (default), 2 length -- a rifle is longer than it is tall
##   height:   the size along `fit_axis` in showcase metres
##   yaw:      degrees, so the model faces the camera
##   clips:    clip names to cycle through; the first one also plays on entry
func present(scene: PackedScene, options: Dictionary = {}) -> bool:
	clear_model()
	if scene == null:
		return false
	var fit_axis := int(options.get("fit_axis", 1))
	var size := float(options.get("height", 1.0))
	var yaw := float(options.get("yaw", 180.0))
	var fitted := ModelFitterScript.attach(
		_rig, scene, size, yaw, "ShowcasePivot", "ShowcaseModel", fit_axis
	)
	if fitted.is_empty():
		push_warning("ShowcaseViewport: '%s' produced no measurable meshes." % scene.resource_path)
		return false
	_pivot = fitted["pivot"] as Node3D
	_model = fitted["model"] as Node3D
	_model_path = scene.resource_path
	_anim = _find_animation_player(_model)
	_clip_names = _animation_list(_anim)
	_cycle = []
	for clip in options.get("clips", []):
		if _has_clip(str(clip)):
			_cycle.append(str(clip))
	# A model's first showcase clip is its idle; the cycle starts there and the
	# reveal plays the same one, so the screen never fades in mid-stride.
	if not _cycle.is_empty():
		_play(_cycle[0])
	_cycle_index = 0
	_cycle_remaining = BEAT_SECONDS
	_breath = 0.0
	_reveal()
	set_process(true)
	return true


func clear_model() -> void:
	if is_instance_valid(_pivot):
		_pivot.queue_free()
	_pivot = null
	_model = null
	_anim = null
	_model_path = ""
	_clip_names.clear()
	_current_clip = ""
	_cycle.clear()
	_fill = 0.0
	_framed_view = Vector2i(-1, -1)
	set_process(false)


## Plays one clip if the model has it. Always returns whether it did, so a
## caller can fall back rather than assume a clip name exists.
func play_clip(clip_name: String) -> bool:
	return _play(clip_name)


func has_model() -> bool:
	return is_instance_valid(_model)


## `res://` path of the scene on screen, or "" -- the value the "same model as
## gameplay" test compares against.
func model_path() -> String:
	return _model_path


func clip_names() -> Array[String]:
	return _clip_names.duplicate()


func current_clip() -> String:
	return _current_clip


## Frames the camera for a model of `size` metres. Called by the screens after
## `present()`, because a rifle and a 1.8 m operative do not share a distance.
## Snaps the reveal to its end state. A rotation or a profile refresh re-frames
## a model that is already on screen; replaying the entrance there would make
## the screen flash every time the window changes size.
func skip_reveal() -> void:
	if not is_instance_valid(_pivot):
		return
	_pivot.scale = Vector3.ONE


func frame_model(size: float, crouch := false) -> void:
	_fill = 0.0
	_camera_distance = clampf(size * 2.15, 1.2, 4.0)
	_camera_height = size * (0.30 if crouch else 0.52)
	_look_target = Vector3(0.0, _camera_height * 0.92, 0.0)
	_apply_camera()


## Frames whatever is on the pivot so it fills `fill` of the visible frame.
##
## This measures the model that is actually there, at the size it was actually
## fitted to, and solves for the camera distance against the *rendered viewport's*
## aspect. `frame_model()` takes a number the caller guessed; a 1.8 m operative
## and a 1 m rifle need two different guesses, and a guess is what made the rifle
## render as a sliver. It also re-runs by itself when the container is laid out,
## which is the only moment the aspect is known.
func frame_to_fill(fill := 0.8, elevation := 0.0) -> void:
	_fill = fill
	_elevation = elevation
	_reframe()


func _on_resized() -> void:
	# Deferred: the container updates its SubViewport's size in the same
	# notification that emits `resized`, so reading `_viewport.size` now would
	# still be the previous frame's box.
	if _fill > 0.0:
		_reframe.call_deferred()


func _reframe() -> void:
	if not is_instance_valid(_model) or not is_instance_valid(_camera):
		return
	if not _model.is_inside_tree() or _fill <= 0.0:
		return
	var local := ModelFitterScript.combined_bounds(_model)
	var world := _model.global_transform * local
	var centre := world.position + world.size * 0.5
	var view := _viewport.size
	var aspect := float(view.x) / float(maxi(1, view.y))
	var vertical := deg_to_rad(_camera.fov)
	var horizontal := 2.0 * atan(tan(vertical * 0.5) * maxf(aspect, 0.2))
	# The pivot carries a yaw, so the horizontal extent the camera sees is the
	# larger of the two horizontal axes of the (already rotated) bounds.
	var width := maxf(world.size.x, world.size.z)
	var by_height := world.size.y * 0.5 / (tan(vertical * 0.5) * _fill)
	var by_width := width * 0.5 / (tan(horizontal * 0.5) * _fill)
	_framed_view = Vector2i(_viewport.size)
	_camera_distance = clampf(maxf(by_height, by_width), 0.5, 14.0)
	_camera_height = centre.y + world.size.y * _elevation
	_look_target = centre
	_apply_camera()


# --- construction ----------------------------------------------------------- #


func _build_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "ShowcaseSubViewport"
	# Transparent so the stage's backdrop, scrim and panels show through. This
	# is what makes it a showcase inside the screen rather than a screen of its
	# own.
	_viewport.transparent_bg = true
	# Own world: the menu has no other 3D, and sharing would let a future
	# gameplay viewport's environment bleed into the menu lighting.
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# No MSAA: this renders on a phone, in the same frame budget as the UI.
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.positional_shadow_atlas_size = 0
	add_child(_viewport)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Cool and dim: the arena's fill, not a studio white box. Bright ambient is
	# what flattened the old selection art.
	environment.ambient_light_color = Color(AegisTokens.LINE_HI, 0.6)
	environment.ambient_light_energy = 0.85
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.adjustment_saturation = 0.94
	var world_environment := WorldEnvironment.new()
	world_environment.name = "ShowcaseEnvironment"
	world_environment.environment = environment
	_viewport.add_child(world_environment)

	_rig = Node3D.new()
	_rig.name = "ShowcaseRig"
	_viewport.add_child(_rig)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "ShowcaseCamera"
	_camera.fov = 32.0
	# keep_aspect KEEP_HEIGHT matches the gameplay camera, so a model composed to
	# fill this frame is not cropped differently on a wide phone.
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_viewport.add_child(_camera)
	_apply_camera()


func _apply_camera() -> void:
	if not is_instance_valid(_camera):
		return
	_camera.position = Vector3(_look_target.x, _camera_height, _camera_distance)
	_camera.look_at(_look_target, Vector3.UP)
	_camera.current = true


func _build_lighting() -> void:
	# Three lights, deliberately: a key so the form reads, a cyan rim so the
	# silhouette separates from a dark backdrop, and one warm fill low down.
	# More than this is a phone frame budget spent on a menu.
	var key := DirectionalLight3D.new()
	key.name = "ShowcaseKey"
	key.rotation_degrees = Vector3(-34.0, 38.0, 0.0)
	key.light_color = Color(0.92, 0.96, 1.0)
	key.light_energy = 1.55
	_viewport.add_child(key)

	var rim := DirectionalLight3D.new()
	rim.name = "ShowcaseRim"
	rim.rotation_degrees = Vector3(-12.0, 208.0, 0.0)
	rim.light_color = AegisTokens.INFO
	rim.light_energy = 2.3
	_viewport.add_child(rim)

	var fill := OmniLight3D.new()
	fill.name = "ShowcaseFill"
	fill.position = Vector3(0.0, 0.35, 1.1)
	fill.light_color = AegisTokens.ACCENT
	fill.light_energy = 0.55
	fill.omni_range = 3.2
	_viewport.add_child(fill)


# --- animation -------------------------------------------------------------- #


func _process(delta: float) -> void:
	if not is_instance_valid(_pivot):
		return
	# A breath, not an animation: two centimetres of vertical travel at half a
	# hertz. It keeps a still frame from looking like a frozen screenshot
	# without competing with the model's own idle clip.
	if _fill > 0.0 and is_instance_valid(_viewport) and _viewport.size != _framed_view:
		_reframe()
	_breath += delta
	_pivot.position.y = sin(_breath * 1.9) * 0.012
	if _cycle.size() < 2:
		return
	_cycle_remaining -= delta
	if _cycle_remaining > 0.0:
		return
	_cycle_index = (_cycle_index + 1) % _cycle.size()
	_play(_cycle[_cycle_index])
	_cycle_remaining = BEAT_SECONDS


func _reveal() -> void:
	if not is_instance_valid(_pivot) or not is_inside_tree():
		return
	# Scale from 0.965 with a fade-in: the model arrives, the screen does not
	# blink. One second, and the selector stays responsive while it runs because
	# nothing blocks input.
	var tween := create_tween()
	_pivot.scale = Vector3.ONE * 0.965
	tween.set_parallel(true)
	tween.tween_property(_pivot, "scale", Vector3.ONE, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_OUT
	)
	tween.tween_property(_pivot, "rotation:y", _pivot.rotation.y, 0.55)


func _play(clip_name: String) -> bool:
	if _anim == null or clip_name.is_empty():
		return false
	if not _anim.has_animation(clip_name):
		return false
	_current_clip = clip_name
	_anim.play(clip_name, 0.25)
	return true


func _has_clip(clip_name: String) -> bool:
	return _anim != null and _anim.has_animation(clip_name)


static func _find_animation_player(root: Node) -> AnimationPlayer:
	if root == null:
		return null
	var players := root.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return null
	return players[0] as AnimationPlayer


static func _animation_list(player: AnimationPlayer) -> Array[String]:
	var names: Array[String] = []
	if player == null:
		return names
	for animation_name in player.get_animation_list():
		names.append(str(animation_name))
	return names
