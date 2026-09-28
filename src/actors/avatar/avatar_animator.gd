class_name AvatarAnimator
extends RefCounted
## Animazione procedurale dell'eroe (M4, disegno nuovo). Ogni frame compone:
## guardia dell'arma + ciclo di corsa legato alla distanza percorsa (niente
## piedi che scivolano) + salto/atterraggio + nuoto/guado + capriola + colpo.
## Il colpo segue esattamente il tempo del `CombatController` (carica ->
## scatto -> rientro, con le pose chiave dell'attacco). Una molla smorzata
## per osso da' inerzia e un leggero rimbalzo dopo i colpi veloci.

const STRIDE := 1.25
const SPRING_W := 32.0
const SPRING_Z := 0.58


class State:
	extends RefCounted
	var speed := 0.0
	var on_ground := true
	var vy := 0.0
	var swimming := false
	var swim_phase := 0.0
	var wade := 0.0
	var land := 0.0
	var turn := 0.0
	var weapon: WeaponDefinition
	var attack: AttackDefinition
	## 0 carica, 1 colpo, 2 rientro; `u` avanzamento 0..1 nella fase.
	var phase := 0
	var u := 0.0
	var charge := -1.0
	## Capriola: avanzamento 0..1, -1 se non in corso.
	var dodge := -1.0
	## Magia (mano sinistra): raccolta 0..1 e rilascio 0..1, -1 se assenti.
	var gather := -1.0
	var release := -1.0
	## Magia pesante (Output >= 120): raccolta e spinta a due mani.
	var two_hands := false
	## Braccio teso della magia (RMNDWN karmaPose): peso 0..1, impegno 0..1,
	## postura (inclinazione, apertura, allargamento), convergenza delle mani
	## e rinculo in corso {upper, lower, spine_y, spine_x, head_y}.
	var cast_w := 0.0
	var cast_c := 0.0
	var stance := Vector3.ZERO
	var converge := 0.0
	var recoil := {}
	## 0 in guardia, 1 rilassato (fuori combattimento).
	var relax := 0.0
	## Cambio d'arma: la destra va dietro la spalla (0..1..0).
	var reach := 0.0
	## Scavo/abbattimento: fase del colpo ripetuto (in cicli), -1 se fermo.
	var mine := -1.0


var stride_phase := 0.0
## Gambe e bob del passo li fa `GaitLegs` (D-028): qui restano braccia, busto e
## la fase del passo arriva da fuori.
var gait := false
var time := 0.0
var pose := {}
var _vel := {}
var _w_run := 0.0
var _w_air := 0.0
var _w_swim := 0.0
var _w_wade := 0.0
var _lean := 0.0
var _roll := 0.0
var _up := 0.0


static func d(x: float, y: float = 0.0, z: float = 0.0) -> Vector3:
	return Vector3(deg_to_rad(x), deg_to_rad(y), deg_to_rad(z))


func update(dt: float, s: State) -> Dictionary:
	time += dt
	var target := target_pose(dt, s)
	if pose.is_empty() or dt <= 0.0:
		pose = target.duplicate()
		for k: StringName in target:
			_vel[k] = Vector3.ZERO
		return pose
	# Molle: gli angoli seguono il bersaglio per la via piu' corta.
	var w := SPRING_W
	var z := SPRING_Z
	# Sottopassi da 1/60 s: la molla resta stabile e in tempo anche a pochi FPS.
	var steps := clampi(ceili(dt * 60.0), 1, 8)
	var h := dt / steps
	for k: StringName in target:
		var tv: Vector3 = target[k]
		var cur: Vector3 = pose.get(k, tv)
		var vel: Vector3 = _vel.get(k, Vector3.ZERO)
		if k != &"body_pos":
			tv = cur + Vector3(wrapf(tv.x - cur.x, -PI, PI), wrapf(tv.y - cur.y, -PI, PI), wrapf(tv.z - cur.z, -PI, PI))
		for i in steps:
			vel += (w * w * (tv - cur) - 2.0 * z * w * vel) * h
			cur += vel * h
		pose[k] = cur
		_vel[k] = vel
	for k: StringName in pose.keys():
		if not target.has(k):
			pose.erase(k)
			_vel.erase(k)
	return pose


