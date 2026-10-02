class_name GaitLegs
extends RefCounted
## Locomozione procedurale dell'eroe del prototipo (D-028): porting di
## `CharacterRig.updateAnimation` (HTML 6221–6357, costanti GAIT a 5775). Piedi
## piantati nel mondo, passo con arco 9,48(1-u)^3 u verso un bersaglio
## ri-stimato ogni frame (casa + avanzamento del corpo nel tempo residuo +
## meta' della corsa d'appoggio), cadenza e fattore d'appoggio che dipendono
## dalla velocita' (camminata -> corsa con fase di volo), passo di assestamento
## da fermi, bacino che scende se una gamba piantata non arriva, bob a doppia
## frequenza, ondeggio verso la gamba d'appoggio, inclinazione con
## l'accelerazione, gambe raccolte in aria. IK a due ossa col ginocchio in avanti.
##
## Spazio locale = spazio del rig (piedi all'origine, davanti -Z, destra +X).

# D-045: gambe dal rig (un poco piu' lunghe del prototipo).
const HIP_W := AvatarRig.HIP_W
const HIP_Y := AvatarRig.HIP_Y
const L1 := AvatarRig.THIGH
const L2 := AvatarRig.SHIN
const FOOT_H := 0.035
const CAD_MIN := 1.7
const CAD_K := 0.38
const CAD_MAX := 3.9
const DUTY_MAX := 0.60
const DUTY_K := 0.058
const DUTY_MIN := 0.30
const ARC_H := 0.085
const SETTLE_DIST := 0.11
const SETTLE_DUR := 0.22
const MOVE_SPEED := 0.45
const DROP_MAX := 0.13
## Colpi (D-034): il piede del passo va oltre l'arrivo del corpo di LEAD, quello
## dietro resta piantato finche' non resta piu' indietro di LEASH, poi segue.
const LEAD := 0.12
const REAR := 0.08
const LEASH := 0.24


class Leg:
	extends RefCounted
	var side := 1.0
	var planted := false
	var foot := Vector3.ZERO
	## {kind, u, dur, from, to}
	var swing := {}
	var tuck := 0.0
	var ankle := Vector3.ZERO
	var knee := Vector3.ZERO


## Gamba sinistra (side -1) e destra (+1).
var legs: Array[Leg] = []
var phase := 0.0
var move_k := 0.0
var jump_lift := 0.0
var crouch := 0.0
var base_off := 0.0
var drop := 0.0
var sway := 0.0
var lean := 0.0
var acc := 0.0
var idle_t := 0.0
var _pv := Vector2.ZERO
var _was_ground := true
## Uscite per il corpo: quota del bacino (bob, caduta, schiacciamento),
## inclinazione in avanti e ondeggio laterale.
var body_y := 0.0
## In un colpo (D-034): niente ciclo del passo ne' assestamento; i piedi si
## muovono solo col passo d'attacco (`step_to`) o quando il corpo li trascina.
var hold := false


func _init() -> void:
	for s in [-1.0, 1.0]:
		var l := Leg.new()
		l.side = s
		legs.append(l)


## Ritorna al piano (teletrasporto, respawn): i piedi si ripiantano.
func reset() -> void:
	for l in legs:
		l.planted = false
		l.swing = {}


## Passo d'attacco: il piede `side` va a `to` (mondo, la quota la prende il
## terreno) in `dur` secondi, con un arco basso.
func step_to(side: float, to: Vector3, dur: float) -> void:
	var l := legs[0] if side < 0.0 else legs[1]
	var from := l.foot
	if not l.planted and l.swing.is_empty():
		return
	if Vector2(to.x - from.x, to.z - from.z).length() < 0.03:
		return
	l.swing = {"kind": "attack", "u": 0.0, "dur": maxf(0.06, dur), "from": from, "to": to, "goal": to}
	l.planted = false


