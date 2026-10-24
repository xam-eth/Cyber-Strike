extends Node3D

## Fixed vantage points for judging the level itself.
##
## The gameplay camera is glued to the player's shoulder, which is the right view
## for play and the wrong view for reviewing a district: from 4 m behind one
## soldier you cannot tell whether the outpost reads as a base or whether the
## cliff line has a seam in it. This node adds a review camera that anyone can
## drive from the keyboard, and that the browser QA script drives with real key
## events so the screenshots are of the shipped build.
##
##   F10 / P    toggle the review camera (simulation pauses while touring).
##              F10 is reserved by browsers and never reaches the page, so the
##              browser QA drives P; both are bound to the same action.
##   1 – 8      jump to a vantage point
##   F9         hide/show only imported FBX visuals during tour; in the normal
##              player camera too, but ONLY with ?qa_fbx=1 on the Web preview
##   Esc / 0    restore all imports and hand the view back to the player
##   F8         only with ?qa_effect: arm ONE real shot, freeze after it fires;
##              press F8 again to resume. Never spawns an effect or a fake shot.
##   F7         only with ?qa_effect: arm ONE real reload, freeze after about
##              half a second of the actual imported clip; F7 resumes.
##
## It is deliberately not part of the HUD: no touch player will ever press F10,
## and nothing in the combat code reads it.

const FRONTIER_VANTAGES := [
	{
		# Raised and pulled back off the 42 m deck: at (-27, 14, 27) the pale
		# perimeter structure crossed the bottom third of the frame and the
		# hazard disc filled the centre, so the vantage meant to review the
		# arena was framed through it (docs/DECISIONS.md §5).
		"name": "arena",
		"from": Vector3(-44.0, 30.0, 44.0),
		"at": Vector3(0.0, 0.5, 0.0),
		"fov": 55.0,
	},
	{
		"name": "outpost",
		"from": Vector3(-30.0, 12.0, 27.0),
		"at": Vector3(-62.0, 2.0, -8.0),
		"fov": 55.0,
	},
	{
		"name": "landing",
		"from": Vector3(25.0, 12.0, -15.0),
		"at": Vector3(52.0, 2.0, 5.0),
		"fov": 55.0,
	},
	{
		"name": "extraction",
		"from": Vector3(28.0, 15.0, -6.0),
		"at": Vector3(64.0, 2.0, -40.0),
		"fov": 55.0,
	},
	{
		"name": "boss",
		"from": Vector3(0.0, 12.0, -20.0),
		"at": Vector3(0.0, 3.5, -72.0),
		"fov": 60.0,
	},
	{
		"name": "ruins",
		"from": Vector3(-18.0, 12.0, 18.0),
		"at": Vector3(-52.0, 1.5, 48.0),
		"fov": 55.0,
	},
	{
		"name": "skyline",
		"from": Vector3(4.0, 58.0, 96.0),
		"at": Vector3(0.0, 0.0, -14.0),
		"fov": 62.0,
	},
	{
		"name": "cliffs",
		"from": Vector3(40.0, 10.0, 30.0),
		"at": Vector3(86.0, 4.0, 18.0),
		"fov": 58.0,
	},
]

## Each theatre is reviewed from its own set. The frontier's vantages are outdoor
## distances measured in tens of metres; the station is a roofed interior where
## the same coordinates would be inside a wall.
const STATION_VANTAGES := [
	{
		"name": "dock",
		"from": Vector3(0.0, 2.6, 15.5),
		"at": Vector3(0.0, 2.2, 0.0),
		"fov": 72.0,
	},
	{
		"name": "hall",
		"from": Vector3(-14.5, 3.2, 13.0),
		"at": Vector3(8.0, 2.0, -9.0),
		"fov": 68.0,
	},
	{
		"name": "reactor",
		"from": Vector3(0.0, 2.8, -21.5),
		"at": Vector3(0.0, 2.6, -36.0),
		"fov": 70.0,
	},
	{
		# Standing a metre inside the doorway put the room's own wall across half
		# the frame; the cargo bay reads from its middle.
		"name": "cargo",
		"from": Vector3(-22.0, 2.7, 1.0),
		"at": Vector3(-34.0, 1.0, 1.5),
		"fov": 72.0,
	},
	{
		# A door's width into the corridor is 8 m of wall either side of the lens,
		# so the old vantage photographed two wall faces and a slit of corridor.
		# From 6 m in, the corridor is a corridor.
		"name": "corridor",
		"from": Vector3(26.0, 2.4, 0.0),
		"at": Vector3(43.0, 2.0, 0.0),
		"fov": 66.0,
	},
	{
		# From the deck under the open roof, looking up at the east catwalk. A lens
		# near roof height sits inside the run of ceiling lamps and photographs the
		# light fittings rather than the walk; from head height it reads as a
		# structure over the room.
		"name": "catwalk",
		"from": Vector3(-2.0, 2.0, 11.0),
		"at": Vector3(15.5, 3.6, -4.0),
		"fov": 76.0,
	},
]

