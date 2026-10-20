class_name Hud
extends CanvasLayer
## In-game overlay: top bar, tray + station dock, order bubbles over the tables,
## floating coin texts and toasts.

signal settings_requested
signal pause_requested

const STATION_ICONS := {"tea": "tea", "simit": "simit", "coffee": "coffee", "ayran": "ayran", "sink": "sink"}
const AVATARS := {"normal": "person", "office": "office", "group": "group", "regular": "regular"}

var world: WorldView

var _root: Control
var _bubble_layer: Control
var _float_layer: Control
var _top: PanelContainer
var _logo: Control
var _day_label: Label
var _clock_bar: ProgressBar
var _clock_label: Label
var _clock_fill: StyleBoxFlat
var _clock_fill_late: StyleBoxFlat
var _late_shown := false
var _coin_chip: Control
var _coin_icon: Icon
var _coin_label: Label
var _goal_label: Label
var _goal_bar: ProgressBar
var _happy_label: Label
var _angry_label: Label
var _speed_btn: Button
var _pause_btn: Button
var _pause_icon: Icon
var _snd_btn: Button
var _snd_icon: Icon
var _lang_btn: Button
var _dock: HFlowContainer
var _tray_title: Label
var _tray_slots: Array[PanelContainer] = []
var _tray_icons: Array[Icon] = []
var _slot_full: Array[bool] = [true, true, true, true, true]
var _queue_box: HBoxContainer
var _queue_n := -1
var _clear_btn: Button
var _stations: Dictionary = {}
var _toasts: VBoxContainer
var _bubbles: Array[OrderBubble] = []
var _dirty_bubbles: Array[OrderBubble] = []
var _floats: Array[Dictionary] = []
var _sim: TeaSim = null
var _last_toast := ""
var _last_toast_ms := 0
var _queue_sig := ""


func _ready() -> void:
	layer = 5
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_bubble_layer = Control.new()
	_bubble_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bubble_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bubble_layer)
	_float_layer = Control.new()
	_float_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_float_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_float_layer)
	_build_top()
	_build_dock()
	_build_toasts()
	_build_bubbles()
	GameState.sim_created.connect(_on_sim_created)
	GameState.phase_changed.connect(_on_phase)
	GameState.paused_changed.connect(func(_p: bool) -> void: _refresh_buttons())
	GameState.speed_changed.connect(func(_s: int) -> void: _refresh_buttons())
	Settings.language_changed.connect(_refresh_texts)
	Settings.changed.connect(_refresh_buttons)
	_refresh_texts()
	_refresh_buttons()
	_update_visibility()
	if GameState.sim != null:
		_on_sim_created(GameState.sim)


func _update_visibility() -> void:
	_root.visible = GameState.phase == "play"


func _on_phase(p: String) -> void:
	_update_visibility()
	if p == "play" and GameState.day == 1 and not GameState.won:
		toast(Loc.t("welcome"), "good")


# ---- construction ----------------------------------------------------------

func _chip(parent: Control, icon_kind: String, size_px: float = 22.0) -> Label:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(Icon.make(icon_kind, size_px))
	var l := UiKit.label("0", 15)
	h.add_child(l)
	parent.add_child(h)
	return l


## Square HUD button. No keyboard focus: every one of them has its own key (F, P, M, L).
func _hud_button(text: String, w: float) -> Button:
	var b := UiKit.button(text, "icon", 14)
	b.focus_mode = Control.FOCUS_NONE
	var touch := UiKit.is_touch()
	b.custom_minimum_size = Vector2(maxf(w, UiKit.TOUCH_MIN) if touch else w, UiKit.TOUCH_MIN if touch else 36.0)
	return b


func _icon_button(icon_kind: String) -> Array:
	var b := _hud_button("", 38.0)
	var ic := Icon.make(icon_kind, 20.0)
	ic.custom_minimum_size = Vector2.ZERO
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	b.add_child(ic)
	return [b, ic]


