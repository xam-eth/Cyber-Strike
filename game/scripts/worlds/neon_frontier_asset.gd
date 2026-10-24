@tool
extends Node3D

const ScifiBayBuilder = preload("res://scripts/worlds/scifi_bay_builder.gd")
# 171 shapes are built in this file; the short alias keeps those calls on one line.
const GEOMETRY = preload("res://scripts/worlds/neon_frontier/geometry.gd")

@export_enum(
	"reactor_core",
	"command_center",
	"research_lab",
	"equipment_depot",
	"generator_bank",
	"boss_gate",
	"defense_turret",
	"sensor_tower",
	"landing_pad",
	"wrecked_transport",
	"alien_drone_wreck",
	"crystal_cluster",
	"alien_flora",
	"rock_cluster",
	"enemy_spawn_gate",
	"cover_module"
)
var asset_kind: String = "reactor_core"
@export_range(0, 9999, 1) var variant_seed: int = 0

var _materials: Dictionary = {}
var _built: bool = false


func _ready() -> void:
	if _built or not get_children().is_empty():
		return
	_built = true
	_create_materials()
	match asset_kind:
		"reactor_core":
			_build_reactor_core()
		"command_center":
			_build_command_center()
		"research_lab":
			_build_research_lab()
		"equipment_depot":
			_build_equipment_depot()
		"generator_bank":
			_build_generator_bank()
		"boss_gate":
			_build_boss_gate()
		"defense_turret":
			_build_defense_turret()
		"sensor_tower":
			_build_sensor_tower()
		"landing_pad":
			_build_landing_pad()
		"wrecked_transport":
			_build_wrecked_transport()
		"alien_drone_wreck":
			_build_alien_drone_wreck()
		"crystal_cluster":
			NeonFrontierProps.build_crystal_cluster(self)
		"alien_flora":
			NeonFrontierProps.build_alien_flora(self)
		"rock_cluster":
			NeonFrontierProps.build_rock_cluster(self)
		"enemy_spawn_gate":
			NeonFrontierProps.build_enemy_spawn_gate(self)
		"cover_module":
			NeonFrontierProps.build_cover_module(self)


func _create_materials() -> void:
	_materials = {
		"silver": NeonFrontierMaterialKit.make_material(Color(0.36, 0.43, 0.48), 0.56, 0.43),
		"pearl": NeonFrontierMaterialKit.make_material(Color(0.58, 0.65, 0.7), 0.15, 0.5),
		"ceramic": NeonFrontierMaterialKit.make_material(Color(0.43, 0.52, 0.58), 0.23, 0.5),
		"blue": NeonFrontierMaterialKit.make_material(Color(0.055, 0.15, 0.28), 0.46, 0.4),
		"deep_blue": NeonFrontierMaterialKit.make_material(Color(0.025, 0.08, 0.18), 0.5, 0.44),
		"cyan": NeonFrontierMaterialKit.make_emissive(Color(0.02, 0.53, 0.7), 0.78, 0.28, 0.28),
		"turquoise":
		# The reactor's big glass and energy shapes were becoming a white/cyan
		NeonFrontierMaterialKit.make_emissive(Color(0.015, 0.6, 0.52), 0.7, 0.28, 0.28),
		# billboard in portrait; reserve the brightest values for slim halos.
		"reactor_core":
		NeonFrontierMaterialKit.make_emissive(Color(0.02, 0.3, 0.37), 0.27, 0.28, 0.28),
		"reactor_spine": NeonFrontierMaterialKit.make_material(Color(0.07, 0.16, 0.19), 0.62, 0.38),
		"reactor_coils":
		NeonFrontierMaterialKit.make_emissive(Color(0.08, 0.64, 0.58), 0.75, 0.28, 0.28),
		"emerald": NeonFrontierMaterialKit.make_emissive(Color(0.08, 0.53, 0.33), 0.58, 0.28, 0.28),
		"yellow": NeonFrontierMaterialKit.make_emissive(Color(0.9, 0.54, 0.065), 0.43, 0.28, 0.28),
		"orange": NeonFrontierMaterialKit.make_emissive(Color(1.0, 0.27, 0.035), 0.95, 0.28, 0.28),
		"red": NeonFrontierMaterialKit.make_emissive(Color(0.98, 0.045, 0.055), 1.25, 0.28, 0.28),
		"dark_trim": NeonFrontierMaterialKit.make_material(Color(0.105, 0.17, 0.2), 0.66, 0.36),
		"rock": NeonFrontierMaterialKit.make_material(Color(0.59, 0.43, 0.34), 0.02, 0.93),
		"rock_light": NeonFrontierMaterialKit.make_material(Color(0.76, 0.58, 0.42), 0.02, 0.88),
		"rock_rose": NeonFrontierMaterialKit.make_material(Color(0.64, 0.39, 0.37), 0.03, 0.9),
		"glass": NeonFrontierMaterialKit.make_translucent(Color(0.09, 0.48, 0.61, 0.2), 0.25, 0.2),
		"reactor_glass":
		NeonFrontierMaterialKit.make_translucent(Color(0.07, 0.34, 0.42, 0.085), 0.25, 0.2),
		"flora": NeonFrontierMaterialKit.make_material(Color(0.19, 0.64, 0.35), 0.0, 0.72),
		"flora_lime":
		NeonFrontierMaterialKit.make_emissive(Color(0.51, 0.87, 0.17), 0.25, 0.28, 0.28),
		"flora_teal": NeonFrontierMaterialKit.make_material(Color(0.04, 0.58, 0.54), 0.05, 0.52),
		"copper": NeonFrontierMaterialKit.make_material(Color(0.76, 0.32, 0.13), 0.65, 0.34),
	}


