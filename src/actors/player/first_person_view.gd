class_name FirstPersonView
extends Node3D
## Braccio in prima persona (D-037, D-038): figlio della camera, mostra solo il
## braccio dritto (omero e avambraccio con la manica) e la mano con
## l'oggetto impugnato (copie delle mesh dell'eroe: arma, attrezzo,
## blocco, guanti dei pugni) mentre il corpo vero diventa invisibile alla camera
## (resta la sua ombra e restano le sue hitbox, che fanno i colpi veri).
## La mano si anima da sola, a partire dallo stato del combattimento: guardia,
## fendente da un lato all'altro, affondo, colpo dall'alto, montante, carica,
## scavo, capriola, cambio d'arma e un filo di passo.
##
## Pose in spazio camera (x destra, y su, -z avanti): posizione della mano,
## direzione della lama (o delle nocche) e direzione avambraccio (dal gomito
## alla mano, resa perpendicolare alla lama come nella presa del rig).

const FOREARM := AvatarRig.FOREARM
const UPPER_ARM := AvatarRig.UPPER_ARM
## D-040: piu' piccolo (era 0,46) e spostato a destra, ingombra meno lo schermo.
const SCALE := 0.36
## Spostamento di tutto il braccio (spazio camera): a destra e un filo in basso;
## coi pugni il braccio sinistro si sposta a sinistra (specchio).
const SHIFT := Vector3(0.1, -0.03, 0.0)
## Braccio dritto: l'omero continua l'avambraccio fino alla spalla, fuori dallo schermo.
const ELBOW_FLEX := 0.0
## L'oggetto in mano appare un po' piu' grande che sull'eroe (D-039; D-040 1,35 -> 1,1).
const HELD_GROW := 1.1

class Pose:
	extends RefCounted
	var hand := Vector3.ZERO
	var blade := Vector3.UP
	var arm := Vector3.FORWARD

	func _init(h: Vector3 = Vector3.ZERO, b: Vector3 = Vector3.UP, f: Vector3 = Vector3.FORWARD) -> void:
		hand = h
		blade = b.normalized()
		arm = f.normalized()

	func mirrored() -> Pose:
		return Pose.new(hand * Vector3(-1, 1, 1), blade * Vector3(-1, 1, 1), arm * Vector3(-1, 1, 1))

	static func mix(a: Pose, b: Pose, t: float) -> Pose:
		return Pose.new(a.hand.lerp(b.hand, t), a.blade.lerp(b.blade, t), a.arm.lerp(b.arm, t))


# Pose chiave (lato destro; il sinistro e' lo specchio).
static var REST := Pose.new(Vector3(0.21, -0.19, -0.48), Vector3(-0.15, 0.85, -0.5), Vector3(-0.3, 0.5, -0.8))
static var ARC_W := Pose.new(Vector3(0.36, -0.06, -0.46), Vector3(0.75, 0.55, 0.35), Vector3(0.2, 0.6, -0.7))
static var ARC_M := Pose.new(Vector3(0.12, -0.20, -0.56), Vector3(0.0, 0.15, -1.0), Vector3(-0.2, 0.3, -0.9))
static var ARC_S := Pose.new(Vector3(-0.28, -0.28, -0.46), Vector3(-0.85, -0.2, 0.45), Vector3(-0.7, 0.1, -0.7))
static var THRUST_W := Pose.new(Vector3(0.22, -0.21, -0.38), Vector3(-0.05, 0.12, -1.0), Vector3(-0.1, 0.95, -0.3))
static var THRUST_S := Pose.new(Vector3(0.10, -0.20, -0.74), Vector3(-0.05, 0.08, -1.0), Vector3(-0.1, 0.9, -0.4))
static var OVER_W := Pose.new(Vector3(0.17, 0.06, -0.38), Vector3(0.0, 0.6, 0.8), Vector3(-0.2, 0.8, -0.5))
static var OVER_M := Pose.new(Vector3(0.12, -0.08, -0.56), Vector3(0.0, 0.55, -0.85), Vector3(-0.2, 0.7, -0.7))
static var OVER_S := Pose.new(Vector3(0.06, -0.36, -0.56), Vector3(0.0, -0.6, -0.8), Vector3(-0.2, 0.6, -0.8))
static var UP_W := Pose.new(Vector3(0.19, -0.34, -0.42), Vector3(0.0, -0.3, -0.95), Vector3(-0.2, 0.5, -0.8))
static var UP_S := Pose.new(Vector3(0.12, 0.02, -0.55), Vector3(0.0, 0.95, 0.3), Vector3(-0.2, 0.9, -0.4))

