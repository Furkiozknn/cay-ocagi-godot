class_name WorldBuilder
extends RefCounted
## Builds the static scenery (quay, tea house, counter, lamps, boats, far shore) and the
## animated characters/props as merged meshes.

const CNT_X := TeaSim.CNT_X


static func semaver(m: MeshMerger, zc: float) -> void:
	var x := CNT_X
	m.cyl(x, 1.12, zc, 0.52, 0.56, 0.12, Palette.STONE_D, 12)
	m.cyl(x, 1.24, zc, 0.46, 0.52, 0.95, Palette.BRONZE, 12)
	m.cyl(x, 1.9, zc, 0.5, 0.5, 0.07, Palette.GOLD, 12)
	m.cyl(x, 2.19, zc, 0.5, 0.5, 0.07, Palette.GOLD, 12)
	m.cyl(x, 2.26, zc, 0.3, 0.46, 0.18, Palette.BRONZE, 12)
	m.cyl(x, 2.44, zc, 0.09, 0.09, 0.38, Palette.GOLD, 8)
	m.cyl(x, 2.84, zc, 0.25, 0.31, 0.3, Palette.CREAM, 12)
	m.cyl(x, 2.9, zc, 0.32, 0.32, 0.05, Palette.RED, 12)
	m.sph(x, 3.14, zc, 0.24, Palette.CREAM, 1.0, 0.62, 1.0, 10, 6)
	m.sph(x, 3.3, zc, 0.06, Palette.GOLD, 1.0, 1.0, 1.0, 6, 4)
	m.box(x + 0.5, 1.45, zc - 0.08, 0.22, 0.08, 0.16, Palette.GOLD)
	m.box(x + 0.6, 1.35, zc - 0.08, 0.06, 0.16, 0.06, Palette.GOLD)
	m.box(x - 0.08, 2.86, zc + 0.36, 0.34, 0.06, 0.09, Palette.CREAM, 0.0, 0.0, 0.3)
	m.box(x - 0.05, 3.0, zc - 0.38, 0.16, 0.22, 0.07, Palette.CREAM)


static func geranium_pot(k: MeshMerger, x: float, z: float, s: float = 1.0) -> void:
	k.cyl(x, 0.0, z, 0.26 * s, 0.19 * s, 0.34 * s, 0xc4683a, 8)
	k.cyl(x, 0.32 * s, z, 0.29 * s, 0.29 * s, 0.06 * s, 0xa9552d, 8)
	k.sph(x, 0.55 * s, z, 0.34 * s, Palette.GREEN, 1.0, 0.7, 1.0, 7, 5)
	for i in 5:
		var a := i * 1.3
		var col := 0xdf3b4b if i % 2 == 1 else 0xf26a88
		k.sph(x + cos(a) * 0.2 * s, 0.7 * s + (i % 2) * 0.06, z + sin(a) * 0.2 * s, 0.1 * s, col, 1.0, 1.0, 1.0, 6, 4)


static func bunting(k: MeshMerger, a: Vector3, b: Vector3, n: int) -> void:
	var cols: Array[int] = [Palette.RED, Palette.CREAM, Palette.TEAL, Palette.GOLD, 0xe05a7a]
	for i in n + 1:
		var f := float(i) / n
		var x := lerpf(a.x, b.x, f)
		var z := lerpf(a.z, b.z, f)
		var y := lerpf(a.y, b.y, f) - sin(PI * f) * 0.7
		k.cone(x, y - 0.34, z, 0.17, 0.34, cols[i % cols.size()], 3, PI / 2.0, PI, 0.0)
		k.box(x, y, z, absf(b.x - a.x) / n + 0.05, 0.03, absf(b.z - a.z) / n + 0.05, Palette.DARK, atan2(-(b.z - a.z), b.x - a.x))


static func sailboat(k: MeshMerger, x: float, z: float, s: float, col: int) -> void:
	k.box(x, -0.3, z, 2.2 * s, 0.45 * s, 0.8 * s, Palette.WHITE)
	k.box(x, -0.1, z, 2.3 * s, 0.12 * s, 0.9 * s, col)
	k.cyl(x, 0.1, z, 0.04, 0.04, 2.6 * s, Palette.WOOD, 5)
	k.cone(x + 0.05, 0.1 + 0.25 * s, z - 0.02, 1.1 * s, 2.3 * s, Palette.CREAM, 3, 0.0, 0.0, 0.0, 0.06 / (1.1 * s))


