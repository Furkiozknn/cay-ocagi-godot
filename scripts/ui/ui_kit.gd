class_name UiKit
extends RefCounted
## Small helpers that build styled Controls (cards, buttons, labels, bars) in code.

static var _bold: FontVariation = null


static func bold_font() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = ThemeDB.fallback_font
		_bold.variation_embolden = 0.55
	return _bold


static func box(bg: Color, radius: int = 14, border: Color = Color(0, 0, 0, 0), border_w: int = 0, shadow: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	if shadow:
		sb.shadow_color = Color(0.35, 0.16, 0.04, 0.28)
		sb.shadow_size = 10
		sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func glass_panel() -> StyleBoxFlat:
	return box(Palette.UI_GLASS, 16, Palette.UI_GLASS_BORDER, 2, true)


static func label(text: String, size: int = 16, color: Color = Palette.UI_INK, is_bold: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if is_bold:
		l.add_theme_font_override("font", bold_font())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## kind: "primary" (amber), "alt" (cream), "small" (compact amber), "mini" (tiny cream), "icon" (square).
static func button(text: String, kind: String = "primary", font_size: int = 18) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", bold_font())
	b.add_theme_font_size_override("font_size", font_size)
	var normal := Palette.UI_AMBER
	var hover := Palette.UI_AMBER_LIGHT
	var edge := Palette.UI_AMBER_DARK
	var fg := Color.WHITE
	var pad_h := 26
	var pad_v := 10
	var radius := 14
	match kind:
		"alt":
			normal = Color(1, 1, 1, 0.8)
			hover = Color.WHITE
			edge = Color(0.47, 0.27, 0.12, 0.35)
			fg = Palette.UI_INK
		"small":
			pad_h = 16
			pad_v = 6
			radius = 11
		"mini":
			normal = Color(1, 1, 1, 0.75)
			hover = Color.WHITE
			edge = Color(0.47, 0.27, 0.12, 0.3)
			fg = Palette.UI_AMBER_DARK
			pad_h = 9
			pad_v = 1
			radius = 8
		"icon":
			normal = Color(1, 1, 1, 0.62)
			hover = Color.WHITE
			edge = Color(0.47, 0.27, 0.12, 0.3)
			fg = Palette.UI_INK
			pad_h = 8
			pad_v = 4
			radius = 10
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.7))
	var n := _btn_box(normal, edge, radius, pad_h, pad_v, 4)
	var h := _btn_box(hover, edge, radius, pad_h, pad_v, 4)
	var p := _btn_box(hover, edge, radius, pad_h, pad_v + 3, 1)
	var d := _btn_box(Color("b9a99a"), Color("8d7b6c"), radius, pad_h, pad_v, 4)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", d)
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			Sfx.play("tick", -12.0, 1.4))
	return b


static func _btn_box(bg: Color, edge: Color, radius: int, pad_h: int, pad_v: int, depth: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_color = edge
	sb.border_width_bottom = depth
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v + depth
	sb.shadow_color = Color(0.4, 0.15, 0.04, 0.22)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	return sb


static func bar(fill: Color, width: float, height: float = 8.0) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.min_value = 0.0
	pb.max_value = 1.0
	pb.step = 0.0
	pb.custom_minimum_size = Vector2(width, height)
	pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pb.add_theme_stylebox_override("background", box(Color(0.31, 0.16, 0.04, 0.17), 6))
	pb.add_theme_stylebox_override("fill", box(fill, 6))
	return pb


static func spacer(width: float = 0.0, height: float = 0.0, expand: bool = false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func fmt_time(seconds: float) -> String:
	var s := maxi(0, ceili(seconds))
	return "%d:%02d" % [floori(s / 60.0), s % 60]
