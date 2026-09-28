class_name MagicSystem
extends RefCounted
## Magia del giocatore (M4): regole del prototipo (HTML 7977–8322, inventario §8)
## senza nodi, deterministica con il suo generatore.
##
## - Lancio: nessuna → raccolta → recupero. Niente mana (D-027, RMNDWN): ogni
##   magia ha un Output che non puo' superare il tetto del caster, e ogni
##   raccolta, appena parte, alza la Pressione del nucleo (satura a 1, riparte
##   sotto .85). Magie del libro (RMNDWN, D-031): una pressione avvia una
##   raccolta che finisce da sola, niente carica tenuta; la annullano solo la
##   spinta prima dell'impegno (78%) o la capriola; coda dal 55%. Dardi del
##   prototipo: impegno al 35%, rilascio prima dell'impegno dopo 0,2 s =
##   annullato, tocco breve = lancio automatico.
## - Mira: bersaglio agganciato al 55% dell'altezza, altrimenti 7 unita' avanti.
## - Dardi balistici (gravita' 18 × grav, attrito), compensazione balistica,
##   collisione con bersagli (4 campioni), voxel (DDA), tronchi. L'aria trapassa.
## - Stati (bruciatura, bagnato, lento, spinto) e `status_react` come RMNDWN:
##   fuoco su bagnato = vapore e niente danno; acqua su bruciante = shock termico
##   (4 × pile di danno silenzioso); aria su bruciante = ventaglio; Karma su
##   bagnato = conduzione (stagger ×1,8 e scossa ai vicini bagnati).
## - Karma: ogni colpo e' una testa che viaggia e si ferma sul primo corpo; a
##   fine portata svanisce senza impatto. Hitstop e scossa con le famiglie
##   d'impatto di RMNDWN (HITFAM) e il loro refrattario.
## - Mondo: fuoco su erba/legno/foglie con automa a tick 0,25 s, bagnato che
##   spegne e impedisce l'accensione, cratere del masso, vento che soffia le braci.
##
## Differenza voluta (D-024): si lancia con la mano sinistra, l'arma resta in pugno.

const MG := 18.0
const COMMIT := 0.35
const TAP := 0.2
const HOLD_EXTRA := 1.6
const AIM_DIST := 7.0
const LOCK_RANGE := 14.0
const LOCK_CONE := 1.2

const SOFT := {BlockCatalog.DIRT: true, BlockCatalog.GRASS: true, BlockCatalog.SAND: true}
const FLAM := {BlockCatalog.GRASS: .55, BlockCatalog.WOOD: .30, BlockCatalog.LEAVES: .85}
const BURN_LIFE := {BlockCatalog.GRASS: 3.2, BlockCatalog.WOOD: 7.5, BlockCatalog.LEAVES: 2.5}
const BURN_TO := {BlockCatalog.GRASS: BlockCatalog.DIRT, BlockCatalog.WOOD: BlockCatalog.AIR, BlockCatalog.LEAVES: BlockCatalog.AIR}
const FIRE_MAX := 110
const STDEF := {
	"burn": {"dur": 4.0, "tick": .45, "dps": 3.5, "max": 3, "gap": .9, "tag": "BRUCIA"},
	"wet": {"dur": 6.0, "tag": "BAGNATO"},
	"slow": {"dur": 2.5, "mag": .45, "tag": "LENTO"},
	"pushed": {"dur": .85, "mag": .70, "tag": "SPINTO"},
	"flow": {"dur": 4.5, "mag": 1.55, "tag": "FLUSSO"},
	"mud": {"dur": .35, "mag": .70, "tag": "FANGO"},
}

enum Phase { NONE, GATHER, RECOVER }


class Dart:
	extends RefCounted
	var spell: SpellDefinition
	var p := Vector3.ZERO
	var prev := Vector3.ZERO
	var v := Vector3.ZERO
	var t := 0.0
	var hits := {}
	var bounces := 0
	var acc := 0
	var dead := false
	## Punto di partenza (i raggi del Karma sono accesi da qui alla testa).
	var origin := Vector3.ZERO
	## Secondi ancora fermo mentre si compone (masso davanti alla mano, coni ai
	## lati del caster), posizione trattenuta (destra, su, avanti rispetto al
	## caster; ZERO = davanti alla mano) e velocita' del lancio (0 = arriva in hold).
	var hold := 0.0
	var hold_at := Vector3.ZERO
	var hold_speed := 0.0
	## Distanza oltre la quale un proiettile elementale si ferma (la mira).
	var reach := INF
	## Dopo il contatto: secondi di dissolvenza del raggio (niente collisioni).
	var fade := 0.0
	var fade_life := 0.0
	## Coerenza al contatto (per il disegno dell'impatto).
	var k := 1.0


class FireCell:
	extends RefCounted
	var cell: Vector3i
	var id := 0
	var t := 0.0
	var life := 1.0
	var gen := 0
	var kids := 0


var world: WorldData
var edits: WorldEditService
var catalog: BlockCatalog
var tree_grid := {}
var phase: Phase = Phase.NONE
var t := 0.0
## Avanzamento della raccolta 0..1.
var w := 0.0
var committed := false
var auto_fire := false
var held := false
var aim := Vector3.ZERO
var face := 0.0
var lock_target: CombatTarget
var darts: Array[Dart] = []
## CombatTarget -> {nome: {t, st, tick, since}}
var statuses := {}
## Vector3i -> FireCell
var fire := {}
## Vector3i -> secondi rimasti
var wet := {}
## Vento dell'ultima spina d'aria: {x, z, dx, dz, t, pow, r}.
var wind := {}
## Blocchi presi dai crateri (li mette nello zaino il gioco).
var crater_items := 0
## Eventi per gli effetti: {type, ...}.
var events: Array[Dictionary] = []
## Hitstop chiesto dai colpi (lo consuma il GameRoot).
var hitstop := 0.0
var daylight := 1.0
var rng := RandomNumberGenerator.new()

# --- Libro e barra (RMNDWN: 5 magie equipaggiate) --------------------------
const BAR := 5
## Magie conosciute (id -> true): il livello 1 da subito, il resto dalle pergamene.
var known := {}
## Barra delle magie: 5 id (o &"").
var bar: Array[StringName] = [&"fire", &"water", &"earth", &"air", &""]
var bar_index := 0

# --- Nucleo (RMNDWN K33 + K116): Output massimo per lancio e Pressione -------
## Output del caster senza equipaggiamento; l'equipaggiamento lo alza (Mente, oro).
const OUTPUT_BASE := 60.0
## Output guadagnato per ogni magia di livello 2+ imparata (aggiunta RPG, D-027).
const STUDY := 5.0
const PRESS_DECAY := 0.24
const PRESS_GAIN := 0.85
const ALT_BONUS := 0.55
const COMMIT_NEW := 0.78
const QUEUE_FROM := 0.55
## Passo massimo durante la magia (RMNDWN ACTP.strikeEntryCap, m/s).
const CAST_WALK := 1.75
var output_bonus := 0.0
## Rigenerazione dell'equipaggiamento: accelera il calo della pressione.
var decay_bonus := 0.0
var power := 1.0
var pressure := 0.0
var saturated := false
var last_el := ""
var queued := false
## Il giocatore come bersaglio degli stati (fango, flusso, bagnato).
var player := CombatTarget.new()
## Forme, strutture e zone (SpellRuntime).
var runtime := SpellRuntime.new(self)

