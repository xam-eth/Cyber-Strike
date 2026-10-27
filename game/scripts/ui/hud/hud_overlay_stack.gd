## Which in-game overlay owns the screen right now.
##
## The HUD has five things that can take the whole screen -- pause, results,
## settings, the armory and the HUD editor -- and they used to be five booleans
## plus a hand-written if/elif ladder in `_input`. That works until a sixth
## overlay is added and one of the five places that knew about the ladder is
## forgotten: the round-11 HOME plates were built, connected, drawn, and dead
## under a finger for exactly that reason.
##
## This object is the one place that knows the order. It owns three things the
## booleans could not:
##
##   * **who is on top** -- `back()` closes exactly the top layer, so ESC means
##     the same thing in every overlay;
##   * **the focus trap** -- `Control.focus_behavior_recursive` and
##     `mouse_behavior_recursive` (Godot 4.5+) are switched off on every other
##     child of the HUD while a layer is open, so a gamepad or a mouse cannot
##     reach the buttons behind the modal;
##   * **where focus goes back to** -- opening a modal remembers the control
##     that had focus, closing it restores that control instead of leaving the
##     player with no focus at all.
##
## Layers are Controls that are direct children of the HUD. `on_back` is what
## ESC runs; it is expected to call `remove()` (every existing close path does),
## so a layer that is closed by its own button and a layer that is closed by ESC
## end in the same state.
class_name HudOverlayStack
extends RefCounted

var _hud: Control
var _panels: Array[Control] = []
var _back_actions: Array[Callable] = []
## The focus owner at the moment each layer opened, one per layer.
var _focus_before: Array[Control] = []


func _init(hud: Control) -> void:
	_hud = hud


func is_empty() -> bool:
	return _panels.is_empty()


func size() -> int:
	return _panels.size()


func top() -> Control:
	return _panels.back() if not _panels.is_empty() else null


func has(panel: Control) -> bool:
	return panel != null and _panels.has(panel)


## Opens `panel` on top of whatever is already open. Idempotent: pushing a panel
## that is already a layer only re-applies the trap, because `apply_paused(true)`
## and `_open_settings()` can both run for one pause.
func push(panel: Control, on_back: Callable) -> void:
	if not is_instance_valid(panel):
		return
	if _panels.has(panel):
		_trap()
		return
	var viewport := _hud.get_viewport()
	_focus_before.append(viewport.gui_get_focus_owner() if viewport != null else null)
	_panels.append(panel)
	_back_actions.append(on_back)
	_trap()


## Closes `panel`, or the top layer when `panel` is null. Restores the focus the
## layer took and re-traps for the layer underneath (settings closes back onto
## pause, so the trap has to move rather than lift).
func remove(panel: Control = null) -> void:
	var index := _panels.size() - 1 if panel == null else _panels.find(panel)
	if index < 0 or index >= _panels.size():
		return
	var focused: Control = _focus_before[index]
	_panels.remove_at(index)
	_back_actions.remove_at(index)
	_focus_before.remove_at(index)
	if _panels.is_empty():
		_release()
	else:
		_trap()
	if is_instance_valid(focused) and focused.is_inside_tree() and focused.is_visible_in_tree():
		focused.grab_focus()


## Closes everything without asking anybody: the run was resumed, so none of the
## overlays' own close paths (which expect a paused tree) may run.
func clear() -> void:
	_panels.clear()
	_back_actions.clear()
	_focus_before.clear()
	_release()


## ESC. Returns true when a layer consumed it, so the caller can stop looking.
func back() -> bool:
	if _panels.is_empty():
		return false
	var action: Callable = _back_actions.back()
	if action.is_valid():
		action.call()
	else:
		remove()
	return true


func _trap() -> void:
	var target := top()
	if target == null:
		return
	for child in _hud.get_children():
		if child is Control:
			_set_recursive_enabled(child as Control, child == target)


func _release() -> void:
	for child in _hud.get_children():
		if child is Control:
			_set_recursive_enabled(child as Control, true)


## Godot 4.5 added both properties; guard by name so a project pinned to an older
## 4.x still runs (the trap is then simply absent) instead of failing to parse.
static func _set_recursive_enabled(control: Control, enabled: bool) -> void:
	if "focus_behavior_recursive" in control:
		control.focus_behavior_recursive = (
			Control.FOCUS_BEHAVIOR_INHERITED if enabled else Control.FOCUS_BEHAVIOR_DISABLED
		)
	if "mouse_behavior_recursive" in control:
		control.mouse_behavior_recursive = (
			Control.MOUSE_BEHAVIOR_INHERITED if enabled else Control.MOUSE_BEHAVIOR_DISABLED
		)