static func mosque(k: MeshMerger, x: float, z: float, s: float) -> void:
	var hz := 0xa89cb4
	var hz2 := 0x9a8cae
	var hz3 := 0xb9aac0
	k.box(x, -0.3, z, 5 * s, 1.3 * s, 3.4 * s, hz)
	k.sph(x, 1.0 * s, z, 1.9 * s, hz3, 1.0, 0.8, 1.0, 10, 6)
	k.sph(x + 2.3 * s, 0.8 * s, z + 1.2 * s, 0.8 * s, hz3, 1.0, 0.8, 1.0, 8, 5)
	k.sph(x - 2.3 * s, 0.8 * s, z + 1.2 * s, 0.8 * s, hz3, 1.0, 0.8, 1.0, 8, 5)
	for ab in [Vector2(-3.1, -1.6), Vector2(3.1, -1.6), Vector2(-3.1, 1.6), Vector2(3.1, 1.6)]:
		k.cyl(x + ab.x * s, 0.0, z + ab.y * s, 0.12 * s, 0.17 * s, 4.2 * s, hz2, 6)
		k.cone(x + ab.x * s, 4.2 * s, z + ab.y * s, 0.22 * s, 0.8 * s, hz2, 6)


## Everything that never changes (one big mesh) plus the ground (a second mesh).
## `skip` lists the parts that come from a generated model instead (semaver, oven, coffee, ayran, sink, window,
## ground), like the browser's buildWorld(skip).
static func build_static(skip: Dictionary = {}) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var k := MeshMerger.new(11)
	var gd := MeshMerger.new(13)
	# ground: cobblestone offset rows
	gd.quad(-200, -9.3, 200, 200, 0.0, 0x8c7a66, 0.0)
	var tones: Array[int] = [0xc9b79a, 0xbfae92, 0xd2c1a3, 0xb7a68b, 0xc4b296]
	if not skip.has("ground"):
		for x in range(-14, 17):
			for z in range(-9, 14):
				var o := 0.45 if (z & 1) == 1 else 0.0
				gd.quad(x + o + 0.04, z + 0.04, x + o + 0.96, z + 0.96, 0.015, tones[rng.randi() % tones.size()], 0.06)
	# quay
	k.box(0, -0.32, -9.55, 90, 0.9, 0.7, Palette.STONE, 0.0, 0.0, 0.0, 0.02)
	k.box(0, 0.55, -9.55, 90, 0.08, 0.8, Palette.STONE_D, 0.0, 0.0, 0.0, 0.02)
	for x in range(-8, 31, 2):
		k.box(x, 0.6, -9.4, 0.14, 0.85, 0.14, Palette.TEAL_D)
	k.box(10, 1.4, -9.4, 76, 0.09, 0.12, Palette.TEAL)
	k.box(10, 1.0, -9.4, 76, 0.05, 0.08, Palette.TEAL)
	# tea house building
	var bx := -11.4
	k.box(bx, 0, -1, 6.6, 0.4, 16, Palette.STONE_D)
	k.box(bx + 0.1, 0.4, -1, 6.4, 5.9, 15.4, Palette.WALL)
	k.box(bx + 0.1, 6.3, -1, 6.9, 0.22, 15.9, Palette.ROOF)
	k.box(-8.35, 6.4, -1, 0.3, 0.45, 15.9, Palette.ROOF)
	k.box(-9.8, 6.5, -5.5, 1.0, 1.9, 1.0, Palette.STONE_D)
	k.box(-9.8, 8.3, -5.5, 1.2, 0.25, 1.2, Palette.STONE)
	k.box(-8.3, 4.35, -1, 0.14, 0.16, 15.4, Palette.WALL_D)
	k.box(-8.3, 5.45, -1, 0.12, 0.12, 15.4, Palette.WALL_D)
	var z := -7.0
	if not skip.has("window"):
		while z <= 6.01:
			k.box(-8.21, 5.45, z, 0.1, 0.72, 1.3, Palette.DARK)
			k.box(-8.2, 5.4, z, 0.08, 0.08, 1.45, Palette.CREAM)
			k.box(-8.2, 6.12, z, 0.08, 0.08, 1.45, Palette.CREAM)
			k.box(-8.18, 5.45, z - 0.84, 0.1, 0.7, 0.3, Palette.TEAL)
			k.box(-8.18, 5.45, z + 0.84, 0.1, 0.7, 0.3, Palette.TEAL)
			k.box(-8.0, 5.25, z, 0.3, 0.22, 1.5, Palette.WOOD)
			for i in range(-2, 3):
				k.sph(-7.95, 5.55, z + i * 0.27, 0.13, Palette.GREEN, 1.0, 0.8, 1.0, 6, 4)
				k.sph(-7.93, 5.64, z + i * 0.27, 0.075, 0xe23b4a if i % 2 != 0 else 0xf06a8a, 1.0, 1.0, 1.0, 6, 4)
			z += 3.25
	# door + step
	k.box(-8.15, 0.3, -7.6, 0.12, 2.4, 1.2, Palette.TEAL_D)
	k.box(-8.12, 0.3, -7.6, 0.08, 2.55, 1.45, Palette.CREAM, 0.0, 0.0, 0.0, 0.0)
	k.box(-8.1, 0.45, -7.6, 0.1, 2.3, 1.0, Palette.TEAL)
	k.sph(-8.0, 1.5, -7.25, 0.06, Palette.GOLD, 1.0, 1.0, 1.0, 6, 4)
	k.box(-7.55, 0, -7.6, 1.3, 0.3, 1.5, Palette.STONE)
	# sign backing
	k.box(-8.18, 4.7, 0, 0.2, 0.7, 7.8, Palette.WOOD)
	k.box(-8.1, 4.72, 0, 0.08, 0.66, 7.6, 0x2d3d3f, 0.0, 0.0, 0.0, 0.0)
	# wall shelves + tulip glasses
	k.box(-7.95, 1.85, -0.2, 0.5, 0.08, 12.8, Palette.WOOD_L)
	k.box(-7.95, 2.55, -0.2, 0.5, 0.08, 12.8, Palette.WOOD_L)
	z = -6.2
	while z <= 5.91:
		k.cyl(-7.95, 1.93, z, 0.15, 0.09, 0.26, Palette.AMBER, 8)
		k.cyl(-7.95, 2.19, z, 0.16, 0.16, 0.03, 0xf6dcc0, 8)
		if rng.randf() < 0.6:
			k.cyl(-7.95, 2.63, z, 0.07, 0.1, 0.24, 0xf0e4d2, 8)
		else:
			k.cyl(-7.95, 2.63, z, 0.15, 0.09, 0.26, Palette.AMBER, 8)
		if rng.randf() < 0.25:
			k.sph(-7.95, 2.9, z, 0.1, Palette.RED, 1.0, 1.0, 1.0, 6, 4)
		z += 0.46
	# counter
	k.box(CNT_X, 0, -0.2, 1.7, 1.0, 12.8, Palette.WOOD)
	k.box(CNT_X + 0.03, 1.0, -0.2, 1.95, 0.12, 13.0, Palette.WOOD_L)
	z = -5.6
	while z <= 5.81:
		k.box(CNT_X + 0.86, 0.18, z, 0.06, 0.64, 1.3, 0x6e4528)
		z += 1.6
	k.box(CNT_X + 0.9, 0.02, -0.2, 0.08, 0.1, 12.9, Palette.DARK)
	# striped awning + poles
	var slope := atan2(0.5, 2.3)
	var i := 0
	z = -6.55
	while z < 6.4:
		var col := Palette.CREAM if i % 2 == 1 else Palette.RED
		k.box(-7.05, 4.22, z + 0.325, 2.45, 0.08, 0.65, col, 0.0, 0.0, -slope, 0.02)
		k.box(-5.9, 3.84, z + 0.325, 0.08, 0.3, 0.65, col, 0.0, 0.0, 0.0, 0.02)
		z += 0.65
		i += 1
	k.box(-5.9, 0, -6.45, 0.1, 3.95, 0.1, Palette.CREAM)
	k.box(-5.9, 0, 6.3, 0.1, 3.95, 0.1, Palette.CREAM)
	if not skip.has("semaver"):
		semaver(k, -5.05)
	# simit oven
	var zc: float = TeaSim.STATION_Z["simit"]
	var x := CNT_X
	if not skip.has("oven"):
		_oven(k, x, zc)
	zc = TeaSim.STATION_Z["coffee"]
	if not skip.has("coffee"):
		_coffee(k, x, zc)
	zc = TeaSim.STATION_Z["ayran"]
	if not skip.has("ayran"):
		_ayran(k, x, zc)
	zc = TeaSim.STATION_Z["sink"]
	if not skip.has("sink"):
		_sink(k, x, zc)
	_quay_props(k)
	_far_shore(k, rng)
	var second := MeshMerger.new(17)
	if not skip.has("semaver"):
		semaver(second, -3.85)
	return {"world": k.build(), "ground": gd.build(), "semaver2": second.build()}