func _build_reactor_core() -> void:
	# Four separated footings support the suspended reactor while keeping combat lanes open.
	for x_sign in [-1.0, 1.0]:
		for z_sign in [-1.0, 1.0]:
			GEOMETRY.box(
				self,
				"ReactorFoundation_%s_%s" % [str(x_sign), str(z_sign)],
				Vector3(x_sign * 4.7, 0.09, z_sign * 4.7),
				Vector3(3.4, 0.18, 3.4),
				_materials["silver"]
			)
			GEOMETRY.box(
				self,
				"ReactorFootingStripe_%s_%s" % [str(x_sign), str(z_sign)],
				Vector3(x_sign * 4.7, 0.2, z_sign * 4.7),
				Vector3(2.8, 0.04, 2.8),
				_materials["yellow"]
			)
	GEOMETRY.box(
		self,
		"ReactorAccessWalk",
		Vector3(0.0, 0.08, 6.0),
		Vector3(2.2, 0.16, 2.0),
		_materials["silver"]
	)
	for side in [-1.0, 1.0]:
		GEOMETRY.box(
			self,
			"ReactorConduit_%s" % str(side),
			Vector3(side * 6.6, 0.52, 0.0),
			Vector3(2.4, 0.34, 1.0),
			_materials["copper"]
		)
		GEOMETRY.box(
			self,
			"ReactorConduitGlow_%s" % str(side),
			Vector3(side * 6.6, 0.72, 0.0),
			Vector3(2.0, 0.05, 0.2),
			_materials["orange"]
		)

	# Four load-bearing pylons frame a clear walkable and line-of-fire opening below the core.
	for x_sign in [-1.0, 1.0]:
		for z_sign in [-1.0, 1.0]:
			var pylon_x: float = 4.35 * x_sign
			var pylon_z: float = 4.35 * z_sign
			GEOMETRY.cylinder(
				self,
				"ReactorPylonFoot_%s_%s" % [str(x_sign), str(z_sign)],
				Vector3(pylon_x, 0.55, pylon_z),
				0.8,
				0.58,
				0.7,
				_materials["copper"]
			)
			# Keep the old mesh as an editable structural fallback, but dress the
			# visible load-bearing pylon with the user's imported FBX column.
			var blockout_pylon := GEOMETRY.box(
				self,
				"ReactorPylon_%s_%s" % [str(x_sign), str(z_sign)],
				Vector3(pylon_x, 4.55, pylon_z),
				Vector3(0.72, 7.2, 0.72),
				_materials["pearl"]
			)
			blockout_pylon.visible = false
			ScifiBayBuilder.place(
				self,
				"column",
				"SciFiReactorPylon_%s_%s" % [str(x_sign), str(z_sign)],
				Vector3(pylon_x, 0.95, pylon_z),
				0.0,
				1.0,
				true,
				true,
				Vector3(0.2, 1.8, 1.6)
			)
			GEOMETRY.box(
				self,
				"ReactorPylonLight_%s_%s" % [str(x_sign), str(z_sign)],
				Vector3(pylon_x * 1.095, 5.0, pylon_z * 1.095),
				Vector3(0.09, 5.4, 0.09),
				_materials["cyan"]
			)
			GEOMETRY.box(
				self,
				"ReactorPylonBrace_%s_%s" % [str(x_sign), str(z_sign)],
				Vector3(pylon_x * 0.73, 2.1, pylon_z * 0.73),
				Vector3(0.34, 2.5, 0.34),
				_materials["blue"],
				Vector3(18.0 * z_sign, 0.0, -18.0 * x_sign)
			)

	GEOMETRY.cylinder(
		self,
		"ContainmentGlass",
		Vector3(0.0, 7.0, 0.0),
		2.45,
		2.45,
		5.6,
		_materials["reactor_glass"],
		Vector3.ZERO,
		32
	)
	GEOMETRY.cylinder(
		self,
		"EmeraldEnergyColumn",
		Vector3(0.0, 7.0, 0.0),
		0.84,
		0.64,
		6.1,
		_materials["reactor_spine"],
		Vector3.ZERO,
		24
	)
	GEOMETRY.reactor_coils(self, _materials["reactor_coils"])
	for rail in range(6):
		var angle := TAU * float(rail) / 6.0
		GEOMETRY.box(
			self,
			"ReactorCoilRail_%02d" % rail,
			Vector3(cos(angle) * 1.06, 7.0, sin(angle) * 1.06),
			Vector3(0.12, 5.7, 0.12),
			_materials["dark_trim"],
			Vector3(0.0, -rad_to_deg(angle), 0.0)
		)
	# Focus the emissive focal point inside the larger FBX-framed structure:
	# the earlier overexposed cyan orb filled the portrait camera's horizon.
	GEOMETRY.sphere(
		self,
		"SuspendedReactorSeed",
		Vector3(0.0, 7.0, 0.0),
		Vector3(1.32, 1.63, 1.32),
		_materials["reactor_core"]
	)
	GEOMETRY.ring(self, "ContainmentLowerHalo", Vector3.ZERO, 3.1, 4.1, 0.3, _materials["cyan"], 24)
	GEOMETRY.ring(self, "ContainmentUpperHalo", Vector3.ZERO, 3.1, 9.9, 0.3, _materials["cyan"], 24)
	GEOMETRY.ring(
		self, "ReactorServiceRing", Vector3.ZERO, 4.9, 10.9, 0.42, _materials["silver"], 24
	)
	GEOMETRY.ring(
		self, "ReactorWarningRing", Vector3.ZERO, 5.1, 10.7, 0.08, _materials["orange"], 24
	)
	for quadrant in range(4):
		var angle := PI * 0.5 * float(quadrant)
		var at := Vector3(cos(angle) * 3.5, 11.2, sin(angle) * 3.5)
		GEOMETRY.box(
			self,
			"ReactorTopArm_%d" % quadrant,
			at,
			Vector3(2.6, 0.35, 0.45),
			_materials["silver"],
			Vector3(0.0, -rad_to_deg(angle), 0.0)
		)
	GEOMETRY.box(
		self,
		"ReactorTopBridge",
		Vector3(0.0, 11.65, 0.0),
		Vector3(7.0, 0.35, 0.6),
		_materials["blue"]
	)
	GEOMETRY.sphere(
		self, "ReactorBeacon", Vector3(0.0, 12.2, 0.0), Vector3(0.52, 0.8, 0.52), _materials["cyan"]
	)
	for bolt_x in [-4.0, 4.0]:
		for bolt_z in [-4.0, 4.0]:
			GEOMETRY.cylinder(
				self,
				"ReactorDeckFastener",
				Vector3(bolt_x, 0.93, bolt_z),
				0.075,
				0.075,
				0.035,
				_materials["dark_trim"],
				Vector3.ZERO,
				8
			)


