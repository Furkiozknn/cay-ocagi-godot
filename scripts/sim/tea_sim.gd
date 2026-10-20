class_name TeaSim
extends RefCounted
## The rules of one tea house day, with no nodes and no rendering.
## Coordinates: x/z on the floor in metres (Vector2 x = world x, y = world z).

signal toast(key: String, tone: String)
signal sfx(sound: String)
signal burst(kind: String, pos: Vector3, count: int)
signal floating(pos: Vector3, text: String, tone: String)
signal day_ended

const STATION_IDS: Array[String] = ["tea", "simit", "coffee", "ayran", "sink"]
const LANE_X := -5.1
const CNT_X := -6.75
const STATION_Z := {"tea": -4.45, "simit": -1.9, "coffee": 0.5, "ayran": 2.7, "sink": 4.9}
const TABLE_POS: Array[Vector2] = [
	Vector2(-1.0, -0.5), Vector2(-1.0, 3.5), Vector2(-1.0, -4.5),
	Vector2(3.6, -0.5), Vector2(3.6, 3.5), Vector2(3.6, -4.5),
]
const SPAWN := Vector2(14.2, 9.2)
const EXIT := Vector2(14.2, -7.4)
const SEAT_ANGLES: Array[float] = [PI, PI / 2.0, PI * 1.5, 0.0]
const MAX_QUEUE := 6
const APPRENTICE_HOME := Vector2(-4.3, 5.9)
const SKIN_COLORS: Array[int] = [0xf0c6a0, 0xd9a07a, 0xb9794f, 0x8d5a3a, 0xe8b88e]
const HAIR_COLORS: Array[int] = [0x2a1a10, 0x4a2c18, 0x1c1c1c, 0x6b4426, 0x8a5a2a]
const SHIRT_COLORS: Array[int] = [0x4c8a8e, 0xc2602a, 0x7a9a4a, 0x8a6bb0, 0xd9a43c, 0xb85a6a, 0x5a7fb0]


## Anything that walks along a path.
class Mover:
	extends RefCounted
	var pos := Vector2.ZERO
	var face := 0.0
	var path: Array[Vector2] = []
	var moving := false

	## Advances along the path; returns true once the path is finished.
	func follow(speed: float, dt: float) -> bool:
		var move := speed * dt
		var moved := false
		while move > 0.0 and not path.is_empty():
			var n: Vector2 = path[0]
			var delta := n - pos
			var d := delta.length()
			if d <= move:
				pos = n
				path.pop_front()
				move -= d
				if d > 0.001:
					face = atan2(delta.x, delta.y)
					moved = true
			else:
				pos += delta / d * move
				face = atan2(delta.x, delta.y)
				move = 0.0
				moved = true
		moving = moved
		return path.is_empty()


class Person:
	extends Mover
	var delay := 0.0
	var seat := Vector2.ZERO
	var sitting := false
	var arrived := false
	var leaving := false
	var done := false
	var speed := 2.6
	var kind := "normal"
	var mood := 0
	var flash := 0.0
	var body_color := 0xffffff
	var skin_color := 0xffffff
	var hair_color := 0xffffff
	var big := 1.0
	var capped := false


class Party:
	extends RefCounted
	var id := 0
	var kind := "normal"
	var table := 0
	var persons: Array[Person] = []
	var order: Array[Dictionary] = []  # {item: String, done: bool}
	var state := "enter"  # enter, think, wait, eat, leave
	var timer := 0.0
	var patience := 0.0
	var max_patience := 0.0
	var final_frac := 1.0
	var cust: CustomerData = null

	func unmet() -> Array[String]:
		var out: Array[String] = []
		for o in order:
			if not o["done"]:
				out.append(o["item"])
		return out

	func all_served() -> bool:
		for o in order:
			if not o["done"]:
				return false
		return true


class Table:
	extends RefCounted
	var index := 0
	var pos := Vector2.ZERO
	var unlocked := false
	var party: Party = null
	var dirty := false
	var claimed := false
	var slots: Array[Dictionary] = []  # {kind, item, dirty}


class Waiter:
	extends Mover
	var queue: Array[Dictionary] = []  # {type: "station"|"table", id: Variant}
	var current: Dictionary = {}
	var state := "idle"  # idle, walk, work
	var work_t := 0.0
	var target := Vector3.ZERO  # x, z, face
	var tray: Array[String] = []


