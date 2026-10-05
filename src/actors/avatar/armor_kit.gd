class_name ArmorKit
extends RefCounted
## Armature modulari (D-065). Ogni set e' una lista di moduli per slot (elmo,
## corazza, spallacci, maniche, bracciali, guanti, cintura, scarselle,
## cosciali, schinieri, scarpe...) e ogni modulo porta il suo materiale, che lo
## shader degli attori legge per la texture (piastra, cuoio, stoffa, maglia,
## ottone, pelliccia, cordino).
##
## Lo stile di un pezzo puo' essere il nome di un set ("iron", "leather",
## "leather_cap", "leather_hood", "chain") o una lista di moduli separati da
## "+", ognuno con un colore fisso facoltativo dopo "@" (chiave di PALETTE):
## "iron_helm+mail_coif@mail" mette l'elmo nel colore del pezzo e il camaglio
## sempre grigio.

## Materiali nell'alfa del colore dei vertici (1 = automatico: corpo, vestiti).
const PLATE := 0.9
const LEATHER := 0.8
const CLOTH := 0.7
const MAIL := 0.6
const BRASS := 0.5
const FUR := 0.4
const CORD := 0.3

const PALETTE := {
	"leather": Color(0.50, 0.32, 0.18),
	"iron": Color(0.60, 0.61, 0.64),
	"mail": Color(0.58, 0.59, 0.62),
	"blue": Color(0.16, 0.24, 0.52),
	"red": Color(0.55, 0.14, 0.12),
	"fur": Color(0.46, 0.36, 0.26),
}

## Modulo -> [slot di riferimento, materiale].
const MODULES := {
	"iron_helm": ["head", PLATE], "nasal_helm": ["head", PLATE], "mail_coif": ["head", MAIL],
	"leather_cap": ["head", LEATHER], "leather_hood": ["head", LEATHER],
	"iron_cuirass": ["chest", PLATE], "iron_sleeves": ["chest", LEATHER], "iron_pauldrons": ["chest", PLATE],
	"iron_couters": ["chest", PLATE], "iron_vambraces": ["chest", PLATE], "iron_gauntlets": ["chest", PLATE],
	"leather_jerkin": ["chest", LEATHER], "leather_sleeves": ["chest", LEATHER], "leather_pauldrons": ["chest", LEATHER],
	"leather_bracers": ["chest", LEATHER], "mail_hauberk": ["chest", MAIL], "mail_sleeves": ["chest", MAIL],
	"tabard": ["chest", CLOTH], "fur_mantle": ["chest", FUR],
	"iron_belt": ["legs", LEATHER], "iron_tassets": ["legs", PLATE], "iron_cuisses": ["legs", LEATHER],
	"iron_greaves": ["legs", PLATE], "leather_belt": ["legs", LEATHER], "leather_thighs": ["legs", LEATHER],
	"leather_knees": ["legs", LEATHER], "mail_chausses": ["legs", MAIL],
	"iron_sabatons": ["feet", PLATE], "leather_boots": ["feet", LEATHER], "iron_toecaps": ["feet", PLATE],
}

## Set -> slot -> moduli.
const SETS := {
	"iron": {
		"head": "iron_helm",
		"chest": "iron_cuirass+iron_sleeves+iron_pauldrons+iron_couters+iron_vambraces+iron_gauntlets",
		"legs": "iron_belt+iron_tassets+iron_cuisses+iron_greaves",
		"feet": "iron_sabatons",
	},
	"leather": {
		"head": "leather_cap",
		"chest": "leather_jerkin+leather_sleeves+leather_pauldrons+leather_bracers",
		"legs": "leather_belt+leather_thighs+leather_knees",
		"feet": "leather_boots",
	},
	"chain": {
		"head": "mail_coif+nasal_helm@iron",
		"chest": "mail_hauberk+mail_sleeves+tabard@blue+leather_bracers@leather",
		"legs": "mail_chausses+leather_belt@leather+leather_knees@leather",
		"feet": "leather_boots@leather+iron_toecaps@iron",
	},
}


