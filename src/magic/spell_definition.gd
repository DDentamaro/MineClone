class_name SpellDefinition
extends RefCounted
## Un incantesimo (M5, magia ampliata — D-027). Due fonti:
## - i quattro dardi del prototipo (SPELLS, HTML 8002–8006) con i loro numeri
##   (`kind` = "dart", balistica e raccolta come nel gate R);
## - il libro di RMNDWN K122 (SpellForge v78): elementDef e roster Karma, con
##   Output richiesto, tempi, velocita', danno e forma per `kind`.
## Scuole: fire, water, air, earth, karma. Livelli 1..4.

var id: StringName
var display_name := ""
## Scuola/elemento (karma = materia neutra, niente stati).
var el := "fire"
var tier := 1
## Forma: dart, bolt, volley, ball, meteor, throw, shaft, orb, beam, jet,
## column, spikes, quake, rain, cyclone, vacuum, updraft, wave, lash, slash,
## push, spray, aura, buff, wall, pillar.
var kind := "bolt"
## Output richiesto (RMNDWN `karma`/`output`): si lancia solo se <= Output del caster.
var output := 20.0
var cast_dur := 0.4
var recover := 0.3
var speed := 10.0
var grav := 0.0
var drag := 0.0
var life := 1.2
## Durata dell'effetto visibile/attivo (fxLife).
var fx_life := 1.2
var r := 0.15
var wide := 0.0
var area := 0.0
var height := 0.0
var width := 0.0
var dmg := 18.0
var knock := 0.8
var status := ""
## Sul caster invece che sul bersaglio.
var at_self := false
## Salva: colpi per lancio e intervallo; ventaglio in gradi.
var salvo_n := 1
var salvo_gap := 0.0
var fan_deg := 0.0
## Scoppio delle sfere (raggio, danno, spinta).
var burst_r := 0.0
var burst_dmg := 0.0
var burst_knock := 0.0
## Coerenza del Karma: exp(-decoh·t), danno × max(coh_floor, coerenza).
var decoh := 0.0
var scatter := 0.0
var coh_floor := 1.0
## Getti sostenuti (SUSTAIN_TUNE): dps, spinta continua, portata, sezioni.
var dps := 0.0
var push := 0.0
var reach := 0.0
## Vecchie regole del prototipo (costo in mana, impegno al 35%).
var cost := 0.0
## Stagger (poise) del colpo: fa vacillare il corpo (RMNDWN `stagger`).
var stagger := 12.0
## Hitstop dell'attacco prima dei moltiplicatori di famiglia (RMNDWN `hitstop`).
var hit_stop := 0.025
## Juice: ampiezza della scossa e altezza del suono d'impatto (`juice.shake/sfx`).
var shake := 0.006
var sfx := 1.0
## Calcio del campo visivo in gradi (`juice.fov`).
var fov := 0.18
## Colpo pesante (`hitbox.forceHeavy`).
var heavy := false
## Ruolo (colpo, rosa, area, difesa, utilita): "difesa" non fa mai danno.
var role := "colpo"
## Istante del contatto dopo il rilascio (timeline v78); <0 = volo del proiettile.
var hit_at := -1.0
## Getti: secondi di emissione (finestra in cui feriscono) e sezioni del cono.
var emit := 0.0
var r0 := 0.0
var r1 := 0.0
## Stagger al secondo dei getti.
var poise := 0.0
## Fasci del Karma: lunghezza del bastone luminoso (0 = raggio intero).
var body_len := 0.0
## Scoppio delle sfere: stagger.
var burst_stag := 0.0
## Postura del lancio (RMNDWN stance): inclinazione, apertura, allargamento,
## due braccia e convergenza delle mani.
var lean := 0.0
var open := 0.0
var widen := 0.0
var both := false
var converge := 0.0
## Glifo del lancio davanti alla mano (RMNDWN elementGlyph / Karma glyph):
## raggio, distanza dal palmo, lati del poligono inscritto e tacche radiali.
var glyph_r := 0.26
var glyph_off := 0.14
var glyph_poly := 3
var glyph_ticks := 8
## Rinculo quando la magia colpisce (impactAtk, impactDec, impactPose).
var recoil_atk := 0.035
var recoil_dec := 0.24
var recoil_pose := {"upper": -0.08, "lower": 0.10, "spine_y": 0.04}
## Descrizione breve per il libro.
var note := ""


func is_legacy() -> bool:
	return kind == "dart"