var _tap := false
var _fire_tick := 0.0
var _fire_edits: Array[WorldEditService.Edit] = []
var _flush_t := 0.0
## Colpi della salva ancora da partire: {t, spell, i}.
var _pending: Array[Dictionary] = []


func _init(seed_value: int = 1) -> void:
	rng.seed = seed_value
	player.radius = PlayerMotor.RADIUS
	player.height = PlayerMotor.HEIGHT
	for s in SpellDefinition.all():
		if s.tier == 1:
			known[s.id] = true


## Output: base + equipaggiamento + studio (ogni magia imparata da pergamena).
func output_cap() -> float:
	return OUTPUT_BASE + output_bonus + STUDY * learned_count()


func learned_count() -> int:
	var n := 0
	for id: StringName in known:
		var s := SpellDefinition.by_id(id)
		if s != null and s.tier > 1:
			n += 1
	return n


func to_dict() -> Dictionary:
	var k: Array[String] = []
	for id: StringName in known:
		k.append(String(id))
	var b: Array[String] = []
	for id in bar:
		b.append(String(id))
	return {"known": k, "bar": b, "sel": bar_index}


func load_dict(d: Dictionary) -> void:
	for id in d.get("known", []):
		if SpellDefinition.by_id(StringName(id)) != null:
			known[StringName(id)] = true
	var b: Array = d.get("bar", [])
	for i in mini(BAR, b.size()):
		var id := StringName(b[i])
		bar[i] = id if known.has(id) else &""
	bar_index = clampi(int(d.get("sel", 0)), 0, BAR - 1)
	if bar[bar_index] == &"":
		select_next()


func spell() -> SpellDefinition:
	var s := SpellDefinition.by_id(bar[bar_index]) if bar[bar_index] != &"" else null
	return s if s != null else SpellDefinition.by_id(&"fire")


func select(i: int) -> void:
	var k := posmod(i, BAR)
	if bar[k] == &"":
		return
	bar_index = k
	if phase == Phase.GATHER and not committed:
		phase = Phase.NONE
		events.append({"type": "cancel"})


## Prossimo slot pieno della barra.
func select_next() -> void:
	for k in range(1, BAR + 1):
		var j := (bar_index + k) % BAR
		if bar[j] != &"":
			select(j)
			return


func learn(id: StringName) -> bool:
	if SpellDefinition.by_id(id) == null or known.has(id):
		return false
	known[id] = true
	return true


## Mette la magia nello slot (spostandola se era in un altro); solo magie conosciute.
func equip(id: StringName, slot: int) -> bool:
	if not known.has(id):
		return false
	var at := bar.find(id)
	if at >= 0 and at != slot:
		bar[at] = &""
	bar[slot] = id
	if bar[bar_index] == &"":
		bar_index = slot
	return true


func press() -> void:
	_tap = true
	held = true
	# Coda (RMNDWN): una pressione durante il recupero o dopo il 55% della raccolta.
	if phase == Phase.RECOVER or (phase == Phase.GATHER and w >= QUEUE_FROM):
		queued = true


func release() -> void:
	held = false


## Mira alla Brawl Stars (D-034): direzione nel piano XZ (vuota = mira
## automatica) e distanza 0..1 della portata per le magie a punto.
var aim_dir := Vector2.ZERO
var aim_frac := 1.0
## La magia in corso ha una mira scelta dal giocatore.
var aimed := false
## Cono stretto in cui un bersaglio viene preso lungo la direzione scelta.
const AIM_SNAP := 0.26


func press_aimed(dir: Vector2, frac: float) -> void:
	aim_dir = dir.normalized() if dir.length() > 1e-3 else Vector2.ZERO
	aim_frac = clampf(frac, 0.0, 1.0)
	press()


func is_casting() -> bool:
	return phase != Phase.NONE or not _pending.is_empty()


## Motivo per cui la magia scelta non parte ("" = puo' partire).
func blocked_reason(s: SpellDefinition) -> String:
	if not known.has(s.id):
		return "NON CONOSCIUTA"
	if s.output > output_cap() + 1e-4:
		return "OUTPUT %d/%d" % [int(s.output), int(output_cap())]
	if saturated:
		return "NUCLEO SATURO"
	if has_status(player, "pushed"):
		return "SPINTO"
	return ""


func reset() -> void:
	phase = Phase.NONE
	arm_w = 0.0
	recoils.clear()
	darts.clear()
	statuses.clear()
	fire.clear()
	wet.clear()
	wind = {}
	_fire_edits.clear()
	_pending.clear()
	runtime.clear()
	pressure = 0.0
	saturated = false
	queued = false


static func _fwd(f: float) -> Vector3:
	return Vector3(-sin(f), 0, -cos(f))


## La raccolta si allunga con la pressione: sopra .75 fino a +60% (K116).
func gather_mul() -> float:
	return 1.0 + 0.6 * minf(1.0, (pressure - 0.75) / 0.25) if pressure > 0.75 else 1.0


func _press_add(s: SpellDefinition) -> void:
	var g := maxf(0.12, s.output / maxf(1.0, output_cap()) * PRESS_GAIN)
	if last_el != "" and last_el != s.el:
		g *= ALT_BONUS
	last_el = s.el
	pressure = minf(1.25, pressure + g)
	if pressure >= 1.0 and not saturated:
		saturated = true
		events.append({"type": "text", "p": player.position + Vector3(0, 1.8, 0), "text": "NUCLEO SATURO"})


func _press_step(dt: float) -> void:
	var d := PRESS_DECAY * (1.0 + 0.12 * decay_bonus) * (0.45 if phase != Phase.NONE else 1.0) * (1.0 + 0.6 * maxf(0.0, pressure - 0.75))
	pressure = maxf(0.0, pressure - d * dt)
	if saturated and pressure < 0.85:
		saturated = false