func target_pose(dt: float, s: State) -> Dictionary:
	var p := {}
	for b in AvatarRig.BONES:
		p[b] = Vector3.ZERO
	p[&"body_pos"] = Vector3.ZERO
	var k := 1.0 - exp(-dt * 10.0)
	var run := clampf(s.speed / 5.5, 0.0, 1.2)
	_w_run += (run - _w_run) * k
	_w_air += ((0.0 if s.on_ground or s.swimming else 1.0) - _w_air) * (1.0 - exp(-dt * 14.0))
	_w_swim += ((1.0 if s.swimming else 0.0) - _w_swim) * (1.0 - exp(-dt * 6.0))
	_w_wade += (clampf(s.wade * 2.0, 0.0, 1.0) - _w_wade) * k
	_lean += (clampf(s.turn * 0.12, -0.35, 0.35) - _lean) * k
	if not gait:
		stride_phase = fmod(stride_phase + s.speed * dt / STRIDE * TAU, TAU)

	# Guardia dell'arma (parte alta del corpo).
	if s.weapon != null:
		for b: StringName in s.weapon.guard:
			p[b] = s.weapon.guard[b]
		# Fuori combattimento l'arma si abbassa o va sulla spalla.
		if s.relax > 0.0:
			for b: StringName in s.weapon.relaxed:
				p[b] = (p[b] as Vector3).lerp(s.weapon.relaxed[b], s.relax)
			for b: StringName in s.weapon.guard:
				if not s.weapon.relaxed.has(b):
					p[b] = (p[b] as Vector3).lerp(Vector3.ZERO, s.relax)
	# Cambio d'arma: la mano destra va a prenderla dietro la spalla.
	if s.reach > 0.0:
		var rk := _smooth(s.reach)
		p[&"arm_r"] = (p[&"arm_r"] as Vector3).lerp(d(150, -10, 28), rk)
		p[&"fore_r"] = (p[&"fore_r"] as Vector3).lerp(d(115), rk)
		p[&"hand_r"] = (p[&"hand_r"] as Vector3).lerp(d(-40), rk)
		p[&"chest"] += d(0, -12.0 * rk)
		p[&"head"] += d(0, 10.0 * rk)
	# Respiro.
	var br := sin(time * 2.2)
	p[&"chest"] += d(br * 1.6)
	p[&"head"] += d(-br * 1.0)
	p[&"arm_l"] += d(0, 0, -3.0 - br * 1.2)
	p[&"arm_r"] += d(0, 0, 3.0 + br * 1.2)

	# Corsa.
	var r := _w_run * (1.0 - _w_swim)
	var ph := stride_phase
	var sn := sin(ph)
	var cs := cos(ph)
	if not gait:
		p[&"leg_l"] += d(sn * 40.0 * r)
		p[&"leg_r"] += d(-sn * 40.0 * r)
		p[&"shin_l"] += d(-(8.0 + 62.0 * maxf(0.0, cs)) * r)
		p[&"shin_r"] += d(-(8.0 + 62.0 * maxf(0.0, -cs)) * r)
	var free_r := 0.35 if s.weapon != null and s.weapon.kind != WeaponDefinition.Kind.FISTS else 0.6
	p[&"arm_l"] += d(-sn * 34.0 * r * (0.35 if s.weapon != null and s.weapon.two_handed else 1.0), 0, -6.0 * r)
	p[&"fore_l"] += d(24.0 * r)
	p[&"arm_r"] += d(sn * 30.0 * r * free_r)
	p[&"chest"] += d(0, sn * 9.0 * r)
	p[&"hips"] += d(0, -sn * 7.0 * r)
	p[&"body"] += d(-9.0 * r, 0, -rad_to_deg(_lean) * r)
	p[&"head"] += d(5.0 * r)
	if not gait:
		p[&"body_pos"] += Vector3(0, (0.045 * (1.0 - absf(sn)) - 0.03) * r, 0)

	# Aria: gambe raccolte in salita, distese e braccia aperte in caduta.
	var a := _w_air
	if a > 0.001:
		var up := clampf(s.vy / 8.0, -1.0, 1.0)
		_up += (up - _up) * k
		var rise := maxf(0.0, _up)
		var fall := maxf(0.0, -_up)
		p[&"leg_l"] = p[&"leg_l"].lerp(d(42.0 * rise + 12.0 * fall), a)
		p[&"shin_l"] = p[&"shin_l"].lerp(d(-70.0 * rise - 20.0 * fall), a)
		p[&"leg_r"] = p[&"leg_r"].lerp(d(-12.0 * rise - 6.0 * fall), a)
		p[&"shin_r"] = p[&"shin_r"].lerp(d(-40.0 * rise - 12.0 * fall), a)
		p[&"arm_l"] += d(-10.0 * a, 0, -35.0 * fall * a)
		p[&"body"] += d(4.0 * fall * a)
	# Atterraggio: il corpo si schiaccia sulle ginocchia.
	if s.land > 0.0:
		var l := clampf(s.land, 0.0, 1.0)
		p[&"leg_l"] += d(34.0 * l)
		p[&"leg_r"] += d(26.0 * l)
		p[&"shin_l"] += d(-62.0 * l)
		p[&"shin_r"] += d(-56.0 * l)
		p[&"body"] += d(-10.0 * l)
		p[&"body_pos"] += Vector3(0, -0.13 * l, 0)
	# Guado: braccia sollevate sopra l'acqua.
	if _w_wade > 0.01 and _w_swim < 0.5:
		p[&"arm_l"] += d(10.0 * _w_wade, 0, -28.0 * _w_wade)
		p[&"arm_r"] += d(8.0 * _w_wade, 0, 22.0 * _w_wade)

	# Nuoto a crawl: corpo prono, bracciate alternate, battito delle gambe.
	if _w_swim > 0.001:
		var sw := _w_swim
		var sp := s.swim_phase
		var swim := {}
		swim[&"body"] = d(-72.0)
		swim[&"body_pos"] = Vector3(0, 0.5, 0.45)
		swim[&"head"] = d(52.0)
		swim[&"chest"] = d(0, sin(sp) * 14.0)
		swim[&"arm_l"] = d(rad_to_deg(fposmod(sp, TAU)), 0, -18.0)
		swim[&"arm_r"] = d(rad_to_deg(fposmod(sp + PI, TAU)), 0, 18.0)
		swim[&"fore_l"] = d(25.0 + 20.0 * maxf(0.0, sin(sp)))
		swim[&"fore_r"] = d(25.0 + 20.0 * maxf(0.0, -sin(sp)))
		swim[&"leg_l"] = d(sin(sp * 2.0) * 16.0)
		swim[&"leg_r"] = d(-sin(sp * 2.0) * 16.0)
		swim[&"shin_l"] = d(-12.0 - 10.0 * maxf(0.0, sin(sp * 2.0)))
		swim[&"shin_r"] = d(-12.0 - 10.0 * maxf(0.0, -sin(sp * 2.0)))
		swim[&"hand_r"] = d(-90.0)
		for key: StringName in swim:
			p[key] = p[key].lerp(swim[key], sw)

	# Colpo.
	if s.attack != null:
		_apply_attack(p, s)

	# Scavo: colpi ripetuti dall'alto (carica lenta, colpo secco, piccolo rimbalzo).
	if s.mine >= 0.0:
		var mp := fposmod(s.mine, 1.0)
		var mk := _smooth(mp / 0.65) if mp < 0.65 else 1.0 - pow((mp - 0.65) / 0.35, 0.5)
		mk = 1.0 - mk
		p[&"arm_r"] = d(lerpf(55.0, 150.0, mk), -8, 10)
		p[&"fore_r"] = d(lerpf(10.0, 55.0, mk))
		p[&"hand_r"] = d(lerpf(-100.0, -40.0, mk))
		p[&"chest"] += d(lerpf(-22.0, 8.0, mk), -10)
		p[&"spine"] += d(-8.0 * (1.0 - mk))
		p[&"arm_l"] = d(35, 10, -12)
		p[&"fore_l"] = d(60)
		p[&"leg_l"] += d(18)
		p[&"leg_r"] += d(-12)
		p[&"shin_r"] += d(-14)

	# Magia con la mano sinistra: il palmo si carica davanti al viso, poi
	# spinge in avanti a braccio teso; l'arma resta nella destra.
	if s.cast_w > 0.0:
		_apply_cast(p, s)

	# Capriola: giro completo in avanti attorno al centro del corpo, raccolto.
	if s.dodge >= 0.0:
		var u := s.dodge
		var e := u * u * (3.0 - 2.0 * u)
		var tuck := sin(u * PI)
		var ang := -TAU * e
		# Perno all'altezza del bacino raccolto; il corpo si arrotola (schiena e
		# testa piegate) e sale un poco, cosi' da capovolto non entra nel suolo.
		var c := Vector3(0, 0.55, 0)
		var rot := Basis(Vector3.RIGHT, ang)
		p[&"body"] = Vector3(ang, p[&"body"].y, 0)
		p[&"body_pos"] = c - rot * c + Vector3(0, 0.1 * tuck, 0)
		p[&"spine"] = p[&"spine"].lerp(d(-28.0), tuck)
		for key: StringName in [&"leg_l", &"leg_r"]:
			p[key] = p[key].lerp(d(85.0), tuck)
		for key: StringName in [&"shin_l", &"shin_r"]:
			p[key] = p[key].lerp(d(-120.0), tuck)
		p[&"arm_l"] = p[&"arm_l"].lerp(d(70.0, 0, -10.0), tuck)
		p[&"fore_l"] = p[&"fore_l"].lerp(d(95.0), tuck)
		p[&"chest"] = p[&"chest"].lerp(d(-50.0), tuck)
		p[&"head"] = p[&"head"].lerp(d(-40.0), tuck)
	return p