func _build_command_center() -> void:
	GEOMETRY.box(
		self,
		"CommandFoundation",
		Vector3(0.0, 0.24, 0.0),
		Vector3(22.0, 0.48, 16.0),
		_materials["silver"],
		Vector3.ZERO,
		true
	)
	GEOMETRY.box(
		self,
		"CommandLowerHull",
		Vector3(0.0, 2.9, 0.0),
		Vector3(18.0, 5.0, 12.5),
		_materials["pearl"],
		Vector3.ZERO,
		true
	)
	GEOMETRY.box(
		self,
		"CommandUpperBridge",
		Vector3(0.0, 6.55, -0.25),
		Vector3(12.4, 2.4, 9.0),
		_materials["blue"]
	)
	GEOMETRY.box(
		self,
		"CommandRoof",
		Vector3(0.0, 7.85, -0.25),
		Vector3(13.4, 0.3, 10.0),
		_materials["silver"]
	)
	GEOMETRY.box(
		self,
		"CommandFrontVisor",
		Vector3(0.0, 6.85, 4.55),
		Vector3(13.0, 0.56, 0.52),
		_materials["cyan"]
	)
	GEOMETRY.box(
		self,
		"CommandSignBand",
		Vector3(0.0, 4.95, 6.32),
		Vector3(14.5, 0.24, 0.18),
		_materials["blue"]
	)
	GEOMETRY.box(
		self,
		"CommandMainDoor",
		Vector3(0.0, 1.65, 6.36),
		Vector3(3.2, 3.3, 0.24),
		_materials["deep_blue"]
	)
	GEOMETRY.box(
		self,
		"CommandDoorLight",
		Vector3(0.0, 1.8, 6.51),
		Vector3(0.1, 2.6, 0.045),
		_materials["turquoise"]
	)
	for window_index in range(6):
		var x := -6.1 + float(window_index) * 2.44
		GEOMETRY.box(
			self,
			"CommandWindow_%02d" % window_index,
			Vector3(x, 3.5, 6.32),
			Vector3(1.65, 1.75, 0.16),
			_materials["glass"]
		)
		GEOMETRY.box(
			self,
			"CommandWindowTrim_%02d" % window_index,
			Vector3(x, 2.52, 6.43),
			Vector3(1.85, 0.12, 0.16),
			_materials["blue"]
		)
	for side in [-1.0, 1.0]:
		for z in [-4.0, 0.0, 4.0]:
			GEOMETRY.box(
				self,
				"CommandSideFin",
				Vector3(side * 9.15, 2.8, z),
				Vector3(0.34, 4.6, 0.8),
				_materials["blue"]
			)
		for x in [-7.0, 7.0]:
			GEOMETRY.box(
				self,
				"CommandCornerArmor",
				Vector3(x, 3.1, side * 6.1),
				Vector3(0.45, 5.3, 0.45),
				_materials["silver"]
			)
	for vent_index in range(5):
		GEOMETRY.box(
			self,
			"CommandRoofVent_%02d" % vent_index,
			Vector3(-4.8 + vent_index * 2.4, 8.12, -2.4),
			Vector3(1.0, 0.48, 1.6),
			_materials["dark_trim"]
		)
	GEOMETRY.box(
		self,
		"CommandAntennaMast",
		Vector3(7.5, 9.2, -4.2),
		Vector3(0.22, 2.2, 0.22),
		_materials["silver"]
	)
	GEOMETRY.cylinder(
		self,
		"CommandAntennaDish",
		Vector3(7.5, 10.3, -4.2),
		0.82,
		0.82,
		0.12,
		_materials["cyan"],
		Vector3(34.0, 0.0, 0.0),
		20
	)
	GEOMETRY.box(
		self,
		"CommandRoofBeacon",
		Vector3(-7.2, 8.45, -4.0),
		Vector3(0.32, 0.68, 0.32),
		_materials["blue"]
	)
	GEOMETRY.sphere(
		self,
		"CommandRoofBeaconLens",
		Vector3(-7.2, 8.84, -4.0),
		Vector3(0.22, 0.26, 0.22),
		_materials["turquoise"]
	)
	GEOMETRY.bolts(
		self,
		"CommandFoundation",
		Vector3(0.0, 0.5, 0.0),
		Vector2(10.1, 7.1),
		0.03,
		_materials["dark_trim"]
	)


