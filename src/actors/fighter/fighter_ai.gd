class_name FighterAI
extends RefCounted
## Cervello del nemico dell'arena (D-058). Non ha mosse sue: preme gli stessi
## tasti del giocatore sul suo `CombatController` (colpo, forte tenuto, schivata,
## para tenuto), muove lo stesso stick e salta. Cosi' ha tutte le azioni del
## giocatore: catene, colpi forti e caricati, attacco in corsa dopo la
## capriola, attacco in aria dopo il salto, guardia, parata perfetta, magia col
## bastone.
##
## Vede quello che vedrebbe un giocatore: dove sta l'avversario, che colpo sta
## preparando (con un ritardo di reazione), i proiettili in arrivo, il bordo del
## ring. La difficolta' (`level` 0..3) cambia riflessi e scelte.

## [reazione (s), parata perfetta, schivata, guardia, colpi in catena, forte]
const LEVELS := [
	[0.34, 0.10, 0.18, 0.30, 2, 0.30],
	[0.27, 0.20, 0.24, 0.30, 3, 0.40],
	[0.21, 0.32, 0.28, 0.25, 4, 0.45],
	[0.16, 0.45, 0.30, 0.20, 4, 0.50],
]
## Distanza preferita col bastone.
const STAFF_RANGE := 5.5

var level := 0
## Uscite verso il motore: direzione voluta (piano XZ) e salto.
var stick := Vector2.ZERO
var jump := false
## Cosa sta facendo (per le prove e il debug).
var mode := "approach"
var rng := RandomNumberGenerator.new()

var _clock := 0.0
var _mode_t := 0.0
var _seen_starts := 0
var _pressed_starts := -1
var _press_clock := -99.0
var _threat_at := -1.0
var _threat_kind := ""
var _threat_dir := Vector2.ZERO
var _combo_left := 0
var _heavy_hold := 0.0
var _guard_hold := 0.0
var _strafe := 1.0
var _stuck_t := 0.0
var _sidestep_t := 0.0
var _last_pos := Vector3.ZERO
var _dash_t := -1.0
var _leap_t := -1.0
var _seen_shots := {}
var _hold_guard_until_safe := false


func _init(lv: int = 0, seed_value: int = 0) -> void:
	level = clampi(lv, 0, LEVELS.size() - 1)
	rng.seed = seed_value if seed_value != 0 else randi()


func _p(i: int) -> Variant:
	return LEVELS[level][i]


func reset() -> void:
	stick = Vector2.ZERO
	jump = false
	mode = "approach"
	_mode_t = 0.0
	_threat_at = -1.0
	_threat_kind = ""
	_combo_left = 0
	_heavy_hold = 0.0
	_guard_hold = 0.0
	_dash_t = -1.0
	_leap_t = -1.0
	_hold_guard_until_safe = false
	_seen_shots.clear()


## Un passo di decisione. `me`/`foe`: controller e corpo; `shots`: i
## proiettili del rivale; `center`/`half`: il ring (half <= 0: nessun ring).
func think(dt: float, me_c: CombatController, me_m: PlayerMotor, foe: FighterBody, foe_c: CombatController,
		shots: Array, center: Vector3, half: float) -> void:
	_clock += dt
	_mode_t += dt
	jump = false
	_release_holds(dt, me_c)
	if not foe.alive:
		stick = Vector2.ZERO
		me_c.release_guard()
		me_c.release_heavy()
		return
	var v := Vector2(foe.position.x - me_m.position.x, foe.position.z - me_m.position.z)
	var d := v.length()
	var dir := v / d if d > 1e-3 else Vector2(0, -1)
	var w := me_c.weapon
	var staff := w.kind == WeaponDefinition.Kind.STAFF
	var reach := w.strike_dist + 0.35
	_track_stuck(dt, me_m)
	# Stordito: non c'e' niente da fare.
	if me_c.stunned():
		stick = Vector2.ZERO
		return
	# --- Difesa: un colpo nuovo dell'avversario si vede dopo la reazione.
	_watch_attack(me_c, foe_c, d, dir)
	_watch_shots(shots, me_m, dir)
	if _defend(me_c, foe_c, me_m, d, dir):
		_ring_guard(me_m, center, half)
		return
	# --- Attacco.
	if staff:
		_think_staff(me_c, foe_c, d, dir)
	else:
		_think_melee(me_c, foe_c, me_m, d, dir, reach, foe, center, half)
	_ring_guard(me_m, center, half)
	if _sidestep_t > 0.0:
		_sidestep_t -= dt
		stick = (stick + Vector2(-dir.y, dir.x) * _strafe * 1.2).normalized()


