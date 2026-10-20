class_name DayData
extends Resource
## Rules of one day: menu, customer mix, pace and coin target.

@export var day_index: int = 1
@export var menu: PackedStringArray = PackedStringArray()
@export var type_ids: PackedStringArray = PackedStringArray()
@export var type_weights: PackedFloat32Array = PackedFloat32Array()
@export var spawn_gap: float = 8.0
@export var target: int = 60
## Localisation key of the "new today" blurb and the icon that goes with it.
@export var new_key: String = ""
@export var new_icon: String = ""
