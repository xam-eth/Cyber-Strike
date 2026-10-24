## Applies saved editor offsets after each platform's default layout. Offsets
## are stored in 1280x720 design units, not in the active canvas units: they
## survive orientation changes and the Web canvas_items stretch factor.
class_name HudEditorLayout
extends RefCounted

const CONTROLS := {
	"VITALS": "_health_card",
	"WAVE": "_wave_card",
	"SYSTEM": "_system_row",
	"RUN": "_run_card",
	"SCORE": "_score_chip",
	"COMPACT": "_compact_card",
	"FIRE": "_fire_button",
	"AIM": "_aim_button",
	"EMP": "_skill_button",
	"SWAP": "_weapon_button",
	"AMMO": "_touch_ammo_chip",
}


static func apply(hud) -> void:
	if hud._hud_preset == "MINIMAL":
		hud._help_panel.visible = false
		hud._desktop_hint.visible = false
		hud._run_card.visible = false
		hud._score_chip.visible = false
	elif hud._hud_preset == "ADVANCED" and not hud.get_tree().paused:
		hud._help_panel.visible = true
		hud._help_panel.modulate.a = 1.0
	for key in AegisPreferences.HUD_GROUPS:
		if not hud._hud_offsets.has(key):
			continue
		var offset: Vector2 = hud._hud_offsets[key]
		var target := hud.get(CONTROLS[key]) as Control
		_move(hud, target, offset)
		if key == "EMP":
			_move(hud, hud._skill_ring, offset)
		elif key == "SWAP":
			_move(hud, hud._touch_ammo_chip, offset)


static func _move(hud, target: Control, offset: Vector2) -> void:
	if not is_instance_valid(target):
		return
	var rect := target.get_global_rect()
	var margin: float = hud._to_layout(12.0)
	var dx := clampf(
		offset.x * hud.size.x / 1280.0, margin - rect.position.x, hud.size.x - margin - rect.end.x
	)
	var dy := clampf(
		offset.y * hud.size.y / 720.0, margin - rect.position.y, hud.size.y - margin - rect.end.y
	)
	target.offset_left += dx
	target.offset_right += dx
	target.offset_top += dy
	target.offset_bottom += dy