## Un passo. `facing` e' la direzione del giocatore; `hand` il punto di lancio;
## `can_start` falso se il corpo a corpo e' occupato.
func step(dt: float, motor: PlayerMotor, targets: Array, facing: float, hand: Vector3, can_start: bool = true) -> void:
	var s := spell()
	player.position = motor.position
	var all: Array = []
	all.append_array(targets)
	all.append(player)
	_targets_cache = targets
	_player_pos = motor.position
	_press_step(dt)
	for f: String in _refr:
		_refr[f] = maxf(0.0, float(_refr[f]) - dt)
	var tap := _tap
	_tap = false
	match phase:
		Phase.NONE:
			face = facing
			var want := held or tap or queued
			if want and motor.on_ground and can_start and not motor.swimming:
				queued = false
				var why := blocked_reason(s)
				if why != "":
					if tap:
						events.append({"type": "text", "p": motor.position + Vector3(0, 1.6, 0), "text": why})
				else:
					phase = Phase.GATHER
					t = 0.0
					w = 0.0
					committed = false
					# RMNDWN: la raccolta finisce da sola; i dardi del prototipo si tengono.
					auto_fire = ((tap or queued) and not held) or not s.is_legacy()
					# La pressione sale quando la raccolta parte (RMNDWN L33895).
					_press_add(s)
					aimed = aim_dir != Vector2.ZERO and s.aim_shape() != "self"
					if aimed:
						facing = atan2(-aim_dir.x, -aim_dir.y)
						face = facing
					if s.at_self or (aimed and s.aim_shape() == "point"):
						lock_target = null
					elif aimed:
						lock_target = _pick_target(motor.position, facing, targets, AIM_SNAP, s.aim_range())
					else:
						lock_target = _pick_target(motor.position, facing, targets)
					aim_dir = Vector2.ZERO
					aim = _resolve_aim(motor, facing, s)
					events.append({"type": "gather", "el": s.el, "spell": s})
		Phase.GATHER:
			var dur := s.cast_dur * gather_mul()
			t += dt
			w = minf(1.0, t / dur)
			if lock_target != null and not lock_target.alive:
				lock_target = null
			aim = _resolve_aim(motor, facing, s)
			if w >= (COMMIT if s.is_legacy() else COMMIT_NEW):
				if not committed:
					events.append({"type": "commit", "el": s.el})
				committed = true
			if has_status(player, "pushed") and not committed:
				# Spinto: la raccolta non impegnata si perde (K116/RMNDWN 21648).
				phase = Phase.NONE
				events.append({"type": "cancel"})
			elif not held and not auto_fire and not committed:
				if t < TAP:
					auto_fire = true
				else:
					phase = Phase.NONE
					events.append({"type": "cancel"})
			elif w >= 1.0 and (not held or auto_fire or t > dur + HOLD_EXTRA):
				_cast(s, hand, motor)
			var d := aim - motor.position
			if Vector2(d.x, d.z).length() > 0.05 and not s.at_self:
				face = atan2(-d.x, -d.z)
		Phase.RECOVER:
			t += dt
			if t >= s.recover and _pending.is_empty():
				phase = Phase.NONE
	_step_pending(dt, hand, motor)
	_step_darts(dt, motor, targets, hand)
	runtime.step(dt, motor, targets, hand)
	_step_fire(dt, motor, all)
	_step_status(dt)
	_step_pose(dt, s)


func _pick_target(from: Vector3, facing: float, targets: Array, cone: float = LOCK_CONE, max_range: float = LOCK_RANGE) -> CombatTarget:
	var best: CombatTarget = null
	var score := INF
	for o in targets:
		var tg := o as CombatTarget
		if tg == null or not tg.alive or tg == player:
			continue
		var v := Vector2(tg.position.x - from.x, tg.position.z - from.z)
		var d := v.length()
		if d > max_range or d < 0.3:
			continue
		var ang := absf(wrapf(atan2(-v.x, -v.y) - facing, -PI, PI))
		if ang > cone:
			continue
		var sc := d + ang * 4.0
		if sc < score:
			score = sc
			best = tg
	return best


## Mira: bersaglio al 55% dell'altezza; senza bersaglio 7 unita' avanti (dardi
## del prototipo) o 10 (RMNDWN), all'altezza della mano.
func _resolve_aim(motor: PlayerMotor, facing: float, s: SpellDefinition = null) -> Vector3:
	if lock_target != null and lock_target.alive:
		return lock_target.position + Vector3(0, lock_target.height * 0.55, 0)
	if aimed and s != null:
		# Mira scelta: punto a distanza (aree) o fondo della fascia (proiettili).
		var r := s.aim_range()
		var dist := clampf(aim_frac * r, 1.5, r) if s.aim_shape() == "point" else r
		return motor.position + _fwd(face) * dist + Vector3(0, 0.55, 0)
	var dist := AIM_DIST if s == null or s.is_legacy() else 10.0
	return motor.position + _fwd(facing) * dist + Vector3(0, 0.55, 0)


## Fine della raccolta: pressione, poi la forma della magia (salve comprese).
func _cast(s: SpellDefinition, hand: Vector3, motor: PlayerMotor) -> void:
	phase = Phase.RECOVER
	t = 0.0
	if s.is_legacy():
		_release(s, hand, motor)
		return
	for i in s.salvo_n:
		if i == 0:
			_shot(s, i, hand, motor)
		else:
			_pending.append({"t": s.salvo_gap * i, "spell": s, "i": i})


func _step_pending(dt: float, hand: Vector3, motor: PlayerMotor) -> void:
	var k := _pending.size() - 1
	while k >= 0:
		_pending[k]["t"] = float(_pending[k]["t"]) - dt
		if float(_pending[k]["t"]) <= 0.0:
			var e: Dictionary = _pending[k]
			_pending.remove_at(k)
			_shot(e["spell"], int(e["i"]), hand, motor)
		k -= 1


## Direzione del colpo `i` di una salva a ventaglio.
func shot_dir(s: SpellDefinition, i: int, hand: Vector3) -> Vector3:
	var d := aim - hand
	var l := d.length()
	d = d / l if l > 1e-4 else _fwd(face)
	# Il ventaglio esiste solo per i raggi del Karma (la raffica di fuoco converge).
	if s.fan_deg > 0.0 and s.salvo_n > 1 and s.el == "karma":
		var off := (float(i) - (s.salvo_n - 1) * 0.5) / maxf(1.0, (s.salvo_n - 1) * 0.5)
		d = d.rotated(Vector3.UP, deg_to_rad(s.fan_deg) * off)
	return d


func _shot(s: SpellDefinition, i: int, hand: Vector3, motor: PlayerMotor) -> void:
	var d := shot_dir(s, i, hand)
	events.append({"type": "release", "el": s.el, "p": hand + d * 0.12, "dir": d, "spell": s})
	match s.kind:
		"beam", "shaft", "orb":
			# Karma: una testa che viaggia per speed·lifetime (RMNDWN L29483).
			_spawn_dart(s, hand + d * 0.12, d)
		"bolt", "volley", "ball":
			var dart := _spawn_dart(s, hand + d * 0.12, d)
			dart.reach = maxf(0.5, (aim - dart.p).length())
		"throw":
			# Il masso si compone davanti alla mano per meta' del viaggio, poi vola
			# e arriva al contatto a 1,5 s (v78 struct throw).
			var o := hand + _fwd(face) * 0.45 + Vector3(0, 0.22, 0)
			var dd := aim - o
			var dist := maxf(1.0, dd.length())
			var r := _spawn_dart(s, o, dd / dist)
			r.hold = s.hold
			r.v = dd / dist * (dist / maxf(0.05, s.hit_at - s.hold))
			r.reach = dist
		"twins":
			# Coni gemelli (RMNDWN earth_twins: gap 2,0, avanti .85, su .55): si
			# alzano ai lati del caster, poi partono insieme verso la mira.
			for side in [-1.0, 1.0]:
				var loc := Vector3(side * 1.0, 1.0, 0.85)
				var o2 := _held_point(loc, hand)
				var tw := _spawn_dart(s, o2, (aim - o2).normalized())
				tw.hold = s.hold
				tw.hold_at = loc
				tw.hold_speed = s.speed
				tw.reach = maxf(1.0, (aim - o2).length())
		"meteor":
			var from := aim + Vector3(-1.2, 7.5, 1.0)
			var dm := (aim - from).normalized()
			var met := _spawn_dart(s, from, dm)
			met.reach = (aim - from).length()
		_:
			runtime.cast(s, i, hand, d, motor)


func _spawn_dart(s: SpellDefinition, o: Vector3, d: Vector3) -> Dart:
	var dart := Dart.new()
	dart.spell = s
	dart.p = o
	dart.prev = o
	dart.origin = o
	dart.v = d * s.speed
	if s.grav > 0.0:
		var dist := Vector2(aim.x - o.x, aim.z - o.z).length()
		dart.v.y += 0.5 * MG * s.grav * dist / s.speed
	darts.append(dart)
	return dart


