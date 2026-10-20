class_name Fx
extends Node3D
## Pooled CPUParticles3D bursts (sparks, hearts, anger puffs) and continuous emitters
## (kettle steam, oven smoke). Soft round billboards, no texture files.

const KINDS := {
	"steam": {"color": Color(0.98, 0.96, 0.93, 0.55), "life": 1.6, "vmin": 0.5, "vmax": 0.9, "spread": 14.0, "grav": Vector3(0, 0.15, 0), "smin": 0.3, "smax": 0.55, "grow": 1.8},
	"smoke": {"color": Color(0.62, 0.56, 0.52, 0.5), "life": 2.2, "vmin": 0.5, "vmax": 0.8, "spread": 20.0, "grav": Vector3(0, 0.1, 0), "smin": 0.35, "smax": 0.7, "grow": 1.8},
	"spark": {"color": Color(1.0, 0.84, 0.3, 1.0), "life": 0.7, "vmin": 1.6, "vmax": 3.0, "spread": 70.0, "grav": Vector3(0, -5, 0), "smin": 0.1, "smax": 0.18, "grow": 0.3},
	"heart": {"color": Color(1.0, 0.42, 0.55, 0.95), "life": 1.3, "vmin": 0.7, "vmax": 1.1, "spread": 20.0, "grav": Vector3.ZERO, "smin": 0.2, "smax": 0.3, "grow": 1.2},
	"anger": {"color": Color(0.92, 0.24, 0.14, 0.85), "life": 0.9, "vmin": 1.0, "vmax": 1.6, "spread": 50.0, "grav": Vector3.ZERO, "smin": 0.18, "smax": 0.3, "grow": 1.3},
}
const POOL_SIZE := 4

var _pools: Dictionary = {}
var _next: Dictionary = {}
var _mat: StandardMaterial3D
var _mesh: QuadMesh


func _ready() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.vertex_color_use_as_albedo = true
	_mat.albedo_texture = tex
	_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_mat.billboard_keep_scale = true
	_mat.no_depth_test = false
	_mat.disable_receive_shadows = true
	_mesh = QuadMesh.new()
	_mesh.size = Vector2.ONE
	_mesh.material = _mat
	for kind in KINDS:
		var arr: Array[CPUParticles3D] = []
		for i in POOL_SIZE:
			var p := _make(kind, true, 8)
			add_child(p)
			arr.append(p)
		_pools[kind] = arr
		_next[kind] = 0


func _make(kind: String, one_shot: bool, amount: int) -> CPUParticles3D:
	var k: Dictionary = KINDS[kind]
	var p := CPUParticles3D.new()
	p.mesh = _mesh
	p.amount = amount
	p.lifetime = k["life"]
	p.one_shot = one_shot
	p.explosiveness = 0.9 if one_shot else 0.0
	p.emitting = false
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = k["spread"]
	p.gravity = k["grav"]
	p.initial_velocity_min = k["vmin"]
	p.initial_velocity_max = k["vmax"]
	p.scale_amount_min = k["smin"]
	p.scale_amount_max = k["smax"]
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.6))
	curve.add_point(Vector2(1, k["grow"]))
	p.scale_amount_curve = curve
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.12
	p.color = k["color"]
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.6, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)])
	p.color_ramp = ramp
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## One-shot burst of `count` particles at a world position.
func burst(kind: String, pos: Vector3, count: int) -> void:
	if not _pools.has(kind):
		return
	var arr: Array = _pools[kind]
	var i: int = _next[kind]
	_next[kind] = (i + 1) % arr.size()
	var p: CPUParticles3D = arr[i]
	p.global_position = pos
	p.amount = maxi(1, int(count * (0.5 if Settings.is_low() else 1.0)))
	p.restart()
	p.emitting = true


## A continuous emitter that the caller switches on and off with `emitting`.
func make_emitter(kind: String, pos: Vector3, amount: int = 6) -> CPUParticles3D:
	var p := _make(kind, false, _emitter_amount(amount))
	p.position = pos
	p.set_meta("base_amount", amount)
	add_child(p)
	return p


func _emitter_amount(base: int) -> int:
	return maxi(2, int(base * (0.5 if Settings.is_low() else 1.0)))


## Low quality halves the continuous emitters too (they are made once, so a quality change resizes them here).
func apply_quality() -> void:
	for c in get_children():
		if c is CPUParticles3D and c.has_meta("base_amount"):
			var want := _emitter_amount(int(c.get_meta("base_amount")))
			if (c as CPUParticles3D).amount != want:
				(c as CPUParticles3D).amount = want
