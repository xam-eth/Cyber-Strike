## The one way out of the world.
##
## Every gameplay menu offers HOME (pause, results, armory, settings) and HOME
## has exactly one meaning: the dashboard the player launched from. Two builds
## have to agree on that with different owners of the screen:
##
##   * in the player shell (`ui/shell.js`) the lobby is HTML outside the canvas,
##     so the engine hands the document back with `window.AegisShell.home()`;
##   * a build running the engine on its own (the committed `web/index.html`, a
##     desktop run) returns to `front_end.tscn`, which enters DASHBOARD directly
##     instead of replaying BOOT -> LOADING -> CHAPTER.
##
## The tree is unpaused and the cursor released before the scene changes: the
## pause overlay holds `get_tree().paused`, and a new scene built under a paused
## tree would arrive frozen with the pointer still captured.
class_name DashboardReturn
extends RefCounted

const FRONT_END_SCENE := "res://scenes/ui/front_end.tscn"


static func request(tree: SceneTree) -> void:
	if tree == null:
		return
	tree.paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if OS.has_feature("web") and _shell_owns_the_home_screen():
		# The shell replaces the document; nothing after this line runs.
		JavaScriptBridge.eval("window.AegisShell.home()", true)
		return
	if OS.has_feature("web"):
		# The deep link that put the engine in the world (`?qa_stage=GAMEPLAY`)
		# would put it back there on the next reload. A return is allowed to
		# edit the URL it was given.
		JavaScriptBridge.eval(
			(
				"(() => { const u = new URL(location.href);"
				+ " for (const k of ['qa_stage', 'weapon', 'qa_world']) u.searchParams.delete(k);"
				+ " history.replaceState(null, '', u); })()"
			),
			true
		)
	FrontEnd.resume_stage = &"DASHBOARD"
	var error := tree.change_scene_to_file(FRONT_END_SCENE)
	if error != OK:
		push_error("DashboardReturn: could not open the front end (%d)." % error)


## The shell only exists around the engine: `web/index.html` and the desktop
## build have no `AegisShell`, and asking a missing object would be an error in
## the browser console on every press.
static func _shell_owns_the_home_screen() -> bool:
	if not OS.has_feature("web"):
		return false
	return str(JavaScriptBridge.eval("typeof window.AegisShell === 'object'", true)) == "true"
