extends Node
## Wires the world, HUD and screens together and turns raw input into game commands.

const DRAG_THRESHOLD := 9.0

var _press_pos := Vector2.ZERO
var _pressing := false
var _dragging := false
var _touches: Dictionary = {}
var _sel_table := -1
var _pinch_start := 0.0
var _pinch_zoom := 1.0

@onready var world: WorldView = $World
@onready var hud: Hud = $Hud
@onready var screens: Screens = $Screens


func _ready() -> void:
	hud.world = world
	hud.settings_requested.connect(_open_settings_from_hud)
	hud.pause_requested.connect(GameState.toggle_pause)
	get_window().size_changed.connect(_update_ui_scale)
	_update_ui_scale()
	get_window().title = "Çay Ocağı"
	RenderingServer.set_default_clear_color(Color("f3b274"))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--zoom="):
			world.rig.zoom_goal = clampf(float(a.substr(7)), CameraRig.ZOOM_MIN, CameraRig.ZOOM_MAX)
		elif a.begins_with("--pan="):
			var xy := a.substr(6).split(",")
			if xy.size() == 2:
				world.rig.pan_goal = Vector2(float(xy[0]), float(xy[1]))
	if GameState.arg_open != "":
		_open_menu_arg.call_deferred()


## Developer flag: --open=settings|pause|settings-pause jumps straight to a menu (for screenshots).
func _open_menu_arg() -> void:
	match GameState.arg_open:
		"settings":
			screens.open_settings("title")
		"pause", "settings-pause":
			GameState.start_new()
			GameState.begin_day()
			GameState.set_paused(true)
			if GameState.arg_open == "settings-pause":
				screens.open_settings("pause")


func _update_ui_scale() -> void:
	var win := get_window()
	var s := Vector2(win.size)
	var f := 1.0
	if s.x < s.y:
		f = clampf(s.x / 460.0, 0.7, 2.5)
	else:
		f = clampf(minf(s.x / 1150.0, s.y / 670.0), 0.8, 2.5)
	win.content_scale_factor = f


func _open_settings_from_hud() -> void:
	GameState.set_paused(true)
	screens.open_settings("pause")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and GameState.phase == "play" and not GameState.auto:
		GameState.set_paused(true)


func _unhandled_input(event: InputEvent) -> void:
	var playing := GameState.phase == "play" and GameState.sim != null
	if event.is_action_pressed("pause") and GameState.phase == "play":
		GameState.toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("clear_queue"):
		if screens.current() == "settings":
			screens.close_settings()
		elif playing and GameState.paused:
			GameState.toggle_pause()
		elif playing:
			GameState.sim.clear_queue()
		return
	if not playing or GameState.paused:
		return
	if event.is_action_pressed("speed_toggle"):
		GameState.toggle_speed()
		return
	for i in 5:
		if event.is_action_pressed("station_%d" % (i + 1)):
			GameState.sim.click_station(TeaSim.STATION_IDS[i])
			return
	if event.is_action_pressed("table_next"):
		_cycle_table(1)
	elif event.is_action_pressed("table_prev"):
		_cycle_table(-1)
	elif event.is_action_pressed("table_serve"):
		if _sel_table >= 0:
			GameState.sim.click_table(_sel_table)
	elif event.is_action_pressed("zoom_in"):
		world.rig.zoom_by(1.12)
	elif event.is_action_pressed("zoom_out"):
		world.rig.zoom_by(1.0 / 1.12)
	elif event is InputEventMagnifyGesture:
		world.rig.zoom_by((event as InputEventMagnifyGesture).factor)
	elif event is InputEventScreenTouch:
		_handle_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_touch_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_dragging = false
			_press_pos = event.position
		else:
			if _pressing and not _dragging and _touches.size() < 2:
				_pick(event.position)
			_pressing = false
			_dragging = false
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _pressing and _touches.size() < 2:
			if not _dragging and mm.position.distance_to(_press_pos) > DRAG_THRESHOLD:
				_dragging = true
			if _dragging:
				world.rig.pan_by_pixels(mm.relative)
		elif not _pressing:
			var hit := world.pick_at(mm.position)
			world.set_hover(hit.get("kind", ""), hit.get("id", -1))


## Keyboard / gamepad table selection: Q / E (or d-pad left / right) move the ring, Enter serves.
func _cycle_table(step: int) -> void:
	var open: Array[int] = []
	for tb in GameState.sim.tables:
		if tb.unlocked:
			open.append(tb.index)
	if open.is_empty():
		return
	var at := open.find(_sel_table)
	at = 0 if at < 0 else posmod(at + step, open.size())
	_sel_table = open[at]
	world.set_hover("table", _sel_table)
	Sfx.play("tick")


func _pick(pos: Vector2) -> void:
	var hit := world.pick_at(pos)
	if hit.is_empty():
		return
	match hit["kind"]:
		"station":
			GameState.sim.click_station(hit["id"])
		"table":
			GameState.sim.click_table(hit["id"])
		"cat":
			world.pet_cat()


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
		if _touches.size() == 2:
			_pinch_start = _pinch_distance()
			_pinch_zoom = world.rig.zoom_goal
			_dragging = true
	else:
		_touches.erase(event.index)


func _handle_touch_drag(event: InputEventScreenDrag) -> void:
	_touches[event.index] = event.position
	if _touches.size() == 2 and _pinch_start > 1.0:
		world.rig.zoom_goal = clampf(_pinch_zoom * _pinch_distance() / _pinch_start, CameraRig.ZOOM_MIN, CameraRig.ZOOM_MAX)


func _pinch_distance() -> float:
	var pts: Array = _touches.values()
	return (pts[0] as Vector2).distance_to(pts[1] as Vector2)
