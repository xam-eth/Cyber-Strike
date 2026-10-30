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
	if OS.has_feature("web") and _hand_off_to_shell():
		# Flush Emscripten's /userfs mount to IndexedDB via OS_Web::finalize() ->
		# GodotFS.sync() before the shell's onExit callback replaces the document.
		print("DashboardReturn: shell home")
		tree.quit(0)
		return
	if OS.has_feature("web"):
		# The deep link that put the engine in the world (`?qa_stage=GAMEPLAY`)
		# would put it back there on the next reload. Clear loadout/tier query
		# handoff params too so newly earned Tier-2+ selections are not clamped.
		JavaScriptBridge.eval(
			(
				"(() => { const u = new URL(location.href);"
				+ " for (const k of ['qa_stage', 'weapon', 'qa_world', 'hero', 'tier'])"
				+ " u.searchParams.delete(k);"
				+ " history.replaceState(null, '', u); })()"
			)
		)
	FrontEnd.resume_stage = &"DASHBOARD"
	var error := tree.change_scene_to_file(FRONT_END_SCENE)
	if error != OK:
		push_error("DashboardReturn: could not open the front end (%d)." % error)


## The shell only exists around the engine: `web/index.html` and the desktop
## build have no `AegisShell`, and asking a missing object would be an error in
## the browser console on every press. Calling `home()` inside the same JS
## frame and returning a string ('1' / '0') avoids boolean union marshaling in
## WASM and guarantees `history.replaceState` never races `location.replace`.
static func _hand_off_to_shell() -> bool:
	if not OS.has_feature("web"):
		return false
	var handed_off := str(
		JavaScriptBridge.eval(
			(
				"(() => {"
				+ " const s = window.AegisShell;"
				+ " if (s && typeof s.home === 'function') { s.home(); return '1'; }"
				+ " return '0';"
				+ " })()"
			)
		)
	)
	return handed_off == "1"