func _release_holds(dt: float, me_c: CombatController) -> void:
	if _heavy_hold > 0.0:
		_heavy_hold -= dt
		if _heavy_hold <= 0.0:
			me_c.release_heavy()
	if _guard_hold > 0.0:
		_guard_hold -= dt
		if _guard_hold <= 0.0 and not _hold_guard_until_safe:
			me_c.release_guard()


## Un attacco nuovo del rivale: si sceglie come reagire (dopo il ritardo).
func _watch_attack(me_c: CombatController, foe_c: CombatController, d: float, _dir: Vector2) -> void:
	if foe_c.starts == _seen_starts:
		return
	_seen_starts = foe_c.starts
	var a := foe_c.attack
	if a == null:
		return
	var danger := foe_c.weapon.strike_dist + a.lunge * 1.25 + a.radial + 1.4
	if a.cast != "":
		danger = 30.0
	if d > danger:
		return
	_threat_at = _clock + float(_p(0)) * rng.randf_range(0.8, 1.3)
	var r := rng.randf()
	var parry := float(_p(1))
	var dodge := float(_p(2))
	var guard := float(_p(3))
	if a.cast != "":
		# Contro la magia: schivare di lato o parare (la magia non si para
		# all'ultimo istante).
		_threat_kind = "dodge" if r < 0.55 else ("block" if r < 0.85 else "")
	elif a.shape == AttackDefinition.Shape.RADIAL or a.plunge:
		# Colpi a terra: meglio la capriola, oppure la guardia.
		_threat_kind = "dodge" if r < dodge + parry else ("block" if r < dodge + parry + guard else "")
	elif r < parry:
		_threat_kind = "parry"
	elif r < parry + dodge:
		_threat_kind = "dodge"
	elif r < parry + dodge + guard:
		_threat_kind = "block"
	else:
		_threat_kind = ""
	# Chi sta gia' colpendo da vicino a volte scambia invece di difendersi.
	if me_c.state == CombatController.State.ATTACK and me_c.phase() >= 1 and rng.randf() < 0.5:
		_threat_kind = ""


## Proiettili in arrivo: capriola di lato o guardia.
func _watch_shots(shots: Array, me_m: PlayerMotor, _dir: Vector2) -> void:
	for o in shots:
		var s := o as FireMagic.Shot
		if s == null or s.dead or _seen_shots.has(s):
			continue
		var to_me := me_m.position + Vector3(0, 0.8, 0) - s.p
		var dist := to_me.length()
		if dist > 7.0 or s.v.length() < 0.1 or s.v.normalized().dot(to_me / maxf(dist, 1e-3)) < 0.8:
			continue
		_seen_shots[s] = true
		if _threat_kind != "":
			continue
		_threat_at = _clock + float(_p(0)) * rng.randf_range(0.6, 1.0)
		_threat_kind = "dodge" if rng.randf() < 0.6 else "block"
		_threat_dir = Vector2(s.v.x, s.v.z).normalized()
	if _seen_shots.size() > 32:
		_seen_shots.clear()


