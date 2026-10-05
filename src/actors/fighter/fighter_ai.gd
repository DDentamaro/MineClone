class_name FighterAI
extends RefCounted
## Cervello del nemico dell'arena (D-058, rifatto in D-060 attorno allo
## scambio). Non ha mosse sue: preme gli stessi tasti del giocatore sul suo
## `CombatController` (colpo, forte tenuto, schivata, para tenuto), muove lo
## stesso stick e salta.
##
## Lo scontro e' a turni, come nei giochi d'azione con i duelli (Sekiro, For
## Honor; i "gettoni d'attacco" di DOOM e Batman per chi attacca quando):
## - Distanza: resta appena fuori portata, gira attorno, finte di passo avanti
##   e indietro. Non attacca mentre attacca il giocatore.
## - Offensiva: una sequenza di 2-4 colpi della catena dell'arma con un ritmo
##   che cambia (a volte trattiene il seguito), chiusa a volte da un forte o
##   da un attacco pericoloso (rosso, si schiva). Se viene deviata si ferma.
## - Rientro: finita la sequenza resta scoperta per un attimo (la finestra per
##   colpirla), poi torna alla distanza.
## - Difesa: quando il giocatore attacca alza la guardia e devia all'ultimo
##   istante (riflessi e precisione dal livello); dopo una deviazione o alla
##   fine della sequenza del giocatore contrattacca subito.
## - Punizione: giocatore con la postura rotta o scoperto -> colpo forte.
## Vede quello che vedrebbe un giocatore: il colpo che l'altro prepara (con un
## ritardo di reazione), i proiettili in arrivo.

## [reazione (s), deviazione, schivata, interrompere, colpi in sequenza,
##  forte in coda, pazienza (moltiplica i tempi d'attesa), pericoloso]
const LEVELS := [
	[0.34, 0.22, 0.15, 0.04, 2, 0.25, 1.4, 0.0],
	[0.28, 0.40, 0.18, 0.08, 3, 0.30, 1.2, 0.15],
	[0.22, 0.55, 0.20, 0.12, 4, 0.35, 1.0, 0.25],
	[0.17, 0.70, 0.22, 0.16, 4, 0.40, 0.85, 0.30],
]
## Distanza preferita col bastone.
const STAFF_RANGE := 5.5

var level := 0
## Uscite verso il motore: direzione voluta (piano XZ) e salto.
var stick := Vector2.ZERO
var jump := false
## Cosa sta facendo: neutral, offense, recover, defense, counter, dash, leap.
var mode := "neutral"
var rng := RandomNumberGenerator.new()

var _clock := 0.0
var _mode_t := 0.0
var _mode_len := 1.0
var _seen_starts := 0
var _pressed_starts := -1
var _press_clock := -99.0
var _string_left := 0
var _finisher := ""
var _hold_next := false
var _heavy_hold := 0.0
var _strafe := 1.0
var _step_dir := 0.0
var _step_t := 0.0
var _stuck_t := 0.0
var _sidestep_t := 0.0
var _last_pos := Vector3.ZERO
var _leap_t := -1.0
var _seen_shots := {}
## Difesa in corso: momento in cui reagire e come.
var _react_at := -1.0
var _react := ""
var _shot_dir := Vector2.ZERO
var _deflects := 0
var _dash_clock := -99.0
var _dt := 1.0 / 60.0


func _init(lv: int = 0, seed_value: int = 0) -> void:
	level = clampi(lv, 0, LEVELS.size() - 1)
	rng.seed = seed_value if seed_value != 0 else randi()


func _p(i: int) -> Variant:
	return LEVELS[level][i]


func reset() -> void:
	stick = Vector2.ZERO
	jump = false
	_set_mode("neutral", 1.0)
	_react = ""
	_react_at = -1.0
	_string_left = 0
	_heavy_hold = 0.0
	_seen_shots.clear()