static func _oven(k: MeshMerger, x: float, zc: float) -> void:
	k.box(x, 1.12, zc, 1.55, 0.45, 1.7, Palette.STONE_D)
	k.box(x, 1.57, zc, 1.5, 1.15, 1.65, 0xa0673a)
	k.box(x, 2.72, zc, 1.62, 0.12, 1.78, Palette.ROOF)
	k.cyl(x - 0.45, 2.84, zc - 0.5, 0.16, 0.2, 0.8, Palette.STONE_D, 8)
	k.box(x + 0.77, 1.78, zc, 0.08, 0.85, 1.05, 0x2a1810)
	k.box(x + 0.79, 2.64, zc, 0.1, 0.1, 1.2, Palette.CREAM)
	k.box(x + 0.78, 1.68, zc - 0.62, 0.06, 1.0, 0.12, Palette.CREAM)
	k.box(x + 0.78, 1.68, zc + 0.62, 0.06, 1.0, 0.12, Palette.CREAM)
	k.box(x + 0.6, 1.4, zc, 0.5, 0.06, 1.5, Palette.WOOD)


static func _coffee(k: MeshMerger, x: float, zc: float) -> void:
	k.box(x, 1.12, zc, 1.5, 0.1, 1.9, Palette.DARK)
	k.box(x, 1.2, zc, 1.34, 0.08, 1.74, Palette.SAND, 0.0, 0.0, 0.0, 0.02)
	k.box(x - 0.62, 1.12, zc, 0.08, 0.3, 1.9, Palette.WOOD)
	k.box(x + 0.62, 1.12, zc, 0.08, 0.3, 1.9, Palette.WOOD)
	k.box(x, 1.12, zc - 0.93, 1.5, 0.3, 0.08, Palette.WOOD)
	k.box(x, 1.12, zc + 0.93, 1.5, 0.3, 0.08, Palette.WOOD)
	k.box(x - 0.5, 1.22, zc, 0.5, 1.1, 1.0, 0x4b4038)
	k.box(x - 0.5, 2.32, zc, 0.56, 0.08, 1.1, Palette.BRONZE)
	for sgn in [-1.0, 1.0]:
		var zz: float = zc + sgn * 0.45
		k.cyl(x + 0.05, 1.28, zz, 0.09, 0.19, 0.34, 0xc67a3a, 10)
		k.cyl(x + 0.05, 1.62, zz, 0.13, 0.1, 0.06, 0xc67a3a, 10)
		k.box(x + 0.38, 1.5, zz, 0.4, 0.05, 0.06, Palette.DARK, 0.0, 0.0, 0.25)