func _build_top() -> void:
	_top = PanelContainer.new()
	_top.mouse_filter = Control.MOUSE_FILTER_STOP
	_top.add_theme_stylebox_override("panel", UiKit.glass_panel())
	_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top.offset_left = 8
	_top.offset_right = -8
	_top.offset_top = 8
	_root.add_child(_top)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 14)
	flow.add_theme_constant_override("v_separation", 4)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_child(flow)
	var logo := HBoxContainer.new()
	logo.add_theme_constant_override("separation", 6)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo.add_child(Icon.make("tea", 26.0))
	logo.add_child(UiKit.label("Çay Ocağı", 19, Palette.UI_AMBER))
	flow.add_child(logo)
	_logo = logo
	_day_label = UiKit.label("", 15)
	_day_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	flow.add_child(_day_label)
	var clock := HBoxContainer.new()
	clock.add_theme_constant_override("separation", 6)
	clock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock_bar = UiKit.bar(Color("f3c14f"), 96.0, 8.0)
	_clock_fill = _clock_bar.get_theme_stylebox("fill") as StyleBoxFlat
	_clock_fill_late = UiKit.box(Palette.UI_BAD, 6)
	clock.add_child(_clock_bar)
	_clock_label = UiKit.label("3:00", 15)
	clock.add_child(_clock_label)
	flow.add_child(clock)
	var coins := HBoxContainer.new()
	coins.add_theme_constant_override("separation", 6)
	coins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coin_icon = Icon.make("coin", 22.0)
	_coin_icon.pivot_offset = Vector2(11, 11)
	coins.add_child(_coin_icon)
	_coin_chip = coins
	_coin_label = UiKit.label("0", 15)
	coins.add_child(_coin_label)
	_goal_label = UiKit.label("/ 0", 12, Palette.UI_INK_SOFT)
	coins.add_child(_goal_label)
	_goal_bar = UiKit.bar(Palette.UI_AMBER, 96.0, 8.0)
	coins.add_child(_goal_bar)
	flow.add_child(coins)
	var moods := HBoxContainer.new()
	moods.add_theme_constant_override("separation", 12)
	moods.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_happy_label = _chip(moods, "happy")
	_angry_label = _chip(moods, "angry")
	flow.add_child(moods)
	var grow := UiKit.spacer(8, 0, true)
	flow.add_child(grow)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 6)
	btns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speed_btn = _hud_button("1×", 44.0)
	_speed_btn.pressed.connect(GameState.toggle_speed)
	btns.add_child(_speed_btn)
	var pb := _icon_button("pause")
	_pause_btn = pb[0]
	_pause_icon = pb[1]
	_pause_btn.pressed.connect(func() -> void: pause_requested.emit())
	btns.add_child(_pause_btn)
	var sb := _icon_button("snd")
	_snd_btn = sb[0]
	_snd_icon = sb[1]
	_snd_btn.pressed.connect(func() -> void: Settings.set_muted(not Settings.muted))
	btns.add_child(_snd_btn)
	var gb := _icon_button("gear")
	gb[0].pressed.connect(func() -> void: settings_requested.emit())
	btns.add_child(gb[0])
	_lang_btn = _hud_button("EN", 44.0)
	_lang_btn.pressed.connect(Settings.toggle_language)
	btns.add_child(_lang_btn)
	flow.add_child(btns)