func _release(s: SpellDefinition, hand: Vector3, motor: PlayerMotor) -> void:
	var d := aim - hand
	var l := d.length()
	d = d / l if l > 1e-4 else _fwd(face)
	if s.el != "air" and l < 1.2:
		d = _fwd(face)
	var o := hand + d * 0.12
	var dart := Dart.new()
	dart.spell = s
	dart.p = o
	dart.prev = o
	dart.v = d * s.speed
	# Compensazione balistica: il dardo arriva dove si mira.
	if s.grav > 0.0:
		var dist := Vector2(aim.x - o.x, aim.z - o.z).length()
		var tt := dist / s.speed
		dart.v.y += 0.5 * MG * s.grav * tt
	darts.append(dart)
	events.append({"type": "release", "el": s.el, "p": o, "dir": d, "spell": s})


## Coerenza del Karma a un tempo di volo (K8): exp(-decoh·t).
static func coherence(s: SpellDefinition, t_fly: float) -> float:
	if s.decoh <= 0.0:
		return 1.0
	return maxf(s.coh_floor, exp(-s.decoh * t_fly))


func _step_darts(dt: float, motor: PlayerMotor, targets: Array, hand: Vector3 = Vector3.ZERO) -> void:
	var opaque := catalog.opaque_table() if catalog != null else PackedByteArray()
	var i := darts.size() - 1
	while i >= 0:
		var P := darts[i]
		var S := P.spell
		if P.fade > 0.0:
			# Raggio gia' arrivato: resta solo il disegno che si spegne.
			P.fade -= dt
			if P.fade <= 0.0:
				darts.remove_at(i)
			i -= 1
			continue
		if P.hold > 0.0:
			# Il costrutto si compone e segue il caster, poi parte verso la mira.
			P.hold -= dt
			P.p = _held_point(P.hold_at, hand)
			P.prev = P.p
			P.origin = P.p
			var dd := aim - P.p
			var dist0 := maxf(1.0, dd.length())
			var sp := P.hold_speed if P.hold_speed > 0.0 else dist0 / maxf(0.05, S.hit_at - S.hold)
			P.v = dd / dist0 * sp
			P.reach = dist0
			i -= 1
			continue
		P.t += dt
		P.prev = P.p
		P.v.y -= MG * S.grav * dt
		if S.drag > 0.0:
			P.v *= exp(-S.drag * dt)
		P.p += P.v * dt
		var seg := P.p - P.prev
		var dist := maxf(seg.length(), 1e-6)
		var dir := seg / dist
		var done := false
		# 1) bersagli: sfera contro cilindro su 4 campioni del segmento. Il Karma
		# si allarga man mano che perde coerenza: r0·(1 + scatter·(1 − coh)).
		var rr := S.r + S.wide * 0.5
		if S.el == "karma":
			rr = S.r * (1.0 + S.scatter * (1.0 - exp(-S.decoh * P.t)))
		for o in targets:
			var tg := o as CombatTarget
			if tg == null or not tg.alive or P.hits.has(tg):
				continue
			var hit := false
			var at := P.p
			for k in 4:
				var q := P.prev + seg * (k / 3.0)
				if Vector2(q.x - tg.position.x, q.z - tg.position.z).length() < tg.radius + rr \
						and q.y > tg.position.y - rr and q.y < tg.position.y + tg.height + rr:
					hit = true
					at = q
					break
			if not hit:
				continue
			P.hits[tg] = true
			P.p = at
			_hit_target(P, tg)
			if not (S.el == "air" and S.is_legacy()):
				_impact(P, P.p, -dir, {"kind": "target"})
				done = true
				break
		if done:
			_end_dart(i)
			i -= 1
			continue
		# 2) voxel lungo il segmento.
		if world != null:
			var h := VoxelQuery.raycast(world, opaque, P.prev, dir, dist + S.r)
			if h != null:
				var q := P.prev + dir * maxf(0.0, h.distance - S.r * 0.5)
				var n := Vector3(h.normal)
				if S.is_legacy() and S.el == "earth" and P.bounces < 1 and not SOFT.has(h.id) and P.v.length() > 5.0:
					P.bounces += 1
					var vn := P.v.dot(n)
					P.v = (P.v - 2.0 * vn * n) * 0.45
					P.p = q
					events.append({"type": "burst", "el": "earth", "p": q, "n": n, "k": 0.5})
					i -= 1
					continue
				P.p = q
				_impact(P, q, n, {"kind": "block", "cell": h.cell, "id": h.id})
				_end_dart(i)
				i -= 1
				continue
		# 3) tronchi.
		var tree := _tree_at(P.p, S.r)
		if tree != null:
			var e := Vector3(P.p.x - tree.x, 0, P.p.z - tree.z)
			var el := Vector2(e.x, e.z).normalized() if e.length() > 1e-4 else Vector2(0, 1)
			events.append({"type": "shake_tree", "tree": tree, "dir": -el, "k": 1.0})
			_impact(P, P.p, e.normalized() if e.length() > 1e-4 else Vector3.UP, {"kind": "tree"})
			_end_dart(i)
			i -= 1
			continue
		# 4) aria: vento lungo il passaggio, braci soffiate.
		if S.el == "air" and S.is_legacy():
			wind = {"x": P.p.x, "z": P.p.z, "dx": dir.x, "dz": dir.z, "t": 0.7, "pow": 0.30, "r": 1.7}
			if P.acc > 0:
				P.acc -= 1
			else:
				P.acc = 2
				_blow_fire(P.p, 1.4, Vector2(dir.x, dir.z))
				_shake_near(P.p, Vector2(dir.x, dir.z))
		# 5) proiettili elementali: arrivati alla mira si fermano li' (RMNDWN
		# risolve il colpo nel punto mirato all'istante del contatto).
		if P.reach < INF and P.origin.distance_to(P.p) >= P.reach:
			var dd := P.origin.direction_to(P.p)
			P.p = P.origin + dd * P.reach
			_impact(P, P.p, -dd, {"kind": "aim"})
			_end_dart(i)
			i -= 1
			continue
		var outside := world != null and not world.inside(floori(P.p.x), floori(P.p.y), floori(P.p.z)) and P.p.y >= 0.0
		if P.t >= S.life or outside or (world != null and P.p.y < 0.0):
			if S.el == "karma":
				# A fine portata il Karma svanisce: niente impatto ne' scoppio.
				events.append({"type": "karma_fade", "p": P.p, "spell": S})
			elif S.burst_r > 0.0 or S.kind == "meteor" or S.area > 0.0:
				_impact(P, P.p, Vector3.UP, {"kind": "air"})
			elif S.el == "fire" or S.el == "air":
				events.append({"type": "burst", "el": S.el, "p": P.p, "n": dir, "k": 0.45})
			else:
				_impact(P, P.p, Vector3.UP, {"kind": "air"})
			_end_dart(i)
		i -= 1


## Punto trattenuto di un costrutto: `loc` = (destra, su, avanti) dai piedi del
## caster, ZERO = davanti alla mano.
func _held_point(loc: Vector3, hand: Vector3) -> Vector3:
	var f := _fwd(face)
	if loc == Vector3.ZERO:
		return hand + f * 0.45 + Vector3(0, 0.22, 0)
	var right := Vector3(-f.z, 0, f.x)
	return _player_pos + right * loc.x + Vector3(0, loc.y, 0) + f * loc.z