func _apply_attack(p: Dictionary, s: State) -> void:
	var at := s.attack
	var from: Dictionary
	var to: Dictionary
	var t: float
	var u := clampf(s.u, 0.0, 1.0)
	match s.phase:
		0:
			from = {}
			to = at.key_wind
			# Anticipazione: lenta all'inizio, arriva in carica un po' prima.
			t = _smooth(minf(1.0, u * 1.15))
		1:
			from = at.key_wind
			to = at.key_strike
			t = 1.0 - pow(1.0 - u, 3.0)
		_:
			if u < 0.4:
				from = at.key_strike
				to = at.key_follow
				t = _smooth(u / 0.4)
			else:
				from = at.key_follow
				to = {}
				t = _smooth((u - 0.4) / 0.6)
	var keys := {}
	for k: StringName in at.key_wind:
		keys[k] = true
	for k: StringName in at.key_strike:
		keys[k] = true
	for k: StringName in at.key_follow:
		keys[k] = true
	for k: StringName in keys:
		var base: Vector3 = p.get(k, Vector3.ZERO)
		var a: Vector3 = from.get(k, base) if not from.is_empty() else base
		var b: Vector3 = to.get(k, base) if not to.is_empty() else base
		if k == &"body_pos":
			p[k] = a.lerp(b, t)
		else:
			p[k] = a.lerp(b, t)
	# Tremito della carica.
	if s.charge >= 0.0 and s.phase == 0:
		var q := s.charge
		p[&"chest"] += d(sin(time * 61.0) * 2.0 * q, sin(time * 47.0) * 1.5 * q)
		p[&"body_pos"] += Vector3(sin(time * 53.0) * 0.012 * q, -0.04 * q, 0)
	# Giro del corpo.
	if at.spin != 0.0 and s.phase == 1:
		p[&"body"] += Vector3(0, deg_to_rad(at.spin) * _smooth(u), 0)


