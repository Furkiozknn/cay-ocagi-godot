extends Node
## Headless unit tests for the core rules. Prints one final line "TESTS PASSED n/n" or
## "TESTS FAILED k/n" and exits with code 0 or 1.
## godot_console --headless --path . --scene res://tests/run_tests.tscn

var _total := 0
var _failed := 0


func check(cond: bool, message: String) -> void:
	_total += 1
	if not cond:
		_failed += 1
		print("  FAIL: ", message)


func eq(actual: Variant, expected: Variant, message: String) -> void:
	_total += 1
	if actual != expected:
		_failed += 1
		print("  FAIL: %s (got %s, expected %s)" % [message, str(actual), str(expected)])


func _ready() -> void:
	GameState.save_path = "user://test_save.json"
	for method in get_method_list():
		var n: String = method["name"]
		if n.begins_with("test_"):
			print("- ", n)
			call(n)
	var line := "TESTS PASSED %d/%d" % [_total, _total]
	if _failed > 0:
		line = "TESTS FAILED %d/%d" % [_failed, _total]
	if FileAccess.file_exists(GameState.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GameState.save_path))
	print(line)
	get_tree().quit(1 if _failed > 0 else 0)


# ---- helpers ---------------------------------------------------------------

func make_sim(day: int = 1, up: Dictionary = {}, seed_value: int = 1) -> TeaSim:
	return TeaSim.new(day, up, seed_value)


func run(sim: TeaSim, seconds: float) -> void:
	for i in int(seconds * 60.0):
		sim.step(1.0 / 60.0)


## Gives the waiter orders and runs until the queue is empty.
func do_clicks(sim: TeaSim) -> void:
	var guard := 0
	while (not sim.waiter.queue.is_empty() or not sim.waiter.current.is_empty()) and guard < 3000:
		sim.step(1.0 / 60.0)
		guard += 1


# ---- data ------------------------------------------------------------------

func test_data_loads() -> void:
	eq(GameData.ITEM_IDS.size(), 4, "four menu items")
	for id in GameData.ITEM_IDS:
		check(GameData.item(id) != null and GameData.item(id).price > 0, "item %s has a price" % id)
	eq(GameData.item("coffee").price, 8, "coffee costs 8")
	eq(GameData.customer("group").party_size, 3, "group has three people")
	for d in range(1, 8):
		check(GameData.day_config(d) != null, "day %d exists" % d)
	eq(GameData.day_config(1).menu.size(), 1, "day 1 only tea")
	eq(GameData.day_config(4).menu.size(), 4, "day 4 full menu")
	eq(GameData.day_config(7).target, 250, "day 7 target")


func test_endless_days_scale() -> void:
	var d8 := GameData.day_config(8)
	var d12 := GameData.day_config(12)
	check(d12.target > d8.target, "endless targets grow")
	check(d12.spawn_gap <= d8.spawn_gap, "endless gaps shrink")
	check(d12.spawn_gap >= GameData.balance().endless_gap_min, "gap never below the floor")


func test_localisation_tables_match() -> void:
	for key in Loc.TR:
		check(Loc.EN.has(key), "EN has key %s" % key)
	for key in Loc.EN:
		check(Loc.TR.has(key), "TR has key %s" % key)
	Settings.lang = "tr"
	eq(Loc.t("best", [3, 120]), "En iyi: Gün 3 · 120 altın", "Turkish format args")
	Settings.lang = "en"
	eq(Loc.t("best", [3, 120]), "Best: Day 3 · 120 coins", "English format args")
	eq(Loc.t("no_such_key"), "no_such_key", "unknown key falls back to itself")
	Settings.lang = "tr"


# ---- rules -----------------------------------------------------------------

func test_star_rating() -> void:
	eq(TeaSim.rating_stars(64, 65, 10, 0), 0, "below target fails")
	eq(TeaSim.rating_stars(65, 65, 10, 0), 1, "target reached is one star")
	eq(TeaSim.rating_stars(82, 65, 10, 0), 2, "125% with happy guests is two stars")
	eq(TeaSim.rating_stars(82, 65, 5, 5), 1, "125% with many angry guests stays at one")
	eq(TeaSim.rating_stars(98, 65, 10, 0), 3, "150% with happy guests is three stars")
	eq(TeaSim.rating_stars(98, 65, 9, 3), 2, "150% but ratio below 88% is two stars")


