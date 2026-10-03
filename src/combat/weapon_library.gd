class_name WeaponLibrary
extends RefCounted
## Le cinque armi del giocatore (M4). Movimenti, tempi e catene sono un
## disegno nuovo (D-022), non quelli del prototipo:
##
## - Pugni: jab, diretto, gancio, montante (lancia in aria); forte = pugno a razzo.
## - Spada: fendente, rovescio, calata con affondo, giro finale; forte = fendente
##   dall'alto a due mani, piedi a terra (D-033: prima era un balzo in aria);
##   L+forte = montante che lancia; L L+forte = stoccata in corsa.
##
## D-033: ogni arma ha la sua distanza vera di contatto (`strike_dist`, misurata
## con le hitbox del rig) e i colpi di catena spingono poco il bersaglio, cosi'
## resta a portata; spinge forte solo il colpo finale della catena.
## - Lancia (D-034, ritmo veloce e a distanza): due stoccate secche perforanti,
##   spazzata bassa, infilzata finale che trapassa la fila per 1,6 m; forte =
##   affondo in carica lungo 6 unita' che trapassa per 2,2 m; L+forte = mulinello.
## - Martello (D-034, lento: carica e rientro x1,35): laterale, montante,
##   schianto ad area; forte = terremoto caricato.
## - Spadone (D-034, lento: x1,3): tagli larghi avanti e indietro, calata;
##   forte = turbine (due giri con colpi ripetuti).
##
## D-034: ogni colpo indica il piede che fa il passo (`step_foot`), l'IK delle
## gambe lo porta davanti mentre l'altro resta piantato.
##
## Ogni arma ha anche un attacco dopo la schivata e uno in picchiata dall'aria.
## Pose in gradi: [x, y, z] per osso (vedi `AvatarRig` per gli assi).

static var _cache: Array[WeaponDefinition] = []


static func all() -> Array[WeaponDefinition]:
	if _cache.is_empty():
		_cache = [_fists(), _sword(), _spear(), _hammer(), _greatsword(), _staff(), _tool()]
		for w in _cache:
			if w.id != &"tool":
				# Spadone e martello erano gia' lenti (D-034): meta' dell'effetto.
				_pace(w, 0.4 if w.id in [&"hammer", &"greatsword"] else 1.0)
			if w.id in [&"hammer", &"greatsword"]:
				_weight(w)
	return _cache


static func by_id(id: StringName) -> WeaponDefinition:
	for w in all():
		if w.id == id:
			return w
	return all()[1]


## Dizionario di gradi -> dizionario di Vector3 in radianti.
static func pose(d: Dictionary) -> Dictionary:
	var out := {}
	for k: String in d:
		var a: Array = d[k]
		if k == "body_pos":
			out[StringName(k)] = Vector3(a[0], a[1], a[2])
		else:
			out[StringName(k)] = Vector3(deg_to_rad(a[0]), deg_to_rad(a[1]), deg_to_rad(a[2]))
	return out


static func _atk(w: WeaponDefinition, id: String, props: Dictionary, wind: Dictionary, strike: Dictionary, follow: Dictionary) -> AttackDefinition:
	var a := AttackDefinition.new()
	a.id = StringName(id)
	for k: String in props:
		var v: Variant = props[k]
		if k in ["next_light", "next_heavy"]:
			v = StringName(v)
		a.set(k, v)
	a.key_wind = pose(wind)
	a.key_strike = pose(strike)
	a.key_follow = pose(follow)
	w.attacks[a.id] = a
	return a


# Pose ricorrenti delle gambe.
const STANCE := {"leg_l": [22, 0, 0], "shin_l": [-14, 0, 0], "leg_r": [-16, 0, 0], "shin_r": [-20, 0, 0]}
const LUNGE := {"leg_l": [48, 0, 0], "shin_l": [-40, 0, 0], "leg_r": [-34, 0, 0], "shin_r": [-8, 0, 0], "body_pos": [0, -0.1, 0]}
const TUCK := {"leg_l": [70, 0, 0], "shin_l": [-100, 0, 0], "leg_r": [55, 0, 0], "shin_r": [-95, 0, 0]}
const SQUAT := {"leg_l": [55, 0, -6], "shin_l": [-70, 0, 0], "leg_r": [40, 0, 6], "shin_r": [-60, 0, 0], "body_pos": [0, -0.16, 0], "hips": [-10, 0, 0]}


## Armi pesanti (D-034): carica e rientro piu' lunghi di `k`, arresto sul
## colpo piu' marcato, quasi fermi mentre si colpisce. Le picchiate no (sono
## gia' legate all'atterraggio) e gli attacchi in corsa partono comunque subito.
static func _tempo(w: WeaponDefinition, k: float) -> void:
	for a: AttackDefinition in w.attacks.values():
		if a.plunge:
			continue
		if not String(a.id).begins_with("dash_"):
			a.windup *= k
		a.recovery *= k
		# I giri tengono la loro velocita' (i colpi ripetuti restano a portata).
		if a.spin == 0.0:
			a.active *= 1.0 + (k - 1.0) * 0.4
		# Arresto piu' marcato, ma non sui colpi ripetuti del turbine.
		if a.rehit <= 0.0:
			a.hitstop *= 1.25
		a.move_scale *= 0.5


## Ritmo generale (D-040): i colpi erano troppo frenetici. Carica e rientro
## piu' lunghi per tutte le armi, e il colpo seguente della catena parte piu'
## tardi nel rientro, cosi' ogni colpo si legge. Le proporzioni fra le armi
## (pugni veloci, spadone e martello lenti) restano quelle di D-034.
const PACE_WINDUP := 1.25
const PACE_ACTIVE := 1.1
const PACE_RECOVERY := 1.3
const PACE_CHAIN_MIN := 0.35

static func _pace(w: WeaponDefinition, s: float) -> void:
	for a: AttackDefinition in w.attacks.values():
		# Picchiate (legate all'atterraggio) e giri (gia' lunghi) restano come sono.
		if a.plunge or a.spin != 0.0:
			continue
		a.windup *= lerpf(1.0, PACE_WINDUP, s)
		if a.rehit <= 0.0:
			a.active *= lerpf(1.0, PACE_ACTIVE, s)
		a.recovery *= lerpf(1.0, PACE_RECOVERY, s)
		a.chain_at = maxf(a.chain_at, PACE_CHAIN_MIN * s)


## Peso di spadone e martello (D-042): carica piu' lunga, colpo piu' secco
## (la massa arriva tutta insieme), arresto sul colpo, spinta e scossa piu'
## forti, rientro un po' piu' faticoso. Giri e picchiate: solo l'impatto.
const WEIGHT_WINDUP := 1.15
const WEIGHT_ACTIVE := 0.8
const WEIGHT_RECOVERY := 1.05
const WEIGHT_HITSTOP := 1.5
const WEIGHT_KNOCKBACK := 1.25
const WEIGHT_SHAKE := 1.6

static func _weight(w: WeaponDefinition) -> void:
	for a: AttackDefinition in w.attacks.values():
		if not a.plunge and a.spin == 0.0:
			if not String(a.id).begins_with("dash_"):
				a.windup *= WEIGHT_WINDUP
			a.active *= WEIGHT_ACTIVE
			a.recovery *= WEIGHT_RECOVERY
		if a.rehit <= 0.0:
			a.hitstop *= WEIGHT_HITSTOP
		a.knockback *= WEIGHT_KNOCKBACK
		a.launch *= 1.15
		a.shake *= WEIGHT_SHAKE


## Colpo con le pose chiave di un video di riferimento (`MocapMoves`, D-046):
## busto e braccia dal video, gambe dalle pose d'appoggio del gioco; i tempi del
## video portati nella scala del gioco (il ritmo generale lo applica `_pace`).
static func _mocap(w: WeaponDefinition, id: String, move: String, props: Dictionary, legs_w: Dictionary, legs_s: Dictionary, legs_f: Dictionary) -> AttackDefinition:
	var m: Dictionary = MocapMoves.MOVES[move]
	var t: Array = m["time"]
	var timing := {"windup": clampf(t[0], 0.1, 0.4), "active": clampf(t[1] * 0.5, 0.08, 0.16), "recovery": clampf(t[2], 0.2, 0.42)}
	return _atk(w, id, _with(timing, props), _with(legs_w, m["wind"]), _with(legs_s, m["strike"]), _with(legs_f, m["follow"]))


