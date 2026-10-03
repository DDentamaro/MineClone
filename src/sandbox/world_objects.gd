class_name WorldObjects
extends Node3D
## Oggetti piazzati nel mondo (M5): banco da lavoro, fornace, forziere, falò e
## forzieri del tesoro. Ognuno occupa una cella d'aria sopra un blocco solido;
## non sono voxel (il catalogo resta quello del prototipo) ma il giocatore non li
## attraversa e i blocchi non ci si posano sopra.

const TYPES := ["workbench", "furnace", "chest", "campfire", "treasure", "armory", "armor_stand"]
## Contenuto dell'armeria: un'arma per tipo e gli attrezzi, di ferro (D-029).
## Dal D-054 le armature stanno sugli espositori.
const ARMORY_ITEMS: Array[StringName] = [&"sword_iron", &"spear_iron", &"hammer_iron", &"greatsword_iron",
	&"pick_iron", &"axe_iron", &"shovel_iron"]
## Espositori delle armature dell'arena (D-054): cuoio (con i due copricapo) e ferro.
const STAND_SETS := {
	"leather": [&"head_leather", &"head_leather_hood", &"chest_leather", &"legs_leather", &"feet_leather"],
	"iron": [&"head_iron", &"chest_iron", &"legs_iron", &"feet_iron"],
}
const RADIUS := 0.42

class Obj:
	extends RefCounted
	var type := ""
	var cell := Vector3i.ZERO
	var rot := 0
	var inv: Inventory
	var node: MeshInstance3D
	## Armeria: armi esposte sulla rastrelliera.
	var shown: Array[MeshInstance3D] = []
	## Espositore: manichino che indossa i pezzi contenuti.
	var rig: AvatarRig


var world: WorldData
var list: Array[Obj] = []
var _material: ShaderMaterial
var _meshes := {}


func _init() -> void:
	_material = ShaderMaterial.new()
	_material.shader = preload("res://src/presentation/shaders/actor.gdshader")


func clear() -> void:
	for o in list:
		if o.node != null:
			o.node.queue_free()
	list.clear()


func at(cell: Vector3i) -> Obj:
	for o in list:
		if o.cell == cell:
			return o
	return null


func can_place(cell: Vector3i) -> bool:
	if world == null or not world.inside(cell.x, cell.y, cell.z) or cell.y < 1:
		return false
	if world.get_block(cell) != BlockCatalog.AIR or not world.is_solid_at(cell.x, cell.y - 1, cell.z):
		return false
	return at(cell) == null


func place(type: String, cell: Vector3i, rot: int = 0) -> Obj:
	if not TYPES.has(type) or not can_place(cell):
		return null
	var o := Obj.new()
	o.type = type
	o.cell = cell
	o.rot = posmod(rot, 4)
	if type in ["chest", "treasure", "armory", "armor_stand"]:
		o.inv = Inventory.new(18)
	list.append(o)
	_make_node(o)
	_watch(o)
	return o


## Armeria ed espositori mostrano cio' che contengono: si aggiornano quando cambia.
func _watch(o: Obj) -> void:
	if o.inv == null or not o.type in ["armory", "armor_stand"]:
		return
	o.inv.changed.connect(func() -> void: refresh_display(o))
	refresh_display(o)


## D-054: rastrelliera larga, armi ben distanziate (una ogni mezzo metro).
const RACK_STEP := 0.5
const RACK_SLOTS := 4


## Armi dell'armeria in piedi sulla rastrelliera, una per posto e ben
## separate (D-054; gli attrezzi restano dentro ma non si espongono).
func refresh_display(o: Obj) -> void:
	if o.type == "armor_stand":
		_dress(o)
		return
	for n in o.shown:
		if is_instance_valid(n):
			n.queue_free()
	o.shown.clear()
	if o.node == null or o.inv == null:
		return
	var long: Array[ItemStack] = []
	for s in o.inv.slots:
		if s != null and s.def().kind == ItemDefinition.Kind.WEAPON and long.size() < RACK_SLOTS:
			long.append(s)
	for i in long.size():
		var d := long[i].def()
		var tint: Color = ItemLibrary.TIERS[clampi(d.tier - 1, 0, ItemLibrary.TIERS.size() - 1)]["color"]
		var mesh := WeaponMeshes.build(WeaponLibrary.by_id(d.weapon).kind, tint) if d.kind == ItemDefinition.Kind.WEAPON \
			else WeaponMeshes.build_tool(d.tool_type, tint)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _material
		var sc := AvatarRig.WEAPON_SCALE
		var bottom := mesh.get_aabb().position.y * sc
		mi.scale = Vector3.ONE * sc
		# In fila sulla base, appoggiati alla traversa (lieve inclinazione indietro).
		mi.position = Vector3((i - (RACK_SLOTS - 1) * 0.5) * RACK_STEP, 0.09 - bottom, -0.02)
		mi.rotation = Vector3(deg_to_rad(9.0), 0, 0)
		o.node.add_child(mi)
		o.shown.append(mi)
	_light(o)