func test_upgrade_effects() -> void:
	var base := make_sim(1, {})
	eq(base.tray_cap(), 3, "tray holds 3")
	eq(base.table_count(), 3, "3 tables")
	eq(base.active_kettles(), 1, "one kettle")
	check(is_equal_approx(base.stool_mul(), 1.0), "no stool bonus")
	var maxed := make_sim(1, {"tray": 2, "table": 3, "kettle": 1, "oven": 2, "stool": 2})
	eq(maxed.tray_cap(), 5, "tray holds 5")
	eq(maxed.table_count(), 6, "6 tables")
	eq(maxed.active_kettles(), 2, "two kettles")
	check(is_equal_approx(maxed.stool_mul(), 1.4), "stools give +40%")
	check(maxed.oven_time() < base.oven_time(), "faster oven")
	var unlocked := 0
	for tb in maxed.tables:
		unlocked += 1 if tb.unlocked else 0
	eq(unlocked, 6, "all tables unlocked")


func test_shop_rules() -> void:
	GameState.up = GameData.empty_upgrades()
	GameState.coins = 50
	check(GameState.can_buy("tray"), "can afford a 45 coin tray")
	check(not GameState.can_buy("kettle"), "cannot afford a 60 coin kettle")
	var ok := GameState.buy("tray")
	check(ok, "buying works")
	eq(GameState.coins, 5, "coins are spent")
	eq(GameState.up["tray"], 1, "level goes up")
	check(not GameState.buy("tray"), "second tray level costs 90")
	GameState.coins = 1000
	GameState.up["tray"] = 2
	check(not GameState.can_buy("tray"), "max level cannot be bought")
	eq(GameState.upgrade_cost("tray"), -1, "no cost at max level")
	GameState.up = GameData.empty_upgrades()
	GameState.coins = 0


func test_nav_grid() -> void:
	var nav := NavGrid.new(TeaSim.TABLE_POS)
	check(not nav.is_free(Vector2(-1.0, -0.5)), "table centre is solid")
	check(not nav.is_free(Vector2(-6.5, 0.0)), "counter side is solid")
	check(nav.is_free(Vector2(-5.1, 0.5)), "service lane is free")
	var path := nav.find_path(Vector2(-5.1, 0.5), Vector2(8.0, -3.0))
	check(not path.is_empty(), "path exists")
	eq(path[path.size() - 1], Vector2(8.0, -3.0), "path ends at the target")
	var prev := Vector2(-5.1, 0.5)
	var clear := true
	for p in path:
		clear = clear and nav.line_of_sight(prev, p)
		prev = p
	check(clear, "every path segment is walkable")


# ---- one day of service ----------------------------------------------------

func test_tea_brew_and_collect() -> void:
	var sim := make_sim()
	check(sim.click_station("tea"), "tea click queued")
	do_clicks(sim)
	eq(sim.kettles[0].state, "brewing", "kettle starts brewing")
	run(sim, sim.balance.brew_time + 0.5)
	eq(sim.kettles[0].state, "ready", "tea is ready after the brew time")
	eq(sim.kettles[0].n, sim.balance.tea_servings, "four glasses ready")
	sim.click_station("tea")
	do_clicks(sim)
	eq(sim.waiter.tray, ["tea"] as Array[String], "one tea on the tray")
	eq(sim.kettles[0].n, sim.balance.tea_servings - 1, "one glass taken")


func test_tray_capacity_and_drop() -> void:
	var sim := make_sim(4)
	for i in 5:
		sim.click_station("ayran")
		do_clicks(sim)
	eq(sim.waiter.tray.size(), 3, "tray stops at three items")
	sim.drop_tray(0)
	eq(sim.waiter.tray.size(), 2, "dropping frees a slot")


func test_locked_station_rejects_click() -> void:
	var sim := make_sim(1)
	check(sim.station_locked("coffee"), "coffee locked on day 1")
	check(not sim.click_station("coffee"), "locked click refused")
	eq(sim.waiter.queue.size(), 0, "nothing queued")