func _build_research_lab() -> void:
	GEOMETRY.box(
		self,
		"ResearchFoundation",
		Vector3(0.0, 0.22, 0.0),
		Vector3(20.0, 0.44, 14.0),
		_materials["silver"],
		Vector3.ZERO,
		true
	)
	GEOMETRY.box(
		self,
		"ResearchMainModule",
		Vector3(0.0, 2.65, 0.0),
		Vector3(16.0, 4.6, 10.5),
		_materials["ceramic"],
		Vector3.ZERO,
		true
	)
	GEOMETRY.box(
		self,
		"ResearchBlueBelt",
		Vector3(0.0, 3.5, 5.34),
		Vector3(15.8, 0.58, 0.16),
		_materials["blue"]
	)
	GEOMETRY.box(
		self,
		"ResearchWindowBand",
		Vector3(0.0, 3.55, 5.46),
		Vector3(11.8, 1.08, 0.08),
		_materials["glass"]
	)
	GEOMETRY.box(
		self,
		"ResearchEntryFrame",
		Vector3(0.0, 1.35, 5.46),
		Vector3(3.8, 2.65, 0.45),
		_materials["blue"]
	)
	GEOMETRY.box(
		self,
		"ResearchEntryDoor",
		Vector3(0.0, 1.38, 5.72),
		Vector3(2.4, 2.5, 0.16),
		_materials["silver"]
	)
	GEOMETRY.box(
		self,
		"ResearchDoorLight",
		Vector3(0.0, 1.45, 5.83),
		Vector3(0.11, 2.0, 0.04),
		_materials["cyan"]
	)
	GEOMETRY.box(
		self,
		"ResearchRoofPod",
		Vector3(0.0, 5.15, -0.2),
		Vector3(9.2, 0.6, 7.6),
		_materials["pearl"]
	)
	GEOMETRY.cylinder(
		self,
		"ResearchContainmentVessel",
		Vector3(0.0, 6.1, -0.1),
		2.7,
		2.15,
		1.9,
		_materials["glass"],
		Vector3.ZERO,
		28
	)
	GEOMETRY.cylinder(
		self,
		"ResearchSampleColumn",
		Vector3(0.0, 6.15, -0.1),
		0.75,
		0.55,
		1.55,
		_materials["emerald"],
		Vector3.ZERO,
		20
	)
	GEOMETRY.ring(
		self, "ResearchVesselRing", Vector3(0.0, 0.0, -0.1), 2.85, 6.0, 0.18, _materials["cyan"], 20
	)
	for side in [-1.0, 1.0]:
		GEOMETRY.box(
			self,
			"ResearchWing",
			Vector3(side * 7.7, 2.1, -1.0),
			Vector3(2.0, 2.8, 8.0),
			_materials["blue"]
		)
		GEOMETRY.box(
			self,
			"ResearchWingLight",
			Vector3(side * 8.75, 2.0, -1.0),
			Vector3(0.08, 2.4, 6.2),
			_materials["turquoise"]
		)
		GEOMETRY.box(
			self,
			"ResearchInstrumentPod",
			Vector3(side * 5.2, 5.2, -4.2),
			Vector3(1.4, 0.9, 1.2),
			_materials["copper"]
		)
	for vent_index in range(4):
		GEOMETRY.box(
			self,
			"ResearchRoofVent_%02d" % vent_index,
			Vector3(-5.0 + vent_index * 3.3, 5.65, 3.0),
			Vector3(1.1, 0.36, 0.72),
			_materials["dark_trim"]
		)
	GEOMETRY.link_cylinder(
		self,
		"ResearchMaintenanceArm",
		Vector3(8.0, 4.1, -3.8),
		Vector3(10.2, 3.1, -2.8),
		0.14,
		_materials["silver"]
	)
	GEOMETRY.sphere(
		self,
		"ResearchToolEnd",
		Vector3(10.25, 3.1, -2.8),
		Vector3(0.3, 0.3, 0.3),
		_materials["yellow"]
	)
	GEOMETRY.bolts(
		self, "ResearchFoundation", Vector3.ZERO, Vector2(9.2, 6.2), 0.47, _materials["dark_trim"]
	)


func _build_equipment_depot() -> void:
	GEOMETRY.box(
		self,
		"DepotFoundation",
		Vector3(0.0, 0.2, 0.0),
		Vector3(19.0, 0.4, 13.0),
		_materials["silver"],
		Vector3.ZERO,
		true
	)

	ScifiBayBuilder.place(
		self,
		"wall_cube",
		"SciFiEquipmentDepotFacade",
		Vector3(-3.6, 0.4, 0.0),
		90.0,
		1.85,
		true,
		true
	)
	ScifiBayBuilder.place(
		self, "doorway", "SciFiEquipmentDepotAccess", Vector3(-3.6, 0.4, 5.2), 0.0, 1.3, false, true
	)

	for crate_index in range(4):
		var crate_x := 7.0 + float(crate_index % 2) * 1.7
		var crate_z := 3.1 + float(crate_index / 2) * 1.6
		ScifiBayBuilder.place(
			self,
			"crate",
			"SciFiEquipmentSupply_%02d" % crate_index,
			Vector3(crate_x, 0.4, crate_z),
			float(crate_index) * 90.0,
			1.2,
			false,
			true
		)
	GEOMETRY.bolts(
		self, "DepotFoundation", Vector3.ZERO, Vector2(8.8, 5.8), 0.42, _materials["dark_trim"]
	)


