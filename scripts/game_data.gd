class_name GameData
extends RefCounted
## Loads the .tres game data once and hands out typed lookups.

const ITEM_IDS: Array[String] = ["tea", "simit", "coffee", "ayran"]
const CUSTOMER_IDS: Array[String] = ["normal", "office", "group", "regular"]
const UPGRADE_IDS: Array[String] = ["kettle", "tray", "oven", "table", "apprentice", "stool"]
const DAY_COUNT := 7

static var _items: Dictionary = {}
static var _customers: Dictionary = {}
static var _days: Array[DayData] = []
static var _upgrades: Dictionary = {}
static var _balance: BalanceData = null
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	for id in ITEM_IDS:
		_items[id] = load("res://data/items/%s.tres" % id) as ItemData
	for id in CUSTOMER_IDS:
		_customers[id] = load("res://data/customers/%s.tres" % id) as CustomerData
	for id in UPGRADE_IDS:
		_upgrades[id] = load("res://data/upgrades/%s.tres" % id) as UpgradeData
	for n in range(1, DAY_COUNT + 1):
		_days.append(load("res://data/days/day_%d.tres" % n) as DayData)
	_balance = load("res://data/balance.tres") as BalanceData


static func balance() -> BalanceData:
	ensure_loaded()
	return _balance


static func item(id: String) -> ItemData:
	ensure_loaded()
	return _items[id] as ItemData


static func customer(id: String) -> CustomerData:
	ensure_loaded()
	return _customers[id] as CustomerData


static func upgrade(id: String) -> UpgradeData:
	ensure_loaded()
	return _upgrades[id] as UpgradeData


static func empty_upgrades() -> Dictionary:
	var d: Dictionary = {}
	for id in UPGRADE_IDS:
		d[id] = 0
	return d


## Day 1..7 come from the .tres files, later days are an endless shift
## computed from the balance numbers.
static func day_config(day: int) -> DayData:
	ensure_loaded()
	if day <= DAY_COUNT:
		return _days[maxi(day, 1) - 1]
	var b := _balance
	var k := day - DAY_COUNT
	var d := DayData.new()
	d.day_index = day
	d.menu = PackedStringArray(ITEM_IDS)
	d.type_ids = PackedStringArray(CUSTOMER_IDS)
	d.type_weights = b.endless_type_weights
	d.spawn_gap = maxf(b.endless_gap_min, b.endless_gap_start - b.endless_gap_step * k)
	d.target = b.endless_target_base + b.endless_target_step * k
	d.new_key = "newE"
	d.new_icon = "star"
	return d
