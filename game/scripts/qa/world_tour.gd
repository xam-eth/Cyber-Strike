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
##   F10        toggle the review camera (gameplay keeps running)
##   1 – 8      jump to a vantage point
##   Esc / 0    hand the view back to the player
##
## It is deliberately not part of the HUD: no touch player will ever press F10,
## and nothing in the combat code reads it.

const VANTAGES := [
	{
		"name": "arena",
		"from": Vector3(-27.0, 14.0, 27.0),
		"at": Vector3(0.0, 1.0, -2.0),
		"fov": 60.0,
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

var _camera: Camera3D
var _active := false
var _vantage := 0


func _ready() -> void:
	# The tour must keep receiving F10 and the number keys while the tree is
	# paused, otherwise the first vantage you pick would trap the view there.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_camera = Camera3D.new()
	_camera.name = "TourCamera"
	_camera.fov = 60.0
	_camera.near = 0.1
	_camera.far = 400.0
	_camera.current = false
	add_child(_camera)
	set_process_unhandled_input(true)


func is_active() -> bool:
	return _active


func vantage_name() -> String:
	return VANTAGES[_vantage]["name"]


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key := (event as InputEventKey).keycode
	if key == KEY_F10:
		_set_active(not _active)
		if _active:
			_apply()
		get_viewport().set_input_as_handled()
		return
	if not _active:
		return
	if key >= KEY_1 and key <= KEY_8:
		_vantage = key - KEY_1
		_apply()
		get_viewport().set_input_as_handled()
	elif key == KEY_ESCAPE or key == KEY_0:
		_set_active(false)
		get_viewport().set_input_as_handled()


func _set_active(value: bool) -> void:
	_active = value
	_camera.current = value
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


func _all_cameras(node: Node) -> Array[Camera3D]:
	var found: Array[Camera3D] = []
	for child in node.get_children():
		if child is Camera3D:
			found.append(child as Camera3D)
		found.append_array(_all_cameras(child))
	return found


func _apply() -> void:
	var vantage: Dictionary = VANTAGES[_vantage]
	_camera.fov = float(vantage["fov"])
	_camera.global_position = vantage["from"]
	_camera.look_at(vantage["at"], Vector3.UP)
	_camera.current = true
