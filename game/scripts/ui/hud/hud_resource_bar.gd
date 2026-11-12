class_name HudResourceBar
extends Control

## AAA Sci-Fi Live Resource Telemetry Strip, Overshield/Overcharge Bridge, &
## Acquisition Feed.
##
## Displays real-time player resources during gameplay:
##   1) Blueprints (wallet BP + in-run earned +BP delta)
##   2) Cryo-Alloy salvage progress (x/3 toward Field Tactical Evolution)
##   3) Sector Tech Caches secured (secured / total)
##   4) Sliding live loot acquisition feed when pickups/crates are collected.

const FEED_DURATION := 3.1
const MAX_FEED_ITEMS := 3

var wallet_bp: int = 0
var run_bp: int = 0
var cryo_alloy: int = 0
var caches_secured: int = 0
var caches_total: int = 4
var compact_mode: bool = false
var scale_unit: float = 1.0

var _feed: Array[Dictionary] = []
var _pulse_bp: float = 0.0
var _pulse_alloy: float = 0.0
var _pulse_cache: float = 0.0


static func install_top_bar(hud) -> void:
	var bar := HudResourceBar.new()
	bar.name = "ResourceBar"
	hud._resource_bar = bar
	hud._top_bar.add_child(bar)


static func build_vitals_card(hud) -> void:
	var card := AegisPanel.new()
	card.name = "HealthCard"
	card.cut_top_right = 12.0
	card.cut_bottom_left = 7.0
	card.accent_side = "left"
	card.accent_color = AegisTokens.OK
	card.accent_width = 3.0
	card.tactical_header = true
	card.show_brackets = true
	card.clip_contents = true
	hud._health_card = card
	hud._top_bar.add_child(card)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	card.add_child(content)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	content.add_child(row)
	var vitals_icon := TextureRect.new()
	vitals_icon.name = "VitalsIcon"
	vitals_icon.texture = AegisTheme.hud_icon("hud-vitals")
	vitals_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vitals_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vitals_icon.custom_minimum_size = Vector2(18.0, 14.0)
	vitals_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vitals_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitals_icon.modulate = Color(AegisTokens.OK.r, AegisTokens.OK.g, AegisTokens.OK.b, 0.95)
	row.add_child(vitals_icon)
	hud._health_heading = hud._label_key("hud.vitals", "label", AegisTokens.OK)
	row.add_child(hud._health_heading)
	hud._health_tier_badge = hud._label("T1", "mono_s", AegisTokens.INFO)
	hud._health_tier_badge.name = "OperativeTierBadge"
	row.add_child(hud._health_tier_badge)
	hud._overshield_label = hud._label("", "mono_s", AegisTokens.INFO)
	hud._overshield_label.name = "OvershieldBadge"
	hud._overshield_label.visible = false
	row.add_child(hud._overshield_label)
	hud._health_value_label = hud._label("100 / 100", "mono_m", AegisTokens.INK)
	hud._health_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud._health_value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hud._health_value_label)

	var shd := SegmentedBar.new()
	shd.name = "OvershieldBar"
	shd.min_value = 0.0
	shd.max_value = 45.0
	shd.value = 0.0
	shd.segments = 5
	shd.custom_minimum_size = Vector2(0.0, 4.0)
	shd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shd.add_theme_stylebox_override(
		"background", AegisTheme.flat_style(Color(AegisTokens.PANEL_3, 0.72))
	)
	shd.add_theme_stylebox_override("fill", AegisTheme.flat_style(AegisTokens.INFO))
	hud._overshield_bar = shd
	content.add_child(shd)

	var hp := SegmentedBar.new()
	hp.name = "HealthBar"
	hp.min_value = 0.0
	hp.max_value = 100.0
	hp.value = 100.0
	hp.segments = 8
	hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp.add_theme_stylebox_override("background", AegisTheme.flat_style(AegisTokens.PANEL_3))
	hp.add_theme_stylebox_override("fill", AegisTheme.flat_style(AegisTokens.OK))
	hud._health_bar = hp
	content.add_child(hp)


