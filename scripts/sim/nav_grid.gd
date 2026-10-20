class_name NavGrid
extends RefCounted
## Walkable floor of the tea house on a 0.5 m grid, with A* path finding and
## line-of-sight smoothing. Tables (and the counter side) are solid.

const ORIGIN := Vector2(-9.0, -9.5)
const CELL := 0.5
const WIDTH := 48
const HEIGHT := 40
const TABLE_RADIUS := 1.25

var _astar := AStarGrid2D.new()


func _init(table_positions: Array[Vector2] = []) -> void:
	_astar.region = Rect2i(0, 0, WIDTH, HEIGHT)
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()
	rebuild(table_positions)


## Re-marks solid cells for the given (unlocked) table centres.
func rebuild(table_positions: Array[Vector2]) -> void:
	for iz in HEIGHT:
		for ix in WIDTH:
			var p := cell_center(Vector2i(ix, iz))
			var solid := p.x < -5.7 or p.y < -8.2
			if not solid:
				for tp in table_positions:
					if p.distance_to(tp) < TABLE_RADIUS:
						solid = true
						break
			_astar.set_point_solid(Vector2i(ix, iz), solid)


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - ORIGIN.x) / CELL), floori((p.y - ORIGIN.y) / CELL))


func cell_center(c: Vector2i) -> Vector2:
	return ORIGIN + (Vector2(c) + Vector2(0.5, 0.5)) * CELL


func cell_free(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < WIDTH and c.y < HEIGHT and not _astar.is_point_solid(c)


func is_free(p: Vector2) -> bool:
	return cell_free(cell_of(p))


func nearest_free(c: Vector2i) -> Vector2i:
	c = Vector2i(clampi(c.x, 0, WIDTH - 1), clampi(c.y, 0, HEIGHT - 1))
	if cell_free(c):
		return c
	var best := c
	var best_d := 1 << 30
	var found := false
	for r in range(1, 12):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var n := Vector2i(c.x + dx, c.y + dz)
				if cell_free(n):
					var d := dx * dx + dz * dz
					if d < best_d:
						best_d = d
						best = n
						found = true
		if found:
			break
	return best


func line_of_sight(a: Vector2, b: Vector2) -> bool:
	var d := a.distance_to(b)
	var n := maxi(1, ceili(d / 0.2))
	for i in range(1, n + 1):
		if not is_free(a.lerp(b, float(i) / n)):
			return false
	return true


## Shortest smoothed route; always ends exactly at `to`.
func find_path(from: Vector2, to: Vector2) -> Array[Vector2]:
	var s := nearest_free(cell_of(from))
	var t := nearest_free(cell_of(to))
	var out: Array[Vector2] = []
	if s == t:
		out.append(to)
		return out
	var ids: Array[Vector2i] = _astar.get_id_path(s, t)
	if ids.is_empty():
		out.append(to)
		return out
	var pts: Array[Vector2] = [from]
	for k in range(1, ids.size() - 1):
		pts.append(cell_center(ids[k]))
	pts.append(to)
	var i := 0
	while i < pts.size() - 1:
		var j := pts.size() - 1
		while j > i + 1 and not line_of_sight(pts[i], pts[j]):
			j -= 1
		out.append(pts[j])
		i = j
	return out
