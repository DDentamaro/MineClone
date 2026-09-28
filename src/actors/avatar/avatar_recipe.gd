class_name AvatarRecipe
extends RefCounted
## Ricetta dell'eroe (D-028): il DNA di CHARGEN del prototipo (`HeroChargen`),
## salvato nelle impostazioni (sezione "avatar"). L'editor fa scorrere le
## scelte del prototipo (acconciatura, cappello, occhi, barba, abiti...) e le
## palette dei colori.

## Campo dell'editor -> [chiave del DNA, tipo]: "opt" = OPTIONS di CHARGEN,
## "col" = palette di colori, "bool" = si/no.
const FIELDS := {
	"skin": ["skin", "col"], "hair": ["hair", "col"], "hairStyle": ["hairStyle", "opt"], "hat": ["hat", "opt"],
	"eyes": ["eyes", "opt"], "brows": ["brows", "opt"], "nose": ["nose", "opt"], "mouth": ["mouth", "opt"],
	"beard": ["beard", "opt"], "scar": ["scar", "opt"], "paint": ["paint", "opt"], "face": ["face", "opt"],
	"shirt": ["shirt", "col"], "pants": ["pants", "col"], "boots": ["boots", "col"], "accent": ["accent", "col"],
	"sleeves": ["sleeves", "opt"], "legs": ["legs", "opt"], "belt": ["belt", "opt"], "back": ["back", "opt"],
	"eye": ["eye", "col"], "tuft": ["tuft", "bool"], "ears": ["ears", "bool"], "freckles": ["freckles", "bool"],
}
const NAMES := {"skin": "Pelle", "hair": "Capelli", "hairStyle": "Acconciatura", "hat": "Cappello", "eyes": "Occhi",
	"brows": "Sopracciglia", "nose": "Naso", "mouth": "Bocca", "beard": "Barba", "scar": "Cicatrice", "paint": "Pittura",
	"face": "Viso", "shirt": "Maglia", "pants": "Pantaloni", "boots": "Stivali", "accent": "Dettagli", "sleeves": "Maniche",
	"legs": "Gambe", "belt": "Cintura", "back": "Schiena", "eye": "Iridi", "tuft": "Ciuffo", "ears": "Orecchie", "freckles": "Lentiggini"}

var dna := HeroChargen.preset(0)


func _palette(field: String) -> Array:
	match field:
		"skin":
			return HeroChargen.SKINS
		"hair":
			return HeroChargen.HAIRS
		"boots":
			return HeroChargen.BOOTS
		"accent":
			return HeroChargen.ACCENTS
		"eye":
			return HeroChargen.EYE_COLS
	return HeroChargen.CLOTH


## Scelta successiva dell'editor; restituisce l'etichetta aggiornata.
func cycle(field: String) -> String:
	if not FIELDS.has(field):
		return field
	var f: Array = FIELDS[field]
	var key: String = f[0]
	match String(f[1]):
		"opt":
			var o: Array = HeroChargen.OPTIONS[key]
			var i := 0
			for k in o.size():
				if o[k][0] == dna.get(key):
					i = k
			dna[key] = o[(i + 1) % o.size()][0]
		"col":
			var pal := _palette(field)
			dna[key] = pal[(pal.find(dna.get(key)) + 1) % pal.size()]
			if field == "hair":
				dna["brow"] = dna[key]
				dna["beardCol"] = dna[key]
		"bool":
			dna[key] = not bool(dna.get(key, false))
	return label(field)


func label(field: String) -> String:
	if not FIELDS.has(field):
		return field
	var f: Array = FIELDS[field]
	var key: String = f[0]
	var v: Variant = dna.get(key)
	match String(f[1]):
		"opt":
			for o: Array in HeroChargen.OPTIONS[key]:
				if o[0] == v:
					return "%s: %s" % [NAMES[field], o[1]]
		"col":
			return "%s %d" % [NAMES[field], _palette(field).find(v) + 1]
		"bool":
			return "%s %s" % [NAMES[field], "si" if v else "no"]
	return NAMES[field]


## Eroi predefiniti ("Eroe 1", "Eroe 2" come nel prototipo).
static func preset(i: int) -> AvatarRecipe:
	var r := AvatarRecipe.new()
	r.dna = HeroChargen.preset(i)
	return r


static func random(seed_value: int) -> AvatarRecipe:
	var r := AvatarRecipe.new()
	r.dna = HeroChargen.random_dna(seed_value)
	return r


## Ricetta come testo JSON (da copiare e incollare, come #c-dna del prototipo).
func to_json() -> String:
	return JSON.stringify(to_dict())


## null se il testo non e' una ricetta valida.
static func from_json(text: String) -> AvatarRecipe:
	var j := JSON.new()
	if j.parse(text) != OK:
		return null
	var d: Variant = j.data
	if not (d is Dictionary) or int((d as Dictionary).get("v", 0)) != 2:
		return null
	return from_dict(d)


func to_dict() -> Dictionary:
	return dna.duplicate()


## Le chiavi sconosciute si ignorano; i valori mancanti o non validi restano
## quelli di "Eroe 1". Le ricette della v1 (eroe di M4) danno "Eroe 1".
static func from_dict(d: Dictionary) -> AvatarRecipe:
	var r := AvatarRecipe.new()
	if int(d.get("v", 0)) != 2:
		return r
	for k: String in HeroChargen.BASE:
		if not d.has(k) or k == "v":
			continue
		var v: Variant = d[k]
		var base: Variant = HeroChargen.BASE[k]
		if base is bool:
			r.dna[k] = bool(v)
		elif base is int or base is float:
			r.dna[k] = int(v)
		elif HeroChargen.OPTIONS.has(k):
			for o: Array in HeroChargen.OPTIONS[k]:
				if o[0] == v:
					r.dna[k] = v
		elif String(v).begins_with("#") and String(v).length() == 7 and Color.html_is_valid(String(v)):
			r.dna[k] = String(v)
	return r


func save() -> void:
	Settings.save_value("avatar", "recipe", to_dict())


static func load_saved() -> AvatarRecipe:
	var d: Variant = Settings.load_value("avatar", "recipe", {})
	return from_dict(d if d is Dictionary else {})