## Un passo di decisione. `shots`: i proiettili del rivale; `center`/`half`:
## il ring (half <= 0: nessun limite).
func think(dt: float, me_c: CombatController, me_m: PlayerMotor, foe: FighterBody, foe_c: CombatController,
		shots: Array, center: Vector3, half: float) -> void:
	_clock += dt
	_dt = dt
	_mode_t += dt
	jump = false
	if _heavy_hold > 0.0:
		_heavy_hold -= dt
		if _heavy_hold <= 0.0:
			me_c.release_heavy()
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
	# Portata vera: arma piu' lo scatto in avanti del primo colpo.
	var first := w.attack(w.light_start)
	var reach := w.strike_dist + 0.3 + (first.lunge * 0.8 if first != null else 0.0)
	_track_stuck(dt, me_m)
	# Respinto dalla deviazione del giocatore o da un clash: la sequenza e' finita.
	if me_c.stunned() and me_c.stun_kind in ["recoil", "clash", "break"] and mode == "offense":
		_set_mode("recover", 0.2)
	if me_c.stunned():
		stick = Vector2.ZERO
		me_c.release_guard()
		# Barcollare leggero: chi e' sveglio alza subito la guardia.
		if me_c.stun_kind == "flinch" and rng.randf() < 0.1 + 0.15 * level:
			me_c.press_guard()
		return
	_watch_attack(me_c, foe_c, d)
	_watch_shots(shots, me_m)
	if _defend(me_c, foe_c, d, dir):
		_ring_guard(me_m, center, half)
		return
	var open := foe_c.stunned() and foe_c.stun_kind != "flinch" or foe_c.broken
	if staff:
		_think_staff(me_c, foe_c, d, dir)
	else:
		_think_melee(me_c, foe_c, me_m, d, dir, reach, open)
	_ring_guard(me_m, center, half)
	if _sidestep_t > 0.0:
		_sidestep_t -= dt
		stick = (stick + Vector2(-dir.y, dir.x) * _strafe * 1.2).normalized()


# ------------------------------------------------------------------ difesa

## Un attacco nuovo del rivale: si sceglie come reagire (dopo il ritardo).
func _watch_attack(me_c: CombatController, foe_c: CombatController, d: float) -> void:
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
	# Durante la propria sequenza si continua (chi colpisce per primo ha
	# l'iniziativa), salvo attacchi pericolosi.
	if mode == "offense" and me_c.state == CombatController.State.ATTACK and not foe_c.perilous:
		return
	_react_at = _clock + float(_p(0)) * rng.randf_range(0.8, 1.25)
	var r := rng.randf()
	if foe_c.perilous or a.shape == AttackDefinition.Shape.RADIAL or a.plunge:
		# Pericoloso o a terra: capriola (la guardia non basta o costa troppo).
		_react = "dodge" if r < 0.45 + 0.12 * level else "block"
	elif a.cast != "":
		# Magia da lontano: solo una capriola di lato, senza fermarsi in difesa.
		_react = "dodge" if r < 0.6 else ""
		return
	elif r < float(_p(1)):
		_react = "deflect"
	elif r < float(_p(1)) + float(_p(2)):
		_react = "dodge"
	elif r < float(_p(1)) + float(_p(2)) + float(_p(3)):
		_react = "interrupt"
	else:
		_react = "block"
	if mode != "defense":
		_set_mode("defense", 2.0)


func _watch_shots(shots: Array, me_m: PlayerMotor) -> void:
	for o in shots:
		var s := o as FireMagic.Shot
		if s == null or s.dead or _seen_shots.has(s):
			continue
		var to_me := me_m.position + Vector3(0, 0.8, 0) - s.p
		var dist := to_me.length()
		if dist > 7.0 or s.v.length() < 0.1 or s.v.normalized().dot(to_me / maxf(dist, 1e-3)) < 0.8:
			continue
		_seen_shots[s] = true
		if _clock - _dash_clock < 1.2:
			continue
		_react_at = _clock + float(_p(0)) * rng.randf_range(0.6, 1.0)
		_react = "dodge" if rng.randf() < 0.5 else ""
		_shot_dir = Vector2(s.v.x, s.v.z).normalized()
	if _seen_shots.size() > 32:
		_seen_shots.clear()