func test_queue_limit() -> void:
	var sim := make_sim(4)
	for i in 8:
		sim.click_station("ayran")
	eq(sim.waiter.queue.size(), TeaSim.MAX_QUEUE, "queue holds six orders")
	sim.clear_queue()
	eq(sim.waiter.queue.size(), 0, "clear empties the queue")


func test_coffee_boils_over() -> void:
	var sim := make_sim(4)
	sim.click_station("coffee")
	do_clicks(sim)
	eq(sim.pots[0].state, "cook", "coffee cooking")
	run(sim, sim.balance.cook_time + 0.3)
	eq(sim.pots[0].state, "ready", "coffee ready")
	run(sim, sim.balance.cook_window + 0.3)
	eq(sim.pots[0].state, "spilled", "ignored coffee boils over")
	sim.click_station("coffee")
	do_clicks(sim)
	eq(sim.pots[0].state, "empty", "spilled pot gets cleaned")


func test_simit_oven() -> void:
	var sim := make_sim(2)
	sim.click_station("simit")
	do_clicks(sim)
	eq(sim.oven.state, "baking", "oven heats")
	run(sim, sim.oven_time() + 0.3)
	eq(sim.oven.state, "ready", "simit ready")
	eq(sim.oven.n, sim.balance.oven_servings, "three simit ready")


func test_customer_lifecycle_and_payment() -> void:
	var sim := make_sim(1, {}, 3)
	# run until the first customer waits
	var guard := 0
	while guard < 60 * 60:
		sim.step(1.0 / 60.0)
		guard += 1
		if not sim.parties.is_empty() and sim.parties[0].state == "wait":
			break
	check(not sim.parties.is_empty(), "a customer arrived")
	var party := sim.parties[0]
	eq(party.state, "wait", "customer sits down and orders")
	check(party.persons[0].sitting, "customer is seated")
	var teas := party.order.size()
	# brew and serve
	sim.click_station("tea")
	do_clicks(sim)
	run(sim, sim.balance.brew_time + 0.5)
	for i in teas:
		sim.click_station("tea")
	do_clicks(sim)
	sim.click_table(party.table)
	do_clicks(sim)
	eq(party.state, "eat", "fully served customer starts eating")
	var before := sim.day_coins
	run(sim, 12.0)
	check(sim.day_coins >= before + teas * 3, "payment at least covers the order")
	eq(sim.happy, 1, "one happy customer")


func test_impatient_customer_leaves_angry() -> void:
	var sim := make_sim(1, {}, 3)
	run(sim, 200.0)
	check(sim.angry > 0, "ignored customers leave angry")
	eq(sim.day_coins, 0, "no coins without service")


func test_wrong_item_is_refused() -> void:
	var sim := make_sim(4, {}, 3)
	var guard := 0
	while guard < 60 * 60:
		sim.step(1.0 / 60.0)
		guard += 1
		if not sim.parties.is_empty() and sim.parties[0].state == "wait":
			break
	var party := sim.parties[0]
	var wanted: Array[String] = party.unmet()
	var other := "ayran" if not wanted.has("ayran") else "tea"
	if other == "tea":
		return
	sim.click_station("ayran")
	do_clicks(sim)
	sim.click_table(party.table)
	do_clicks(sim)
	eq(party.unmet().size(), wanted.size(), "wrong item changes nothing")
	eq(sim.waiter.tray.size(), 1, "wrong item stays on the tray")


func test_dirty_table_washing() -> void:
	var sim := make_sim(4, {}, 4)
	var tb := sim.tables[0]
	tb.dirty = true
	tb.slots.append({"kind": "glass", "item": "tea", "dirty": true})
	sim.click_table(0)
	do_clicks(sim)
	check(sim.waiter.tray.has("dirty"), "dirty glasses picked up")
	check(not tb.dirty, "table is clear")
	sim.click_station("sink")
	do_clicks(sim)
	check(not sim.waiter.tray.has("dirty"), "glasses washed at the sink")


func test_apprentice_cleans_tables() -> void:
	var sim := make_sim(4, {"apprentice": 1}, 5)
	check(sim.apprentice != null, "apprentice hired")
	var tb := sim.tables[1]
	tb.dirty = true
	tb.slots.append({"kind": "glass", "item": "tea", "dirty": true})
	run(sim, 15.0)
	check(not tb.dirty, "apprentice cleared the table")