static func sync_overshield(hud, current: float, maximum: float) -> void:
	hud._state.overshield = maxf(current, 0.0)
	hud._state.max_overshield = maxf(maximum, 1.0)
	if is_instance_valid(hud._overshield_bar):
		hud._overshield_bar.max_value = hud._state.max_overshield
		hud._overshield_bar.value = clampf(hud._state.overshield, 0.0, hud._state.max_overshield)
	if is_instance_valid(hud._overshield_label):
		var shd_int := roundi(hud._state.overshield)
		hud._overshield_label.visible = shd_int > 0
		hud._overshield_label.text = "+%d SHD" % shd_int


static func sync_overcharge(hud, seconds: float) -> void:
	hud._state.overcharge_seconds = maxf(seconds, 0.0)
	if is_instance_valid(hud._touch_ammo_chip):
		hud._touch_ammo_chip.set_overcharge(hud._state.overcharge_seconds)
	if is_instance_valid(hud._reticle_layer):
		hud._reticle_layer.queue_redraw()


static func sync_telemetry(
	hud,
	p_wallet_bp: int,
	p_run_bp: int,
	p_cryo_alloy: int,
	p_caches_secured: int,
	p_caches_total: int
) -> void:
	hud._state.wallet_bp = p_wallet_bp
	hud._state.bp = p_run_bp
	hud._state.cryo_alloy = p_cryo_alloy
	hud._state.caches_secured = p_caches_secured
	hud._state.caches_total = p_caches_total
	if is_instance_valid(hud._resource_bar):
		hud._resource_bar.set_telemetry(
			p_wallet_bp, p_run_bp, p_cryo_alloy, p_caches_secured, p_caches_total
		)


static func push_toast(hud, text: String, accent: Color, tag: String = "+GET") -> void:
	if is_instance_valid(hud._resource_bar):
		hud._resource_bar.push_acquisition(text, accent, tag)


static func clear_toast_feed(hud) -> void:
	if is_instance_valid(hud._resource_bar):
		hud._resource_bar.clear_feed()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func set_telemetry(
	p_wallet_bp: int, p_run_bp: int, p_cryo_alloy: int, p_caches_secured: int, p_caches_total: int
) -> void:
	var bp_changed := (p_wallet_bp + p_run_bp) > (wallet_bp + run_bp)
	var alloy_changed := p_cryo_alloy > cryo_alloy
	var cache_changed := p_caches_secured > caches_secured
	if (
		wallet_bp == p_wallet_bp
		and run_bp == p_run_bp
		and cryo_alloy == p_cryo_alloy
		and caches_secured == p_caches_secured
		and caches_total == p_caches_total
	):
		return
	wallet_bp = maxi(p_wallet_bp, 0)
	run_bp = maxi(p_run_bp, 0)
	cryo_alloy = maxi(p_cryo_alloy, 0)
	caches_secured = maxi(p_caches_secured, 0)
	caches_total = maxi(p_caches_total, 1)
	if bp_changed:
		_pulse_bp = 0.45
	if alloy_changed:
		_pulse_alloy = 0.45
	if cache_changed:
		_pulse_cache = 0.55
	if bp_changed or alloy_changed or cache_changed:
		set_process(true)
	queue_redraw()


func push_acquisition(text: String, accent: Color, tag: String = "+GET") -> void:
	if text.is_empty():
		return
	(
		_feed
		. push_front(
			{
				"text": text,
				"tag": tag,
				"color": accent,
				"remaining": FEED_DURATION,
			}
		)
	)
	while _feed.size() > MAX_FEED_ITEMS:
		_feed.pop_back()
	set_process(true)
	queue_redraw()


