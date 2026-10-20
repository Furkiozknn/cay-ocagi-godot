extends Node
## Drives the real main scene with synthetic input (keys, mouse clicks, settings) and prints
## "UI SMOKE PASSED n/n" or "UI SMOKE FAILED k/n". Run with:
## godot_console --headless --path . --scene res://tests/ui_smoke.tscn

var _total := 0
var _failed := 0
var _main: Node
var _world: WorldView
var _hud: Hud
var _screens: Screens


func check(cond: bool, message: String) -> void:
	_total += 1
	if not cond:
		_failed += 1
		print("  FAIL: ", message)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func key(code: Key, pressed: bool = true) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func click(pos: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = pos
		ev.global_position = pos
		ev.button_index = button
		ev.pressed = pressed
		ev.button_mask = (1 << (button - 1)) if pressed else 0
		Input.parse_input_event(ev)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	GameState.save_path = "user://ui_smoke_save.json"
	var old_lang := Settings.lang
	var old_quality := Settings.quality
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	await frames(6)
	_world = _main.get_node("World") as WorldView
	_hud = _main.get_node("Hud") as Hud
	_screens = _main.get_node("Screens") as Screens

	check(GameState.phase == "title", "starts on the title")
	check(_screens.current() == "title", "title card is shown")
	check(GameState.demo and GameState.sim != null, "demo day runs behind the title")

	# language switch rebuilds the card
	Settings.set_language("en")
	await frames(3)
	check(Loc.t("play") == "Start game", "language switched to English")
	Settings.set_language("tr")
	await frames(3)

	# settings screen and back
	_screens.open_settings("title")
	await frames(3)
	check(_screens.current() == "settings", "settings opens")
	Settings.set_volume("music", 0.3)
	Settings.set_quality("low")
	await frames(2)
	check(not _world.sun.shadow_enabled, "low quality turns the shadows off")
	Settings.set_quality("high")
	await frames(2)
	check(_world.sun.shadow_enabled, "high quality turns them back on")
	_screens.close_settings()
	await frames(2)
	check(_screens.current() == "title", "back returns to the title")

	# start a game and play the first day by hand
	GameState.start_new()
	await frames(3)
	check(GameState.phase == "intro" and _screens.current() == "intro", "intro card")
	GameState.begin_day()
	await frames(3)
	check(GameState.phase == "play" and not _screens.is_open(), "play hides the cards")
	var sim := GameState.sim
	key(KEY_1)
	await frames(2)
	check(sim.waiter.queue.size() + (0 if sim.waiter.current.is_empty() else 1) == 1, "key 1 queues the tea station")
	# click table 0 with the mouse
	var cam := _world.rig.cam
	var tpos := cam.unproject_position(Vector3(TeaSim.TABLE_POS[0].x, 1.0, TeaSim.TABLE_POS[0].y))
	click(tpos)
	await frames(2)
	var queued := sim.waiter.queue.size() + (0 if sim.waiter.current.is_empty() else 1)
	check(queued == 2, "clicking a table queues it (queue is %d)" % queued)
	key(KEY_ESCAPE)
	await frames(2)
	check(sim.waiter.queue.is_empty(), "escape clears the queue")
	# right click also clears
	key(KEY_2)
	await frames(1)
	click(Vector2(5, 400), MOUSE_BUTTON_RIGHT)
	await frames(2)
	check(sim.waiter.queue.is_empty(), "right click clears the queue")

	# keyboard table selection: E moves the ring, Enter serves
	key(KEY_E, false)
	key(KEY_E)
	await frames(2)
	check(_world.hover_kind == "table" and _world.hover_id >= 0, "E selects a table")
	key(KEY_ENTER)
	await frames(2)
	check(sim.waiter.queue.size() + (0 if sim.waiter.current.is_empty() else 1) >= 1, "Enter queues the selected table")
	sim.clear_queue()

	# HUD reads the sim
	sim.waiter.tray.append("tea")
	await frames(3)
	check(is_instance_valid(_hud), "HUD alive while playing")

	# pause / resume
	key(KEY_SPACE)
	await frames(2)
	check(GameState.paused and _screens.current() == "pause", "space pauses and shows the pause card")
	var clock := sim.clock
	await frames(10)
	check(sim.clock == clock, "paused time does not advance")
	key(KEY_SPACE)
	await frames(2)
	check(not GameState.paused and not _screens.is_open(), "space resumes")

	# settings from the HUD while playing
	_hud.settings_requested.emit()
	await frames(3)
	check(GameState.paused and _screens.current() == "settings", "gear opens settings over a paused game")
	_screens.close_settings()
	await frames(2)
	check(_screens.current() == "pause", "back from settings returns to the pause card")
	GameState.toggle_pause()
	await frames(2)

	# zoom with the wheel
	var z0 := _world.rig.zoom_goal
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = Vector2(400, 300)
	Input.parse_input_event(wheel)
	await frames(2)
	check(_world.rig.zoom_goal > z0, "mouse wheel zooms in")

	# let the day finish quickly and walk through summary and shop
	GameState.up["tray"] = 1
	GameState.fast_forward(200.0)
	await frames(3)
	check(GameState.phase == "summary" or GameState.phase == "gameover", "day ended (%s)" % GameState.phase)
	if GameState.phase == "gameover":
		GameState.retry_day()
		GameState.begin_day()
		GameState.coins = 500
		GameState.sim.day_coins = 500
		GameState.fast_forward(200.0)
	await frames(3)
	check(_screens.current() == "summary", "summary card")
	GameState.after_summary()
	await frames(3)
	check(GameState.phase == "shop" and _screens.current() == "shop", "shop card")
	GameState.coins = 500
	var tables_before := GameState.sim.table_count()
	check(GameState.buy("table"), "buying a table works")
	await frames(3)
	check(GameState.sim.table_count() == tables_before + 1, "new sim has the extra table")
	GameState.next_day()
	await frames(3)
	check(GameState.phase == "intro", "next day shows the intro")
	GameState.to_menu()
	await frames(3)
	check(GameState.phase == "title" and _screens.current() == "title", "back to the title")

	var line := "UI SMOKE PASSED %d/%d" % [_total, _total]
	if _failed > 0:
		line = "UI SMOKE FAILED %d/%d" % [_failed, _total]
	Settings.lang = old_lang
	Settings.quality = old_quality
	Settings.save()
	if FileAccess.file_exists(GameState.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	print(line)
	get_tree().quit(1 if _failed > 0 else 0)
