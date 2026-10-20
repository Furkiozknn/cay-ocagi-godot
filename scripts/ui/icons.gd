class_name Icons
extends RefCounted
## Vector icons drawn with CanvasItem draw calls in a 24x24 design space.

const BROWN := Color("7c2d12")


static func draw_at(ci: CanvasItem, kind: String, rect: Rect2, tint: Color = Palette.UI_INK) -> void:
	var s := minf(rect.size.x, rect.size.y)
	var off := rect.position + (rect.size - Vector2(s, s)) * 0.5
	ci.draw_set_transform(off, 0.0, Vector2(s / 24.0, s / 24.0))
	_draw_kind(ci, kind, tint)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _shape(ci: CanvasItem, pts: Array, fill: Color, stroke: Color = Color(0, 0, 0, 0), width: float = 1.2) -> void:
	var arr := PackedVector2Array(pts)
	if fill.a > 0.0:
		ci.draw_colored_polygon(arr, fill)
	if stroke.a > 0.0:
		var closed := arr.duplicate()
		closed.append(arr[0])
		ci.draw_polyline(closed, stroke, width, true)


static func _ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, fill: Color, stroke: Color = Color(0, 0, 0, 0), width: float = 1.0) -> void:
	var pts: Array[Vector2] = []
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	_shape(ci, pts, fill, stroke, width)


static func _circle(ci: CanvasItem, c: Vector2, r: float, fill: Color, stroke: Color = Color(0, 0, 0, 0), width: float = 1.2) -> void:
	ci.draw_circle(c, r, fill)
	if stroke.a > 0.0:
		ci.draw_arc(c, r, 0.0, TAU, 32, stroke, width, true)


static func _star_points(c: Vector2, r_out: float, r_in: float) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var r := r_out if i % 2 == 0 else r_in
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


static func _glass(ci: CanvasItem, fill: Color, stroke: Color, saucer: bool = true) -> void:
	var pts: Array[Vector2] = [Vector2(6.4, 3.2), Vector2(17.6, 3.2), Vector2(17.0, 7.5), Vector2(15.8, 10.8), Vector2(14.2, 13.0), Vector2(14.2, 15.3), Vector2(9.8, 15.3), Vector2(9.8, 13.0), Vector2(8.2, 10.8), Vector2(7.0, 7.5)]
	if saucer:
		_ellipse(ci, Vector2(12, 19), 6.6, 1.9, Color("f1e1c4"), stroke, 1.0)
	_shape(ci, pts, fill, stroke, 1.2)