func _build_dock() -> void:
	_dock = HFlowContainer.new()
	_dock.alignment = FlowContainer.ALIGNMENT_CENTER
	_dock.add_theme_constant_override("h_separation", 10)
	_dock.add_theme_constant_override("v_separation", 6)
	_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_dock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_dock.offset_left = 8
	_dock.offset_right = -8
	_dock.offset_bottom = -8
	_root.add_child(_dock)
	# tray
	var tray := PanelContainer.new()
	tray.mouse_filter = Control.MOUSE_FILTER_STOP
	tray.add_theme_stylebox_override("panel", UiKit.glass_panel())
	_dock.add_child(tray)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 7)
	th.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray.add_child(th)
	_tray_title = UiKit.label("", 12, Palette.UI_INK_SOFT)
	_tray_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(_tray_title)
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 5)
	slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	th.add_child(slots)
	for i in 5:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(UiKit.TOUCH_MIN, UiKit.TOUCH_MIN) if UiKit.is_touch() else Vector2(40, 40)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		var ic := Icon.make("tea", 28.0)
		ic.visible = false
		var center := CenterContainer.new()
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(ic)
		slot.add_child(center)
		slot.gui_input.connect(_on_slot_input.bind(i))
		slots.add_child(slot)
		_tray_slots.append(slot)
		_tray_icons.append(ic)
	_queue_box = HBoxContainer.new()
	_queue_box.add_theme_constant_override("separation", 4)
	_queue_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	th.add_child(_queue_box)
	_clear_btn = UiKit.button("", "mini", 11)
	_clear_btn.focus_mode = Control.FOCUS_NONE
	_clear_btn.pressed.connect(func() -> void:
		if GameState.sim != null:
			GameState.sim.clear_queue())
	_clear_btn.visible = false
	th.add_child(_clear_btn)
	# stations
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", UiKit.glass_panel())
	_dock.add_child(panel)
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 6)
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(sh)
	var n := 1
	for id in TeaSim.STATION_IDS:
		var sbtn := StationButton.new()
		sh.add_child(sbtn)
		sbtn.setup(id, str(n), STATION_ICONS[id])
		sbtn.pressed.connect(_on_station_pressed)
		sbtn.hovered.connect(_on_station_hover)
		_stations[id] = sbtn
		n += 1


func _build_toasts() -> void:
	_toasts = VBoxContainer.new()
	_toasts.add_theme_constant_override("separation", 6)
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toasts.offset_top = 78
	_root.add_child(_toasts)


func _build_bubbles() -> void:
	for i in TeaSim.TABLE_POS.size():
		var b := OrderBubble.new()
		_bubble_layer.add_child(b)
		b.pressed.connect(_on_table_pressed.bind(i))
		_bubbles.append(b)
		var d := OrderBubble.new()
		_bubble_layer.add_child(d)
		d.pressed.connect(_on_table_pressed.bind(i))
		_dirty_bubbles.append(d)


# ---- events ----------------------------------------------------------------

func _on_sim_created(s: TeaSim) -> void:
	if _sim != null and _sim.toast.is_connected(_on_toast):
		_sim.toast.disconnect(_on_toast)
		_sim.floating.disconnect(_on_float)
		_sim.paid.disconnect(_on_paid)
	_sim = s
	_sim.toast.connect(_on_toast)
	_sim.floating.connect(_on_float)
	_sim.paid.connect(_on_paid)
	_queue_sig = ""
	for b in _bubbles:
		b.clear()
	for d in _dirty_bubbles:
		d.clear()
	_queue_n = -1
	_set_late(false)
	for f in _floats:
		(f["node"] as Node).queue_free()
	_floats.clear()


func _on_station_pressed(id: String) -> void:
	if GameState.phase == "play" and not GameState.paused and GameState.sim != null:
		GameState.sim.click_station(id)


func _on_station_hover(id: String, on: bool) -> void:
	if world != null:
		world.set_hover("station" if on else "", id)


func _on_table_pressed(i: int) -> void:
	if GameState.phase == "play" and not GameState.paused and GameState.sim != null:
		GameState.sim.click_table(i)


func _on_slot_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if GameState.sim != null and GameState.phase == "play" and not GameState.paused:
			GameState.sim.drop_tray(index)


func _on_toast(key: String, tone: String) -> void:
	if GameState.phase != "play":
		return
	toast(Loc.t(key), tone)


func _on_float(pos: Vector3, text: String, tone: String) -> void:
	if GameState.phase != "play":
		return
	var l := UiKit.label(Loc.t(text), 24, Color.WHITE)
	if tone == "bad":
		l.add_theme_color_override("font_color", Color("ffd0c0"))
		l.add_theme_font_size_override("font_size", 18)
	elif tone == "coin":
		l.add_theme_color_override("font_color", Color("fff0b0"))
	l.add_theme_constant_override("outline_size", 7)
	l.add_theme_color_override("font_outline_color", Color("7c2d12"))
	l.pivot_offset = Vector2(20, 12)
	_float_layer.add_child(l)
	_floats.append({"node": l, "pos": pos, "age": 0.0})


