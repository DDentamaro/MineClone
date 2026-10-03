class_name CombatController
extends RefCounted
## Combattimento corpo a corpo del giocatore (M4, disegno nuovo — D-022).
##
## - Input bufferizzati 0,3 s: colpo, forte (tenuto = carica), schivata.
## - Catene per arma: ogni attacco indica il seguito leggero e quello forte;
##   il seguito parte nel rientro (dopo `chain_at`), senza aspettare la fine.
## - Mira assistita leggera (D-033): all'avvio del colpo, se un bersaglio sta
##   entro 35° dalla direzione voluta e a portata di affondo, l'eroe corregge la
##   direzione di al massimo 20° e l'affondo lo porta alla distanza vera
##   dell'arma (`strike_dist`), mai oltre l'affondo del colpo.
## - Catene fluide: il colpo premuto durante un attacco resta in coda fino al
##   punto di seguito (non scade), e i colpi di catena spingono poco il
##   bersaglio perche' resti a portata; spinge forte solo il colpo finale.
## - Schivata a capriola con invulnerabilita' iniziale; annulla il rientro di
##   un colpo (e la prima meta' della carica); un colpo nell'ultima parte della
##   capriola diventa l'attacco in corsa dell'arma.
## - In aria il colpo diventa una picchiata con urto ad area all'atterraggio.
## - Colpi (D-028): con `hitboxes` forniti dal rig il danno nasce dal contatto
##   hitbox/hurtbox come nel prototipo (sfere lungo la lama o sui pugni contro
##   la capsula del bersaglio, test spazzato tra un passo e l'altro), solo nella
##   fase attiva del colpo e nel primo tratto del seguito, solo con la lama in
##   movimento; gli urti al suolo (area) restano ad area. Senza rig (test) i
##   colpi usano le forme astratte: arco, striscia, area. Un colpo per bersaglio
##   per attacco (salvo `rehit`), hitstop, scossa della camera.
##
## Nessun nodo: `step` e' deterministico e gira nei test headless.

enum State { IDLE, ATTACK, DODGE }

const BUFFER := 0.3
const DODGE_TIME := 0.4
const DODGE_SPEED := 12.0
const DODGE_IFRAMES := Vector2(0.02, 0.28)
const DODGE_COOLDOWN := 0.12
const DASH_WINDOW := 0.5
## Aiuto alla mira: oltre portata + affondo quanto si guarda, cono e correzione massima.
const LOCK_EXTRA := 0.6
const LOCK_CONE := 0.61
const AIM_ASSIST := 0.35
const PLUNGE_FALL := 22.0

var weapon: WeaponDefinition
var state: State = State.IDLE
var attack: AttackDefinition
## Tempo trascorso nell'attacco o nella schivata in corso.
var t := 0.0
## Direzione del giocatore (rotazione Y; avanti = (-sin, -cos) in XZ).
var facing := 0.0
var heavy_held := false
var charging := false
var charge := 0.0
var buffer: StringName = &""
var buffer_t := 0.0
var dodge_dir := Vector2.ZERO
var cooldown := 0.0
var hitstop := 0.0
## Attacchi iniziati (l'avatar ci riconosce un colpo nuovo, anche in catena).
var starts := 0
var lock_target: CombatTarget
## Bersaglio agganciato col Lock (D-035): ogni colpo parte verso di lui (anche
## fuori dal cono della mira assistita) e lo segue durante la carica.
var forced: CombatTarget
## Prima persona (D-037): il colpo va dove si guarda, anche camminando di lato.
var aim_view := false
## Oltre questa distanza il Lock orienta il colpo ma lo scatto resta il suo.
const FORCED_RANGE := 12.0
## Guida del motore: velocita' imposta (scatti, capriole) o scala dello stick.
var drive_on := false
var drive := Vector2.ZERO
var move_scale := 1.0
## Colpi a segno nella catena corrente (si azzera dopo 1,6 s senza colpi).
var combo := 0
var combo_t := 0.0
var events: Array[Dictionary] = []
var clock := 0.0
## Mondo e tabella dei blocchi opachi: i colpi non passano attraverso i muri.
var world: WorldData
var opaque := PackedByteArray()