class Apprentice:
	extends Mover
	var state := "idle"
	var t := 0.0
	var table: Table = null
	var carrying := false


## One cooking slot: kettle, oven or coffee pot.
class Station:
	extends RefCounted
	var state := "empty"  # empty, brewing/baking/cook, ready, spilled
	var t := 0.0
	var n := 0

	func reset() -> void:
		state = "empty"
		t = 0.0
		n = 0


var day := 1
var cfg: DayData
var balance: BalanceData
var up: Dictionary = {}
var rng := RandomNumberGenerator.new()
var cosmetic := RandomNumberGenerator.new()
var nav: NavGrid
var tables: Array[Table] = []
var parties: Array[Party] = []
var waiter: Waiter
var apprentice: Apprentice = null
var kettles: Array[Station] = []
var oven: Station
var pots: Array[Station] = []
var clock := 0.0
var day_len := 180.0
var target := 0
var day_coins := 0
var day_tips := 0
var happy := 0
var angry := 0
var served := 0
var missed := 0
var spawn_t := 0.0
var spawn_count := 0
var walkby := 0
var finished := false


func _init(p_day: int, p_up: Dictionary, p_seed: int = 0) -> void:
	day = p_day
	up = p_up.duplicate()
	for id in GameData.UPGRADE_IDS:
		if not up.has(id):
			up[id] = 0
	balance = GameData.balance()
	cfg = GameData.day_config(day)
	if p_seed == 0:
		rng.randomize()
	else:
		rng.seed = p_seed
	cosmetic.randomize()
	day_len = balance.day_length
	target = cfg.target
	var unlocked_pos: Array[Vector2] = []
	for i in TABLE_POS.size():
		var tb := Table.new()
		tb.index = i
		tb.pos = TABLE_POS[i]
		tb.unlocked = i < table_count()
		tables.append(tb)
		if tb.unlocked:
			unlocked_pos.append(tb.pos)
	nav = NavGrid.new(unlocked_pos)
	for i in 2:
		kettles.append(Station.new())
		pots.append(Station.new())
	oven = Station.new()
	waiter = Waiter.new()
	waiter.pos = Vector2(LANE_X, 0.5)
	waiter.face = -PI / 2.0
	if up["apprentice"] > 0:
		apprentice = Apprentice.new()
		apprentice.pos = APPRENTICE_HOME
	spawn_t = balance.start_spawn_delay


# ---- derived numbers -------------------------------------------------------

func tray_cap() -> int:
	return balance.tray_base + int(up["tray"])


func oven_time() -> float:
	return balance.oven_times[int(up["oven"])]


func stool_mul() -> float:
	return 1.0 + balance.stool_bonus * int(up["stool"])


func table_count() -> int:
	return 3 + int(up["table"])


func active_kettles() -> int:
	return 1 + int(up["kettle"])


func station_locked(id: String) -> bool:
	return (id == "simit" or id == "coffee" or id == "ayran") and not cfg.menu.has(id)


static func table_approach(i: int) -> Vector2:
	var p := TABLE_POS[i]
	return Vector2(p.x - 2.0, p.y) if i < 3 else Vector2(p.x - 2.2, p.y)


static func seat_pos(i: int, k: int) -> Vector2:
	var p := TABLE_POS[i]
	var a := SEAT_ANGLES[k]
	return p + Vector2(cos(a), sin(a)) * 0.98


static func station_pos(id: String) -> Vector2:
	return Vector2(LANE_X, float(STATION_Z[id]))


## 0 = failed, 1..3 stars.
static func rating_stars(coins: int, goal: int, happy_count: int, angry_count: int) -> int:
	var total := happy_count + angry_count
	var ratio := float(happy_count) / total if total > 0 else 1.0
	if coins < goal:
		return 0
	var s := 1
	if coins >= goal * 1.25 and ratio >= 0.7:
		s = 2
	if s == 2 and coins >= goal * 1.5 and ratio >= 0.88:
		s = 3
	return s


func stars() -> int:
	return rating_stars(day_coins, target, happy, angry)


# ---- player commands -------------------------------------------------------

func click_station(id: String) -> bool:
	if station_locked(id):
		toast.emit("toastNothing", "")
		return false
	return _enqueue({"type": "station", "id": id})


func click_table(i: int) -> bool:
	if i < 0 or i >= tables.size() or not tables[i].unlocked:
		return false
	return _enqueue({"type": "table", "id": i})