## Due mani con la postura a braccia unite o dai 120 di Output (RMNDWN K56).
func two_handed() -> bool:
	return both or output >= 120.0


## Convergenza delle due mani (almeno .30 se le impone l'Output).
func hands_converge() -> float:
	return maxf(converge, 0.30) if output >= 120.0 and not both else converge


func school_name() -> String:
	return {"fire": "Fuoco", "water": "Acqua", "air": "Aria", "earth": "Terra", "karma": "Karma"}.get(el, el)


const EL_COLOR := {"fire": Color(1.0, 0.45, 0.15), "water": Color(0.3, 0.6, 1.0), "air": Color(0.62, 0.86, 0.86),
	"earth": Color(0.62, 0.45, 0.25), "karma": Color(0.72, 0.5, 1.0)}


func color() -> Color:
	return EL_COLOR.get(el, Color.WHITE)


## Sigla per la barra: prime tre lettere del nome.
func glyph() -> String:
	return display_name.substr(0, 3)


static var _all: Array[SpellDefinition] = []
static var _by_id := {}


static func all() -> Array[SpellDefinition]:
	if _all.is_empty():
		_build()
	return _all


static func by_id(id: StringName) -> SpellDefinition:
	if _all.is_empty():
		_build()
	return _by_id.get(id)


static func _add(s: SpellDefinition) -> void:
	_all.append(s)
	_by_id[s.id] = s


## I dardi del prototipo: numeri della tabella SPELLS (costo -> Output ×2).
static func _legacy(id: StringName, n: String, el: String, cost: float, cd: float, rec: float, sp: float, g: float, dr: float,
		life: float, r: float, wide: float, dmg: float, knock: float, area: float, st: String) -> void:
	var s := SpellDefinition.new()
	s.id = id
	s.display_name = n
	s.el = el
	s.tier = 1
	s.kind = "dart"
	s.cost = cost
	s.output = cost * 2.0
	s.cast_dur = cd
	s.recover = rec
	s.speed = sp
	s.grav = g
	s.drag = dr
	s.life = life
	s.fx_life = life
	s.r = r
	s.wide = wide
	s.dmg = dmg
	s.knock = knock
	s.area = area
	s.status = st
	s.note = "Dardo del prototipo IsoTerra"
	_add(s)


## Incantesimo elementale di RMNDWN (elementDef): valori mancanti = default del file.
static func _e(id: String, n: String, el: String, tier: int, kind: String, o: Dictionary) -> void:
	var s := SpellDefinition.new()
	s.id = StringName(id)
	s.display_name = n
	s.el = el
	s.tier = tier
	s.kind = kind
	s.output = o.get("output", 20.0)
	s.cast_dur = o.get("cast", 0.4)
	s.recover = o.get("rec", 0.3)
	s.speed = o.get("speed", 10.0)
	s.life = o.get("life", 1.2)
	s.fx_life = o.get("fx", s.life)
	s.r = o.get("r", 0.18)
	s.area = o.get("area", 0.0)
	s.height = o.get("h", 0.0)
	s.width = o.get("w", 0.0)
	s.dmg = o.get("dmg", 18.0)
	s.knock = o.get("kb", 0.8)
	s.at_self = o.get("self", false)
	s.salvo_n = o.get("n", 1)
	s.salvo_gap = o.get("gap", 0.0)
	s.fan_deg = o.get("fan", 0.0)
	s.grav = o.get("grav", 0.0)
	s.dps = o.get("dps", 0.0)
	s.push = o.get("push", 0.0)
	s.reach = o.get("reach", 0.0)
	s.burst_r = o.get("burst_r", 0.0)
	s.burst_dmg = o.get("burst_dmg", 0.0)
	s.burst_knock = o.get("burst_kb", 0.0)
	s.decoh = o.get("decoh", 0.0)
	s.scatter = o.get("scatter", 0.0)
	s.coh_floor = o.get("floor", 1.0)
	s.stagger = o.get("stag", 12.0)
	s.hit_stop = o.get("stop", 0.025)
	s.shake = o.get("shake", 0.006)
	s.sfx = o.get("sfx", 1.0)
	s.fov = o.get("fov", 0.18)
	s.heavy = o.get("heavy", false)
	s.role = o.get("role", "colpo")
	s.hit_at = o.get("at", -1.0)
	s.emit = o.get("emit", 0.0)
	s.r0 = o.get("r0", 0.0)
	s.r1 = o.get("r1", 0.0)
	s.poise = o.get("poise", 0.0)
	s.body_len = o.get("body", 0.0)
	s.burst_stag = o.get("burst_stag", 0.0)
	s.status = o.get("status", {"fire": "burn", "water": "wet", "earth": "slow", "air": "", "karma": ""}[el])
	s.note = o.get("note", "")
	_stance(s)
	_add(s)


