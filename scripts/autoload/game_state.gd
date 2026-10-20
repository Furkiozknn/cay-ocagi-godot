extends Node
## Run progress (day, coins, upgrades), the phase machine (title, intro, play, summary,
## shop, gameover, victory), saving, the `--auto` self-player and the JSON state dump.

signal phase_changed(phase: String)
signal sim_created(sim: TeaSim)
signal progress_changed
signal paused_changed(paused: bool)
signal speed_changed(speed: int)

const DEFAULT_SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1
const STEP := 1.0 / 60.0
const MAX_STEPS_PER_FRAME := 240

var phase := "title"
var day := 1
var coins := 0
var total_earned := 0
var up: Dictionary = GameData.empty_upgrades()
var day_log: Array[Dictionary] = []
var won := false
var endless := false
## Set after a failed day: the shop's button retries the same day instead of moving on.
var retrying := false
## True when the day that just ended set a new best result (summary / game over / victory badge).
var new_record := false
var paused := false
var speed := 1
var sim: TeaSim = null
var last_result: Dictionary = {}
var best := {"day": 0, "total": 0}
## True while the title screen shows a self-playing demo day behind the menu.
var demo := false
## Tests point this at a throw-away file so they never touch a real save.
var save_path := DEFAULT_SAVE_PATH
## --no-save: nothing is read from or written to disk (tests, screenshots).
var no_save := false

# command line flags (everything after `--` on the godot command line)
var auto := false
var arg_seed := 0
var arg_day := 0
var arg_stop := ""
var arg_stop_day := 0
var arg_sim := 0.0
var arg_speed := 0
var arg_skill := 1.0
var arg_open := ""
var arg_quit_on_finish := false
var halted := false

var _snap: Dictionary = {}
var _resume := "intro"
var _acc := 0.0
var _bot := AutoBot.new()
var _demo_bot := AutoBot.new()
var _auto_timer := 0.0
var _auto_shopped := false
var _auto_retries := 0
var _auto_total_retries := 0
var _auto_done := false
var _auto_started_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_args()
	_load_best()
	Settings.apply_window()
	_auto_started_ms = Time.get_ticks_msec()
	if auto:
		_bot = AutoBot.new(arg_seed)
		_bot.skill = arg_skill
	_start_demo()


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		var key := kv[0]
		var val := kv[1] if kv.size() > 1 else ""
		match key:
			"--auto":
				auto = true
				save_path = "user://auto_save.json"
			"--seed":
				arg_seed = int(val)
			"--day":
				arg_day = clampi(int(val), 1, 99)
			"--speed":
				arg_speed = clampi(int(val), 1, 600)
			"--lang":
				if val == "en" or val == "tr":
					Settings.lang = val
			"--low":
				Settings.quality = "low"
			"--stop":
				var parts := val.split(":")
				arg_stop = parts[0]
				arg_stop_day = int(parts[1]) if parts.size() > 1 else 0
			"--sim":
				arg_sim = float(val)
			"--save":
				save_path = "user://%s.json" % val
			"--no-save":
				no_save = true
			"--skill":
				arg_skill = clampf(float(val), 0.1, 2.0)
			"--open":
				arg_open = val
			"--quit-on-finish":
				arg_quit_on_finish = true
	if arg_speed > 0:
		speed = arg_speed
	elif auto:
		speed = 3


# ---- frame loop ------------------------------------------------------------

func _process(delta: float) -> void:
	if halted:
		return
	if auto:
		_auto_update(delta)
	if phase == "play" and sim != null and not paused:
		_run_sim(delta * speed, _bot if auto else null)
	elif demo and sim != null:
		_run_sim(delta * 1.5, _demo_bot)
		if sim.finished:
			_start_demo()


func _run_sim(game_dt: float, bot: AutoBot) -> void:
	_acc += game_dt
	var steps := 0
	while _acc >= STEP and steps < MAX_STEPS_PER_FRAME:
		_acc -= STEP
		steps += 1
		if bot != null:
			bot.update(sim, STEP)
		sim.step(STEP)
		if sim.finished:
			break
	if steps >= MAX_STEPS_PER_FRAME:
		_acc = 0.0
	if sim.finished and phase == "play":
		_end_day()


