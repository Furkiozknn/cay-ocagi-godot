class_name PersonView
extends Node3D
## Visual of one customer: a merged body mesh and a head mesh that can turn.

var person: TeaSim.Person
var _body: MeshInstance3D
var _head: MeshInstance3D
var _seed := 0.0


func setup(p: TeaSim.Person, index: int) -> void:
	person = p
	_seed = float(index)
	_body = MeshInstance3D.new()
	_body.mesh = WorldBuilder.person_body(p.body_color)
	_head = MeshInstance3D.new()
	_head.mesh = WorldBuilder.person_head(p.skin_color, p.hair_color, p.capped, 0x3a4a6a)
	add_child(_body)
	add_child(_head)
	visible = false


func update_view(t: float) -> void:
	var pe := person
	if pe.delay > 0.0 and not pe.leaving:
		visible = false
		return
	visible = true
	var seated := pe.sitting
	var moving := pe.moving
	var phase := t * 9.0 + _seed
	var by := 0.32 if seated else (absf(sin(phase)) * 0.06 if moving else 0.0)
	var lean := sin(phase) * 0.07 if moving else 0.0
	var shake := sin(t * 40.0) * 0.05 * pe.flash if pe.flash > 0.0 else 0.0
	var s := pe.big
	position = Vector3(pe.pos.x + shake, 0.0, pe.pos.y)
	_body.position = Vector3(0, by, 0)
	_body.rotation = Vector3(0, pe.face, lean)
	_body.scale = Vector3(s, 1.0, s)
	var look := sin(t * 0.7 + _seed) * 0.15 if (seated and pe.arrived) else 0.0
	_head.position = Vector3(0, by + 1.02 * s, 0)
	_head.rotation = Vector3(0, pe.face + look, lean * 0.5)
	_head.scale = Vector3(s, s, s)