## Postura e rinculo del Karma (RMNDWN KARMA_SPELLS stance/impactPose, L32100–L32243):
## [lean, open, wide, both, converge, atk, dec, posa del rinculo].
const KARMA_POSE := {
	"ago": [0.0, -0.02, 0.0, false, 0.0, 0.020, 0.16, {"lower": 0.10, "spine_y": 0.025}],
	"zoltraak": [0.0, 0.0, 0.0, false, 0.0, 0.035, 0.26, {"upper": -0.12, "lower": 0.16, "spine_y": 0.07, "head_y": -0.06}],
	"dardo": [-0.03, -0.04, 0.0, false, 0.0, 0.028, 0.20, {"lower": 0.20, "upper": -0.05, "head_y": -0.03}],
	"tridente": [-0.01, 0.10, 0.06, false, 0.0, 0.026, 0.18, {"lower": 0.18, "upper": -0.07, "spine_y": 0.04}],
	"spina": [0.05, -0.06, 0.0, false, 0.0, 0.038, 0.30, {"upper": -0.17, "lower": 0.21, "spine_y": 0.10, "head_y": -0.08}],
	"orbe": [0.03, 0.10, 0.02, false, 0.0, 0.044, 0.36, {"upper": -0.18, "lower": 0.24, "spine_y": 0.10, "head_y": -0.09}],
	"giudizio": [0.07, 0.18, 0.0, true, 0.36, 0.062, 0.58, {"upper": -0.30, "lower": 0.34, "spine_y": 0.18, "spine_x": -0.09, "head_y": -0.14}],
	"nova": [0.06, 0.18, 0.0, true, 0.30, 0.058, 0.54, {"upper": -0.28, "lower": 0.32, "spine_y": 0.17, "spine_x": -0.08, "head_y": -0.13}],
}


## Glifi del roster (v78 glyph r/poly/ticks e Karma glyph r).
const GLYPH := {"fire_bolt": [.207, 3, 8], "fire_volley": [.221, 3, 6], "fire_jet": [.235, 3, 10], "fire_embers": [.29, 3, 9],
	"fire_ball": [.414, 4, 16], "fire_columns": [.42, 5, 14], "fire_meteor": [.552, 6, 24], "water_hydrant": [.345, 4, 5],
	"water_bolt": [.248, 4, 5], "water_tide": [.442, 4, 8], "water_pressure": [.40, 4, 6], "water_ball": [.455, 4, 7],
	"water_geyser": [.47, 4, 9], "water_rain": [.54, 4, 11], "air_lash": [.359, 3, 4], "air_push": [.40, 3, 5],
	"air_slash": [.42, 3, 6], "air_vacuum": [.50, 3, 7], "air_updraft": [.55, 3, 8], "air_cyclone": [.59, 3, 9],
	"earth_spikes": [.26, 6, 5], "earth_rock": [.28, 6, 5], "earth_wall": [.31, 6, 6], "earth_pillar": [.32, 6, 6],
	"earth_quake": [.42, 6, 8], "ago": [.22, 6, 6], "zoltraak": [.30, 6, 6], "dardo": [.26, 6, 6], "flusso": [.24, 6, 6],
	"tridente": [.28, 6, 6], "spina": [.30, 6, 6], "orbe": [.34, 6, 6], "giudizio": [.60, 6, 6], "nova": [.52, 6, 6]}


static func _stance(s: SpellDefinition) -> void:
	if GLYPH.has(String(s.id)):
		var g: Array = GLYPH[String(s.id)]
		s.glyph_r = g[0]
		s.glyph_poly = g[1]
		s.glyph_ticks = g[2]
		s.glyph_off = 0.17 if s.el == "karma" else 0.12
	if KARMA_POSE.has(String(s.id)):
		var k: Array = KARMA_POSE[String(s.id)]
		s.lean = k[0]
		s.open = k[1]
		s.widen = k[2]
		s.both = k[3]
		s.converge = k[4]
		s.recoil_atk = k[5]
		s.recoil_dec = k[6]
		s.recoil_pose = k[7]
	elif s.el != "karma":
		# elementStance (RMNDWN L20158).
		s.lean = 0.015 * s.tier
		s.open = 0.025 * s.tier
		s.widen = 0.06 if s.role == "area" else 0.0
		s.both = s.tier >= 3
		s.converge = 0.16 if s.tier >= 3 else 0.0