## Esegue la difesa scelta quando e' il momento. True = questo passo e' difesa.
func _defend(me_c: CombatController, foe_c: CombatController, me_m: PlayerMotor, d: float, dir: Vector2) -> bool:
	if _hold_guard_until_safe:
		# Guardia tenuta finche' il colpo dell'avversario non e' finito.
		var busy := foe_c.state == CombatController.State.ATTACK and foe_c.phase() <= 1
		stick = dir * 0.0
		if not busy and _clock > _threat_at + 0.15:
			_hold_guard_until_safe = false
			me_c.release_guard()
			return false
		return true
	if _threat_kind == "" or _clock < _threat_at:
		return false
	var kind := _threat_kind
	match kind:
		"parry":
			# Si preme Para un attimo prima che la lama arrivi.
			var a := foe_c.attack
			if foe_c.state != CombatController.State.ATTACK or a == null:
				_threat_kind = ""
				return false
			var left := a.windup - foe_c.t
			if foe_c.phase() == 0 and (foe_c.charging or left > 0.12):
				stick = Vector2.ZERO
				return true
			_threat_kind = ""
			me_c.release_guard()
			me_c.press_guard()
			_guard_hold = 0.4
			stick = Vector2.ZERO
			return true
		"dodge":
			_threat_kind = ""
			var side := Vector2(-dir.y, dir.x) * (1.0 if rng.randf() < 0.5 else -1.0)
			if _threat_dir != Vector2.ZERO:
				side = Vector2(-_threat_dir.y, _threat_dir.x) * signf(side.x + 0.001)
			_threat_dir = Vector2.ZERO
			stick = (side - dir * 0.4).normalized() if d < 2.5 else side
			me_c.press_dodge()
			return true
		"block":
			_threat_kind = ""
			me_c.press_guard()
			_hold_guard_until_safe = true
			stick = Vector2.ZERO
			return true
	_threat_kind = ""
	return false


func _think_melee(me_c: CombatController, foe_c: CombatController, me_m: PlayerMotor, d: float, dir: Vector2,
		reach: float, foe: FighterBody, center: Vector3, half: float) -> void:
	# L'avversario stordito o scoperto (rientro di un colpo forte): si punisce.
	var open := foe_c.stunned() or (foe_c.state == CombatController.State.ATTACK and foe_c.phase() == 2 and foe_c.attack != null and foe_c.attack.recovery > 0.35)
	match mode:
		"approach":
			stick = dir
			if d <= reach + 0.4:
				_set_mode("attack")
				_combo_left = rng.randi_range(1, int(_p(4)))
			elif d < reach + 4.5 and d > reach + 1.5 and me_m.on_ground and _mode_t > 0.4:
				var r := rng.randf()
				if r < 0.012 + 0.006 * level:
					# Capriola verso l'avversario e colpo in corsa.
					me_c.press_dodge()
					_dash_t = _clock
					_set_mode("dash")
				elif r < 0.02 + 0.006 * level and d < reach + 3.2:
					# Salto e colpo dall'alto.
					jump = true
					_leap_t = _clock
					_set_mode("leap")
		"dash":
			stick = dir
			if me_c.state == CombatController.State.DODGE and me_c.dodge_u() >= 0.5:
				me_c.press_light()
			if _mode_t > 0.7:
				_set_mode("recover")
		"leap":
			stick = dir
			if not me_m.on_ground and _clock - _leap_t > 0.18 and me_c.state == CombatController.State.IDLE:
				me_c.press_light()
			if _mode_t > 1.0 and me_m.on_ground:
				_set_mode("recover")
		"attack":
			stick = dir if d > reach * 0.6 else Vector2.ZERO
			if d > reach + 1.6 and not me_c.is_busy():
				_set_mode("approach")
				return
			if _can_press(me_c):
				var edge := half > 0.0 and Vector2(foe.position.x - center.x, foe.position.z - center.z).length() > half - 3.0
				if _combo_left > 0:
					me_c.press_light()
					_combo_left -= 1
				elif _combo_left == 0 and (edge or open or rng.randf() < float(_p(5))):
					# Forte in coda (vicino al bordo spinge fuori dal ring).
					me_c.press_heavy()
					_heavy_hold = rng.randf_range(0.05, 0.25) if rng.randf() < 0.6 else rng.randf_range(0.5, 1.0)
					_combo_left = -1
				else:
					_combo_left = -1
				_mark_press(me_c)
			if _combo_left < 0 and not me_c.is_busy() and _heavy_hold <= 0.0:
				_set_mode("recover")
		"recover":
			# Dopo la catena: di lato e un passo indietro, a volte in guardia.
			stick = (Vector2(-dir.y, dir.x) * _strafe - dir * (0.5 if d < reach + 1.0 else -0.3)).normalized()
			if _mode_t < 0.05 and rng.randf() < 0.35:
				me_c.press_guard()
				_guard_hold = rng.randf_range(0.4, 0.9)
			if _mode_t > rng.randf_range(0.5, 1.3) or (open and d < reach + 2.0):
				_strafe = -_strafe if rng.randf() < 0.4 else _strafe
				_set_mode("approach")
	if open and mode == "approach" and d <= reach + 1.2:
		_set_mode("attack")
		_combo_left = int(_p(4))