## Un passo. `xf` = trasformazione globale del rig (origine ai piedi, ruotata col
## personaggio); `vel` = velocita' del corpo; `ground` = func(x, z) -> quota.
func update(dt: float, xf: Transform3D, vel: Vector3, on_ground: bool, max_speed: float, ground: Callable) -> void:
	if dt <= 0.0:
		return
	var inv := xf.affine_inverse()
	var P := xf.origin
	var speed := Vector2(vel.x, vel.z).length()
	var moving := on_ground and speed > MOVE_SPEED and not hold
	var move_target := minf(1.0, speed / maxf(0.001, max_speed)) if on_ground else 0.0
	move_k += (move_target - move_k) * (1.0 - exp(-dt * 10.0))
	jump_lift += ((0.0 if on_ground else 1.0) - jump_lift) * (1.0 - exp(-dt * 12.0))
	idle_t += dt
	# Accelerazione lungo la direzione di marcia (inclinazione del busto).
	var fw := -xf.basis.z
	fw = Vector3(fw.x, 0, fw.z).normalized()
	var a2 := (Vector2(vel.x, vel.z) - _pv) / maxf(1e-3, dt)
	_pv = Vector2(vel.x, vel.z)
	var acc_f := clampf(a2.x * fw.x + a2.y * fw.z, -40.0, 40.0)
	acc += (acc_f - acc) * (1.0 - exp(-dt * 6.0))
	# Ciclo del passo.
	var cad := minf(CAD_MAX, CAD_MIN + CAD_K * speed)
	var duty := maxf(DUTY_MIN, DUTY_MAX - DUTY_K * speed)
	var swing_dur := (1.0 - duty) / cad
	var leg_swinging := false
	for l in legs:
		if not l.swing.is_empty() and l.swing["kind"] == "gait":
			leg_swinging = true
	if moving or leg_swinging:
		phase = fmod(phase + dt * (cad if moving else CAD_MIN), 1.0)
	var dir := Vector3(vel.x, 0, vel.z) / speed if speed > 0.05 else fw
	var stance_travel := speed * duty / cad
	var right := xf.basis.x
	right = Vector3(right.x, 0, right.z).normalized()
	var landed := on_ground and not _was_ground
	_was_ground = on_ground
	if landed:
		crouch = 0.07
	crouch *= exp(-dt * 7.0)
	var gc: float = ground.call(P.x, P.z)
	var base_t := clampf(gc - P.y + 0.01, -0.30, 0.0) if on_ground else 0.0
	base_off += (base_t - base_off) * (1.0 - exp(-dt * 14.0))
	for l in legs:
		var hip_l := Vector3(l.side * HIP_W, HIP_Y + body_y, 0)
		var home := P + right * (l.side * HIP_W)
		var ph := fmod(phase + (0.5 if l.side > 0 else 0.0), 1.0)
		var in_swing_window := ph >= duty
		if not on_ground:
			# In aria: piedi raccolti sotto l'anca.
			l.planted = false
			l.swing = {}
			l.tuck = minf(1.0, l.tuck + dt * 7.0)
			var tgt := Vector3(hip_l.x + l.side * 0.01, hip_l.y - L1 - L2 * 0.55 + (0.06 if vel.y > 0.0 else 0.0), -0.10)
			l.ankle = l.ankle.lerp(tgt, 1.0 - exp(-dt * 14.0))
			continue
		l.tuck = 0.0
		if not l.planted and l.swing.is_empty():
			l.foot = Vector3(home.x, ground.call(home.x, home.z), home.z)
			l.planted = true
		if moving and in_swing_window and l.planted and l.swing.is_empty():
			l.swing = {"kind": "gait", "u": 0.0, "dur": swing_dur, "from": l.foot, "to": l.foot}
			l.planted = false
		if not moving and l.planted and l.swing.is_empty():
			var other := legs[1] if l.side < 0 else legs[0]
			var off := Vector2(l.foot.x - home.x, l.foot.z - home.z).length()
			if hold:
				# Il corpo scatta avanti: il piede rimasto indietro lo segue
				# subito, anche a passo in corso (passo saltellato dell'affondo).
				if off > LEASH:
					l.swing = {"kind": "follow", "u": 0.0, "dur": SETTLE_DUR * 0.8, "from": l.foot, "to": l.foot}
					l.planted = false
			elif off > SETTLE_DIST and other.planted:
				l.swing = {"kind": "settle", "u": 0.0, "dur": SETTLE_DUR, "from": l.foot, "to": l.foot}
				l.planted = false
		if not l.swing.is_empty():
			var sw := l.swing
			sw["u"] = minf(1.0, float(sw["u"]) + dt / float(sw["dur"]))
			var u: float = sw["u"]
			var rem := (1.0 - u) * float(sw["dur"])
			var t := home
			if sw["kind"] == "gait":
				t = home + Vector3(vel.x, 0, vel.z) * rem + dir * stance_travel * 0.5
			elif sw["kind"] == "attack":
				t = sw["goal"]
			elif sw["kind"] == "follow":
				t = home + Vector3(vel.x, 0, vel.z) * rem - fw * REAR
			var to := Vector3(t.x, ground.call(t.x, t.z), t.z)
			sw["to"] = to
			var e := u * u * (3.0 - 2.0 * u)
			var arc := 9.481481 * pow(1.0 - u, 3.0) * u
			var h := ARC_H * (0.7 + 0.3 * move_target) if sw["kind"] == "gait" else (0.06 if sw["kind"] == "attack" else 0.05)
			var from: Vector3 = sw["from"]
			l.foot = from.lerp(to, e) + Vector3(0, arc * h, 0)
			if u >= 1.0:
				l.foot = to
				l.planted = true
				l.swing = {}
		l.ankle = inv * l.foot + Vector3(0, FOOT_H, 0)
	# Bacino: scende quanto serve perche' la gamba piantata piu' tesa arrivi.
	var dr := 0.0
	if on_ground:
		for l in legs:
			if l.planted:
				dr = maxf(dr, minf(DROP_MAX, (P.y + base_off - l.foot.y) - 0.015))
				if hold:
					# Piedi larghi nel colpo: il bacino scende quanto serve
					# perche' la gamba tesa arrivi a terra (affondo).
					var hp := P + right * (l.side * HIP_W)
					var hd := Vector2(l.foot.x - hp.x, l.foot.z - hp.z).length()
					var reach := (L1 + L2) * 0.97
					var need := sqrt(maxf(0.0, reach * reach - hd * hd)) + FOOT_H
					dr = maxf(dr, minf(DROP_MAX, HIP_Y - need))
	drop += (dr - drop) * (1.0 - exp(-dt * (25.0 if dr > drop else 9.0)))
	# Bob a doppia frequenza, ondeggio, inclinazione.
	var gait_s := sin(phase * TAU)
	var gait_c := cos(phase * TAU * 2.0)
	var bob_walk := (0.012 + 0.010 * move_target) * maxf(0.0, -gait_c) * move_k
	var idle_bob := sin(idle_t * 1.8) * 0.006 * (1.0 - move_k) * (1.0 - jump_lift)
	var air_bob := maxf(0.0, sin(minf(PI, maxf(0.0, 1.2 + vel.y * 0.18)))) * 0.012 if not on_ground else 0.0
	var sway_t := gait_s * 0.022 * move_k if moving else 0.0
	sway += (sway_t - sway) * (1.0 - exp(-dt * 12.0))
	var lean_t := clampf(acc * 0.006 + 0.045 * move_target, -0.14, 0.14)
	lean += (lean_t - lean) * (1.0 - exp(-dt * 7.0))
	body_y = idle_bob + bob_walk + air_bob - drop - crouch + base_off