static func _ayran(k: MeshMerger, x: float, zc: float) -> void:
	k.box(x, 1.12, zc, 1.45, 1.75, 1.55, 0xe2eaef)
	k.box(x + 0.74, 1.3, zc, 0.06, 1.25, 1.25, 0x89b1c6)
	k.box(x + 0.76, 2.5, zc, 0.08, 0.3, 1.35, 0x3b6f94)
	for r in 3:
		for kk in range(-1, 2):
			k.cyl(x + 0.66, 1.45 + r * 0.38, zc + kk * 0.38, 0.13, 0.1, 0.22, 0xfaf6ee if r == 1 else 0xf2ecd9, 8)
	k.box(x + 0.76, 1.15, zc, 0.08, 0.1, 1.3, Palette.DARK)
	k.cyl(x - 0.3, 2.87, zc + 0.3, 0.17, 0.13, 0.3, 0xfbfaf4, 8)
	k.cyl(x - 0.3, 2.87, zc - 0.3, 0.17, 0.13, 0.3, 0xfbfaf4, 8)


static func _sink(k: MeshMerger, x: float, zc: float) -> void:
	k.box(x, 1.12, zc, 1.5, 0.5, 1.6, 0x8aa6b4)
	k.box(x + 0.05, 1.58, zc, 1.15, 0.06, 1.25, 0x5e94b0, 0.0, 0.0, 0.0, 0.0)
	k.cyl(x - 0.5, 1.62, zc, 0.06, 0.06, 0.85, 0xc9ccd0, 8)
	k.box(x - 0.3, 2.4, zc, 0.55, 0.07, 0.07, 0xc9ccd0)
	k.box(x - 0.6, 1.62, zc + 0.74, 0.4, 0.06, 0.5, 0xa0b0b8)
	for j in 4:
		k.cyl(x - 0.62 + (j % 2) * 0.2, 1.68 + (0.24 if j > 1 else 0.0), zc + 0.66 + (j % 2) * 0.1, 0.09, 0.07, 0.22, 0xcfd6d4, 6)


