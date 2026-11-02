class_name WorldMood
extends RefCounted

## world_mood.gd — canonical lighting & atmosphere fallback for SH-01 Aetherfall.

const MOODS := {
	"aetherfall":
	{
		"label": "Aetherfall — Sentinel Citadel",
		"mood": "polar glacier citadel, cyan beacon spine, aurora sky and drifting snow",
		"sky": Color(0.11, 0.21, 0.35),
		"ambient": Color(0.36, 0.52, 0.68),
		"ambient_energy": 0.72,
		"fog": Color(0.34, 0.49, 0.64),
		"fog_density": 0.00055,
		"key":
		{
			"name": "MissionKeyLight",
			"color": Color(0.92, 0.96, 1.0),
			"energy": 1.38,
			"position": Vector3(-90.0, 120.0, -70.0),
		},
		"fill":
		{
			"name": "MissionFillLight",
			"color": Color(0.45, 0.68, 0.92),
			"energy": 0.36,
			"position": Vector3(85.0, 50.0, 45.0),
		},
		"rim":
		{
			"name": "MissionRimLight",
			"color": Color(0.22, 0.84, 1.0),
			"energy": 0.58,
			"position": Vector3(0.0, 34.0, -26.0),
		},
		"accent": Color(0.18, 0.78, 1.0),
		"accent_energy": 0.95,
		"accent_range": 18.0,
		"exposure": 1.02,
		"saturation": 1.02,
		"contrast": 1.06,
		"glow": 0.34,
	},
}

const MOOD_ORDER: Array[String] = [
	"aetherfall",
]


static func has_mood(world_id: String) -> bool:
	return MOODS.has(world_id)


static func mood(world_id: String) -> Dictionary:
	return MOODS.get(world_id, MOODS[MOOD_ORDER[0]])


static func for_world(world_id: String) -> Dictionary:
	return mood(world_id)


static func sun_color(world_id: String) -> Color:
	var key_spec: Dictionary = mood(world_id).get("key", {}) as Dictionary
	return key_spec.get("color", Color(0.92, 0.96, 1.0)) as Color


static func fog_color(world_id: String) -> Color:
	return mood(world_id).get("fog", Color(0.34, 0.49, 0.64)) as Color


static func label(world_id: String) -> String:
	return String(mood(world_id).get("label", world_id))
