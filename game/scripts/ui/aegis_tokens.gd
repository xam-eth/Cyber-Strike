## AEGIS design tokens: the single source of truth for colour, type, spacing
## and shape in the HUD and menus.
##
## The values mirror docs/UI_UX_REDESIGN_SPEC.md §4. Nothing in the UI should
## hard-code a colour or font path again: components read `AegisTokens` and
## `AegisTheme`, which also keeps the palette auditable in one place.
class_name AegisTokens
extends RefCounted

# --- Colour ---------------------------------------------------------------- #
# Never use pure black or pure white: they clip on OLED and read as "default
# engine UI" next to the hand-painted world.
const VOID := Color("05080c")
const PANEL := Color("0b131b")
const PANEL_2 := Color("111c26")
const PANEL_3 := Color("16232e")
const LINE := Color("27384a")
const LINE_HI := Color("4e6a7e")
const INK := Color("edf5fb")
const INK_2 := Color("a9bccb")
const INK_3 := Color("7c94a6")
const ACCENT := Color("ffb020")
const ACCENT_INK := Color("171005")
const OK := Color("37e08c")
const INFO := Color("54c8ff")
const DANGER := Color("ff5a5a")
const ABILITY := Color("b79cff")

# Common translucencies. The world stays visible through panels but the text
# keeps its measured contrast (see the spec's WCAG table).
const PANEL_ALPHA := 0.92
const PANEL_ALPHA_SOFT := 0.86
const SCRIM_ALPHA := 0.68
const DISABLED_ALPHA := 0.55

# --- Type ------------------------------------------------------------------ #
# Fonts are shipped in game/assets/ui/fonts (SIL Open Font License, see the
# OFL-*.txt next to them). A missing font falls back to the engine font so the
# HUD still boots in a stripped export.
const FONT_DISPLAY := "res://assets/ui/fonts/ChakraPetch-SemiBold.ttf"
const FONT_DISPLAY_M := "res://assets/ui/fonts/ChakraPetch-Medium.ttf"
const FONT_UI := "res://assets/ui/fonts/Barlow-Regular.ttf"
const FONT_UI_M := "res://assets/ui/fonts/Barlow-Medium.ttf"
const FONT_UI_SB := "res://assets/ui/fonts/Barlow-SemiBold.ttf"
const FONT_MONO := "res://assets/ui/fonts/JetBrainsMono-Medium.ttf"
const FONT_MONO_B := "res://assets/ui/fonts/JetBrainsMono-Bold.ttf"

# Family keys accepted by AegisTheme.font().
const FAMILY_DISPLAY := "display"
const FAMILY_DISPLAY_M := "display_m"
const FAMILY_UI := "ui"
const FAMILY_UI_M := "ui_m"
const FAMILY_UI_SB := "ui_sb"
const FAMILY_MONO := "mono"
const FAMILY_MONO_B := "mono_b"

# role -> [family, size, tracking percent, uppercase]
const TYPE := {
	"display_xl": [FAMILY_DISPLAY, 40, 2.0, true],
	"display_l": [FAMILY_DISPLAY, 28, 2.0, true],
	"heading": [FAMILY_DISPLAY, 18, 1.0, true],
	"heading_s": [FAMILY_DISPLAY_M, 14, 1.0, true],
	"title": [FAMILY_UI_SB, 15, 1.0, false],
	"body": [FAMILY_UI, 14, 0.0, false],
	"body_s": [FAMILY_UI, 12, 0.0, false],
	"label": [FAMILY_UI_M, 11, 12.0, true],
	"label_s": [FAMILY_UI_M, 10, 10.0, true],
	"caption": [FAMILY_UI, 11, 2.0, false],
	"mono_xl": [FAMILY_MONO, 34, 0.0, false],
	"mono_l": [FAMILY_MONO, 20, 0.0, false],
	"mono_m": [FAMILY_MONO, 13, 0.0, false],
	"mono_s": [FAMILY_MONO, 11, 0.0, false],
}

# --- Spacing, shape, motion ------------------------------------------------ #
const SPACE_1 := 2.0
const SPACE_2 := 4.0
const SPACE_3 := 8.0
const SPACE_4 := 12.0
const SPACE_5 := 16.0
const SPACE_6 := 24.0
const SPACE_7 := 32.0
const SPACE_8 := 48.0

const RADIUS := 2.0
const BRACKET_LENGTH := 10.0
const BRACKET_INSET := 3.0
const BRACKET_WIDTH := 1.0
const ACCENT_EDGE := 2.0
const HAIRLINE := 1.0
const FOCUS_WIDTH := 2.0
const FOCUS_OFFSET := 2.0

const MOTION_FAST := 0.12
const MOTION_PRESS := 0.09
const MOTION_RESULTS := 0.24
const HIT_MARKER := 0.16
const DAMAGE_VIGNETTE := 0.28

const MIN_PHYSICAL_FONT_PX := 11.0
const MIN_TOUCH_PX := 44.0
const TOUCH_GAP_PX := 12.0


static func panel(alpha: float = PANEL_ALPHA) -> Color:
	return Color(PANEL, alpha)


static func accent_ink() -> Color:
	return ACCENT_INK