## Impugnature: [destra] o [destra, sinistra] con i pugni.
var _grips: Array[Node3D] = []
var _instances: Array[GeometryInstance3D] = []
var _key := ""
var _t := 0.0
var _light := Vector2(1, 0)


## Ricostruisce le copie quando cambiano eroe, arma o oggetto in mano.
func sync_from(rig: AvatarRig) -> void:
	if rig == null or rig.bones.is_empty():
		return
	var fists := rig.weapon != null and rig.weapon.kind == WeaponDefinition.Kind.FISTS
	var key := "%d|%s|%d|%d" % [(rig.bones[&"fore_r"] as Node3D).get_instance_id(), String(rig.weapon.id) if rig.weapon != null else "",
		rig.held_mesh.get_instance_id() if rig.held_mesh != null else 0, rig.instance_count()]
	if key == _key:
		return
	_key = key
	for g in _grips:
		g.queue_free()
	_grips.clear()
	_instances.clear()
	var sides: Array[StringName] = [&"r"]
	if fists:
		sides.append(&"l")
	for side in sides:
		var grip := _clone(rig.bones[StringName("fore_" + side)])
		# La mano nella presa di riposo del rig (arma perpendicolare all'avambraccio).
		var hand := grip.get_node_or_null(NodePath("hand_" + side)) as Node3D
		if hand != null:
			hand.transform = Transform3D(Basis.IDENTITY, Vector3(0, -FOREARM, 0))
			var sock := hand.get_node_or_null(^"Socket") as Node3D
			if sock != null:
				sock.scale *= HELD_GROW
		# Omero: le mesh dell'osso del braccio, col gomito sull'origine
		# dell'avambraccio, in linea con esso (braccio dritto).
		var upper := Node3D.new()
		upper.name = "omero"
		var ub := Basis(Vector3.RIGHT, ELBOW_FLEX)
		upper.transform = Transform3D(ub, ub * Vector3(0, UPPER_ARM, 0))
		for c in (rig.bones[StringName("arm_" + side)] as Node3D).get_children():
			if c is MeshInstance3D:
				upper.add_child(_clone(c))
		grip.add_child(upper)
		grip.scale = Vector3.ONE * SCALE
		add_child(grip)
		_grips.append(grip)
	set_light(_light.x, _light.y)


func _clone(src: Node3D) -> Node3D:
	var n: Node3D
	if src is MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.mesh = (src as MeshInstance3D).mesh
		mi.material_override = (src as MeshInstance3D).material_override
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_instances.append(mi)
		n = mi
	else:
		n = Node3D.new()
	n.name = src.name
	n.transform = src.transform
	for c in src.get_children():
		if c is Node3D:
			n.add_child(_clone(c))
	return n


func set_light(sun: float, blk: float) -> void:
	_light = Vector2(sun, blk)
	for gi in _instances:
		gi.set_instance_shader_parameter(&"sun_here", sun)
		gi.set_instance_shader_parameter(&"blk_here", blk)


func grip_count() -> int:
	return _grips.size()