## Fine di un dardo: i raggi del Karma restano ancora un poco per spegnersi
## verso il punto d'arrivo (fade .30 s di Zoltraak), il resto sparisce.
func _end_dart(i: int) -> void:
	var P := darts[i]
	if P.spell.el == "karma" and P.spell.kind != "orb":
		P.fade = 0.30
		P.fade_life = 0.30
	else:
		darts.remove_at(i)


## La spina d'aria scuote gli alberi entro 1,8 dal suo passaggio.
func _shake_near(p: Vector3, d: Vector2) -> void:
	var cx := int(p.x / 8.0)
	var cz := int(p.z / 8.0)
	for gz in range(cz - 1, cz + 2):
		for gx in range(cx - 1, cx + 2):
			for ts: Vegetation.TreeSpot in tree_grid.get(Vector2i(gx, gz), []):
				if not ts.dead and Vector2(ts.x - p.x, ts.z - p.z).length() < 1.8:
					events.append({"type": "shake_tree", "tree": ts, "dir": d.normalized(), "k": 0.5})


func _tree_at(p: Vector3, r: float) -> Vegetation.TreeSpot:
	if tree_grid.is_empty():
		return null
	var cx := int(p.x / 8.0)
	var cz := int(p.z / 8.0)
	for gz in range(cz - 1, cz + 2):
		for gx in range(cx - 1, cx + 2):
			for ts: Vegetation.TreeSpot in tree_grid.get(Vector2i(gx, gz), []):
				if ts.dead:
					continue
				var rr := 0.30 * ts.scale + r
				if Vector2(p.x - ts.x, p.z - ts.z).length() < rr and p.y > ts.y and p.y < ts.y + 4.0 * ts.scale * 0.78:
					return ts
	return null


func _hit_target(P: Dart, tg: CombatTarget) -> void:
	var S := P.spell
	var hv := Vector2(P.v.x, P.v.z)
	var d := hv.normalized() if hv.length() > 1e-4 else Vector2(0, -1)
	P.k = coherence(S, P.t)
	if S.is_legacy() or S.area <= 0.0:
		spell_hit(tg, S, S.dmg * P.k, d, P.p, 1.0, -1.0, false, S.stagger * P.k, P.k)


## Spinta dei nuovi incantesimi: il knockback di RMNDWN in m/s (×2,4, perche' il
## manichino ha l'attrito del prototipo).
const KNOCK_SCALE := 2.4
## Grammatica d'impatto per elemento (IMPACT_GRAMMAR, RMNDWN L18502):
## [scossa, hitstop, durata, frequenza, campo visivo].
const GRAMMAR := {"fire": [0.78, 0.55, 0.70, 1.75, 0.95], "water": [1.05, 1.0, 1.0, 0.95, 1.0], "air": [0.55, 0.45, 0.85, 1.15, 1.15],
	"earth": [1.4, 1.35, 1.55, 0.60, 0.80], "karma": [1.0, 1.0, 0.90, 1.30, 1.20]}
## Famiglie d'impatto (HITFAM L18462): hitstop, scossa, suono e refrattario
## (in quella finestra niente hitstop, scossa, lampo ne' suono).
const FAMILY := {"spell": {"stop": 0.30, "shake": 0.55, "sfx": 0.85, "refr": 0.16},
	"sustain": {"stop": 0.0, "shake": 0.32, "sfx": 0.55, "refr": 0.22}}
## Materiale della forza (ELEMENT_FORCE_MATERIAL): l'aria ferma meno.
const FORCE_STOP := {"air": 0.45}
var _refr := {"spell": 0.0, "sustain": 0.0}


## Vicinanza al giocatore (0,18..1): scossa e suono calano con la distanza.
func near_k(p: Vector3) -> float:
	return clampf(1.0 - (_player_pos.distance_to(p) - 4.5) / (14.0 - 4.5), 0.18, 1.0)


## Stati dati dal colpo (statusFromHit, RMNDWN L21619).
static func statuses_from(S: SpellDefinition, knock: float) -> Array[String]:
	var out: Array[String] = []
	if S.status != "" and S.status != "flow":
		out.append(S.status)
	if (S.el == "air" or S.el == "water") and absf(knock) >= 0.6 and not out.has("pushed"):
		out.append("pushed")
	return out


## Colpo di una magia su un bersaglio (applyCombatHit + elementResolveHit):
## reazioni, danno, stagger, spinta, stati, hitstop e scossa col refrattario.
## `k` = coerenza del Karma (1 per gli elementi); `quiet` = colpo sostenuto.
func spell_hit(tg: CombatTarget, S: SpellDefinition, base: float, dir: Vector2, p: Vector3, knock_mul: float = 1.0, lift: float = -1.0,
		quiet: bool = false, stag: float = -1.0, k: float = 1.0) -> void:
	if tg == player:
		return
	# Le magie di difesa non feriscono mai (role 'difesa', RMNDWN L20835).
	if S.role == "difesa":
		return
	var mul := status_react(tg, S.el)
	var crit := rng.randf() < 0.10 and base > 0.0
	var amount := base * rng.randf_range(0.9, 1.1) * (1.5 if crit else 1.0) * mul * power
	var knock := S.knock * (1.0 if S.is_legacy() else KNOCK_SCALE * (1.12 if S.heavy else 1.0)) * knock_mul
	var st := (S.stagger if stag < 0.0 else stag)
	# Conduzione (RMNDWN statusConduct): il Karma sul bagnato fa vacillare ×1,8
	# e meta' del danno salta sugli altri corpi bagnati entro 3 unita'.
	if S.el == "karma" and has_status(tg, "wet"):
		st *= 1.8
		events.append({"type": "conduct", "p": tg.position + Vector3(0, tg.height * 0.6, 0)})
		var arcs := 0
		for o in _targets_cache:
			var other := o as CombatTarget
			if other == null or other == tg or not other.alive or not has_status(other, "wet"):
				continue
			if other.position.distance_to(tg.position) <= 3.0 and amount > 0.0:
				other.take_hit(Vector3.ZERO, amount * 0.5)
				arcs += 1
				events.append({"type": "arc", "from": tg.position + Vector3(0, tg.height * 0.6, 0), "to": other.position + Vector3(0, other.height * 0.6, 0)})
		if arcs > 0:
			events.append({"type": "text", "p": tg.position + Vector3(0, tg.height + 0.5, 0), "text": "CONDUZIONE"})
	# Il knockback di RMNDWN e' orizzontale; i dardi del prototipo sollevano.
	var up := lift if lift >= 0.0 else (1.2 if S.is_legacy() else 0.0)
	if base > 0.0 or knock != 0.0:
		tg.take_hit(Vector3(dir.x * knock, up, dir.y * knock), maxf(amount, 1.0 if mul > 0.0 and base > 0.0 else 0.0))
	if st > 0.0 and mul > 0.0:
		tg.stagger(st, dir)
	if mul > 0.0:
		for n in statuses_from(S, knock / (KNOCK_SCALE if not S.is_legacy() else 1.0)):
			apply_status(tg, n)
	# Ventaglio (RMNDWN statusReact): l'aria su chi brucia aggiunge una pila
	# (col suo intervallo) e accende i corpi entro 3,2 unita', giocatore compreso.
	if S.el == "air" and has_status(tg, "burn"):
		apply_status(tg, "burn")
		var near_bodies: Array = []
		near_bodies.append_array(_targets_cache)
		near_bodies.append(player)
		for o in near_bodies:
			var other := o as CombatTarget
			if other != null and other != tg and other.alive and other.position.distance_to(tg.position) <= 3.2:
				apply_status(other, "burn")
		events.append({"type": "text", "p": tg.position + Vector3(0, tg.height + 0.5, 0), "text": "VENTAGLIO"})
		events.append({"type": "fan_ring", "p": tg.position + Vector3(0, tg.height * 0.5, 0)})
	if S.el == "air":
		wind = {"x": tg.position.x, "z": tg.position.z, "dx": dir.x, "dz": dir.y, "t": 0.6, "pow": 0.35, "r": 1.8}
	# Famiglia e refrattario: solo il primo colpo della finestra fa hitstop,
	# scossa e suono (il lampo sul bersaglio c'e' sempre).
	var fam := "sustain" if quiet else "spell"
	var F: Dictionary = FAMILY[fam]
	var juice := float(_refr[fam]) <= 0.0
	if juice:
		_refr[fam] = F["refr"]
	var g: Array = GRAMMAR.get(S.el, GRAMMAR["karma"])
	var near := near_k(p)
	if juice and not S.is_legacy():
		hitstop = maxf(hitstop, S.hit_stop * float(F["stop"]) * float(FORCE_STOP.get(S.el, 1.0)) * float(g[1]) * (0.35 + 0.65 * k))
	elif juice:
		hitstop = maxf(hitstop, 0.03 * float(g[1]))
	if base > 0.0 and not quiet and not S.is_legacy():
		recoil(S)
	events.append({"type": "hit", "el": S.el, "p": p, "target": tg, "damage": amount, "crit": crit, "quiet": quiet, "juice": juice,
		"heavy": S.heavy, "dir": dir, "near": near, "sfx": S.sfx, "spell": S,
		"shake": S.shake * float(F["shake"]) * near * float(g[0]) if juice else 0.0})