static func _build() -> void:
	# Prototipo IsoTerra (gate R).
	_legacy(&"fire", "Dardo di fuoco", "fire", 14, .36, .22, 16, .16, .12, 1.4, .13, 0, 24, 3.2, 1.1, "burn")
	_legacy(&"water", "Dardo d'acqua", "water", 12, .40, .24, 14, 1.0, .04, 1.7, .14, 0, 20, 4.4, 1.5, "wet")
	_legacy(&"earth", "Masso", "earth", 18, .55, .30, 11, 1.0, 0, 2.2, .22, 0, 34, 6.0, 1.2, "slow")
	_legacy(&"air", "Spina d'aria", "air", 9, .22, .16, 38, 0, 0, .40, .12, .45, 14, 8.0, .9, "pushed")
	# FUOCO (RMNDWN ELEMENTAL_SPELLS L20181–L20225; contatto e vita dalla
	# timeline SpellForge v78: `at` = contatto, `fx` = travel + impatto + residuo).
	_e("fire_bolt", "Proiettile di fuoco", "fire", 1, "bolt", {"output": 25, "cast": .26, "rec": .24, "speed": 21, "life": .8, "fx": .95, "r": .15, "dmg": 24, "stag": 14, "kb": .75})
	_e("fire_volley", "Raffica di fuoco", "fire", 1, "volley", {"output": 35, "cast": .30, "rec": .34, "speed": 19, "life": .8, "fx": 1.05, "r": .10, "dmg": 11, "stag": 7, "kb": .35, "n": 6, "gap": .11, "role": "rosa", "note": "Sei proiettili che convergono sul bersaglio"})
	_e("fire_jet", "Lanciafiamme", "fire", 2, "jet", {"output": 65, "cast": .30, "rec": .42, "fx": 3.1, "emit": 1.6, "w": .58, "area": .62, "dmg": 16, "stag": 10, "kb": .55, "dps": 34, "poise": 16, "reach": 6.5, "r0": .16, "r1": .70, "role": "area", "note": "Getto sostenuto che segue la mira"})
	_e("fire_embers", "Braci", "fire", 2, "spray", {"output": 55, "cast": .38, "rec": .34, "speed": 8, "fx": 3.6, "self": true, "area": 1.9, "dmg": 9, "stag": 5, "kb": .35, "role": "difesa", "note": "Braci tutt'attorno: accendono il suolo, non feriscono"})
	_e("fire_ball", "Palla di fuoco", "fire", 3, "ball", {"output": 125, "cast": .68, "rec": .48, "speed": 6.2, "life": 1.4, "fx": 1.75, "r": .36, "area": 1.55, "dmg": 58, "stag": 42, "kb": 2.0, "heavy": true, "role": "area", "note": "Lenta; all'impatto colpisce tutti nel raggio"})
	_e("fire_columns", "Colonne di fuoco", "fire", 3, "column", {"output": 135, "cast": .72, "rec": .52, "fx": 4.65, "at": .57, "area": 2.1, "h": 3.3, "dmg": 46, "stag": 34, "kb": 1.35, "role": "area", "note": "Sei colonne di fiamma sul punto mirato"})
	_e("fire_meteor", "Meteorite di fuoco", "fire", 4, "meteor", {"output": 240, "cast": .95, "rec": .72, "speed": 21, "life": 1.6, "fx": 1.8, "r": .58, "area": 2.8, "dmg": 118, "stag": 92, "kb": 3.6, "heavy": true, "note": "Cade dal cielo sul punto mirato"})
	# ACQUA.
	_e("water_hydrant", "Idrante", "water", 1, "jet", {"output": 25, "cast": .36, "rec": .30, "fx": 3.7, "emit": 2.0, "w": .20, "area": .38, "dmg": 0, "stag": 10, "kb": 2.8, "dps": 0, "poise": 10, "push": 28, "reach": 7.0, "r0": .10, "r1": .40, "role": "area", "note": "Spinta continua, bagna e rallenta"})
	_e("water_bolt", "Dardo d'acqua", "water", 1, "bolt", {"output": 30, "cast": .34, "rec": .25, "speed": 18, "life": .9, "fx": 1.0, "r": .15, "dmg": 23, "stag": 15, "kb": .85})
	_e("water_tide", "Marea", "water", 2, "wave", {"output": 65, "cast": .62, "rec": .42, "speed": 5.6, "life": 2.0, "fx": 1.75, "w": 3.8, "h": .9, "area": 2.0, "dmg": 18, "stag": 20, "kb": 3.3, "role": "area", "note": "Un'onda larga che avanza"})
	_e("water_pressure", "Getto pressurizzato", "water", 2, "jet", {"output": 70, "cast": .44, "rec": .36, "fx": 2.42, "emit": 1.1, "w": .06, "area": .16, "dmg": 44, "stag": 26, "kb": 2.8, "dps": 56, "poise": 20, "push": 24, "reach": 9.0, "r0": .06, "r1": .16, "note": "Getto sottile e potente"})
	_e("water_ball", "Sfera d'acqua", "water", 3, "ball", {"output": 120, "cast": .66, "rec": .48, "speed": 6.8, "life": 1.4, "fx": 1.7, "r": .42, "area": 1.25, "dmg": 52, "stag": 44, "kb": 3.45, "heavy": true})
	_e("water_geyser", "Geyser", "water", 3, "column", {"output": 130, "cast": .66, "rec": .50, "fx": 3.9, "at": .27, "area": 1.1, "h": 4.3, "dmg": 34, "stag": 38, "kb": 2.8, "role": "area", "note": "Quattro getti verticali attorno al punto mirato"})
	_e("water_rain", "Diluvio", "water", 4, "rain", {"output": 220, "cast": .70, "rec": .66, "fx": 4.8, "emit": 3.6, "at": .36, "area": 2.6, "h": 5.0, "dmg": 42, "stag": 34, "kb": .6, "role": "area", "note": "Pioggia battente ad area"})
	# ARIA.
	_e("air_lash", "Schiocco", "air", 1, "lash", {"output": 20, "cast": .22, "rec": .20, "fx": .72, "at": .44, "r": .08, "dmg": 18, "stag": 9, "kb": 1.15, "note": "Frusta d'aria fino al bersaglio"})
	_e("air_push", "Spinta", "air", 1, "push", {"output": 25, "cast": .26, "rec": .24, "fx": .88, "at": .45, "area": .9, "dmg": 0, "stag": 10, "kb": 3.5, "role": "utilita", "note": "Un'onda d'urto che allontana"})
	_e("air_slash", "Taglio d'aria", "air", 2, "slash", {"output": 55, "cast": .17, "rec": .30, "fx": .82, "at": .04, "area": 1.15, "dmg": 40, "stag": 18, "kb": 1.65, "note": "Mezzaluna che compare sul bersaglio"})
	_e("air_vacuum", "Vuoto", "air", 3, "vacuum", {"output": 120, "cast": .72, "rec": .48, "fx": 2.45, "at": .28, "area": 1.8, "dmg": 0, "stag": 20, "kb": -3.1, "role": "utilita", "note": "Attira verso il centro"})
	_e("air_updraft", "Ascensione", "air", 4, "updraft", {"output": 210, "cast": .95, "rec": .66, "fx": 3.85, "at": 2.3, "area": 1.95, "h": 5.4, "dmg": 0, "stag": 24, "kb": 0, "role": "utilita", "note": "Colonna d'aria che ricade di schianto"})
	_e("air_cyclone", "Ciclone", "air", 4, "cyclone", {"output": 240, "cast": 1.0, "rec": .78, "fx": 3.8, "at": .28, "area": 1.65, "h": 5.0, "dmg": 54, "stag": 34, "kb": 2.3, "role": "area", "note": "Spirale che colpisce e trascina"})
	# TERRA.
	_e("earth_spikes", "Punte", "earth", 1, "spikes", {"output": 30, "cast": .34, "rec": .28, "fx": 1.15, "at": .30, "area": 1.25, "dmg": 30, "stag": 24, "kb": 1.1, "role": "area"})
	_e("earth_rock", "Masso", "earth", 1, "throw", {"output": 35, "cast": .42, "rec": .30, "speed": 14, "life": 2.0, "fx": 1.25, "at": 1.5, "r": .34, "dmg": 36, "stag": 30, "kb": 1.45, "note": "Si compone davanti alla mano, poi vola"})
	_e("earth_wall", "Muraglia", "earth", 2, "wall", {"output": 80, "cast": .55, "rec": .42, "fx": 3.5, "at": .53, "w": 4.8, "h": 2.7, "dmg": 0, "stag": 0, "kb": 0, "role": "difesa", "note": "Muro di terra che sale dal suolo"})
	_e("earth_pillar", "Colonna tellurica", "earth", 2, "pillar", {"output": 78, "cast": .58, "rec": .42, "fx": 2.8, "self": true, "h": 3.35, "dmg": 0, "stag": 0, "kb": 0, "role": "utilita", "note": "Ti solleva su una colonna"})
	_e("earth_quake", "Sisma", "earth", 4, "quake", {"output": 250, "cast": .85, "rec": .78, "fx": 3.85, "at": .31, "area": 3.8, "dmg": 68, "stag": 78, "kb": 2.7, "heavy": true, "role": "area", "note": "Quattro anelli di faglia"})
	# KARMA (materia coerente; roster finale di K122: teste che viaggiano).
	_e("ago", "Ago", "karma", 1, "beam", {"output": 15, "cast": .28, "rec": .20, "speed": 110, "life": .70, "r": .026, "dmg": 18, "stag": 8, "kb": .38, "stop": .018, "shake": .0042, "fov": 0.12, "sfx": 1.36, "decoh": 2.7, "scatter": .42, "floor": .82, "note": "Ago quasi istantaneo"})
	_e("zoltraak", "Zoltraak", "karma", 1, "beam", {"output": 30, "cast": .55, "rec": .34, "speed": 64, "life": .5, "r": .052, "dmg": 42, "stag": 34, "kb": 1.15, "stop": .032, "shake": .0105, "fov": 0.34, "sfx": 1.16, "decoh": 7.6, "scatter": 1.2, "floor": .30, "note": "Raggio: forte da vicino, si disperde lontano"})
	_e("dardo", "Dardo", "karma", 1, "shaft", {"output": 20, "cast": .48, "rec": .26, "speed": 26, "life": .9, "r": .085, "body": 2.40, "dmg": 26, "stag": 20, "kb": .9, "stop": .028, "shake": .0072, "fov": 0.24, "sfx": 1.30, "decoh": 5.2, "scatter": .90, "floor": .62})
	_e("flusso", "Flusso", "karma", 1, "buff", {"output": 20, "cast": .22, "rec": .12, "fx": 4.5, "self": true, "dmg": 0, "stag": 0, "kb": 0, "status": "flow", "note": "Velocità ×1,55 per 4,5 s"})
	_e("tridente", "Tridente", "karma", 2, "shaft", {"output": 60, "cast": .58, "rec": .40, "speed": 31, "life": .78, "r": .074, "body": 2.25, "dmg": 18, "stag": 14, "kb": .72, "stop": .024, "shake": .0068, "fov": 0.23, "sfx": 1.24, "decoh": 5.0, "scatter": .92, "floor": .62, "n": 3, "gap": .045, "fan": 12})
	_e("spina", "Spina", "karma", 2, "beam", {"output": 70, "cast": .62, "rec": .36, "speed": 84, "life": .55, "r": .095, "dmg": 64, "stag": 42, "kb": 1.45, "stop": .038, "shake": .0110, "fov": 0.36, "sfx": 1.10, "decoh": 3.6, "scatter": 1.0, "floor": .64})
	_e("orbe", "Orbe", "karma", 2, "orb", {"output": 85, "cast": .60, "rec": .38, "speed": 20, "life": 1.2, "r": .24, "dmg": 46, "stag": 34, "kb": 1.6, "stop": .040, "shake": .0130, "fov": 0.44, "sfx": .98, "decoh": 4.6, "scatter": .32, "floor": .78, "burst_r": 1.6, "burst_dmg": 22, "burst_stag": 18, "burst_kb": 1.1})
	_e("giudizio", "Giudizio", "karma", 3, "beam", {"output": 175, "cast": 1.20, "rec": .70, "speed": 104, "life": .8, "r": .30, "dmg": 132, "stag": 98, "kb": 3.6, "stop": .075, "shake": .0195, "fov": 0.72, "sfx": .68, "heavy": true, "decoh": 2.2, "scatter": .85, "floor": .60})
	_e("nova", "Nova", "karma", 3, "orb", {"output": 150, "cast": 1.05, "rec": .66, "speed": 27, "life": 1.15, "r": .38, "dmg": 92, "stag": 72, "kb": 3.1, "stop": .062, "shake": .0195, "fov": 0.7, "sfx": .70, "heavy": true, "decoh": 3.4, "scatter": .30, "floor": .82, "burst_r": 2.6, "burst_dmg": 48, "burst_stag": 40, "burst_kb": 2.2})