var _camera: Camera3D
var _active := false
var _vantage := 0
var _uploaded_fbx_visible := true
var _gameplay_fbx_review_enabled := false
var _effect_review_enabled := false
var _freeze_next_shot := false
var _shot_frozen := false
var _freeze_next_reload := false
var _reload_frozen := false
var _reload_review_elapsed := 0.0


func _ready() -> void:
	# The tour and effect reviewer must still receive their toggle keys while
	# paused, otherwise a frozen frame would trap the player there.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_camera = Camera3D.new()
	_camera.name = "TourCamera"
	_camera.fov = 60.0
	_camera.near = 0.1
	_camera.far = 400.0
	_camera.current = false
	add_child(_camera)
	set_process_unhandled_input(true)
	# Poll the reload pose only while an explicit WebGL QA capture is armed.
	set_process(false)
	if OS.has_feature("web"):
		_effect_review_enabled = bool(
			JavaScriptBridge.eval("new URLSearchParams(location.search).has('qa_effect')")
		)
		_gameplay_fbx_review_enabled = bool(
			JavaScriptBridge.eval("new URLSearchParams(location.search).has('qa_fbx')")
		)
	if _effect_review_enabled:
		var player := get_parent().get_node_or_null("Player")
		if player != null:
			player.shot_fired.connect(_freeze_live_shot)


func is_active() -> bool:
	return _active


func _vantages() -> Array:
	return (
		STATION_VANTAGES if WorldSelection.selected() == &"vanguard_station" else FRONTIER_VANTAGES
	)


func vantage_name() -> String:
	var list := _vantages()
	return list[clampi(_vantage, 0, list.size() - 1)]["name"]


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := (event as InputEventKey).keycode
	if key == KEY_F7 and _effect_review_enabled:
		if _reload_frozen:
			_reload_frozen = false
			get_tree().paused = false
			print("Reload QA: resumed gameplay")
		elif not _active and not _shot_frozen:
			_freeze_next_reload = not _freeze_next_reload
			_reload_review_elapsed = 0.0
			set_process(_freeze_next_reload)
			print(
				"Reload QA: %s next real reload" % ("armed" if _freeze_next_reload else "disarmed")
			)
		get_viewport().set_input_as_handled()
		return
	if key == KEY_F8 and _effect_review_enabled:
		if _shot_frozen:
			_shot_frozen = false
			get_tree().paused = false
			print("Shot QA: resumed gameplay")
		elif not _active:
			_freeze_next_shot = not _freeze_next_shot
			print("Shot QA: %s next real shot" % ("armed" if _freeze_next_shot else "disarmed"))
		get_viewport().set_input_as_handled()
		return
	# P is an alias for F10 on purpose. In a browser, F10 is a reserved key:
	# Chromium swallows it before the page sees it, so the review camera could
	# not be engaged from tools/web_qa.mjs at all — the eight "tour" frames were
	# the live game, and the check that compared them reported a pass because
	# they differed, not because the camera moved (docs/DECISIONS.md
	# §12.3, the same defect one layer deeper). P is also the key to use on a
	# laptop where F10 is a system volume/mute key.
	if key == KEY_F10 or key == KEY_P:
		if _shot_frozen or _reload_frozen:
			_shot_frozen = false
			_reload_frozen = false
			get_tree().paused = false
		_freeze_next_shot = false
		_freeze_next_reload = false
		set_process(false)
		_set_active(not _active)
		if _active:
			_apply()
		get_viewport().set_input_as_handled()
		return
	# Opt-in A/B under the *playable* shoulder camera. The normal game never
	# exposes this key; the same FBX group/physics remain untouched by the toggle.
	if key == KEY_F9 and (_active or _gameplay_fbx_review_enabled):
		_set_uploaded_fbx_visible(not _uploaded_fbx_visible)
		get_viewport().set_input_as_handled()
		return
	if not _active:
		return
	if key >= KEY_1 and key <= KEY_8:
		_vantage = mini(key - KEY_1, _vantages().size() - 1)
		_apply()
		get_viewport().set_input_as_handled()
	elif key == KEY_ESCAPE or key == KEY_0:
		_set_active(false)
		get_viewport().set_input_as_handled()


