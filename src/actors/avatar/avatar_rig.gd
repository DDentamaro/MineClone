class_name AvatarRig
extends Node3D
## Scheletro a pezzi rigidi dell'eroe (M4, disegno nuovo). Ogni osso e' un
## Node3D con la sua mesh a scatole smussate; l'animazione imposta solo le
## rotazioni (e lo spostamento di `body`).
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
const UPPER_ARM := 0.24
const FOREARM := 0.215
const HAND := 0.05
const HEIGHT := 1.46

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


func _init() -> void:
	_material = ShaderMaterial.new()
	_material.shader = preload("res://src/presentation/shaders/actor.gdshader")


func build(r: AvatarRecipe) -> void:
	recipe = r
	for c in get_children():
		remove_child(c)
		c.queue_free()
	bones.clear()
	rest.clear()
	_instances.clear()
	_weapon_nodes.clear()
	var w := r.width()
	var skin := r.skin_color()
	var shirt := r.shirt_color()
	var pants := r.pants_color()
	var leather := Color(0.33, 0.21, 0.13)
	var pos := {&"body": Vector3.ZERO, &"hips": Vector3(0, 0.62, 0), &"spine": Vector3(0, 0.06, 0), &"chest": Vector3(0, 0.16, 0),
		&"head": Vector3(0, 0.27, 0), &"arm_r": Vector3(0.235 * w, 0.215, 0), &"arm_l": Vector3(-0.235 * w, 0.215, 0),
		&"fore_r": Vector3(0, -UPPER_ARM, 0), &"fore_l": Vector3(0, -UPPER_ARM, 0), &"hand_r": Vector3(0, -FOREARM, 0),
		&"hand_l": Vector3(0, -FOREARM, 0), &"leg_r": Vector3(0.095 * w, -0.04, 0), &"leg_l": Vector3(-0.095 * w, -0.04, 0),
		&"shin_r": Vector3(0, -0.28, 0), &"shin_l": Vector3(0, -0.28, 0)}
	for b in BONES:
		var n := Node3D.new()
		n.name = String(b)
		n.position = pos[b]
		rest[b] = pos[b]
		bones[b] = n
		var parent: Node3D = self if b == &"body" else bones[PARENT[b]]
		parent.add_child(n)
	var k: MeshKit
	# Bacino e cintura.
	k = MeshKit.new()
	k.box(Vector3(0, -0.02, 0), Vector3(0.32 * w, 0.16, 0.2), pants, 0.03)
	k.box(Vector3(0, 0.05, 0), Vector3(0.335 * w, 0.05, 0.212), leather, 0.012)
	k.box(Vector3(0, 0.05, -0.108), Vector3(0.06, 0.045, 0.01), Color(0.78, 0.62, 0.3), 0.004)
	_mesh(&"hips", k)
	k = MeshKit.new()
	k.box(Vector3(0, 0.08, 0), Vector3(0.3 * w, 0.18, 0.19), shirt.darkened(0.06), 0.03)
	_mesh(&"spine", k)
	k = MeshKit.new()
	k.box(Vector3(0, 0.13, 0), Vector3(0.41 * w, 0.27, 0.24), shirt, 0.045, 0.84)
	k.box(Vector3(0, 0.255, 0), Vector3(0.2, 0.04, 0.16), shirt.darkened(0.15), 0.012)
	# Tracolla in diagonale.
	var strap := MeshKit.rot_about(Vector3(0, 0, 1), deg_to_rad(-38.0), Vector3(0, 0.13, 0))
	k.box(Vector3(0, 0.13, 0), Vector3(0.06, 0.4, 0.252), leather, 0.01, 1.0, strap)
	_mesh(&"chest", k)
	_mesh(&"head", _head(r, skin))
	for side in [&"r", &"l"]:
		var sx := 1.0 if side == &"r" else -1.0
		k = MeshKit.new()
		k.box(Vector3(0, -0.11, 0), Vector3(0.125 * w, 0.25, 0.125 * w), shirt, 0.03)
		k.box(Vector3(0.012 * sx, -0.005, 0), Vector3(0.15 * w, 0.08, 0.15 * w), shirt.darkened(0.12), 0.03)
		_mesh(StringName("arm_" + side), k)
		k = MeshKit.new()
		k.box(Vector3(0, -0.1, 0), Vector3(0.105, 0.22, 0.105), skin, 0.028)
		k.box(Vector3(0, -0.16, 0), Vector3(0.12, 0.085, 0.12), leather, 0.02)
		_mesh(StringName("fore_" + side), k)
		k = MeshKit.new()
		k.box(Vector3(0, -HAND, 0), Vector3(0.11, 0.11, 0.12), skin, 0.03)
		k.box(Vector3(-0.055 * sx, -0.035, -0.04), Vector3(0.04, 0.07, 0.045), skin.darkened(0.05), 0.012)
		_mesh(StringName("hand_" + side), k)
		k = MeshKit.new()
		k.box(Vector3(0, -0.13, 0), Vector3(0.145 * w, 0.28, 0.155), pants, 0.03, 0.9)
		_mesh(StringName("leg_" + side), k)
		k = MeshKit.new()
		k.box(Vector3(0, -0.11, 0), Vector3(0.125, 0.24, 0.14), pants.darkened(0.1), 0.028, 0.9)
		k.box(Vector3(0, -0.255, -0.022), Vector3(0.14, 0.09, 0.215), leather, 0.025)
		k.box(Vector3(0, -0.175, 0), Vector3(0.145, 0.06, 0.15), leather.lightened(0.1), 0.02)
		_mesh(StringName("shin_" + side), k)
	socket = Node3D.new()
	socket.name = "Socket"
	socket.position = Vector3(0, -HAND, 0)
	socket.rotation = Vector3(deg_to_rad(-90.0), 0, 0)
	(bones[&"hand_r"] as Node3D).add_child(socket)
	if weapon != null:
		var wd := weapon
		weapon = null
		set_weapon(wd)


