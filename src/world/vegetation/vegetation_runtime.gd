class_name VegetationRuntime
extends Node3D
## Alberi ed erba nella scena. Alberi a gruppi 32x32 come il prototipo
## (View.setTrees); erba per colonna di chunk, ricostruita quando una colonna
## cambia (il prototipo la rigenerava solo col chunk a y=0). Tutto il calcolo
## gira sul WorkerThreadPool con snapshot del mondo; le mesh si applicano sul
## main thread a budget.

signal trees_ready(count: int)

const TREE_GROUP := 32
const TREE_GRID := 8
const GRASS_DENSITY := 0.27
@export var apply_budget_ms := 2.0
@export var max_jobs := 4

var world: WorldData
var opaque := PackedByteArray()
var world_seed := 1931
var tree_material: ShaderMaterial
var grass_material: ShaderMaterial
var spots: Array[Vegetation.TreeSpot] = []
## Griglia 8x8 per collisioni e copertura: Vector2i -> Array[TreeSpot].
var tree_grid := {}
var grass_visible := true

var _session := 0
var _tree_task := -1
var _tree_result: Array = []
var _grass_dirty := {} # Vector2i colonna -> true
var _grass_version := {} # Vector2i -> int
var _grass_jobs := {} # Vector2i -> task id
var _grass_done := {} # Vector2i -> [versione, sessione, PackedFloat32Array]
var _grass_nodes := {} # Vector2i -> MeshInstance3D
var _tree_nodes: Array[MeshInstance3D] = []
var _mutex := Mutex.new()
var _snapshot: WorldData
var _snapshot_revision := -1


func _init() -> void:
	tree_material = ShaderMaterial.new()
	tree_material.shader = preload("res://src/presentation/shaders/tree.gdshader")
	grass_material = ShaderMaterial.new()
	grass_material.shader = preload("res://src/presentation/shaders/grass.gdshader")
	grass_material.set_shader_parameter(&"leaf_tex", ProtoTextures.leaf_texture())


func setup(w: WorldData, catalog: BlockCatalog, seed_value: int) -> void:
	_clear()
	_session += 1
	world = w
	opaque = catalog.opaque_table()
	world_seed = seed_value
	_snapshot = null
	_snapshot_revision = -1
	var snap := _get_snapshot()
	_tree_task = WorkerThreadPool.add_task(_tree_job.bind(snap, opaque, seed_value, _session))
	for cz in world.chunks_z():
		for cx in world.chunks_x():
			_grass_dirty[Vector2i(cx, cz)] = true


func mark_dirty(chunks: Array[Vector3i]) -> void:
	for c in chunks:
		var col := Vector2i(c.x, c.z)
		_grass_dirty[col] = true
		_grass_version[col] = int(_grass_version.get(col, 0)) + 1


func is_idle() -> bool:
	return _tree_task < 0 and _grass_dirty.is_empty() and _grass_jobs.is_empty()


func flush() -> void:
	while not is_idle():
		_process_work(1e9, true)


func _process(_dt: float) -> void:
	if world != null:
		_process_work(apply_budget_ms, false)


func _get_snapshot() -> WorldData:
	if _snapshot == null or _snapshot_revision != world.revision:
		_snapshot = world.render_snapshot()
		_snapshot_revision = world.revision
	return _snapshot