## Armeria vicino allo spawn (fra 3 e 6 blocchi), piena come ARMORY_ITEMS.
func place_armory(spawn: Vector3, rng: RandomNumberGenerator = null) -> Obj:
	for o in list:
		if o.type == "armory":
			return o
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = 99
	for r in range(3, 7):
		for k in 16:
			var a := k * TAU / 16.0 + 2.2
			var x := floori(spawn.x + cos(a) * r)
			var z := floori(spawn.z + sin(a) * r)
			if x < 2 or z < 2 or x >= world.size_x - 2 or z >= world.size_z - 2:
				continue
			if world.water_level[z * world.size_x + x] != 0:
				continue
			var y := world.surface_height(x, z) + 1
			if absf(y - spawn.y) > 2.0:
				continue
			# Girata verso lo spawn.
			var to := Vector2(spawn.x - (x + 0.5), spawn.z - (z + 0.5))
			var rot := posmod(roundi(atan2(-to.x, -to.y) / (PI * 0.5)), 4)
			var o := place("armory", Vector3i(x, y, z), rot)
			if o == null:
				continue
			for id in ARMORY_ITEMS:
				o.inv.add(Loot.make_equipment(id, 0, rng))
			return o
	return null


## Espositore: il manichino indossa i pezzi che contiene (il primo per slot).
func _dress(o: Obj) -> void:
	if o.node == null or o.inv == null:
		return
	if o.rig == null:
		o.rig = AvatarRig.new()
		o.node.add_child(o.rig)
		o.rig.position = Vector3(0, 0.1, 0)
		o.rig.build(mannequin())
	var colors := {}
	var styles := {}
	for s in o.inv.slots:
		if s == null or s.def().kind != ItemDefinition.Kind.ARMOR or colors.has(s.def().slot):
			continue
		colors[s.def().slot] = Equipment.color_of(s.def())
		styles[s.def().slot] = s.def().armor_style
	o.rig.set_armor_all(colors, styles)
	_light(o)


## Manichino di legno degli espositori: niente capelli, viso liscio.
static func mannequin() -> AvatarRecipe:
	var r := AvatarRecipe.preset(0)
	r.dna = r.dna.duplicate()
	for k: String in ["skin"]:
		r.dna[k] = "#b88a5c"
	r.dna["hairStyle"] = "none"
	r.dna["tuft"] = false
	r.dna["eyes"] = "chiuso"
	r.dna["brows"] = "none"
	r.dna["mouth"] = "none"
	r.dna["nose"] = "none"
	r.dna["beard"] = "none"
	r.dna["shirt"] = "#a07a52"
	r.dna["pants"] = "#a07a52"
	r.dna["boots"] = "#8a6644"
	return r


## Arena (D-054): armeria al centro, espositori a ovest (cuoio) e a est
## (ferro) girati verso il centro. Ognuno si piazza una volta sola.
func place_arena(c: Vector3i, rng: RandomNumberGenerator = null) -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = 99
	if not list.any(func(o: Obj) -> bool: return o.type == "armory"):
		var a := place("armory", c, 0)
		if a != null:
			for id in ARMORY_ITEMS:
				a.inv.add(Loot.make_equipment(id, 0, rng))
	for e: Array in [["leather", Vector3i(-4, 0, 0), 1], ["iron", Vector3i(4, 0, 0), 3]]:
		var cell: Vector3i = c + e[1]
		if at(cell) != null:
			continue
		var o := place("armor_stand", cell, e[2])
		if o == null:
			continue
		for id: StringName in STAND_SETS[e[0]]:
			o.inv.add(Loot.make_equipment(id, 0, rng))