static func _quay_props(k: MeshMerger) -> void:
	# lamp posts + bunting
	for lp in [Vector2(6.0, -8.7), Vector2(-3.6, -8.7)]:
		k.cyl(lp.x, 0, lp.y, 0.26, 0.32, 0.4, Palette.TEAL_D, 8)
		k.cyl(lp.x, 0.4, lp.y, 0.07, 0.09, 3.7, Palette.TEAL_D, 8)
		k.box(lp.x, 4.05, lp.y, 0.56, 0.08, 0.56, Palette.TEAL_D)
		k.cone(lp.x, 4.35, lp.y, 0.4, 0.35, Palette.TEAL_D, 4)
	bunting(k, Vector3(6.0, 4.0, -8.7), Vector3(-3.6, 4.0, -8.7), 18)
	bunting(k, Vector3(-3.6, 4.0, -8.7), Vector3(-5.9, 3.9, -6.45), 6)
	for px in [-1.5, 2.2, 9.2, 12.5]:
		geranium_pot(k, px, -8.55)
	geranium_pot(k, -5.1, -7.7, 0.9)
	geranium_pot(k, -5.1, 6.9, 0.9)
	geranium_pot(k, 12.2, 4.6, 1.0)
	k.box(10.0, 0, -8.6, 0.9, 0.6, 0.8, Palette.WOOD_L)
	k.box(10.1, 0.6, -8.55, 0.8, 0.5, 0.7, Palette.WOOD)
	k.box(11.2, 0, -8.6, 0.8, 0.5, 0.8, Palette.WOOD_L)


static func _far_shore(k: MeshMerger, rng: RandomNumberGenerator) -> void:
	# sailboats, far shore, hills
	sailboat(k, 1.5, -17.5, 1.0, Palette.RED)
	sailboat(k, -7.5, -23.0, 1.2, Palette.TEAL)
	sailboat(k, 9.0, -25.0, 0.9, Palette.GOLD)
	mosque(k, -3, -29, 1.5)
	mosque(k, 13, -33, 1.3)
	var hz := 0xa89cb4
	var hz2 := 0x9a8cae
	for n in 26:
		var hx := -22.0 + n * 1.9 + rng.randf()
		var hzz := -29.5 - rng.randf() * 2.0
		var h := 1.0 + rng.randf() * 1.8
		k.box(hx - 6, -0.3, hzz + 3, 1.6, h + 0.3, 1.5, hz if n % 3 != 0 else hz2)
		k.box(hx - 6, h, hzz + 3, 1.8, 0.16, 1.7, 0xa9795f, 0.0, 0.0, 0.0, 0.02)
	k.sph(-4, -2, -42, 20, 0xb6aebe, 1.0, 0.32, 0.5, 12, 6)
	k.sph(24, -2, -46, 22, 0xbfb2bf, 1.0, 0.3, 0.5, 12, 6)


