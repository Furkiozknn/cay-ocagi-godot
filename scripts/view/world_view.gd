class_name WorldView
extends Node3D
## The 3D tea house: builds the scenery (procedural, with the generated GLB models where they load), then mirrors
## the simulation (tables, people, waiter, stations) every frame and runs the ambient life (cat, gulls, ferry).

const CNT_X := TeaSim.CNT_X
## Counter top: the station models stand on it.
const TOP := 1.12
const CAT_HOME := Vector2(-7.55, -7.6)
const SEA_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec3 deep : source_color = vec3(0.29, 0.59, 0.65);
uniform vec3 shallow : source_color = vec3(0.24, 0.51, 0.58);
uniform vec3 foam : source_color = vec3(0.82, 0.94, 0.95);
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float w1 = sin(wp.x * 0.35 + TIME * 0.5 + sin(wp.z * 0.21) * 2.0);
	float w2 = sin(wp.z * 0.9 - TIME * 0.35 + wp.x * 0.12);
	float band = smoothstep(0.72, 0.98, w1 * w2 * 0.5 + 0.5);
	vec3 col = mix(deep, shallow, 0.5 + 0.5 * w1 * 0.4);
	col = mix(col, foam, band * 0.32);
	ALBEDO = col;
}
"""

var hover_kind := ""
var hover_id := -1

var _sim: TeaSim = null
var _vt := 0.0
var _people: Dictionary = {}
var _person_serial := 0
var _tables: Array[TableView] = []
var _waiter: Node3D
var _tray_items: Array[MeshInstance3D] = []
var _apprentice: Node3D
var _appr_item: MeshInstance3D
var _semaver2: MeshInstance3D
var _models: Dictionary = {}
var _table_mm: MultiMeshInstance3D = null
var _table_scale := Vector3.ONE
## Effect anchors on the station props; the generated models move them (browser `FIT`).
var _tea_steam_y := 3.3
var _ring_x := CNT_X + 0.05
var _ring_y := 2.86
var _smoke_pos := Vector3(CNT_X - 0.45, 3.7, TeaSim.STATION_Z["simit"] - 0.5)
var _pots: Array[Vector3] = [
	Vector3(CNT_X + 0.05, 1.66, TeaSim.STATION_Z["coffee"] - 0.45),
	Vector3(CNT_X + 0.05, 1.66, TeaSim.STATION_Z["coffee"] + 0.45),
]
var _pot_steam_dy := 0.24
var _oven_glow: MeshInstance3D
var _oven_mat: StandardMaterial3D
var _rings: Array[MeshInstance3D] = []
var _foam: Array[MeshInstance3D] = []
var _foam_mats: Array[StandardMaterial3D] = []
var _steam_kettles: Array[CPUParticles3D] = []
var _steam_pots: Array[CPUParticles3D] = []
var _smoke_oven: CPUParticles3D
var _cat: Node3D
var _cat_nav: NavGrid
var _cat_state := "sleep"
var _cat_t := 16.0
var _cat_mover := TeaSim.Mover.new()
var _cat_pet := 0.0
var _gulls: Array[Node3D] = []
var _gull_params: Array[Dictionary] = []
var _ferry: Node3D
var _ferry_x := -44.0
var _ferry_horn := false
var _hover_ring: MeshInstance3D
var _sway_player: AnimationPlayer
var _rng := RandomNumberGenerator.new()

@onready var sun: DirectionalLight3D = $Sun
@onready var rig: CameraRig = $CameraRig
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var scenery: Node3D = $Scenery
@onready var props: Node3D = $Props
@onready var people: Node3D = $People
@onready var fx: Fx = $Fx
@onready var sign_label: Label3D = $Scenery/Sign


func _ready() -> void:
	_rng.randomize()
	_setup_environment()
	_build_scenery()
	_build_dynamic()
	apply_quality()
	Settings.changed.connect(apply_quality)
	_build_title_sway()
	GameState.phase_changed.connect(_on_phase)
	_on_phase(GameState.phase)
	GameState.sim_created.connect(_on_sim_created)
	if GameState.sim != null:
		_on_sim_created(GameState.sim)


func _setup_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("f08a50")
	sky_mat.sky_horizon_color = Color("ffd9a0")
	sky_mat.ground_horizon_color = Color("ffd9a0")
	sky_mat.ground_bottom_color = Color("f6c58a")
	sky_mat.sky_curve = 0.25
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("ffe2b8")
	env.ambient_light_energy = 0.26
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.tonemap_white = 5.0
	env.fog_enabled = true
	env.fog_light_color = Color("f5cfa0")
	env.fog_density = 0.0028
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.04
	world_env.environment = env
	sun.light_color = Color("ffd29a")
	sun.light_energy = 0.45
	sun.position = Vector3(4.0, 15.0, 9.0)
	sun.look_at(Vector3(-4.0, 0.0, -1.95), Vector3.UP)
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 70.0


func apply_quality() -> void:
	var low := Settings.is_low()
	fx.apply_quality()
	sun.shadow_enabled = not low
	# without a shadow map the unshadowed sun reads darker, so lift it a little
	sun.light_energy = 0.6 if low else 0.45
	world_env.environment.ambient_light_energy = 0.3 if low else 0.26
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if low else Viewport.MSAA_2X


## The camera drifts slowly while the title screen is up (an AnimationPlayer clip).
func _build_title_sway() -> void:
	var anim := Animation.new()
	anim.length = 14.0
	anim.loop_mode = Animation.LOOP_LINEAR
	var track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track, NodePath("CameraRig:sway"))
	anim.track_set_interpolation_type(track, Animation.INTERPOLATION_CUBIC)
	anim.track_set_interpolation_loop_wrap(track, true)
	anim.track_insert_key(track, 0.0, 0.0)
	anim.track_insert_key(track, 3.5, 1.0)
	anim.track_insert_key(track, 7.0, 0.0)
	anim.track_insert_key(track, 10.5, -1.0)
	anim.track_insert_key(track, 14.0, 0.0)
	var lib := AnimationLibrary.new()
	lib.add_animation("sway", anim)
	_sway_player = AnimationPlayer.new()
	_sway_player.name = "TitleSway"
	add_child(_sway_player)
	_sway_player.add_animation_library("", lib)


func _on_phase(phase: String) -> void:
	if phase == "title":
		if not _sway_player.is_playing():
			_sway_player.play("sway")
	else:
		_sway_player.stop()
		create_tween().tween_property(rig, "sway", 0.0, 0.6)


func _mesh_node(mesh: Mesh, parent: Node3D, shadow := true) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(n)
	return n


func _build_scenery() -> void:
	_models = AssetModels.load_all()
	var skip := _models.duplicate()
	var ground_tex := AssetModels.ground_texture()
	if ground_tex != null:
		skip["ground"] = true
	var parts := WorldBuilder.build_static(skip)
	var w := _mesh_node(parts["world"], scenery)
	w.name = "Buildings"
	var g := _mesh_node(parts["ground"], scenery, false)
	g.name = "Ground"
	if not _models.has("semaver"):
		_semaver2 = _mesh_node(parts["semaver2"], scenery)
		_semaver2.name = "SecondSamovar"
		_semaver2.visible = false
	_place_models(ground_tex)
	# sea
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(500, 300)
	var shader := Shader.new()
	shader.code = SEA_SHADER
	var smat := ShaderMaterial.new()
	smat.shader = shader
	plane.material = smat
	sea.mesh = plane
	sea.position = Vector3(0, -0.32, -159.3)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.name = "Sea"
	scenery.add_child(sea)
	# sign above the counter
	sign_label.text = "ÇAY OCAĞI"
	sign_label.font_size = 96
	sign_label.pixel_size = 0.0085
	sign_label.outline_size = 14
	sign_label.outline_modulate = Color("1c2b2d")
	sign_label.modulate = Color("ffb25a")
	sign_label.position = Vector3(-8.0, 5.04, 0.0)
	sign_label.rotation = Vector3(0, PI / 2.0, 0)
	sign_label.shaded = false
	# lantern glow
	for lp in [Vector3(6.0, 4.15, -8.7), Vector3(-3.6, 4.15, -8.7)]:
		var lm := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.36, 0.5, 0.36)
		lm.mesh = box
		lm.material_override = Palette.flat(0xffd48a, 1.6)
		lm.position = lp
		lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		scenery.add_child(lm)


func _model_node(model_name: String, sc: Vector3, pos: Vector3, parent: Node3D = null, shadow := true) -> MeshInstance3D:
	var m: AssetModels.Model = _models[model_name]
	var n := _mesh_node(m.mesh, scenery if parent == null else parent, shadow)
	n.name = model_name.capitalize()
	n.scale = sc
	n.position = pos
	return n


## Places the generated models with the browser's transforms (review §5.3) and moves the effect anchors onto them.
func _place_models(ground_tex: Texture2D) -> void:
	if _models.has("semaver"):
		var m: AssetModels.Model = _models["semaver"]
		var sc := 2.0 / m.size.y
		# the brass texture is a little dull under the warm light (browser: colour x1.2 in linear light)
		m.material.albedo_color = Color(1.08, 1.08, 1.08)
		_model_node("semaver", Vector3.ONE * sc, Vector3(CNT_X, TOP, -5.05))
		_semaver2 = _model_node("semaver", Vector3.ONE * sc, Vector3(CNT_X, TOP, -3.85))
		_semaver2.name = "SecondSamovar"
		_semaver2.visible = false
		_tea_steam_y = TOP + m.size.y * sc + 0.05
	if _models.has("oven"):
		var m: AssetModels.Model = _models["oven"]
		var sc := 1.6 / m.size.x
		var zc: float = TeaSim.STATION_Z["simit"]
		var h := m.size.y * sc
		_model_node("oven", Vector3.ONE * sc, Vector3(CNT_X, TOP, zc))
		var spot := m.top_spot(0.1, sc)
		_smoke_pos = Vector3(CNT_X + spot.x, TOP + h + 0.1, zc + spot.y)
		_ring_y = TOP + h * 0.87
		_ring_x = CNT_X + 0.15
	if _models.has("coffee"):
		var m: AssetModels.Model = _models["coffee"]
		var sc := 1.65 / m.size.x
		var zc: float = TeaSim.STATION_Z["coffee"]
		_model_node("coffee", Vector3.ONE * sc, Vector3(CNT_X, TOP, zc))
		# foam in the mouths of the model's two cezve pots (measured in the browser with tools/assets/pots.mjs)
		_pots = [Vector3(CNT_X + 0.1 * sc, TOP + 0.34 * sc, zc - 0.26 * sc), Vector3(CNT_X + 0.1 * sc, TOP + 0.34 * sc, zc + 0.31 * sc)]
		_pot_steam_dy = 0.15
	if _models.has("ayran"):
		var m: AssetModels.Model = _models["ayran"]
		_model_node("ayran", Vector3(2.5, 1.8 / m.size.y, 2.5), Vector3(CNT_X + 0.2, TOP, TeaSim.STATION_Z["ayran"]))
	if _models.has("sink"):
		var m: AssetModels.Model = _models["sink"]
		_model_node("sink", Vector3.ONE * (1.55 / m.size.z), Vector3(CNT_X + 0.3, TOP, TeaSim.STATION_Z["sink"]))
	if _models.has("window"):
		# five windows in one MultiMesh, back flush with the facade (x = -8.1), under the roof slab
		var m: AssetModels.Model = _models["window"]
		var sc := 1.05 / m.size.y
		var wx := -8.1 + m.size.x * sc * 0.5 - 0.04
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = m.mesh
		mm.instance_count = 5
		for i in 5:
			mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * sc), Vector3(wx, 5.2, -7.0 + i * 3.25)))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Windows"
		mmi.multimesh = mm
		scenery.add_child(mmi)
	if _models.has("table"):
		# six tables in one MultiMesh; the white cloth takes each table's colour from the instance colour
		var m: AssetModels.Model = _models["table"]
		_table_scale = Vector3(1.8 / m.size.x, 0.98 / m.size.y, 1.8 / m.size.z)
		var mat := m.material.duplicate() as StandardMaterial3D
		mat.vertex_color_use_as_albedo = true
		mat.vertex_color_is_srgb = true
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = m.mesh
		mm.instance_count = TeaSim.TABLE_POS.size()
		for i in mm.instance_count:
			mm.set_instance_color(i, Color.hex(TableView.CLOTH[i] * 256 + 255))
			mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
		_table_mm = MultiMeshInstance3D.new()
		_table_mm.name = "Tables"
		_table_mm.multimesh = mm
		_table_mm.material_override = mat
		props.add_child(_table_mm)
	if ground_tex != null:
		var plane := PlaneMesh.new()
		plane.size = Vector2(31.5, 23.0)
		var gm := StandardMaterial3D.new()
		gm.albedo_texture = ground_tex
		gm.uv1_scale = Vector3(31.5 / 5.0, 23.0 / 5.0, 1.0)
		gm.texture_repeat = true
		gm.roughness = 1.0
		gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		plane.material = gm
		var gn := _mesh_node(plane, scenery, false)
		gn.name = "Cobblestones"
		gn.position = Vector3(-14.0 + 31.5 / 2.0, 0.015, -9.0 + 23.0 / 2.0)


func _build_dynamic() -> void:
	# tables
	for i in TeaSim.TABLE_POS.size():
		var tv := TableView.new()
		tv.name = "Table%d" % i
		props.add_child(tv)
		tv.setup(i, _models.has("table"))
		_tables.append(tv)
	# oven glow, simit rings and coffee foam
	_oven_mat = StandardMaterial3D.new()
	_oven_mat.albedo_color = Color("2a1810")
	_oven_mat.emission_enabled = true
	_oven_mat.emission = Color("ff7a1a")
	_oven_mat.emission_energy_multiplier = 0.2
	var glow_box := BoxMesh.new()
	glow_box.size = Vector3(0.05, 0.62, 0.82)
	_oven_glow = _mesh_node(glow_box, props, false)
	_oven_glow.material_override = _oven_mat
	_oven_glow.position = Vector3(CNT_X + 0.73, 2.07, TeaSim.STATION_Z["simit"])
	if _models.has("oven"):
		# the glow sits at the back of the model's arched mouth (measured in the browser with tools/assets/front.mjs)
		var osc := 1.6 / (_models["oven"] as AssetModels.Model).size.x
		var zc: float = TeaSim.STATION_Z["simit"]
		_oven_glow.position = Vector3(CNT_X - 0.03 * osc, TOP + 0.32 * osc, zc - 0.045 * osc)
		_oven_glow.scale = Vector3(1.0, 0.24 * osc / 0.62, 0.33 * osc / 0.82)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.095
	torus.outer_radius = 0.245
	torus.rings = 12
	torus.ring_segments = 6
	for k in 3:
		var r := _mesh_node(torus, props)
		r.material_override = Palette.flat(0xd9983a)
		r.position = Vector3(_ring_x, _ring_y, TeaSim.STATION_Z["simit"] + (k - 1) * 0.45)
		r.rotation.y = 0.3 * k
		r.visible = false
		_rings.append(r)
	var foam_mesh := SphereMesh.new()
	foam_mesh.radius = 1.0
	foam_mesh.height = 2.0
	foam_mesh.radial_segments = 8
	foam_mesh.rings = 6
	for k in 2:
		var f := _mesh_node(foam_mesh, props, false)
		var fm := StandardMaterial3D.new()
		fm.albedo_color = Color("6b4226")
		f.material_override = fm
		f.position = _pots[k]
		f.visible = false
		_foam.append(f)
		_foam_mats.append(fm)
	# steam
	_steam_kettles.append(fx.make_emitter("steam", Vector3(CNT_X, _tea_steam_y, -5.05), 6))
	_steam_kettles.append(fx.make_emitter("steam", Vector3(CNT_X, _tea_steam_y, -3.85), 6))
	_smoke_oven = fx.make_emitter("smoke", _smoke_pos, 5)
	for k in 2:
		_steam_pots.append(fx.make_emitter("steam", _pots[k] + Vector3(0, _pot_steam_dy, 0), 4))
	# waiter + apprentice
	_waiter = Node3D.new()
	_waiter.name = "Waiter"
	props.add_child(_waiter)
	_mesh_node(WorldBuilder.waiter(0xf6efe0, 0x3b2a22, Palette.RED, 0x20150f), _waiter)
	for k in 5:
		var it := _mesh_node(ItemModels.mesh("tea"), _waiter)
		it.visible = false
		_tray_items.append(it)
	_apprentice = Node3D.new()
	_apprentice.name = "Apprentice"
	props.add_child(_apprentice)
	_mesh_node(WorldBuilder.waiter(0x7fa3c9, 0x3a5f8a, 0xf4f0e6, 0x5a3a22), _apprentice)
	_apprentice.scale = Vector3(0.92, 0.92, 0.92)
	_appr_item = _mesh_node(ItemModels.mesh("glass"), _apprentice)
	_appr_item.position = Vector3(0, 1.08, 0.55)
	_appr_item.visible = false
	_apprentice.visible = false
	# ambient: cat, gulls, ferry
	_cat = Node3D.new()
	_cat.name = "Cat"
	props.add_child(_cat)
	if _models.has("cat"):
		_model_node("cat", Vector3.ONE * (0.85 / (_models["cat"] as AssetModels.Model).size.x), Vector3.ZERO, _cat)
	else:
		_mesh_node(WorldBuilder.cat(), _cat)
	_cat_nav = NavGrid.new(TeaSim.TABLE_POS)
	_cat_mover.pos = CAT_HOME
	_cat_mover.face = PI / 2.0
	var gull_mesh := WorldBuilder.gull()
	for gp in [
		{"a": 0.0, "r": 6.5, "cx": 1.0, "cz": -13.0, "h": 8.5, "sp": 0.32},
		{"a": 2.1, "r": 8.0, "cx": -2.0, "cz": -12.0, "h": 10.5, "sp": -0.27},
		{"a": 4.2, "r": 5.5, "cx": 5.0, "cz": -11.0, "h": 7.5, "sp": 0.4},
		{"a": 5.5, "r": 9.0, "cx": 0.0, "cz": -14.0, "h": 12.0, "sp": -0.22},
	]:
		var gn := Node3D.new()
		props.add_child(gn)
		var gm := _mesh_node(gull_mesh, gn)
		gm.scale = Vector3(1.3, 1.0, 1.3)
		_gulls.append(gn)
		_gull_params.append(gp)
	_ferry = Node3D.new()
	_ferry.name = "Ferry"
	props.add_child(_ferry)
	if _models.has("ferry"):
		# 8 m long, sunk 0.55 m into the water, bow towards +X (the direction it sails)
		_model_node("ferry", Vector3.ONE * (8.0 / (_models["ferry"] as AssetModels.Model).size.x), Vector3(0, -0.55, 0), _ferry)
	else:
		_mesh_node(WorldBuilder.ferry(), _ferry)
	_ferry.position = Vector3(_ferry_x, 0, -13.6)
	# hover ring
	var ring := TorusMesh.new()
	ring.inner_radius = 0.9
	ring.outer_radius = 1.08
	ring.rings = 32
	ring.ring_segments = 4
	_hover_ring = _mesh_node(ring, props, false)
	_hover_ring.material_override = Palette.flat(0xc2410c, 1.2)
	_hover_ring.position.y = 0.05
	_hover_ring.scale = Vector3(1, 0.3, 1)
	_hover_ring.visible = false


func _on_sim_created(s: TeaSim) -> void:
	if _sim != null and _sim.burst.is_connected(_on_burst):
		_sim.burst.disconnect(_on_burst)
		_sim.sfx.disconnect(_on_sfx)
	_sim = s
	_sim.burst.connect(_on_burst)
	_sim.sfx.connect(_on_sfx)
	for pv in _people.values():
		pv.queue_free()
	_people.clear()
	for tv in _tables:
		tv.visible = false
		tv._shown = false


func _on_burst(kind: String, pos: Vector3, count: int) -> void:
	fx.burst(kind, pos, count)


func _on_sfx(sound: String) -> void:
	if GameState.phase != "play":
		return
	if sound == "grumble":
		rig.add_shake(0.35)
	elif sound == "hiss":
		rig.add_shake(0.2)


# ---- picking ---------------------------------------------------------------

## Finds the station / table / cat under a screen position, if any.
func pick_at(screen_pos: Vector2) -> Dictionary:
	var cam := rig.cam
	var best := {}
	var best_score := 1.0
	var candidates: Array[Dictionary] = []
	for id in TeaSim.STATION_IDS:
		var z: float = TeaSim.STATION_Z[id]
		candidates.append({"kind": "station", "id": id, "pos": Vector3(CNT_X, 1.5, z), "radius": 1.5 if id != "tea" else 2.6})
	if _sim != null:
		for tb in _sim.tables:
			if tb.unlocked:
				candidates.append({"kind": "table", "id": tb.index, "pos": Vector3(tb.pos.x, 1.0, tb.pos.y), "radius": 1.45})
	candidates.append({"kind": "cat", "id": 0, "pos": Vector3(_cat_mover.pos.x, 0.4, _cat_mover.pos.y), "radius": 0.7})
	for c in candidates:
		var p3: Vector3 = c["pos"]
		if cam.is_position_behind(p3):
			continue
		var sp := cam.unproject_position(p3)
		var one_m := cam.unproject_position(p3 + CameraRig.RIGHT).distance_to(sp)
		var d := sp.distance_to(screen_pos) / maxf(one_m, 1.0)
		var score := d / float(c["radius"])
		if score < best_score:
			best_score = score
			best = c
	return best


func set_hover(kind: String, id: Variant) -> void:
	hover_kind = kind
	if kind == "table":
		hover_id = int(id)
	elif kind == "station":
		hover_id = TeaSim.STATION_IDS.find(str(id))
	else:
		hover_id = -1


func pet_cat() -> void:
	if _cat_pet > 0.0:
		return
	_cat_pet = 1.2
	Sfx.play("meow")
	fx.burst("heart", Vector3(_cat_mover.pos.x, 1.0, _cat_mover.pos.y), 4)
	if _cat_state == "sleep":
		_cat_t = minf(_cat_t, 0.5)
	if _sim != null:
		_sim.toast.emit("toastMeow", "")


## Screen position for a point above the floor (HUD bubbles).
func to_screen(world_pos: Vector3) -> Vector2:
	return rig.cam.unproject_position(world_pos)


func is_behind(world_pos: Vector3) -> bool:
	return rig.cam.is_position_behind(world_pos)


# ---- per-frame sync --------------------------------------------------------

func _process(delta: float) -> void:
	# everything stands still while the game is paused (the ferry, gulls and cat too)
	if GameState.paused:
		delta = 0.0
	_vt += delta
	_update_ambient(delta)
	_update_hover()
	if _sim == null:
		return
	var s := _sim
	_update_tables(s)
	_update_stations(s)
	_update_staff(s)
	_update_people(s)


func _update_hover() -> void:
	var show := false
	if hover_kind == "table" and _sim != null and hover_id >= 0 and hover_id < _sim.tables.size():
		_hover_ring.position = Vector3(_sim.tables[hover_id].pos.x, 0.05, _sim.tables[hover_id].pos.y)
		_hover_ring.scale = Vector3(1, 0.3, 1)
		show = true
	elif hover_kind == "station" and hover_id >= 0:
		var id: String = TeaSim.STATION_IDS[hover_id]
		var sp := TeaSim.station_pos(id)
		_hover_ring.position = Vector3(sp.x, 0.05, sp.y)
		_hover_ring.scale = Vector3(0.7, 0.3, 0.7)
		show = true
	_hover_ring.visible = show and GameState.phase == "play"


func _update_tables(s: TeaSim) -> void:
	var stool_level := int(s.up["stool"])
	for i in _tables.size():
		_tables[i].update_view(s.tables[i], stool_level)
		if _table_mm != null:
			var tv := _tables[i]
			var sc := _table_scale * tv.scale if tv.visible else Vector3.ZERO
			_table_mm.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(sc), tv.position))


func _update_stations(s: TeaSim) -> void:
	_semaver2.visible = int(s.up["kettle"]) > 0
	var baking := s.oven.state == "baking"
	var energy := 0.12
	if baking:
		energy = 0.9 + sin(_vt * 9.0) * 0.15
	elif s.oven.state == "ready":
		energy = 0.7
	_oven_mat.emission_energy_multiplier = energy
	for k in 3:
		_rings[k].visible = s.oven.state == "ready" and k < s.oven.n
	for k in 2:
		var p := s.pots[k]
		var sc := 0.0
		var col := Color("6b4226")
		if p.state == "cook":
			sc = 0.02 + (p.t / s.balance.cook_time) * 0.12
			col = Color("7a4a2a")
		elif p.state == "ready":
			sc = 0.14 + sin(_vt * 12.0) * 0.01
			col = Color("b98a56")
		elif p.state == "spilled":
			sc = 0.02
			col = Color("2e1d10")
		_foam[k].visible = sc > 0.0
		if p.state == "spilled":
			# boiled over: a wide, flat, dark froth spread over the pot mouth
			_foam[k].scale = Vector3(0.26, 0.05, 0.26)
			_foam[k].position = _pots[k] + Vector3(0, 0.01, 0)
		else:
			_foam[k].scale = Vector3(sc * 1.2, sc * 0.8, sc * 1.2)
			_foam[k].position = _pots[k]
		_foam_mats[k].albedo_color = col
		_steam_pots[k].emitting = (p.state == "cook" and p.t > s.balance.cook_time * 0.5) or p.state == "ready"
	for k in 2:
		var kt := s.kettles[k]
		_steam_kettles[k].emitting = k < s.active_kettles() and (kt.state == "brewing" or kt.state == "ready")
	_smoke_oven.emitting = s.oven.state == "baking" or s.oven.state == "ready"


func _update_staff(s: TeaSim) -> void:
	var w := s.waiter
	var bob := absf(sin(_vt * 11.0)) * 0.07 if w.moving else 0.0
	_waiter.position = Vector3(w.pos.x, bob, w.pos.y)
	_waiter.rotation = Vector3(0, w.face, sin(_vt * 11.0) * 0.04 if w.moving else 0.0)
	var slots_x: Array[float] = [-0.18, 0.18, 0.0, -0.2, 0.2]
	var slots_z: Array[float] = [0.2, 0.2, 0.4, 0.58, 0.58]
	for k in _tray_items.size():
		var node := _tray_items[k]
		if k < w.tray.size():
			node.visible = true
			node.position = Vector3(slots_x[k], 1.07, slots_z[k])
			var it := w.tray[k]
			var look := ItemModels.for_slot("tea" if it == "dirty" else it, it == "dirty")
			if node.mesh != look[0]:
				node.mesh = look[0]
				node.material_override = look[1]
		else:
			node.visible = false
	var a := s.apprentice
	_apprentice.visible = a != null
	if a != null:
		_apprentice.position = Vector3(a.pos.x, absf(sin(_vt * 11.0 + 1.0)) * 0.06 if a.moving else 0.0, a.pos.y)
		_apprentice.rotation = Vector3(0, a.face, 0)
		_appr_item.visible = a.carrying


func _update_people(s: TeaSim) -> void:
	var alive: Dictionary = {}
	for party in s.parties:
		for pe in party.persons:
			alive[pe] = true
			if not _people.has(pe):
				var pv := PersonView.new()
				_person_serial += 1
				people.add_child(pv)
				pv.setup(pe, _person_serial)
				_people[pe] = pv
	for pe in _people.keys():
		if not alive.has(pe):
			(_people[pe] as PersonView).queue_free()
			_people.erase(pe)
	for pv in _people.values():
		(pv as PersonView).update_view(_vt)


# ---- ambient life ----------------------------------------------------------

func _update_ambient(delta: float) -> void:
	# ferry
	_ferry_x += delta * 1.1
	if _ferry_x > 40.0:
		_ferry_x = -46.0
		_ferry_horn = false
	if not _ferry_horn and _ferry_x > -14.0:
		_ferry_horn = true
		Sfx.play("horn")
	_ferry.position = Vector3(_ferry_x, sin(_vt * 1.2) * 0.06, -13.6)
	_ferry.rotation.z = sin(_vt * 0.9) * 0.01
	# gulls
	for i in _gulls.size():
		var g := _gull_params[i]
		g["a"] = float(g["a"]) + float(g["sp"]) * delta
		var a: float = g["a"]
		var x: float = float(g["cx"]) + cos(a) * float(g["r"])
		var z: float = float(g["cz"]) + sin(a) * float(g["r"]) * 0.6
		var y: float = float(g["h"]) + sin(_vt * 0.9 + i * 2.0) * 0.5
		var flap := 0.55 + absf(sin(_vt * 5.0 + i * 1.7)) * 0.9
		_gulls[i].position = Vector3(x, y, z)
		_gulls[i].rotation = Vector3(0, -a * signf(float(g["sp"])) + (0.0 if float(g["sp"]) > 0.0 else PI), sin(_vt * 5.0 + i) * 0.12)
		_gulls[i].scale = Vector3(1.0, flap, 1.0)
	# cat
	_cat_pet = maxf(0.0, _cat_pet - delta)
	match _cat_state:
		"sleep":
			_cat_t -= delta
			_cat_mover.moving = false
			if _cat_t <= 0.0:
				_cat_state = "wake"
				_cat_t = 1.4
		"wake":
			_cat_t -= delta
			if _cat_t <= 0.0:
				var dest := Vector2.ZERO
				for n in 40:
					dest = Vector2(_rng.randf_range(-4.2, 8.5), _rng.randf_range(-7.4, 7.5))
					if _cat_nav.is_free(dest):
						break
				_cat_mover.path = _cat_nav.find_path(_cat_mover.pos, dest)
				_cat_state = "walk"
		"walk":
			if _cat_mover.follow(1.3, delta):
				_cat_state = "sit"
				_cat_t = _rng.randf_range(4.0, 9.0)
		"sit":
			_cat_mover.moving = false
			_cat_t -= delta
			if _cat_t <= 0.0:
				_cat_mover.path = _cat_nav.find_path(_cat_mover.pos, CAT_HOME)
				_cat_state = "return"
		"return":
			if _cat_mover.follow(1.4, delta):
				_cat_state = "sleep"
				_cat_t = _rng.randf_range(18.0, 38.0)
				_cat_mover.face = PI / 2.0
	var asleep := _cat_state == "sleep"
	var cy := 0.3 if _cat_mover.pos.x < -6.7 else 0.0
	var breathe := 1.0 + sin(_vt * 1.8) * 0.04 if asleep else 1.0
	_cat.position = Vector3(_cat_mover.pos.x, cy + (absf(sin(_vt * 12.0)) * 0.05 if _cat_mover.moving else 0.0), _cat_mover.pos.y)
	_cat.rotation.y = _cat_mover.face - PI / 2.0
	_cat.scale = Vector3(1.0, 0.72 * breathe if asleep else (0.9 if _cat_state == "sit" else 1.0), 1.0)