## Statistiche dell'equipaggiamento (M5): moltiplicatore del danno e critico (×1,5).
var damage_mult := 1.0
var crit_chance := 0.0
## Slancio accumulato nella catena (D-047, armi con `momentum_step`).
var momentum := 0
var _via_chain := &""
var rng := RandomNumberGenerator.new()
## Cambio d'arma in corso (secondi): gli attacchi aspettano.
var draw_t := 0.0
var _hit_log := {}
var _lunge_speed := 0.0
var _prev_u := 0.0
var _impact_done := false
var _attack_facing := 0.0
var _last_dodge_end := -99.0
## Hitbox dell'arma in coordinate globali ([centro, raggio]), aggiornate dal
## gioco prima di ogni passo; vuoto = forme astratte.
var hitboxes: Array = []
var _prev_boxes: Array = []
## Seguito in cui la lama ferisce ancora (frazione del rientro).
const FOLLOW := 0.3
## Velocita' minima della sfera per ferire (la mano in guardia, l'elsa ferma no).
const MIN_SPEED := 1.0


func _init(w: WeaponDefinition = null) -> void:
	weapon = w if w != null else WeaponLibrary.by_id(&"sword")


static func forward(f: float) -> Vector2:
	return Vector2(-sin(f), -cos(f))


static func heading(v: Vector2) -> float:
	return atan2(-v.x, -v.y)


func press_light() -> void:
	_buffer(&"light")


func press_heavy() -> void:
	heavy_held = true
	_buffer(&"heavy")


func release_heavy() -> void:
	heavy_held = false


func press_dodge() -> void:
	_buffer(&"dodge")


func _buffer(a: StringName) -> void:
	buffer = a
	buffer_t = BUFFER


func set_weapon(w: WeaponDefinition) -> void:
	weapon = w
	cancel()


func cancel() -> void:
	state = State.IDLE
	attack = null
	charging = false
	drive_on = false
	move_scale = 1.0
	buffer = &""


func is_busy() -> bool:
	return state != State.IDLE


func invulnerable() -> bool:
	return state == State.DODGE and t >= DODGE_IFRAMES.x and t <= DODGE_IFRAMES.y


## Fase dell'attacco: 0 carica, 1 colpo, 2 rientro; `u` 0..1 nella fase.
func phase() -> int:
	if attack == null:
		return -1
	if t < attack.windup:
		return 0
	if t < attack.windup + attack.active:
		return 1
	return 2


func phase_u() -> float:
	if attack == null:
		return 0.0
	match phase():
		0:
			return t / maxf(attack.windup, 1e-4)
		1:
			return (t - attack.windup) / maxf(attack.active, 1e-4)
	return clampf((t - attack.windup - attack.active) / maxf(attack.recovery, 1e-4), 0.0, 1.0)


func charge_fraction() -> float:
	if attack == null or attack.charge_max <= 0.0:
		return 0.0
	return clampf(charge / attack.charge_max, 0.0, 1.0)


func dodge_u() -> float:
	return clampf(t / DODGE_TIME, 0.0, 1.0) if state == State.DODGE else -1.0


## Un passo di simulazione. `stick` e' la direzione voluta nel piano XZ.
func step(dt: float, motor: PlayerMotor, targets: Array, stick: Vector2) -> void:
	if hitstop > 0.0:
		hitstop = maxf(0.0, hitstop - dt)
		return
	clock += dt
	# In un attacco il colpo premuto aspetta il punto di seguito senza scadere.
	if not (state == State.ATTACK and (buffer == &"light" or buffer == &"heavy")):
		buffer_t -= dt
	if buffer_t <= 0.0:
		buffer = &""
	cooldown = maxf(0.0, cooldown - dt)
	combo_t += dt
	if combo_t > 1.6:
		combo = 0
	if motor.swimming:
		cancel()
		return
	match state:
		State.IDLE:
			drive_on = false
			move_scale = 1.0
			if draw_t > 0.0:
				# Arma in arrivo: l'input resta in attesa e parte appena e' in mano.
				draw_t -= dt
				buffer_t = maxf(buffer_t, 0.05) if buffer != &"" else buffer_t
				return
			_take_buffer(motor, targets, stick)
		State.ATTACK:
			_step_attack(dt, motor, targets, stick)
		State.DODGE:
			_step_dodge(dt, motor, targets, stick)


