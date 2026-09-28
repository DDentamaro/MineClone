class_name AvatarRig
extends Node3D
## Scheletro a pezzi rigidi dell'eroe. Ogni osso e' un Node3D; l'animazione
## imposta solo le rotazioni (e lo spostamento di `body`). Da D-028 le misure e
## le mesh sono quelle dell'eroe del prototipo (CHARGEN, `HeroChargen`): anca
## .32, collo .80, omero .21, avambraccio+mano .28, coscia .15, stinco+piede
## .185, testa grande. Le gambe le muove `GaitLegs` (piedi piantati, IK).
##
## Assi (il personaggio guarda -Z, la sua destra e' +X):
## - braccia e gambe pendono lungo -Y; X positivo le porta in avanti/in alto;
##   Z positivo apre il braccio destro verso l'esterno (il sinistro con Z negativo);
##   Y positivo (applicato per ultimo) le gira verso la sinistra del personaggio;
## - avambraccio: X positivo piega il gomito; stinco: X negativo piega il ginocchio;
## - busto/testa: Y positivo ruota a sinistra, X negativo piega in avanti;
## - mano destra: con X = 0 l'arma e' perpendicolare all'avambraccio; la
##   direzione della lama nel piano sagittale vale braccio + avambraccio + mano + 90°.

const BONES: Array[StringName] = [&"body", &"hips", &"spine", &"chest", &"head", &"arm_l", &"fore_l", &"hand_l",
	&"arm_r", &"fore_r", &"hand_r", &"leg_l", &"shin_l", &"leg_r", &"shin_r"]
const PARENT := {&"hips": &"body", &"spine": &"hips", &"chest": &"spine", &"head": &"chest",
	&"arm_l": &"chest", &"fore_l": &"arm_l", &"hand_l": &"fore_l", &"arm_r": &"chest", &"fore_r": &"arm_r",
	&"hand_r": &"fore_r", &"leg_l": &"hips", &"shin_l": &"leg_l", &"leg_r": &"hips", &"shin_r": &"leg_r"}
const HIP_Y := 0.32
const HIP_W := 0.10
const THIGH := 0.15
const SHIN := 0.15
const UPPER_ARM := 0.21
const FOREARM := 0.19
const HAND := 0.04
const SHOULDER := Vector3(0.40, 0.19, 0.0)
## Altezza della testa senza capelli (collo .80 + testa .58).
const HEIGHT := 1.38
## Le armi di M4 sono lunghe per un eroe di 1,46 m con arti lunghi: nella mano
## dell'eroe del prototipo stanno a questa scala (spada ~0,7 come nel prototipo).
const WEAPON_SCALE := 0.72

var recipe := AvatarRecipe.new()
var bones := {}
var rest := {}
var weapon: WeaponDefinition
var socket: Node3D
## IK della mano sinistra sull'arma a due mani (spento mentre si lancia una magia).
var ik_enabled := true
var _material: ShaderMaterial
var _instances: Array[GeometryInstance3D] = []
var _weapon_nodes: Array[MeshInstance3D] = []
## Mesh dell'eroe gia' costruite per ricetta (l'occlusione cotta costa).
static var _mesh_cache := {}


func _init() -> void:
	_material = ShaderMaterial.new()
	_material.shader = preload("res://src/presentation/shaders/actor.gdshader")


static func chest_offset() -> Vector3:
	return Vector3(0, -(0.06 + 0.16), 0)


## Mesh per osso della ricetta con occlusione cotta (dalla cache), o null se
## non e' ancora pronta.
static func cached_meshes(r: AvatarRecipe) -> Variant:
	return _mesh_cache.get(r.to_json())


## Mesh con occlusione cotta, calcolate subito (test, strumenti).
static func hero_meshes(r: AvatarRecipe) -> Dictionary:
	var key := r.to_json()
	if not _mesh_cache.has(key):
		var parts := HeroChargen.build(r.dna, HeroChargen.hair_lib())
		HeroChargen.bake_ao(parts)
		_store(key, HeroChargen.to_rig(parts, {&"chest": chest_offset()}))
	return _mesh_cache[key]


static func _store(key: String, m: Dictionary) -> void:
	if _mesh_cache.size() > 8:
		_mesh_cache.clear()
	_mesh_cache[key] = m


## Occlusione in corso su un thread: ricetta e pezzi.
var _ao_task := -1
var _ao_key := ""
var _ao_parts: Array = []
## Vero per costruire sempre con l'occlusione subito (niente thread).
var sync_ao := false


