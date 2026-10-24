## Transitions between Pause → Settings → HUD Editor without putting editor
## construction or persistence into the already-large TouchControls facade.
class_name HudEditorBridge
extends RefCounted


static func install(hud) -> void:
	hud._hud_editor = AegisHudEditor.new()
	hud._hud_editor.name = "HudEditor"
	hud._hud_editor.visible = false
	hud._hud_editor.changed.connect(_on_changed.bind(hud))
	hud._hud_editor.done.connect(close.bind(hud))
	hud._settings_menu.editor_requested.connect(open.bind(hud))
	hud.add_child(hud._hud_editor)


static func open(hud) -> void:
	if not hud.get_tree().paused:
		return
	hud._settings_menu.visible = false
	hud._pause_panel.visible = false
	hud._top_bar.visible = true
	hud._scrim.visible = false
	hud._hud_editor.open(hud, hud._settings_menu.values)
	print("HUD: editor opened")


static func close(hud) -> void:
	hud._hud_editor.close()
	if not hud.get_tree().paused:
		return
	hud._scrim.visible = true
	hud._top_bar.visible = false
	hud._settings_menu.open()
	print("HUD: editor closed")


static func layout(hud) -> void:
	if is_instance_valid(hud._hud_editor):
		hud._hud_editor.apply_layout(
			hud._stretch, hud._ui_scale * hud._hud_scale * hud._text_scale, hud._physical_size
		)


static func _on_changed(values: Dictionary, hud) -> void:
	hud._settings_menu.values = values.duplicate(true)
	hud._apply_preferences(values)