func _build_generator_bank() -> void:
	GEOMETRY.box(
		self,
		"GeneratorFoundation",
		Vector3(0.0, 0.26, 0.0),
		Vector3(26.0, 0.52, 18.0),
		_materials["silver"],
		Vector3.ZERO,
		true
	)
	GEOMETRY.box(
		self,
		"GeneratorLowerDeck",
		Vector3(0.0, 0.56, 0.0),
		Vector3(24.0, 0.16, 16.0),
		_materials["blue"]
	)
	for tower_index in range(3):
		var x := -8.0 + float(tower_index) * 8.0
		GEOMETRY.cylinder(
			self,
			"GeneratorHousing_%d" % tower_index,
			Vector3(x, 4.1, 0.0),
			2.5,
			2.0,
			7.0,
			_materials["pearl"],
			Vector3.ZERO,
			28
		)
		GEOMETRY.cylinder(
			self,
			"GeneratorCoreGlass_%d" % tower_index,
			Vector3(x, 4.25, 0.0),
			1.58,
			1.42,
			6.2,
			_materials["glass"],
			Vector3.ZERO,
			24
		)
		GEOMETRY.cylinder(
			self,
			"GeneratorEnergyColumn_%d" % tower_index,
			Vector3(x, 4.2, 0.0),
			0.72,
			0.8,
			5.9,
			_materials["turquoise"] if tower_index == 1 else _materials["emerald"],
			Vector3.ZERO,
			20
		)
		for band_index in range(4):
			var y := 1.2 + float(band_index) * 1.8
			GEOMETRY.cylinder(
				self,
				"GeneratorBand_%d_%d" % [tower_index, band_index],
				Vector3(x, y, 0.0),
				2.62,
				2.62,
				0.16,
				_materials["copper"] if band_index == 0 else _materials["silver"],
				Vector3.ZERO,
				28
			)
			GEOMETRY.cylinder(
				self,
				"GeneratorBandLight_%d_%d" % [tower_index, band_index],
				Vector3(x, y + 0.11, 0.0),
				2.64,
				2.64,
				0.06,
				_materials["orange"] if band_index == 0 else _materials["cyan"],
				Vector3.ZERO,
				28
			)
		for side in [-1.0, 1.0]:
			GEOMETRY.box(
				self,
				"GeneratorRadialBrace_%d_%s" % [tower_index, str(side)],
				Vector3(x + side * 2.1, 3.9, 0.0),
				Vector3(0.22, 6.3, 0.22),
				_materials["blue"]
			)
		GEOMETRY.sphere(
			self,
			"GeneratorCrown_%d" % tower_index,
			Vector3(x, 8.1, 0.0),
			Vector3(1.1, 0.75, 1.1),
			_materials["cyan"]
		)
	for pipe_z in [-6.2, 6.2]:
		GEOMETRY.box(
			self,
			"GeneratorManifold",
			Vector3(0.0, 2.6, pipe_z),
			Vector3(22.0, 0.75, 0.65),
			_materials["copper"]
		)
		GEOMETRY.box(
			self,
			"GeneratorManifoldGlow",
			Vector3(0.0, 3.02, pipe_z),
			Vector3(21.5, 0.08, 0.24),
			_materials["orange"]
		)
	for x in [-8.0, 0.0, 8.0]:
		GEOMETRY.link_cylinder(
			self,
			"GeneratorFeedPipe",
			Vector3(x, 2.6, -6.2),
			Vector3(x, 2.6, -2.2),
			0.3,
			_materials["cyan"]
		)
		GEOMETRY.link_cylinder(
			self,
			"GeneratorReturnPipe",
			Vector3(x, 2.1, 2.2),
			Vector3(x, 2.1, 6.2),
			0.24,
			_materials["copper"]
		)
	GEOMETRY.box(
		self,
		"GeneratorServiceWalk",
		Vector3(0.0, 1.2, -8.4),
		Vector3(20.0, 0.34, 1.0),
		_materials["yellow"]
	)
	for edge_x in [-11.6, 11.6]:
		GEOMETRY.box(
			self,
			"GeneratorSafetyRail",
			Vector3(edge_x, 1.95, -8.4),
			Vector3(0.16, 1.5, 1.0),
			_materials["silver"]
		)
	GEOMETRY.bolts(
		self, "GeneratorFoundation", Vector3.ZERO, Vector2(12.0, 8.0), 0.54, _materials["dark_trim"]
	)