## Runs the current day without rendering (used by --sim and tests).
func fast_forward(seconds: float) -> void:
	if sim == null or phase != "play":
		return
	Sfx.silent = true
	var n := int(seconds / STEP)
	for i in n:
		if _bot != null and auto:
			_bot.update(sim, STEP)
		sim.step(STEP)
		if sim.finished:
			_end_day()
			break
	Sfx.silent = false


# ---- demo behind the title -------------------------------------------------

func _start_demo() -> void:
	demo = true
	_acc = 0.0
	sim = TeaSim.new(4, {"tray": 1, "table": 1, "kettle": 1, "oven": 1}, 0)
	sim.sfx.connect(_on_sim_sfx)
	sim.clock = 10.0
	_demo_bot = AutoBot.new()
	for i in 1800:
		_demo_bot.update(sim, STEP)
		sim.step(STEP)
	sim_created.emit(sim)


func _on_sim_sfx(sound: String) -> void:
	if phase == "play" and not demo and not paused:
		Sfx.play(sound)


func _stop_demo() -> void:
	demo = false


# ---- phases ----------------------------------------------------------------

func _set_phase(p: String) -> void:
	phase = p
	if p != "play":
		paused = false
	phase_changed.emit(p)
	_check_stop()


func _check_stop() -> void:
	if arg_stop != "" and phase == arg_stop and (arg_stop_day == 0 or arg_stop_day == day):
		halted = true


func _new_sim(for_day: int, play_seed: int = 0) -> void:
	_acc = 0.0
	sim = TeaSim.new(for_day, up, play_seed)
	sim.sfx.connect(_on_sim_sfx)
	sim_created.emit(sim)


func start_new() -> void:
	_stop_demo()
	won = false
	endless = false
	retrying = false
	new_record = false
	up = GameData.empty_upgrades()
	day_log.clear()
	total_earned = 0
	day = maxi(arg_day, 1)
	coins = GameData.balance().skip_day_coins * (day - 1)
	_auto_shopped = false
	_auto_retries = 0
	_enter_intro()


func continue_game() -> bool:
	if not load_progress():
		return false
	_stop_demo()
	_new_sim(day)
	if _resume == "shop":
		if day == GameData.balance().win_day and not won and not retrying:
			after_summary()
		else:
			go_shop()
	else:
		_enter_intro()
	return true


func _enter_intro() -> void:
	_new_sim(day)
	_snap = {"coins": coins, "up": up.duplicate(), "total": total_earned}
	save_progress()
	_set_phase("intro")


func begin_day() -> void:
	_new_sim(day, arg_seed + day * 7919 if arg_seed != 0 else 0)
	paused = false
	new_record = false
	_set_phase("play")
	if arg_sim > 0.0:
		var s := arg_sim
		arg_sim = 0.0
		fast_forward(s)


func _end_day() -> void:
	var stars := sim.stars()
	var passed := stars > 0
	last_result = {
		"day": day, "coins": sim.day_coins, "target": sim.target, "tips": sim.day_tips, "happy": sim.happy,
		"angry": sim.angry, "stars": stars, "passed": passed, "served": sim.served, "spawned": sim.spawn_count,
		"walked_by": sim.walkby,
	}
	# failed-day rule (same as the browser version): the coins of a failed day are kept too, and the retry goes
	# through the shop, so the player can buy an upgrade before trying the same day again
	coins += sim.day_coins
	total_earned += sim.day_coins
	day_log.append(last_result)
	var reached := day if passed else day - 1
	# no record for a run that earned nothing or started on a later day (--day)
	new_record = reached > 0 and total_earned > 0 and arg_day <= 1 and (reached > int(best["day"]) or (reached == int(best["day"]) and total_earned > int(best["total"])))
	if new_record:
		best = {"day": reached, "total": total_earned}
		_save_best_only()
	if passed:
		retrying = false
		Sfx.play("fanfare")
		save_progress("shop")
		_set_phase("summary")
	else:
		retrying = true
		Sfx.play("lose")
		save_progress("shop")
		_set_phase("gameover")