func _impact(P: Dart, p: Vector3, n: Vector3, info: Dictionary) -> void:
	var S := P.spell
	var el := S.el
	events.append({"type": "impact", "el": el, "p": p, "n": n, "spell": S, "dart": P})
	if not S.is_legacy():
		_impact_new(P, p, n, info)
		return
	# Area: stato e danno ridotto sugli altri bersagli vicini.
	for o in _targets_cache:
		var tg := o as CombatTarget
		if tg == null or not tg.alive or P.hits.has(tg):
			continue
		var dd := Vector2(tg.position.x - p.x, tg.position.z - p.z)
		if dd.length() > S.area + tg.radius:
			continue
		P.hits[tg] = true
		var mul := status_react(tg, el)
		var dn := dd.normalized() if dd.length() > 1e-4 else Vector2.ZERO
		tg.take_hit(Vector3(dn.x, 0.4, dn.y) * S.knock * 0.6, maxf(1.0, S.dmg * 0.35 * mul * power))
		if mul > 0.0 and S.status != "":
			apply_status(tg, S.status)
	if world == null:
		return
	if info.get("kind") == "tree":
		if el == "fire":
			ignite_around(p, 1)
		return
	var cell: Vector3i = info.get("cell", Vector3i(floori(p.x), floori(p.y), floori(p.z)))
	match el:
		"fire":
			if info.get("kind") == "block" and FLAM.has(int(info.get("id", 0))):
				ignite(cell, true, 0)
			ignite_around(p, 1)
		"water":
			wet_around(p, 1)
			_lava_quench(cell)
		"earth":
			if info.get("kind") == "block" and SOFT.has(int(info.get("id", 0))) and P.v.length() > 4.0:
				_crater(cell, int(info["id"]))
			else:
				events.append({"type": "burst", "el": "earth", "p": p, "n": n, "k": 0.5})
		_:
			wind = {"x": p.x, "z": p.z, "dx": -n.x, "dz": -n.z, "t": 0.5, "pow": 0.4, "r": 2.0}
			_blow_fire(p, 1.6, Vector2(P.v.x, P.v.z))


## Impatto dei nuovi dardi. Karma: la sfera scoppia (burst × coerenza) sui
## corpi vicini non ancora colpiti. Elementi con area (palla, meteorite):
## tutti i corpi nella sfera `area` prendono il danno pieno (elementResolveHit).
func _impact_new(P: Dart, p: Vector3, n: Vector3, info: Dictionary) -> void:
	var S := P.spell
	if S.el == "karma" and info.get("kind") != "target":
		recoil(S)
	if S.el == "karma" and S.burst_r > 0.0:
		var k := coherence(S, P.t)
		for o in _targets_cache:
			var tg := o as CombatTarget
			if tg == null or not tg.alive or P.hits.has(tg):
				continue
			if not runtime.in_sphere(tg, p, S.burst_r):
				continue
			P.hits[tg] = true
			var dd := Vector2(tg.position.x - p.x, tg.position.z - p.z)
			spell_hit(tg, S, S.burst_dmg * k, dd.normalized() if dd.length() > 1e-3 else Vector2(0, -1), tg.position,
				S.burst_knock / maxf(S.knock, 1e-3), -1.0, false, S.burst_stag * k, k)
		events.append({"type": "burst_ring", "el": S.el, "p": p, "r": S.burst_r})
	elif S.el != "karma" and S.area > 0.0:
		for o in _targets_cache:
			var tg := o as CombatTarget
			if tg == null or not tg.alive or not runtime.in_sphere(tg, p, S.area):
				continue
			P.hits[tg] = true
			var dd := Vector2(tg.position.x - P.origin.x, tg.position.z - P.origin.z)
			spell_hit(tg, S, S.dmg, dd.normalized() if dd.length() > 1e-3 else Vector2(0, -1), tg.position + Vector3(0, tg.height * 0.5, 0))
		events.append({"type": "burst_ring", "el": S.el, "p": p, "r": S.area})
	if world == null or info.get("kind") == "tree":
		return
	runtime.world_touch(S, p, maxf(S.burst_r, S.area))


# ---------------------------------------------------------------- posa

## Braccio teso (KARMAP): sale in .34 della raccolta, resta finche' qualcosa del
## lancio vive (raccolta, recupero, salva, colpi in volo, effetti sostenuti),
## poi tiene ancora .44 s (Karma .62 s) e scende in .34 s. (Il glifo di
## RMNDWN e' stato tolto in D-032: la sostanza si accumula nel palmo.)
const ARM_UP := 0.34
const ARM_LOWER := 0.34
const ARM_KEEP := 0.16
var arm_w := 0.0
var cast_commit := 0.0
## Magia della posa (resta anche dopo il recupero finche' il braccio scende).
var cast_spell: SpellDefinition
var _idle_t := 99.0
## Rinculi attivi: {t, n, atk, dec, pose}.
var recoils: Array[Dictionary] = []