## Bastone: a distanza, dardi in catena e palla di fuoco caricata.
func _think_staff(me_c: CombatController, foe_c: CombatController, d: float, dir: Vector2) -> void:
	var side := Vector2(-dir.y, dir.x) * _strafe
	if d < STAFF_RANGE - 2.0:
		stick = (-dir + side * 0.4).normalized()
		if d < 2.2 and me_c.state == CombatController.State.IDLE and rng.randf() < 0.04:
			stick = -dir
			me_c.press_dodge()
		elif d < 2.4 and rng.randf() < 0.05:
			me_c.press_light()
	elif d > STAFF_RANGE + 3.5:
		stick = dir
	else:
		stick = side * 0.7
		if _mode_t > 1.5:
			_strafe = -_strafe
			_set_mode("cast")
	if d < 11.0 and _heavy_hold <= 0.0 and _can_press(me_c):
		if foe_c.stunned() or (d > 4.0 and rng.randf() < 0.012 + 0.004 * level):
			me_c.press_heavy()
			_heavy_hold = rng.randf_range(0.6, 1.2)
			_mark_press(me_c)
		elif rng.randf() < 0.05 + 0.02 * level:
			me_c.press_light()
			_mark_press(me_c)


## Si puo' premere un colpo: libero, in guardia o nel colpo gia' partito, e
## l'ultima pressione e' gia' diventata un attacco.
func _can_press(me_c: CombatController) -> bool:
	var st := me_c.state
	var ok := st == CombatController.State.IDLE or st == CombatController.State.GUARD \
		or (st == CombatController.State.ATTACK and me_c.phase() >= 1)
	return ok and me_c.buffer == &"" and (me_c.starts != _pressed_starts or _clock - _press_clock > 0.6)


func _mark_press(me_c: CombatController) -> void:
	_pressed_starts = me_c.starts
	_press_clock = _clock


## Vicino al bordo del ring si torna verso il centro (ma si puo' cadere lo
## stesso se spinti).
func _ring_guard(me_m: PlayerMotor, center: Vector3, half: float) -> void:
	if half <= 0.0:
		return
	var off := Vector2(me_m.position.x - center.x, me_m.position.z - center.z)
	var edge := maxf(absf(off.x), absf(off.y))
	if edge > half - 1.6:
		var back := -off.normalized()
		var k := clampf((edge - (half - 1.6)) / 1.2, 0.0, 1.0)
		stick = (stick * (1.0 - k) + back * (0.6 + k)).limit_length(1.0)


## Bloccati contro un oggetto (rastrelliera, espositori): un passo di lato.
func _track_stuck(dt: float, me_m: PlayerMotor) -> void:
	var moved := Vector2(me_m.position.x - _last_pos.x, me_m.position.z - _last_pos.z).length()
	_last_pos = me_m.position
	if stick.length() > 0.5 and moved < 0.6 * dt:
		_stuck_t += dt
	else:
		_stuck_t = maxf(0.0, _stuck_t - dt)
	if _stuck_t > 0.35:
		_stuck_t = 0.0
		_sidestep_t = 0.7
		if rng.randf() < 0.5:
			_strafe = -_strafe


func _set_mode(m: String) -> void:
	mode = m
	_mode_t = 0.0