func after_summary() -> void:
	if day == GameData.balance().win_day and not won:
		won = true
		endless = true
		save_progress("shop")
		Sfx.play("fanfare")
		_set_phase("victory")
	else:
		go_shop()


func go_shop() -> void:
	_new_sim(day)
	save_progress("shop")
	_set_phase("shop")


func upgrade_cost(id: String) -> int:
	var u := GameData.upgrade(id)
	var lv: int = up[id]
	return u.costs[lv] if lv < u.max_level else -1


func can_buy(id: String) -> bool:
	var c := upgrade_cost(id)
	return c >= 0 and coins >= c


func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	coins -= upgrade_cost(id)
	up[id] = int(up[id]) + 1
	Sfx.play("cash")
	_new_sim(day)
	save_progress("shop")
	progress_changed.emit()
	return true


## The shop's main button: the next day, or the same day again after a failed one.
func next_day() -> void:
	if retrying:
		retrying = false
	else:
		day += 1
		_auto_retries = 0
	_enter_intro()


## Game over → "Shop & retry": keep the coins, visit the shop, then play the same day again.
func retry_via_shop() -> void:
	retrying = true
	go_shop()


## Pause menu → "Restart the day": back to the coins and upgrades the day began with, then straight into play.
func restart_day() -> void:
	if phase != "play":
		return
	if not _snap.is_empty():
		coins = int(_snap["coins"])
		up = (_snap["up"] as Dictionary).duplicate()
		total_earned = int(_snap["total"])
	begin_day()


func go_endless() -> void:
	endless = true
	go_shop()


func to_menu() -> void:
	endless = false
	won = false
	retrying = false
	new_record = false
	_start_demo()
	_set_phase("title")


func toggle_pause() -> void:
	if phase != "play":
		return
	paused = not paused
	Sfx.play("click")
	paused_changed.emit(paused)


func set_paused(p: bool) -> void:
	if phase == "play" and paused != p:
		paused = p
		paused_changed.emit(paused)


func toggle_speed() -> void:
	speed = 1 if speed >= 3 else speed + 1
	speed_changed.emit(speed)


## Banked coins plus what the running day has earned (the HUD shows only the day's coins).
func live_coins() -> int:
	return coins + (sim.day_coins if sim != null and phase == "play" else 0)


# ---- save / load -----------------------------------------------------------

func has_save() -> bool:
	if no_save or not FileAccess.file_exists(save_path):
		return false
	var d := _read_save()
	return d.has("progress") and d["progress"] is Dictionary


func _read_save() -> Dictionary:
	if no_save:
		return {}
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


func _write_save(data: Dictionary) -> void:
	if no_save:
		return
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save file")
		return
	f.store_string(JSON.stringify(data))


## `resume` says which screen Continue should open: "intro" (start of a day) or "shop".
func save_progress(resume: String = "intro") -> void:
	var d := _read_save()
	d["version"] = SAVE_VERSION
	d["best"] = best
	d["progress"] = {
		"day": day, "coins": coins, "total_earned": total_earned, "up": up, "won": won, "endless": endless,
		"log": day_log, "resume": resume, "retrying": retrying,
	}
	_write_save(d)


func _save_best_only() -> void:
	var d := _read_save()
	d["version"] = SAVE_VERSION
	d["best"] = best
	_write_save(d)


func _load_best() -> void:
	var d := _read_save()
	if d.has("best") and d["best"] is Dictionary:
		best = {"day": int(d["best"].get("day", 0)), "total": int(d["best"].get("total", 0))}