func drop_tray(k: int) -> void:
	if k >= 0 and k < waiter.tray.size():
		waiter.tray.remove_at(k)
		sfx.emit("tick")


func clear_queue() -> void:
	waiter.queue.clear()


func _enqueue(a: Dictionary) -> bool:
	if finished:
		return false
	if waiter.queue.size() >= MAX_QUEUE:
		toast.emit("toastQueue", "bad")
		return false
	waiter.queue.append(a)
	sfx.emit("tick")
	return true


# ---- simulation step -------------------------------------------------------

func step(dt: float) -> void:
	if finished:
		return
	clock += dt
	_stations_update(dt)
	_spawn_update(dt)
	_parties_update(dt)
	_waiter_update(dt)
	_apprentice_update(dt)
	_people_update(dt)
	if clock >= day_len:
		finished = true
		day_ended.emit()


func _stations_update(dt: float) -> void:
	for i in active_kettles():
		var k := kettles[i]
		if k.state == "brewing":
			k.t += dt
			if k.t >= balance.brew_time:
				k.state = "ready"
				k.t = 0.0
				k.n = balance.tea_servings
				sfx.emit("whistle")
				toast.emit("toastTeaReady", "good")
	if oven.state == "baking":
		oven.t += dt
		if oven.t >= oven_time():
			oven.state = "ready"
			oven.t = 0.0
			oven.n = balance.oven_servings
			sfx.emit("ping")
			toast.emit("toastSimitReady", "good")
	for k in pots.size():
		var p := pots[k]
		if p.state == "cook":
			p.t += dt
			if p.t >= balance.cook_time:
				p.state = "ready"
				p.t = 0.0
				sfx.emit("ping")
				toast.emit("toastCoffeeReady", "good")
		elif p.state == "ready":
			p.t += dt
			if p.t >= balance.cook_window:
				p.state = "spilled"
				p.t = 0.0
				sfx.emit("hiss")
				toast.emit("toastSpill", "bad")
				burst.emit("steam", Vector3(CNT_X, 1.5, float(STATION_Z["coffee"])), 10)


func _do_station(id: String) -> void:
	var w := waiter
	var full := w.tray.size() >= tray_cap()
	if id == "tea":
		var ready: Station = null
		var empty: Station = null
		for i in active_kettles():
			if ready == null and kettles[i].state == "ready" and kettles[i].n > 0:
				ready = kettles[i]
			if empty == null and kettles[i].state == "empty":
				empty = kettles[i]
		if ready != null:
			if full:
				toast.emit("toastTray", "bad")
				return
			ready.n -= 1
			if ready.n <= 0:
				ready.reset()
			w.tray.append("tea")
			sfx.emit("pour")
		elif empty != null:
			empty.state = "brewing"
			empty.t = 0.0
			sfx.emit("pour")
			toast.emit("toastBrewStart", "")
		else:
			toast.emit("toastBrewing", "")
	elif id == "simit":
		if oven.state == "ready" and oven.n > 0:
			if full:
				toast.emit("toastTray", "bad")
				return
			oven.n -= 1
			if oven.n <= 0:
				oven.reset()
			w.tray.append("simit")
			sfx.emit("clink")
		elif oven.state == "empty":
			oven.state = "baking"
			oven.t = 0.0
			sfx.emit("clink")
			toast.emit("toastWarm", "")
		else:
			toast.emit("toastBrewing", "")
	elif id == "coffee":
		var rd: Station = null
		var sp: Station = null
		var em: Station = null
		for p in pots:
			if rd == null and p.state == "ready":
				rd = p
			if sp == null and p.state == "spilled":
				sp = p
			if em == null and p.state == "empty":
				em = p
		if rd != null:
			if full:
				toast.emit("toastTray", "bad")
				return
			rd.reset()
			w.tray.append("coffee")
			sfx.emit("clink")
		elif sp != null:
			sp.reset()
			toast.emit("toastClean", "")
			sfx.emit("clink")
		elif em != null:
			em.state = "cook"
			em.t = 0.0
			sfx.emit("clink")
			toast.emit("toastCook", "")
		else:
			toast.emit("toastBrewing", "")
	elif id == "ayran":
		if full:
			toast.emit("toastTray", "bad")
			return
		w.tray.append("ayran")
		sfx.emit("pour")
	elif id == "sink":
		var before := w.tray.size()
		var kept: Array[String] = []
		for it in w.tray:
			if it != "dirty":
				kept.append(it)
		w.tray = kept
		if kept.size() == before:
			toast.emit("toastNothingToWash", "")
			return
		sfx.emit("wash")
		burst.emit("spark", Vector3(CNT_X, 1.8, float(STATION_Z["sink"])), 6)
		toast.emit("toastWash", "")


