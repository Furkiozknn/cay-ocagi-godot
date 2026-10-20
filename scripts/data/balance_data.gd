class_name BalanceData
extends Resource
## Global tuning numbers of the simulation.

@export var day_length: float = 180.0
@export var brew_time: float = 7.0
@export var tea_servings: int = 4
@export var oven_times: PackedFloat32Array = PackedFloat32Array([6.5, 4.6, 3.3])
@export var oven_servings: int = 3
@export var cook_time: float = 4.2
@export var cook_window: float = 3.6
@export var walk_speed: float = 5.4
@export var tray_base: int = 3
@export var tip_rate: float = 0.4
@export var serve_patience_bonus: float = 0.08
@export var stool_bonus: float = 0.2
@export var day_patience_decay: float = 0.03
@export var day_patience_floor: float = 0.78
## Rush hour: spawn gaps shrink by up to this fraction around noon.
@export var rush_depth: float = 0.22
@export var last_spawn_before_end: float = 20.0
@export var start_spawn_delay: float = 2.2
@export var win_day: int = 7
@export var skip_day_coins: int = 150
@export var endless_gap_start: float = 4.8
@export var endless_gap_step: float = 0.25
@export var endless_gap_min: float = 3.4
@export var endless_target_base: int = 250
@export var endless_target_step: int = 35
@export var endless_type_weights: PackedFloat32Array = PackedFloat32Array([44.0, 22.0, 17.0, 17.0])
