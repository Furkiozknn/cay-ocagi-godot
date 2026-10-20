class_name Icon
extends Control
## A square control that draws one of the vector icons from Icons.

@export var kind := "tea":
	set(value):
		kind = value
		queue_redraw()
@export var tint := Palette.UI_INK:
	set(value):
		tint = value
		queue_redraw()


static func make(p_kind: String, px: float, p_tint: Color = Palette.UI_INK) -> Icon:
	var ic := Icon.new()
	ic.kind = p_kind
	ic.tint = p_tint
	ic.custom_minimum_size = Vector2(px, px)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ic


func _draw() -> void:
	Icons.draw_at(self, kind, Rect2(Vector2.ZERO, size), tint)
