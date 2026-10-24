## Persistent AEGIS UI settings. Values are clamped on read as well as write:
## an edited user:// file should never make HUD targets too small or turn the
## camera sensitivity negative. AudioDirector still owns the actual mute state.
class_name AegisPreferences
extends RefCounted

const PATH := "user://aegis.cfg"
const SECTION := "settings"
const DEFAULTS := {
	"sensitivity": 1.0,
	"hud_scale": 1.0,
	"hud_opacity": 1.0,
	"text_scale": 1.0,
	"left_handed": false,
	"colorblind": false,
	"reduce_motion": false,
	"reduce_flash": false,
	"muted": false,
	"hud_preset": "STANDARD",
	"hud_offsets": {},
}
const HUD_GROUPS := [
	"VITALS",
	"WAVE",
	"SYSTEM",
	"RUN",
	"SCORE",
	"COMPACT",
	"FIRE",
	"AIM",
	"EMP",
	"SWAP",
	"AMMO",
]


static func defaults() -> Dictionary:
	return DEFAULTS.duplicate(true)


static func read(file_path: String = PATH) -> Dictionary:
	var values := defaults()
	var config := ConfigFile.new()
	if config.load(file_path) == OK:
		for key in DEFAULTS:
			values[key] = config.get_value(SECTION, key, DEFAULTS[key])
	return sanitized(values)


static func sanitized(source: Dictionary) -> Dictionary:
	var values := defaults()
	values["sensitivity"] = clampf(float(source.get("sensitivity", 1.0)), 0.5, 1.5)
	values["hud_scale"] = clampf(float(source.get("hud_scale", 1.0)), 0.8, 1.2)
	values["hud_opacity"] = clampf(float(source.get("hud_opacity", 1.0)), 0.65, 1.0)
	values["text_scale"] = clampf(float(source.get("text_scale", 1.0)), 1.0, 1.3)
	for key in ["left_handed", "colorblind", "reduce_motion", "reduce_flash", "muted"]:
		values[key] = bool(source.get(key, false))
	var preset := String(source.get("hud_preset", "STANDARD"))
	values["hud_preset"] = preset if preset in ["MINIMAL", "STANDARD", "ADVANCED"] else "STANDARD"
	var offsets: Dictionary = {}
	var raw_offsets = source.get("hud_offsets", {})
	if raw_offsets is Dictionary:
		for key in HUD_GROUPS:
			var raw = raw_offsets.get(key, Vector2.ZERO)
			if raw is Vector2 and raw != Vector2.ZERO:
				offsets[key] = Vector2(
					roundf(clampf(raw.x, -640.0, 640.0) / 8.0) * 8.0,
					roundf(clampf(raw.y, -360.0, 360.0) / 8.0) * 8.0
				)
	values["hud_offsets"] = offsets
	return values


static func write(source: Dictionary, file_path: String = PATH) -> Error:
	var values := sanitized(source)
	var config := ConfigFile.new()
	for key in values:
		config.set_value(SECTION, key, values[key])
	return config.save(file_path)