func _process(_dt: float) -> void:
	if _ao_task < 0 or not WorkerThreadPool.is_task_completed(_ao_task):
		return
	WorkerThreadPool.wait_for_task_completion(_ao_task)
	_ao_task = -1
	_store(_ao_key, HeroChargen.to_rig(_ao_parts, {&"chest": chest_offset()}))
	_ao_parts = []
	# Pronta questa ricetta, o ne serve un'altra (cambiata nel frattempo).
	build(recipe)


func _exit_tree() -> void:
	if _ao_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_ao_task)
		_ao_task = -1


## Mesh da mostrare ora: con occlusione se pronte, altrimenti senza (e parte
## il calcolo dell'occlusione su un thread).
func _meshes_now(r: AvatarRecipe) -> Dictionary:
	var key := r.to_json()
	if _mesh_cache.has(key) or sync_ao or not is_inside_tree():
		return hero_meshes(r)
	var parts := HeroChargen.build(r.dna, HeroChargen.hair_lib())
	if _ao_task < 0:
		_ao_key = key
		var ao_parts := HeroChargen.build(r.dna, HeroChargen.hair_lib())
		_ao_parts = ao_parts
		_ao_task = WorkerThreadPool.add_task(func() -> void: HeroChargen.bake_ao(ao_parts), false, "occlusione eroe")
	return HeroChargen.to_rig(parts, {&"chest": chest_offset()})


func build(r: AvatarRecipe) -> void:
	recipe = r
	for c in get_children():
		remove_child(c)
		c.queue_free()
	bones.clear()
	rest.clear()
	_instances.clear()
	_weapon_nodes.clear()
	var pos := {&"body": Vector3.ZERO, &"hips": Vector3(0, HIP_Y, 0), &"spine": Vector3(0, 0.06, 0), &"chest": Vector3(0, 0.16, 0),
		&"head": Vector3(0, 0.26, 0), &"arm_r": SHOULDER, &"arm_l": SHOULDER * Vector3(-1, 1, 1),
		&"fore_r": Vector3(0, -UPPER_ARM, 0), &"fore_l": Vector3(0, -UPPER_ARM, 0), &"hand_r": Vector3(0, -FOREARM, 0),
		&"hand_l": Vector3(0, -FOREARM, 0), &"leg_r": Vector3(HIP_W, 0, 0), &"leg_l": Vector3(-HIP_W, 0, 0),
		&"shin_r": Vector3(0, -THIGH, 0), &"shin_l": Vector3(0, -THIGH, 0)}
	for b in BONES:
		var n := Node3D.new()
		n.name = String(b)
		n.position = pos[b]
		rest[b] = pos[b]
		bones[b] = n
		var parent: Node3D = self if b == &"body" else bones[PARENT[b]]
		parent.add_child(n)
	var meshes := _meshes_now(r)
	for b: StringName in meshes:
		for m: ArrayMesh in meshes[b]:
			_mesh_node(b, m)
	socket = Node3D.new()
	socket.name = "Socket"
	socket.position = Vector3(0, -HAND, 0)
	socket.rotation = Vector3(deg_to_rad(-90.0), 0, 0)
	socket.scale = Vector3.ONE * WEAPON_SCALE
	(bones[&"hand_r"] as Node3D).add_child(socket)
	if weapon != null:
		var wd := weapon
		var hm := held_mesh
		weapon = null
		set_weapon(wd, hm)
	var armor := _armor_colors.duplicate()
	_armor.clear()
	for slot_name: String in armor:
		set_armor(slot_name, armor[slot_name])