func _build_boss_gate() -> void:
	GEOMETRY.box(
		self,
		"BossGateFoundation",
		Vector3(0.0, 0.28, 0.0),
		Vector3(36.0, 0.56, 7.0),
		_materials["silver"],
		Vector3.ZERO,
		true
	)
	for side in [-1.0, 1.0]:
		GEOMETRY.box(
			self,
			"BossGatePillar_%s" % str(side),
			Vector3(side * 13.2, 11.4, 0.0),
			Vector3(4.8, 22.8, 6.0),
			_materials["blue"],
			Vector3.ZERO,
			true
		)
		GEOMETRY.box(
			self,
			"BossGatePillarArmor_%s" % str(side),
			Vector3(side * 13.2, 11.4, 3.05),
			Vector3(3.5, 20.2, 0.18),
			_materials["pearl"]
		)
		GEOMETRY.box(
			self,
			"BossGateEnergyRail_%s" % str(side),
			Vector3(side * 10.8, 11.5, 3.2),
			Vector3(0.28, 19.8, 0.18),
			_materials["cyan"]
		)
		GEOMETRY.box(
			self,
			"BossGateButtress_%s" % str(side),
			Vector3(side * 16.0, 8.4, -1.5),
			Vector3(3.5, 16.8, 3.4),
			_materials["silver"]
		)
		GEOMETRY.cylinder(
			self,
			"BossGateConduitNode_%s" % str(side),
			Vector3(side * 13.2, 19.5, 3.25),
			0.72,
			0.72,
			0.42,
			_materials["orange"],
			Vector3(90.0, 0.0, 0.0),
			16
		)
		GEOMETRY.box(
			self,
			"BossGateWarning_%s" % str(side),
			Vector3(side * 13.2, 21.0, 3.25),
			Vector3(0.34, 0.75, 0.18),
			_materials["red"]
		)
		GEOMETRY.box(
			self,
			"BossGateDoorLeaf_%s" % str(side),
			Vector3(side * 4.3, 8.9, 0.0),
			Vector3(8.4, 17.6, 1.1),
			_materials["dark_trim"]
		)
	for slat_index in range(10):
		var y := 1.0 + float(slat_index) * 1.65
		GEOMETRY.box(
			self,
			"BossGateShutterSlat_%02d" % slat_index,
			Vector3(0.0, y, 0.75),
			Vector3(8.2, 0.18, 0.14),
			_materials["silver"]
		)
		GEOMETRY.box(
			self,
			"BossGateShutterLight_%02d" % slat_index,
			Vector3(0.0, y + 0.22, 0.84),
			Vector3(2.4, 0.06, 0.05),
			_materials["cyan"]
		)
	GEOMETRY.box(
		self,
		"BossGateHeader",
		Vector3(0.0, 22.8, 0.0),
		Vector3(30.0, 2.4, 7.0),
		_materials["pearl"]
	)
	GEOMETRY.box(
		self,
		"BossGateHeaderBlue",
		Vector3(0.0, 21.5, 3.2),
		Vector3(18.0, 0.32, 0.22),
		_materials["blue"]
	)
	GEOMETRY.box(
		self,
		"BossGateHeaderEnergy",
		Vector3(0.0, 21.15, 3.32),
		Vector3(10.0, 0.08, 0.08),
		_materials["turquoise"]
	)
	for side in [-1.0, 1.0]:
		for offset in [-5.0, 0.0, 5.0]:
			GEOMETRY.link_cylinder(
				self,
				"BossGatePowerConduit",
				Vector3(side * 14.5, 2.0, -2.6),
				Vector3(side * 14.5, 18.5, -2.6 + offset * 0.12),
				0.28,
				_materials["copper"]
			)
	GEOMETRY.bolts(
		self, "BossGateFoundation", Vector3.ZERO, Vector2(17.0, 3.0), 0.57, _materials["dark_trim"]
	)


func _build_defense_turret() -> void:
	GEOMETRY.cylinder(
		self,
		"TurretMountPlate",
		Vector3(0.0, 0.22, 0.0),
		2.7,
		2.7,
		0.44,
		_materials["yellow"],
		Vector3.ZERO,
		20
	)
	GEOMETRY.cylinder(
		self,
		"TurretArmoredFoot",
		Vector3(0.0, 0.75, 0.0),
		2.05,
		1.75,
		0.8,
		_materials["blue"],
		Vector3.ZERO,
		20
	)
	GEOMETRY.cylinder(
		self,
		"TurretYawBearing",
		Vector3(0.0, 1.28, 0.0),
		1.5,
		1.5,
		0.22,
		_materials["silver"],
		Vector3.ZERO,
		20
	)
	GEOMETRY.box(
		self, "TurretHousing", Vector3(0.0, 2.25, 0.0), Vector3(2.5, 1.25, 2.4), _materials["pearl"]
	)
	GEOMETRY.box(
		self, "TurretFrontArmor", Vector3(0.0, 2.2, 1.2), Vector3(1.9, 0.9, 0.2), _materials["blue"]
	)
	for barrel_index in range(2):
		var x := -0.52 + float(barrel_index) * 1.04
		GEOMETRY.link_cylinder(
			self,
			"TurretBarrel_%d" % barrel_index,
			Vector3(x, 2.1, 1.3),
			Vector3(x, 2.1, 3.7),
			0.18,
			_materials["silver"]
		)
		GEOMETRY.cylinder(
			self,
			"TurretMuzzle_%d" % barrel_index,
			Vector3(x, 2.1, 3.75),
			0.23,
			0.25,
			0.25,
			_materials["orange"],
			Vector3(90.0, 0.0, 0.0),
			16
		)
	GEOMETRY.box(
		self,
		"TurretSensorStem",
		Vector3(0.0, 3.18, -0.25),
		Vector3(0.16, 0.78, 0.16),
		_materials["silver"]
	)
	GEOMETRY.sphere(
		self,
		"TurretSensor",
		Vector3(0.0, 3.62, -0.25),
		Vector3(0.48, 0.36, 0.42),
		_materials["cyan"]
	)
	for side in [-1.0, 1.0]:
		GEOMETRY.box(
			self,
			"TurretSideLight_%s" % str(side),
			Vector3(side * 1.34, 2.28, -0.2),
			Vector3(0.08, 0.32, 0.72),
			_materials["orange"]
		)
	GEOMETRY.box_collider(
		self, "TurretBaseCollision", Vector3(0.0, 1.25, 0.0), Vector3(3.8, 2.5, 3.8)
	)


