class_name CustomerData
extends Resource
## One kind of customer (normal, office, group, regular).

@export var id: String = ""
@export var patience: float = 40.0
@export var items_min: int = 1
@export var items_max: int = 3
@export var party_size: int = 1
@export var tip_mul: float = 1.0
@export var eat_time: float = 5.0
@export var walk_speed: float = 2.6
## Alpha 0 means "pick a random shirt colour".
@export var body_color: Color = Color(0, 0, 0, 0)
