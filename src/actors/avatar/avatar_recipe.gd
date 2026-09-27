class_name AvatarRecipe
extends RefCounted
## Ricetta dell'eroe (M4): palette e proporzioni scelte nell'editor, salvate
## nelle impostazioni (sezione "avatar"). Disegno nuovo, non la CHARGEN del
## prototipo (D-022): pochi parametri leggibili, ognuno con un elenco di
## scelte che l'editor fa scorrere.

const SKINS: Array[Color] = [Color(0.93, 0.76, 0.60), Color(0.80, 0.60, 0.44), Color(0.62, 0.43, 0.30), Color(0.42, 0.28, 0.20), Color(0.97, 0.84, 0.72)]
const HAIRS: Array[Color] = [Color(0.22, 0.14, 0.09), Color(0.55, 0.33, 0.14), Color(0.86, 0.70, 0.36), Color(0.12, 0.11, 0.12), Color(0.70, 0.26, 0.12), Color(0.82, 0.82, 0.78)]
const CLOTHES: Array[Color] = [Color(0.20, 0.42, 0.62), Color(0.62, 0.20, 0.18), Color(0.28, 0.48, 0.26), Color(0.52, 0.38, 0.62), Color(0.78, 0.62, 0.26), Color(0.30, 0.30, 0.34)]
const PANTS: Array[Color] = [Color(0.30, 0.24, 0.18), Color(0.20, 0.22, 0.30), Color(0.42, 0.36, 0.26), Color(0.18, 0.18, 0.18)]
const HAIR_STYLES := ["corti", "ciuffo", "coda", "rasati", "lunghi"]
const BUILDS := ["snello", "medio", "robusto"]

var skin := 0
var hair := 0
var hair_style := 0
var shirt := 0
var pants := 0
var build := 1


func skin_color() -> Color:
	return SKINS[skin % SKINS.size()]


func hair_color() -> Color:
	return HAIRS[hair % HAIRS.size()]


func shirt_color() -> Color:
	return CLOTHES[shirt % CLOTHES.size()]


func pants_color() -> Color:
	return PANTS[pants % PANTS.size()]


## Larghezza del busto e degli arti per la corporatura.
func width() -> float:
	return [0.88, 1.0, 1.16][build % BUILDS.size()]


## Parametro successivo dell'editor; restituisce l'etichetta aggiornata.
func cycle(field: String) -> String:
	match field:
		"skin":
			skin = (skin + 1) % SKINS.size()
		"hair":
			hair = (hair + 1) % HAIRS.size()
		"hair_style":
			hair_style = (hair_style + 1) % HAIR_STYLES.size()
		"shirt":
			shirt = (shirt + 1) % CLOTHES.size()
		"pants":
			pants = (pants + 1) % PANTS.size()
		"build":
			build = (build + 1) % BUILDS.size()
	return label(field)


func label(field: String) -> String:
	match field:
		"skin":
			return "Pelle %d" % (skin + 1)
		"hair":
			return "Capelli %d" % (hair + 1)
		"hair_style":
			return String(HAIR_STYLES[hair_style]).capitalize()
		"shirt":
			return "Veste %d" % (shirt + 1)
		"pants":
			return "Brache %d" % (pants + 1)
		"build":
			return String(BUILDS[build]).capitalize()
	return field


static func random(seed_value: int) -> AvatarRecipe:
	var r := AvatarRecipe.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	r.skin = rng.randi() % SKINS.size()
	r.hair = rng.randi() % HAIRS.size()
	r.hair_style = rng.randi() % HAIR_STYLES.size()
	r.shirt = rng.randi() % CLOTHES.size()
	r.pants = rng.randi() % PANTS.size()
	r.build = rng.randi() % BUILDS.size()
	return r


func to_dict() -> Dictionary:
	return {"v": 1, "skin": skin, "hair": hair, "hair_style": hair_style, "shirt": shirt, "pants": pants, "build": build}


static func from_dict(d: Dictionary) -> AvatarRecipe:
	var r := AvatarRecipe.new()
	if int(d.get("v", 0)) != 1:
		return r
	r.skin = clampi(int(d.get("skin", 0)), 0, SKINS.size() - 1)
	r.hair = clampi(int(d.get("hair", 0)), 0, HAIRS.size() - 1)
	r.hair_style = clampi(int(d.get("hair_style", 0)), 0, HAIR_STYLES.size() - 1)
	r.shirt = clampi(int(d.get("shirt", 0)), 0, CLOTHES.size() - 1)
	r.pants = clampi(int(d.get("pants", 0)), 0, PANTS.size() - 1)
	r.build = clampi(int(d.get("build", 1)), 0, BUILDS.size() - 1)
	return r


func save() -> void:
	Settings.save_value("avatar", "recipe", to_dict())


static func load_saved() -> AvatarRecipe:
	var d: Variant = Settings.load_value("avatar", "recipe", {})
	return from_dict(d if d is Dictionary else {})