static func smoother5(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * x * (x * (x * 6.0 - 15.0) + 10.0)


## Qualcosa del lancio e' ancora vivo (colpi del libro in volo, effetti prima
## del contatto o mentre emettono).
func _cast_alive() -> bool:
	if phase != Phase.NONE or not _pending.is_empty():
		return true
	for d in darts:
		if not d.spell.is_legacy() and d.fade <= 0.0:
			return true
	for e in runtime.effects:
		if e.t < maxf(e.hit_at, e.spell.emit):
			return true
	return false


func _step_pose(dt: float, s: SpellDefinition) -> void:
	if phase == Phase.GATHER:
		var dur := s.cast_dur * gather_mul()
		cast_spell = s
		arm_w = maxf(arm_w, smoother5(t / maxf(1e-3, dur * ARM_UP)))
		cast_commit = smoother5((w - 0.78) / 0.22)
	if _cast_alive():
		_idle_t = 0.0
		if phase != Phase.GATHER:
			arm_w = 1.0
	else:
		_idle_t += dt
		var keep := ARM_KEEP + (0.46 if cast_spell != null and cast_spell.el == "karma" else 0.28)
		var down := clampf((_idle_t - keep) / ARM_LOWER, 0.0, 1.0)
		arm_w = minf(arm_w, 1.0 - down)
		if arm_w <= 0.0:
			cast_commit = 0.0
	var i := recoils.size() - 1
	while i >= 0:
		var r := recoils[i]
		r["t"] = float(r["t"]) + dt
		if float(r["t"]) >= float(r["atk"]) + float(r["dec"]):
			recoils.remove_at(i)
		i -= 1


## Rinculo quando il colpo arriva (karmaRecoil L30948): i colpi entro l'attacco
## si sommano fino a 3 (×(1 + .35(n − 1))).
func recoil(S: SpellDefinition) -> void:
	for r in recoils:
		if float(r["t"]) < float(r["atk"]):
			r["n"] = mini(3, int(r["n"]) + 1)
			return
	recoils.append({"t": 0.0, "n": 1, "atk": S.recoil_atk, "dec": S.recoil_dec, "pose": S.recoil_pose})


## Somma dei rinculi in corso: {upper, lower, spine_y, spine_x, head_y}.
func recoil_pose() -> Dictionary:
	var out := {}
	for r in recoils:
		var t := float(r["t"])
		var atk := float(r["atk"])
		var env := smoother5(t / atk) if t < atk else 1.0 - smoother5((t - atk) / float(r["dec"]))
		env *= 1.0 + 0.35 * (int(r["n"]) - 1)
		var pose: Dictionary = r["pose"]
		for k: String in pose:
			out[k] = float(out.get(k, 0.0)) + float(pose[k]) * env
	return out


var _targets_cache: Array = []
var _player_pos := Vector3.ZERO


func _crater(cell: Vector3i, id: int) -> void:
	# Mai sotto i piedi del giocatore.
	var hw := PlayerMotor.RADIUS
	if cell.x + 1 > _player_pos.x - hw and cell.x < _player_pos.x + hw and cell.z + 1 > _player_pos.z - hw \
			and cell.z < _player_pos.z + hw and cell.y >= floori(_player_pos.y) - 1:
		return
	if edits != null:
		var r := edits.set_block(cell, BlockCatalog.AIR, &"crater")
		if not r.ok():
			return
	crater_items += 1
	events.append({"type": "crater", "p": Vector3(cell) + Vector3(0.5, 1.0, 0.5), "id": id})
	events.append({"type": "text", "p": Vector3(cell) + Vector3(0.5, 1.4, 0.5), "text": "CRATERE"})


func _lava_quench(c: Vector3i) -> void:
	var list: Array[WorldEditService.Edit] = []
	for dy in range(-1, 2):
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var q := c + Vector3i(dx, dy, dz)
				if world.inside(q.x, q.y, q.z) and world.get_block(q) == BlockCatalog.LAVA:
					list.append(WorldEditService.Edit.new(q, BlockCatalog.DARKSTONE))
					events.append({"type": "steam", "p": Vector3(q) + Vector3(0.5, 1.1, 0.5), "n": 8})
	if not list.is_empty() and edits != null:
		edits.try_apply(list, &"lava_quench")


# ---------------------------------------------------------------- fuoco e bagnato

## Cella solida in superficie sotto (px, pz) (surfaceCell del prototipo).
func surface_cell(px: float, pz: float, y_ref: float) -> Vector3i:
	var x := floori(px)
	var z := floori(pz)
	var gy := VoxelQuery.field_height(world, x + 0.5, z + 0.5, y_ref)
	return Vector3i(x, maxi(0, int(gy) - 1), z)


func ignite(c: Vector3i, force: bool, gen: int) -> bool:
	if world == null or not world.inside(c.x, c.y, c.z):
		return false
	var id := world.get_block(c)
	if not FLAM.has(id):
		return false
	if fire.has(c) or wet.has(c):
		return false
	if fire.size() >= FIRE_MAX and not force:
		return false
	var f := FireCell.new()
	f.cell = c
	f.id = id
	f.life = float(BURN_LIFE[id]) * rng.randf_range(0.8, 1.2)
	f.gen = gen
	fire[c] = f
	return true


func ignite_around(p: Vector3, r: int) -> void:
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dz * dz > r * r:
				continue
			var c := surface_cell(p.x + dx, p.z + dz, p.y + 1.0)
			var center := dx == 0 and dz == 0
			if rng.randf() < (0.9 if center else 0.5):
				ignite(c, false, 0 if center else 1)


func wet_around(p: Vector3, r: int) -> void:
	var ext := 0
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dz * dz > r * r:
				continue
			var c := surface_cell(p.x + dx, p.z + dz, p.y + 1.0)
			wet[c] = 45.0
			for dy in range(-1, 3):
				var k := c + Vector3i(0, dy, 0)
				if fire.has(k):
					fire.erase(k)
					events.append({"type": "steam", "p": Vector3(k) + Vector3(0.5, 1.05, 0.5), "n": 6})
					ext += 1
	events.append({"type": "puddle", "p": p, "r": float(r) + 0.6})
	if ext > 0:
		events.append({"type": "text", "p": p + Vector3(0, 0.6, 0), "text": "SPENTO"})


func _blow_fire(p: Vector3, r: float, dir_xz: Vector2) -> void:
	var d := dir_xz.normalized() if dir_xz.length() > 1e-4 else Vector2(1, 0)
	for c: Vector3i in fire.keys():
		var f: FireCell = fire[c]
		if Vector2(c.x + 0.5 - p.x, c.z + 0.5 - p.z).length() > r:
			continue
		if f.id == BlockCatalog.GRASS and rng.randf() < 0.55:
			fire.erase(c)
			events.append({"type": "smoke", "p": Vector3(c) + Vector3(0.5, 1.05, 0.5), "dir": d})
		else:
			f.life += 0.6
			events.append({"type": "embers", "p": Vector3(c) + Vector3(0.5, 1.05, 0.5), "dir": d})
			var nc := c + Vector3i(roundi(d.x), 0, roundi(d.y))
			for dy in range(-1, 2):
				if rng.randf() < 0.35 and ignite(nc + Vector3i(0, dy, 0), false, maxi(0, f.gen - 1)):
					break


func _step_fire(dt: float, _motor: PlayerMotor, targets: Array) -> void:
	if world == null:
		return
	for c: Vector3i in wet.keys():
		var nt: float = float(wet[c]) - dt * (1.0 + daylight * 1.5)
		if nt <= 0.0:
			wet.erase(c)
		else:
			wet[c] = nt
	# Chi sta nel fuoco brucia.
	for o in targets:
		var tg := o as CombatTarget
		if tg == null or not tg.alive:
			continue
		var b := Vector3i(floori(tg.position.x), floori(tg.position.y), floori(tg.position.z))
		for dy in range(-1, 2):
			if fire.has(b + Vector3i(0, dy, 0)):
				apply_status(tg, "burn")
				break
	_fire_tick += dt
	if _fire_tick >= 0.25:
		_fire_tick -= 0.25
		var wd: Dictionary = wind if not wind.is_empty() and float(wind["t"]) > 0.0 else {}
		for c: Vector3i in fire.keys():
			if not fire.has(c):
				continue
			var f: FireCell = fire[c]
			f.t += 0.25
			if world.get_block(c) != f.id:
				fire.erase(c)
				continue
			if f.t >= f.life:
				fire.erase(c)
				_fire_edits.append(WorldEditService.Edit.new(c, BURN_TO[f.id]))
				events.append({"type": "ash", "p": Vector3(c) + Vector3(0.5, 1.02, 0.5)})
				continue
			if fire.size() >= FIRE_MAX:
				continue
			var max_kids := 2 if f.id == BlockCatalog.GRASS else 3
			if f.kids >= max_kids:
				continue
			var decay := pow(0.78 if f.id == BlockCatalog.GRASS else 0.88, f.gen)
			var nb: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			if f.id != BlockCatalog.GRASS:
				nb.append_array([Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)] as Array[Vector2i])
			for d in nb:
				if f.kids >= max_kids:
					break
				var bias := 0.0
				if not wd.is_empty():
					bias = maxf(0.0, (d.x * float(wd["dx"]) + d.y * float(wd["dz"])) / Vector2(d).length()) * 2.5
				for dy in range(-1, 2):
					var q := c + Vector3i(d.x, dy, d.y)
					if not world.inside(q.x, q.y, q.z):
						continue
					var id := world.get_block(q)
					if not FLAM.has(id):
						continue
					if rng.randf() < float(FLAM[id]) * 0.13 * decay * (1.0 + bias) * (1.3 if f.id == BlockCatalog.WOOD else 1.0):
						if ignite(q, false, f.gen + 1):
							f.kids += 1
					break
			if f.id == BlockCatalog.WOOD:
				for dy in [1, -1]:
					var q := c + Vector3i(0, dy, 0)
					if world.inside(q.x, q.y, q.z) and FLAM.has(world.get_block(q)) and rng.randf() < 0.14 * decay:
						if ignite(q, false, f.gen + 1):
							f.kids += 1
	_flush_t += dt
	if not _fire_edits.is_empty() and (_flush_t >= 0.4 or _fire_edits.size() >= 14):
		if edits != null:
			edits.try_apply(_fire_edits, &"fire")
		else:
			for e in _fire_edits:
				world.blocks[world.index(e.cell.x, e.cell.y, e.cell.z)] = e.id
		_fire_edits = []
		_flush_t = 0.0
	if not wind.is_empty():
		wind["t"] = float(wind["t"]) - dt
		if float(wind["t"]) <= 0.0:
			wind = {}