func _process_work(budget_ms: float, wait: bool) -> void:
	var t0 := Time.get_ticks_usec()
	if _tree_task >= 0 and (wait or WorkerThreadPool.is_task_completed(_tree_task)):
		WorkerThreadPool.wait_for_task_completion(_tree_task)
		_tree_task = -1
		_mutex.lock()
		var res := _tree_result
		_tree_result = []
		_mutex.unlock()
		if not res.is_empty() and int(res[0]) == _session:
			_apply_trees(res[1], res[2])
	for col: Vector2i in _grass_dirty.keys():
		if _grass_jobs.size() >= max_jobs:
			break
		if _grass_jobs.has(col):
			continue
		_grass_dirty.erase(col)
		var ver := int(_grass_version.get(col, 0))
		_grass_jobs[col] = WorkerThreadPool.add_task(_grass_job.bind(col, ver, _session, _get_snapshot()))
	for col: Vector2i in _grass_jobs.keys():
		var task: int = _grass_jobs[col]
		if not wait and not WorkerThreadPool.is_task_completed(task):
			continue
		if (Time.get_ticks_usec() - t0) / 1000.0 > budget_ms:
			break
		WorkerThreadPool.wait_for_task_completion(task)
		_grass_jobs.erase(col)
		_mutex.lock()
		var r: Array = _grass_done.get(col, [])
		_grass_done.erase(col)
		_mutex.unlock()
		if r.is_empty() or int(r[1]) != _session or int(r[0]) != int(_grass_version.get(col, 0)):
			if not r.is_empty() and int(r[1]) == _session:
				_grass_dirty[col] = true
			continue
		_apply_grass(col, r[2])


# ------------------------------------------------------------------ alberi

func _tree_job(snap: WorldData, op: PackedByteArray, seed_value: int, session: int) -> void:
	var list := Vegetation.tree_spots(snap, op, seed_value)
	var tpls: Array[Vegetation.Template] = []
	for k in 3:
		for v in 2:
			tpls.append(Vegetation.tree_template(k, seed_value * 7 + k * 13 + v * 101))
	var groups := {}
	for sp in list:
		var key := Vector2i(int(sp.x / TREE_GROUP), int(sp.z / TREE_GROUP))
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(sp)
	var meshes: Array = []
	for key: Vector2i in groups:
		meshes.append(_tree_group_arrays(snap, groups[key], tpls))
	_mutex.lock()
	_tree_result = [session, list, meshes]
	_mutex.unlock()


## Array della mesh di un gruppo, come View._buildTreeGroup (winding orario per Godot).
static func _tree_group_arrays(snap: WorldData, list: Array, tpls: Array[Vegetation.Template]) -> Array:
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var col := PackedColorArray()
	var cus := PackedFloat32Array()
	for sp: Vegetation.TreeSpot in list:
		if sp.dead:
			continue
		var t := tpls[sp.kind * 2 + int(sp.seed_value * 7.0) % 2]
		var d := t.data
		var c := cos(sp.rot)
		var sn := sin(sp.rot)
		var lx := floori(sp.x)
		var ly := floori(sp.y + 0.5)
		var lz := floori(sp.z)
		var ls := 15
		if snap.inside(lx, ly, lz):
			ls = snap.sun[snap.index(lx, ly, lz)]
		elif ly < snap.size_y:
			ls = 0
		var li := maxi(ls, 10) / 15.0
		var n := t.verts()
		for tri in range(0, n, 3):
			for k in [0, 2, 1]:
				var o: int = (tri + k) * Vegetation.STRIDE
				var px := d[o] * sp.scale
				var py := d[o + 1] * sp.scale
				var pz := d[o + 2] * sp.scale
				pos.append(Vector3(c * px - sn * pz + sp.x, py + sp.y, sn * px + c * pz + sp.z))
				nrm.append(Vector3(c * d[o + 3] - sn * d[o + 5], d[o + 4], sn * d[o + 3] + c * d[o + 5]))
				col.append(Color(d[o + 6], d[o + 7], d[o + 8]))
				cus.append_array(PackedFloat32Array([d[o + 9], sp.seed_value, sp.y, li]))
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = pos
	a[Mesh.ARRAY_NORMAL] = nrm
	a[Mesh.ARRAY_COLOR] = col
	a[Mesh.ARRAY_CUSTOM0] = cus
	return a