# ---- characters and animals ------------------------------------------------

static func person_body(body_color: int) -> ArrayMesh:
	var b := MeshMerger.new(31)
	b.jitter = 0.0
	b.cyl(0, 0, 0, 0.21, 0.29, 0.8, body_color, 8)
	b.sph(-0.27, 0.55, 0, 0.1, body_color, 1.0, 1.5, 1.0, 5, 4)
	b.sph(0.27, 0.55, 0, 0.1, body_color, 1.0, 1.5, 1.0, 5, 4)
	return b.build()


static func person_head(skin: int, hair: int, capped: bool, cap_color: int) -> ArrayMesh:
	var h := MeshMerger.new(33)
	h.jitter = 0.0
	h.sph(0, 0, 0, 0.22, skin, 1.0, 1.0, 1.0, 10, 8)
	h.box(0, -0.04, 0.22, 0.07, 0.09, 0.08, skin)
	h.box(-0.08, 0.04, 0.205, 0.05, 0.05, 0.04, 0x1b1410)
	h.box(0.08, 0.04, 0.205, 0.05, 0.05, 0.04, 0x1b1410)
	if capped:
		h.cyl(0, 0.04, 0, 0.23, 0.24, 0.11, cap_color, 10)
		h.box(0, 0.04, 0.24, 0.26, 0.03, 0.16, cap_color)
		h.sph(0, 0.03, -0.02, 0.2, hair, 1.0, 0.45, 1.0, 8, 4, 0.0, -0.3)
	else:
		h.sph(0, 0.0, -0.02, 0.245, hair, 1.0, 1.0, 1.0, 10, 6, 0.0, -0.1)
	return h.build()


static func waiter(shirt: int, vest: int, apron: int, hair: int) -> ArrayMesh:
	var m := MeshMerger.new(41)
	m.jitter = 0.02
	m.cyl(0, 0, 0, 0.27, 0.3, 0.5, 0x2b2f3a, 10)
	m.cyl(0, 0.5, 0, 0.21, 0.27, 0.5, shirt, 10)
	m.cyl(0, 0.5, 0, 0.23, 0.285, 0.42, vest, 10)
	m.cyl(0, 0.26, 0.02, 0.31, 0.32, 0.5, apron, 10)
	m.sph(-0.3, 0.95, 0, 0.1, shirt, 1.0, 1.4, 1.0, 6, 4)
	m.sph(0.3, 0.95, 0, 0.1, shirt, 1.0, 1.4, 1.0, 6, 4)
	m.sph(0, 1.28, 0, 0.23, 0xe9bd96, 1.0, 1.0, 1.0, 10, 8, 0.0)
	m.box(0, 1.22, 0.22, 0.07, 0.09, 0.08, 0xe2b08a, 0.0, 0.0, 0.0, 0.0)
	m.box(-0.08, 1.32, 0.21, 0.05, 0.05, 0.04, 0x1b1410, 0.0, 0.0, 0.0, 0.0)
	m.box(0.08, 1.32, 0.21, 0.05, 0.05, 0.04, 0x1b1410, 0.0, 0.0, 0.0, 0.0)
	m.sph(0, 1.29, -0.02, 0.25, hair, 1.0, 1.0, 1.0, 10, 6, 0.0, -0.1)
	m.box(0, 1.2, 0.1, 0.3, 0.06, 0.09, 0x1b1410, 0.0, 0.0, 0.0, 0.0)
	m.cyl(0, 1.0, 0.5, 0.42, 0.42, 0.04, 0xcfd3d8, 14)
	m.cyl(0, 1.04, 0.5, 0.36, 0.36, 0.02, 0xe9ecef, 14, 0.0)
	m.box(-0.3, 0.95, 0.3, 0.08, 0.06, 0.4, shirt, 0.4)
	m.box(0.3, 0.95, 0.3, 0.08, 0.06, 0.4, shirt, -0.4)
	return m.build()


