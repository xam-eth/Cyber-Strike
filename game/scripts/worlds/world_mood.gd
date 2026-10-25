class_name WorldMood
extends RefCounted

## world_mood.gd — the art direction of each mission world, as data.
##
## Each mission has its own mood, and the mood is what tells them apart once the
## camera is inside one. The values here are the Godot half of
## `tools/asset-forge/src/worlds/themes.js`: the forge decides how the *surfaces*
## are graded and photographed, this file decides how they are *lit* in-engine.
## Keeping both lists next to each other and in the same order is deliberate —
## `tests/world_palette_smoke.gd` reads both and fails if a world's key light,
## sky, fog or accent stops matching its theme.
##
## A mood is one dictionary:
##
##   label, mood      what the launcher card and this file say about it
##   sky, ambient     background and ambient fill (Godot `Color`, sRGB)
##   fog, fog_density atmosphere: the haze that makes a field look big
##   key/fill/rim     the three directional lights, as `position` + colour
##   accent, glow     the emissive light at the landmark, and bloom strength
##   exposure, sat    tonemapping white and saturation adjustment
##
## A `position` is where the light sits relative to the field centre; the rig
## aims it at the centre, so the same numbers read the same way in three.js and
## here. Energies are Godot's: the forge's HDR intensities are scaled down,
## because three.js lights and Godot lights do not share units.

const MOODS := {
	"frostline_relay":
	{
		"label": "Frostline Relay",
		"mood": "polar dusk: white ice, cyan light, air you can see",
		"sky": Color(0.051, 0.169, 0.231),
		"ambient": Color(0.365, 0.510, 0.596),
		"ambient_energy": 0.9,
		"fog": Color(0.125, 0.255, 0.310),
		"fog_density": 0.0058,
		"key":
		{
			"name": "MissionKeyLight",
			"color": Color(0.812, 0.894, 1.0),
			"energy": 1.0,
			"position": Vector3(-52.0, 46.0, -96.0),
		},
		"fill":
		{
			"name": "MissionFillLight",
			"color": Color(0.431, 0.643, 0.910),
			"energy": 0.34,
			"position": Vector3(96.0, 34.0, 24.0),
		},
		"rim":
		{
			"name": "MissionRimLight",
			"color": Color(0.561, 0.894, 1.0),
			"energy": 0.4,
			"position": Vector3(-30.0, 18.0, 88.0),
		},
		"accent": Color(0.349, 0.902, 1.0),
		"accent_energy": 0.7,
		"accent_range": 14.0,
		"exposure": 1.0,
		"saturation": 0.92,
		"contrast": 1.06,
		"glow": 0.5,
	},
	"verdant_bloom":
	{
		"label": "Verdant Bloom",
		"mood": "humid overgrowth: moss, spore light, a warm green sun",
		"sky": Color(0.078, 0.196, 0.149),
		"ambient": Color(0.435, 0.612, 0.486),
		"ambient_energy": 0.85,
		"fog": Color(0.082, 0.188, 0.122),
		"fog_density": 0.0072,
		"key":
		{
			"name": "MissionKeyLight",
			"color": Color(1.0, 0.941, 0.753),
			"energy": 1.35,
			"position": Vector3(-24.0, 92.0, 58.0),
		},
		"fill":
		{
			"name": "MissionFillLight",
			"color": Color(0.388, 0.788, 0.541),
			"energy": 0.46,
			"position": Vector3(88.0, 28.0, -34.0),
		},
		"rim":
		{
			"name": "MissionRimLight",
			"color": Color(0.604, 0.408, 0.902),
			"energy": 0.34,
			"position": Vector3(-76.0, 22.0, -52.0),
		},
		"accent": Color(0.549, 1.0, 0.620),
		"accent_energy": 0.55,
		"accent_range": 16.0,
		"exposure": 1.0,
		"saturation": 1.02,
		"contrast": 1.04,
		"glow": 0.62,
	},
	"emberfall_foundry":
	{
		"label": "Emberfall Foundry",
		"mood": "volcanic industry: black basalt, molten seams, ash in the air",
		"sky": Color(0.114, 0.043, 0.024),
		"ambient": Color(0.369, 0.208, 0.125),
		"ambient_energy": 0.85,
		"fog": Color(0.239, 0.102, 0.059),
		"fog_density": 0.0078,
		"key":
		{
			"name": "MissionKeyLight",
			"color": Color(1.0, 0.616, 0.329),
			"energy": 1.15,
			"position": Vector3(-70.0, 40.0, -40.0),
		},
		"fill":
		{
			"name": "MissionFillLight",
			"color": Color(1.0, 0.353, 0.118),
			"energy": 0.32,
			"position": Vector3(40.0, -8.0, 30.0),
		},
		"rim":
		{
			"name": "MissionRimLight",
			"color": Color(0.333, 0.376, 0.847),
			"energy": 0.3,
			"position": Vector3(70.0, 30.0, -70.0),
		},
		"accent": Color(1.0, 0.478, 0.118),
		"accent_energy": 1.1,
		"accent_range": 18.0,
		"exposure": 1.0,
		"saturation": 0.96,
		"contrast": 1.1,
		"glow": 0.8,
	},
	"titans":
	{
		"label": "THE TITANS",
		"mood": "breached station interior: emergency amber, alien cyan, settled dust",
		"sky": Color(0.019608, 0.039216, 0.070588),
		"ambient": Color(0.352941, 0.415686, 0.470588),
		"ambient_energy": 0.85,
		"fog": Color(0.101961, 0.149020, 0.180392),
		"fog_density": 0.0042,
		"key":
		{
			"name": "MissionKeyLight",
			"color": Color(1.0, 0.878431, 0.658824),
			"energy": 1.0,
			"position": Vector3(0.0, 44.0, 8.0),
		},
		"fill":
		{
			"name": "MissionFillLight",
			"color": Color(0.486275, 0.941176, 1.0),
			"energy": 0.42,
			"position": Vector3(-18.0, 18.0, -12.0),
		},
		"rim":
		{
			"name": "MissionRimLight",
			"color": Color(0.415686, 0.431373, 1.0),
			"energy": 0.36,
			"position": Vector3(0.0, 14.0, -32.0),
		},
		"accent": Color(1.0, 0.478431, 0.117647),
		"accent_energy": 0.9,
		"accent_range": 10.0,
		"exposure": 1.25,
		"saturation": 1.0,
		"contrast": 1.08,
		"glow": 0.38,
	},
}

## Same order as `THEME_ORDER` in themes.js and `MISSION_WORLD.WORLD_ORDER`.
const MOOD_ORDER: Array[String] = [
	"frostline_relay",
	"verdant_bloom",
	"emberfall_foundry",
	"titans",
]


static func has_mood(world_id: String) -> bool:
	return MOODS.has(world_id)


## The mood for a world, falling back to the first mission rather than to null:
## a lighting rig is not something a missing id should be able to delete.
static func mood(world_id: String) -> Dictionary:
	return MOODS.get(world_id, MOODS[MOOD_ORDER[0]])


static func label(world_id: String) -> String:
	return String(mood(world_id).get("label", world_id))