func _do_table(i: int) -> void:
	var w := waiter
	var tb := tables[i]
	var p := tb.party
	var did := false
	if p != null and p.state == "think":
		toast.emit("toastNoOrder", "")
		return
	if p != null and p.state == "wait":
		var k := w.tray.size() - 1
		while k >= 0:
			var it := w.tray[k]
			if it != "dirty":
				for o in p.order:
					if not o["done"] and o["item"] == it:
						o["done"] = true
						w.tray.remove_at(k)
						did = true
						_leave_tableware(tb, it)
						p.patience = minf(p.max_patience, p.patience + p.max_patience * balance.serve_patience_bonus)
						sfx.emit("clink")
						burst.emit("spark", Vector3(tb.pos.x, 1.4, tb.pos.y), 3)
						break
			k -= 1
		if did and p.all_served():
			p.state = "eat"
			p.timer = p.cust.eat_time * rng.randf_range(0.8, 1.2)
			p.final_frac = clampf(p.patience / p.max_patience, 0.0, 1.0)
		if not did:
			toast.emit("toastWrong", "bad")
			return
	if p == null and tb.dirty:
		if w.tray.size() >= tray_cap():
			toast.emit("toastTray", "bad")
			return
		w.tray.append("dirty")
		tb.dirty = false
		tb.slots.clear()
		did = true
		sfx.emit("clink")
	if not did:
		toast.emit("toastNothing", "")


func _leave_tableware(tb: Table, item: String) -> void:
	var kind := GameData.item(item).tableware
	tb.slots.append({"kind": kind, "item": item, "dirty": false})


func _target_for(a: Dictionary) -> Vector3:
	if a["type"] == "station":
		var sp := station_pos(a["id"])
		return Vector3(sp.x, sp.y, -PI / 2.0)
	var idx: int = a["id"]
	var ap := table_approach(idx)
	var tpos := tables[idx].pos
	return Vector3(ap.x, ap.y, atan2(tpos.x - ap.x, tpos.y - ap.y))


func _waiter_update(dt: float) -> void:
	var w := waiter
	if w.current.is_empty() and not w.queue.is_empty():
		w.current = w.queue.pop_front()
		w.target = _target_for(w.current)
		w.path = nav.find_path(w.pos, Vector2(w.target.x, w.target.y))
		w.state = "walk"
	if w.state == "walk":
		if w.follow(balance.walk_speed, dt):
			w.state = "work"
			w.work_t = 0.32
			w.face = w.target.z
			w.moving = false
	elif w.state == "work":
		w.work_t -= dt
		w.moving = false
		if w.work_t <= 0.0:
			var a := w.current
			w.current = {}
			w.state = "idle"
			if a["type"] == "station":
				_do_station(a["id"])
			else:
				_do_table(a["id"])
	else:
		w.moving = false


func _apprentice_update(dt: float) -> void:
	var a := apprentice
	if a == null:
		return
	var sink := Vector2(-4.35, float(STATION_Z["sink"]) - 0.1)
	match a.state:
		"idle":
			var found: Table = null
			for tb in tables:
				if tb.unlocked and tb.dirty and not tb.claimed:
					found = tb
					break
			if found != null:
				found.claimed = true
				a.table = found
				var ap := table_approach(found.index)
				a.path = nav.find_path(a.pos, Vector2(ap.x, ap.y + 0.4))
				a.state = "goto"
			else:
				a.moving = false
		"goto":
			if a.follow(balance.walk_speed * 0.85, dt):
				a.state = "clear"
				a.t = 0.7
				a.face = atan2(a.table.pos.x - a.pos.x, a.table.pos.y - a.pos.y)
		"clear":
			a.moving = false
			a.t -= dt
			if a.t <= 0.0:
				a.table.dirty = false
				a.table.slots.clear()
				a.table.claimed = false
				a.table = null
				a.carrying = true
				a.path = nav.find_path(a.pos, sink)
				a.state = "sink"
				sfx.emit("clink")
				toast.emit("toastApprentice", "")
		"sink":
			if a.follow(balance.walk_speed * 0.85, dt):
				a.state = "wash"
				a.t = 0.8
				a.face = -PI / 2.0
		"wash":
			a.moving = false
			a.t -= dt
			if a.t <= 0.0:
				a.carrying = false
				sfx.emit("wash")
				a.path = nav.find_path(a.pos, APPRENTICE_HOME)
				a.state = "back"
		"back":
			if a.follow(balance.walk_speed * 0.7, dt):
				a.state = "idle"