## In difesa: guardia, deviazione all'ultimo istante, capriola; finita la
## sequenza del giocatore (o dopo una deviazione) si contrattacca.
func _defend(me_c: CombatController, foe_c: CombatController, d: float, dir: Vector2) -> bool:
	if mode != "defense":
		# Fuori dalla difesa resta solo la capriola contro la magia.
		if _react == "dodge" and _clock >= _react_at:
			var side := Vector2(-dir.y, dir.x) * (1.0 if rng.randf() < 0.5 else -1.0)
			if _shot_dir != Vector2.ZERO:
				side = Vector2(-_shot_dir.y, _shot_dir.x) * signf(side.x + 0.001)
				_shot_dir = Vector2.ZERO
			stick = side
			me_c.press_dodge()
			_dash_clock = _clock
			_react = ""
			return true
		return false
	var foe_busy := foe_c.state == CombatController.State.ATTACK and foe_c.phase() <= 1
	var a := foe_c.attack
	stick = -dir * 0.15 if d < 1.2 else Vector2.ZERO
	if _react != "" and _clock >= _react_at:
		match _react:
			"deflect":
				# Para un attimo prima che la lama arrivi.
				if foe_c.state == CombatController.State.ATTACK and a != null and foe_c.phase() == 0 \
						and (foe_c.charging or a.windup - foe_c.t > 0.1):
					me_c.press_guard()
					return true
				me_c.release_guard()
				me_c.press_guard()
				_react = ""
			"block":
				me_c.press_guard()
				_react = ""
			"dodge":
				me_c.release_guard()
				var side := Vector2(-dir.y, dir.x) * (1.0 if rng.randf() < 0.5 else -1.0)
				if _shot_dir != Vector2.ZERO:
					side = Vector2(-_shot_dir.y, _shot_dir.x) * signf(side.x + 0.001)
					_shot_dir = Vector2.ZERO
				stick = (side - dir * 0.5).normalized() if d < 2.5 else side
				me_c.press_dodge()
				_react = ""
				_set_mode("recover", 0.25)
				return true
			"interrupt":
				# Colpo veloce dentro la carica lenta dell'avversario.
				me_c.release_guard()
				me_c.press_light()
				_react = ""
				_begin_offense(1, "")
				return true
	# Deviazione riuscita (si apre la risposta): contrattacco immediato.
	if me_c.riposte_t > 0.0:
		_deflects += 1
		me_c.release_guard()
		_begin_offense(rng.randi_range(1, 2), "heavy" if foe_c.broken else "")
		return false
	# Finita la sequenza del giocatore: tocca a noi.
	if not foe_busy and _react == "" and _mode_t > 0.25:
		me_c.release_guard()
		if d < me_c.weapon.strike_dist + 1.8 and rng.randf() < 0.75:
			_begin_offense(rng.randi_range(1, int(_p(4))), "")
		else:
			_set_mode("neutral", rng.randf_range(0.4, 0.9) * float(_p(6)))
		return false
	if _mode_t > _mode_len and not foe_busy:
		me_c.release_guard()
		_set_mode("neutral", 0.6)
		return false
	return true


# ------------------------------------------------------------------ attacco

