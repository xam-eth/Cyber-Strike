## Typography, icon and stylebox factory for the AEGIS visual language.
##
## Everything here is static and cached: the HUD builds dozens of labels and
## re-themes buttons on every state change, so allocating a new `FontVariation`
## per call would waste memory and, worse, make the same role render at slightly
## different spacing. `style_label` is the one entry point for text.
class_name AegisTheme
extends RefCounted

const ICON_ROOT := "res://assets/ui/icons"

static var _fonts: Dictionary = {}
static var _tracked: Dictionary = {}
static var _icons: Dictionary = {}


static func font(family: String) -> Font:
	if _fonts.has(family):
		return _fonts[family]
	var path := ""
	match family:
		AegisTokens.FAMILY_DISPLAY:
			path = AegisTokens.FONT_DISPLAY
		AegisTokens.FAMILY_DISPLAY_M:
			path = AegisTokens.FONT_DISPLAY_M
		AegisTokens.FAMILY_UI:
			path = AegisTokens.FONT_UI
		AegisTokens.FAMILY_UI_M:
			path = AegisTokens.FONT_UI_M
		AegisTokens.FAMILY_UI_SB:
			path = AegisTokens.FONT_UI_SB
		AegisTokens.FAMILY_MONO:
			path = AegisTokens.FONT_MONO
		AegisTokens.FAMILY_MONO_B:
			path = AegisTokens.FONT_MONO_B
	var resolved: Font = null
	if not path.is_empty() and ResourceLoader.exists(path):
		resolved = load(path) as Font
	if resolved == null:
		resolved = ThemeDB.fallback_font
	_fonts[family] = resolved
	return resolved


## Font with the role's tracking baked in. Tracking is expressed as a percent of
## the font size (the spec asks for +12% on uppercase labels), because a fixed
## pixel value collapses at the 11 px floor.
static func tracked_font(family: String, size: int, tracking_percent: float) -> Font:
	if is_zero_approx(tracking_percent):
		return font(family)
	var key := "%s:%d:%.1f" % [family, size, tracking_percent]
	if _tracked.has(key):
		return _tracked[key]
	var variation := FontVariation.new()
	variation.base_font = font(family)
	variation.spacing_glyph = roundi(float(size) * tracking_percent / 100.0)
	_tracked[key] = variation
	return variation


static func type_size(role: String) -> int:
	var spec: Array = AegisTokens.TYPE.get(role, AegisTokens.TYPE["body"])
	return int(spec[1])


## Applies a type role to a Label. `scale` lets callers shrink a role on a phone
## while the caller keeps ownership of the physical-pixel floor.
static func style_label(
	label: Label,
	role: String,
	color: Color = AegisTokens.INK,
	scale: float = 1.0,
	shadow: bool = false
) -> void:
	if not is_instance_valid(label):
		return
	var spec: Array = AegisTokens.TYPE.get(role, AegisTokens.TYPE["body"])
	var size := maxi(roundi(float(spec[1]) * scale), 1)
	label.add_theme_font_override("font", tracked_font(spec[0], size, spec[2]))
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if shadow:
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.02, 0.05, 0.9))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		label.add_theme_constant_override("shadow_outline_size", 3)


## Re-applies only the size of an existing role, preserving family, tracking and
## colour. Used when the physical-pixel floor has to grow a label.
static func resize_label(label: Label, role: String, size: int) -> void:
	if not is_instance_valid(label):
		return
	var spec: Array = AegisTokens.TYPE.get(role, AegisTokens.TYPE["body"])
	label.add_theme_font_override("font", tracked_font(spec[0], size, spec[2]))
	label.add_theme_font_size_override("font_size", size)


## Re-applies a type role to a Button's text. Buttons use the same font cache as
## labels so a keycap and a caption never disagree about the family.
static func resize_button_font(button: Button, role: String, size: int) -> void:
	if not is_instance_valid(button):
		return
	var spec: Array = AegisTokens.TYPE.get(role, AegisTokens.TYPE["body"])
	button.add_theme_font_override("font", tracked_font(spec[0], size, spec[2]))
	button.add_theme_font_size_override("font_size", size)


static func icon(icon_name: String, filled: bool = false) -> Texture2D:
	var folder := "fill" if filled else "regular"
	var key := "%s/%s" % [folder, icon_name]
	if _icons.has(key):
		return _icons[key]
	var path := "%s/%s/%s.svg" % [ICON_ROOT, folder, icon_name]
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	_icons[key] = texture
	return texture


# --- Styleboxes ------------------------------------------------------------ #