## Moduli di uno slot per uno stile; vuoto = stile sconosciuto.
static func modules_for(slot: String, style: String) -> PackedStringArray:
	var spec := ""
	if style == "leather_cap" or style == "leather_hood":
		spec = style if slot == "head" else String(SETS["leather"].get(slot, ""))
	elif SETS.has(style):
		spec = String(SETS[style].get(slot, ""))
	elif style.contains("+") or MODULES.has(style.get_slice("@", 0)):
		spec = style
	if spec.is_empty():
		return PackedStringArray()
	return spec.split("+", false)


static func knows(slot: String, style: String) -> bool:
	return not modules_for(slot, style).is_empty()


## Pezzi dello slot: [nome, osso, min, max, raggio, colore(alfa = materiale)]
## e, facoltativa, la deformazione.
static func boxes(slot: String, mat: Color, style: String) -> Array:
	var out := []
	for m: String in modules_for(slot, style):
		var name := m.get_slice("@", 0)
		var col := mat
		if m.contains("@"):
			col = PALETTE.get(m.get_slice("@", 1), mat)
		col.a = 1.0
		var part := module(name, col)
		out.append_array(part)
	return out


## Un modulo nel colore `mat`, gia' col materiale nei colori.
static func module(name: String, mat: Color) -> Array:
	var out := []
	var dark := mat.darkened(0.38)
	var ldark := mat.darkened(0.45)
	var lite := mat.lightened(0.10)
	match name:
		"iron_helm":
			IronArmor._helm(out, mat, dark)
		"iron_cuirass":
			IronArmor.cuirass(out, mat, dark)
		"iron_sleeves":
			IronArmor.sleeves(out, mat, dark)
		"iron_pauldrons":
			IronArmor.pauldrons(out, mat, dark)
		"iron_couters":
			IronArmor.couters(out, mat, dark)
		"iron_vambraces":
			IronArmor.vambraces(out, mat, dark)
		"iron_gauntlets":
			IronArmor.gauntlets(out, mat, dark)
		"iron_belt":
			IronArmor.belt(out, mat, dark)
		"iron_tassets":
			IronArmor.tassets(out, mat, dark)
		"iron_cuisses":
			IronArmor.cuisses(out, mat, dark)
		"iron_greaves":
			IronArmor.greaves(out, mat, dark)
		"iron_sabatons":
			IronArmor._sabatons(out, mat, dark)
		"leather_cap":
			LeatherArmor._cap(out, mat, ldark, lite)
		"leather_hood":
			LeatherArmor._hood(out, mat, ldark)
		"leather_jerkin":
			LeatherArmor.jerkin(out, mat, ldark, lite)
		"leather_sleeves":
			LeatherArmor.sleeves(out, mat, ldark, lite)
		"leather_pauldrons":
			LeatherArmor.pauldrons(out, mat, ldark, lite)
		"leather_bracers":
			LeatherArmor.bracers(out, mat, ldark, lite)
		"leather_belt":
			LeatherArmor.belt(out, mat, ldark)
		"leather_thighs":
			LeatherArmor.thighs(out, mat, ldark)
		"leather_knees":
			LeatherArmor.knees(out, mat, ldark)
		"leather_boots":
			LeatherArmor._boots(out, mat, ldark, lite)
		"nasal_helm":
			_nasal_helm(out, mat, dark)
		"mail_coif":
			_mail_coif(out, mat, dark)
		"mail_hauberk":
			_hauberk(out, mat, dark)
		"mail_sleeves":
			_mail_sleeves(out, mat)
		"mail_chausses":
			_chausses(out, mat)
		"tabard":
			_tabard(out, mat)
		"fur_mantle":
			_fur_mantle(out, mat)
		"iron_toecaps":
			_toecaps(out, mat, dark)
	var def: float = MODULES[name][1] if MODULES.has(name) else 1.0
	for b: Array in out:
		var c: Color = b[5]
		b[5] = Color(c.r, c.g, c.b, material_of(c, def))
	return out