func _mesh_node(bone: StringName, m: ArrayMesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = _material
	(bones[bone] as Node3D).add_child(mi)
	_instances.append(mi)
	return mi


func _mesh(bone: StringName, k: MeshKit) -> MeshInstance3D:
	return _mesh_node(bone, k.commit())


## `mesh` sostituisce la mesh dell'arma (materiale dell'oggetto, attrezzi).
var held_mesh: ArrayMesh


func set_weapon(w: WeaponDefinition, mesh_override: ArrayMesh = null) -> void:
	if w == weapon and mesh_override == held_mesh:
		return
	weapon = w
	held_mesh = mesh_override
	for n in _weapon_nodes:
		_instances.erase(n)
		n.get_parent().remove_child(n)
		n.queue_free()
	_weapon_nodes.clear()
	if w == null or bones.is_empty():
		return
	var mesh := held_mesh if held_mesh != null else WeaponMeshes.build(w.kind)
	if w.kind == WeaponDefinition.Kind.FISTS:
		for h in [&"hand_r", &"hand_l"]:
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = _material
			(bones[h] as Node3D).add_child(mi)
			_weapon_nodes.append(mi)
	else:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _material
		socket.add_child(mi)
		_weapon_nodes.append(mi)
	_instances.append_array(_weapon_nodes)


## Applica una posa: osso -> rotazione (radianti); "body_pos" sposta il corpo.
func apply_pose(pose: Dictionary) -> void:
	for b: StringName in bones:
		var n: Node3D = bones[b]
		var r: Vector3 = pose.get(b, Vector3.ZERO)
		n.transform = Transform3D(Basis.from_euler(r), rest[b])
	var bp: Vector3 = pose.get(&"body_pos", Vector3.ZERO)
	(bones[&"body"] as Node3D).position = bp
	if weapon != null and weapon.two_handed and ik_enabled:
		solve_off_hand()


## IK a due ossa: la mano sinistra afferra l'impugnatura dell'arma. Tutto in
## spazio del rig (funziona anche fuori dall'albero, nei test).
func solve_off_hand() -> void:
	var arm: Node3D = bones[&"arm_l"]
	var fore: Node3D = bones[&"fore_l"]
	var hand: Node3D = bones[&"hand_l"]
	var chest_x := rig_xf(bones[&"chest"])
	var t: Vector3 = rig_xf(socket) * Vector3(0, weapon.off_grip, 0)
	var s := (chest_x * arm.transform).origin
	var a := UPPER_ARM
	var b := FOREARM + HAND
	var to := t - s
	var d := clampf(to.length(), 0.02, a + b - 0.002)
	var dir := to.normalized() if to.length() > 1e-5 else Vector3.DOWN
	var cb := chest_x.basis
	# Il gomito piega in basso, all'esterno e indietro.
	var pole := -cb.y * 0.6 - cb.x * 0.8 + cb.z * 0.4
	var perp := pole - dir * pole.dot(dir)
	perp = perp.normalized() if perp.length() > 1e-5 else cb.z
	var ca := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var e := s + a * (dir * ca + perp * sqrt(1.0 - ca * ca))
	var tgt := s + dir * d
	var arm_x := Transform3D(_aim(e - s, cb.z), s)
	arm.transform = chest_x.affine_inverse() * arm_x
	var fore_x := Transform3D(_aim(tgt - e, cb.z), e)
	fore.transform = arm_x.affine_inverse() * fore_x
	hand.transform = Transform3D(Basis.IDENTITY, hand.transform.origin)


## Trasformazione di un nodo del rig nello spazio del rig.
func rig_xf(n: Node3D) -> Transform3D:
	var x := n.transform
	var p := n.get_parent() as Node3D
	while p != null and p != self:
		x = p.transform * x
		p = p.get_parent() as Node3D
	return x


## Base con -Y lungo `down` e Z il piu' vicino possibile a `z_hint`.
static func _aim(down: Vector3, z_hint: Vector3) -> Basis:
	var y := -down.normalized()
	var z := z_hint - y * z_hint.dot(y)
	if z.length() < 1e-4:
		z = Vector3.FORWARD - y * Vector3.FORWARD.dot(y)
	z = z.normalized()
	var x := y.cross(z)
	return Basis(x, y, z)


## Base e punta della lama (per la scia), in coordinate globali.
func blade_segment() -> PackedVector3Array:
	if weapon == null or socket == null:
		return PackedVector3Array()
	var h: Node3D = socket
	if weapon.kind == WeaponDefinition.Kind.FISTS:
		h = bones[&"hand_r"]
		var x := h.global_transform
		return PackedVector3Array([x * Vector3(0, -0.02, 0), x * Vector3(0, -0.12, 0)])
	var g := h.global_transform
	return PackedVector3Array([g * Vector3(0, weapon.trail_from, 0), g * Vector3(0, weapon.trail_to, 0)])


## Punto di lancio della magia: palmo sinistro, in coordinate globali.
func cast_point() -> Vector3:
	var x := global_transform * rig_xf(bones[&"hand_l"]) if is_inside_tree() else rig_xf(bones[&"hand_l"])
	return x * Vector3(0, -HAND - 0.04, 0)


## Armatura indossata (M5): pezzi a scatole smussate sopra le ossa, nel colore
## del materiale. `mat` trasparente = slot vuoto.
var _armor := {}


var _armor_colors := {}


func set_armor(slot: String, mat: Color) -> void:
	_armor_colors[slot] = mat
	for n: MeshInstance3D in _armor.get(slot, []):
		_instances.erase(n)
		n.get_parent().remove_child(n)
		n.queue_free()
	_armor[slot] = []
	if mat.a <= 0.0 or bones.is_empty():
		return
	# Pezzi a cubi smussati nelle unita' del modello CHARGEN, poi nelle ossa.
	var W := HeroChargen.Builder.new()
	var band := mat.darkened(0.3)
	var hi := mat.lightened(0.18)
	var T: Dictionary = HeroChargen.BODY["torso"]
	var tmin: Vector3 = T["min"]
	var tmax: Vector3 = T["max"]
	var box := func(n: String, bone: String, mn: Vector3, mx: Vector3, r: float, col: Color) -> void:
		W.add(n, bone, HeroChargen.rbox(mn, mx, r, col))
	match slot:
		"head":
			box.call("elmo", "head", Vector3(-.63, 2.18, -.64), Vector3(.63, 2.76, .63), .16, mat)
			box.call("elmo", "head", Vector3(-.63, 1.76, -.64), Vector3(.63, 2.30, -.02), .08, mat)
			box.call("elmo", "head", Vector3(-.65, 2.16, -.66), Vector3(.65, 2.30, .65), .04, band)
			box.call("elmo", "head", Vector3(-.06, 1.80, .54), Vector3(.06, 2.30, .67), .03, band)
			for s in [1, -1]:
				box.call("elmo", "head", Vector3(.50 if s > 0 else -.65, 1.66, -.02), Vector3(.65 if s > 0 else -.50, 2.22, .30), .05, mat)
			box.call("elmo", "head", Vector3(-.07, 2.74, -.07), Vector3(.07, 2.92, .07), .04, hi)
		"chest":
			box.call("corazza", "torso", Vector3(tmin.x - .05, .98, tmin.z - .05), Vector3(tmax.x + .05, 1.50, tmax.z + .07), .10, mat)
			box.call("corazza", "torso", Vector3(-.30, 1.10, tmax.z + .03), Vector3(.30, 1.40, tmax.z + .10), .05, hi)
			box.call("corazza", "torso", Vector3(tmin.x - .04, .95, tmin.z - .04), Vector3(tmax.x + .04, 1.03, tmax.z + .06), .03, band)
			for s in [1, -1]:
				var m := "L" if s > 0 else "R"
				box.call("spallaccio", "arm" + m + "U", Vector3(.50 if s > 0 else -.84, 1.08, -.38), Vector3(.84 if s > 0 else -.50, 1.60, .26), .10, mat)
				box.call("spallaccio", "arm" + m + "U", Vector3(.78 if s > 0 else -.86, 1.06, -.40), Vector3(.86 if s > 0 else -.78, 1.62, .28), .03, band)
		"legs":
			box.call("fiancale", "torso", Vector3(tmin.x - .04, .72, tmin.z - .04), Vector3(tmax.x + .04, .95, tmax.z + .06), .05, band)
			for s in [1, -1]:
				var m := "L" if s > 0 else "R"
				var lx := [-.02, .53] if s > 0 else [-.53, .02]
				box.call("cosciale", "leg" + m + "U", Vector3(lx[0], .42, -.36), Vector3(lx[1], .78, .24), .10, mat)
				box.call("ginocchiera", "leg" + m + "F", Vector3(lx[0] + .1, .30, .14), Vector3(lx[1] - .1, .46, .27), .05, hi)
		"feet":
			for s in [1, -1]:
				var m := "L" if s > 0 else "R"
				var lx := [-.02, .53] if s > 0 else [-.53, .02]
				box.call("stivale", "leg" + m + "F", Vector3(lx[0], -.01, -.36), Vector3(lx[1], .30, .30), .10, mat)
				box.call("stivale", "leg" + m + "F", Vector3(lx[0] + .02, .26, -.37), Vector3(lx[1] - .02, .33, .26), .03, band)
	var meshes := HeroChargen.to_rig(W.parts, {&"chest": chest_offset()})
	var list: Array = []
	for b: StringName in meshes:
		for m: ArrayMesh in meshes[b]:
			list.append(_mesh_node(b, m))
	_armor[slot] = list


func set_light(sun: float, blk: float) -> void:
	for gi in _instances:
		gi.set_instance_shader_parameter(&"sun_here", sun)
		gi.set_instance_shader_parameter(&"blk_here", blk)


func set_flash(v: float, tint: Color = Color.WHITE) -> void:
	for gi in _instances:
		gi.set_instance_shader_parameter(&"flash", v)
		gi.set_instance_shader_parameter(&"tint", Vector3(tint.r, tint.g, tint.b))


func instance_count() -> int:
	return _instances.size()