func _apply_trees(list: Array[Vegetation.TreeSpot], meshes: Array) -> void:
	spots = list
	tree_grid.clear()
	for sp in spots:
		var key := Vector2i(int(sp.x / TREE_GRID), int(sp.z / TREE_GRID))
		if not tree_grid.has(key):
			tree_grid[key] = []
		(tree_grid[key] as Array).append(sp)
	for a: Array in meshes:
		if (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
			continue
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {},
			Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
		mesh.surface_set_material(0, tree_material)
		var inst := MeshInstance3D.new()
		inst.mesh = mesh
		inst.extra_cull_margin = 0.5
		add_child(inst)
		_tree_nodes.append(inst)
	trees_ready.emit(spots.size())


## Alberi entro una cella della griglia 8x8 attorno a (x, z).
func trees_near(x: float, z: float, radius_cells: int = 1) -> Array[Vegetation.TreeSpot]:
	var out: Array[Vegetation.TreeSpot] = []
	var cx := int(x / TREE_GRID)
	var cz := int(z / TREE_GRID)
	for gz in range(cz - radius_cells, cz + radius_cells + 1):
		for gx in range(cx - radius_cells, cx + radius_cells + 1):
			for sp: Vegetation.TreeSpot in tree_grid.get(Vector2i(gx, gz), []):
				if not sp.dead:
					out.append(sp)
	return out


# ------------------------------------------------------------------ erba

func _grass_job(col: Vector2i, ver: int, session: int, snap: WorldData) -> void:
	var b := Vegetation.grass_blades(snap, col.x, col.y, snap.world_seed, GRASS_DENSITY)
	_mutex.lock()
	_grass_done[col] = [ver, session, b]
	_mutex.unlock()


func _apply_grass(col: Vector2i, b: PackedFloat32Array) -> void:
	var old: MeshInstance3D = _grass_nodes.get(col)
	if old != null:
		old.queue_free()
		_grass_nodes.erase(col)
	var n := b.size() / 7
	if n == 0:
		return
	var pos := PackedVector3Array()
	var c0 := PackedFloat32Array()
	var c1 := PackedFloat32Array()
	var idx := PackedInt32Array()
	pos.resize(n * 4)
	c0.resize(n * 16)
	c1.resize(n * 16)
	idx.resize(n * 6)
	var corners := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for i in n:
		var o := i * 7
		var p := Vector3(b[o], b[o + 5], b[o + 1])
		for k in 4:
			var v := i * 4 + k
			var cr: Vector2 = corners[k]
			pos[v] = p
			c0[v * 4] = cr.x
			c0[v * 4 + 1] = cr.y
			c0[v * 4 + 2] = b[o + 2]
			c0[v * 4 + 3] = b[o + 6]
			c1[v * 4] = b[o + 3]
			c1[v * 4 + 1] = b[o + 4]
		var q := i * 6
		var v0 := i * 4
		idx[q] = v0
		idx[q + 1] = v0 + 2
		idx[q + 2] = v0 + 1
		idx[q + 3] = v0
		idx[q + 4] = v0 + 3
		idx[q + 5] = v0 + 2
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = pos
	a[Mesh.ARRAY_CUSTOM0] = c0
	a[Mesh.ARRAY_CUSTOM1] = c1
	a[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {},
		(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT))
	mesh.surface_set_material(0, grass_material)
	var cs := WorldData.CHUNK_SIZE
	mesh.custom_aabb = AABB(Vector3(col.x * cs - 1, 0, col.y * cs - 1), Vector3(cs + 2, world.size_y + 1, cs + 2))
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.visible = grass_visible
	add_child(inst)
	_grass_nodes[col] = inst


func set_grass_visible(on: bool) -> void:
	grass_visible = on
	for inst: MeshInstance3D in _grass_nodes.values():
		inst.visible = on


func grass_count() -> int:
	return _grass_nodes.size()


func _clear() -> void:
	if _tree_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_tree_task)
		_tree_task = -1
	for col: Vector2i in _grass_jobs.keys():
		WorkerThreadPool.wait_for_task_completion(_grass_jobs[col])
	_grass_jobs.clear()
	_grass_done.clear()
	_grass_dirty.clear()
	for inst: MeshInstance3D in _grass_nodes.values():
		inst.queue_free()
	_grass_nodes.clear()
	for inst in _tree_nodes:
		inst.queue_free()
	_tree_nodes.clear()
	spots.clear()
	tree_grid.clear()


func _exit_tree() -> void:
	_clear()