func _build_sensor_tower() -> void:
	GEOMETRY.cylinder(
		self,
		"SensorTowerFoundation",
		Vector3(0.0, 0.25, 0.0),
		2.9,
		2.9,
		0.5,
		_materials["yellow"],
		Vector3.ZERO,
		20
	)
	GEOMETRY.cylinder(
		self,
		"SensorTowerShaft",
		Vector3(0.0, 7.0, 0.0),
		0.72,
		0.54,
		13.0,
		_materials["pearl"],
		Vector3.ZERO,
		16
	)
	for band_index in range(5):
		var y := 2.3 + float(band_index) * 2.3
		GEOMETRY.cylinder(
			self,
			"SensorTowerBand_%d" % band_index,
			Vector3(0.0, y, 0.0),
			0.9,
			0.9,
			0.12,
			_materials["blue"],
			Vector3.ZERO,
			16
		)
		GEOMETRY.cylinder(
			self,
			"SensorTowerBandLight_%d" % band_index,
			Vector3(0.0, y + 0.1, 0.0),
			0.93,
			0.93,
			0.06,
			_materials["cyan"],
			Vector3.ZERO,
			16
		)
	GEOMETRY.cylinder(
		self,
		"SensorTowerObservationDeck",
		Vector3(0.0, 12.0, 0.0),
		3.5,
		3.5,
		0.52,
		_materials["silver"],
		Vector3.ZERO,
		20
	)
	GEOMETRY.cylinder(
		self,
		"SensorTowerGlassCabin",
		Vector3(0.0, 13.15, 0.0),
		2.6,
		2.4,
		1.9,
		_materials["glass"],
		Vector3.ZERO,
		20
	)
	GEOMETRY.cylinder(
		self,
		"SensorTowerRoof",
		Vector3(0.0, 14.2, 0.0),
		2.9,
		2.9,
		0.34,
		_materials["blue"],
		Vector3.ZERO,
		20
	)
	GEOMETRY.cylinder(
		self,
		"SensorTowerRadar",
		Vector3(0.0, 15.35, 0.0),
		2.1,
		2.1,
		0.12,
		_materials["cyan"],
		Vector3.ZERO,
		24
	)
	GEOMETRY.box(
		self,
		"SensorTowerAntenna",
		Vector3(0.0, 17.0, 0.0),
		Vector3(0.2, 3.0, 0.2),
		_materials["silver"]
	)
	for side in [-1.0, 1.0]:
		GEOMETRY.box(
			self,
			"SensorTowerDishMast",
			Vector3(side * 3.3, 13.2, 0.0),
			Vector3(0.14, 2.0, 0.14),
			_materials["silver"]
		)
		GEOMETRY.cylinder(
			self,
			"SensorTowerDish",
			Vector3(side * 3.3, 14.1, 0.0),
			0.88,
			0.88,
			0.13,
			_materials["turquoise"],
			Vector3(0.0, 0.0, 36.0 * side),
			18
		)
	GEOMETRY.box_collider(
		self, "SensorTowerShaftCollision", Vector3(0.0, 6.8, 0.0), Vector3(1.2, 13.2, 1.2)
	)


func _build_landing_pad() -> void:
	GEOMETRY.box(
		self,
		"LandingPadFoundation",
		Vector3(0.0, 0.3, 0.0),
		Vector3(32.0, 0.6, 24.0),
		_materials["silver"],
		Vector3.ZERO,
		true
	)
	GEOMETRY.box(
		self,
		"LandingPadDeck",
		Vector3(0.0, 0.64, 0.0),
		Vector3(29.0, 0.12, 21.0),
		_materials["blue"]
	)
	for edge in [-1.0, 1.0]:
		GEOMETRY.box(
			self,
			"LandingPadSafetyStripeX",
			Vector3(edge * 13.9, 0.73, 0.0),
			Vector3(0.28, 0.06, 19.0),
			_materials["yellow"]
		)
		GEOMETRY.box(
			self,
			"LandingPadSafetyStripeZ",
			Vector3(0.0, 0.73, edge * 9.9),
			Vector3(27.5, 0.06, 0.28),
			_materials["yellow"]
		)
	for strip_index in range(8):
		var z := -7.0 + float(strip_index) * 2.0
		GEOMETRY.box(
			self,
			"LandingPadPanel_%02d" % strip_index,
			Vector3(0.0, 0.72, z),
			Vector3(23.0, 0.04, 1.72),
			_materials["pearl"] if strip_index % 2 == 0 else _materials["ceramic"]
		)
	GEOMETRY.box(
		self,
		"LandingPadCenterStroke",
		Vector3(0.0, 0.78, 0.0),
		Vector3(1.0, 0.05, 8.0),
		_materials["cyan"]
	)
	GEOMETRY.box(
		self,
		"LandingPadH_Left",
		Vector3(-4.4, 0.8, 0.0),
		Vector3(1.15, 0.08, 7.0),
		_materials["yellow"]
	)
	GEOMETRY.box(
		self,
		"LandingPadH_Right",
		Vector3(4.4, 0.8, 0.0),
		Vector3(1.15, 0.08, 7.0),
		_materials["yellow"]
	)
	GEOMETRY.box(
		self,
		"LandingPadH_Crossbar",
		Vector3(0.0, 0.8, 0.0),
		Vector3(9.8, 0.08, 1.0),
		_materials["yellow"]
	)
	for x in [-13.6, 13.6]:
		for z in [-9.6, 9.6]:
			GEOMETRY.cylinder(
				self,
				"LandingPadBeaconBase",
				Vector3(x, 1.0, z),
				0.42,
				0.42,
				0.55,
				_materials["silver"],
				Vector3.ZERO,
				12
			)
			GEOMETRY.sphere(
				self,
				"LandingPadBeaconLens",
				Vector3(x, 1.38, z),
				Vector3(0.28, 0.32, 0.28),
				_materials["orange"]
			)
	for panel in range(6):
		GEOMETRY.box(
			self,
			"LandingPadEdgeRib_%02d" % panel,
			Vector3(-11.0 + panel * 4.4, 0.82, -10.6),
			Vector3(2.0, 0.12, 0.18),
			_materials["cyan"]
		)
	# Six uploaded FBX floor modules form the playable pad surface. The ramp,
	# safety markings and deck collision remain separate so traversal is stable.
	for tile_x in range(3):
		for tile_z in range(2):
			var key := "floor_alt" if (tile_x + tile_z) % 2 == 0 else "floor"
			ScifiBayBuilder.place(
				self,
				key,
				"SciFiLandingDeck_%d_%d" % [tile_x, tile_z],
				Vector3((float(tile_x) - 1.0) * 8.9, 0.745, (float(tile_z) - 0.5) * 8.9),
				90.0,
				1.65,
				false,
				false
			)

	GEOMETRY.bolts(
		self, "LandingPadDeck", Vector3.ZERO, Vector2(14.0, 10.0), 0.73, _materials["dark_trim"]
	)