func remove(o: Obj) -> void:
	if o.node != null:
		o.node.queue_free()
	list.erase(o)


func center_of(o: Obj) -> Vector3:
	return Vector3(o.cell) + Vector3(0.5, 0.45, 0.5)


## Raccoglie l'oggetto (col contenuto) nello zaino; falso se non entra tutto.
## I forzieri del tesoro non si raccolgono.
func pick_up(o: Obj, inv: Inventory) -> bool:
	if o.type in ["treasure", "armory", "armor_stand"]:
		return false
	var items: Array[ItemStack] = [ItemStack.new(StringName(o.type))]
	if o.inv != null:
		for s in o.inv.slots:
			if s != null:
				items.append(s.duplicate_stack())
	# Prova su una copia: tutto o niente.
	var copy := Inventory.new(inv.size())
	for i in inv.size():
		copy.slots[i] = inv.slots[i].duplicate_stack() if inv.slots[i] != null else null
	for s in items:
		if copy.add(s.duplicate_stack()) > 0:
			return false
	for s in items:
		inv.add(s)
	remove(o)
	return true


## Oggetto colpito dal raggio (scatola della cella), o null.
func pick(origin: Vector3, dir: Vector3) -> Obj:
	var best: Obj = null
	var bt := INF
	for o in list:
		var lo := Vector3(o.cell) + Vector3(0.1, 0.0, 0.1)
		var hi := Vector3(o.cell) + Vector3(0.9, 0.9, 0.9)
		var t := _ray_box(origin, dir, lo, hi)
		if t >= 0.0 and t < bt:
			bt = t
			best = o
	return best


static func _ray_box(o: Vector3, d: Vector3, lo: Vector3, hi: Vector3) -> float:
	var t0 := -INF
	var t1 := INF
	for a in 3:
		if absf(d[a]) < 1e-8:
			if o[a] < lo[a] or o[a] > hi[a]:
				return -1.0
			continue
		var ta := (lo[a] - o[a]) / d[a]
		var tb := (hi[a] - o[a]) / d[a]
		t0 = maxf(t0, minf(ta, tb))
		t1 = minf(t1, maxf(ta, tb))
	if t1 < maxf(t0, 0.0):
		return -1.0
	return maxf(t0, 0.0)


## Stazioni entro `r` dal punto (per le ricette).
func stations_near(p: Vector3, r: float) -> Array:
	var out := []
	for o in list:
		if center_of(o).distance_to(p) <= r and not out.has(o.type):
			out.append(o.type)
	return out


func nearest(p: Vector3, type: String, r: float) -> Obj:
	var best: Obj = null
	var bd := r
	for o in list:
		if o.type == type and center_of(o).distance_to(p) <= bd:
			bd = center_of(o).distance_to(p)
			best = o
	return best


## Spinge fuori il punto `p` (piedi del giocatore) dagli oggetti.
func push_out(p: Vector3, r: float) -> Vector3:
	for o in list:
		var c := Vector3(o.cell) + Vector3(0.5, 0, 0.5)
		if p.y > c.y + 0.9 or p.y + 1.4 < c.y:
			continue
		var v := Vector2(p.x - c.x, p.z - c.z)
		var rr := RADIUS + r
		if v.length() < rr:
			var n := v.normalized() if v.length() > 1e-4 else Vector2(1, 0)
			p.x = c.x + n.x * rr
			p.z = c.z + n.y * rr
	return p


## Forzieri del tesoro sparsi nel mondo, deterministici per seme.
func scatter_treasure(seed_value: int, spawn: Vector3, n: int = 10) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 17
	var tries := 0
	var placed := 0
	while placed < n and tries < 400:
		tries += 1
		var a := rng.randf() * TAU
		var d := rng.randf_range(14.0, 80.0)
		var x := floori(spawn.x + cos(a) * d)
		var z := floori(spawn.z + sin(a) * d)
		if x < 2 or z < 2 or x >= world.size_x - 2 or z >= world.size_z - 2:
			continue
		if world.water_level[z * world.size_x + x] != 0:
			continue
		var y := world.surface_height(x, z) + 1
		var o := place("treasure", Vector3i(x, y, z), rng.randi() % 4)
		if o == null:
			continue
		fill_treasure(o.inv, d / 80.0, rng)
		placed += 1