static func _with(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate()
	out.merge(b, true)
	return out


static func _fists() -> WeaponDefinition:
	var w := WeaponDefinition.new()
	w.id = &"fists"
	w.display_name = "Pugni"
	w.kind = WeaponDefinition.Kind.FISTS
	w.move_mult = 1.06
	w.light_start = &"jab"
	w.heavy_start = &"rocket"
	w.dash_attack = &"dash_hook"
	w.air_attack = &"dive"
	w.trail_from = -0.02
	w.trail_to = 0.08
	w.hit_r = 0.12
	w.strike_dist = 0.72
	w.relaxed = pose({"arm_l": [4, 0, -6], "fore_l": [16, 0, 0], "arm_r": [4, 0, 6], "fore_r": [16, 0, 0]})
	w.guard = pose({"arm_l": [34, 10, -8], "fore_l": [112, 0, 0], "arm_r": [26, 8, 10], "fore_r": [118, 0, 0], "chest": [0, 12, 0], "hand_r": [-60, 0, 0], "hand_l": [-60, 0, 0]})
	var jab := {"windup": 0.05, "active": 0.07, "recovery": 0.16, "chain_at": 0.2, "shape": AttackDefinition.Shape.THRUST,
		"reach_min": 0.2, "reach": 1.3, "width": 0.5, "damage": 5.0, "knockback": 1.2, "hitstop": 0.045, "shake": 0.06,
		"lunge": 0.6, "fx": "punch", "trail": false}
	_atk(w, "jab", _with(jab, {"next_light": "cross", "next_heavy": "palm"}),
		{"arm_l": [30, 0, -10], "fore_l": [120, 0, 0], "chest": [0, 20, 0]},
		{"arm_l": [86, 8, 0], "fore_l": [4, 0, 0], "chest": [0, 32, 0], "head": [0, -20, 0]},
		{"arm_l": [60, 5, -5], "fore_l": [60, 0, 0], "chest": [0, 22, 0]})
	_atk(w, "cross", _with(jab, {"damage": 6.0, "knockback": 1.5, "next_light": "hook", "next_heavy": "elbow", "lunge": 0.45, "step_foot": 1.0}),
		_with(STANCE, {"arm_r": [30, 0, 12], "fore_r": [120, 0, 0], "chest": [0, -18, 0]}),
		_with(STANCE, {"arm_r": [88, -8, 0], "fore_r": [2, 0, 0], "chest": [0, 38, 0], "head": [0, -30, 0], "arm_l": [30, 10, -10], "fore_l": [115, 0, 0]}),
		_with(STANCE, {"arm_r": [60, -5, 5], "fore_r": [60, 0, 0], "chest": [0, 24, 0]}))
	_atk(w, "hook", {"windup": 0.08, "active": 0.09, "recovery": 0.2, "chain_at": 0.2, "shape": AttackDefinition.Shape.ARC,
		"arc_from": 80.0, "arc_to": -30.0, "reach_min": 0.2, "reach": 1.35, "damage": 7.0, "knockback": 2.0, "hitstop": 0.06,
		"shake": 0.1, "lunge": 0.4, "fx": "punch", "trail": true, "next_light": "upper", "next_heavy": "lift"},
		{"arm_l": [80, 70, -10], "fore_l": [85, 0, 0], "chest": [0, 30, 0]},
		{"arm_l": [86, -18, 0], "fore_l": [40, 0, 0], "chest": [0, -40, 0], "head": [0, 25, 0], "body_pos": [0, -0.03, -0.06]},
		{"arm_l": [60, -10, -5], "fore_l": [90, 0, 0], "chest": [0, -25, 0]})
	_atk(w, "upper", {"windup": 0.12, "active": 0.09, "recovery": 0.32, "shape": AttackDefinition.Shape.THRUST,
		"reach_min": 0.2, "reach": 1.35, "width": 0.6, "damage": 9.0, "knockback": 2.0, "launch": 4.0, "hitstop": 0.09,
		"shake": 0.2, "lunge": 0.6, "strike": 0.55, "fx": "punch", "trail": true, "next_light": "flurry", "next_heavy": "rocket"},
		_with(SQUAT, {"arm_r": [0, 0, 12], "fore_r": [125, 0, 0], "chest": [-15, -25, 0]}),
		{"arm_r": [128, -5, 0], "fore_r": [34, 0, 0], "chest": [4, 20, 0], "body_pos": [0, 0.04, -0.05], "leg_l": [26, 0, 0], "shin_l": [-30, 0, 0]},
		{"arm_r": [120, 0, 5], "fore_r": [80, 0, 0], "chest": [5, 10, 0]})
	_atk(w, "rocket", {"windup": 0.2, "active": 0.14, "recovery": 0.34, "shape": AttackDefinition.Shape.THRUST,
		"reach_min": 0.2, "reach": 1.5, "width": 0.7, "damage": 12.0, "knockback": 11.0, "launch": 2.0, "hitstop": 0.12,
		"shake": 0.35, "lunge": 3.8, "charge_max": 0.8, "charge_bonus": 1.2, "fx": "punch", "trail": true, "move_scale": 0.0},
		_with(STANCE, {"arm_r": [-35, 10, 18], "fore_r": [105, 0, 0], "chest": [5, -45, 0], "head": [0, 35, 0], "arm_l": [60, 20, -10], "fore_l": [70, 0, 0]}),
		_with(LUNGE, {"arm_r": [90, -6, 0], "fore_r": [0, 0, 0], "chest": [-18, 38, 0], "head": [0, -30, 0], "arm_l": [-25, 0, -20], "fore_l": [60, 0, 0]}),
		_with(STANCE, {"arm_r": [60, 0, 5], "fore_r": [50, 0, 0], "chest": [-5, 20, 0]}))
	_atk(w, "dash_hook", {"windup": 0.04, "active": 0.1, "recovery": 0.24, "shape": AttackDefinition.Shape.ARC,
		"arc_from": -90.0, "arc_to": 60.0, "reach": 1.45, "damage": 8.0, "knockback": 6.0, "hitstop": 0.07, "shake": 0.15,
		"lunge": 1.6, "fx": "punch", "next_light": "upper"},
		{"arm_r": [80, -80, 10], "fore_r": [70, 0, 0], "chest": [0, -35, 0]},
		{"arm_r": [85, 35, 0], "fore_r": [65, 0, 0], "chest": [-10, 40, 0]},
		{"arm_r": [60, 20, 5], "fore_r": [90, 0, 0], "chest": [0, 20, 0]})
	_atk(w, "dive", {"windup": 0.1, "active": 0.2, "recovery": 0.3, "shape": AttackDefinition.Shape.RADIAL, "plunge": true, "step_foot": 0.0,
		"radial_ahead": 0.5, "radial": 1.8, "damage": 9.0, "knockback": 6.0, "launch": 4.0, "hitstop": 0.1, "shake": 0.4, "fx": "dust", "trail": false},
		_with(TUCK, {"arm_r": [170, 0, 20], "fore_r": [40, 0, 0], "arm_l": [170, 0, -20], "fore_l": [40, 0, 0]}),
		_with(SQUAT, {"arm_r": [30, 0, 10], "fore_r": [10, 0, 0], "arm_l": [30, 0, -10], "fore_l": [10, 0, 0], "chest": [-30, 0, 0]}),
		_with(SQUAT, {"arm_r": [40, 0, 20], "fore_r": [30, 0, 0], "arm_l": [40, 0, -20], "fore_l": [30, 0, 0]}))
	# D-047, stile "rissa": cinque colpi leggeri (l'ultimo e' una raffica) e un
	# forte diverso per ogni punto della catena.
	_atk(w, "palm", _with(jab, {"windup": 0.08, "active": 0.1, "recovery": 0.3, "chain_at": 0.3, "damage": 7.0, "knockback": 7.0,
		"launch": 0.5, "hitstop": 0.08, "shake": 0.16, "lunge": 0.5, "step_foot": 1.0, "next_light": "jab", "next_heavy": "rocket"}),
		_with(STANCE, {"arm_r": [30, 0, 12], "fore_r": [120, 0, 0], "hand_r": [40, 0, 0], "chest": [0, -25, 0], "head": [0, 20, 0]}),
		_with(LUNGE, {"arm_r": [85, -5, 0], "fore_r": [0, 0, 0], "hand_r": [70, 0, 0], "chest": [-10, 35, 0], "head": [0, -25, 0], "arm_l": [30, 10, -10], "fore_l": [115, 0, 0]}),
		_with(STANCE, {"arm_r": [60, 0, 5], "fore_r": [50, 0, 0], "hand_r": [30, 0, 0], "chest": [0, 20, 0]}))
	_atk(w, "elbow", {"windup": 0.1, "active": 0.1, "recovery": 0.3, "chain_at": 0.25, "shape": AttackDefinition.Shape.ARC,
		"arc_from": 90.0, "arc_to": -40.0, "reach_min": 0.2, "reach": 1.15, "damage": 8.0, "knockback": 3.0, "hitstop": 0.08,
		"shake": 0.14, "lunge": 0.5, "fx": "punch", "trail": true, "next_light": "hook", "next_heavy": "rocket"},
		_with(STANCE, {"arm_r": [60, 40, 20], "fore_r": [140, 0, 0], "chest": [0, 50, 0], "head": [0, -35, 0], "arm_l": [30, 0, -10], "fore_l": [110, 0, 0]}),
		_with(STANCE, {"arm_r": [85, -60, 0], "fore_r": [150, 0, 0], "chest": [0, -45, 0], "head": [0, 30, 0], "arm_l": [40, 20, -10], "fore_l": [100, 0, 0]}),
		_with(STANCE, {"arm_r": [60, -40, 5], "fore_r": [120, 0, 0], "chest": [0, -25, 0]}))
	_atk(w, "lift", {"windup": 0.14, "active": 0.1, "recovery": 0.36, "chain_at": 0.3, "shape": AttackDefinition.Shape.THRUST,
		"reach_min": 0.2, "reach": 1.35, "width": 0.6, "damage": 10.0, "knockback": 2.0, "launch": 10.0, "hitstop": 0.1,
		"shake": 0.22, "lunge": 0.6, "strike": 0.55, "fx": "punch", "trail": true, "next_light": "upper", "next_heavy": "rocket"},
		_with(SQUAT, {"arm_r": [-5, 0, 12], "fore_r": [130, 0, 0], "chest": [-22, -30, 0], "arm_l": [30, 10, -10], "fore_l": [110, 0, 0]}),
		{"arm_r": [150, -5, 0], "fore_r": [20, 0, 0], "chest": [8, 25, 0], "body_pos": [0, 0.06, -0.05], "leg_l": [30, 0, 0], "shin_l": [-35, 0, 0]},
		{"arm_r": [130, 0, 5], "fore_r": [70, 0, 0], "chest": [5, 10, 0]})
	_atk(w, "flurry", {"windup": 0.06, "active": 0.32, "recovery": 0.32, "shape": AttackDefinition.Shape.THRUST,
		"reach_min": 0.2, "reach": 1.3, "width": 0.6, "damage": 3.0, "knockback": 0.6, "hitstop": 0.03, "shake": 0.06,
		"lunge": 1.0, "rehit": 0.07, "fx": "punch", "trail": false, "next_heavy": "rocket"},
		_with(STANCE, {"arm_r": [30, 0, 12], "fore_r": [120, 0, 0], "arm_l": [30, 0, -12], "fore_l": [120, 0, 0], "chest": [0, -10, 0]}),
		_with(LUNGE, {"arm_r": [98, -10, 0], "fore_r": [4, 0, 0], "arm_l": [98, 10, 0], "fore_l": [4, 0, 0], "chest": [-12, 25, 0], "head": [0, -20, 0]}),
		_with(STANCE, {"arm_r": [60, -5, 5], "fore_r": [60, 0, 0], "arm_l": [60, 5, -5], "fore_l": [60, 0, 0]}))
	return w


## Attrezzo in mano (piccone, ascia, pala; D-039): non e' un'arma da lotta.
## Un solo colpo, quello dello scavo (dall'alto verso il basso davanti a se'),
## che si ripete sempre uguale: niente catene, niente forte, niente scatti
## particolari; anche dopo la capriola e in aria e' lo stesso colpo.
static func _tool() -> WeaponDefinition:
	var w := _sword()
	w.id = &"tool"
	w.display_name = "Attrezzo"
	w.attacks = {}
	w.light_start = &"chop"
	w.heavy_start = &"chop"
	w.dash_attack = &"chop"
	w.air_attack = &"chop"
	w.trail_from = 0.35
	w.trail_to = 0.62
	w.hit_r = 0.12
	w.strike_dist = 0.95
	_atk(w, "chop", {"windup": 0.18, "active": 0.1, "recovery": 0.26, "chain_at": 0.6, "shape": AttackDefinition.Shape.THRUST,
		"reach_min": 0.3, "reach": 1.7, "width": 0.5, "damage": 5.0, "knockback": 1.5, "hitstop": 0.05, "shake": 0.08,
		"lunge": 0.2, "move_scale": 0.3, "next_light": "chop", "next_heavy": "chop", "trail": false},
		_with(STANCE, {"arm_r": [150, -8, 10], "fore_r": [55, 0, 0], "hand_r": [-40, 0, 0], "chest": [8, -10, 0], "arm_l": [35, 10, -12], "fore_l": [60, 0, 0]}),
		_with(STANCE, {"arm_r": [55, -8, 10], "fore_r": [10, 0, 0], "hand_r": [-100, 0, 0], "chest": [-22, -10, 0], "spine": [-8, 0, 0], "arm_l": [35, 10, -12], "fore_l": [60, 0, 0]}),
		_with(STANCE, {"arm_r": [60, -8, 10], "fore_r": [20, 0, 0], "hand_r": [-90, 0, 0], "chest": [-10, -10, 0], "arm_l": [35, 10, -12], "fore_l": [60, 0, 0]}))
	return w


static func _sword() -> WeaponDefinition:
	var w := WeaponDefinition.new()
	w.id = &"sword"
	w.display_name = "Spada"
	w.kind = WeaponDefinition.Kind.SWORD
	w.light_start = &"slash"
	w.heavy_start = &"leap"
	w.dash_attack = &"dash_cut"
	w.air_attack = &"plunge"
	w.trail_from = 0.22
	w.trail_to = 0.98
	w.strike_dist = 1.15
	w.relaxed = pose({"arm_r": [-6, 0, 8], "fore_r": [12, 0, 0], "hand_r": [-100, 0, 0], "arm_l": [4, 0, -6], "fore_l": [14, 0, 0]})
	w.guard = pose({"arm_r": [22, 6, 10], "fore_r": [52, 0, 0], "hand_r": [-26, 0, 0], "arm_l": [12, 0, -12], "fore_l": [30, 0, 0], "chest": [0, 8, 0]})
	var base := {"windup": 0.13, "active": 0.1, "recovery": 0.24, "chain_at": 0.15, "shape": AttackDefinition.Shape.ARC,
		"reach_min": 0.3, "reach": 2.05, "damage": 9.0, "knockback": 1.8, "hitstop": 0.07, "shake": 0.14, "lunge": 0.7}
	_atk(w, "slash", _with(base, {"arc_from": -80.0, "arc_to": 70.0, "next_light": "backhand", "next_heavy": "rise"}),
		_with(STANCE, {"arm_r": [84, -78, 0], "fore_r": [22, 0, 0], "hand_r": [-104, 0, 0], "chest": [0, -45, 0], "spine": [0, -10, 0], "head": [0, 32, 0], "arm_l": [40, 30, -20], "fore_l": [60, 0, 0]}),
		_with(STANCE, {"arm_r": [80, 72, 0], "fore_r": [6, 0, 0], "hand_r": [-86, 0, 0], "chest": [0, 50, 0], "spine": [0, 12, 0], "head": [0, -35, 0], "arm_l": [18, 0, -38], "fore_l": [30, 0, 0]}),
		_with(STANCE, {"arm_r": [52, 66, 0], "fore_r": [36, 0, 0], "hand_r": [-70, 0, 0], "chest": [0, 32, 0], "arm_l": [20, 0, -25], "fore_l": [35, 0, 0]}))
	_atk(w, "backhand", _with(base, {"arc_from": 80.0, "arc_to": -75.0, "damage": 10.0, "next_light": "cleave", "next_heavy": "pierce", "step_foot": 1.0}),
		_with(STANCE, {"arm_r": [88, 92, 0], "fore_r": [22, 0, 0], "hand_r": [-110, 0, 0], "chest": [0, 50, 0], "head": [0, -30, 0], "arm_l": [10, 0, -30]}),
		_with(STANCE, {"arm_r": [84, -82, 0], "fore_r": [6, 0, 0], "hand_r": [-90, 0, 0], "chest": [0, -46, 0], "head": [0, 30, 0], "arm_l": [40, 40, -15], "fore_l": [70, 0, 0]}),
		_with(STANCE, {"arm_r": [56, -70, 5], "fore_r": [30, 0, 0], "hand_r": [-70, 0, 0], "chest": [0, -30, 0]}))
	_atk(w, "cleave", {"windup": 0.17, "active": 0.09, "recovery": 0.3, "chain_at": 0.2, "shape": AttackDefinition.Shape.THRUST,
		"reach_min": 0.3, "reach": 2.3, "width": 0.55, "damage": 13.0, "knockback": 3.0, "hitstop": 0.09, "shake": 0.22,
		"lunge": 1.4, "next_light": "whirl", "next_heavy": "m_leap", "fx": "spark"},
		_with(STANCE, {"arm_r": [168, 0, 12], "fore_r": [42, 0, 0], "hand_r": [-40, 0, 0], "chest": [16, 0, 0], "arm_l": [150, 0, -20], "fore_l": [50, 0, 0], "body_pos": [0, 0.05, 0]}),
		_with(LUNGE, {"arm_r": [95, -8, 4], "fore_r": [0, 0, 0], "hand_r": [-100, 0, 0], "chest": [-26, 28, 0], "spine": [-10, 0, 0], "head": [0, -22, 0], "arm_l": [10, 0, -30], "fore_l": [20, 0, 0]}),
		_with(LUNGE, {"arm_r": [80, 5, 5], "fore_r": [10, 0, 0], "hand_r": [-95, 0, 0], "chest": [-15, 0, 0]}))
	_atk(w, "whirl", {"windup": 0.16, "active": 0.26, "recovery": 0.36, "shape": AttackDefinition.Shape.ARC,
		"arc_from": -180.0, "arc_to": 180.0, "reach_min": 0.2, "reach": 2.2, "damage": 14.0, "knockback": 9.0, "launch": 3.0,
		"hitstop": 0.12, "shake": 0.35, "lunge": 0.8, "spin": 360.0, "step_foot": 0.0, "next_heavy": "pierce"},
		_with(SQUAT, {"arm_r": [76, -96, 0], "fore_r": [10, 0, 0], "hand_r": [-100, 0, 0], "chest": [0, -60, 0], "arm_l": [60, 40, -20], "fore_l": [60, 0, 0]}),
		_with(STANCE, {"arm_r": [86, 30, 0], "fore_r": [4, 0, 0], "hand_r": [-90, 0, 0], "chest": [0, 22, 0], "arm_l": [60, 0, -60], "fore_l": [10, 0, 0]}),
		_with(STANCE, {"arm_r": [50, 40, 10], "fore_r": [30, 0, 0], "hand_r": [-70, 0, 0], "chest": [0, 15, 0]}))
	_atk(w, "rise", {"windup": 0.12, "active": 0.1, "recovery": 0.3, "chain_at": 0.25, "shape": AttackDefinition.Shape.THRUST,
		"reach_min": 0.3, "reach": 1.95, "width": 0.6, "damage": 10.0, "knockback": 2.0, "launch": 10.0, "hitstop": 0.09,
		"shake": 0.2, "lunge": 0.6, "next_light": "slash", "next_heavy": "pierce"},
		_with(SQUAT, {"arm_r": [14, -30, 16], "fore_r": [10, 0, 0], "hand_r": [-114, 0, 0], "chest": [-12, -25, 0]}),
		{"arm_r": [160, 8, 0], "fore_r": [10, 0, 0], "hand_r": [-100, 0, 0], "chest": [12, 15, 0], "body_pos": [0, 0.05, 0], "leg_l": [26, 0, 0], "shin_l": [-30, 0, 0], "leg_r": [-10, 0, 0]},
		{"arm_r": [130, 5, 5], "fore_r": [30, 0, 0], "hand_r": [-90, 0, 0], "chest": [6, 8, 0]})
	_atk(w, "pierce", {"windup": 0.16, "active": 0.16, "recovery": 0.3, "shape": AttackDefinition.Shape.THRUST,
		"reach_min": 0.3, "reach": 2.3, "width": 0.5, "damage": 15.0, "knockback": 10.0, "hitstop": 0.11, "shake": 0.3,
		"lunge": 4.5, "move_scale": 0.0},
		_with(STANCE, {"arm_r": [-22, 0, 14], "fore_r": [92, 0, 0], "hand_r": [-70, 0, 0], "chest": [0, -40, 0], "head": [0, 30, 0], "arm_l": [70, 20, -10], "fore_l": [20, 0, 0]}),
		_with(LUNGE, {"arm_r": [88, 0, 0], "fore_r": [2, 0, 0], "hand_r": [-90, 0, 0], "chest": [-20, 30, 0], "head": [0, -25, 0], "arm_l": [-30, 0, -25], "fore_l": [30, 0, 0]}),
		_with(LUNGE, {"arm_r": [70, 0, 5], "fore_r": [20, 0, 0], "hand_r": [-90, 0, 0], "chest": [-10, 20, 0]}))
	# Colpo forte: fendente dall'alto a due mani con un passo avanti, piedi a
	# terra; si puo' caricare tenendo premuto (prima: balzo di mezzo metro).
	_atk(w, "leap", {"windup": 0.3, "active": 0.09, "recovery": 0.42, "shape": AttackDefinition.Shape.THRUST,
		"reach_min": 0.3, "reach": 2.2, "width": 0.6, "damage": 18.0, "knockback": 5.0, "hitstop": 0.13, "shake": 0.5,
		"lunge": 1.1, "strike": 0.9, "charge_max": 0.7, "charge_bonus": 1.0, "fx": "dust", "move_scale": 0.0},
		_with(STANCE, {"arm_r": [172, 0, 12], "fore_r": [40, 0, 0], "hand_r": [-30, 0, 0], "arm_l": [165, 0, -14], "fore_l": [40, 0, 0], "chest": [14, 0, 0], "spine": [6, 0, 0], "body_pos": [0, 0.02, 0.04]}),
		_with(LUNGE, {"arm_r": [100, -10, 4], "fore_r": [0, 0, 0], "hand_r": [-106, 0, 0], "arm_l": [86, 10, -10], "fore_l": [10, 0, 0], "chest": [-38, 30, 0], "spine": [-12, 0, 0], "head": [0, -25, 0]}),
		_with(LUNGE, {"arm_r": [82, -8, 6], "fore_r": [8, 0, 0], "hand_r": [-100, 0, 0], "arm_l": [60, 0, -12], "fore_l": [20, 0, 0], "chest": [-28, 24, 0]}))
	_atk(w, "dash_cut", {"windup": 0.04, "active": 0.1, "recovery": 0.26, "chain_at": 0.2, "shape": AttackDefinition.Shape.ARC,
		"arc_from": -95.0, "arc_to": 85.0, "reach_min": 0.3, "reach": 2.1, "damage": 11.0, "knockback": 6.0, "hitstop": 0.08,
		"shake": 0.18, "lunge": 2.0, "next_light": "backhand", "next_heavy": "rise"},
		_with(LUNGE, {"arm_r": [70, -95, 0], "fore_r": [10, 0, 0], "hand_r": [-100, 0, 0], "chest": [-15, -40, 0]}),
		_with(LUNGE, {"arm_r": [74, 80, 0], "fore_r": [4, 0, 0], "hand_r": [-90, 0, 0], "chest": [-15, 45, 0], "arm_l": [10, 0, -40]}),
		_with(STANCE, {"arm_r": [50, 65, 0], "fore_r": [30, 0, 0], "hand_r": [-70, 0, 0], "chest": [0, 30, 0]}))
	_atk(w, "plunge", {"windup": 0.1, "active": 0.2, "recovery": 0.32, "shape": AttackDefinition.Shape.RADIAL, "plunge": true, "step_foot": 0.0,
		"radial_ahead": 0.6, "radial": 2.0, "damage": 12.0, "knockback": 6.0, "launch": 5.0, "hitstop": 0.1, "shake": 0.45, "fx": "dust"},
		_with(TUCK, {"arm_r": [172, 0, 10], "fore_r": [20, 0, 0], "hand_r": [-20, 0, 0], "chest": [10, 0, 0]}),
		_with(SQUAT, {"arm_r": [22, 0, 0], "fore_r": [0, 0, 0], "hand_r": [-112, 0, 0], "chest": [-32, 0, 0]}),
		_with(SQUAT, {"arm_r": [30, 0, 6], "fore_r": [10, 0, 0], "hand_r": [-100, 0, 0], "chest": [-20, 0, 0]}))
	# D-046: colpo ricavato dal video di riferimento (Higgsfield + tools/mocap):
	# il fendente saltato, forte dopo la calata. Il rovescio orizzontale dopo il
	# giro (`m_cross`) e' stato tolto (D-050): la catena leggera finisce col giro.
	_mocap(w, "m_leap", "sword_leap", {"chain_at": 0.3, "shape": AttackDefinition.Shape.THRUST, "reach_min": 0.3, "reach": 2.2,
		"width": 0.6, "damage": 17.0, "knockback": 5.0, "hitstop": 0.12, "shake": 0.45, "lunge": 1.2, "fx": "dust",
		"move_scale": 0.0, "next_light": "slash"}, STANCE, SQUAT, SQUAT)
	return w


static func _spear() -> WeaponDefinition:
	var w := WeaponDefinition.new()
	w.id = &"spear"
	w.display_name = "Lancia"
	w.kind = WeaponDefinition.Kind.SPEAR
	w.light_start = &"thrust"
	w.heavy_start = &"charge"
	w.dash_attack = &"dash_thrust"
	w.air_attack = &"plunge"
	w.trail_from = 1.25
	w.trail_to = 1.62
	# D-041: ferisce solo la punta (la testa di ferro, da 1,2 a 1,62), non l'asta.
	w.hit_from = 1.2
	w.strike_dist = 1.25
	w.move_mult = 1.0
	w.relaxed = pose({"arm_r": [10, 0, 10], "fore_r": [70, 0, 0], "hand_r": [0, 0, 0], "arm_l": [4, 0, -6], "fore_l": [14, 0, 0]})
	w.guard = pose({"arm_r": [8, 0, 12], "fore_r": [72, 0, 0], "hand_r": [-62, 0, 0], "chest": [0, -20, 0], "head": [0, 18, 0]})
	# Ritmo della lancia (D-034, D-040): solo colpi di punta perforanti. Due
	# stoccate secche, la stoccata alta che solleva e l'infilzata finale lenta e
	# lunga che trapassa tutta la fila; ramo forte: affondo in avanzata.
	var th := {"windup": 0.08, "active": 0.08, "recovery": 0.18, "chain_at": 0.12, "shape": AttackDefinition.Shape.THRUST,
		"reach_min": 0.4, "reach": 2.75, "width": 0.35, "damage": 8.0, "knockback": 1.2, "hitstop": 0.05, "shake": 0.1, "lunge": 0.8,
		"strike": 1.3, "pierce": 0.6}
	# D-041: carica, colpo e seguito tengono la lancia dritta davanti all'eroe
	# (entro ±6°, misurato con tools/spear_probe.gd): la punta va avanti e indietro
	# lungo l'asta. Prima il petto girava da -40° a +55° e la lancia spazzava di
	# 80° da destra a sinistra, come un fendente.
	var wind := _with(STANCE, {"arm_r": [-30, 50, 12], "fore_r": [100, 0, 0], "hand_r": [-68, 0, 0], "chest": [0, -55, 0], "head": [0, 45, 0]})
	var strike := _with(LUNGE, {"arm_r": [86, -15, 2], "fore_r": [6, 0, 0], "hand_r": [-86, 0, 0], "chest": [-12, 20, 0], "head": [0, -20, 0]})
	var follow := _with(STANCE, {"arm_r": [30, 15, 8], "fore_r": [55, 0, 0], "hand_r": [-78, 0, 0], "chest": [-6, -20, 0], "head": [0, 20, 0]})
	_atk(w, "thrust", _with(th, {"next_light": "thrust2", "next_heavy": "retreat"}), wind, strike, follow)
	# D-047, stile "distanza": dal primo colpo il forte fa un passo indietro e
	# colpisce da lontano (tiene il nemico sulla punta).
	_atk(w, "retreat", _with(th, {"windup": 0.3, "active": 0.1, "recovery": 0.26, "chain_at": 0.25, "damage": 10.0, "knockback": 2.5,
		"lunge": 0.2, "backstep": 0.9, "pierce": 0.8, "step_foot": 0.0, "next_light": "thrust2", "next_heavy": "drive"}), wind, strike, follow)
	_atk(w, "thrust2", _with(th, {"damage": 9.0, "next_light": "rise", "next_heavy": "drive", "lunge": 0.9, "step_foot": 1.0}), wind, strike, follow)
	# Stoccata alta (D-040): la punta sale da sotto e trapassa verso l'alto,
	# solleva chi prende. Prima era una spazzata di taglio, come una spada.
	_atk(w, "rise", _with(th, {"windup": 0.12, "active": 0.1, "recovery": 0.24, "chain_at": 0.2, "damage": 11.0,
		"knockback": 2.0, "launch": 4.0, "hitstop": 0.07, "shake": 0.14, "lunge": 0.9, "pierce": 0.9, "step_foot": 1.0,
		"next_light": "impale", "next_heavy": "charge"}),
		_with(SQUAT, {"arm_r": [-30, 50, 12], "fore_r": [100, 0, 0], "hand_r": [-68, 0, 0], "chest": [0, -55, 0], "head": [0, 45, 0]}),
		_with(LUNGE, {"arm_r": [116, -15, 2], "fore_r": [4, 0, 0], "hand_r": [-86, 0, 0], "chest": [-16, 20, 0], "head": [0, -20, 0]}),
		_with(STANCE, {"arm_r": [60, 0, 6], "fore_r": [40, 0, 0], "hand_r": [-84, 0, 0], "chest": [-6, -10, 0], "head": [0, 10, 0]}))
	# Infilzata: carica lunga all'indietro, affondo col peso del corpo che
	# trapassa per 1,6 m oltre la punta; chiude la catena e spinge lontano.
	_atk(w, "impale", _with(th, {"windup": 0.22, "active": 0.13, "recovery": 0.36, "chain_at": 0.3, "reach": 2.9, "width": 0.45,
		"damage": 15.0, "knockback": 8.0, "hitstop": 0.11, "shake": 0.3, "lunge": 1.4, "pierce": 1.6, "move_scale": 0.0,
		"next_light": "thrust", "next_heavy": "charge"}),
		_with(SQUAT, {"arm_r": [-40, 50, 12], "fore_r": [100, 0, 0], "hand_r": [-68, 0, 0], "chest": [0, -55, 0], "head": [0, 50, 0]}),
		strike, follow)
	# Affondo in avanzata (D-040, ramo forte della catena): un passo lungo e la
	# lancia che trapassa la fila; prima era un giro di taglio a 360°.
	_atk(w, "drive", _with(th, {"windup": 0.18, "active": 0.14, "recovery": 0.34, "chain_at": 0.3, "reach": 2.9, "width": 0.45,
		"damage": 13.0, "knockback": 6.0, "hitstop": 0.1, "shake": 0.22, "lunge": 1.9, "pierce": 1.3, "move_scale": 0.0,
		"step_foot": 1.0, "next_light": "thrust", "next_heavy": "charge"}),
		_with(SQUAT, {"arm_r": [-40, 50, 12], "fore_r": [100, 0, 0], "hand_r": [-68, 0, 0], "chest": [0, -55, 0], "head": [0, 50, 0]}),
		strike, follow)
	_atk(w, "charge", _with(th, {"windup": 0.22, "active": 0.24, "recovery": 0.36, "chain_at": 0.0, "reach": 2.9, "width": 0.55,
		"damage": 16.0, "knockback": 12.0, "launch": 2.0, "hitstop": 0.12, "shake": 0.35, "lunge": 6.0, "move_scale": 0.0,
		"charge_max": 0.8, "charge_bonus": 1.0, "rehit": 0.0, "pierce": 2.2}), wind, strike, follow)
	_atk(w, "dash_thrust", _with(th, {"windup": 0.04, "active": 0.12, "damage": 11.0, "knockback": 7.0, "lunge": 2.6, "pierce": 1.0, "next_light": "thrust2"}), wind, strike, follow)
	_atk(w, "plunge", {"windup": 0.12, "active": 0.2, "recovery": 0.34, "shape": AttackDefinition.Shape.RADIAL, "plunge": true, "step_foot": 0.0,
		"radial_ahead": 0.9, "radial": 1.9, "damage": 13.0, "knockback": 5.0, "launch": 6.0, "hitstop": 0.1, "shake": 0.45, "fx": "dust"},
		_with(TUCK, {"arm_r": [160, 0, 10], "fore_r": [30, 0, 0], "hand_r": [-40, 0, 0]}),
		_with(SQUAT, {"arm_r": [40, 0, 0], "fore_r": [10, 0, 0], "hand_r": [-140, 0, 0], "chest": [-30, 0, 0]}),
		_with(SQUAT, {"arm_r": [40, 0, 6], "fore_r": [10, 0, 0], "hand_r": [-120, 0, 0], "chest": [-20, 0, 0]}))
	return w


static func _hammer() -> WeaponDefinition:
	var w := WeaponDefinition.new()
	w.id = &"hammer"
	w.display_name = "Martello"
	w.kind = WeaponDefinition.Kind.HAMMER
	w.move_mult = 0.9
	w.light_start = &"swing"
	w.heavy_start = &"quake"
	w.dash_attack = &"dash_swing"
	w.air_attack = &"meteor"
	w.trail_from = 0.72
	w.trail_to = 1.0
	w.hit_from = 0.78
	w.hit_r = 0.17
	w.strike_dist = 1.0
	w.relaxed = pose({"arm_r": [40, 24, 12], "fore_r": [124, 0, 0], "hand_r": [-16, 0, 0], "arm_l": [4, 0, -6], "fore_l": [14, 0, 0]})
	w.guard = pose({"arm_r": [38, 22, 12], "fore_r": [118, 0, 0], "hand_r": [-20, 0, 0], "chest": [0, -10, 0]})
	var sw := {"windup": 0.24, "active": 0.14, "recovery": 0.34, "chain_at": 0.2, "shape": AttackDefinition.Shape.ARC,
		"reach_min": 0.4, "reach": 2.2, "damage": 16.0, "knockback": 3.5, "hitstop": 0.11, "shake": 0.3, "lunge": 0.7, "fx": "spark"}
	_atk(w, "swing", _with(sw, {"arc_from": -100.0, "arc_to": 80.0, "next_light": "upswing", "next_heavy": "quake"}),
		_with(STANCE, {"arm_r": [70, -100, 0], "fore_r": [18, 0, 0], "hand_r": [-100, 0, 0], "chest": [0, -62, 0], "spine": [0, -12, 0], "head": [0, 40, 0]}),
		_with(STANCE, {"arm_r": [70, 74, 0], "fore_r": [6, 0, 0], "hand_r": [-88, 0, 0], "chest": [0, 56, 0], "spine": [0, 14, 0], "head": [0, -35, 0]}),
		_with(STANCE, {"arm_r": [40, 70, 0], "fore_r": [30, 0, 0], "hand_r": [-80, 0, 0], "chest": [0, 45, 0]}))
	# D-054: il montante si ferma a 1,2 m (su terreno piano a 0,8 la testa che
	# sale passava sopra un bersaglio vicino) e la finestra di contatto copre la
	# salita (la posa arriva in ritardo, come le spazzate dello spadone, D-052).
	_atk(w, "upswing", _with(sw, {"windup": 0.34, "active": 0.2, "shape": AttackDefinition.Shape.THRUST, "reach": 1.95, "width": 0.7, "launch": 5.0, "strike": 1.2,
		"knockback": 3.0, "next_light": "slam", "next_heavy": "quake"}),
		_with(SQUAT, {"arm_r": [8, -30, 12], "fore_r": [10, 0, 0], "hand_r": [-120, 0, 0], "chest": [-15, -30, 0]}),
		{"arm_r": [108, -12, 0], "fore_r": [8, 0, 0], "hand_r": [-90, 0, 0], "chest": [2, 34, 0], "head": [0, -25, 0], "body_pos": [0, 0.04, -0.08]},
		{"arm_r": [138, 0, 5], "fore_r": [36, 0, 0], "hand_r": [-62, 0, 0], "chest": [8, 5, 0]})
	_atk(w, "slam", {"windup": 0.3, "active": 0.06, "recovery": 0.46, "shape": AttackDefinition.Shape.RADIAL,
		"radial_ahead": 1.4, "radial": 2.4, "damage": 20.0, "knockback": 9.0, "launch": 6.0, "hitstop": 0.14, "shake": 0.55,
		"lunge": 0.8, "fx": "dust", "next_light": "swing", "next_heavy": "aftershock"},
		_with(STANCE, {"arm_r": [175, 0, 10], "fore_r": [30, 0, 0], "hand_r": [-30, 0, 0], "chest": [18, 0, 0], "body_pos": [0, 0.06, 0]}),
		_with(SQUAT, {"arm_r": [98, 0, 4], "fore_r": [0, 0, 0], "hand_r": [-110, 0, 0], "chest": [-38, 0, 0]}),
		_with(SQUAT, {"arm_r": [90, 0, 6], "fore_r": [4, 0, 0], "hand_r": [-104, 0, 0], "chest": [-30, 0, 0]}))
	_atk(w, "quake", {"windup": 0.4, "active": 0.06, "recovery": 0.5, "shape": AttackDefinition.Shape.RADIAL,
		"radial_ahead": 1.2, "radial": 3.2, "damage": 24.0, "knockback": 11.0, "launch": 8.0, "hitstop": 0.16, "shake": 0.7,
		"lunge": 0.5, "charge_max": 1.0, "charge_bonus": 1.2, "fx": "dust", "move_scale": 0.0},
		_with(STANCE, {"arm_r": [178, 30, 10], "fore_r": [40, 0, 0], "hand_r": [-20, 0, 0], "chest": [22, -30, 0], "body_pos": [0, 0.08, 0]}),
		_with(SQUAT, {"arm_r": [98, 0, 4], "fore_r": [0, 0, 0], "hand_r": [-110, 0, 0], "chest": [-42, 0, 0]}),
		_with(SQUAT, {"arm_r": [92, 0, 6], "fore_r": [4, 0, 0], "hand_r": [-106, 0, 0], "chest": [-32, 0, 0]}))
	_atk(w, "dash_swing", _with(sw, {"windup": 0.06, "arc_from": -95.0, "arc_to": 85.0, "lunge": 1.8, "next_light": "upswing"}),
		_with(LUNGE, {"arm_r": [60, -100, 0], "fore_r": [10, 0, 0], "hand_r": [-100, 0, 0], "chest": [-10, -50, 0]}),
		_with(LUNGE, {"arm_r": [66, 76, 0], "fore_r": [6, 0, 0], "hand_r": [-88, 0, 0], "chest": [-10, 50, 0]}),
		_with(STANCE, {"arm_r": [40, 70, 0], "fore_r": [30, 0, 0], "hand_r": [-80, 0, 0], "chest": [0, 45, 0]}))
	_atk(w, "meteor", {"windup": 0.14, "active": 0.2, "recovery": 0.44, "shape": AttackDefinition.Shape.RADIAL, "plunge": true, "step_foot": 0.0,
		"radial_ahead": 1.0, "radial": 2.8, "damage": 20.0, "knockback": 9.0, "launch": 7.0, "hitstop": 0.14, "shake": 0.65, "fx": "dust"},
		_with(TUCK, {"arm_r": [176, 0, 10], "fore_r": [30, 0, 0], "hand_r": [-30, 0, 0], "chest": [16, 0, 0]}),
		_with(SQUAT, {"arm_r": [96, 0, 4], "fore_r": [0, 0, 0], "hand_r": [-110, 0, 0], "chest": [-40, 0, 0]}),
		_with(SQUAT, {"arm_r": [90, 0, 6], "fore_r": [4, 0, 0], "hand_r": [-104, 0, 0], "chest": [-30, 0, 0]}))
	# Forte dopo il montante. D-046 lo prendeva dal video (`m_smash`), ma busto
	# e martello finivano troppo in avanti; D-049: colpo pesante disegnato a mano.
	# Carica lunga col martello alto dietro la testa e il busto inarcato
	# indietro (tenendo premuto si carica), poi colpo secco a terra poco davanti
	# ai piedi col busto appena chinato, e si resta piantati.
	(w.attacks[&"upswing"] as AttackDefinition).next_heavy = &"smash"
	_atk(w, "smash", {"windup": 0.44, "active": 0.06, "recovery": 0.44, "chain_at": 0.0, "shape": AttackDefinition.Shape.RADIAL,
		"radial_ahead": 1.1, "radial": 2.8, "damage": 24.0, "knockback": 10.0, "launch": 7.0, "hitstop": 0.16, "shake": 0.65,
		"lunge": 0.3, "charge_max": 1.0, "charge_bonus": 1.0, "fx": "dust", "move_scale": 0.0, "next_light": "swing"},
		_with(STANCE, {"arm_r": [172, 0, 10], "fore_r": [4, 0, 0], "hand_r": [-56, 0, 0], "arm_l": [165, 0, -10], "fore_l": [10, 0, 0],
			"chest": [26, 0, 0], "head": [-10, 0, 0], "body_pos": [0, 0.08, 0]}),
		_with(SQUAT, {"arm_r": [78, 0, 4], "fore_r": [0, 0, 0], "hand_r": [-96, 0, 0], "arm_l": [72, 0, -6], "fore_l": [10, 0, 0],
			"chest": [-20, 0, 0]}),
		_with(SQUAT, {"arm_r": [72, 0, 6], "fore_r": [4, 0, 0], "hand_r": [-92, 0, 0], "arm_l": [64, 0, -6], "fore_l": [20, 0, 0],
			"chest": [-16, 0, 0]}))
	# D-047, stile "distruzione": dopo il colpo a terra il forte e' un secondo
	# colpo a terra piu' forte, con l'onda che arriva lontano.
	_atk(w, "aftershock", {"windup": 0.36, "active": 0.06, "recovery": 0.55, "shape": AttackDefinition.Shape.RADIAL,
		"radial_ahead": 1.6, "radial": 3.6, "damage": 28.0, "knockback": 14.0, "launch": 9.0, "hitstop": 0.16, "shake": 0.8,
		"lunge": 0.6, "fx": "dust", "move_scale": 0.0, "next_light": "swing"},
		_with(STANCE, {"arm_r": [178, -20, 10], "fore_r": [40, 0, 0], "hand_r": [-20, 0, 0], "chest": [24, 20, 0], "body_pos": [0, 0.08, 0]}),
		_with(SQUAT, {"arm_r": [100, 0, 4], "fore_r": [0, 0, 0], "hand_r": [-110, 0, 0], "chest": [-44, 0, 0]}),
		_with(SQUAT, {"arm_r": [94, 0, 6], "fore_r": [4, 0, 0], "hand_r": [-106, 0, 0], "chest": [-34, 0, 0]}))
	_tempo(w, 1.35)
	return w


## Bastone magico (D-055): il colpo lancia un dardo di fuoco (catena di tre,
## il terzo piu' forte), il forte tenuto carica una palla di fuoco che esplode.
## Le pose puntano la gemma verso il bersaglio come l'affondo della lancia.
static func _staff() -> WeaponDefinition:
	var w := WeaponDefinition.new()
	w.id = &"staff"
	w.display_name = "Bastone"
	w.kind = WeaponDefinition.Kind.STAFF
	w.light_start = &"fire_bolt"
	w.heavy_start = &"fireball"
	w.dash_attack = &"fire_bolt"
	w.air_attack = &"fire_bolt"
	w.trail_from = 1.1
	w.trail_to = 1.4
	w.hit_from = 1.1
	w.strike_dist = 6.0
	w.move_mult = 1.0
	w.relaxed = pose({"arm_r": [10, 0, 10], "fore_r": [70, 0, 0], "hand_r": [0, 0, 0], "arm_l": [4, 0, -6], "fore_l": [14, 0, 0]})
	w.guard = pose({"arm_r": [20, 0, 12], "fore_r": [80, 0, 0], "hand_r": [-40, 0, 0], "chest": [0, -12, 0], "head": [0, 10, 0]})
	var bolt := {"windup": 0.14, "active": 0.06, "recovery": 0.26, "chain_at": 0.25, "shape": AttackDefinition.Shape.THRUST,
		"reach_min": 0.0, "reach": 0.0, "width": 0.0, "damage": 9.0, "knockback": 2.0, "hitstop": 0.05, "shake": 0.08, "lunge": 0.0,
		"move_scale": 0.6, "cast": "bolt", "trail": false, "fx": "fire"}
	var wind := _with(STANCE, {"arm_r": [40, 30, 12], "fore_r": [90, 0, 0], "hand_r": [-40, 0, 0], "chest": [0, -30, 0], "head": [0, 25, 0]})
	var strike := _with(STANCE, {"arm_r": [84, -6, 2], "fore_r": [8, 0, 0], "hand_r": [-82, 0, 0], "chest": [-6, 12, 0], "head": [0, -12, 0]})
	var follow := _with(STANCE, {"arm_r": [60, 0, 6], "fore_r": [40, 0, 0], "hand_r": [-70, 0, 0], "chest": [-4, 0, 0]})
	_atk(w, "fire_bolt", _with(bolt, {"next_light": "fire_bolt2", "next_heavy": "fireball"}), wind, strike, follow)
	_atk(w, "fire_bolt2", _with(bolt, {"next_light": "fire_bolt3", "next_heavy": "fireball"}),
		_with(STANCE, {"arm_r": [40, -20, 12], "fore_r": [90, 0, 0], "hand_r": [-40, 0, 0], "chest": [0, 20, 0], "head": [0, -15, 0]}), strike, follow)
	_atk(w, "fire_bolt3", _with(bolt, {"windup": 0.2, "damage": 14.0, "knockback": 4.0, "shake": 0.14, "next_light": "fire_bolt", "next_heavy": "fireball"}),
		_with(STANCE, {"arm_r": [150, 0, 10], "fore_r": [40, 0, 0], "hand_r": [-30, 0, 0], "chest": [10, 0, 0]}), strike, follow)
	_atk(w, "fireball", {"windup": 0.36, "active": 0.08, "recovery": 0.4, "chain_at": 0.3, "shape": AttackDefinition.Shape.THRUST,
		"reach_min": 0.0, "reach": 0.0, "width": 0.0, "damage": 22.0, "knockback": 9.0, "launch": 4.0, "hitstop": 0.12, "shake": 0.45,
		"lunge": 0.0, "move_scale": 0.2, "charge_max": 1.2, "charge_bonus": 0.8, "cast": "ball", "trail": false, "fx": "fire",
		"next_light": "fire_bolt"},
		_with(STANCE, {"arm_r": [160, 10, 12], "fore_r": [30, 0, 0], "hand_r": [-20, 0, 0], "arm_l": [120, -10, -10], "fore_l": [40, 0, 0], "chest": [12, 0, 0], "head": [-8, 0, 0]}),
		_with(LUNGE, {"arm_r": [96, -4, 2], "fore_r": [4, 0, 0], "hand_r": [-40, 0, 0], "arm_l": [80, 10, -10], "fore_l": [20, 0, 0], "chest": [-10, 10, 0], "head": [0, -10, 0]}),
		follow)
	return w


static func _greatsword() -> WeaponDefinition:
	var w := WeaponDefinition.new()
	w.id = &"greatsword"
	w.display_name = "Spadone"
	w.kind = WeaponDefinition.Kind.GREATSWORD
	w.move_mult = 0.94
	w.light_start = &"sweep"
	w.heavy_start = &"cyclone"
	w.dash_attack = &"dash_sweep"
	w.air_attack = &"plunge"
	w.trail_from = 0.3
	w.trail_to = 1.45
	w.hit_r = 0.11
	w.strike_dist = 1.25
	w.relaxed = pose({"arm_r": [40, 22, 12], "fore_r": [122, 0, 0], "hand_r": [-12, 0, 0], "arm_l": [4, 0, -6], "fore_l": [14, 0, 0]})
	w.guard = pose({"arm_r": [30, 16, 8], "fore_r": [70, 0, 0], "hand_r": [-52, 0, 0], "chest": [0, -12, 0]})
	var sw := {"windup": 0.28, "active": 0.2, "recovery": 0.26, "chain_at": 0.2, "shape": AttackDefinition.Shape.ARC,
		"reach_min": 0.4, "reach": 2.55, "damage": 14.0, "knockback": 3.0, "hitstop": 0.09, "shake": 0.25, "lunge": 0.9}
	_atk(w, "sweep", _with(sw, {"arc_from": -110.0, "arc_to": 90.0, "next_light": "return", "next_heavy": "cleave"}),
		_with(STANCE, {"arm_r": [80, -100, 0], "fore_r": [16, 0, 0], "hand_r": [-104, 0, 0], "chest": [0, -62, 0], "spine": [0, -14, 0], "head": [0, 40, 0]}),
		_with(STANCE, {"arm_r": [78, 80, 0], "fore_r": [6, 0, 0], "hand_r": [-90, 0, 0], "chest": [0, 58, 0], "spine": [0, 14, 0], "head": [0, -38, 0]}),
		_with(STANCE, {"arm_r": [50, 72, 0], "fore_r": [30, 0, 0], "hand_r": [-74, 0, 0], "chest": [0, 40, 0]}))
	_atk(w, "return", _with(sw, {"arc_from": 100.0, "arc_to": -100.0, "next_light": "sweep2", "next_heavy": "cyclone"}),
		_with(STANCE, {"arm_r": [84, 96, 0], "fore_r": [16, 0, 0], "hand_r": [-104, 0, 0], "chest": [0, 58, 0], "head": [0, -35, 0]}),
		_with(STANCE, {"arm_r": [80, -90, 0], "fore_r": [6, 0, 0], "hand_r": [-90, 0, 0], "chest": [0, -56, 0], "head": [0, 38, 0]}),
		_with(STANCE, {"arm_r": [52, -76, 0], "fore_r": [30, 0, 0], "hand_r": [-74, 0, 0], "chest": [0, -38, 0]}))
	_atk(w, "cleave", {"windup": 0.28, "active": 0.08, "recovery": 0.42, "shape": AttackDefinition.Shape.THRUST,
		"reach_min": 0.4, "reach": 2.8, "width": 0.7, "damage": 22.0, "knockback": 8.0, "launch": 3.0, "hitstop": 0.13,
		"shake": 0.45, "lunge": 1.2, "strike": 1.05, "fx": "dust", "next_light": "sweep"},
		_with(STANCE, {"arm_r": [172, 0, 10], "fore_r": [36, 0, 0], "hand_r": [-36, 0, 0], "chest": [18, 0, 0], "body_pos": [0, 0.05, 0]}),
		_with(LUNGE, {"arm_r": [95, -10, 4], "fore_r": [0, 0, 0], "hand_r": [-106, 0, 0], "chest": [-34, 30, 0], "spine": [-10, 0, 0], "head": [0, -25, 0]}),
		_with(LUNGE, {"arm_r": [88, 0, 6], "fore_r": [6, 0, 0], "hand_r": [-100, 0, 0], "chest": [-26, 0, 0]}))
	_atk(w, "cyclone", {"windup": 0.3, "active": 0.56, "recovery": 0.46, "shape": AttackDefinition.Shape.ARC,
		"arc_from": -360.0, "arc_to": 360.0, "reach_min": 0.3, "reach": 2.6, "damage": 11.0, "knockback": 7.0, "launch": 2.5,
		"hitstop": 0.07, "shake": 0.25, "lunge": 1.4, "rehit": 0.1, "spin": 720.0, "step_foot": 0.0, "charge_max": 0.8, "charge_bonus": 0.8, "move_scale": 0.35},
		_with(SQUAT, {"arm_r": [76, -110, 0], "fore_r": [10, 0, 0], "hand_r": [-100, 0, 0], "chest": [0, -70, 0]}),
		_with(STANCE, {"arm_r": [84, 20, 0], "fore_r": [4, 0, 0], "hand_r": [-90, 0, 0], "chest": [0, 20, 0]}),
		_with(STANCE, {"arm_r": [50, 30, 0], "fore_r": [30, 0, 0], "hand_r": [-74, 0, 0], "chest": [0, 20, 0]}))
	_atk(w, "dash_sweep", _with(sw, {"windup": 0.06, "arc_from": -100.0, "arc_to": 90.0, "lunge": 2.2, "next_light": "return"}),
		_with(LUNGE, {"arm_r": [70, -100, 0], "fore_r": [12, 0, 0], "hand_r": [-104, 0, 0], "chest": [-12, -55, 0]}),
		_with(LUNGE, {"arm_r": [74, 80, 0], "fore_r": [6, 0, 0], "hand_r": [-90, 0, 0], "chest": [-12, 55, 0]}),
		_with(STANCE, {"arm_r": [50, 72, 0], "fore_r": [30, 0, 0], "hand_r": [-74, 0, 0], "chest": [0, 40, 0]}))
	_atk(w, "plunge", {"windup": 0.14, "active": 0.2, "recovery": 0.4, "shape": AttackDefinition.Shape.RADIAL, "plunge": true, "step_foot": 0.0,
		"radial_ahead": 1.0, "radial": 2.5, "damage": 18.0, "knockback": 8.0, "launch": 6.0, "hitstop": 0.13, "shake": 0.55, "fx": "dust"},
		_with(TUCK, {"arm_r": [174, 0, 10], "fore_r": [30, 0, 0], "hand_r": [-30, 0, 0], "chest": [14, 0, 0]}),
		_with(SQUAT, {"arm_r": [30, 0, 0], "fore_r": [0, 0, 0], "hand_r": [-112, 0, 0], "chest": [-36, 0, 0]}),
		_with(SQUAT, {"arm_r": [36, 0, 6], "fore_r": [10, 0, 0], "hand_r": [-104, 0, 0], "chest": [-26, 0, 0]}))
	# D-047, stile "slancio": la catena leggera gira all'infinito (spazzata,
	# ritorno, spazzata, ritorno...) e ogni colpo concatenato fa +10% di danno,
	# fino a +30%; dalla seconda spazzata il forte e' la calata finale che usa
	# tutto lo slancio.
	w.momentum_step = 0.1
	w.momentum_max = 3
	var swp: AttackDefinition = w.attacks[&"sweep"]
	var sw2 := _atk(w, "sweep2", _with(sw, {"arc_from": -110.0, "arc_to": 90.0, "damage": 15.0, "next_light": "return", "next_heavy": "finale"}), {}, {}, {})
	sw2.key_wind = swp.key_wind
	sw2.key_strike = swp.key_strike
	sw2.key_follow = swp.key_follow
	var clv: AttackDefinition = w.attacks[&"cleave"]
	var fin := _atk(w, "finale", {"windup": 0.34, "active": 0.08, "recovery": 0.5, "shape": AttackDefinition.Shape.THRUST,
		"reach_min": 0.4, "reach": 2.9, "width": 0.8, "damage": 26.0, "knockback": 12.0, "launch": 4.0, "hitstop": 0.15,
		"shake": 0.6, "lunge": 1.4, "strike": 1.05, "fx": "dust", "move_scale": 0.0, "next_light": "sweep"}, {}, {}, {})
	fin.key_wind = clv.key_wind
	fin.key_strike = clv.key_strike
	fin.key_follow = clv.key_follow
	_tempo(w, 1.3)
	return w
