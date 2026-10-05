class_name IronArmor
extends RefCounted
## Armatura di ferro da cavaliere (D-051), dalla tavola di concept Higgsfield
## scelta dal proprietario: piastre grigie a blocchi smussati, bordi e borchie
## piu' scuri, cuoio marrone sotto, finiture d'ottone.
## - testa: elmo chiuso con la feritoia degli occhi, prese d'aria, cresta e
##   dischi ai lati con la borchia d'ottone;
## - busto, spalle e braccia in un solo pezzo: corazza col bordo d'ottone a V,
##   gorgiera, spallacci tondi, maniche di cuoio, cubitiere, bracciali e
##   guanti di ferro;
## - gambe: cintura col fibbione, scarselle, cosciali di cuoio, ginocchiere a
##   punta e schinieri;
## - piedi: scarpe di ferro a lamelle con la suola scura.
## Stesse unita' e ossa di `LeatherArmor`.

const BROWN := Color(0.36, 0.21, 0.12)
const BRASS := Color(0.86, 0.66, 0.24)
const SOLE := Color(0.22, 0.22, 0.24)


static func boxes(slot: String, mat: Color) -> Array:
	var out := []
	var dark := mat.darkened(0.38)
	match slot:
		"head":
			_helm(out, mat, dark)
		"chest":
			_cuirass(out, mat, dark)
		"legs":
			_legs(out, mat, dark)
		"feet":
			_sabatons(out, mat, dark)
	return out


static func _b(out: Array, name: String, bone: String, mn: Vector3, mx: Vector3, r: float, col: Color, tw: Callable = Callable()) -> void:
	if tw.is_valid():
		out.append([name, bone, mn, mx, r, col, tw])
	else:
		out.append([name, bone, mn, mx, r, col])


# ---------------------------------------------------------------- testa

static func _helm(out: Array, mat: Color, dark: Color) -> void:
	# Guscio chiuso dietro e ai lati, fino in fondo alla testa.
	_b(out, "elmo", "head", Vector3(-.65, 1.50, -.57), Vector3(.65, 2.76, .44), .16, mat)
	# Davanti: piastra della fronte sopra la feritoia, mentoniera sotto.
	_b(out, "elmo", "head", Vector3(-.65, 2.08, .36), Vector3(.65, 2.76, .67), .10, mat)
	_b(out, "elmo", "head", Vector3(-.65, 1.50, .36), Vector3(.65, 1.84, .69), .08, mat)
	for s in [1, -1]:
		# Ai lati della feritoia (resta aperta solo davanti agli occhi).
		var x0 := .44 if s > 0 else -.65
		var x1 := .65 if s > 0 else -.44
		_b(out, "elmo", "head", Vector3(x0, 1.82, .36), Vector3(x1, 2.10, .67), .04, mat)
		# Disco laterale scuro con la borchia d'ottone.
		var d0 := .62 if s > 0 else -.71
		var d1 := .71 if s > 0 else -.62
		_b(out, "elmo", "head", Vector3(d0, 1.78, -.06), Vector3(d1, 2.22, .34), .04, dark)
		var r0 := .70 if s > 0 else -.75
		var r1 := .75 if s > 0 else -.70
		_b(out, "borchia", "head", Vector3(r0, 1.95, .09), Vector3(r1, 2.05, .19), .02, BRASS)
	# Bordo scuro sopra la feritoia.
	_b(out, "elmo", "head", Vector3(-.66, 2.06, .60), Vector3(.66, 2.13, .69), .02, dark)
	# Prese d'aria sulla mentoniera.
	for x in [-.30, -.10, .10, .30]:
		_b(out, "presa", "head", Vector3(x - .05, 1.60, .685), Vector3(x + .05, 1.72, .70), .005, dark.darkened(0.4))
	# Cresta dalla fronte alla nuca e costola sulla fronte.
	_b(out, "cresta", "head", Vector3(-.07, 2.70, -.46), Vector3(.07, 2.88, .52), .04, dark)
	_b(out, "cresta", "head", Vector3(-.07, 2.30, .62), Vector3(.07, 2.80, .72), .03, dark)