static func cat() -> ArrayMesh:
	var m := MeshMerger.new(43)
	var fur := 0xd98a3e
	var wh := 0xf3ebdc
	m.sph(0, 0.24, 0, 0.27, fur, 1.35, 0.85, 0.85, 8, 6)
	m.sph(0.34, 0.38, 0, 0.17, fur, 1.0, 1.0, 1.0, 8, 6)
	m.cone(0.36, 0.5, -0.1, 0.06, 0.13, fur, 4)
	m.cone(0.36, 0.5, 0.1, 0.06, 0.13, fur, 4)
	m.sph(0.5, 0.35, 0, 0.06, wh, 1.0, 0.8, 1.2, 5, 4)
	m.box(0.47, 0.39, -0.07, 0.03, 0.03, 0.03, 0x1b1410, 0.0, 0.0, 0.0, 0.0)
	m.box(0.47, 0.39, 0.07, 0.03, 0.03, 0.03, 0x1b1410, 0.0, 0.0, 0.0, 0.0)
	for lg in [Vector2(-0.2, -0.14), Vector2(-0.2, 0.14), Vector2(0.18, -0.14), Vector2(0.18, 0.14)]:
		m.box(lg.x, 0, lg.y, 0.1, 0.2, 0.1, wh if lg.x > 0.0 else fur)
	m.sph(-0.4, 0.3, 0.06, 0.09, fur, 1.6, 0.6, 0.6, 6, 4)
	m.sph(-0.52, 0.42, 0.1, 0.07, wh, 1.2, 1.0, 1.0, 6, 4)
	m.sph(0, 0.2, 0, 0.15, wh, 1.0, 0.93, 1.8, 8, 6)
	return m.build()


static func gull() -> ArrayMesh:
	var m := MeshMerger.new(47)
	m.jitter = 0.0
	m.sph(0, 0, 0, 0.2, 0xfafafa, 1.6, 0.7, 0.7, 6, 4)
	m.box(-0.02, 0, 0.08, 0.24, 0.025, 0.5, 0xe8e8ea, 0.0, 0.3)
	m.box(-0.02, 0, -0.08, 0.24, 0.025, 0.5, 0xe8e8ea, 0.0, -0.3)
	m.cone(0.34, -0.03, 0, 0.035, 0.1, 0xf2a03a, 4, 0.0, 0.0, -PI / 2.0)
	return m.build()


static func ferry() -> ArrayMesh:
	var m := MeshMerger.new(53)
	m.box(0, -0.4, 0, 8, 0.95, 2.4, 0xf4f1ea, 0.0, 0.0, 0.0, 0.01)
	m.box(0, 0.1, 0, 8.05, 0.22, 2.45, 0x2f5675, 0.0, 0.0, 0.0, 0.0)
	m.box(4.2, -0.3, 0, 1.3, 0.85, 1.7, 0xf4f1ea, 0.0, 0.0, 0.0, 0.01)
	m.box(-0.3, 0.55, 0, 6.4, 0.9, 2.0, 0xf6eed8)
	m.box(-0.2, 1.45, 0, 4.2, 0.8, 1.7, 0xf6eed8)
	m.box(-0.3, 0.8, 1.01, 6.2, 0.3, 0.04, 0x2b3a48)
	m.box(-0.2, 1.7, 0.86, 4.0, 0.28, 0.04, 0x2b3a48)
	m.box(-0.3, 0.8, -1.01, 6.2, 0.3, 0.04, 0x2b3a48)
	m.box(-0.2, 2.25, 0, 4.4, 0.1, 1.9, Palette.RED)
	m.cyl(0.6, 2.35, 0, 0.38, 0.42, 1.2, Palette.RED, 10)
	m.cyl(0.6, 3.45, 0, 0.4, 0.38, 0.2, 0x20140f, 10)
	m.cyl(-1.6, 2.35, 0, 0.25, 0.28, 0.9, Palette.RED, 10)
	m.cyl(-1.6, 3.2, 0, 0.27, 0.25, 0.16, 0x20140f, 10)
	m.cyl(3.0, 1.6, 0, 0.04, 0.04, 2.2, 0xdddddd, 5)
	return m.build()