func test_day_ends_after_day_length() -> void:
	var sim := make_sim(1, {}, 7)
	var ended := [false]
	sim.day_ended.connect(func() -> void: ended[0] = true)
	run(sim, sim.day_len + 1.0)
	check(ended[0], "day_ended fired")
	check(sim.finished, "sim is finished")
	var clock := sim.clock
	sim.step(1.0)
	eq(sim.clock, clock, "finished sim stops advancing")


func test_same_seed_same_day() -> void:
	var a := make_sim(3, {"tray": 1}, 99)
	var b := make_sim(3, {"tray": 1}, 99)
	run(a, 60.0)
	run(b, 60.0)
	eq(a.spawn_count, b.spawn_count, "same spawn count")
	eq(JSON.stringify(a.to_dict()), JSON.stringify(b.to_dict()), "same state after 60 s")


# ---- bot, save and state text ----------------------------------------------

func test_bot_clears_day_one() -> void:
	var sim := make_sim(1, {}, 11)
	var bot := AutoBot.new(11)
	for i in int(sim.day_len * 60.0) + 60:
		bot.update(sim, 1.0 / 60.0)
		sim.step(1.0 / 60.0)
	check(sim.finished, "day finished")
	check(sim.stars() >= 1, "bot reaches the day 1 target (%d/%d)" % [sim.day_coins, sim.target])


func test_save_round_trip() -> void:
	GameState.day = 5
	GameState.coins = 321
	GameState.total_earned = 700
	GameState.up = GameData.empty_upgrades()
	GameState.up["tray"] = 2
	GameState.up["table"] = 1
	GameState.won = false
	GameState.day_log.clear()
	GameState.day_log.append({"day": 4, "coins": 120, "target": 100, "stars": 2, "passed": true})
	GameState.save_progress()
	GameState.day = 1
	GameState.coins = 0
	GameState.up = GameData.empty_upgrades()
	GameState.day_log.clear()
	check(GameState.has_save(), "save file exists")
	check(GameState.load_progress(), "save loads")
	eq(GameState.day, 5, "day restored")
	eq(GameState.coins, 321, "coins restored")
	eq(GameState.total_earned, 700, "total restored")
	eq(GameState.up["tray"], 2, "tray level restored")
	eq(GameState.up["table"], 1, "table level restored")
	eq(GameState.day_log.size(), 1, "log restored")
	GameState.delete_save()
	check(not GameState.has_save(), "progress deleted")
	GameState.up = GameData.empty_upgrades()
	GameState.coins = 0
	GameState.day = 1
	GameState.day_log.clear()


func test_continue_resumes_the_right_screen() -> void:
	GameState.day = 3
	GameState.coins = 100
	GameState.up = GameData.empty_upgrades()
	GameState.won = false
	GameState.save_progress("shop")
	GameState.day = 1
	check(GameState.continue_game(), "continue finds the save")
	eq(GameState.phase, "shop", "a shop save resumes in the shop")
	eq(GameState.day, 3, "day restored")
	GameState.save_progress("intro")
	check(GameState.continue_game(), "continue finds the intro save")
	eq(GameState.phase, "intro", "a day-start save resumes at the intro")
	GameState.day = 7
	GameState.won = false
	GameState.save_progress("shop")
	check(GameState.continue_game(), "continue finds the day 7 save")
	eq(GameState.phase, "victory", "an unclaimed win shows the victory screen first")
	GameState.delete_save()
	GameState.up = GameData.empty_upgrades()
	GameState.coins = 0
	GameState.day = 1
	GameState.won = false
	GameState.day_log.clear()


func test_state_text_is_json() -> void:
	var parsed: Variant = JSON.parse_string(GameState.get_state_text())
	check(parsed is Dictionary, "state text parses as a JSON object")
	var d: Dictionary = parsed
	check(d.has("phase") and d.has("day") and d.has("coins"), "has phase, day, coins")
	check(d.has("sim") and (d["sim"] as Dictionary).has("tables"), "includes the simulation")
