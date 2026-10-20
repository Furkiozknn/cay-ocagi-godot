class_name OrderBubble
extends Control
## Speech bubble above a table: party avatar inside a patience ring, then the order.
## Also used as a small mood / dirty-glass bubble.

signal pressed

const RING := 19.0
const ITEM := 26.0
const PAD := 5.0

var mode := "none"  # none, think, order, mini
var avatar := "person"
var mini_icon := "happy"
var items: Array[Dictionary] = []
var frac := 1.0
var urgent := false
var _bob := 0.0

static var _styles: Dictionary = {}


static func _style(key: String, bg: Color, radius: int, border: Color, border_w: int, shadow: bool) -> StyleBoxFlat:
	if not _styles.has(key):
		_styles[key] = UiKit.box(bg, radius, border, border_w, shadow)
	return _styles[key]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	visible = false


func show_order(p_avatar: String, p_items: Array[Dictionary], p_frac: float) -> void:
	mode = "order"
	avatar = p_avatar
	items = p_items
	frac = p_frac
	urgent = p_frac < 0.28
	_relayout()


func show_think(p_avatar: String) -> void:
	mode = "think"
	avatar = p_avatar
	_relayout()


func show_mini(icon_kind: String) -> void:
	mode = "mini"
	mini_icon = icon_kind
	_relayout()


func clear() -> void:
	if mode != "none":
		mode = "none"
		visible = false


func _relayout() -> void:
	var w := PAD * 2.0 + 8.0
	match mode:
		"order":
			w = PAD * 2.0 + RING * 2.0 + 6.0 + items.size() * (ITEM + 3.0) + 2.0
		"think":
			w = PAD * 2.0 + RING * 2.0 + 6.0 + 48.0
		"mini":
			w = 44.0
	var h := RING * 2.0 + PAD * 2.0 if mode != "mini" else 40.0
	custom_minimum_size = Vector2(w, h)
	size = Vector2(w, h)
	pivot_offset = Vector2(w * 0.5, h + 8.0)
	visible = true
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_bob += delta
	if mode == "mini" and mini_icon == "dirty":
		pivot_offset = Vector2(size.x * 0.5, size.y + 8.0)
	if urgent and mode == "order":
		rotation = sin(_bob * 28.0) * 0.04
	else:
		rotation = 0.0
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()


func _draw() -> void:
	if mode == "none":
		return
	var h := size.y
	var w := size.x
	var bg := Color(1.0, 0.988, 0.957, 0.95)
	draw_style_box(_style("bg%d" % int(h), bg, int(h * 0.5), Color(0, 0, 0, 0), 0, true), Rect2(Vector2.ZERO, size))
	# tail
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.5 - 7, h - 2), Vector2(w * 0.5 + 7, h - 2), Vector2(w * 0.5, h + 8)]), bg)
	if mode == "mini":
		Icons.draw_at(self, mini_icon, Rect2(Vector2(8, 6), Vector2(w - 16, h - 12)))
		return
	var c := Vector2(PAD + RING, h * 0.5)
	if mode == "order":
		var col := Palette.UI_OK
		if frac < 0.5:
			col = Color("d4a017")
		if frac < 0.28:
			col = Palette.UI_BAD
		draw_arc(c, RING - 2.0, 0.0, TAU, 32, Color(0.31, 0.16, 0.04, 0.15), 4.0, true)
		draw_arc(c, RING - 2.0, -PI / 2.0, -PI / 2.0 + TAU * clampf(frac, 0.0, 1.0), 32, col, 4.0, true)
	else:
		draw_arc(c, RING - 2.0, 0.0, TAU, 32, Color(0.31, 0.16, 0.04, 0.15), 4.0, true)
	Icons.draw_at(self, avatar, Rect2(c - Vector2(12, 12), Vector2(24, 24)))
	if mode == "think":
		var phase := int(_bob * 3.0) % 4
		for i in 3:
			var a := 0.25 if i >= phase else 1.0
			draw_circle(Vector2(c.x + RING + 14.0 + i * 12.0, h * 0.5), 3.4, Color(0.31, 0.16, 0.04, a * 0.8))
		return
	var x := c.x + RING + 6.0
	for it in items:
		var r := Rect2(Vector2(x, h * 0.5 - ITEM * 0.5), Vector2(ITEM, ITEM))
		var done: bool = it["done"]
		draw_style_box(_style("done" if done else "item", Color("dff3e0") if done else Color.WHITE, 8, Color(0.47, 0.27, 0.12, 0.2), 1, false), r)
		Icons.draw_at(self, it["item"], r.grow(-3.0), Palette.UI_INK)
		if done:
			draw_rect(r, Color(1, 1, 1, 0.35))
			Icons.draw_at(self, "check", r.grow(-2.0))
		x += ITEM + 3.0