## Freeze only after the normal player controller has successfully fired a live
## projectile and activated its own muzzle effect. The next WebGL draw shows
## that exact barrel pose without stretching a 105-ms flash to several seconds.
func _freeze_live_shot() -> void:
	if not _freeze_next_shot or _active:
		return
	_freeze_next_shot = false
	_shot_frozen = true
	var muzzle := get_parent().get_node_or_null("Player/VisualRoot/WeaponSocket/Muzzle") as Node3D
	var camera := get_viewport().get_camera_3d()
	if muzzle != null and camera != null:
		var screen := camera.unproject_position(muzzle.global_position)
		print("Shot QA: real shot frozen muzzle=%s screen=%s" % [muzzle.global_position, screen])
	else:
		print("Shot QA: real shot frozen but barrel or camera missing")
	get_tree().paused = true


## F7 does not play a clip or alter the ammo timer. It merely pauses after a
## real reload request has advanced the Blender animation in the player camera,
## making a sub-second pose inspectable on a slow headless WebGL compositor.
func _process(delta: float) -> void:
	if not _freeze_next_reload or _active or _shot_frozen:
		return
	var visual := get_parent().get_node_or_null("Player/VisualRoot")
	if visual == null or str(visual.call("current_clip")) != "reload":
		_reload_review_elapsed = 0.0
		return
	_reload_review_elapsed += delta
	if _reload_review_elapsed < 0.45:
		return
	_freeze_next_reload = false
	_reload_frozen = true
	set_process(false)
	var muzzle := get_parent().get_node_or_null("Player/VisualRoot/WeaponSocket/Muzzle") as Node3D
	var camera := get_viewport().get_camera_3d()
	if muzzle != null and camera != null:
		print(
			(
				"Reload QA: real imported reload frozen at %.2fs muzzle=%s screen=%s"
				% [
					_reload_review_elapsed,
					muzzle.global_position,
					camera.unproject_position(muzzle.global_position)
				]
			)
		)
	else:
		print("Reload QA: real imported reload frozen at %.2fs" % _reload_review_elapsed)
	get_tree().paused = true


func _set_active(value: bool) -> void:
	# A review-only visibility comparison must never strand the playable world
	# without the user's FBX assets after exiting or changing camera.
	if not value:
		_set_uploaded_fbx_visible(true)
	_active = value
	_camera.current = value
	# Printed so a browser run can prove the rig was left, not only entered: a
	# tour that is never released keeps the simulation paused, and the play pass
	# that follows then fails to fire for a reason that looks like a combat bug
	# (tools/web_qa.mjs asserts on this line).
	print(
		(
			"World tour: %s · %s"
			% [
				(
					"review camera engaged, simulation paused"
					if value
					else "review camera released, gameplay resumed"
				),
				vantage_name() if value else "player camera",
			]
		)
	)
	# Freeze the simulation while reviewing. Without this the enemies keep
	# shooting the idle player and the run-results panel lands on top of the
	# district you are trying to look at.
	get_tree().paused = value
	if not value:
		# Hand the view back to whichever camera is not this one — the player's
		# spring-arm camera. Looking it up by path would break the moment the
		# camera rig is renamed; looking it up by identity does not.
		for camera in _all_cameras(get_tree().root):
			if camera != _camera:
				camera.current = true
				return


func _set_uploaded_fbx_visible(value: bool) -> void:
	if _uploaded_fbx_visible == value:
		return
	_uploaded_fbx_visible = value
	var count := 0
	for node in get_tree().get_nodes_in_group(&"uploaded_fbx_visual"):
		if node is Node3D:
			(node as Node3D).visible = value
			count += 1
	print("World QA: uploaded FBX %s · %d visual instances" % ["ON" if value else "OFF", count])


func _all_cameras(node: Node) -> Array[Camera3D]:
	var found: Array[Camera3D] = []
	for child in node.get_children():
		if child is Camera3D:
			found.append(child as Camera3D)
		found.append_array(_all_cameras(child))
	return found


func _apply() -> void:
	var list := _vantages()
	var vantage: Dictionary = list[clampi(_vantage, 0, list.size() - 1)]
	_camera.fov = float(vantage["fov"])
	_camera.global_position = vantage["from"]
	_camera.look_at(vantage["at"], Vector3.UP)
	_camera.current = true