func _take_buffer(motor: PlayerMotor, targets: Array, stick: Vector2) -> void:
	match buffer:
		&"dodge":
			if motor.on_ground and cooldown <= 0.0:
				_start_dodge(stick)
		&"light":
			if not motor.on_ground:
				_start_attack(weapon.air_attack, motor, targets, stick)
			elif clock - _last_dodge_end < 0.12:
				_start_attack(weapon.dash_attack, motor, targets, stick)
			else:
				_start_attack(weapon.light_start, motor, targets, stick)
		&"heavy":
			if motor.on_ground:
				_start_attack(weapon.heavy_start, motor, targets, stick)
			else:
				_start_attack(weapon.air_attack, motor, targets, stick)


func _start_attack(id: StringName, motor: PlayerMotor, targets: Array, stick: Vector2) -> void:
	var a := weapon.attack(id)
	buffer = &""
	if a == null:
		return
	# Slancio: sale coi leggeri concatenati, il forte dalla catena lo usa, ogni
	# altro inizio (catena nuova, corsa, aria) lo azzera.
	if weapon.momentum_step > 0.0:
		if _via_chain == &"light":
			momentum = mini(weapon.momentum_max, momentum + 1)
		elif _via_chain != &"heavy":
			momentum = 0
	_via_chain = &""
	attack = a
	state = State.ATTACK
	t = 0.0
	_prev_u = 0.0
	_prev_boxes = hitboxes.duplicate()
	_impact_done = false
	_hit_log.clear()
	charging = a.charge_max > 0.0 and heavy_held
	charge = 0.0
	# Mira assistita leggera: la direzione voluta (stick o sguardo) si corregge
	# di al massimo 20° verso un bersaglio vicino al suo asse.
	var want := facing if stick.length() < 0.2 or aim_view else heading(stick)
	var hard := _forced_ok(motor)
	lock_target = forced if hard else _pick_target(motor.position, want, targets, a)
	var dist_goal := a.lunge
	if lock_target != null:
		var v := Vector2(lock_target.position.x - motor.position.x, lock_target.position.z - motor.position.z)
		if hard:
			want = heading(v) if v.length() > 0.05 else want
		else:
			want += clampf(wrapf(heading(v) - want, -PI, PI), -AIM_ASSIST, AIM_ASSIST)
		var stop := a.radial_ahead if a.shape == AttackDefinition.Shape.RADIAL else (a.strike if a.strike > 0.0 else weapon.strike_dist)
		dist_goal = clampf(v.length() - stop, 0.0, a.lunge * 1.25)
	facing = want
	_attack_facing = want
	var lt := a.windup * 0.6 + a.active * 0.35
	_lunge_speed = dist_goal / maxf(lt, 1e-3)
	if a.plunge:
		motor.velocity.y = maxf(motor.velocity.y, 3.0)
	starts += 1
	events.append({"type": "start", "attack": a})


## Metri che lo scatto del colpo in corso fa percorrere (passo delle gambe).
func lunge_dist() -> float:
	if attack == null:
		return 0.0
	return _lunge_speed * (attack.windup * 0.6 + attack.active * 0.35)


func _forced_ok(motor: PlayerMotor) -> bool:
	if forced == null or not forced.alive:
		return false
	var v := Vector2(forced.position.x - motor.position.x, forced.position.z - motor.position.z)
	return v.length() <= FORCED_RANGE and absf(forced.position.y - motor.position.y) < 3.0


func _pick_target(from: Vector3, want: float, targets: Array, a: AttackDefinition) -> CombatTarget:
	var best: CombatTarget = null
	var best_score := INF
	var max_range := (a.radial_ahead + a.radial * 0.5 if a.shape == AttackDefinition.Shape.RADIAL else weapon.strike_dist) + LOCK_EXTRA + a.lunge * 1.25
	for o in targets:
		var tg := o as CombatTarget
		if tg == null or not tg.alive:
			continue
		var v := Vector2(tg.position.x - from.x, tg.position.z - from.z)
		var dist := v.length()
		if dist > max_range or absf(tg.position.y - from.y) > 2.5:
			continue
		var ang := absf(wrapf(heading(v) - want, -PI, PI)) if dist > 0.05 else 0.0
		if ang > LOCK_CONE:
			continue
		var score := dist + ang * 2.2
		if score < best_score:
			best_score = score
			best = tg
	return best