## A few coins fly from the paying table to the coin counter, which then bumps (1-4 coins, 0.7 s).
func _on_paid(pos: Vector3, amount: int) -> void:
	if GameState.phase != "play" or world == null or world.is_behind(pos) or not _coin_icon.is_visible_in_tree():
		return
	var from := world.to_screen(pos) - _float_layer.global_position
	var to := _coin_icon.global_position - _float_layer.global_position
	var n := mini(4, 1 + amount / 8)
	for i in n:
		var c := Icon.make("coin", 22.0)
		c.position = from + Vector2(randf_range(-13.0, 13.0), randf_range(-8.0, 8.0)) - Vector2(11, 11)
		_float_layer.add_child(c)
		var tw := c.create_tween()
		tw.tween_interval(0.04 + i * 0.07)
		tw.tween_property(c, "position", to, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(c, "modulate:a", 0.4, 0.7)
		tw.parallel().tween_property(c, "scale", Vector2(0.8, 0.8), 0.7)
		tw.tween_callback(c.queue_free)
	var bump := _coin_icon.create_tween()
	bump.tween_interval(0.76)
	bump.tween_property(_coin_icon, "scale", Vector2(1.35, 1.35), 0.09)
	bump.tween_property(_coin_icon, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Last orders: the clock bar and the time turn red for the final 20 seconds.
func _set_late(on: bool) -> void:
	if on == _late_shown:
		return
	_late_shown = on
	_clock_bar.add_theme_stylebox_override("fill", _clock_fill_late if on else _clock_fill)
	_clock_label.add_theme_color_override("font_color", Palette.UI_BAD if on else Palette.UI_INK)


## Shows a short message under the top bar.
func toast(msg: String, tone: String = "") -> void:
	var now := Time.get_ticks_msec()
	if msg == _last_toast and now - _last_toast_ms < 900:
		return
	_last_toast = msg
	_last_toast_ms = now
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := Color(0.23, 0.14, 0.08, 0.9)
	if tone == "bad":
		bg = Color(0.63, 0.16, 0.1, 0.93)
	elif tone == "good":
		bg = Color(0.2, 0.47, 0.24, 0.93)
	var sb := UiKit.box(bg, 20)
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	pc.add_theme_stylebox_override("panel", sb)
	pc.add_child(UiKit.label(msg, 14, Color("fff6e5")))
	pc.modulate.a = 0.0
	_toasts.add_child(pc)
	while _toasts.get_child_count() > 3:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var tw := pc.create_tween()
	tw.tween_property(pc, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.8)
	tw.tween_property(pc, "modulate:a", 0.0, 0.5)
	tw.tween_callback(pc.queue_free)


# ---- refresh ---------------------------------------------------------------

func _refresh_texts() -> void:
	_tray_title.text = Loc.t("tray").to_upper()
	_clear_btn.text = Loc.t("clearQ")
	_lang_btn.text = Loc.t("langBtn")
	for id in TeaSim.STATION_IDS:
		(_stations[id] as StationButton).set_title(Loc.t(id))


func _refresh_buttons() -> void:
	_speed_btn.text = "%d×" % GameState.speed
	_pause_icon.kind = "play" if GameState.paused else "pause"
	_snd_icon.kind = "mute" if Settings.muted else "snd"


func _process(_delta: float) -> void:
	if not _root.visible or _sim == null:
		return
	var delta := get_process_delta_time()
	var s := _sim
	var portrait := _root.size.x < _root.size.y
	_logo.visible = not portrait
	_clock_bar.custom_minimum_size.x = 56.0 if portrait else 96.0
	_goal_bar.custom_minimum_size.x = 56.0 if portrait else 96.0
	_day_label.text = Loc.t("dayEndless", [GameState.day]) if GameState.endless or GameState.day > GameData.DAY_COUNT else Loc.t("dayOf", [GameState.day])
	_clock_bar.value = clampf(s.clock / s.day_len, 0.0, 1.0)
	_clock_label.text = UiKit.fmt_time(s.day_len - s.clock)
	_set_late(s.last_call)
	# today's coins against today's target (the wallet is shown in the shop and the summary)
	_coin_label.text = str(s.day_coins)
	_goal_label.text = "/ %d" % s.target
	_goal_bar.value = clampf(float(s.day_coins) / maxf(s.target, 1.0), 0.0, 1.0)
	_happy_label.text = str(s.happy)
	_angry_label.text = str(s.angry)
	_update_tray(s)
	_update_stations(s)
	_update_bubbles(s)
	_update_floats(delta)


func _update_tray(s: TeaSim) -> void:
	var cap := s.tray_cap()
	for i in _tray_slots.size():
		var locked := i >= cap
		var full := i < s.waiter.tray.size()
		if _slot_full[i] != full:
			_slot_full[i] = full
			var sb := UiKit.box(Color.WHITE if full else Color(1, 1, 1, 0.45), 11, Color(1, 1, 1, 0.9) if full else Color(0.47, 0.27, 0.12, 0.28), 2)
			sb.content_margin_left = 3
			sb.content_margin_right = 3
			sb.content_margin_top = 3
			sb.content_margin_bottom = 3
			_tray_slots[i].add_theme_stylebox_override("panel", sb)
		_tray_slots[i].modulate = Color(1, 1, 1, 0.25) if locked else Color.WHITE
		_tray_icons[i].visible = full
		if full and _tray_icons[i].kind != s.waiter.tray[i]:
			_tray_icons[i].kind = s.waiter.tray[i]
	var acts: Array[Dictionary] = []
	if not s.waiter.current.is_empty():
		acts.append(s.waiter.current)
	acts.append_array(s.waiter.queue)
	var sig := ""
	for a in acts:
		sig += "%s%s," % [a["type"], a["id"]]
	if sig != _queue_sig:
		_queue_sig = sig
		_queue_n = acts.size()
		for c in _queue_box.get_children():
			c.queue_free()
		for a in acts:
			# a station shows its icon, a table its number (1-6)
			var chip := PanelContainer.new()
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var station: bool = a["type"] == "station"
			var csb := UiKit.box(Color.WHITE if station else Palette.UI_AMBER, 7, Palette.UI_AMBER, 1 if station else 0)
			csb.content_margin_left = 2 if station else 6
			csb.content_margin_right = 2 if station else 6
			csb.content_margin_top = 1
			csb.content_margin_bottom = 1
			chip.add_theme_stylebox_override("panel", csb)
			if station:
				chip.add_child(Icon.make(STATION_ICONS[a["id"]], 16.0))
			else:
				chip.add_child(UiKit.label(str(int(a["id"]) + 1), 12, Color.WHITE))
			_queue_box.add_child(chip)
		_clear_btn.visible = _queue_n > 0


func _update_stations(s: TeaSim) -> void:
	var b := s.balance
	var tea_units: Array[Dictionary] = []
	var tea_count := 0
	for i in s.active_kettles():
		var k := s.kettles[i]
		match k.state:
			"brewing":
				tea_units.append({"state": "progress", "frac": k.t / b.brew_time})
			"ready":
				tea_units.append({"state": "ready", "frac": 1.0})
				tea_count += k.n
			_:
				tea_units.append({"state": "empty", "frac": 0.0})
	# day 1: the tea station pulses until the first brew starts
	var tea_btn := _stations["tea"] as StationButton
	tea_btn.hint = GameState.day == 1 and not GameState.won and s.clock < 40.0 and s.kettles[0].state == "empty" \
		and s.waiter.queue.is_empty() and s.waiter.current.is_empty()
	tea_btn.set_info(false, tea_units, tea_count, false)
	var oven_units: Array[Dictionary] = []
	match s.oven.state:
		"baking":
			oven_units.append({"state": "progress", "frac": s.oven.t / s.oven_time()})
		"ready":
			oven_units.append({"state": "ready", "frac": 1.0})
		_:
			oven_units.append({"state": "empty", "frac": 0.0})
	(_stations["simit"] as StationButton).set_info(s.station_locked("simit"), oven_units, s.oven.n if s.oven.state == "ready" else 0, false)
	var pot_units: Array[Dictionary] = []
	var any_late := false
	var pot_count := 0
	for p in s.pots:
		match p.state:
			"cook":
				pot_units.append({"state": "progress", "frac": p.t / b.cook_time})
			"ready":
				var late := p.t > b.cook_window * 0.55
				pot_units.append({"state": "warn" if late else "ready", "frac": 1.0})
				any_late = any_late or late
				pot_count += 1
			"spilled":
				pot_units.append({"state": "bad", "frac": 1.0})
			_:
				pot_units.append({"state": "empty", "frac": 0.0})
	(_stations["coffee"] as StationButton).set_info(s.station_locked("coffee"), pot_units, pot_count, any_late)
	(_stations["ayran"] as StationButton).set_info(s.station_locked("ayran"), [], 0, false)
	var dirty := 0
	for it in s.waiter.tray:
		if it == "dirty":
			dirty += 1
	(_stations["sink"] as StationButton).set_info(false, [], dirty, false)


func _update_bubbles(s: TeaSim) -> void:
	# a party that left angry is no longer the table's party: its bubble stays up while the anger flash lasts
	var angry_at: Array[bool] = [false, false, false, false, false, false]
	for p in s.parties:
		if p.state == "leave" and p.persons[0].mood < 0 and p.persons[0].flash > 0.35:
			angry_at[p.table] = true
	for tb in s.tables:
		var bub := _bubbles[tb.index]
		var dirty_bub := _dirty_bubbles[tb.index]
		if not tb.unlocked:
			bub.clear()
			dirty_bub.clear()
			continue
		var p := tb.party
		if p == null and angry_at[tb.index]:
			bub.show_mini("angry")
			_place(bub, Vector3(tb.pos.x, 2.55, tb.pos.y))
		elif p == null:
			bub.clear()
		if p == null:
			if tb.dirty:
				dirty_bub.show_mini("dirty")
				_place(dirty_bub, Vector3(tb.pos.x, 1.7 + 0.1 * sin(Time.get_ticks_msec() / 160.0), tb.pos.y))
			else:
				dirty_bub.clear()
			continue
		dirty_bub.clear()
		var avatar: String = AVATARS.get(p.kind, "person")
		match p.state:
			"think":
				bub.show_think(avatar)
			"wait":
				bub.show_order(avatar, p.order, clampf(p.patience / p.max_patience, 0.0, 1.0))
			"eat":
				bub.show_mini("happy")
			_:
				bub.clear()
		if bub.visible:
			_place(bub, Vector3(tb.pos.x, 2.55, tb.pos.y))


func _place(bub: OrderBubble, world_pos: Vector3) -> void:
	if world == null or world.is_behind(world_pos):
		return
	var sp := world.to_screen(world_pos)
	var portrait := _root.size.x < _root.size.y
	bub.scale = Vector2.ONE * (0.78 if portrait else 1.0)
	bub.position = sp - Vector2(bub.size.x * 0.5, bub.size.y + 8.0)


func _update_floats(delta: float) -> void:
	var i := _floats.size() - 1
	while i >= 0:
		var f := _floats[i]
		f["age"] = float(f["age"]) + delta
		var age: float = f["age"]
		var node: Label = f["node"]
		if age >= 1.3:
			node.queue_free()
			_floats.remove_at(i)
		elif world != null:
			var sp := world.to_screen(f["pos"])
			var rise := 56.0 * (age / 1.3)
			node.position = sp - Vector2(node.size.x * 0.5, rise)
			var fade := 1.0 if age < 0.8 else 1.0 - (age - 0.8) / 0.5
			var pop := 0.6 + minf(age / 0.2, 1.0) * 0.55 if age < 0.2 else 1.15 - minf((age - 0.2) / 0.3, 1.0) * 0.15
			node.modulate.a = clampf(fade, 0.0, 1.0)
			node.scale = Vector2(pop, pop)
		i -= 1
