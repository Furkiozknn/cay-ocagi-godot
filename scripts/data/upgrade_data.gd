class_name UpgradeData
extends Resource
## One shop upgrade with up to max_level levels.

@export var id: String = ""
@export var max_level: int = 1
@export var costs: PackedInt32Array = PackedInt32Array()
@export var icon: String = ""