func _step_attack(dt: float, motor: PlayerMotor, targets: Array, stick: Vector2) -> void:
	var a := attack
	# Carica: la fase di preparazione resta sospesa finche' il tasto e' tenuto.
	if charging:
		if heavy_held and charge < a.charge_max:
			charge += dt
			if t + dt >= a.windup * 0.98:
				t = a.windup * 0.98
				drive_on = false
				move_scale = 0.0
				if buffer == &"dodge" and charge < a.charge_max * 0.5:
					_start_dodge(stick)
				return
		else:
			charging = false
	var before := t
	t += dt
	# Lock: durante la carica il colpo continua a puntare il bersaglio che si
	# sposta (i giri e le picchiate no).
	if lock_target != null and lock_target == forced and t < a.windup and a.spin == 0.0 and not a.plunge and lock_target.alive:
		var lv := Vector2(lock_target.position.x - motor.position.x, lock_target.position.z - motor.position.z)
		if lv.length() > 0.3:
			facing = heading(lv)
			_attack_facing = facing
	var in_dodge_cancel := buffer == &"dodge" and (phase() == 2 or before < a.windup * 0.5)
	if in_dodge_cancel and motor.on_ground and cooldown <= 0.0:
		_start_dodge(stick)
		return
	# Picchiata: il colpo resta attivo fino all'atterraggio.
	if a.plunge:
		var mid := a.windup + a.active * 0.5
		if t < a.windup:
			motor.velocity.y = maxf(motor.velocity.y, 1.2)
		elif not _impact_done:
			if motor.on_ground:
				_impact_done = true
				t = a.windup + a.active
				_radial_hit(motor.position, targets)
				events.append({"type": "impact", "attack": a, "position": motor.position + Vector3(forward(facing).x, 0, forward(facing).y) * a.radial_ahead})
			else:
				t = minf(t, mid)
				motor.velocity.y = -PLUNGE_FALL
	# Guida del motore.
	# Lo scatto finisce presto nel colpo: la lama spazza a distanza giusta.
	var ls := a.windup * 0.4
	var le := a.windup + a.active
	if a.backstep > 0.0 and t < ls and not a.plunge:
		# Passo indietro prima del colpo (lancia).
		drive_on = true
		drive = -forward(facing) * (a.backstep / maxf(ls, 1e-3))
	elif t >= ls and t <= a.windup + a.active * 0.35 and _lunge_speed > 0.0 and not a.plunge:
		drive_on = true
		drive = forward(facing) * _lunge_speed
	elif a.plunge and t >= a.windup and not _impact_done:
		drive_on = true
		drive = forward(facing) * 2.0
	else:
		drive_on = false
		move_scale = a.move_scale if t < le else lerpf(a.move_scale, 0.7, clampf((t - le) / maxf(a.recovery, 1e-3), 0.0, 1.0))
	# Colpi.
	var ph := phase()
	var blade := not hitboxes.is_empty() and a.shape != AttackDefinition.Shape.RADIAL and not a.plunge and a.cast == ""
	if a.cast != "":
		# D-055: magia, il proiettile lo crea il gioco (`MagicSystem`).
		if ph >= 1 and not _impact_done:
			_impact_done = true
			events.append({"type": "cast", "attack": a, "charge": charge_fraction(), "target": lock_target, "facing": _attack_facing})
	elif blade:
		if ph == 1 or (ph == 2 and phase_u() <= FOLLOW):
			_blade_hits(motor.position, targets, dt)
		# Affondo perforante: oltre la lama, la striscia prende tutta la fila.
		if a.pierce > 0.0 and a.shape == AttackDefinition.Shape.THRUST and ph == 1:
			_thrust_hits(motor.position, targets, phase_u())
		_prev_boxes = hitboxes.duplicate()
	elif a.shape == AttackDefinition.Shape.RADIAL and not a.plunge and not _impact_done and _radial_now(a, ph, motor):
		# D-053: l'onda (danno, spinta, arresto, scossa, polvere) parte quando la
		# testa dell'arma tocca davvero terra, non all'inizio della fase attiva.
		_impact_done = true
		_radial_hit(motor.position, targets)
		var f := forward(facing)
		events.append({"type": "impact", "attack": a, "position": motor.position + Vector3(f.x, 0, f.y) * a.radial_ahead})
	elif ph == 1 and not a.plunge and a.shape != AttackDefinition.Shape.RADIAL:
		var u := phase_u()
		match a.shape:
			AttackDefinition.Shape.ARC:
				_arc_hits(motor.position, targets, _prev_u, u)
			AttackDefinition.Shape.THRUST:
				_thrust_hits(motor.position, targets, u)
		_prev_u = u
	elif ph == 2 and before < a.windup + a.active and not a.plunge and not blade:
		# Chiusura del colpo: ultimo tratto dell'arco anche con passi lunghi.
		if a.shape == AttackDefinition.Shape.ARC:
			_arc_hits(motor.position, targets, _prev_u, 1.0)
		elif a.shape == AttackDefinition.Shape.THRUST:
			_thrust_hits(motor.position, targets, 1.0)
		_prev_u = 1.0
	# Catena.
	if ph == 2 and phase_u() >= a.chain_at and buffer != &"":
		var next: StringName = &""
		if buffer == &"light":
			next = a.next_light
		elif buffer == &"heavy":
			next = a.next_heavy if a.next_heavy != &"" else weapon.heavy_start
		if next != &"" and motor.on_ground:
			_via_chain = buffer
			_start_attack(next, motor, targets, stick)
			return
	if t >= a.total():
		state = State.IDLE
		attack = null
		drive_on = false
		move_scale = 1.0
		if buffer != &"":
			_take_buffer(motor, targets, stick)


