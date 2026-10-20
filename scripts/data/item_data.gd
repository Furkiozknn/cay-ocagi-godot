class_name ItemData
extends Resource
## One menu item (tea, simit, coffee, ayran).

@export var id: String = ""
@export var price: int = 1
## Relative chance that a customer orders this item.
@export var weight: float = 1.0
@export var color: Color = Color.WHITE
## "glass" or "plate": which tableware is left behind.
@export var tableware: String = "glass"
