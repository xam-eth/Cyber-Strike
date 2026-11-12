## What the HUD reflects, and nothing else.
##
## Every field here is something the *game* told the HUD: the run's numbers, the
## encounter phase, the weapon in hand. Nothing in here knows about a widget, a
## font, a colour or a layout — that is the facade's job
## (touch_controls.gd), and keeping the two apart is what lets the numbers be
## tested without a screen and the screen be restyled without touching the
## numbers.
##
## It is also the seam the module boundary checker can police: `hud_state` is
## data the HUD owns and renders; it is not a place for gameplay rules, and
## nothing in `content/` may reach into it.
class_name HudState
extends RefCounted

## Score banked in the current run.
var score: int = 0
## Battle Points earned in this run, as opposed to `wallet_bp`, which is what
## the profile can actually spend.
var bp: int = 0
var wallet_bp: int = 0
## How many weapons the player owns. One means the SWAP face becomes the
## armory's entry point instead of a switch.
var available_weapons: int = 1
var kos: int = 0
var run_time: String = "00:00"
var shots: int = 0
## "explore" | "preparing" | "defense" | "results". The HUD's context
## visibility is derived from this, never set directly.
var play_phase: String = "explore"
## Countdown shown while the phase is "preparing"; 0 everywhere else.
var preparation_seconds: int = 0
## Results is also the mission-complete choice surface. In "extraction" mode
## its two actions mean Extract and Continue, never Retry or abandon the run.
var results_mode: String = "results"
var results_extracted: bool = false
var results_arc_blueprint: bool = false
## Main's current Recovery presentation. Empty action means no field interaction
## is available; these values never authorize a spawn, secure, or reward.
var recovery_active: bool = false
var recovery_title: String = ""
var recovery_detail: String = ""
var recovery_state: String = ""
var recovery_action: String = ""
## Live Recovery guards supplied by Main/WaveDirector. This only gates the
## generic Defense presentation; it never authorizes guard completion or Secure.
var recovery_guard_count: int = 0
## Escalating guidance stage ("area" | "local" | "interact" | "combat" | "stuck" | "complete").
var recovery_guidance: String = ""
## Display name of the equipped weapon, kept so a relayout can re-render the
## weapon chip without asking the weapon controller again.
var weapon_display_name: String = ""
## Persistent rank of that equipped weapon; presentation only, never an upgrade
## authority. ProgressionService/WeaponController own the value and its effects.
var weapon_tier: int = 1
## Run-scoped temporary upgrade readout (owned by RunUpgradeManager, never saved).
var upgrade_pending: bool = false
var upgrade_active_tags: String = ""
var upgrade_charge: int = 0
var upgrade_required: int = 2
var upgrade_maxed: bool = false
## Live Guardian encounter readout supplied by Main/WaveDirector (presentation only).
var guardian_active: bool = false
var guardian_hp: float = 0.0
var guardian_max_hp: float = 0.0
var guardian_phase: String = "fortified"
## Fielded operative telemetry supplied by Main/ProgressionService (presentation only).
var operative_id: StringName = &"sable"
var operative_skill_id: StringName = &"emp_pulse"
var operative_armor_pct: int = 0
var field_kit_tags: String = ""
## World-space waypoint supplied by Main for the top bearing compass (presentation only).
var objective_has_target: bool = false
var objective_world_pos: Vector3 = Vector3.ZERO
## Live minimap telemetry supplied by Main every frame (presentation only).
## `map_points` entries are plain dictionaries — {x, z, kind, secured, target}
## — with "kind" one of "cache" | "optional" | "objective"; `map_route` is the
## authored guidance path in world XZ. Nothing here authorizes anything.
var player_world_pos: Vector3 = Vector3.ZERO
var player_yaw: float = 0.0
var map_center: Vector2 = Vector2.ZERO
var map_radius: float = 60.0
var map_points: Array = []
var map_route: PackedVector2Array = PackedVector2Array()
## Live screen-space reticle position driven by the cursor on desktop (center on touch).
var reticle_pos: Vector2 = Vector2(-1.0, -1.0)
var cursor_aim_active: bool = false
## Live Overshield, Weapon Overcharge, and Field Resource Telemetry (presentation only).
var overshield: float = 0.0
var max_overshield: float = 45.0
var overcharge_seconds: float = 0.0
var cryo_alloy: int = 0
var caches_secured: int = 0
var caches_total: int = 4