func _think_melee(me_c: CombatController, foe_c: CombatController, me_m: PlayerMotor, d: float, dir: Vector2,
		reach: float, open: bool) -> void:
	if open and mode != "offense" and mode != "dash":
		_begin_offense(int(_p(4)), "heavy" if foe_c.broken else "")
	match mode:
		"neutral":
			me_c.release_guard()
			# Appena fuori portata, di lato, con finte di passo avanti e indietro.
			var want := reach + 1.0
			var radial := clampf((d - want) * 1.2, -1.0, 1.0)
			_step_t -= _dt
			if _step_t <= 0.0:
				_step_t = rng.randf_range(0.4, 0.9)
				_step_dir = [0.0, 0.0, 0.8, -0.6][rng.randi() % 4]
				if rng.randf() < 0.25:
					_strafe = -_strafe
			stick = (dir * (radial + _step_dir) + Vector2(-dir.y, dir.x) * _strafe * 0.7).limit_length(1.0)
			if _mode_t > _mode_len:
				var r := rng.randf()
				if d > reach + 2.2 and d < reach + 5.0 and me_m.on_ground and r < 0.15 + 0.05 * level:
					me_c.press_dodge()
					_set_mode("dash", 0.8)
				elif d > reach + 1.2 and d < reach + 3.5 and me_m.on_ground and r < 0.25 + 0.05 * level:
					jump = true
					_leap_t = _clock
					_set_mode("leap", 1.2)
				else:
					var fin := ""
					var fr := rng.randf()
					if fr < float(_p(7)):
						fin = "perilous"
					elif fr < float(_p(7)) + float(_p(5)):
						fin = "heavy"
					_begin_offense(rng.randi_range(1, int(_p(4))), fin)
		"dash":
			stick = dir
			if me_c.state == CombatController.State.DODGE and me_c.dodge_u() >= 0.5:
				me_c.press_light()
			if _mode_t > _mode_len:
				_set_mode("recover", 0.5)
		"leap":
			stick = dir
			if not me_m.on_ground and _clock - _leap_t > 0.18 and me_c.state == CombatController.State.IDLE:
				me_c.press_light()
			if _mode_t > 0.5 and me_m.on_ground and not me_c.is_busy():
				_set_mode("recover", 0.5)
		"offense", "counter":
			me_c.release_guard()
			stick = dir if d > reach * 0.7 else Vector2.ZERO
			if d > reach + 2.5 and not me_c.is_busy() and _mode_t > 3.0:
				_set_mode("neutral", 0.5)
				return
			if d > reach + 0.2 and not me_c.is_busy():
				# Inseguimento: a distanza una capriola in avanti chiude lo spazio.
				if d > reach + 2.5 and me_m.on_ground and _clock - _dash_clock > 1.6 and rng.randf() < _dt * 1.5:
					_dash_clock = _clock
					me_c.press_dodge()
				return
			if _can_press(me_c):
				# Ritmo che cambia: a volte il seguito aspetta la fine del rientro.
				if _hold_next and me_c.state == CombatController.State.ATTACK and me_c.phase_u() < 0.7:
					return
				_hold_next = rng.randf() < 0.3
				if _string_left > 0:
					me_c.press_light()
					_string_left -= 1
					_mark_press(me_c)
				elif _finisher != "":
					if _finisher == "perilous":
						me_c.perilous_next = true
						_heavy_hold = rng.randf_range(0.6, 0.9)
					else:
						_heavy_hold = rng.randf_range(0.05, 0.3) if rng.randf() < 0.6 else rng.randf_range(0.5, 0.9)
					me_c.press_heavy()
					_finisher = ""
					_mark_press(me_c)
				elif not me_c.is_busy() and _heavy_hold <= 0.0:
					# Rientro: scoperto per un attimo (la finestra del giocatore).
					_set_mode("recover", rng.randf_range(0.45, 0.85))
		"recover":
			me_c.release_guard()
			stick = -dir * 0.35 if _mode_t > _mode_len * 0.6 else Vector2.ZERO
			if _mode_t > _mode_len:
				_set_mode("neutral", rng.randf_range(0.5, 1.4) * float(_p(6)))


func _begin_offense(n: int, finisher: String) -> void:
	_string_left = maxi(1, n)
	_finisher = finisher
	_hold_next = false
	_set_mode("offense", 3.0)


## Bastone: a distanza, dardi in catena e palla di fuoco caricata.
func _think_staff(me_c: CombatController, foe_c: CombatController, d: float, dir: Vector2) -> void:
	var side := Vector2(-dir.y, dir.x) * _strafe
	if d < STAFF_RANGE - 2.0:
		stick = (-dir + side * 0.4).normalized()
		if d < 2.2 and me_c.state == CombatController.State.IDLE and _clock - _dash_clock > 1.5 and rng.randf() < _dt * 2.0:
			_dash_clock = _clock
			stick = -dir
			me_c.press_dodge()
		elif d < 2.4 and rng.randf() < _dt * 2.5:
			me_c.press_light()
	elif d > STAFF_RANGE + 3.5:
		stick = dir
	else:
		stick = side * 0.7
		if _mode_t > 1.5:
			_strafe = -_strafe
			_set_mode("neutral", 1.0)
	if d < 11.0 and _heavy_hold <= 0.0 and _can_press(me_c):
		# Probabilita' al secondo (indipendenti dai fotogrammi).
		if foe_c.stunned() or foe_c.broken or (d > 4.0 and rng.randf() < _dt * (0.25 + 0.08 * level)):
			me_c.press_heavy()
			_heavy_hold = rng.randf_range(0.6, 1.2)
			_mark_press(me_c)
		elif rng.randf() < _dt * (0.9 + 0.3 * level):
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


## Vicino al bordo del ring si torna verso il centro.
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


func _set_mode(m: String, length: float = 1.0) -> void:
	mode = m
	_mode_t = 0.0
	_mode_len = length