func _start_dodge(stick: Vector2) -> void:
	var dir := stick.normalized() if stick.length() > 0.2 else forward(facing)
	dodge_dir = dir
	facing = heading(dir)
	state = State.DODGE
	attack = null
	charging = false
	t = 0.0
	buffer = &""
	events.append({"type": "dodge"})


func _step_dodge(dt: float, motor: PlayerMotor, targets: Array, stick: Vector2) -> void:
	t += dt
	var u := clampf(t / DODGE_TIME, 0.0, 1.0)
	drive_on = true
	drive = dodge_dir * (DODGE_SPEED * pow(1.0 - u, 1.6) + 1.8)
	if buffer == &"light" and u >= DASH_WINDOW:
		_last_dodge_end = clock
		state = State.IDLE
		_start_attack(weapon.dash_attack, motor, targets, stick)
		return
	if u >= 1.0:
		state = State.IDLE
		drive_on = false
		cooldown = DODGE_COOLDOWN
		_last_dodge_end = clock
		if buffer != &"" and buffer != &"dodge":
			_take_buffer(motor, targets, stick)


## Angolo dell'arco (gradi, relativo) a una frazione del colpo.
func arc_angle(u: float) -> float:
	var e := 1.0 - pow(1.0 - clampf(u, 0.0, 1.0), 3.0)
	return lerpf(attack.arc_from, attack.arc_to, e)


func _can_hit(tg: CombatTarget) -> bool:
	if not tg.alive:
		return false
	if not _hit_log.has(tg):
		return true
	return attack.rehit > 0.0 and t - float(_hit_log[tg]) >= attack.rehit


func _in_height(from: Vector3, tg: CombatTarget) -> bool:
	var lo := from.y + attack.y_min
	var hi := from.y + attack.y_max
	return tg.position.y < hi and tg.position.y + tg.height > lo


