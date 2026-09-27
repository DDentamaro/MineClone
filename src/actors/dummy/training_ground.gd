class_name TrainingGround
extends Node3D
## Manichini d'allenamento in scena (M4): logica in `TrainingDummy`, qui le
## mesh (palo, corpo di paglia, testa di sacco, braccia a croce) e la loro
## oscillazione. Tre manichini a semicerchio davanti al giocatore.

var world: WorldData
var dummies: Array[TrainingDummy] = []
var _views: Array[Node3D] = []
var _parts: Array = []
var _material: ShaderMaterial
var _mesh: ArrayMesh


func _init() -> void:
	_material = ShaderMaterial.new()
	_material.shader = preload("res://src/presentation/shaders/actor.gdshader")
	_mesh = _build_mesh()


static func _build_mesh() -> ArrayMesh:
	var k := MeshKit.new()
	var wood := Color(0.50, 0.34, 0.19)
	var straw := Color(0.86, 0.72, 0.38)
	var sack := Color(0.78, 0.68, 0.50)
	var rope := Color(0.55, 0.42, 0.24)
	k.box(Vector3(0, 0.05, 0), Vector3(0.52, 0.1, 0.52), wood.darkened(0.15), 0.03)
	k.prism(Vector3.ZERO, 0.1, 0.62, 0.06, 0.055, 6, wood)
	k.box(Vector3(0, 0.88, 0), Vector3(0.42, 0.56, 0.3), straw, 0.08, 0.82)
	k.box(Vector3(0, 0.72, 0), Vector3(0.44, 0.05, 0.32), rope, 0.015)
	k.box(Vector3(0, 1.02, 0), Vector3(0.4, 0.05, 0.3), rope, 0.015)
	k.box(Vector3(0, 1.08, 0), Vector3(0.9, 0.09, 0.09), wood, 0.02)
	for sx in [-1.0, 1.0]:
		k.box(Vector3(0.42 * sx, 1.08, 0), Vector3(0.12, 0.16, 0.16), straw.darkened(0.08), 0.04)
	k.box(Vector3(0, 1.33, 0), Vector3(0.3, 0.3, 0.28), sack, 0.07)
	k.box(Vector3(0, 1.2, 0), Vector3(0.18, 0.04, 0.2), rope, 0.012)
	# Bersaglio dipinto sul petto e "occhi" cuciti.
	k.box(Vector3(0, 0.9, -0.15), Vector3(0.2, 0.2, 0.02), Color(0.72, 0.18, 0.14), 0.02)
	k.box(Vector3(0, 0.9, -0.162), Vector3(0.1, 0.1, 0.02), Color(0.93, 0.9, 0.8), 0.015)
	for sx in [-1.0, 1.0]:
		k.box(Vector3(0.065 * sx, 1.36, -0.14), Vector3(0.06, 0.02, 0.02), Color(0.2, 0.14, 0.1), 0.0)
	return k.commit()


func setup(w: WorldData) -> void:
	world = w
	for v in _views:
		v.queue_free()
	_views.clear()
	dummies.clear()


## Piazza `n` manichini ad arco a `dist` unita' davanti a (pos, facing).
func place_around(pos: Vector3, facing: float, n: int = 3, dist: float = 3.2) -> void:
	setup(world)
	for i in n:
		var a := facing + (float(i) - (n - 1) * 0.5) * 0.62
		var f := CombatController.forward(a)
		var p := Vector3(pos.x + f.x * dist, pos.y, pos.z + f.y * dist)
		if world != null:
			p.x = clampf(p.x, 2.0, world.size_x - 2.0)
			p.z = clampf(p.z, 2.0, world.size_z - 2.0)
			p.y = VoxelQuery.field_height(world, p.x, p.z, pos.y + 2.0)
		add_dummy(p)


func add_dummy(p: Vector3) -> TrainingDummy:
	var d := TrainingDummy.new(p)
	dummies.append(d)
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.material_override = _material
	root.add_child(mi)
	add_child(root)
	_views.append(root)
	return d


func targets() -> Array:
	return dummies.duplicate()


## Fisica dei manichini (dt = 0 durante l'hitstop).
func step(dt: float) -> Array[TrainingDummy]:
	var broken: Array[TrainingDummy] = []
	for d in dummies:
		if dt > 0.0:
			d.step(dt, world)
		if d.broke:
			d.broke = false
			broken.append(d)
	return broken


func sync_views(locked: CombatTarget) -> void:
	for i in dummies.size():
		var d := dummies[i]
		var v := _views[i]
		v.visible = d.alive
		v.position = d.position
		v.basis = Basis.from_euler(Vector3(d.tilt.x, 0, d.tilt.y))
		var mi := v.get_child(0) as MeshInstance3D
		mi.set_instance_shader_parameter(&"flash", d.flash * 0.85)
		var lit := d == locked
		mi.set_instance_shader_parameter(&"tint", Vector3(1.12, 0.96, 0.9) if lit else Vector3.ONE)
		if world != null:
			var s := _light_at(world, d.position + Vector3(0, 1.0, 0))
			mi.set_instance_shader_parameter(&"sun_here", s.x)
			mi.set_instance_shader_parameter(&"blk_here", s.y)


## Luce solare e dei blocchi (0..1) nella cella di `p`.
static func _light_at(w: WorldData, p: Vector3) -> Vector2:
	var x := clampi(floori(p.x), 0, w.size_x - 1)
	var y := clampi(floori(p.y), 0, w.size_y - 1)
	var z := clampi(floori(p.z), 0, w.size_z - 1)
	var i := (y * w.size_z + z) * w.size_x + x
	return Vector2(w.sun[i] / 15.0, w.blk[i] / 15.0)