func load_progress() -> bool:
	var d := _read_save()
	if not d.has("progress") or not d["progress"] is Dictionary:
		return false
	var p: Dictionary = d["progress"]
	day = clampi(int(p.get("day", 1)), 1, 99)
	coins = maxi(int(p.get("coins", 0)), 0)
	total_earned = maxi(int(p.get("total_earned", 0)), 0)
	_resume = str(p.get("resume", "intro"))
	won = bool(p.get("won", false))
	endless = bool(p.get("endless", false))
	retrying = bool(p.get("retrying", false))
	new_record = false
	up = GameData.empty_upgrades()
	var saved_up: Dictionary = p.get("up", {})
	for id in GameData.UPGRADE_IDS:
		var u := GameData.upgrade(id)
		up[id] = clampi(int(saved_up.get(id, 0)), 0, u.max_level)
	day_log.clear()
	for r in p.get("log", []):
		if r is Dictionary:
			day_log.append(r)
	return true


func delete_save() -> void:
	if FileAccess.file_exists(save_path):
		var d := _read_save()
		d.erase("progress")
		_write_save(d)


# ---- state dump ------------------------------------------------------------

func get_state_text() -> String:
	var d := {
		"phase": phase, "lang": Settings.lang, "day": day, "coins": coins, "live_coins": live_coins(),
		"total_earned": total_earned, "upgrades": up, "paused": paused, "speed": speed, "auto": auto,
		"won": won, "endless": endless, "retrying": retrying, "new_record": new_record, "demo": demo, "best": best, "last_result": last_result,
		"days_log": day_log.map(func(r: Dictionary) -> String: return "d%d:%d/%d:%d*" % [r["day"], r["coins"], r["target"], r["stars"]]),
		"fps": Engine.get_frames_per_second(),
	}
	if sim != null:
		d["sim"] = sim.to_dict()
	return JSON.stringify(d)


# ---- the --auto self-player ------------------------------------------------

func _auto_update(delta: float) -> void:
	if _auto_done:
		return
	_auto_timer += delta
	match phase:
		"title":
			if _auto_timer > 0.5:
				start_new()
				_auto_timer = 0.0
		"intro":
			if day > 1 and not _auto_shopped:
				_auto_shopped = true
				_auto_buy_all()
			if _auto_timer > 0.8:
				begin_day()
				_auto_timer = 0.0
		"summary":
			if _auto_timer > 1.2:
				after_summary()
				_auto_timer = 0.0
		"shop":
			if _auto_timer > 0.6:
				var pick := _bot.shop_pick(up, coins)
				if pick != "":
					buy(pick)
					_auto_timer = 0.4
				else:
					next_day()
					_auto_timer = 0.0
		"victory":
			if _auto_timer > 2.0:
				_auto_report()
				if arg_quit_on_finish or DisplayServer.get_name() == "headless":
					_auto_done = true
					get_tree().quit(0)
					return
				go_endless()
				_auto_timer = 0.0
		"gameover":
			if _auto_timer > 2.0:
				if _auto_retries < 2:
					_auto_retries += 1
					_auto_total_retries += 1
					retry_via_shop()
					_auto_timer = 0.0
				else:
					_auto_report()
					_auto_done = true
					if arg_quit_on_finish or DisplayServer.get_name() == "headless":
						get_tree().quit(1)


func _auto_buy_all() -> void:
	var pick := _bot.shop_pick(up, coins)
	while pick != "":
		coins -= upgrade_cost(pick)
		up[pick] = int(up[pick]) + 1
		pick = _bot.shop_pick(up, coins)
	_new_sim(day)


func _auto_report() -> void:
	var cleared := 0
	var stars := 0
	var parts: Array[String] = []
	for r in day_log:
		if r["passed"]:
			cleared += 1
			stars += int(r["stars"])
		parts.append("d%d=%d/%d(%d*)" % [r["day"], r["coins"], r["target"], r["stars"]])
	print("AUTO RESULT: days_cleared=%d total_coins=%d stars=%d retries=%d reached_day=%d won=%s wall_seconds=%.1f" % [
		cleared, total_earned, stars, _auto_total_retries, day, str(won), (Time.get_ticks_msec() - _auto_started_ms) / 1000.0])
	print("AUTO DAYS: ", " ".join(parts))
