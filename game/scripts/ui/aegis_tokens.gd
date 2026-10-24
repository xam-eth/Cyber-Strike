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

# --- Art direction --------------------------------------------------------- #
# The same colours under the names docs/ART_DIRECTION.md gives the concept art,
# so a texture audit and a button style are reading one palette rather than two
# that drift apart. These are aliases of the tokens above, never new colours:
# art and UI are allowed to disagree about names, never about values.
const ART_NAVY := VOID
const ART_NAVY_2 := PANEL
const ART_GUNMETAL := LINE
const ART_GRAPHITE := LINE_HI
const ART_CYAN := INFO
const ART_AMBER := ACCENT
const ART_SILVER := INK
const ART_STEEL := INK_2
const ART_GREEN := OK
const ART_RED := DANGER
# Every family a shipped texture is allowed to land in. `steel` covers the
# desaturated gunmetal and silver; `shadow` covers the near-black falloff the
# art direction asks for at the edges of every composition.
const ART_FAMILIES := {
	"navy": ART_NAVY,
	"cyan": ART_CYAN,
	"green": ART_GREEN,
	"amber": ART_AMBER,
	"red": ART_RED,
	"steel": ART_STEEL,
	"silver": ART_SILVER,
	"shadow": ART_NAVY,
}

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
# Rajdhani carries the interface. It was chosen over Barlow because it is the
# face the reference lobbies actually use: squarish, condensed, built for
# uppercase rows and numerals, and it keeps a 15 px label legible where Barlow
# at the same size read as body copy. Chakra Petch stays on headings and labels
# so the two agree on a squared silhouette instead of mixing a geometric face
# with a humanist one.
const FONT_UI := "res://assets/ui/fonts/Rajdhani-Regular.ttf"
const FONT_UI_M := "res://assets/ui/fonts/Rajdhani-Medium.ttf"
const FONT_UI_SB := "res://assets/ui/fonts/Rajdhani-SemiBold.ttf"
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
#
# Sizes are measured, not taste. The first shipped scale was authored for a
# 1280x720 canvas at 11-15 px for everything below a heading, and a screenshot
# review of the whole journey (docs/DECISIONS.md 2) called it
# what it was: body copy that disappears next to the world art. So the scale
# was set against three references measured at 16:9 and re-based on 720 px of
# height, which is this project's canvas:
#
#   * Call of Duty Mobile lobby (1568x882): body 22 px, panel title 30-40 px,
#     primary button 72 px tall, mode cards 18 % of the screen width;
#   * Apex Legends lobby (1568x879): body 26 px, tab 30 px, READY 70 px tall;
#   * Free Fire lobby (1200x675): bottom tabs 15 px, STORE/START 34 px, and the
#     one control a player must hit (START) is ~13 % of the screen height.
#
# Body copy therefore lands at 18 px (was 14), labels at 15 (was 11) and the
# big titles at 38-52 (was 28-40). Nothing here is "one notch up": at 720 px a
# 15 px label is half the size of the smallest body text in the references.
const TYPE := {
	"display_xl": [FAMILY_DISPLAY, 56, 2.0, true],
	"display_l": [FAMILY_DISPLAY, 40, 2.0, true],
	"display_m": [FAMILY_DISPLAY, 32, 2.0, true],
	"heading": [FAMILY_DISPLAY, 26, 1.0, true],
	"heading_s": [FAMILY_DISPLAY_M, 20, 1.0, true],
	"title": [FAMILY_UI_SB, 24, 1.0, false],
	"body": [FAMILY_UI, 20, 0.0, false],
	"body_s": [FAMILY_UI, 17, 0.0, false],
	"label": [FAMILY_UI_M, 16, 12.0, true],
	"label_s": [FAMILY_UI_M, 14, 10.0, true],
	"caption": [FAMILY_UI, 16, 2.0, false],
	"mono_xl": [FAMILY_MONO, 46, 0.0, false],
	"mono_l": [FAMILY_MONO, 29, 0.0, false],
	"mono_m": [FAMILY_MONO, 18, 0.0, false],
	"mono_s": [FAMILY_MONO, 15, 0.0, false],
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

## Baseline for supporting HUD text. Raised with the type scale above: at
## 16 px a label is still smaller than any body text in the measured
## references, but it is legible on a phone held at arm's length, which 13 was
## not (docs/DECISIONS.md 2).
const MIN_PHYSICAL_FONT_PX := 16.0
## Comfortable touch target. 64 is the Android/Material floor (48 dp at 1.33x)
## and the height Free Fire's START and COD Mobile's Store button land on.
const MIN_TOUCH_PX := 64.0
const TOUCH_GAP_PX := 14.0

# --- Safe area -------------------------------------------------------------- #
# Physical pixels kept clear of the display edges for the bottom-docked combat
# controls. The Android gesture bar is only ~16 dp tall, but its swipe zone
# reaches further and a swipe started on a button never reaches the game, so
# the bottom reserve is deliberately larger than the side reserve. These are
# floors: a device that reports a bigger safe area always wins.
const SAFE_BOTTOM_PX := 28.0
const SAFE_SIDE_PX := 8.0
# Anything the OS reports below this is noise from a windowed or embedded
# canvas rather than a real system inset.
const SAFE_INSET_NOISE_PX := 4.0


static func panel(alpha: float = PANEL_ALPHA) -> Color:
	return Color(PANEL, alpha)


static func accent_ink() -> Color:
	return ACCENT_INK