func _arc_hits(from: Vector3, targets: Array, u0: float, u1: float) -> void:
	var a0 := arc_angle(u0)
	var a1 := arc_angle(u1)
	var lo := minf(a0, a1)
	var hi := maxf(a0, a1)
	var sweep_sign := signf(a1 - a0)
	for o in targets:
		var tg := o as CombatTarget
		if tg == null or not _can_hit(tg) or not _in_height(from, tg):
			continue
		var v := Vector2(tg.position.x - from.x, tg.position.z - from.z)
		var r := v.length()
		if r < attack.reach_min - tg.radius or r > attack.reach + tg.radius:
			continue
		var rel := rad_to_deg(wrapf(heading(v) - _attack_facing, -PI, PI)) if r > 0.05 else 0.0
		var half := rad_to_deg(atan2(tg.radius, maxf(r, 0.1)))
		var inside := false
		for k in [-720.0, -360.0, 0.0, 360.0, 720.0]:
			var x: float = rel + k
			if x >= lo - half and x <= hi + half:
				inside = true
				break
		if not inside:
			continue
		var radial := v.normalized() if r > 0.05 else forward(_attack_facing)
		# Tangente nel verso della spazzata (angolo positivo = verso sinistra).
		var tangent := forward(heading(radial) + sweep_sign * PI * 0.5)
		_hit(tg, (radial + tangent * 0.55).normalized(), from)


func _thrust_hits(from: Vector3, targets: Array, u: float) -> void:
	var e := 1.0 - pow(1.0 - clampf(u, 0.0, 1.0), 3.0)
	var extent := lerpf(attack.reach_min, attack.reach + attack.pierce, e)
	var f := forward(_attack_facing)
	var left := forward(_attack_facing + PI * 0.5)
	for o in targets:
		var tg := o as CombatTarget
		if tg == null or not _can_hit(tg) or not _in_height(from, tg):
			continue
		var v := Vector2(tg.position.x - from.x, tg.position.z - from.z)
		var along := v.dot(f)
		var side := absf(v.dot(left))
		if along < -tg.radius or along > extent + tg.radius or side > attack.width + tg.radius:
			continue
		_hit(tg, f, from)


## Altezza (m sopra i piedi) sotto cui la testa dell'arma "tocca terra".
const GROUND_HIT := 0.32
## Se la testa non scende fin li' (pendio, posa), l'onda parte comunque a
## questo punto del rientro.
const GROUND_LATE := 0.5
## ...e almeno cosi' avanti (m) rispetto ai piedi.
const GROUND_AHEAD := 0.35


## Momento dell'onda di un colpo a terra: senza hitbox (test, prima persona)
## all'inizio della fase attiva come prima; con le hitbox vere quando la sfera
## piu' bassa dell'arma scende vicino al suolo, al piu' tardi a meta' rientro.
func _radial_now(a: AttackDefinition, ph: int, motor: PlayerMotor) -> bool:
	if ph == 0:
		return false
	if hitboxes.is_empty():
		return ph == 1
	if ph == 2 and phase_u() >= GROUND_LATE:
		return true
	# Solo la testa davanti all'eroe: nella carica alta il martello pende
	# dietro la schiena con la testa in basso, e quello non e' l'impatto.
	var f := forward(_attack_facing)
	var low := INF
	for hb: Array in hitboxes:
		var p: Vector3 = hb[0]
		if (p.x - motor.position.x) * f.x + (p.z - motor.position.z) * f.y > GROUND_AHEAD:
			low = minf(low, p.y - float(hb[1]))
	return low - motor.position.y <= GROUND_HIT


func _radial_hit(from: Vector3, targets: Array) -> void:
	var f := forward(_attack_facing)
	var c := Vector2(from.x, from.z) + f * attack.radial_ahead
	for o in targets:
		var tg := o as CombatTarget
		if tg == null or not _can_hit(tg):
			continue
		if absf(tg.position.y - from.y) > 1.6:
			continue
		var v := Vector2(tg.position.x, tg.position.z) - c
		if v.length() > attack.radial + tg.radius:
			continue
		var dir := v.normalized() if v.length() > 0.2 else f
		_hit(tg, dir, from)


## Capsula verticale del bersaglio (hurtbox): [y0, y1, raggio].
static func hurtbox(tg: CombatTarget) -> Array:
	return [tg.position.y + 0.08, tg.position.y + tg.height * 0.95, tg.radius]