## Bottino: materiali e 1–2 pezzi di equipaggiamento, migliori lontano dallo spawn.
static func fill_treasure(inv: Inventory, far: float, rng: RandomNumberGenerator) -> void:
	var mats := [[&"wood", 4, 10], [&"stick", 2, 6], [&"copper_ingot", 1, 4], [&"iron_ingot", 0, 3], [&"gold_ingot", 0, 2], [&"torch", 2, 6]]
	for m: Array in mats:
		var k := rng.randi_range(int(m[1]), int(m[2]))
		if k > 0 and rng.randf() < 0.7:
			inv.add_item(m[0], k)
	var tiers := ["stone", "copper", "iron", "gold"] if far > 0.5 else ["wood", "stone", "copper", "iron"]
	var kinds := ["sword", "spear", "hammer", "greatsword", "pick", "axe", "shovel", "head", "chest", "legs", "feet"]
	for i in rng.randi_range(1, 2):
		var tier: String = tiers[rng.randi() % tiers.size()]
		var kind: String = kinds[rng.randi() % kinds.size()]
		var id := StringName("%s_%s" % [kind, tier])
		if ItemLibrary.get_item(id) == null:
			id = StringName("%s_%s" % [kind, "copper"])
		var w := [10.0, 45.0, 32.0, 13.0] if far > 0.5 else [25.0, 50.0, 20.0, 5.0]
		inv.add(Loot.make_equipment(id, Loot.roll_rarity(rng, w), rng))


func _make_node(o: Obj) -> void:
	if not _meshes.has(o.type):
		_meshes[o.type] = build_mesh(o.type)
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[o.type]
	mi.material_override = _material
	mi.position = Vector3(o.cell) + Vector3(0.5, 0, 0.5)
	mi.rotation.y = o.rot * PI * 0.5
	add_child(mi)
	o.node = mi
	_light(o)


func _light(o: Obj) -> void:
	if world == null or o.node == null:
		return
	var i := world.index(o.cell.x, o.cell.y, o.cell.z)
	o.node.set_instance_shader_parameter(&"sun_here", world.sun[i] / 15.0)
	o.node.set_instance_shader_parameter(&"blk_here", maxf(world.blk[i] / 15.0, 0.55 if o.type == "campfire" or o.type == "furnace" else 0.0))
	for n in o.shown:
		if is_instance_valid(n):
			n.set_instance_shader_parameter(&"sun_here", world.sun[i] / 15.0)
			n.set_instance_shader_parameter(&"blk_here", world.blk[i] / 15.0)
	if o.rig != null:
		var j := world.index(o.cell.x, mini(o.cell.y + 1, world.size_y - 1), o.cell.z)
		o.rig.set_light(world.sun[j] / 15.0, world.blk[j] / 15.0)


## Aggiorna la luce degli oggetti (dopo edit vicini).
func refresh_light() -> void:
	for o in list:
		_light(o)