## Un passo: `speed` del corpo, `mining` fase dello scavo (-1 fermo), `swap`
## cambio d'arma 0..1..0.
func update(dt: float, combat: CombatController, speed: float, mining: float, swap: float) -> void:
	_t += dt
	var fists := _grips.size() > 1
	# A mani nude le braccia hanno la stessa forma di quando si impugna (D-039).
	var rest := REST
	var right := rest
	var left := rest.mirrored()
	var a := combat.attack if combat.state == CombatController.State.ATTACK else null
	if a != null:
		var use_left := fists and a.key_strike.has(&"arm_l") and not a.key_strike.has(&"arm_r")
		var p := _attack_pose(a, combat, use_left, rest)
		if use_left:
			left = p.mirrored()
		else:
			right = p
	elif combat.state == CombatController.State.DODGE:
		var d := sin(PI * clampf(combat.dodge_u(), 0.0, 1.0))
		right = Pose.new(rest.hand + Vector3(0, -0.22 * d, 0.05 * d), rest.blade, rest.arm)
		left = right.mirrored()
	elif mining >= 0.0:
		# Scavo: colpo dall'alto ripetuto.
		var u := fposmod(mining, 1.0)
		right = Pose.mix(OVER_W, OVER_S, _smooth(u / 0.45)) if u < 0.45 else Pose.mix(OVER_S, rest, _smooth((u - 0.45) / 0.55))
	# Passo: la mano oscilla appena; cambio d'arma: la mano scende fuori vista.
	var k := clampf(speed / PlayerMotor.SPEED, 0.0, 1.0)
	var bob := Vector3(sin(_t * 8.0) * 0.010, -absf(cos(_t * 8.0)) * 0.012, 0) * k
	var drop := Vector3(0, -0.45 * clampf(swap, 0.0, 1.0), 0)
	_place(0, right, bob + drop + SHIFT)
	if fists:
		_place(1, left, (bob + SHIFT) * Vector3(-1, 1, 1) + drop)


## Posa del colpo per il braccio destro; `left` = colpo del braccio sinistro
## (pugni): si legge dalle pose chiave del braccio sinistro con l'arco
## specchiato, e chi chiama specchia la posa sul lato sinistro.
func _attack_pose(a: AttackDefinition, c: CombatController, left: bool, rest: Pose) -> Pose:
	var w: Pose
	var m: Pose = null
	var s: Pose
	var arm := &"arm_l" if left else &"arm_r"
	var arm_w: Vector3 = a.key_wind.get(arm, Vector3.ZERO)
	var arm_s: Vector3 = a.key_strike.get(arm, Vector3.ZERO)
	var arc_from := -a.arc_from if left else a.arc_from
	if a.shape == AttackDefinition.Shape.ARC:
		w = ARC_W
		m = ARC_M
		s = ARC_S
		if arc_from > 0.0:
			# Da sinistra verso destra (rovescio).
			w = w.mirrored()
			m = m.mirrored()
			s = s.mirrored()
	elif a.shape == AttackDefinition.Shape.RADIAL or a.plunge or arm_w.x > deg_to_rad(120.0):
		w = OVER_W
		m = OVER_M
		s = OVER_S
	elif arm_s.x > deg_to_rad(115.0) and arm_w.x < deg_to_rad(60.0):
		w = UP_W
		s = UP_S
	else:
		w = THRUST_W
		s = THRUST_S
	var ph := c.phase()
	var u := c.phase_u()
	match ph:
		0:
			var p := Pose.mix(rest, w, _smooth(u))
			if c.charging:
				# Carica: la mano trema sulla posa di partenza.
				p.hand += Vector3(sin(_t * 61.0), cos(_t * 53.0), 0) * 0.004 * (1.0 + c.charge_fraction())
			return p
		1:
			var e := 1.0 - pow(1.0 - clampf(u, 0.0, 1.0), 2.0)
			if m == null:
				return Pose.mix(w, s, e)
			return Pose.mix(Pose.mix(w, m, e), Pose.mix(m, s, e), e)
	return Pose.mix(s, rest, _smooth(u))


## Mette l'impugnatura `i` nella posa: gomito = mano - avambraccio, assi
## -Y = avambraccio, -Z = lama (come l'osso dell'avambraccio e la presa del rig).
func _place(i: int, p: Pose, off: Vector3) -> void:
	if i >= _grips.size():
		return
	var b := p.blade.normalized()
	var f := p.arm - b * p.arm.dot(b)
	f = f.normalized() if f.length() > 1e-4 else Vector3.FORWARD
	var y := -f
	var z := -b
	var x := y.cross(z).normalized()
	var hand := p.hand + off
	_grips[i].transform = Transform3D(Basis(x, y, z).scaled(Vector3.ONE * SCALE), hand - f * FOREARM * SCALE)


static func _smooth(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)
