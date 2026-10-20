class_name StationButton
extends PanelContainer
## One dock button (tea, simit, coffee, ayran, sink) with progress units and a ready counter.

signal pressed(id: String)
signal hovered(id: String, on: bool)

const UNIT_COLORS := {
	"empty": Color(0.31, 0.16, 0.04, 0.0),
	"progress": Color("e8863d"),
	"ready": Color("3f8f4a"),
	"warn": Color("d4a017"),
	"bad": Color("c0392b"),
}

var station_id := ""
var _icon: Icon
var _name: Label
var _key: Label
var _count: Label
var _count_panel: PanelContainer
var _units: HBoxContainer
var _bars: Array[ProgressBar] = []
var _bar_states: Array[String] = []
var _hover := false
var _locked := false
var _pulse := 0.0
var _ready_flag := false
var _blink := false

static var _unit_styles: Dictionary = {}


func setup(id: String, key_text: String, icon_kind: String) -> void:
	station_id = id
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(70, 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key = UiKit.label(key_text, 10, Color.WHITE)
	var key_panel := PanelContainer.new()
	key_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ksb := UiKit.box(Palette.UI_INK_SOFT, 5)
	ksb.content_margin_left = 5
	ksb.content_margin_right = 5
	ksb.content_margin_top = 0
	ksb.content_margin_bottom = 0
	key_panel.add_theme_stylebox_override("panel", ksb)
	key_panel.add_child(_key)
	top.add_child(key_panel)
	top.add_child(UiKit.spacer(0, 0, true))
	_count_panel = PanelContainer.new()
	_count_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var csb := UiKit.box(Palette.UI_OK, 10)
	csb.content_margin_left = 5
	csb.content_margin_right = 5
	csb.content_margin_top = 0
	csb.content_margin_bottom = 0
	_count_panel.add_theme_stylebox_override("panel", csb)
	_count = UiKit.label("0", 12, Color.WHITE)
	_count_panel.add_child(_count)
	_count_panel.visible = false
	top.add_child(_count_panel)
	v.add_child(top)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon = Icon.make(icon_kind, 30.0)
	center.add_child(_icon)
	v.add_child(center)
	_name = UiKit.label("", 12)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_name)
	_units = HBoxContainer.new()
	_units.add_theme_constant_override("separation", 3)
	_units.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_units.custom_minimum_size = Vector2(0, 8)
	v.add_child(_units)
	mouse_entered.connect(func() -> void:
		_hover = true
		hovered.emit(station_id, true)
		_refresh_style())
	mouse_exited.connect(func() -> void:
		_hover = false
		hovered.emit(station_id, false)
		_refresh_style())
	_refresh_style()


func set_title(text: String) -> void:
	_name.text = text


func _unit_style(key: String) -> StyleBoxFlat:
	if not _unit_styles.has(key):
		_unit_styles[key] = UiKit.box(UNIT_COLORS[key], 5)
	return _unit_styles[key]


func _refresh_style() -> void:
	var bg := Color(1, 1, 1, 0.62)
	var border := Color(0, 0, 0, 0)
	if _hover and not _locked:
		bg = Color.WHITE
		border = Palette.UI_AMBER
	if _ready_flag and not _locked:
		border = Palette.UI_AMBER.lerp(Color(1, 0.7, 0.3), 0.5 + 0.5 * sin(_pulse * 6.0)) if not _hover else Palette.UI_AMBER
	var sb := UiKit.box(bg, 13, border, 2)
	sb.content_margin_top = 4
	sb.content_margin_bottom = 6
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	add_theme_stylebox_override("panel", sb)
	modulate = Color(1, 1, 1, 0.38) if _locked else Color.WHITE


## units: Array of {state: "empty"|"progress"|"ready"|"warn"|"bad", frac: float}
func set_info(locked: bool, units: Array[Dictionary], count: int, blink: bool) -> void:
	if locked != _locked:
		_locked = locked
		_refresh_style()
	while _bars.size() < units.size():
		var pb := UiKit.bar(Color("e8863d"), 10.0, 8.0)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_units.add_child(pb)
		_bars.append(pb)
		_bar_states.append("")
	var any_ready := false
	for i in _bars.size():
		var bar := _bars[i]
		bar.visible = i < units.size()
		if i >= units.size():
			continue
		var st: String = units[i]["state"]
		var frac: float = units[i]["frac"]
		bar.value = 1.0 if st == "ready" or st == "warn" or st == "bad" else frac
		if _bar_states[i] != st:
			_bar_states[i] = st
			bar.add_theme_stylebox_override("fill", _unit_style(st if st != "empty" else "progress"))
		any_ready = any_ready or st == "ready" or st == "warn"
	_blink = blink
	_units.visible = not units.is_empty()
	_count_panel.visible = count > 0
	_count.text = str(count)
	if any_ready != _ready_flag:
		_ready_flag = any_ready
		_refresh_style()


func _process(delta: float) -> void:
	if _ready_flag:
		_pulse += delta
		_refresh_style()
	if _blink:
		_units.modulate.a = 0.35 if int(Time.get_ticks_msec() / 170.0) % 2 == 0 else 1.0
	elif _units.modulate.a != 1.0:
		_units.modulate.a = 1.0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _locked:
			Sfx.play("tick")
		pressed.emit(station_id)
		accept_event()