# ---------------------------------------------------------------- busto, spalle e braccia

static func _cuirass(out: Array, mat: Color, dark: Color) -> void:
	cuirass(out, mat, dark)
	sleeves(out, mat, dark)
	pauldrons(out, mat, dark)
	couters(out, mat, dark)
	vambraces(out, mat, dark)
	gauntlets(out, mat, dark)


## Moduli (D-065): ogni pezzo si puo' combinare con quelli degli altri set
## (`ArmorKit`).
static func cuirass(out: Array, mat: Color, dark: Color) -> void:
	var T: Dictionary = HeroChargen.BODY["torso"]
	var tmin: Vector3 = T["min"]
	var tmax: Vector3 = T["max"]
	# Corazza.
	_b(out, "corazza", "torso", Vector3(tmin.x - .06, .84, tmin.z - .06), Vector3(tmax.x + .06, 1.50, tmax.z + .09), .12, mat)
	# Gorgiera scura attorno al collo.
	_b(out, "gorgiera", "torso", Vector3(-.40, 1.42, -.42), Vector3(.40, 1.57, .32), .05, dark)
	# Bordo d'ottone a V sul petto e sulla schiena, e lungo il fondo.
	for a in [0.42, -0.42]:
		var px := -.20 if a > 0 else .20
		var piv := Vector3(px, 1.36, 0)
		_b(out, "bordo", "torso", Vector3(px - .25, 1.33, tmax.z + .08), Vector3(px + .25, 1.39, tmax.z + .12), .01, BRASS, HeroChargen.rot_t(2, a, piv))
		_b(out, "bordo", "torso", Vector3(px - .25, 1.33, tmin.z - .12), Vector3(px + .25, 1.39, tmin.z - .08), .01, BRASS, HeroChargen.rot_t(2, a, piv))
	_b(out, "bordo", "torso", Vector3(tmin.x - .07, .84, tmin.z - .07), Vector3(tmax.x + .07, .90, tmax.z + .10), .02, BRASS)


## Per ogni lato: (osso, X(x0, x1) -> intervallo sul lato, ay, az, segno).
static func _sides(f: Callable) -> void:
	var A: Dictionary = HeroChargen.BODY["arm"]
	var ay: Array = A["y"]
	var az: Array = A["z"]
	for s in [1, -1]:
		var m := "L" if s > 0 else "R"
		var X := func(x0: float, x1: float) -> Vector2:
			return Vector2(x0, x1) if s > 0 else Vector2(-x1, -x0)
		f.call(m, X, ay, az, s)


## Maniche di cuoio sotto le piastre (colore del cuoio, non del metallo).
static func sleeves(out: Array, _mat: Color, _dark: Color, col: Color = BROWN) -> void:
	_sides(func(m: String, X: Callable, ay: Array, az: Array, _s: int) -> void:
		var mx: Vector2 = X.call(.52, .97)
		_b(out, "manica", "arm" + m + "U", Vector3(mx.x, ay[0] - .03, az[0] - .03), Vector3(mx.y, ay[1] + .03, az[1] + .03), .10, col))


## Spallacci tondi e grandi, con la lamella sotto e la borchia.
static func pauldrons(out: Array, mat: Color, dark: Color) -> void:
	_sides(func(m: String, X: Callable, _ay: Array, az: Array, _s: int) -> void:
		var p1: Vector2 = X.call(.42, .88)
		_b(out, "spallaccio", "arm" + m + "U", Vector3(p1.x, 1.30, az[0] - .14), Vector3(p1.y, 1.76, az[1] + .14), .18, mat)
		var p2: Vector2 = X.call(.66, .96)
		_b(out, "spallaccio", "arm" + m + "U", Vector3(p2.x, 1.22, az[0] - .10), Vector3(p2.y, 1.36, az[1] + .10), .05, dark)
		var bx: Vector2 = X.call(.62, .70)
		_b(out, "borchia", "arm" + m + "U", Vector3(bx.x, 1.50, az[1] + .13), Vector3(bx.y, 1.58, az[1] + .17), .01, dark))


