class_name Screens
extends CanvasLayer
## Full-screen cards: title, new-game confirm, day intro, pause, settings, day summary, shop, game over, victory.
## Every card works with the keyboard / gamepad: its first button takes the focus when it opens.

const CARD_WIDTH := 620.0
## Dimmed, blurred backdrop behind the cards (a 13-tap blur of what is drawn below: the 3D view and the HUD).
const BACKDROP_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform vec4 tint : source_color = vec4(0.27, 0.12, 0.04, 0.22);
uniform float radius = 5.0;
void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * radius;
	vec3 c = texture(screen_tex, SCREEN_UV).rgb * 0.2;
	for (int i = 0; i < 12; i++) {
		float a = float(i) * 0.5236;
		float r = (i % 2 == 0) ? 1.0 : 0.55;
		c += texture(screen_tex, SCREEN_UV + vec2(cos(a), sin(a)) * px * r).rgb * (0.8 / 12.0);
	}
	COLOR = vec4(mix(c, tint.rgb, tint.a), 1.0);
}
"""

var _dim: ColorRect
var _dim_mat: ShaderMaterial
var _center: CenterContainer
var _card: PanelContainer
var _scroll: ScrollContainer
var _body: VBoxContainer
var _confetti: Control
var _current := ""
var _settings_return := "title"
var _tween: Tween = null
var _fit_pending := false
var _focus_first: Control = null
## The upgrade whose buy button keeps the focus after the shop card is rebuilt.
var _shop_focus := ""


func _ready() -> void:
	layer = 10
	_dim = ColorRect.new()
	_dim.color = Color(0.27, 0.12, 0.04, 0.34)
	var sh := Shader.new()
	sh.code = BACKDROP_SHADER
	_dim_mat = ShaderMaterial.new()
	_dim_mat.shader = sh
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)
	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UiKit.box(Color(1.0, 0.973, 0.922, 0.93), 22, Color(1, 1, 1, 0.8), 2, true))
	_center.add_child(_card)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_card.add_child(_scroll)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)
	_confetti = Control.new()
	_confetti.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confetti.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_confetti)
	GameState.phase_changed.connect(_on_phase)
	GameState.paused_changed.connect(_on_paused)
	Settings.language_changed.connect(_rebuild)
	get_viewport().size_changed.connect(_request_fit)
	_dim.visible = false
	_center.visible = false
	_on_phase(GameState.phase)


func current() -> String:
	return _current


func open_settings(return_to: String) -> void:
	_settings_return = return_to
	show_screen("settings")


func close_settings() -> void:
	if _settings_return == "pause":
		show_screen("pause")
	else:
		show_screen("title")


## Esc / P: closes a panel shown on top of a screen (settings, new-game confirm). Returns false if there is none.
func close_panel() -> bool:
	match _current:
		"settings":
			close_settings()
			return true
		"confirm":
			show_screen("title")
			return true
	return false


func is_open() -> bool:
	return _center.visible


func _on_phase(p: String) -> void:
	match p:
		"play":
			hide_screen()
		_:
			show_screen(p)


func _on_paused(paused: bool) -> void:
	if paused:
		show_screen("pause")
	elif GameState.phase == "play":
		hide_screen()


func hide_screen() -> void:
	_current = ""
	if _tween:
		_tween.kill()
	_dim.visible = false
	_center.visible = false


func _rebuild() -> void:
	if _current != "":
		show_screen(_current, false)


func show_screen(screen_name: String, animate: bool = true) -> void:
	_current = screen_name
	_focus_first = null
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_body.alignment = BoxContainer.ALIGNMENT_BEGIN
	match screen_name:
		"title":
			_build_title()
		"confirm":
			_build_confirm()
		"intro":
			_build_intro()
		"pause":
			_build_pause()
		"settings":
			_build_settings()
		"summary":
			_build_summary()
		"shop":
			_build_shop()
		"gameover":
			_build_gameover()
		"victory":
			_build_victory(animate)
	_dim.visible = true
	_center.visible = true
	# the title keeps the live demo day sharp behind it; every other card blurs the frozen game
	var on_title := screen_name == "title" or screen_name == "confirm" or (screen_name == "settings" and _settings_return == "title")
	_dim.material = null if on_title else _dim_mat
	_dim.color = Color(0.27, 0.12, 0.04, 0.08)
	_request_fit()
	if animate:
		if _tween:
			_tween.kill()
		_card.modulate.a = 0.0
		_card.pivot_offset = _card.size * 0.5
		_card.scale = Vector2(0.94, 0.94)
		_tween = create_tween().set_parallel(true)
		_tween.tween_property(_card, "modulate:a", 1.0, 0.25)
		_tween.tween_property(_card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Sfx.play("whoosh", -10.0)
	else:
		_card.modulate.a = 1.0
		_card.scale = Vector2.ONE
	_grab_focus.call_deferred()


func _grab_focus() -> void:
	if _focus_first != null and is_instance_valid(_focus_first) and _focus_first.is_visible_in_tree():
		_focus_first.grab_focus()


func _request_fit() -> void:
	if _fit_pending:
		return
	_fit_pending = true
	_fit.call_deferred()


func _fit() -> void:
	_fit_pending = false
	var vp := get_viewport().get_visible_rect().size
	var w := minf(CARD_WIDTH, vp.x - 24.0)
	_scroll.custom_minimum_size = Vector2(w - 28.0, 0.0)
	await get_tree().process_frame
	var want := _body.get_combined_minimum_size().y
	var avail := vp.y - 28.0 - 28.0
	_scroll.custom_minimum_size = Vector2(w - 28.0, minf(want, avail))
	_card.pivot_offset = _card.size * 0.5


# ---- building blocks -------------------------------------------------------

func _title(text: String, size: int = 30, color: Color = Palette.UI_INK) -> Label:
	var l := UiKit.label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(l)
	return l


func _text(text: String, size: int = 15, color: Color = Color("5a3d2a")) -> Label:
	var l := UiKit.label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 200
	_body.add_child(l)
	return l


func _icon_center(kind: String, px: float) -> Icon:
	var c := CenterContainer.new()
	var ic := Icon.make(kind, px)
	c.add_child(ic)
	_body.add_child(c)
	return ic


func _row(left: String, right: String, icon_kind: String = "") -> void:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiKit.box(Color(1, 1, 1, 0.55), 10))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	if icon_kind != "":
		h.add_child(Icon.make(icon_kind, 20.0))
	h.add_child(UiKit.label(left, 15))
	h.add_child(UiKit.spacer(0, 0, true))
	h.add_child(UiKit.label(right, 15))
	pc.add_child(h)
	_body.add_child(pc)


func _buttons(defs: Array) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 4)
	for d in defs:
		var b := UiKit.button(d["text"], d.get("kind", "primary"), d.get("size", 18))
		b.pressed.connect(func() -> void:
			Sfx.play("click")
			(d["action"] as Callable).call())
		flow.add_child(b)
		if _focus_first == null:
			_focus_first = b
	_body.add_child(flow)
	return flow


## "New record!" chip on the summary, game over and victory cards.
func _record_badge() -> void:
	if not GameState.new_record:
		return
	var c := CenterContainer.new()
	var pc := PanelContainer.new()
	var sb := UiKit.box(Color("f2b632"), 16, Palette.UI_AMBER_DARK, 2)
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	pc.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(Icon.make("star", 20.0))
	h.add_child(UiKit.label(Loc.t("newRecord"), 15, Palette.UI_AMBER_DARK))
	pc.add_child(h)
	c.add_child(pc)
	_body.add_child(c)


func _menu_button() -> void:
	_buttons([{"text": Loc.t("menu"), "kind": "alt", "size": 15, "action": func() -> void: GameState.to_menu()}])


func _stars_row(n: int) -> void:
	var c := CenterContainer.new()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	for i in 3:
		var ic := Icon.make("star" if i < n else "starOff", 54.0)
		ic.pivot_offset = Vector2(27, 27)
		h.add_child(ic)
		if i < n:
			ic.scale = Vector2.ZERO
			var tw := create_tween()
			tw.tween_interval(0.3 + i * 0.28)
			tw.tween_callback(Sfx.play.bind("star", 0.0, 1.0 + i * 0.12))
			tw.tween_property(ic, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(ic, "rotation", 0.0, 0.5).from(-0.7)
	c.add_child(h)
	_body.add_child(c)


func _spacer(h: float = 6.0) -> void:
	_body.add_child(UiKit.spacer(0, h))


func _howto(num: int, text: String) -> void:
	var pc := PanelContainer.new()
	var sb := UiKit.box(Color(1, 1, 1, 0.5), 12)
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	pc.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UiKit.box(Palette.UI_AMBER, 11))
	var bl := UiKit.label(str(num), 12, Color.WHITE)
	bl.custom_minimum_size = Vector2(10, 0)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(bl)
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(badge)
	var l := UiKit.label(text, 13, Palette.UI_INK, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 150
	h.add_child(l)
	pc.add_child(h)
	_body.add_child(pc)


# ---- screens ---------------------------------------------------------------

## The generated crest (128 px, 96 px in portrait).
func _logo(px: float) -> void:
	var c := CenterContainer.new()
	var tr := TextureRect.new()
	tr.texture = Icons.logo_texture()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	tr.custom_minimum_size = Vector2(px, px)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(tr)
	_body.add_child(c)


func _build_title() -> void:
	var vp := get_viewport().get_visible_rect().size
	if Icons.logo_texture() != null:
		# 128 px (112 in a short window so the whole card fits), 96 px on a phone
		_logo(96.0 if vp.x < vp.y else (112.0 if vp.y < 760.0 else 128.0))
	else:
		_icon_center("tea", 54.0)
	_title(Loc.t("title"), 48, Palette.UI_AMBER)
	_text(Loc.t("tagline"))
	_howto(1, Loc.t("how1"))
	_howto(2, Loc.t("how2"))
	_howto(3, Loc.t("how3"))
	_howto(4, Loc.t("how4"))
	var best := GameState.best
	_text(Loc.t("best", [best["day"], best["total"]]) if int(best["day"]) > 0 else Loc.t("noBest"), 14, Palette.UI_INK_SOFT)
	var defs: Array = []
	if GameState.has_save():
		defs.append({"text": Loc.t("continue"), "action": func() -> void: GameState.continue_game()})
		defs.append({"text": Loc.t("newGame"), "kind": "alt", "action": func() -> void: show_screen("confirm")})
	else:
		defs.append({"text": Loc.t("play"), "action": func() -> void: GameState.start_new()})
	_buttons(defs)
	_buttons([
		{"text": Loc.t("settings"), "kind": "small", "size": 14, "action": func() -> void: open_settings("title")},
		{"text": Loc.t("langBtn"), "kind": "small", "size": 14, "action": Settings.toggle_language},
	])
	_text(Loc.t("footer", ["Claude Sonnet 5.5"]), 12, Palette.UI_INK_SOFT)


## A new game overwrites the saved run, so it asks first.
func _build_confirm() -> void:
	_title(Loc.t("newGame"), 34, Palette.UI_AMBER)
	_text(Loc.t("newGameWarn"))
	_spacer(4)
	_buttons([
		{"text": Loc.t("yes"), "action": func() -> void: GameState.start_new()},
		{"text": Loc.t("back"), "kind": "alt", "action": func() -> void: show_screen("title")},
	])


func _build_intro() -> void:
	var day := GameState.day
	var cfg := GameData.day_config(day)
	var endless := day > GameData.DAY_COUNT
	_title(Loc.t("dayEndless", [day]) if endless else Loc.t("dayOf", [day]), 40, Palette.UI_AMBER)
	var c := CenterContainer.new()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(Icon.make("coin", 26.0))
	h.add_child(UiKit.label(Loc.t("dayTarget", [cfg.target]), 20))
	c.add_child(h)
	_body.add_child(c)
	_spacer(4)
	var chip_c := CenterContainer.new()
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UiKit.box(Palette.UI_AMBER, 24))
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 8)
	var white := PanelContainer.new()
	white.add_theme_stylebox_override("panel", UiKit.box(Color.WHITE, 18))
	white.add_child(Icon.make(cfg.new_icon, 26.0))
	ch.add_child(white)
	var cl := UiKit.label("%s: %s" % [Loc.t("newThing"), Loc.t(cfg.new_key)], 15, Color.WHITE)
	cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cl.custom_minimum_size.x = 160
	ch.add_child(cl)
	chip.add_child(ch)
	chip_c.add_child(chip)
	_body.add_child(chip_c)
	_spacer(4)
	_text(Loc.t("menuToday"), 14, Palette.UI_INK_SOFT)
	var mc := CenterContainer.new()
	var mh := HBoxContainer.new()
	mh.add_theme_constant_override("separation", 8)
	for id in cfg.menu:
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", UiKit.box(Color.WHITE, 12))
		pc.add_child(Icon.make(id, 34.0))
		mh.add_child(pc)
	mc.add_child(mh)
	_body.add_child(mc)
	_text(Loc.t("tip%d" % (((day - 1) % 5) + 1)), 14, Palette.UI_INK_SOFT)
	_buttons([{"text": Loc.t("startDay"), "action": func() -> void: GameState.begin_day()}])
	_menu_button()


func _build_pause() -> void:
	_title(Loc.t("paused"), 40, Palette.UI_AMBER)
	_text(Loc.t("pausedSub"), 14, Palette.UI_INK_SOFT)
	_spacer(6)
	_buttons([
		{"text": Loc.t("resume"), "action": func() -> void: GameState.toggle_pause()},
		{"text": Loc.t("restart"), "kind": "alt", "action": func() -> void: GameState.restart_day()},
		{"text": Loc.t("settings"), "kind": "alt", "action": func() -> void: open_settings("pause")},
		{"text": Loc.t("menu"), "kind": "alt", "action": func() -> void:
			GameState.set_paused(false)
			GameState.to_menu()},
	])


func _build_settings() -> void:
	_title(Loc.t("settings"), 34, Palette.UI_AMBER)
	_spacer(4)
	_slider_row(Loc.t("volMaster"), Settings.master_volume, "master")
	_slider_row(Loc.t("volMusic"), Settings.music_volume, "music")
	_slider_row(Loc.t("volSfx"), Settings.sfx_volume, "sfx")
	_choice_row(Loc.t("language"), [["TR", "tr"], ["EN", "en"]], Settings.lang, func(v: String) -> void: Settings.set_language(v))
	_choice_row(Loc.t("quality"), [[Loc.t("qLow"), "low"], [Loc.t("qHigh"), "high"]], Settings.quality, func(v: String) -> void:
		Settings.set_quality(v)
		show_screen("settings", false))
	_choice_row(Loc.t("fullscreen"), [[Loc.t("off"), "0"], [Loc.t("on"), "1"]], "1" if Settings.fullscreen else "0", func(v: String) -> void:
		Settings.set_fullscreen(v == "1")
		show_screen("settings", false))
	_spacer(6)
	_buttons([{"text": Loc.t("back"), "action": close_settings}])


func _slider_row(text: String, value: float, key: String) -> void:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiKit.box(Color(1, 1, 1, 0.55), 10))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var l := UiKit.label(text, 15)
	l.custom_minimum_size.x = 120
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.01
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(120, 24)
	s.focus_mode = Control.FOCUS_ALL
	s.add_theme_stylebox_override("focus", UiKit.focus_box(8))
	s.add_theme_stylebox_override("slider", UiKit.box(Color(0.31, 0.16, 0.04, 0.2), 4))
	s.add_theme_stylebox_override("grabber_area", UiKit.box(Palette.UI_AMBER, 4))
	s.add_theme_stylebox_override("grabber_area_highlight", UiKit.box(Palette.UI_AMBER_LIGHT, 4))
	var gt := _knob()
	s.add_theme_icon_override("grabber", gt)
	s.add_theme_icon_override("grabber_highlight", gt)
	h.add_child(s)
	var pct := UiKit.label("%d%%" % roundi(value * 100.0), 14, Palette.UI_INK_SOFT)
	pct.custom_minimum_size.x = 44
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(pct)
	if _focus_first == null:
		_focus_first = s
	var row_sb := UiKit.box(Color(1, 1, 1, 0.55), 10)
	row_sb.border_color = Color("f2b632")
	pc.add_theme_stylebox_override("panel", row_sb)
	s.focus_entered.connect(func() -> void: row_sb.set_border_width_all(3))
	s.focus_exited.connect(func() -> void: row_sb.set_border_width_all(0))
	s.value_changed.connect(func(v: float) -> void:
		pct.text = "%d%%" % roundi(v * 100.0)
		Settings.set_volume(key, v))
	s.drag_ended.connect(func(_changed: bool) -> void: Sfx.play("clink"))
	pc.add_child(h)
	_body.add_child(pc)


static var _knob_tex: ImageTexture = null


func _knob() -> ImageTexture:
	if _knob_tex == null:
		var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
		var c := Vector2(11.5, 11.5)
		for y in 24:
			for x in 24:
				var d := Vector2(x, y).distance_to(c)
				var col := Color(0, 0, 0, 0)
				if d < 10.0:
					col = Color.WHITE if d < 7.0 else Palette.UI_AMBER_DARK
					if d < 7.0:
						col = Color("fff4e6")
				elif d < 11.0:
					col = Color(Palette.UI_AMBER_DARK, 1.0 - (d - 10.0))
				img.set_pixel(x, y, col)
		_knob_tex = ImageTexture.create_from_image(img)
	return _knob_tex


func _choice_row(text: String, options: Array, current_value: String, on_pick: Callable) -> void:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiKit.box(Color(1, 1, 1, 0.55), 10))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var l := UiKit.label(text, 15)
	l.custom_minimum_size.x = 120
	h.add_child(l)
	h.add_child(UiKit.spacer(0, 0, true))
	for o in options:
		var b := UiKit.button(o[0], "small" if o[1] == current_value else "alt", 14)
		b.disabled = false
		var value: String = o[1]
		b.pressed.connect(func() -> void:
			Sfx.play("click")
			on_pick.call(value))
		h.add_child(b)
	pc.add_child(h)
	_body.add_child(pc)


func _build_summary() -> void:
	var r := GameState.last_result
	_title(Loc.t("dayDone"), 36, Palette.UI_AMBER)
	_stars_row(int(r.get("stars", 0)))
	var stars := int(r.get("stars", 0))
	_text(Loc.t("stars3") if stars == 3 else (Loc.t("stars2") if stars == 2 else Loc.t("stars1")), 18, Palette.UI_INK)
	_record_badge()
	_row(Loc.t("earned"), "%d / %d" % [r.get("coins", 0), r.get("target", 0)], "coin")
	_row(Loc.t("tips"), str(r.get("tips", 0)), "coin")
	_row(Loc.t("happyC"), str(r.get("happy", 0)), "happy")
	_row(Loc.t("angryC"), str(r.get("angry", 0)), "angry")
	_row(Loc.t("wallet"), str(GameState.coins), "coin")
	var win := GameState.day == GameData.balance().win_day and not GameState.won
	_buttons([{"text": Loc.t("cont") if win else Loc.t("toShop"), "action": func() -> void: GameState.after_summary()}])
	_menu_button()


func _build_shop() -> void:
	_title(Loc.t("shop"), 34, Palette.UI_AMBER)
	var wc := CenterContainer.new()
	var wp := PanelContainer.new()
	wp.add_theme_stylebox_override("panel", UiKit.box(Color(1, 1, 1, 0.62), 24))
	var wh := HBoxContainer.new()
	wh.add_theme_constant_override("separation", 8)
	wh.add_child(Icon.make("coin", 26.0))
	wh.add_child(UiKit.label(str(GameState.coins), 22))
	wp.add_child(wh)
	wc.add_child(wp)
	_body.add_child(wc)
	var grid := GridContainer.new()
	grid.columns = 2 if get_viewport().get_visible_rect().size.x > 560.0 else 1
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id in GameData.UPGRADE_IDS:
		grid.add_child(_upgrade_card(id))
	_shop_focus = ""
	_body.add_child(grid)
	_buttons([{"text": Loc.t("retry") if GameState.retrying else Loc.t("nextDay"), "action": func() -> void: GameState.next_day()}])
	_menu_button()


func _upgrade_card(id: String) -> Control:
	var u := GameData.upgrade(id)
	var lv: int = GameState.up[id]
	var can := GameState.can_buy(id)
	var pc := PanelContainer.new()
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_theme_stylebox_override("panel", UiKit.box(Color(1, 1, 1, 0.6), 14, Color(Palette.UI_AMBER, 0.6) if can else Color(0, 0, 0, 0), 2))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var ib := PanelContainer.new()
	ib.add_theme_stylebox_override("panel", UiKit.box(Color.WHITE, 12))
	ib.add_child(Icon.make(u.icon, 32.0))
	ib.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ib)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	v.add_child(UiKit.label(Loc.t("u_" + id), 15))
	var d := UiKit.label(Loc.t("u_%s_d" % id), 12, Palette.UI_INK_SOFT, false)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 110
	v.add_child(d)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 3)
	for i in u.max_level:
		var pip := PanelContainer.new()
		pip.custom_minimum_size = Vector2(14, 6)
		pip.add_theme_stylebox_override("panel", UiKit.box(Palette.UI_AMBER if i < lv else Color(0.31, 0.16, 0.04, 0.2), 3))
		pips.add_child(pip)
	v.add_child(pips)
	h.add_child(v)
	var maxed := lv >= u.max_level
	var b := UiKit.button("", "small", 14)
	b.custom_minimum_size = Vector2(76, 36)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bh := HBoxContainer.new()
	bh.set_anchors_preset(Control.PRESET_FULL_RECT)
	bh.alignment = BoxContainer.ALIGNMENT_CENTER
	bh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bh.add_theme_constant_override("separation", 4)
	if maxed:
		var okb := UiKit.label(Loc.t("maxed"), 14, Color.WHITE)
		bh.add_child(okb)
		var sb := UiKit.box(Palette.UI_OK, 11)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("disabled", sb)
		b.disabled = true
	else:
		bh.add_child(Icon.make("coin", 16.0))
		bh.add_child(UiKit.label(str(GameState.upgrade_cost(id)), 14, Color.WHITE))
		b.disabled = not can
		b.pressed.connect(func() -> void:
			if GameState.buy(id):
				_shop_focus = id
				show_screen("shop", false))
		if id == _shop_focus and can:
			_focus_first = b
	b.add_child(bh)
	h.add_child(b)
	pc.add_child(h)
	return pc


func _build_gameover() -> void:
	var r := GameState.last_result
	_title(Loc.t("gameover"), 38, Palette.UI_BAD)
	_icon_center("angry", 64.0)
	_text(Loc.t("goTxt"))
	_record_badge()
	# same rows as the browser version: the day played, the day's coins, happy / angry, total coins of the run
	_row(Loc.t("reached"), str(GameState.day), "star")
	_row(Loc.t("earned"), "%d / %d" % [r.get("coins", 0), r.get("target", 0)], "coin")
	_row(Loc.t("happyC") + " / " + Loc.t("angryC"), "%d / %d" % [r.get("happy", 0), r.get("angry", 0)], "happy")
	_row(Loc.t("total"), str(GameState.total_earned), "coin")
	_buttons([
		{"text": Loc.t("retryShop"), "action": func() -> void: GameState.retry_via_shop()},
		{"text": Loc.t("menu"), "kind": "alt", "action": func() -> void: GameState.to_menu()},
	])


func _build_victory(animate: bool = true) -> void:
	_title(Loc.t("victory"), 42, Palette.UI_AMBER)
	var stars := 0
	var cleared := 0
	for r in GameState.day_log:
		stars += int(r.get("stars", 0))
		cleared += 1 if r.get("passed", true) else 0
	# a failed day stays in the log next to its retry; count every cleared day once
	var days_played := maxi(cleared, 1)
	var ratio := float(stars) / (days_played * 3.0)
	_stars_row(3 if ratio >= 0.8 else (2 if ratio >= 0.55 else 1))
	_text(Loc.t("victoryTxt"))
	_record_badge()
	_row(Loc.t("total"), str(GameState.total_earned), "coin")
	_row(Loc.t("ratingStars"), "%d / %d" % [stars, days_played * 3], "star")
	_buttons([
		{"text": Loc.t("endless"), "action": func() -> void: GameState.go_endless()},
		{"text": Loc.t("menu"), "kind": "alt", "action": func() -> void: GameState.to_menu()},
	])
	if animate:
		_launch_confetti()


func _launch_confetti() -> void:
	var vp := get_viewport().get_visible_rect().size
	var cols: Array[Color] = [Color("c2410c"), Color("f2b632"), Color("3f7f86"), Color("e05a7a"), Color("f8eed8"), Color("5e8c3e")]
	for i in 70:
		var cr := ColorRect.new()
		cr.color = cols[i % cols.size()]
		cr.size = Vector2(9, 15)
		cr.position = Vector2(randf() * vp.x, -30.0 - randf() * 120.0)
		cr.rotation = randf() * TAU
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_confetti.add_child(cr)
		var dur := 2.2 + randf() * 2.0
		var tw := cr.create_tween().set_parallel(true)
		tw.tween_property(cr, "position:y", vp.y + 40.0, dur).set_delay(randf() * 0.6)
		tw.tween_property(cr, "position:x", cr.position.x + (randf() - 0.5) * 160.0, dur)
		tw.tween_property(cr, "rotation", cr.rotation + randf_range(6.0, 12.0), dur)
		tw.chain().tween_callback(cr.queue_free)