static func build_mesh(type: String) -> ArrayMesh:
	var k := MeshKit.new()
	var wood := Color(0.60, 0.42, 0.24)
	var dark := Color(0.34, 0.22, 0.12)
	var metal := Color(0.55, 0.56, 0.58)
	match type:
		"workbench":
			k.box(Vector3(0, 0.72, 0), Vector3(0.86, 0.1, 0.86), wood.lightened(0.1), 0.02)
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					k.box(Vector3(0.34 * sx, 0.34, 0.34 * sz), Vector3(0.1, 0.68, 0.1), dark, 0.015)
			k.box(Vector3(0, 0.2, 0), Vector3(0.74, 0.05, 0.74), dark, 0.01)
			k.box(Vector3(-0.2, 0.8, 0.1), Vector3(0.3, 0.06, 0.1), metal, 0.01)
			k.box(Vector3(0.22, 0.79, -0.18), Vector3(0.12, 0.04, 0.3), Color(0.7, 0.66, 0.6), 0.01)
		"furnace":
			k.box(Vector3(0, 0.42, 0), Vector3(0.86, 0.84, 0.86), Color(0.50, 0.49, 0.50), 0.05)
			k.box(Vector3(0, 0.3, -0.43), Vector3(0.36, 0.3, 0.04), Color(1.0, 0.55, 0.18), 0.01)
			k.box(Vector3(0, 0.88, 0.2), Vector3(0.22, 0.14, 0.22), Color(0.36, 0.35, 0.36), 0.02)
		"armory":
			# Rastrelliera larga (D-054): base, tre montanti, traversa e cimasa,
			# un posto ogni mezzo metro con la sua tacca d'ottone.
			var wdt := RACK_STEP * RACK_SLOTS + 0.1
			k.box(Vector3(0, 0.04, 0), Vector3(wdt, 0.08, 0.46), dark, 0.02)
			for sx in [-1.0, 0.0, 1.0]:
				k.box(Vector3(wdt * 0.5 * sx - 0.035 * sx, 0.55, 0.16), Vector3(0.08, 1.1, 0.08), wood, 0.015)
			k.box(Vector3(0, 0.74, 0.16), Vector3(wdt, 0.07, 0.07), wood.lightened(0.1), 0.015)
			k.box(Vector3(0, 1.08, 0.16), Vector3(wdt + 0.04, 0.07, 0.10), dark, 0.015)
			for i in RACK_SLOTS:
				k.box(Vector3((i - (RACK_SLOTS - 1) * 0.5) * RACK_STEP, 0.79, 0.12), Vector3(0.08, 0.04, 0.03), Color(0.78, 0.62, 0.3), 0.008)
		"armor_stand":
			# Pedana tonda del manichino con il bordo scuro.
			k.prism(Vector3.ZERO, 0.0, 0.1, 0.4, 0.38, 10, wood)
			k.prism(Vector3.ZERO, 0.0, 0.04, 0.42, 0.42, 10, dark)
		"chest", "treasure":
			var body := wood if type == "chest" else Color(0.40, 0.24, 0.16)
			var band := metal if type == "chest" else Color(0.92, 0.74, 0.28)
			k.box(Vector3(0, 0.26, 0), Vector3(0.8, 0.52, 0.6), body, 0.03)
			k.box(Vector3(0, 0.6, 0), Vector3(0.82, 0.18, 0.62), body.lightened(0.08), 0.05)
			for sx in [-1.0, 1.0]:
				k.box(Vector3(0.3 * sx, 0.36, 0), Vector3(0.06, 0.74, 0.64), band, 0.01)
			k.box(Vector3(0, 0.46, -0.31), Vector3(0.12, 0.14, 0.04), band, 0.01)
		"campfire":
			for i in 6:
				var a := TAU * i / 6.0
				k.box(Vector3(cos(a) * 0.36, 0.06, sin(a) * 0.36), Vector3(0.16, 0.12, 0.16), Color(0.5, 0.5, 0.52), 0.04)
			for i in 3:
				var xf := MeshKit.rot_about(Vector3(0, 1, 0), i * PI / 3.0, Vector3.ZERO)
				k.box(Vector3(0, 0.1, 0), Vector3(0.62, 0.09, 0.09), dark, 0.02, 1.0, xf)
			k.box(Vector3(0, 0.2, 0), Vector3(0.14, 0.14, 0.14), Color(1.0, 0.62, 0.2), 0.03)
	return k.commit()


func to_array() -> Array:
	var out := []
	for o in list:
		out.append({"t": o.type, "c": [o.cell.x, o.cell.y, o.cell.z], "r": o.rot, "inv": o.inv.to_array() if o.inv != null else null})
	return out


func load_array(a: Array) -> void:
	clear()
	for d in a:
		if not (d is Dictionary):
			continue
		var c: Array = d.get("c", [0, 0, 0])
		var o := Obj.new()
		o.type = String(d.get("t", ""))
		if not TYPES.has(o.type):
			continue
		o.cell = Vector3i(int(c[0]), int(c[1]), int(c[2]))
		o.rot = int(d.get("r", 0))
		if d.get("inv") is Array:
			o.inv = Inventory.new(18)
			o.inv.load_array(d["inv"])
		if o.type == "armor_stand" and o.inv == null:
			o.inv = Inventory.new(18)
		list.append(o)
		_make_node(o)
		_watch(o)