func _build_wrecked_transport() -> void:
	GEOMETRY.box(
		self,
		"TransportBrokenHull",
		Vector3(0.0, 1.25, 0.0),
		Vector3(9.4, 2.2, 4.4),
		_materials["ceramic"],
		Vector3(0.0, 0.0, -8.0),
		true
	)
	GEOMETRY.box(
		self,
		"TransportCockpit",
		Vector3(0.0, 2.45, 1.15),
		Vector3(3.4, 1.5, 2.0),
		_materials["glass"],
		Vector3(-8.0, 0.0, 0.0)
	)
	GEOMETRY.box(
		self,
		"TransportNoseArmor",
		Vector3(0.0, 1.65, 3.4),
		Vector3(3.5, 1.1, 2.5),
		_materials["silver"],
		Vector3(0.0, 0.0, 12.0)
	)
	GEOMETRY.box(
		self,
		"TransportWingLeft",
		Vector3(-8.6, 0.82, -0.8),
		Vector3(10.0, 0.52, 3.2),
		_materials["blue"],
		Vector3(0.0, 0.0, 22.0)
	)
	GEOMETRY.box(
		self,
		"TransportWingRightBroken",
		Vector3(7.0, 0.66, -1.2),
		Vector3(7.0, 0.45, 2.6),
		_materials["ceramic"],
		Vector3(12.0, 6.0, -28.0)
	)
	GEOMETRY.box(
		self,
		"TransportBrokenFin",
		Vector3(6.8, 1.0, 2.3),
		Vector3(3.2, 0.3, 1.8),
		_materials["copper"],
		Vector3(0.0, 0.0, 34.0)
	)
	for engine_index in range(2):
		var x := -3.1 + engine_index * 6.2
		GEOMETRY.cylinder(
			self,
			"TransportEngine_%d" % engine_index,
			Vector3(x, 1.1, -2.6),
			1.0,
			0.8,
			2.6,
			_materials["dark_trim"],
			Vector3(90.0, 0.0, 0.0),
			18
		)
		GEOMETRY.cylinder(
			self,
			"TransportEngineGlow_%d" % engine_index,
			Vector3(x, 1.1, -3.94),
			0.58,
			0.58,
			0.18,
			_materials["orange"],
			Vector3(90.0, 0.0, 0.0),
			16
		)
	GEOMETRY.box(
		self,
		"TransportImpactScar",
		Vector3(-2.3, 2.34, 0.2),
		Vector3(1.0, 0.12, 2.7),
		_materials["orange"],
		Vector3(0.0, 0.0, 28.0)
	)
	for debris_index in range(5):
		var x := -7.0 + float(debris_index) * 3.4
		GEOMETRY.box(
			self,
			"TransportDebris_%02d" % debris_index,
			Vector3(x, 0.25, 5.0 + sin(float(debris_index)) * 2.0),
			Vector3(1.4, 0.5, 0.9),
			_materials["silver"],
			Vector3(0.0, float(debris_index) * 21.0, float(debris_index) * 9.0)
		)
	GEOMETRY.sphere(
		self,
		"TransportFireGlow",
		Vector3(-2.0, 0.85, 2.4),
		Vector3(0.7, 1.0, 0.7),
		_materials["orange"]
	)


func _build_alien_drone_wreck() -> void:
	GEOMETRY.sphere(
		self,
		"DroneCentralChassis",
		Vector3(0.0, 1.7, 0.0),
		Vector3(2.2, 1.15, 2.6),
		_materials["dark_trim"],
		Vector3(0.0, 0.0, 18.0)
	)
	GEOMETRY.sphere(
		self, "DroneCoreLens", Vector3(0.0, 1.85, 1.72), Vector3(1.0, 0.7, 0.3), _materials["red"]
	)
	for arm_index in range(4):
		var angle := TAU * float(arm_index) / 4.0
		var start := Vector3(cos(angle) * 1.1, 1.9, sin(angle) * 1.1)
		var finish := Vector3(cos(angle) * 4.2, 0.55 + float(arm_index % 2) * 0.4, sin(angle) * 4.2)
		GEOMETRY.link_cylinder(
			self,
			"DroneBrokenArm_%d" % arm_index,
			start,
			finish,
			0.34,
			_materials["copper"] if arm_index % 2 == 0 else _materials["blue"]
		)
		GEOMETRY.sphere(
			self,
			"DroneJoint_%d" % arm_index,
			finish,
			Vector3(0.78, 0.58, 0.72),
			_materials["silver"]
		)
		GEOMETRY.box(
			self,
			"DroneClaw_%d" % arm_index,
			finish + Vector3(0.0, -0.38, 0.0),
			Vector3(0.42, 0.82, 0.36),
			_materials["dark_trim"],
			Vector3(0.0, arm_index * 38.0, 18.0)
		)
	for plate_index in range(3):
		GEOMETRY.box(
			self,
			"DroneArmorPlate_%d" % plate_index,
			Vector3(-0.7 + plate_index * 0.7, 2.45, 0.0),
			Vector3(1.15, 0.18, 2.0),
			_materials["rock_rose"],
			Vector3(0.0, 0.0, float(plate_index - 1) * 14.0)
		)
	GEOMETRY.box(
		self,
		"DroneSparkingCable",
		Vector3(0.0, 0.55, 2.0),
		Vector3(2.1, 0.08, 0.08),
		_materials["orange"],
		Vector3(0.0, 0.0, 16.0)
	)
