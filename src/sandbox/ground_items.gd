class_name GroundItems
extends Node3D
## Oggetti a terra (D-028): cio' che si getta dallo zaino cade davanti al
## giocatore, resta per 5 minuti (lampeggia negli ultimi 10 s) e si raccoglie
## passandoci sopra, dopo un secondo dal lancio. Si salvano con la partita.

const LIFETIME := 300.0
const PICKUP_DELAY := 1.0
const PICKUP_R := 1.1
const MAX := 64
const GRAVITY := 20.0


class Drop:
	extends RefCounted
	var stack: ItemStack
	var p := Vector3.ZERO
	var v := Vector3.ZERO
	var age := 0.0
	var landed := false
	var node: MeshInstance3D


var world: WorldData
var list: Array[Drop] = []
var _material: ShaderMaterial
var _t := 0.0


func _init() -> void:
	_material = ShaderMaterial.new()
	_material.shader = preload("res://src/presentation/shaders/actor.gdshader")


func clear() -> void:
	for d in list:
		if d.node != null:
			d.node.queue_free()
	list.clear()


## Getta `stack` da `from` verso `dir` (orizzontale): un piccolo arco in avanti.
func drop(stack: ItemStack, from: Vector3, dir: Vector3) -> Drop:
	if stack == null or stack.count <= 0:
		return null
	if list.size() >= MAX:
		_remove(0)
	var d := Drop.new()
	d.stack = stack
	var f := Vector3(dir.x, 0, dir.z)
	f = f.normalized() if f.length() > 1e-3 else Vector3.FORWARD
	d.p = from + Vector3(0, 1.0, 0) + f * 0.3
	d.v = f * 2.6 + Vector3(0, 3.2, 0)
	list.append(d)
	_make_node(d)
	return d


## Un passo: caduta, invecchiamento, raccolta. Ritorna gli stack raccolti.
func step(dt: float, player: Vector3, inv: Inventory) -> Array[ItemStack]:
	_t += dt
	var got: Array[ItemStack] = []
	var i := list.size() - 1
	while i >= 0:
		var d := list[i]
		d.age += dt
		if d.age >= LIFETIME:
			_remove(i)
			i -= 1
			continue
		if not d.landed:
			d.v.y -= GRAVITY * dt
			var np := d.p + d.v * dt
			var g := _ground(np)
			if np.y <= g:
				np.y = g
				d.v = Vector3.ZERO
				d.landed = true
			elif world != null and world.is_solid_at(floori(np.x), floori(d.p.y), floori(np.z)):
				# Contro un muro: cade dritto.
				np.x = d.p.x
				np.z = d.p.z
				d.v.x = 0.0
				d.v.z = 0.0
			d.p = np
		elif world != null and _ground(d.p) < d.p.y - 0.05:
			# Il blocco sotto e' stato tolto.
			d.landed = false
		if inv != null and d.age >= PICKUP_DELAY and Vector2(d.p.x - player.x, d.p.z - player.z).length() < PICKUP_R \
				and absf(d.p.y - player.y) < 1.6:
			var left := inv.add(d.stack.duplicate_stack())
			if left < d.stack.count:
				var taken := d.stack.duplicate_stack()
				taken.count = d.stack.count - left
				got.append(taken)
			if left == 0:
				_remove(i)
				i -= 1
				continue
			d.stack.count = left
		_sync(d)
		i -= 1
	return got


func _ground(p: Vector3) -> float:
	if world == null:
		return 0.0
	return VoxelQuery.field_height(world, p.x, p.z, p.y + 0.3)


func _remove(i: int) -> void:
	if list[i].node != null:
		list[i].node.queue_free()
	list.remove_at(i)


func _make_node(d: Drop) -> void:
	var def := d.stack.def()
	var mesh: ArrayMesh
	var tint: Color = ItemLibrary.TIERS[clampi(def.tier - 1, 0, ItemLibrary.TIERS.size() - 1)]["color"]
	if def.kind == ItemDefinition.Kind.WEAPON:
		mesh = WeaponMeshes.build(WeaponLibrary.by_id(def.weapon).kind, tint)
	elif def.kind == ItemDefinition.Kind.TOOL:
		mesh = WeaponMeshes.build_tool(def.tool_type, tint)
	else:
		var k := MeshKit.new()
		var s := 0.26 if def.kind != ItemDefinition.Kind.SCROLL else 0.2
		k.box(Vector3(0, s * 0.5, 0), Vector3(s, s, s), def.color, 0.03)
		mesh = k.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material
	add_child(mi)
	d.node = mi
	_sync(d)


func _sync(d: Drop) -> void:
	if d.node == null:
		return
	var def := d.stack.def()
	var long := def.kind == ItemDefinition.Kind.WEAPON or def.kind == ItemDefinition.Kind.TOOL
	var bob := 0.12 + 0.06 * sin(_t * 2.6 + d.p.x) if d.landed else 0.0
	d.node.position = d.p + Vector3(0, bob, 0)
	# Armi e attrezzi girano lenti, inclinati; i blocchi girano su se stessi.
	d.node.rotation = Vector3(0, _t * 1.4 + d.p.z, deg_to_rad(70.0) if long else 0.0)
	d.node.scale = Vector3.ONE * (0.8 if long else 1.0)
	d.node.visible = d.age < LIFETIME - 10.0 or fmod(_t, 0.4) < 0.25
	if world != null:
		var c := Vector3i(floori(d.p.x), floori(d.p.y + 0.2), floori(d.p.z))
		if world.inside(c.x, c.y, c.z):
			var i := world.index(c.x, c.y, c.z)
			d.node.set_instance_shader_parameter(&"sun_here", world.sun[i] / 15.0)
			d.node.set_instance_shader_parameter(&"blk_here", world.blk[i] / 15.0)


func to_array() -> Array:
	var out := []
	for d in list:
		out.append({"s": d.stack.to_dict(), "p": d.p, "a": d.age})
	return out


func load_array(a: Array) -> void:
	clear()
	for e in a:
		if not (e is Dictionary):
			continue
		var st := ItemStack.from_dict(e.get("s", {}))
		if st == null or st.def() == null:
			continue
		var d := Drop.new()
		d.stack = st
		d.p = e.get("p", Vector3.ZERO)
		d.age = float(e.get("a", 0.0))
		d.landed = false
		list.append(d)
		_make_node(d)
