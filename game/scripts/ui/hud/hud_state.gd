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
## Display name of the equipped weapon, kept so a relayout can re-render the
## weapon chip without asking the weapon controller again.
var weapon_display_name: String = ""