func clear_feed() -> void:
	_feed.clear()
	_pulse_bp = 0.0
	_pulse_alloy = 0.0
	_pulse_cache = 0.0
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	var active := false
	if _pulse_bp > 0.0:
		_pulse_bp = maxf(_pulse_bp - delta, 0.0)
		active = active or _pulse_bp > 0.0
	if _pulse_alloy > 0.0:
		_pulse_alloy = maxf(_pulse_alloy - delta, 0.0)
		active = active or _pulse_alloy > 0.0
	if _pulse_cache > 0.0:
		_pulse_cache = maxf(_pulse_cache - delta, 0.0)
		active = active or _pulse_cache > 0.0
	for idx in range(_feed.size() - 1, -1, -1):
		var item: Dictionary = _feed[idx]
		var rem := float(item["remaining"]) - delta
		if rem <= 0.0:
			_feed.remove_at(idx)
		else:
			item["remaining"] = rem
			active = true
	queue_redraw()
	if not active and _feed.is_empty():
		set_process(false)


func _draw() -> void:
	if size.x < 40.0 or size.y < 18.0:
		return
	var s := maxf(scale_unit, 0.72)
	var bar_h := minf((28.0 if compact_mode else 34.0) * s, size.y)
	var bar_rect := Rect2(0.0, 0.0, size.x, bar_h)
	_draw_chamfer_plate(bar_rect, 7.0 * s, Color(AegisTokens.VOID, 0.80), AegisTokens.INFO)

	var mono: Font = AegisTheme.font("mono")
	var ui_font: Font = AegisTheme.font("label")
	if mono == null:
		return
	var val_px := maxi(roundi((10.5 if compact_mode else 12.0) * s), 9)
	var lbl_px := maxi(roundi((8.0 if compact_mode else 9.0) * s), 8)

	var cell_w := bar_rect.size.x / 3.0
	var total_bp := wallet_bp + run_bp
	var bp_txt := "%d" % total_bp
	if run_bp > 0 and not compact_mode:
		bp_txt = "%d (+%d)" % [total_bp, run_bp]
	elif run_bp > 0:
		bp_txt = "%d+%d" % [wallet_bp, run_bp]

	var alloy_cycle := cryo_alloy % 3
	if cryo_alloy > 0 and alloy_cycle == 0:
		alloy_cycle = 3
	var alloy_txt := (
		"%d/3" % alloy_cycle if compact_mode else "%d · %d/3" % [cryo_alloy, alloy_cycle]
	)
	var cache_txt := "%d/%d" % [caches_secured, caches_total]

	_draw_resource_cell(
		Rect2(0.0, 0.0, cell_w, bar_h),
		"BP",
		bp_txt,
		AegisTokens.ACCENT,
		_pulse_bp,
		0,
		ui_font,
		mono,
		lbl_px,
		val_px
	)
	draw_line(
		Vector2(cell_w, 5.0 * s),
		Vector2(cell_w, bar_h - 5.0 * s),
		Color(AegisTokens.LINE_HI, 0.45),
		1.0
	)
	_draw_resource_cell(
		Rect2(cell_w, 0.0, cell_w, bar_h),
		"ALLOY",
		alloy_txt,
		AegisTokens.INFO,
		_pulse_alloy,
		1,
		ui_font,
		mono,
		lbl_px,
		val_px
	)
	draw_line(
		Vector2(cell_w * 2.0, 5.0 * s),
		Vector2(cell_w * 2.0, bar_h - 5.0 * s),
		Color(AegisTokens.LINE_HI, 0.45),
		1.0
	)
	_draw_resource_cell(
		Rect2(cell_w * 2.0, 0.0, cell_w, bar_h),
		"CACHE",
		cache_txt,
		AegisTokens.OK,
		_pulse_cache,
		2,
		ui_font,
		mono,
		lbl_px,
		val_px
	)

	if compact_mode or _feed.is_empty():
		return

	var feed_y := bar_h + 6.0 * s
	var pill_h := 22.0 * s
	for idx in range(_feed.size()):
		if feed_y + pill_h > size.y + 2.0:
			break
		var entry: Dictionary = _feed[idx]
		var rem := float(entry["remaining"])
		var alpha := clampf(minf(rem / 0.45, 1.0), 0.0, 1.0)
		var accent: Color = entry["color"]
		var pill_rect := Rect2(12.0 * s, feed_y, size.x - 12.0 * s, pill_h)
		_draw_chamfer_plate(
			pill_rect,
			5.0 * s,
			Color(AegisTokens.PANEL_2, 0.84 * alpha),
			Color(accent, 0.92 * alpha)
		)
		draw_rect(
			Rect2(pill_rect.position.x, pill_rect.position.y + 2.0 * s, 3.0 * s, pill_h - 4.0 * s),
			Color(accent, alpha)
		)
		draw_string(
			mono,
			Vector2(pill_rect.position.x + 9.0 * s, pill_rect.position.y + pill_h * 0.70),
			String(entry["text"]),
			HORIZONTAL_ALIGNMENT_LEFT,
			pill_rect.size.x - 14.0 * s,
			maxi(roundi(10.0 * s), 9),
			Color(AegisTokens.INK, alpha)
		)
		feed_y += pill_h + 4.0 * s


