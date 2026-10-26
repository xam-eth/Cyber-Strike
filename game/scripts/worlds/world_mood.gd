class_name WorldMood
extends RefCounted

## world_mood.gd — the Godot lighting half of the STELLAR HORIZON forge themes.
##
## All four theatres share one physical route. Daytime, sunset, night and storm
## are therefore carried by light, sky, fog and surface dressing rather than by
## four unrelated layouts. Colours and positions mirror
## `tools/asset-forge/src/worlds/themes.js`; energies are scaled for Godot because
## three.js and Godot lights do not share units.
##
## A `position` is where the light sits relative to the field centre; the rig
## aims it at the centre, so the same direction reads in the forge and in-game.

const MOODS := {
	"frostline_relay":
	{
		"label": "Frostline Relay — Daytime",
		"mood": "bright floating archipelago, blue sky and a cyan tower beam",
		"sky": Color(0.180392, 0.494118, 0.721569),
		"ambient": Color(0.556863, 0.776471, 1.0),
		"ambient_energy": 0.68,
		"fog": Color(0.611765, 0.776471, 0.909804),
		"fog_density": 0.0016,
		"key":
		{
			"name": "MissionKeyLight",
			"color": Color(1.0, 0.968627, 0.878431),
			"energy": 1.72,
			"position": Vector3(-120.0, 140.0, -80.0),
		},
		"fill":
		{
			"name": "MissionFillLight",
			"color": Color(0.556863, 0.776471, 1.0),
			"energy": 0.57,
			"position": Vector3(90.0, 60.0, 40.0),
		},
		"rim":
		{
			"name": "MissionRimLight",
			"color": Color(0.349020, 0.901961, 1.0),
			"energy": 0.70,
			"position": Vector3(0.0, 32.0, 0.0),
		},
		"accent": Color(0.349020, 0.901961, 1.0),
		"accent_energy": 0.85,
		"accent_range": 16.0,
		"exposure": 1.18,
		"saturation": 1.0,
		"contrast": 1.06,
		"glow": 0.28,
	},
	"verdant_bloom":
	{
		"label": "Verdant Bloom — Sunset",
		"mood": "golden-hour islands, humid haze and a cyan tower against amber sky",
		"sky": Color(0.227451, 0.125490, 0.250980),
		"ambient": Color(1.0, 0.603922, 0.352941),
		"ambient_energy": 0.60,
		"fog": Color(0.164706, 0.101961, 0.125490),
		"fog_density": 0.0028,
		"key":
		{
			"name": "MissionKeyLight",
			"color": Color(1.0, 0.721569, 0.415686),
			"energy": 1.65,
			"position": Vector3(140.0, 40.0, -60.0),
		},
		"fill":
		{
			"name": "MissionFillLight",
			"color": Color(1.0, 0.603922, 0.352941),
			"energy": 0.61,
			"position": Vector3(-80.0, 30.0, 40.0),
		},
		"rim":
		{
			"name": "MissionRimLight",
			"color": Color(0.349020, 0.901961, 1.0),
			"energy": 0.60,
			"position": Vector3(0.0, 32.0, 0.0),
		},
		"accent": Color(0.349020, 0.901961, 1.0),
		"accent_energy": 0.75,
		"accent_range": 16.0,
		"exposure": 1.28,
		"saturation": 1.04,
		"contrast": 1.04,
		"glow": 0.38,
	},
	"emberfall_foundry":
	{
		"label": "Emberfall Foundry — Night",
		"mood": "deep navy night, city light and a readable cyan interior glow",
		"sky": Color(0.039216, 0.058824, 0.117647),
		"ambient": Color(0.164706, 0.227451, 0.352941),
		"ambient_energy": 0.44,
		"fog": Color(0.039216, 0.078431, 0.156863),
		"fog_density": 0.0022,
		"key":
		{
			"name": "MissionKeyLight",
			"color": Color(0.556863, 0.721569, 1.0),
			"energy": 0.92,
			"position": Vector3(80.0, 90.0, -40.0),
		},
		"fill":
		{
			"name": "MissionFillLight",
			"color": Color(0.349020, 0.901961, 1.0),
			"energy": 0.78,
			"position": Vector3(40.0, 20.0, 30.0),
		},
		"rim":
		{
			"name": "MissionRimLight",
			"color": Color(0.349020, 0.901961, 1.0),
			"energy": 1.06,
			"position": Vector3(0.0, 32.0, 0.0),
		},
		"accent": Color(0.349020, 0.901961, 1.0),
		"accent_energy": 1.0,
		"accent_range": 18.0,
		"exposure": 1.35,
		"saturation": 0.92,
		"contrast": 1.10,
		"glow": 0.42,
	},
	"titans":
	{
		"label": "THE TITANS — Storm",
		"mood": "low storm cloud, rain haze, lightning rim and interior shelter light",
		"sky": Color(0.101961, 0.137255, 0.180392),
		"ambient": Color(0.352941, 0.415686, 0.478431),
		"ambient_energy": 0.49,
		"fog": Color(0.101961, 0.133333, 0.180392),
		"fog_density": 0.0048,
		"key":
		{
			"name": "MissionKeyLight",
			"color": Color(0.752941, 0.815686, 0.909804),
			"energy": 1.19,
			"position": Vector3(-40.0, 80.0, 60.0),
		},
		"fill":
		{
			"name": "MissionFillLight",
			"color": Color(0.541176, 0.949020, 1.0),
			"energy": 0.84,
			"position": Vector3(60.0, 40.0, -30.0),
		},
		"rim":
		{
			"name": "MissionRimLight",
			"color": Color(0.349020, 0.901961, 1.0),
			"energy": 0.89,
			"position": Vector3(0.0, 32.0, 0.0),
		},
		"accent": Color(0.349020, 0.901961, 1.0),
		"accent_energy": 0.90,
		"accent_range": 16.0,
		"exposure": 1.15,
		"saturation": 0.96,
		"contrast": 1.08,
		"glow": 0.32,
	},
}

## Stable presentation order; not a second environment/asset registry.
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
