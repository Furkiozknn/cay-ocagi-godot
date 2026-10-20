class_name ItemModels
extends RefCounted
## Small vertex-coloured models of the served and carried items (same shapes as the browser version):
## a tulip tea glass on a saucer, simit on a plate, coffee cup, ayran cup, and what is left behind
## (an empty used glass, a plate with crumbs). Shared by the tray, the tables and the apprentice.

## What a finished item leaves on the table, and the tint for used cups.
const USED := {"tea": "glass", "simit": "plate", "coffee": "coffee", "ayran": "ayran", "dirty": "glass"}
const USED_TINT := {"coffee": 0x9a9088, "ayran": 0xb3aca4}

static var _meshes: Dictionary = {}
static var _tinted: Dictionary = {}


## The mesh for an item id (tea, simit, coffee, ayran) or a leftover (glass, plate).
static func mesh(kind: String) -> ArrayMesh:
	if not _meshes.has(kind):
		_meshes[kind] = _build(kind)
	return _meshes[kind]


## Mesh + tint material for a table slot / tray item: dirty leftovers use the used-glass / crumb-plate models.
static func for_slot(item: String, dirty: bool) -> Array:
	if not dirty:
		return [mesh(item), null]
	var kind: String = USED.get(item, "glass")
	return [mesh(kind), tint_material(int(USED_TINT[item])) if USED_TINT.has(item) else null]


static func tint_material(hex: int) -> StandardMaterial3D:
	if not _tinted.has(hex):
		var m := MeshMerger.material().duplicate() as StandardMaterial3D
		m.albedo_color = Color.hex(hex * 256 + 255)
		_tinted[hex] = m
	return _tinted[hex]


static func _saucer(m: MeshMerger, r: float) -> void:
	m.cyl(0, 0, 0, r, r * 0.78, 0.025, 0xf6efe2, 12, 0.0)
	m.cyl(0, 0.025, 0, r * 0.55, r * 0.55, 0.004, 0xc2410c, 12, 0.0)


static func _build(kind: String) -> ArrayMesh:
	var m := MeshMerger.new(71)
	m.jitter = 0.0
	var tulip: Array[Vector2] = [
		Vector2(0, 0.03), Vector2(0.055, 0.03), Vector2(0.07, 0.06), Vector2(0.056, 0.12),
		Vector2(0.054, 0.15), Vector2(0.072, 0.21), Vector2(0.08, 0.24),
	]
	match kind:
		"tea":
			_saucer(m, 0.13)
			m.lathe(0, 0, 0, tulip, 0xb8340e)
			m.cyl(0, 0.2, 0, 0.07, 0.07, 0.012, 0x8e230a, 10, 0.0)
			m.cyl(0, 0.228, 0, 0.079, 0.076, 0.014, 0xf3e3c8, 10, 0.0)
		"glass":
			_saucer(m, 0.13)
			m.lathe(0, 0, 0, tulip, 0xcfc6b8)
			m.cyl(0, 0.035, 0, 0.05, 0.05, 0.025, 0x8a5a3a, 8, 0.0)
		"simit":
			m.cyl(0, 0, 0, 0.19, 0.16, 0.03, 0xf6efe2, 12, 0.0)
			m.torus(0, 0.072, 0, 0.105, 0.048, 0xc7802f)
		"plate":
			m.cyl(0, 0, 0, 0.19, 0.16, 0.03, 0xe6dccb, 12, 0.0)
			m.sph(0.05, 0.035, 0.03, 0.02, 0xb07a3a, 1.0, 0.6, 1.0, 4, 3, 0.0)
			m.sph(-0.06, 0.035, -0.02, 0.016, 0xb07a3a, 1.0, 0.6, 1.0, 4, 3, 0.0)
		"coffee":
			_saucer(m, 0.12)
			var cup: Array[Vector2] = [Vector2(0, 0.025), Vector2(0.045, 0.025), Vector2(0.062, 0.06), Vector2(0.068, 0.125)]
			m.lathe(0, 0, 0, cup, 0xfbf6ec)
			m.cyl(0, 0.108, 0, 0.062, 0.062, 0.01, 0x3b2414, 10, 0.0)
			m.box(0.075, 0.06, 0, 0.03, 0.045, 0.018, 0xfbf6ec, 0.0, 0.0, 0.0, 0.0)
		"ayran":
			var cup2: Array[Vector2] = [Vector2(0, 0), Vector2(0.058, 0), Vector2(0.077, 0.19)]
			m.lathe(0, 0, 0, cup2, 0xfbfaf4)
			m.cyl(0, 0.07, 0, 0.07, 0.066, 0.045, 0x7fb3d5, 10, 0.0)
			m.cyl(0, 0.19, 0, 0.079, 0.079, 0.008, 0xeef3f6, 10, 0.0)
	return m.build()