## Materiale di un colore nel modulo: ottone e cuciture restano tali, il cuoio
## scuro sotto le piastre e' cuoio.
static func material_of(c: Color, def: float) -> float:
	if _near(c, IronArmor.BRASS):
		return BRASS
	if _near(c, LeatherArmor.CREAM):
		return CORD
	if (def == PLATE or def == MAIL) and c.r > c.b + 0.08 and maxf(c.r, maxf(c.g, c.b)) < 0.45:
		return LEATHER
	return def


static func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.02


# ---------------------------------------------------------------- moduli nuovi (set di maglia)

static func _b(out: Array, name: String, bone: String, mn: Vector3, mx: Vector3, r: float, col: Color, tw: Callable = Callable()) -> void:
	IronArmor._b(out, name, bone, mn, mx, r, col, tw)


## Elmo a nasale: calotta tonda con la fascia e la barra sul naso.
static func _nasal_helm(out: Array, mat: Color, dark: Color) -> void:
	_b(out, "elmo", "head", Vector3(-.69, 2.28, -.62), Vector3(.69, 2.90, .50), .24, mat)
	_b(out, "elmo", "head", Vector3(-.71, 2.26, -.64), Vector3(.71, 2.38, .70), .04, dark)
	_b(out, "elmo", "head", Vector3(-.07, 1.88, .64), Vector3(.07, 2.40, .74), .03, mat)
	_b(out, "elmo", "head", Vector3(-.06, 2.84, -.40), Vector3(.06, 2.96, .42), .04, dark)


## Camaglio di maglia: avvolge testa e collo, aperto davanti al viso, con la
## mantellina sulle spalle.
static func _mail_coif(out: Array, mat: Color, dark: Color) -> void:
	_b(out, "camaglio", "head", Vector3(-.67, 1.50, -.60), Vector3(.67, 2.78, .44), .24, mat)
	_b(out, "camaglio", "head", Vector3(-.67, 2.32, .38), Vector3(.67, 2.78, .64), .10, mat)
	for s in [1, -1]:
		var x0 := .46 if s > 0 else -.67
		var x1 := .67 if s > 0 else -.46
		_b(out, "camaglio", "head", Vector3(x0, 1.50, .38), Vector3(x1, 2.40, .64), .08, mat)
	_b(out, "camaglio", "head", Vector3(-.40, 1.50, .38), Vector3(.40, 1.66, .66), .06, mat)
	_b(out, "mantellina", "torso", Vector3(-.70, 1.30, -.58), Vector3(.70, 1.56, .38), .10, mat)
	_b(out, "mantellina", "torso", Vector3(-.71, 1.28, -.59), Vector3(.71, 1.34, .39), .03, dark)


## Usbergo di maglia fino a meta' coscia.
static func _hauberk(out: Array, mat: Color, dark: Color) -> void:
	var T: Dictionary = HeroChargen.BODY["torso"]
	var tmin: Vector3 = T["min"]
	var tmax: Vector3 = T["max"]
	_b(out, "usbergo", "torso", Vector3(tmin.x - .05, .80, tmin.z - .05), Vector3(tmax.x + .05, 1.50, tmax.z + .06), .10, mat)
	for s in [1, -1]:
		var x0 := .02 if s > 0 else -.62
		var x1 := .62 if s > 0 else -.02
		_b(out, "falda", "torso", Vector3(x0, .48, .04), Vector3(x1, .88, tmax.z + .08), .05, mat)
		_b(out, "falda", "torso", Vector3(x0, .46, .04), Vector3(x1, .52, tmax.z + .09), .02, dark)
	_b(out, "falda", "torso", Vector3(-.62, .48, tmin.z - .08), Vector3(.62, .88, .02), .05, mat)