static func _draw_kind(ci: CanvasItem, kind: String, tint: Color) -> void:
	match kind:
		"tea", "tulip":
			_glass(ci, Color("c2410c"), BROWN, kind == "tea")
			ci.draw_line(Vector2(6.8, 4.6), Vector2(17.2, 4.6), Color(1, 1, 1, 0.55), 1.6)
		"simit":
			ci.draw_arc(Vector2(12, 12), 6.6, 0.0, TAU, 40, Color("a9691f"), 6.0, true)
			ci.draw_arc(Vector2(12, 12), 6.6, 0.0, TAU, 40, Color("e0a448"), 4.4, true)
			for i in 14:
				var a := TAU * i / 14.0
				ci.draw_circle(Vector2(12, 12) + Vector2(cos(a), sin(a)) * 6.6, 0.45, Color("fff3cf"))
		"coffee":
			ci.draw_polyline(PackedVector2Array([Vector2(7, 3), Vector2(6.2, 4.6), Vector2(7.8, 5.6), Vector2(7, 7)]), Color("a89888"), 1.3, true)
			ci.draw_polyline(PackedVector2Array([Vector2(11, 3), Vector2(10.2, 4.6), Vector2(11.8, 5.6), Vector2(11, 7)]), Color("a89888"), 1.3, true)
			_ellipse(ci, Vector2(10, 19.5), 7.5, 1.8, Color("f1e1c4"), Color("3b2210"), 1.0)
			ci.draw_arc(Vector2(16.0, 12.6), 2.3, -PI / 2.0, PI / 2.0, 12, Color("3b2210"), 1.5, true)
			_shape(ci, [Vector2(4.5, 9), Vector2(15.5, 9), Vector2(15.5, 12.6), Vector2(14.3, 15.4), Vector2(12.4, 17.3), Vector2(10, 18.1), Vector2(7.6, 17.3), Vector2(5.7, 15.4), Vector2(4.5, 12.6)], Color("6b4226"), Color("3b2210"), 1.2)
		"ayran":
			_shape(ci, [Vector2(6, 6.5), Vector2(18, 6.5), Vector2(16.5, 19.5), Vector2(15, 20.8), Vector2(9, 20.8), Vector2(7.5, 19.5)], Color("fbfaf4"), Color("587486"), 1.3)
			_shape(ci, [Vector2(6.6, 10.5), Vector2(17.4, 10.5), Vector2(16.9, 15), Vector2(7.1, 15)], Color("9cc7de"))
			ci.draw_line(Vector2(5.5, 6.5), Vector2(18.5, 6.5), Color("587486"), 1.6, true)
			ci.draw_polyline(PackedVector2Array([Vector2(8, 4.8), Vector2(10, 3.7), Vector2(12, 3.4), Vector2(14, 3.7), Vector2(16, 4.8)]), Color("c9d6dd"), 1.1, true)
		"dirty":
			_glass(ci, Color("a49a90"), Color("5f554c"))
			ci.draw_circle(Vector2(10, 7), 1.2, Color("6e655c"))
			ci.draw_circle(Vector2(14, 9.5), 1.0, Color("6e655c"))
			_shape(ci, _star_points(Vector2(18, 4), 2.4, 0.9), Color.WHITE, Color("e0b64a"), 0.6)
		"sink":
			_shape(ci, [Vector2(3, 11), Vector2(21, 11), Vector2(21, 14.5), Vector2(18.5, 18), Vector2(15.5, 19.5), Vector2(8.5, 19.5), Vector2(5.5, 18), Vector2(3, 14.5)], Color("8fb4c8"), Color("46687c"), 1.3)
			ci.draw_arc(Vector2(10.5, 8.5), 2.5, PI, TAU, 10, Color("46687c"), 1.8, true)
			ci.draw_line(Vector2(8, 8.5), Vector2(8, 11), Color("46687c"), 1.8)
			ci.draw_circle(Vector2(17, 6), 1.2, Color("8fb4c8"))
			ci.draw_circle(Vector2(19, 8.5), 0.9, Color("8fb4c8"))
		"coin":
			_circle(ci, Vector2(12, 12), 9.5, Color("f2b632"), Color("a96e0c"), 1.4)
			ci.draw_arc(Vector2(12, 12), 6.5, 0.0, TAU, 28, Color("ffe08a"), 1.4, true)
			ci.draw_line(Vector2(12, 7.5), Vector2(12, 16.5), Color("a96e0c"), 1.3, true)
			ci.draw_polyline(PackedVector2Array([Vector2(14.5, 10.2), Vector2(13.5, 9.2), Vector2(10.5, 9.4), Vector2(9.7, 11), Vector2(11, 12.3), Vector2(13, 12.7), Vector2(14.4, 14), Vector2(13.6, 15.4), Vector2(10.6, 15.6), Vector2(9.5, 14.6)]), Color("a96e0c"), 1.3, true)
		"happy":
			_circle(ci, Vector2(12, 12), 9.5, Color("ffd45a"), Color("a96e0c"), 1.3)
			ci.draw_circle(Vector2(8.8, 10), 1.3, Color("5a3410"))
			ci.draw_circle(Vector2(15.2, 10), 1.3, Color("5a3410"))
			ci.draw_arc(Vector2(12, 11.2), 5.0, PI * 0.18, PI * 0.82, 14, Color("5a3410"), 1.6, true)
		"angry":
			_circle(ci, Vector2(12, 12), 9.5, Color("f08a6a"), Color("8c2a12"), 1.3)
			ci.draw_line(Vector2(6.5, 8), Vector2(10.5, 9.6), Color("4a1608"), 1.7, true)
			ci.draw_line(Vector2(17.5, 8), Vector2(13.5, 9.6), Color("4a1608"), 1.7, true)
			ci.draw_circle(Vector2(9, 11.2), 1.2, Color("4a1608"))
			ci.draw_circle(Vector2(15, 11.2), 1.2, Color("4a1608"))
			ci.draw_arc(Vector2(12, 19.5), 4.6, PI * 1.2, PI * 1.8, 12, Color("4a1608"), 1.6, true)
		"star":
			_shape(ci, _star_points(Vector2(12, 12.5), 10.0, 4.3), Color("f2b632"), Color("a96e0c"), 1.2)
		"starOff":
			_shape(ci, _star_points(Vector2(12, 12.5), 10.0, 4.3), Color(0.31, 0.16, 0.04, 0.15), Color(0.31, 0.16, 0.04, 0.3), 1.2)
		"pause":
			ci.draw_rect(Rect2(6, 5, 4, 14), tint)
			ci.draw_rect(Rect2(14, 5, 4, 14), tint)
		"play":
			_shape(ci, [Vector2(7, 4.5), Vector2(19, 12), Vector2(7, 19.5)], tint, tint, 1.5)
		"snd":
			_shape(ci, [Vector2(4, 9.5), Vector2(7.5, 9.5), Vector2(12, 5.5), Vector2(12, 18.5), Vector2(7.5, 14.5), Vector2(4, 14.5)], tint)
			ci.draw_arc(Vector2(12, 12), 4.2, -0.9, 0.9, 8, tint, 1.7, true)
			ci.draw_arc(Vector2(12, 12), 7.2, -0.9, 0.9, 10, tint, 1.7, true)
		"mute":
			_shape(ci, [Vector2(4, 9.5), Vector2(7.5, 9.5), Vector2(12, 5.5), Vector2(12, 18.5), Vector2(7.5, 14.5), Vector2(4, 14.5)], tint)
			ci.draw_line(Vector2(15.5, 9.5), Vector2(20.5, 14.5), tint, 1.8, true)
			ci.draw_line(Vector2(20.5, 9.5), Vector2(15.5, 14.5), tint, 1.8, true)
		"gear":
			for i in 8:
				var a := TAU * i / 8.0
				ci.draw_line(Vector2(12, 12) + Vector2(cos(a), sin(a)) * 6.5, Vector2(12, 12) + Vector2(cos(a), sin(a)) * 9.5, tint, 3.0, true)
			ci.draw_arc(Vector2(12, 12), 6.0, 0.0, TAU, 24, tint, 3.0, true)
			ci.draw_circle(Vector2(12, 12), 2.2, tint)
		"menu":
			for i in 3:
				ci.draw_line(Vector2(5, 7 + i * 5), Vector2(19, 7 + i * 5), tint, 2.2, true)
		"person":
			ci.draw_circle(Vector2(12, 8), 4.0, Color("c9805a"))
			_shape(ci, [Vector2(4.5, 21), Vector2(5.5, 16), Vector2(8.5, 13.8), Vector2(15.5, 13.8), Vector2(18.5, 16), Vector2(19.5, 21)], Color("4c8a8e"))
		"office":
			ci.draw_circle(Vector2(12, 7.5), 3.8, Color("d79a74"))
			_shape(ci, [Vector2(5, 21), Vector2(6, 16), Vector2(9, 13.5), Vector2(15, 13.5), Vector2(18, 16), Vector2(19, 21)], Color("35465a"))
			_shape(ci, [Vector2(10.5, 14), Vector2(13.5, 14), Vector2(13, 18.6), Vector2(12, 19.4), Vector2(11, 18.6)], Color("c2410c"))
		"group":
			ci.draw_circle(Vector2(6.5, 9), 3.0, Color("d79a74"))
			ci.draw_circle(Vector2(17.5, 9), 3.0, Color("c9805a"))
			_shape(ci, [Vector2(1, 20), Vector2(2, 16), Vector2(4.5, 14), Vector2(8.5, 14), Vector2(11, 16), Vector2(12, 20)], Color("8a6bb0"))
			_shape(ci, [Vector2(12, 20), Vector2(13, 16), Vector2(15.5, 14), Vector2(19.5, 14), Vector2(22, 16), Vector2(23, 20)], Color("8a6bb0"))
			ci.draw_circle(Vector2(12, 6.5), 3.3, Color("e0aa84"))
			_shape(ci, [Vector2(6.5, 20), Vector2(7.5, 15.5), Vector2(10, 13.5), Vector2(14, 13.5), Vector2(16.5, 15.5), Vector2(17.5, 20)], Color("4c8a8e"))
		"regular":
			ci.draw_circle(Vector2(12, 9), 4.0, Color("d79a74"))
			_shape(ci, [Vector2(7, 7.5), Vector2(9, 4.6), Vector2(12, 3.6), Vector2(15, 4.6), Vector2(17, 7.5)], Color("eeeeee"))
			_shape(ci, [Vector2(8.5, 11.5), Vector2(12, 14), Vector2(15.5, 11.5), Vector2(14, 14.2), Vector2(10, 14.2)], Color("eeeeee"))
			_shape(ci, [Vector2(4.5, 21), Vector2(5.5, 16.5), Vector2(8.5, 14), Vector2(15.5, 14), Vector2(18.5, 16.5), Vector2(19.5, 21)], Color("a0522d"))
			_shape(ci, _star_points(Vector2(19.5, 4.5), 3.0, 1.3), Color("f2b632"))
		"kettle":
			_shape(ci, [Vector2(7, 11), Vector2(17, 11), Vector2(18, 20), Vector2(6, 20)], Color("b8742e"), Color("6e3f12"), 1.2)
			ci.draw_arc(Vector2(12, 8.5), 3.5, PI, TAU, 12, Color("6e3f12"), 2.0, true)
			_shape(ci, [Vector2(8.5, 11), Vector2(8.5, 8.5), Vector2(15.5, 8.5), Vector2(15.5, 11)], Color("f4efe6"), Color("6e3f12"), 1.2)
			ci.draw_circle(Vector2(12, 4.5), 1.0, Color("6e3f12"))
		"tray":
			_ellipse(ci, Vector2(12, 15), 10.0, 4.0, Color("c9cdd2"), Color("6a7078"), 1.2)
			_ellipse(ci, Vector2(12, 14), 7.0, 2.3, Color("e6e9ec"))
			ci.draw_rect(Rect2(7, 5, 3, 7), Color("c2410c"))
			ci.draw_arc(Vector2(15.5, 9), 3.0, 0.0, TAU, 14, Color("c98a2e"), 2.4, true)
		"oven":
			ci.draw_rect(Rect2(15, 2, 4, 6), Color("7a4a28"))
			ci.draw_rect(Rect2(3, 8, 18, 13), Color("a0673a"))
			ci.draw_rect(Rect2(3, 8, 18, 13), Color("5a3418"), false, 1.2)
			_shape(ci, [Vector2(7, 21), Vector2(7, 15), Vector2(9, 11.5), Vector2(12, 10), Vector2(15, 11.5), Vector2(17, 15), Vector2(17, 21)], Color("2a1810"))
			_shape(ci, [Vector2(9, 21), Vector2(9, 16), Vector2(10.5, 14), Vector2(12, 13.2), Vector2(13.5, 14), Vector2(15, 16), Vector2(15, 21)], Color("ff9a2f"))
		"apprentice":
			ci.draw_circle(Vector2(12, 7), 4.0, Color("e0aa84"))
			ci.draw_arc(Vector2(12, 6), 4.2, PI, TAU, 10, Color("3a2314"), 2.4, true)
			_shape(ci, [Vector2(5, 21), Vector2(6, 16), Vector2(9, 13.5), Vector2(15, 13.5), Vector2(18, 16), Vector2(19, 21)], Color.WHITE, Color("c9b9a4"), 1.0)
			_shape(ci, [Vector2(8.5, 21), Vector2(9.5, 14.5), Vector2(14.5, 14.5), Vector2(15.5, 21)], Color("c2410c"))
		"table":
			ci.draw_line(Vector2(12, 12), Vector2(12, 20), Color("6a3a1a"), 2.0, true)
			ci.draw_line(Vector2(8, 21), Vector2(16, 21), Color("6a3a1a"), 2.0, true)
			_ellipse(ci, Vector2(12, 9), 9.5, 4.0, Color("e9825a"), Color("8a3a1a"), 1.2)
		"stool":
			ci.draw_line(Vector2(7, 10), Vector2(5, 20), Color("6a3a1a"), 1.8, true)
			ci.draw_line(Vector2(17, 10), Vector2(19, 20), Color("6a3a1a"), 1.8, true)
			ci.draw_line(Vector2(12, 11), Vector2(12, 20), Color("6a3a1a"), 1.8, true)
			_ellipse(ci, Vector2(12, 8), 7.5, 3.3, Color("f19b4a"), Color("8a4a14"), 1.2)
		"check":
			ci.draw_polyline(PackedVector2Array([Vector2(5, 12.5), Vector2(10, 17.5), Vector2(19, 6.5)]), Color("3f8f4a"), 3.4, true)
		"dots":
			for i in 3:
				ci.draw_circle(Vector2(5.5 + i * 6.5, 12), 2.1, tint)
		_:
			ci.draw_circle(Vector2(12, 12), 8.0, tint)