# ---- customers -------------------------------------------------------------

func _pick_type() -> String:
	var sum := 0.0
	for wgt in cfg.type_weights:
		sum += wgt
	var r := rng.randf() * sum
	for i in cfg.type_ids.size():
		r -= cfg.type_weights[i]
		if r <= 0.0:
			return cfg.type_ids[i]
	return cfg.type_ids[0]


func _pick_item() -> String:
	var sum := 0.0
	for id in cfg.menu:
		sum += GameData.item(id).weight
	var r := rng.randf() * sum
	for id in cfg.menu:
		r -= GameData.item(id).weight
		if r <= 0.0:
			return id
	return cfg.menu[0]


func _spawn_party() -> bool:
	var free: Array[Table] = []
	for tb in tables:
		if tb.unlocked and tb.party == null and not tb.dirty and not tb.claimed:
			free.append(tb)
	if free.is_empty():
		return false
	var kind := _pick_type()
	var cc := GameData.customer(kind)
	var tb := free[rng.randi_range(0, free.size() - 1)]
	var n := rng.randi_range(cc.items_min, cc.items_max)
	var party := Party.new()
	party.id = spawn_count + 1
	spawn_count += 1
	party.kind = kind
	party.table = tb.index
	party.cust = cc
	for i in n:
		party.order.append({"item": _pick_item(), "done": false})
	var decay := maxf(balance.day_patience_floor, 1.0 - balance.day_patience_decay * (day - 1))
	party.max_patience = cc.patience * stool_mul() * decay
	party.patience = party.max_patience
	var ap := table_approach(tb.index)
	var base := nav.find_path(SPAWN, ap)
	for k in cc.party_size:
		var pe := Person.new()
		pe.pos = SPAWN + Vector2(k * 0.5, k * 0.3)
		pe.face = -PI / 2.0
		pe.seat = seat_pos(tb.index, k)
		var route: Array[Vector2] = base.duplicate()
		route.append(pe.seat)
		pe.path = route
		pe.delay = k * 0.85
		pe.kind = kind
		pe.speed = cc.walk_speed
		pe.skin_color = SKIN_COLORS[cosmetic.randi() % SKIN_COLORS.size()]
		pe.capped = kind == "regular"
		pe.hair_color = 0xe8e8e8 if pe.capped else HAIR_COLORS[cosmetic.randi() % HAIR_COLORS.size()]
		pe.big = 1.12 if pe.capped else 1.0
		if cc.body_color.a > 0.0:
			pe.body_color = cc.body_color.to_rgba32() >> 8
		else:
			pe.body_color = SHIRT_COLORS[cosmetic.randi() % SHIRT_COLORS.size()]
		party.persons.append(pe)
	tb.party = party
	tb.slots.clear()
	parties.append(party)
	sfx.emit("bell")
	return true


func _spawn_update(dt: float) -> void:
	if clock > day_len - balance.last_spawn_before_end:
		return
	spawn_t -= dt
	if spawn_t <= 0.0:
		var rush := 1.0 - balance.rush_depth * sin(PI * clampf(clock / day_len, 0.0, 1.0))
		spawn_t = cfg.spawn_gap * rush * rng.randf_range(0.7, 1.3)
		if not _spawn_party():
			walkby += 1
			floating.emit(Vector3(11.5, 1.8, 6.5), "passByWait", "bad")


func _finish_leave(p: Party, is_angry: bool) -> void:
	var tb := tables[p.table]
	p.state = "leave"
	tb.party = null
	tb.dirty = not tb.slots.is_empty()
	if not tb.dirty:
		tb.slots.clear()
	for s in tb.slots:
		s["dirty"] = true
	for k in p.persons.size():
		var pe := p.persons[k]
		pe.leaving = true
		pe.sitting = false
		pe.arrived = false
		pe.path = nav.find_path(pe.pos, EXIT)
		pe.delay = 0.15 * k
		pe.speed = 3.6 if is_angry else 2.7
		pe.mood = -1 if is_angry else 1
		pe.flash = 1.0 if is_angry else 0.0