## Cubitiere sui gomiti.
static func couters(out: Array, _mat: Color, dark: Color) -> void:
	_sides(func(m: String, X: Callable, ay: Array, az: Array, _s: int) -> void:
		var cx: Vector2 = X.call(.86, .99)
		_b(out, "cubitiera", "arm" + m + "U", Vector3(cx.x, ay[0] - .06, az[0] - .06), Vector3(cx.y, ay[1] + .06, az[1] + .06), .06, dark))


## Bracciali di ferro con due fasce scure.
static func vambraces(out: Array, mat: Color, dark: Color) -> void:
	_sides(func(m: String, X: Callable, ay: Array, az: Array, _s: int) -> void:
		var vx: Vector2 = X.call(.98, 1.20)
		_b(out, "bracciale", "arm" + m + "F", Vector3(vx.x, ay[0] - .05, az[0] - .05), Vector3(vx.y, ay[1] + .05, az[1] + .05), .07, mat)
		for xx in [1.01, 1.15]:
			var fx: Vector2 = X.call(xx, xx + .04)
			_b(out, "fascia", "arm" + m + "F", Vector3(fx.x, ay[0] - .065, az[0] - .065), Vector3(fx.y, ay[1] + .065, az[1] + .065), .02, dark))


## Guanti di ferro con la nocca scura.
static func gauntlets(out: Array, mat: Color, dark: Color) -> void:
	_sides(func(m: String, X: Callable, ay: Array, az: Array, _s: int) -> void:
		var gx: Vector2 = X.call(1.19, 1.48)
		_b(out, "guanto", "arm" + m + "F", Vector3(gx.x, ay[0] - .04, az[0] - .04), Vector3(gx.y, ay[1] + .04, az[1] + .04), .08, mat)
		var kx: Vector2 = X.call(1.30, 1.36)
		_b(out, "guanto", "arm" + m + "F", Vector3(kx.x, ay[0] - .05, az[0] - .05), Vector3(kx.y, ay[1] + .05, az[1] + .05), .02, dark))


# ---------------------------------------------------------------- gambe

static func _legs(out: Array, mat: Color, dark: Color) -> void:
	belt(out, mat, dark)
	tassets(out, mat, dark)
	cuisses(out, mat, dark)
	greaves(out, mat, dark)


## Cintura di cuoio col fibbione d'ottone.
static func belt(out: Array, _mat: Color, _dark: Color) -> void:
	var T: Dictionary = HeroChargen.BODY["torso"]
	var tmin: Vector3 = T["min"]
	var tmax: Vector3 = T["max"]
	_b(out, "cintura", "torso", Vector3(tmin.x - .08, .74, tmin.z - .08), Vector3(tmax.x + .08, .84, tmax.z + .10), .03, BROWN)
	_b(out, "fibbia", "torso", Vector3(-.11, .72, tmax.z + .09), Vector3(.11, .86, tmax.z + .14), .02, BRASS)
	_b(out, "fibbia", "torso", Vector3(-.06, .76, tmax.z + .12), Vector3(.06, .82, tmax.z + .15), .01, BROWN)


