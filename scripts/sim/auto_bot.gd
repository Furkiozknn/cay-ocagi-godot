class_name AutoBot
extends RefCounted
## Plays a tea house day by queueing the same clicks a human would make.

const SHOP_ORDER: Array[String] = ["tray", "kettle", "table", "oven", "apprentice", "stool", "tray", "table", "oven", "stool", "table"]

var rng := RandomNumberGenerator.new()
var skill := 1.0
var _think := 0.0


func _init(p_seed: int = 0) -> void:
	if p_seed == 0:
		rng.randomize()
	else:
		rng.seed = p_seed


func update(sim: TeaSim, dt: float) -> void:
	if sim.finished:
		return
	_think -= dt
	if _think > 0.0:
		return
	_think = rng.randf_range(0.55, 0.95) / maxf(0.3, skill)
	if rng.randf() > 0.1 * (2.0 - minf(skill, 1.5)):
		decide(sim)


## Which shop item to buy next, or "" when nothing is affordable.
func shop_pick(up: Dictionary, coins: int) -> String:
	for id in SHOP_ORDER:
		var u := GameData.upgrade(id)
		var lv: int = up[id]
		if lv < u.max_level and coins >= u.costs[lv]:
			return id
	return ""


func decide(sim: TeaSim) -> void:
	var w := sim.waiter
	var cap := sim.tray_cap()
	if w.queue.size() >= 2:
		return
	var queued: Array[Dictionary] = w.queue.duplicate()
	if not w.current.is_empty():
		queued.append(w.current)
	var tray := w.tray
	var station_queued := func(id: String) -> int:
		var n := 0
		for a in queued:
			if a["type"] == "station" and a["id"] == id:
				n += 1
		return n
	var table_queued := func(i: int) -> bool:
		for a in queued:
			if a["type"] == "table" and a["id"] == i:
				return true
		return false
	var waiting: Array[TeaSim.Party] = []
	for p in sim.parties:
		if p.state == "wait":
			waiting.append(p)

	# 1. can we serve someone with what we carry?
	var best: TeaSim.Party = null
	var best_p := 1e9
	var best_full := false
	for p in waiting:
		if table_queued.call(p.table):
			continue
		var left: Array[String] = p.unmet()
		var matched := 0
		for it in tray:
			var ix := left.find(it)
			if ix >= 0:
				left.remove_at(ix)
				matched += 1
		if matched == 0:
			continue
		if p.patience < best_p:
			best_p = p.patience
			best = p
			best_full = left.is_empty()
	var useful_in_tray := 0
	for it in tray:
		if it != "dirty":
			useful_in_tray += 1

	# demand still to fetch
	var need := {}
	for p in waiting:
		for it in p.unmet():
			need[it] = int(need.get(it, 0)) + 1
	for it in GameData.ITEM_IDS:
		if need.has(it):
			need[it] = int(need[it]) - tray.count(it)
	var station_actions := 0
	for a in queued:
		if a["type"] == "station" and a["id"] != "sink":
			station_actions += 1
	var fetch := ""
	var fetch_urgency := 1e9
	for it in GameData.ITEM_IDS:
		if int(need.get(it, 0)) - int(station_queued.call(it)) <= 0:
			continue
		var urg := 1e9
		for p in waiting:
			if p.unmet().has(it):
				urg = minf(urg, p.patience)
		var can := false
		match it:
			"tea":
				var any_ready := false
				var any_empty := false
				var any_brewing := false
				for i in sim.active_kettles():
					var k := sim.kettles[i]
					any_ready = any_ready or (k.state == "ready" and k.n > 0)
					any_empty = any_empty or k.state == "empty"
					any_brewing = any_brewing or k.state == "brewing"
				can = any_ready or (any_empty and not any_brewing)
			"simit":
				can = (sim.oven.state == "ready" and sim.oven.n > 0) or sim.oven.state == "empty"
			"coffee":
				for p in sim.pots:
					if p.state == "ready" or p.state == "empty":
						can = true
			"ayran":
				can = true
		if not can:
			continue
		if tray.size() + station_actions >= cap and it == "ayran":
			continue
		if urg < fetch_urgency:
			fetch_urgency = urg
			fetch = it
	var tray_room := cap - tray.size() - station_actions

	# decide
	if best != null and (best_full or tray_room <= 0 or fetch == "" or useful_in_tray >= 2):
		sim.click_table(best.table)
		return
	if fetch != "" and tray_room > 0:
		sim.click_station(fetch)
		return
	if best != null:
		sim.click_table(best.table)
		return
	# dirty tables
	var dirty_tables: Array[TeaSim.Table] = []
	for tb in sim.tables:
		if tb.unlocked and tb.dirty and not tb.claimed and not table_queued.call(tb.index):
			dirty_tables.append(tb)
	if sim.apprentice == null and not dirty_tables.is_empty() and tray_room > 0:
		sim.click_table(dirty_tables[0].index)
		return
	if tray.has("dirty") and int(station_queued.call("sink")) == 0:
		sim.click_station("sink")
		return
	# pre-warm idle stations while customers are around
	if not sim.parties.is_empty():
		var any_empty := false
		var any_busy := false
		for i in sim.active_kettles():
			var k := sim.kettles[i]
			any_empty = any_empty or k.state == "empty"
			any_busy = any_busy or k.state == "brewing" or k.state == "ready"
		if any_empty and not any_busy and int(station_queued.call("tea")) == 0:
			sim.click_station("tea")
			return
		if sim.cfg.menu.has("simit") and sim.oven.state == "empty" and int(station_queued.call("simit")) == 0 and sim.parties.size() >= 2:
			sim.click_station("simit")
			return
	# clean a spilled coffee pot
	for p in sim.pots:
		if p.state == "spilled" and int(station_queued.call("coffee")) == 0:
			sim.click_station("coffee")
			return
	# nobody wants what is in the tray: drop it
	if tray.size() >= cap and best == null and fetch == "" and waiting.is_empty():
		for k in tray.size():
			if tray[k] != "dirty":
				sim.drop_tray(k)
				return