func _pay_party(p: Party) -> void:
	var base := 0
	for o in p.order:
		base += GameData.item(o["item"]).price
	var tip := roundi(base * balance.tip_rate * p.final_frac * p.cust.tip_mul)
	var tb := tables[p.table]
	_add_coins(base + tip, tb.pos, tip)
	happy += 1
	served += p.persons.size()


func _add_coins(n: int, at: Vector2, tip: int) -> void:
	day_coins += n
	day_tips += tip
	sfx.emit("cash")
	floating.emit(Vector3(at.x, 2.4, at.y), "+%d" % n if tip == 0 else "+%d (%d)" % [n, tip], "coin")
	burst.emit("spark", Vector3(at.x, 1.8, at.y), 8)


func _parties_update(dt: float) -> void:
	var i := parties.size() - 1
	while i >= 0:
		var p := parties[i]
		match p.state:
			"enter":
				var all_seated := true
				for pe in p.persons:
					if not pe.sitting:
						all_seated = false
						break
				if all_seated:
					p.state = "think"
					p.timer = rng.randf_range(1.0, 2.0)
			"think":
				p.timer -= dt
				if p.timer <= 0.0:
					p.state = "wait"
					sfx.emit("pip")
			"wait":
				p.patience -= dt
				if p.patience <= 0.0:
					angry += 1
					missed += p.persons.size()
					toast.emit("toastAngry", "bad")
					sfx.emit("grumble")
					var tb := tables[p.table]
					burst.emit("anger", Vector3(tb.pos.x, 1.6, tb.pos.y), 10)
					_finish_leave(p, true)
			"eat":
				p.timer -= dt
				if p.timer <= 0.0:
					_pay_party(p)
					_finish_leave(p, false)
			"leave":
				var all_gone := true
				for pe in p.persons:
					if not pe.done:
						all_gone = false
						break
				if all_gone:
					parties.remove_at(i)
		i -= 1


func _people_update(dt: float) -> void:
	for p in parties:
		for pe in p.persons:
			if pe.delay > 0.0:
				pe.delay -= dt
				pe.moving = false
				continue
			if pe.flash > 0.0:
				pe.flash = maxf(0.0, pe.flash - dt * 0.5)
			if not pe.sitting and not pe.done:
				if pe.follow(pe.speed, dt):
					if pe.leaving:
						pe.done = true
					else:
						pe.sitting = true
						pe.arrived = true
						var tpos := tables[p.table].pos
						pe.face = atan2(tpos.x - pe.pos.x, tpos.y - pe.pos.y)


# ---- inspection ------------------------------------------------------------

func to_dict() -> Dictionary:
	var tb_list: Array = []
	for tb in tables:
		var d := {"index": tb.index, "unlocked": tb.unlocked, "dirty": tb.dirty}
		if tb.party != null:
			var p := tb.party
			d["party"] = {
				"kind": p.kind, "state": p.state, "size": p.persons.size(),
				"patience": snappedf(p.patience, 0.1), "order": p.order.duplicate(true),
			}
		tb_list.append(d)
	var stations := {
		"kettles": kettles.slice(0, active_kettles()).map(func(k: Station) -> Dictionary: return _station_dict(k)),
		"oven": _station_dict(oven),
		"pots": pots.map(func(k: Station) -> Dictionary: return _station_dict(k)),
	}
	return {
		"day": day, "clock": snappedf(clock, 0.1), "day_length": day_len, "target": target,
		"day_coins": day_coins, "tips": day_tips, "happy": happy, "angry": angry, "served": served,
		"spawned": spawn_count, "walked_by": walkby, "finished": finished,
		"waiter": {
			"state": waiter.state, "pos": [snappedf(waiter.pos.x, 0.01), snappedf(waiter.pos.y, 0.01)],
			"tray": waiter.tray.duplicate(), "queue": waiter.queue.map(func(a: Dictionary) -> String: return "%s:%s" % [a["type"], a["id"]]),
		},
		"apprentice": apprentice != null,
		"stations": stations,
		"tables": tb_list,
	}


func _station_dict(s: Station) -> Dictionary:
	return {"state": s.state, "t": snappedf(s.t, 0.1), "n": s.n}