## Posizioni di ginocchio e caviglia per una gamba, dall'anca (spazio del rig).
static func solve(hip: Vector3, ankle: Vector3, side: float) -> Array[Vector3]:
	var d := ankle - hip
	var dist := d.length()
	var max_d := (L1 + L2) * 0.995
	if dist > max_d:
		d *= max_d / dist
		dist = max_d
	if dist < 0.02:
		d = Vector3(0, -0.02, 0)
		dist = 0.02
	var u := d / dist
	var a := (L1 * L1 - L2 * L2 + dist * dist) / (2.0 * dist)
	var hh := sqrt(maxf(0.0, L1 * L1 - a * a))
	# Il ginocchio piega in avanti (-Z) e un filo verso l'esterno.
	var b := Vector3(side * 0.18, 0, -1.0)
	b -= u * b.dot(u)
	b = b.normalized() if b.length() > 1e-5 else Vector3.FORWARD
	var knee := hip + u * a + b * hh
	return [knee, hip + d]


## Posa le gambe del rig (dopo `apply_pose`): `w` = peso dell'IK sulla posa
## dell'animatore (0 durante la capriola e il nuoto).
func apply(rig: AvatarRig, w: float) -> void:
	if w <= 0.001:
		return
	var hips_x := rig.rig_xf(rig.bones[&"hips"])
	for l in legs:
		var side_name := "r" if l.side > 0 else "l"
		var leg: Node3D = rig.bones[StringName("leg_" + side_name)]
		var shin: Node3D = rig.bones[StringName("shin_" + side_name)]
		var hip := (hips_x * Transform3D(Basis.IDENTITY, rig.rest[StringName("leg_" + side_name)])).origin
		var ks := solve(hip, l.ankle, l.side)
		l.knee = ks[0]
		var leg_x := Transform3D(AvatarRig._aim(ks[0] - hip, Vector3.BACK), hip)
		var t_leg := hips_x.affine_inverse() * leg_x
		var shin_x := Transform3D(AvatarRig._aim(ks[1] - ks[0], Vector3.BACK), ks[0])
		var t_shin := leg_x.affine_inverse() * shin_x
		if w >= 0.999:
			leg.transform = t_leg
			shin.transform = t_shin
		else:
			leg.transform = leg.transform.interpolate_with(t_leg, w)
			shin.transform = shin.transform.interpolate_with(t_shin, w)