static func sphere_capsule(c: Vector3, r: float, tg: CombatTarget) -> bool:
	var hb := hurtbox(tg)
	var cy := clampf(c.y, hb[0], hb[1])
	var d := Vector3(c.x - tg.position.x, c.y - cy, c.z - tg.position.z)
	return d.length_squared() <= (r + float(hb[2])) * (r + float(hb[2]))


## Contatto spazzato: la sfera nella posizione di ora e in 3 punti intermedi
## dal passo precedente (niente passaggi a vuoto a pochi FPS).
func _blade_hits(from: Vector3, targets: Array, dt: float) -> void:
	var same := _prev_boxes.size() == hitboxes.size()
	for o in targets:
		var tg := o as CombatTarget
		if tg == null or not _can_hit(tg):
			continue
		for i in hitboxes.size():
			var c: Vector3 = hitboxes[i][0]
			var r: float = hitboxes[i][1]
			var p0: Vector3 = _prev_boxes[i][0] if same else c
			if not same or dt <= 0.0 or p0.distance_to(c) / dt < MIN_SPEED:
				continue
			var at := Vector3.INF
			for k in [0.25, 0.5, 0.75, 1.0]:
				var q := p0.lerp(c, k)
				if sphere_capsule(q, r, tg):
					at = q
					break
			if at == Vector3.INF:
				continue
			# Direzione: dal giocatore al bersaglio, piegata nel verso della lama.
			var radial := Vector2(tg.position.x - from.x, tg.position.z - from.z)
			radial = radial.normalized() if radial.length() > 0.05 else forward(_attack_facing)
			var mv := Vector2(c.x - p0.x, c.z - p0.z)
			var dir := (radial + mv.normalized() * 0.55).normalized() if mv.length() > 1e-4 else radial
			_hit(tg, dir, from, at)
			break


## Vero se tra `a` e `b` non c'e' un blocco opaco (raggio voxel).
func clear_path(a: Vector3, b: Vector3) -> bool:
	if world == null or opaque.is_empty():
		return true
	var d := b - a
	var l := d.length()
	if l < 1e-3:
		return true
	var h := VoxelQuery.raycast(world, opaque, a, d / l, l)
	return h == null


func _hit(tg: CombatTarget, dir: Vector2, from: Vector3, at: Vector3 = Vector3.INF) -> void:
	# Niente colpi attraverso le pareti: dal petto (o dal punto d'urto) al bersaglio.
	var eye := from + Vector3(0, 0.9, 0)
	if attack.shape == AttackDefinition.Shape.RADIAL:
		var f := forward(_attack_facing)
		eye = from + Vector3(f.x, 0, f.y) * attack.radial_ahead + Vector3(0, 0.5, 0)
	if not clear_path(eye, tg.position + Vector3(0, tg.height * 0.55, 0)):
		return
	_hit_log[tg] = t
	var cf := charge_fraction()
	var mult := 1.0 + cf * attack.charge_bonus
	var crit := rng.randf() < crit_chance
	var dmg := attack.damage * mult * damage_mult * (1.5 if crit else 1.0) * (1.0 + weapon.momentum_step * momentum)
	var imp := Vector3(dir.x, 0, dir.y) * attack.knockback * (1.0 + cf * 0.5)
	imp.y = attack.launch * (1.0 + cf * 0.3)
	tg.take_hit(imp, dmg)
	hitstop = maxf(hitstop, attack.hitstop * (1.0 + cf * 0.6))
	combo += 1
	combo_t = 0.0
	var p := tg.position + Vector3(0, tg.height * 0.6, 0)
	var back := Vector3(from.x - p.x, 0, from.z - p.z).normalized() * tg.radius
	if at != Vector3.INF:
		# Scintilla dove la lama tocca: sulla superficie della capsula.
		p = Vector3(tg.position.x, clampf(at.y, tg.position.y + 0.1, tg.position.y + tg.height), tg.position.z)
		back = Vector3(at.x - p.x, 0, at.z - p.z).normalized() * tg.radius
	events.append({"type": "hit", "attack": attack, "target": tg, "position": p + back, "dir": Vector3(dir.x, 0, dir.y),
		"damage": dmg, "shake": attack.shake * (1.0 + cf * 0.6) * (1.3 if crit else 1.0), "charge": cf, "crit": crit})