static func panel_style(
	fill: Color = Color(AegisTokens.PANEL, AegisTokens.PANEL_ALPHA),
	border: Color = AegisTokens.LINE,
	border_width: int = 1,
	radius: float = AegisTokens.RADIUS,
	margin: float = 12.0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(roundi(radius))
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin * 0.66
	style.content_margin_bottom = margin * 0.66
	style.anti_aliasing = true
	return style


static func flat_style(color: Color, radius: float = 1.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(roundi(radius))
	style.content_margin_left = 0.0
	style.content_margin_right = 0.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	style.anti_aliasing = true
	return style


static func button_style(
	fill: Color,
	border: Color,
	border_width: int = 1,
	radius: float = AegisTokens.RADIUS,
	pad_h: float = 12.0,
	pad_v: float = 8.0
) -> StyleBoxFlat:
	var style := panel_style(fill, border, border_width, radius, pad_h)
	style.content_margin_top = pad_v
	style.content_margin_bottom = pad_v
	return style


## Focus ring: 2 px amber border offset 2 px outside the button, visible for
## keyboard and gamepad navigation (spec §6). It is a stylebox rather than a
## draw pass so `Button` shows it around the correct variant automatically.
static func focus_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = AegisTokens.ACCENT
	style.set_border_width_all(2)
	style.set_corner_radius_all(roundi(AegisTokens.RADIUS) + 2)
	style.set_expand_margin_all(AegisTokens.FOCUS_OFFSET)
	style.anti_aliasing = true
	return style


## Theme colours apply to the glyph too; without this the SVG's own black fill
## disappears against the dark panel.
static func tint_icon(button: Button, color: Color) -> void:
	for state in ["icon_normal_color", "icon_hover_color", "icon_pressed_color"]:
		button.add_theme_color_override(state, color)


static func set_button_variant(button: Button, variant: String) -> void:
	if not is_instance_valid(button):
		return
	var fill: Color = Color(AegisTokens.PANEL_2, 0.94)
	var border: Color = AegisTokens.LINE
	var font_color: Color = AegisTokens.INK
	var font_size := 13
	var pad_h := 12.0
	var pad_v := 8.0
	var radius: float = AegisTokens.RADIUS
	match variant:
		"primary":
			fill = AegisTokens.ACCENT
			border = AegisTokens.ACCENT
			font_color = AegisTokens.ACCENT_INK
		"ghost":
			fill = Color(0, 0, 0, 0)
			border = Color(0, 0, 0, 0)
			font_color = AegisTokens.INK_2
		"danger":
			fill = Color(AegisTokens.DANGER, 0.10)
			border = AegisTokens.DANGER
			font_color = AegisTokens.DANGER
		"icon":
			fill = Color(AegisTokens.PANEL_2, 0.92)
			border = AegisTokens.LINE
			pad_h = 4.0
			pad_v = 4.0
		"ability":
			fill = Color(AegisTokens.PANEL_2, 0.94)
			border = Color(AegisTokens.ABILITY, 0.55)
			font_color = AegisTokens.INK
		"round":
			fill = Color(AegisTokens.PANEL, 0.82)
			border = Color(AegisTokens.LINE_HI, 0.9)
			radius = 999.0
			pad_h = 4.0
			pad_v = 4.0
		"fire":
			fill = Color(AegisTokens.ACCENT, 0.94)
			border = Color(AegisTokens.ACCENT, 1.0)
			font_color = AegisTokens.ACCENT_INK
			radius = 999.0
			pad_h = 4.0
			pad_v = 4.0
		_:
			pass
	button.add_theme_stylebox_override(
		"normal", button_style(fill, border, 1, radius, pad_h, pad_v)
	)
	button.add_theme_stylebox_override(
		"hover", button_style(fill.lightened(0.08), border.lightened(0.15), 1, radius, pad_h, pad_v)
	)
	button.add_theme_stylebox_override(
		"pressed",
		button_style(fill.darkened(0.10), border.lightened(0.05), 2, radius, pad_h, pad_v)
	)
	button.add_theme_stylebox_override(
		"disabled",
		button_style(
			Color(AegisTokens.PANEL, 0.62), Color(AegisTokens.LINE, 0.55), 1, radius, pad_h, pad_v
		)
	)
	button.add_theme_stylebox_override("focus", focus_style())
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	tint_icon(button, font_color)
	button.add_theme_color_override(
		"font_disabled_color", Color(AegisTokens.INK_3, AegisTokens.DISABLED_ALPHA)
	)
	button.add_theme_font_override("font", tracked_font(AegisTokens.FAMILY_UI_SB, font_size, 6.0))
	button.add_theme_font_size_override("font_size", font_size)