## Scarselle: due piastre davanti, una per lato, una dietro, con le borchie.
static func tassets(out: Array, mat: Color, dark: Color) -> void:
	var T: Dictionary = HeroChargen.BODY["torso"]
	var tmin: Vector3 = T["min"]
	var tmax: Vector3 = T["max"]
	for s in [1, -1]:
		var x0 := .04 if s > 0 else -.56
		var x1 := .56 if s > 0 else -.04
		_b(out, "scarsella", "torso", Vector3(x0, .58, tmax.z + .02), Vector3(x1, .78, tmax.z + .12), .04, mat)
		_b(out, "borchia", "torso", Vector3(x0 + .22, .70, tmax.z + .115), Vector3(x0 + .30, .76, tmax.z + .135), .01, dark)
		var sx0 := .56 if s > 0 else -.66
		var sx1 := .66 if s > 0 else -.56
		_b(out, "scarsella", "torso", Vector3(sx0, .58, -.30), Vector3(sx1, .78, .20), .04, mat)
	_b(out, "scarsella", "torso", Vector3(-.56, .58, tmin.z - .12), Vector3(.56, .78, tmin.z - .02), .04, mat)


## Cosciali (di cuoio col set di ferro) con la cinghia.
static func cuisses(out: Array, _mat: Color, _dark: Color, col: Color = BROWN) -> void:
	var L: Dictionary = HeroChargen.BODY["leg"]
	var lz: Array = L["z"]
	for s in [1, -1]:
		var m := "L" if s > 0 else "R"
		var lx: Array = L["x"] if s > 0 else [-L["x"][1], -L["x"][0]]
		_b(out, "cosciale", "leg" + m + "U", Vector3(lx[0] - .02, .40, lz[0] - .03), Vector3(lx[1] + .03, .86, lz[1] + .03), .09, col)
		_b(out, "cinghia", "leg" + m + "U", Vector3(lx[0] - .03, .50, lz[0] - .04), Vector3(lx[1] + .04, .55, lz[1] + .04), .02, BROWN.darkened(0.35))


## Schinieri e ginocchiere a punta (un rombo davanti).
static func greaves(out: Array, mat: Color, dark: Color) -> void:
	var L: Dictionary = HeroChargen.BODY["leg"]
	var lz: Array = L["z"]
	for s in [1, -1]:
		var m := "L" if s > 0 else "R"
		var lx: Array = L["x"] if s > 0 else [-L["x"][1], -L["x"][0]]
		var cx := (float(lx[0]) + float(lx[1])) * .5
		_b(out, "schiniere", "leg" + m + "F", Vector3(lx[0] - .02, .26, lz[0] - .03), Vector3(lx[1] + .03, .46, lz[1] + .05), .07, mat)
		var c := Vector3(cx, .40, lz[1] + .08)
		_b(out, "ginocchiera", "leg" + m + "F", c - Vector3(.12, .12, .05), c + Vector3(.12, .12, .05), .03, mat, HeroChargen.rot_t(2, PI / 4, c))
		_b(out, "ginocchiera", "leg" + m + "F", c - Vector3(.05, .05, -.03), c + Vector3(.05, .05, .07), .02, dark, HeroChargen.rot_t(2, PI / 4, c))


# ---------------------------------------------------------------- piedi

static func _sabatons(out: Array, mat: Color, dark: Color) -> void:
	var L: Dictionary = HeroChargen.BODY["leg"]
	var lz: Array = L["z"]
	for s in [1, -1]:
		var m := "L" if s > 0 else "R"
		var lx: Array = L["x"] if s > 0 else [-L["x"][1], -L["x"][0]]
		_b(out, "scarpa", "leg" + m + "F", Vector3(lx[0] - .03, .03, lz[0] - .04), Vector3(lx[1] + .04, .30, lz[1] + .14), .08, mat)
		_b(out, "suola", "leg" + m + "F", Vector3(lx[0] - .04, -.02, lz[0] - .05), Vector3(lx[1] + .05, .06, lz[1] + .16), .03, SOLE)
		# Lamelle sulla punta e fascia scura in alto.
		for z in [lz[1] + .02, lz[1] + .09]:
			_b(out, "lamella", "leg" + m + "F", Vector3(lx[0] - .035, .05, z), Vector3(lx[1] + .045, .24, z + .03), .01, dark)
		_b(out, "fascia", "leg" + m + "F", Vector3(lx[0] - .05, .24, lz[0] - .06), Vector3(lx[1] + .06, .31, lz[1] + .07), .03, dark)
