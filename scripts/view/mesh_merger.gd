class_name MeshMerger
extends RefCounted
## Collects primitives (boxes, cylinders, spheres, cones) into one vertex-coloured,
## flat-shaded ArrayMesh. One merged mesh is one draw call, which keeps the tea house
## cheap on an integrated GPU.

static var _prim_cache: Dictionary = {}
static var _material: StandardMaterial3D = null

var jitter := 0.045
var _verts := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 7) -> void:
	_rng.seed = seed_value


## Shared material for every merged mesh (vertex colours are sRGB).
static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.roughness = 0.9
		_material.metallic = 0.0
		_material.metallic_specular = 0.25
	return _material


static func _primitive(key: String, make: Callable) -> Array:
	if not _prim_cache.has(key):
		var mesh: Mesh = make.call()
		var arrays := mesh.surface_get_arrays(0)
		_prim_cache[key] = [arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_INDEX], arrays[Mesh.ARRAY_NORMAL]]
	return _prim_cache[key]


func _add(prim: Array, xf: Transform3D, color: Color, jit: float, clip_y: float = -99.0) -> void:
	var src: PackedVector3Array = prim[0]
	var idx: PackedInt32Array = prim[1]
	var nrm: PackedVector3Array = prim[2]
	var f := 1.0 + (_rng.randf() - 0.5) * 2.0 * (jitter if jit < 0.0 else jit)
	var col := Color(color.r * f, color.g * f, color.b * f, 1.0)
	var tri := 0
	while tri < idx.size():
		var ia := idx[tri]
		var ib := idx[tri + 1]
		var ic := idx[tri + 2]
		tri += 3
		if clip_y > -98.0 and (src[ia].y + src[ib].y + src[ic].y) / 3.0 < clip_y:
			continue
		var a := xf * src[ia]
		var b := xf * src[ib]
		var c := xf * src[ic]
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-12:
			continue
		n = n.normalized()
		var ref_n := xf.basis * (nrm[ia] + nrm[ib] + nrm[ic])
		if n.dot(ref_n) < 0.0:
			n = -n
		_verts.append(a)
		_verts.append(b)
		_verts.append(c)
		_normals.append(n)
		_normals.append(n)
		_normals.append(n)
		_colors.append(col)
		_colors.append(col)
		_colors.append(col)


func _xf(pos: Vector3, scale: Vector3, ry: float, rx: float, rz: float) -> Transform3D:
	var basis := Basis.from_euler(Vector3(rx, ry, rz), EULER_ORDER_YXZ) * Basis.from_scale(scale)
	return Transform3D(basis, pos)


## Box with its bottom at y.
func box(x: float, y: float, z: float, w: float, h: float, d: float, color: int, ry: float = 0.0, rx: float = 0.0, rz: float = 0.0, jit: float = -1.0) -> void:
	var prim := _primitive("box", func() -> Mesh:
		var m := BoxMesh.new()
		m.size = Vector3.ONE
		return m)
	_add(prim, _xf(Vector3(x, y + h / 2.0, z), Vector3(w, h, d), ry, rx, rz), Color.hex(color * 256 + 255), jit)


## Cylinder (or truncated cone) standing on y.
func cyl(x: float, y: float, z: float, rt: float, rb: float, h: float, color: int, seg: int = 10, jit: float = -1.0) -> void:
	var prim := _primitive("cyl%d" % seg, func() -> Mesh:
		var m := CylinderMesh.new()
		m.top_radius = 1.0
		m.bottom_radius = 1.0
		m.height = 1.0
		m.radial_segments = seg
		m.rings = 1
		return m)
	# radii differ per call: bake them into the scale of top/bottom by building per-call vertices
	_add_cyl(prim, Vector3(x, y + h / 2.0, z), rt, rb, h, color, jit)


func _add_cyl(prim: Array, pos: Vector3, rt: float, rb: float, h: float, color: int, jit: float) -> void:
	var src: PackedVector3Array = prim[0]
	var warped := PackedVector3Array()
	warped.resize(src.size())
	for i in src.size():
		var v := src[i]
		var r := rt if v.y > 0.0 else rb
		warped[i] = Vector3(v.x * r, v.y, v.z * r)
	_add([warped, prim[1], prim[2]], Transform3D(Basis.from_scale(Vector3(1.0, h, 1.0)), pos), Color.hex(color * 256 + 255), jit)


## Sphere centred at y. Triangles whose centre is below clip_y (in radii) are dropped.
func sph(x: float, y: float, z: float, r: float, color: int, sx: float = 1.0, sy: float = 1.0, sz: float = 1.0, ws: int = 8, hs: int = 6, jit: float = -1.0, clip_y: float = -99.0) -> void:
	var prim := _primitive("sph%d_%d" % [ws, hs], func() -> Mesh:
		var m := SphereMesh.new()
		m.radius = 1.0
		m.height = 2.0
		m.radial_segments = ws
		m.rings = hs
		return m)
	_add(prim, _xf(Vector3(x, y, z), Vector3(r * sx, r * sy, r * sz), 0.0, 0.0, 0.0), Color.hex(color * 256 + 255), jit, clip_y)


## Cone standing on y.
func cone(x: float, y: float, z: float, r: float, h: float, color: int, seg: int = 8, ry: float = 0.0, rx: float = 0.0, rz: float = 0.0, depth: float = 1.0) -> void:
	var prim := _primitive("cone%d" % seg, func() -> Mesh:
		var m := CylinderMesh.new()
		m.top_radius = 0.0
		m.bottom_radius = 1.0
		m.height = 1.0
		m.radial_segments = seg
		m.rings = 1
		return m)
	_add(prim, _xf(Vector3(x, y + h / 2.0, z), Vector3(r, h, r * depth), ry, rx, rz), Color.hex(color * 256 + 255), -1.0)


## Flat horizontal quad (top faces up).
func quad(x0: float, z0: float, x1: float, z1: float, y: float, color: int, jit: float = 0.05) -> void:
	var f := 1.0 + (_rng.randf() - 0.5) * 2.0 * jit
	var base := Color.hex(color * 256 + 255)
	var col := Color(base.r * f, base.g * f, base.b * f, 1.0)
	var pts := [
		Vector3(x0, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1),
		Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1),
	]
	for p in pts:
		_verts.append(p)
		_normals.append(Vector3.UP)
		_colors.append(col)


func build() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if _verts.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material())
	return mesh