## Maniche di maglia lunghe fino al polso.
static func _mail_sleeves(out: Array, mat: Color) -> void:
	IronArmor._sides(func(m: String, X: Callable, ay: Array, az: Array, _s: int) -> void:
		var u: Vector2 = X.call(.50, .98)
		_b(out, "manica", "arm" + m + "U", Vector3(u.x, ay[0] - .04, az[0] - .04), Vector3(u.y, ay[1] + .04, az[1] + .04), .10, mat)
		var f: Vector2 = X.call(.97, 1.22)
		_b(out, "manica", "arm" + m + "F", Vector3(f.x, ay[0] - .035, az[0] - .035), Vector3(f.y, ay[1] + .035, az[1] + .035), .08, mat))


## Calze di maglia su cosce e stinchi.
static func _chausses(out: Array, mat: Color) -> void:
	var L: Dictionary = HeroChargen.BODY["leg"]
	var lz: Array = L["z"]
	for s in [1, -1]:
		var m := "L" if s > 0 else "R"
		var lx: Array = L["x"] if s > 0 else [-L["x"][1], -L["x"][0]]
		_b(out, "calza", "leg" + m + "U", Vector3(lx[0] - .02, .40, lz[0] - .035), Vector3(lx[1] + .03, .86, lz[1] + .035), .09, mat)
		_b(out, "calza", "leg" + m + "F", Vector3(lx[0] - .015, .26, lz[0] - .025), Vector3(lx[1] + .025, .46, lz[1] + .03), .07, mat)


## Sopravveste di stoffa davanti e dietro, con l'orlo d'oro e lo stemma.
static func _tabard(out: Array, mat: Color) -> void:
	var T: Dictionary = HeroChargen.BODY["torso"]
	var tmin: Vector3 = T["min"]
	var tmax: Vector3 = T["max"]
	var gold := Color(0.86, 0.68, 0.30)
	for z: Array in [[tmax.z + .06, tmax.z + .10], [tmin.z - .10, tmin.z - .06]]:
		_b(out, "sopravveste", "torso", Vector3(-.34, .46, z[0]), Vector3(.34, 1.40, z[1]), .02, mat)
		_b(out, "orlo", "torso", Vector3(-.35, .44, z[0] - .005), Vector3(.35, .50, z[1] + .005), .01, gold)
	var c := Vector3(0, 1.06, tmax.z + .11)
	_b(out, "stemma", "torso", c - Vector3(.11, .11, .015), c + Vector3(.11, .11, .015), .01, gold, HeroChargen.rot_t(2, PI / 4, c))


## Mantello di pelliccia sulle spalle.
static func _fur_mantle(out: Array, mat: Color) -> void:
	_b(out, "pelliccia", "torso", Vector3(-.74, 1.30, -.62), Vector3(.74, 1.64, .40), .16, mat)
	_b(out, "pelliccia", "torso", Vector3(-.66, .80, -.66), Vector3(.66, 1.40, -.50), .06, mat.darkened(0.15))


## Puntali di ferro sugli stivali.
static func _toecaps(out: Array, mat: Color, dark: Color) -> void:
	var L: Dictionary = HeroChargen.BODY["leg"]
	var lz: Array = L["z"]
	for s in [1, -1]:
		var m := "L" if s > 0 else "R"
		var lx: Array = L["x"] if s > 0 else [-L["x"][1], -L["x"][0]]
		_b(out, "puntale", "leg" + m + "F", Vector3(lx[0] - .035, .02, lz[1] + .02), Vector3(lx[1] + .045, .20, lz[1] + .145), .05, mat)
		_b(out, "puntale", "leg" + m + "F", Vector3(lx[0] - .04, .16, lz[1] + .02), Vector3(lx[1] + .05, .21, lz[1] + .15), .01, dark)