func _head(r: AvatarRecipe, skin: Color) -> MeshKit:
	var k := MeshKit.new()
	var hair := r.hair_color()
	var dark := Color(0.1, 0.08, 0.08)
	k.prism(Vector3.ZERO, -0.02, 0.05, 0.06, 0.055, 6, skin.darkened(0.08))
	k.box(Vector3(0, 0.19, 0), Vector3(0.34, 0.33, 0.31), skin, 0.055)
	# Occhi, sopracciglia, naso, bocca, orecchie.
	for sx in [-1.0, 1.0]:
		k.box(Vector3(0.075 * sx, 0.195, -0.152), Vector3(0.05, 0.07, 0.014), dark, 0.006)
		k.box(Vector3(0.085 * sx, 0.212, -0.158), Vector3(0.018, 0.022, 0.006), Color(0.95, 0.95, 0.9), 0.0)
		k.box(Vector3(0.08 * sx, 0.255, -0.153), Vector3(0.075, 0.022, 0.014), hair.darkened(0.2), 0.005)
		k.box(Vector3(0.172 * sx, 0.18, 0.0), Vector3(0.03, 0.07, 0.06), skin.darkened(0.06), 0.01)
	k.box(Vector3(0, 0.145, -0.16), Vector3(0.05, 0.06, 0.03), skin.darkened(0.1), 0.01)
	k.box(Vector3(0, 0.085, -0.153), Vector3(0.08, 0.016, 0.012), Color(0.45, 0.2, 0.18), 0.0)
	match r.hair_style:
		0: # corti
			k.box(Vector3(0, 0.325, 0.01), Vector3(0.365, 0.1, 0.335), hair, 0.035)
			k.box(Vector3(0, 0.22, 0.145), Vector3(0.365, 0.22, 0.06), hair, 0.03)
		1: # ciuffo
			k.box(Vector3(0, 0.325, 0.01), Vector3(0.365, 0.1, 0.335), hair, 0.035)
			k.box(Vector3(0, 0.22, 0.145), Vector3(0.365, 0.22, 0.06), hair, 0.03)
			k.box(Vector3(0.05, 0.36, -0.13), Vector3(0.2, 0.1, 0.1), hair.lightened(0.08), 0.03, 1.0, MeshKit.rot_about(Vector3(0, 0, 1), 0.3, Vector3(0.05, 0.36, -0.13)))
		2: # coda
			k.box(Vector3(0, 0.325, 0.01), Vector3(0.365, 0.1, 0.335), hair, 0.035)
			k.box(Vector3(0, 0.22, 0.145), Vector3(0.365, 0.22, 0.06), hair, 0.03)
			k.box(Vector3(0, 0.16, 0.21), Vector3(0.09, 0.26, 0.09), hair, 0.03, 0.5)
			k.box(Vector3(0, 0.3, 0.19), Vector3(0.1, 0.05, 0.06), Color(0.7, 0.2, 0.15), 0.01)
		3: # rasati
			k.box(Vector3(0, 0.345, 0.005), Vector3(0.35, 0.035, 0.32), hair.darkened(0.1), 0.012)
		_: # lunghi
			k.box(Vector3(0, 0.325, 0.01), Vector3(0.365, 0.1, 0.335), hair, 0.035)
			k.box(Vector3(0, 0.13, 0.15), Vector3(0.37, 0.38, 0.07), hair, 0.03, 0.9)
			for sx in [-1.0, 1.0]:
				k.box(Vector3(0.178 * sx, 0.2, 0.03), Vector3(0.04, 0.24, 0.24), hair, 0.015)
	return k


func _mesh(bone: StringName, k: MeshKit) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = k.commit()
	mi.material_override = _material
	(bones[bone] as Node3D).add_child(mi)
	_instances.append(mi)
	return mi


func set_weapon(w: WeaponDefinition) -> void:
	if w == weapon:
		return
	weapon = w
	for n in _weapon_nodes:
		_instances.erase(n)
		n.get_parent().remove_child(n)
		n.queue_free()
	_weapon_nodes.clear()
	if w == null or bones.is_empty():
		return
	var mesh := WeaponMeshes.build(w.kind)
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
