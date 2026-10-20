class_name TableView
extends Node3D
## One café table: cloth-covered top, stools, optional cushions and the glasses/plates
## that customers leave behind. With the generated table model the top and leg come from
## WorldView's table MultiMesh and this node keeps the stools, cushions and items.

const CLOTH: Array[int] = [0xd9693a, 0x3f8a92, 0xe0a63f, 0xb85a7a, 0x6a9a4a, 0xd9693a]
const SLOT_COUNT := 6

static var _cushion_mesh: CylinderMesh

var index := 0
var unlocked := false
var _cushions: Array[MeshInstance3D] = []
var _slots: Array[MeshInstance3D] = []
var _shown := false
## Height of the table top (items stand on it).
var _top_y := 0.94


func setup(i: int, model_top: bool = false) -> void:
	index = i
	position = Vector3(TeaSim.TABLE_POS[i].x, 0.0, TeaSim.TABLE_POS[i].y)
	if _cushion_mesh == null:
		_cushion_mesh = CylinderMesh.new()
		_cushion_mesh.top_radius = 0.29
		_cushion_mesh.bottom_radius = 0.29
		_cushion_mesh.height = 0.08
		_cushion_mesh.radial_segments = 8
	var m := MeshMerger.new(60 + i)
	m.jitter = 0.0
	if model_top:
		_top_y = 0.98
	else:
		m.cyl(0, 0, 0, 0.34, 0.4, 0.06, 0x4a3a30, 10)
		m.cyl(0, 0.06, 0, 0.08, 0.08, 0.84, 0x4a3a30, 8)
		m.cyl(0, 0.84, 0, 0.88, 0.88, 0.09, CLOTH[i], 16)
		m.cyl(0, 0.93, 0, 0.9, 0.9, 0.01, CLOTH[i], 16)
	var stool_cols: Array[int] = [0x3f7f86, 0xc2602a, 0x3f7f86, 0xc2602a]
	for k in 4:
		var a := TeaSim.SEAT_ANGLES[k]
		m.cyl(cos(a) * 0.98, 0.0, sin(a) * 0.98, 0.27, 0.2, 0.5, stool_cols[k], 8)
	var base := MeshInstance3D.new()
	base.mesh = m.build()
	add_child(base)
	for k in 4:
		var a2 := TeaSim.SEAT_ANGLES[k]
		var c := MeshInstance3D.new()
		c.mesh = _cushion_mesh
		c.material_override = Palette.flat(0xf08c3a)
		c.position = Vector3(cos(a2) * 0.98, 0.52, sin(a2) * 0.98)
		c.visible = false
		add_child(c)
		_cushions.append(c)
	for k in SLOT_COUNT:
		var s := MeshInstance3D.new()
		var ang := k * 1.047 + 0.5
		s.position = Vector3(cos(ang) * 0.45, _top_y, sin(ang) * 0.45)
		s.rotation.y = -ang
		s.visible = false
		add_child(s)
		_slots.append(s)
	visible = false


func update_view(tb: TeaSim.Table, stool_level: int) -> void:
	if tb.unlocked != _shown:
		_shown = tb.unlocked
		visible = _shown
		if _shown and is_inside_tree():
			scale = Vector3(0.01, 0.01, 0.01)
			create_tween().tween_property(self, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not _shown:
		return
	for c in _cushions:
		c.visible = stool_level > 0
		c.scale = Vector3(1.08, 1.6, 1.08) if stool_level > 1 else Vector3.ONE
	for k in SLOT_COUNT:
		var node := _slots[k]
		if k >= tb.slots.size():
			node.visible = false
			continue
		var slot: Dictionary = tb.slots[k]
		node.visible = true
		var look := ItemModels.for_slot(slot["item"], slot["dirty"])
		if node.mesh != look[0] or node.material_override != look[1]:
			node.mesh = look[0]
			node.material_override = look[1]