## Posa di lancio di RMNDWN (karmaPose L32165, D-031) specchiata sulla
## sinistra perche' la destra tiene l'arma (D-024): braccio del tutto teso in
## avanti, poco verso l'esterno, all'altezza della spalla, il glifo davanti al
## palmo. Bersagli (non somme) sul braccio che lancia, somme su busto e testa
## (la corsa continua a muovere il torso). Una spinta di 5 cm della spalla
## nell'ultimo 22% della raccolta, poi il rinculo quando la magia colpisce.
## Mano libera raccolta sotto; a due mani le braccia convergono.
const CAST_ARM := Vector3(90.0, 0.0, 0.0)
## Verso l'esterno (atan .24) e in su (atan .06) rispetto al dritto avanti.
const CAST_OUT := 13.5
const CAST_UP := 3.4


func _apply_cast(p: Dictionary, s: State) -> void:
	var w := s.cast_w
	var c := s.cast_c
	var r := s.recoil
	var lean := rad_to_deg(s.stance.x)
	var open := rad_to_deg(s.stance.y)
	var up_rec := rad_to_deg(float(r.get("upper", 0.0)))
	var fl_rec := rad_to_deg(float(r.get("lower", 0.0)))
	# Braccio sinistro: dritto in avanti, fuori di 13,5°, su di 3,4°.
	var conv := rad_to_deg(s.converge) if s.two_hands else 0.0
	var arm := d(CAST_ARM.x + CAST_UP + lean - 2.9 * c + up_rec, CAST_OUT + open - conv, 0.0)
	p[&"arm_l"] = (p[&"arm_l"] as Vector3).lerp(arm, w)
	p[&"fore_l"] = (p[&"fore_l"] as Vector3).lerp(d(fl_rec), w)
	p[&"hand_l"] = (p[&"hand_l"] as Vector3).lerp(d(-8.0), w)
	if s.two_hands:
		var arm_r := d(CAST_ARM.x + CAST_UP + lean - 2.9 * c + up_rec, -(CAST_OUT + open - conv), 0.0)
		p[&"arm_r"] = (p[&"arm_r"] as Vector3).lerp(arm_r, w)
		p[&"fore_r"] = (p[&"fore_r"] as Vector3).lerp(d(fl_rec), w)
		p[&"hand_r"] = (p[&"hand_r"] as Vector3).lerp(d(-8.0), w)
	else:
		# L'altra mano (con l'arma) resta raccolta: abd +.16 + wide, flex +.38.
		p[&"arm_r"] += d(0, 0, rad_to_deg(0.16 + s.stance.z) * w)
		p[&"fore_r"] += d(rad_to_deg(0.38) * w)
	# Busto e testa: yaw +.13w (+.04c), pitch +.04w −.05c, testa −.05w; specchiati.
	p[&"chest"] += Vector3(0.04 * w - 0.05 * c + float(r.get("spine_x", 0.0)), -(0.13 * w + 0.04 * c + float(r.get("spine_y", 0.0))), 0)
	p[&"head"] += Vector3(0, 0.05 * w - float(r.get("head_y", 0.0)), 0)


static func _smooth(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)