func _draw_resource_cell(
	rect: Rect2,
	title: String,
	value: String,
	accent: Color,
	pulse: float,
	icon_kind: int,
	ui_font: Font,
	mono: Font,
	lbl_px: int,
	val_px: int
) -> void:
	var s := maxf(scale_unit, 0.72)
	if pulse > 0.0:
		draw_rect(rect.grow(-2.0 * s), Color(accent, 0.22 * (pulse / 0.55)))
	var ic := Vector2(rect.position.x + 11.0 * s, rect.position.y + rect.size.y * 0.5)
	var r := 4.8 * s
	if icon_kind == 0:
		draw_colored_polygon(
			PackedVector2Array(
				[
					ic + Vector2(0.0, -r * 1.15),
					ic + Vector2(r, 0.0),
					ic + Vector2(0.0, r * 1.15),
					ic + Vector2(-r, 0.0),
				]
			),
			accent
		)
	elif icon_kind == 1:
		var hex := PackedVector2Array()
		for i in range(6):
			var a := TAU * float(i) / 6.0 - PI * 0.5
			hex.append(ic + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(hex, accent)
	else:
		draw_rect(
			Rect2(ic - Vector2(r * 0.85, r * 0.85), Vector2.ONE * r * 1.7), accent, false, 1.5
		)
		draw_circle(ic, r * 0.38, accent)

	var text_x := rect.position.x + 19.5 * s
	var max_w := maxf(rect.size.x - 22.0 * s, 16.0)
	if ui_font != null and not compact_mode:
		draw_string(
			ui_font,
			Vector2(text_x, rect.position.y + 11.5 * s),
			title,
			HORIZONTAL_ALIGNMENT_LEFT,
			max_w,
			lbl_px,
			Color(accent, 0.90)
		)
		draw_string(
			mono,
			Vector2(text_x, rect.end.y - 6.0 * s),
			value,
			HORIZONTAL_ALIGNMENT_LEFT,
			max_w,
			val_px,
			AegisTokens.INK
		)
	else:
		draw_string(
			mono,
			Vector2(text_x, rect.position.y + rect.size.y * 0.68),
			value,
			HORIZONTAL_ALIGNMENT_LEFT,
			max_w,
			val_px,
			AegisTokens.INK
		)


func _draw_chamfer_plate(rect: Rect2, cut: float, fill: Color, accent: Color) -> void:
	var c := minf(cut, minf(rect.size.x, rect.size.y) * 0.42)
	var poly := PackedVector2Array(
		[
			Vector2(rect.position.x + c, rect.position.y),
			Vector2(rect.end.x, rect.position.y),
			Vector2(rect.end.x, rect.end.y - c),
			Vector2(rect.end.x - c, rect.end.y),
			Vector2(rect.position.x, rect.end.y),
			Vector2(rect.position.x, rect.position.y + c),
		]
	)
	draw_colored_polygon(poly, fill)
	var outline := poly.duplicate()
	outline.append(poly[0])
	draw_polyline(outline, Color(AegisTokens.LINE_HI, 0.72), 1.1, true)
	draw_line(
		Vector2(rect.position.x + c, rect.position.y),
		Vector2(rect.end.x, rect.position.y),
		Color(accent, 0.88),
		1.8,
		true
	)