# ---------------------------------------------------------------- stati

func has_status(tg: CombatTarget, n: String) -> bool:
	return statuses.has(tg) and (statuses[tg] as Dictionary).has(n)


func apply_status(tg: CombatTarget, n: String, force_stack: bool = false) -> void:
	if not statuses.has(tg):
		statuses[tg] = {}
	var s: Dictionary = statuses[tg]
	var D: Dictionary = STDEF[n]
	if n == "burn":
		if s.has("burn"):
			var cur: Dictionary = s["burn"]
			cur["t"] = D["dur"]
			if (force_stack or float(cur["since"]) >= float(D["gap"])) and int(cur["st"]) < int(D["max"]):
				cur["st"] = int(cur["st"]) + 1
				cur["since"] = 0.0
		else:
			s["burn"] = {"t": D["dur"], "st": 1, "tick": 0.0, "since": 0.0}
			events.append({"type": "text", "p": tg.position + Vector3(0, tg.height + 0.3, 0), "text": D["tag"]})
	else:
		if not s.has(n) and n != "mud":
			events.append({"type": "text", "p": tg.position + Vector3(0, tg.height + 0.3, 0), "text": D["tag"]})
		var keep: float = float((s.get(n, {}) as Dictionary).get("t", 0.0))
		s[n] = {"t": maxf(keep, float(D["dur"]))}


## Moltiplicatore della camminata del giocatore dagli stati (lento × spinto ×
## flusso × fango, RMNDWN 21652).
func player_speed() -> float:
	var k := 1.0
	for n in ["slow", "pushed", "flow", "mud"]:
		if has_status(player, n):
			k *= float(STDEF[n]["mag"])
	return k


## L'unico punto in cui un elemento sa dell'altro: moltiplicatore del danno
## (vapore = 0; lo shock termico toglie il fuoco con danno a parte).
func status_react(tg: CombatTarget, el: String) -> float:
	if not statuses.has(tg):
		return 1.0
	var s: Dictionary = statuses[tg]
	var head := tg.position + Vector3(0, tg.height * 0.6, 0)
	if el == "fire" and s.has("wet"):
		s.erase("wet")
		events.append({"type": "steam", "p": head, "n": 10})
		events.append({"type": "text", "p": head + Vector3(0, 0.7, 0), "text": "VAPORE"})
		return 0.0
	if el == "water" and s.has("burn"):
		# Shock termico: il fuoco si spegne con 4 × pile di danno silenzioso.
		var stacks := int(s["burn"]["st"])
		s.erase("burn")
		tg.take_hit(Vector3.ZERO, 4.0 * stacks)
		events.append({"type": "steam", "p": head, "n": 12})
		events.append({"type": "text", "p": head + Vector3(0, 0.7, 0), "text": "SHOCK TERMICO"})
		return 1.0
	return 1.0


func _step_status(dt: float) -> void:
	for tg: CombatTarget in statuses.keys():
		var s: Dictionary = statuses[tg]
		if not tg.alive:
			statuses.erase(tg)
			continue
		for n: String in s.keys():
			var st: Dictionary = s[n]
			var D: Dictionary = STDEF[n]
			st["t"] = float(st["t"]) - dt
			if n == "burn":
				st["since"] = float(st["since"]) + dt
				st["tick"] = float(st["tick"]) + dt
				if float(st["tick"]) >= float(D["tick"]):
					st["tick"] = float(st["tick"]) - float(D["tick"])
					var burn := float(D["dps"]) * float(D["tick"]) * int(st["st"])
					tg.take_hit(Vector3.ZERO, burn)
					# La bruciatura e' un colpo continuo anche lei: numero ed ember.
					if tg != player:
						events.append({"type": "dot", "el": "fire", "target": tg, "damage": burn, "p": tg.position + Vector3(0, tg.height * 0.7, 0)})
			if float(st["t"]) <= 0.0:
				s.erase(n)
		if s.is_empty():
			statuses.erase(tg)


## Etichetta degli stati di un bersaglio (per il riquadro di stato).
func status_tag(tg: CombatTarget) -> String:
	if not statuses.has(tg):
		return ""
	var tags: Array[String] = []
	for n: String in statuses[tg]:
		var st: Dictionary = statuses[tg][n]
		tags.append(String(STDEF[n]["tag"]) + ("×%d" % int(st["st"]) if n == "burn" and int(st["st"]) > 1 else ""))
	return " ".join(tags)
