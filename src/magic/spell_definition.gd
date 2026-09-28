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
## Descrizione breve per il libro.
var note := ""


func is_legacy() -> bool:
	return kind == "dart"


## Le due mani servono dai 120 di Output (RMNDWN K56).
func two_handed() -> bool:
	return output >= 120.0


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
	s.status = o.get("status", {"fire": "burn", "water": "wet", "earth": "slow", "air": "", "karma": ""}[el])
	s.note = o.get("note", "")
	_add(s)


static func _build() -> void:
	# Prototipo IsoTerra (gate R).
	_legacy(&"fire", "Dardo di fuoco", "fire", 14, .36, .22, 16, .16, .12, 1.4, .13, 0, 24, 3.2, 1.1, "burn")
	_legacy(&"water", "Dardo d'acqua", "water", 12, .40, .24, 14, 1.0, .04, 1.7, .14, 0, 20, 4.4, 1.5, "wet")
	_legacy(&"earth", "Masso", "earth", 18, .55, .30, 11, 1.0, 0, 2.2, .22, 0, 34, 6.0, 1.2, "slow")
	_legacy(&"air", "Spina d'aria", "air", 9, .22, .16, 38, 0, 0, .40, .12, .45, 14, 8.0, .9, "pushed")
	# FUOCO (RMNDWN ELEMENTAL_SPELLS, tempi SpellForge v78).
	_e("fire_bolt", "Proiettile di fuoco", "fire", 1, "bolt", {"output": 25, "cast": .26, "rec": .24, "speed": 21, "life": .8, "r": .15, "dmg": 24, "kb": .75})
	_e("fire_volley", "Raffica di fuoco", "fire", 1, "volley", {"output": 35, "cast": .30, "rec": .34, "speed": 19, "life": .8, "r": .10, "dmg": 11, "kb": .35, "n": 6, "gap": .11, "fan": 8, "note": "Sei proiettili a ventaglio"})
	_e("fire_jet", "Lanciafiamme", "fire", 2, "jet", {"output": 65, "cast": .30, "rec": .42, "fx": 1.45, "w": .58, "area": .62, "dmg": 16, "kb": .55, "dps": 34, "reach": 6.5, "note": "Getto sostenuto che segue la mira"})
	_e("fire_embers", "Braci", "fire", 2, "spray", {"output": 55, "cast": .38, "rec": .34, "speed": 8, "fx": 1.55, "self": true, "area": 1.9, "dmg": 9, "kb": .35, "note": "Anello di braci attorno a sé"})
	_e("fire_ball", "Palla di fuoco", "fire", 3, "ball", {"output": 125, "cast": .68, "rec": .48, "speed": 6.2, "life": 1.4, "r": .36, "area": 1.55, "dmg": 58, "kb": 2.0, "burst_r": 1.55, "burst_dmg": 29, "burst_kb": 1.4, "note": "Lenta, esplode ad area"})
	_e("fire_columns", "Colonne di fuoco", "fire", 3, "column", {"output": 135, "cast": .72, "rec": .52, "fx": 1.8, "area": 2.1, "h": 3.3, "dmg": 46, "kb": 1.35, "note": "Fiamme dal suolo nel punto mirato"})
	_e("fire_meteor", "Meteorite di fuoco", "fire", 4, "meteor", {"output": 240, "cast": .95, "rec": .72, "speed": 21, "life": 1.6, "r": .58, "area": 2.8, "dmg": 118, "kb": 3.6, "burst_r": 2.8, "burst_dmg": 60, "burst_kb": 2.6, "note": "Cade dal cielo sul punto mirato"})
	# ACQUA.
	_e("water_hydrant", "Idrante", "water", 1, "jet", {"output": 25, "cast": .36, "rec": .30, "fx": 1.45, "w": .20, "area": .38, "dmg": 0, "kb": 2.8, "dps": 0, "push": 28, "reach": 7.0, "note": "Spinta continua, bagna"})
	_e("water_bolt", "Proiettile d'acqua", "water", 1, "bolt", {"output": 30, "cast": .34, "rec": .25, "speed": 18, "life": .9, "r": .15, "dmg": 23, "kb": .85})
	_e("water_tide", "Marea", "water", 2, "wave", {"output": 65, "cast": .62, "rec": .42, "speed": 5.6, "life": 2.0, "fx": 1.75, "w": 3.8, "h": .9, "area": 2.0, "dmg": 18, "kb": 3.3, "note": "Un'onda larga che avanza"})
	_e("water_pressure", "Getto pressurizzato", "water", 2, "jet", {"output": 70, "cast": .44, "rec": .36, "fx": 1.25, "w": .06, "area": .16, "dmg": 44, "kb": 2.8, "dps": 56, "push": 24, "reach": 9.0, "note": "Getto sottile e potente"})
	_e("water_ball", "Sfera d'acqua", "water", 3, "ball", {"output": 120, "cast": .66, "rec": .48, "speed": 6.8, "life": 1.4, "r": .42, "area": 1.25, "dmg": 52, "kb": 3.45, "burst_r": 1.25, "burst_dmg": 24, "burst_kb": 2.4})
	_e("water_geyser", "Geyser", "water", 3, "column", {"output": 130, "cast": .66, "rec": .50, "fx": 1.75, "area": 1.1, "h": 4.3, "dmg": 34, "kb": 2.8, "note": "Getto verticale che lancia in aria"})
	_e("water_rain", "Diluvio", "water", 4, "rain", {"output": 220, "cast": .70, "rec": .66, "fx": 2.15, "area": 2.6, "h": 5.0, "dmg": 42, "kb": .6, "note": "Pioggia battente ad area"})
	# ARIA.
	_e("air_lash", "Schiocco", "air", 1, "lash", {"output": 20, "cast": .22, "rec": .20, "fx": .72, "r": .08, "dmg": 18, "kb": 1.15, "note": "Frusta d'aria rapida"})
	_e("air_push", "Spinta", "air", 1, "push", {"output": 25, "cast": .26, "rec": .24, "fx": .88, "area": .9, "dmg": 0, "kb": 3.5, "status": "pushed", "note": "Allontana tutto ciò che ha davanti"})
	_e("air_slash", "Taglio d'aria", "air", 2, "slash", {"output": 55, "cast": .17, "rec": .30, "fx": .82, "area": 1.15, "dmg": 40, "kb": 1.65})
	_e("air_vacuum", "Vuoto", "air", 3, "vacuum", {"output": 120, "cast": .72, "rec": .48, "fx": 1.65, "area": 1.8, "dmg": 0, "kb": -3.1, "note": "Attira verso il centro"})
	_e("air_updraft", "Ascensione", "air", 4, "updraft", {"output": 210, "cast": .95, "rec": .66, "fx": 2.1, "area": 1.95, "h": 5.4, "dmg": 0, "kb": 0, "note": "Solleva in aria"})
	_e("air_cyclone", "Ciclone", "air", 4, "cyclone", {"output": 240, "cast": 1.0, "rec": .78, "fx": 2.5, "area": 1.65, "h": 5.0, "dmg": 54, "kb": 2.3, "note": "Spirale che colpisce e trascina"})
	# TERRA.
	_e("earth_spikes", "Punte", "earth", 1, "spikes", {"output": 30, "cast": .34, "rec": .28, "fx": 1.15, "area": 1.25, "dmg": 30, "kb": 1.1})
	_e("earth_rock", "Masso scagliato", "earth", 1, "throw", {"output": 35, "cast": .42, "rec": .30, "speed": 14, "life": 2.0, "r": .34, "dmg": 36, "kb": 1.45, "grav": .42})
	_e("earth_wall", "Muraglia", "earth", 2, "wall", {"output": 80, "cast": .55, "rec": .42, "fx": 6.0, "w": 4.8, "h": 2.7, "dmg": 0, "kb": 0, "note": "Muro di terra per qualche secondo"})
	_e("earth_pillar", "Colonna tellurica", "earth", 2, "pillar", {"output": 78, "cast": .58, "rec": .42, "fx": 8.0, "self": true, "h": 3.35, "dmg": 0, "kb": 0, "note": "Ti solleva su una colonna"})
	_e("earth_quake", "Sisma", "earth", 4, "quake", {"output": 250, "cast": .85, "rec": .78, "fx": 2.7, "area": 3.8, "dmg": 68, "kb": 2.7, "note": "Quattro anelli di faglia"})
	# KARMA (materia neutra; roster K29 con l'Output di K33).
	_e("ago", "Ago", "karma", 1, "beam", {"output": 15, "cast": .28, "rec": .20, "speed": 110, "life": .70, "r": .026, "dmg": 18, "kb": .38, "decoh": 2.7, "scatter": .42, "floor": .82, "n": 3, "gap": .032, "fan": 6, "note": "Tre aghi quasi istantanei"})
	_e("zoltraak", "Zoltraak", "karma", 1, "beam", {"output": 30, "cast": .55, "rec": .34, "speed": 64, "life": .5, "r": .052, "dmg": 42, "kb": 1.15, "decoh": 7.6, "scatter": 1.2, "floor": .30, "note": "Raggio: forte da vicino, si disperde lontano"})
	_e("dardo", "Dardo", "karma", 1, "shaft", {"output": 20, "cast": .48, "rec": .26, "speed": 26, "life": .9, "r": .055, "dmg": 26, "kb": .9, "decoh": 11, "scatter": 1.4, "floor": .5})
	_e("flusso", "Flusso", "karma", 1, "buff", {"output": 20, "cast": .22, "rec": .12, "fx": 4.5, "self": true, "dmg": 0, "kb": 0, "status": "flow", "note": "Velocità ×1,55 per 4,5 s"})
	_e("tridente", "Tridente", "karma", 2, "shaft", {"output": 60, "cast": .58, "rec": .40, "speed": 31, "life": .78, "r": .074, "dmg": 18, "kb": .72, "decoh": 5.0, "scatter": .92, "floor": .62, "n": 3, "gap": .045, "fan": 12})
	_e("spina", "Spina", "karma", 2, "beam", {"output": 70, "cast": .62, "rec": .36, "speed": 84, "life": .55, "r": .095, "dmg": 64, "kb": 1.45, "decoh": 3.6, "scatter": 1.0, "floor": .64, "n": 2, "gap": .055})
	_e("orbe", "Orbe", "karma", 2, "orb", {"output": 85, "cast": .60, "rec": .38, "speed": 20, "life": 1.2, "r": .24, "dmg": 46, "kb": 1.6, "decoh": 4.6, "scatter": .32, "floor": .78, "burst_r": 1.6, "burst_dmg": 22, "burst_kb": 1.1})
	_e("giudizio", "Giudizio", "karma", 3, "beam", {"output": 175, "cast": 1.20, "rec": .70, "speed": 104, "life": .8, "r": .30, "dmg": 132, "kb": 3.6, "decoh": 2.2, "scatter": .85, "floor": .60})
	_e("nova", "Nova", "karma", 3, "orb", {"output": 150, "cast": 1.05, "rec": .66, "speed": 27, "life": 1.15, "r": .38, "dmg": 92, "kb": 3.1, "decoh": 3.4, "scatter": .30, "floor": .82, "burst_r": 2.6, "burst_dmg": 48, "burst_kb": 2.2})
