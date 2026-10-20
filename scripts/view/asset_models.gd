class_name AssetModels
extends RefCounted
## The generated GLB models (Higgsfield Tripo, shared with the browser version). Each one is baked into a single
## flat-shaded ArrayMesh: node transforms applied, turned to face +X (MODEL_YAW), x/z centred, base at y = 0,
## exactly like the browser's loader. A missing file returns null and the procedural part stays.

const DIR := "res://assets/models/%s.glb"
const NAMES: Array[String] = ["semaver", "oven", "coffee", "ayran", "sink", "table", "window", "ferry", "cat"]
## Turns each model to face +X (the coffee sand box was generated at 45°).
const MODEL_YAW := {"oven": PI / 2.0, "coffee": PI / 4.0, "sink": PI / 2.0, "ferry": PI / 2.0}
const GROUND_TEXTURE := "res://assets/textures/cobblestone.webp"


class Model:
	extends RefCounted
	var mesh: ArrayMesh
	## Size of the baked mesh (after the yaw), in model units.
	var size := Vector3.ONE
	var material: StandardMaterial3D
	var verts := PackedVector3Array()

	## Mean x/z of the vertices in the top `frac` of the model, times `sc`: finds a chimney (browser `topSpot`).
	func top_spot(frac: float, sc: float) -> Vector2:
		var y0 := size.y * (1.0 - frac)
		var acc := Vector2.ZERO
		var n := 0
		for v in verts:
			if v.y >= y0:
				acc += Vector2(v.x, v.z)
				n += 1
		return acc / n * sc if n > 0 else Vector2.ZERO


## --noassets keeps the fully procedural look (used to compare and to test the fallback).
static var enabled := not OS.get_cmdline_user_args().has("--noassets")
static var _cache: Dictionary = {}


## Every model that loads, by name.
static func load_all() -> Dictionary:
	var out := {}
	if not enabled:
		return out
	for n in NAMES:
		var m := get_model(n)
		if m != null:
			out[n] = m
	return out


static func get_model(model_name: String) -> Model:
	if _cache.has(model_name):
		return _cache[model_name]
	var m: Model = _bake(model_name)
	_cache[model_name] = m
	return m


static func ground_texture() -> Texture2D:
	if enabled and ResourceLoader.exists(GROUND_TEXTURE):
		return load(GROUND_TEXTURE) as Texture2D
	return null


## Lit material that matches the vertex-coloured scenery (MeshMerger.material) but reads the model's texture.
static func material_for(tex: Texture2D) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.roughness = 0.9
	mat.metallic = 0.0
	mat.metallic_specular = 0.25
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return mat


static func _bake(model_name: String) -> Model:
	var path := DIR % model_name
	if not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		push_warning("model not loaded, keeping the procedural one: %s" % model_name)
		return null
	var root := scene.instantiate()
	var yaw := Basis(Vector3.UP, float(MODEL_YAW.get(model_name, 0.0)))
	var pos := PackedVector3Array()
	var uvs := PackedVector2Array()
	var tex: Texture2D = null
	for mi in _mesh_instances(root):
		var xf := Transform3D(yaw, Vector3.ZERO) * _to_root(mi, root)
		var mesh := mi.mesh
		for si in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(si)
			var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty():
				idx.resize(v.size())
				for i in v.size():
					idx[i] = i
			for i in idx:
				pos.append(xf * v[i])
				uvs.append(uv[i] if i < uv.size() else Vector2.ZERO)
			if tex == null:
				var mat := mi.get_active_material(si) as BaseMaterial3D
				if mat != null:
					tex = mat.albedo_texture
	root.free()
	if pos.is_empty():
		return null
	# recentre x/z, base to y = 0
	var lo := pos[0]
	var hi := pos[0]
	for p in pos:
		lo = lo.min(p)
		hi = hi.max(p)
	var shift := Vector3(-(lo.x + hi.x) * 0.5, -lo.y, -(lo.z + hi.z) * 0.5)
	var normals := PackedVector3Array()
	normals.resize(pos.size())
	for i in pos.size():
		pos[i] += shift
	# flat shading: one normal per triangle (Godot's front faces are clockwise, so the cross product is flipped)
	var t := 0
	while t + 2 < pos.size():
		var n := (pos[t + 2] - pos[t]).cross(pos[t + 1] - pos[t])
		n = n.normalized() if n.length_squared() > 1e-14 else Vector3.UP
		normals[t] = n
		normals[t + 1] = n
		normals[t + 2] = n
		t += 3
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_TEX_UV] = uvs
	var out := Model.new()
	out.mesh = ArrayMesh.new()
	out.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	out.size = hi - lo
	out.verts = pos
	out.material = material_for(tex)
	out.mesh.surface_set_material(0, out.material)
	return out


static func _mesh_instances(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n as MeshInstance3D)
	for c in n.get_children():
		out.append_array(_mesh_instances(c))
	return out


## The node's transform relative to the scene root (the instance is not in the tree, so no global_transform).
static func _to_root(n: Node, root: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur := n
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	if root is Node3D:
		xf = (root as Node3D).transform * xf
	return xf
