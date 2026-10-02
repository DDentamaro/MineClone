class_name LeatherArmor
extends RefCounted
## Armatura di cuoio (D-051), dalle tavole di concept Higgsfield approvate dal
## proprietario: quattro pezzi a blocchi smussati nello stile dell'eroe, tre
## toni (cuoio, cinghie scure, ottone) e cuciture color crema a trattini.
## - testa: casco unico (guscio fino alla mascella, sottogola) o cappuccio a punta
##   (incornicia il viso, mantellina sulle spalle);
## - busto, spalle e braccia in un solo pezzo: giubba col colletto, cinghie
##   incrociate con fibbia, falda corta, maniche, spallacci a due lamelle,
##   bracciali con lacci incrociati;
## - gambe: cosciali con cinghia, ginocchiere, cintura con fibbia e borsello;
## - piedi: stivali a meta' polpaccio col risvolto e la suola scura.
## Unita' del modello CHARGEN (+Z davanti, +X sinistra anatomica, braccia
## distese lungo X); ogni pezzo sta su un solo osso.

const SOLE := Color(0.20, 0.12, 0.07)
const BRASS := Color(0.86, 0.66, 0.24)
const CREAM := Color(0.93, 0.85, 0.64)


static func boxes(slot: String, mat: Color, style: String) -> Array:
	var out := []
	var dark := mat.darkened(0.45)
	var lite := mat.lightened(0.10)
	match slot:
		"head":
			if style == "leather_hood":
				_hood(out, mat, dark)
			else:
				_cap(out, mat, dark, lite)
		"chest":
			_jerkin(out, mat, dark, lite)
		"legs":
			_legs(out, mat, dark)
		"feet":
			_boots(out, mat, dark, lite)
	return out


static func _b(out: Array, name: String, bone: String, mn: Vector3, mx: Vector3, r: float, col: Color, tw: Callable = Callable()) -> void:
	if tw.is_valid():
		out.append([name, bone, mn, mx, r, col, tw])
	else:
		out.append([name, bone, mn, mx, r, col])


## Cuciture: `n` trattini color crema da `a` a `b` (spessore `t`).
static func _stitch(out: Array, bone: String, a: Vector3, b: Vector3, n: int, t: float = 0.025) -> void:
	for i in n:
		var u := (float(i) + 0.5) / n
		var c := a.lerp(b, u)
		var d := (b - a) / n * 0.28
		var h := Vector3(maxf(absf(d.x), t), maxf(absf(d.y), t), maxf(absf(d.z), t))
		out.append(["cucitura", bone, c - h, c + h, 0.008, CREAM])


# ---------------------------------------------------------------- testa

static func _cap(out: Array, mat: Color, dark: Color, lite: Color) -> void:
	# D-051: casco unico, senza parti scoperte. Un guscio tondo copre sopra,
	# lati, orecchie e nuca fino alla mascella; davanti una fascia sulla fronte
	# e due guanciali lasciano libero solo il viso.
	_b(out, "casco", "head", Vector3(-.63, 1.54, -.54), Vector3(.63, 2.72, .42), .24, mat)
	_b(out, "casco", "head", Vector3(-.63, 2.24, .36), Vector3(.63, 2.72, .62), .16, mat)
	for s in [1, -1]:
		var x0 := .44 if s > 0 else -.63
		var x1 := .63 if s > 0 else -.44
		_b(out, "casco", "head", Vector3(x0, 1.70, .36), Vector3(x1, 2.30, .62), .08, mat)
		# Costole cucite ai lati della calotta e sui guanciali.
		_stitch(out, "head", Vector3(s * .36, 2.735, .50), Vector3(s * .36, 2.735, -.40), 5)
		_stitch(out, "head", Vector3(s * .645, 1.70, -.30), Vector3(s * .645, 2.56, -.30), 5)
		_stitch(out, "head", Vector3(s * .535, 1.78, .635), Vector3(s * .535, 2.22, .635), 3)
	_stitch(out, "head", Vector3(0, 2.735, .50), Vector3(0, 2.735, -.40), 5)
	_stitch(out, "head", Vector3(-.40, 2.30, .635), Vector3(.40, 2.30, .635), 5)
	# Bordo scuro in basso tutto attorno.
	_b(out, "casco", "head", Vector3(-.645, 1.52, -.555), Vector3(.645, 1.62, .435), .04, dark)
	# Sottogola scuro con la fibbia d'ottone sul lato sinistro.
	_b(out, "casco", "head", Vector3(-.58, 1.44, .14), Vector3(.58, 1.52, .26), .02, dark)
	for s in [1, -1]:
		var x0 := .52 if s > 0 else -.60
		var x1 := .60 if s > 0 else -.52
		_b(out, "casco", "head", Vector3(x0, 1.46, .14), Vector3(x1, 1.74, .26), .02, dark)
	_b(out, "casco", "head", Vector3(.54, 1.46, .12), Vector3(.66, 1.58, .28), .02, BRASS)


static func _hood(out: Array, mat: Color, dark: Color) -> void:
	# Guscio che avvolge testa e capelli, aperto solo davanti al viso.
	_b(out, "cappuccio", "head", Vector3(-.66, 1.56, -.58), Vector3(.66, 2.78, .44), .24, mat)
	for s in [1, -1]:
		_stitch(out, "head", Vector3(s * .675, 1.70, -.10), Vector3(s * .675, 2.60, -.10), 6)
	# Cornice spessa attorno al viso (sopra le sopracciglia e ai lati).
	_b(out, "cappuccio", "head", Vector3(-.66, 2.30, .40), Vector3(.66, 2.78, .64), .10, mat)
	for s in [1, -1]:
		var x0 := .46 if s > 0 else -.66
		var x1 := .66 if s > 0 else -.46
		_b(out, "cappuccio", "head", Vector3(x0, 1.56, .40), Vector3(x1, 2.40, .64), .08, mat)
		_stitch(out, "head", Vector3(s * .56, 1.66, .655), Vector3(s * .56, 2.30, .655), 4)
	_stitch(out, "head", Vector3(-.44, 2.40, .655), Vector3(.44, 2.40, .655), 5)
	# Punta del cappuccio che scende dietro, a gradini come nel concept.
	_b(out, "cappuccio", "head", Vector3(-.40, 2.20, -.82), Vector3(.40, 2.74, -.52), .10, mat)
	_b(out, "cappuccio", "head", Vector3(-.22, 2.30, -1.02), Vector3(.22, 2.64, -.78), .07, mat)
	_b(out, "cappuccio", "head", Vector3(-.10, 2.38, -1.16), Vector3(.10, 2.56, -.98), .04, mat)
	# Mantellina sulle spalle (sta sul busto: segue il corpo, non la testa).
	_b(out, "mantellina", "torso", Vector3(-.66, 1.36, -.56), Vector3(.66, 1.56, .36), .08, mat)
	_b(out, "mantellina", "torso", Vector3(-.68, 1.33, -.58), Vector3(.68, 1.40, .38), .03, dark)
	_stitch(out, "torso", Vector3(-.56, 1.47, .385), Vector3(.56, 1.47, .385), 6)


# ---------------------------------------------------------------- busto, spalle e braccia

static func _jerkin(out: Array, mat: Color, dark: Color, lite: Color) -> void:
	var T: Dictionary = HeroChargen.BODY["torso"]
	var tmin: Vector3 = T["min"]
	var tmax: Vector3 = T["max"]
	# Giubba imbottita.
	_b(out, "giubba", "torso", Vector3(tmin.x - .06, .80, tmin.z - .06), Vector3(tmax.x + .06, 1.50, tmax.z + .07), .10, mat)
	# Colletto rialzato.
	_b(out, "giubba", "torso", Vector3(-.38, 1.42, -.42), Vector3(.38, 1.56, .30), .05, lite)
	# Falda corta sotto la vita, in due lembi davanti e uno dietro.
	for s in [1, -1]:
		var x0 := .02 if s > 0 else -.60
		var x1 := .60 if s > 0 else -.02
		_b(out, "falda", "torso", Vector3(x0, .70, .06), Vector3(x1, .90, tmax.z + .10), .04, mat)
		_stitch(out, "torso", Vector3(x0 + .06, .735, tmax.z + .105), Vector3(x1 - .06, .735, tmax.z + .105), 3)
	_b(out, "falda", "torso", Vector3(-.60, .70, tmin.z - .09), Vector3(.60, .90, .00), .04, mat)
	_stitch(out, "torso", Vector3(-.52, .735, tmin.z - .095), Vector3(.52, .735, tmin.z - .095), 6)
	# Cinghie incrociate davanti e dietro, fibbia d'ottone al centro del petto.
	var piv := Vector3(0, 1.15, 0)
	for a in [0.72, -0.72]:
		_b(out, "cinghia", "torso", Vector3(-.065, .74, tmax.z + .06), Vector3(.065, 1.56, tmax.z + .12), .02, dark, HeroChargen.rot_t(2, a, piv))
		_b(out, "cinghia", "torso", Vector3(-.065, .74, tmin.z - .12), Vector3(.065, 1.56, tmin.z - .06), .02, dark, HeroChargen.rot_t(2, a, piv))
	_b(out, "fibbia", "torso", Vector3(-.11, 1.04, tmax.z + .10), Vector3(.11, 1.26, tmax.z + .15), .02, BRASS, HeroChargen.rot_t(2, PI / 4, Vector3(0, 1.15, 0)))
	_b(out, "fibbia", "torso", Vector3(-.055, 1.095, tmax.z + .13), Vector3(.055, 1.205, tmax.z + .165), .01, dark, HeroChargen.rot_t(2, PI / 4, Vector3(0, 1.15, 0)))
	var A: Dictionary = HeroChargen.BODY["arm"]
	var ay: Array = A["y"]
	var az: Array = A["z"]
	for s in [1, -1]:
		var m := "L" if s > 0 else "R"
		var X := func(x0: float, x1: float) -> Vector2:
			return Vector2(x0, x1) if s > 0 else Vector2(-x1, -x0)
		# Manica fino al gomito.
		var mx: Vector2 = X.call(.52, .97)
		_b(out, "manica", "arm" + m + "U", Vector3(mx.x, ay[0] - .04, az[0] - .04), Vector3(mx.y, ay[1] + .04, az[1] + .04), .10, mat)
		# Spallacci a due lamelle con il bordo cucito.
		var p1: Vector2 = X.call(.46, .82)
		_b(out, "spallaccio", "arm" + m + "U", Vector3(p1.x, 1.42, az[0] - .10), Vector3(p1.y, 1.68, az[1] + .10), .08, mat)
		var p2: Vector2 = X.call(.66, .96)
		_b(out, "spallaccio", "arm" + m + "U", Vector3(p2.x, 1.36, az[0] - .08), Vector3(p2.y, 1.62, az[1] + .08), .07, lite)
		_stitch(out, "arm" + m + "U", Vector3(s * .66, 1.45, az[1] + .185), Vector3(s * .66, 1.63, az[1] + .185), 2)
		_stitch(out, "arm" + m + "U", Vector3(s * .84, 1.40, az[1] + .165), Vector3(s * .84, 1.58, az[1] + .165), 2)
		# Bracciale scuro sull'avambraccio con i lacci incrociati color crema.
		var bx: Vector2 = X.call(.98, 1.20)
		_b(out, "bracciale", "arm" + m + "F", Vector3(bx.x, ay[0] - .05, az[0] - .05), Vector3(bx.y, ay[1] + .05, az[1] + .05), .07, dark)
		var c := Vector3(s * 1.09, (ay[0] + ay[1]) * .5, az[1] + .06)
		for a in [0.6, -0.6]:
			_b(out, "laccio", "arm" + m + "F", c - Vector3(.018, .17, .012), c + Vector3(.018, .17, .012), .006, CREAM, HeroChargen.rot_t(2, a, c))


# ---------------------------------------------------------------- gambe

static func _legs(out: Array, mat: Color, dark: Color) -> void:
	var L: Dictionary = HeroChargen.BODY["leg"]
	var lz: Array = L["z"]
	var T: Dictionary = HeroChargen.BODY["torso"]
	var tmin: Vector3 = T["min"]
	var tmax: Vector3 = T["max"]
	# Cintura bassa con la fibbia e il borsello sul fianco sinistro.
	_b(out, "cintura", "torso", Vector3(tmin.x - .07, .74, tmin.z - .07), Vector3(tmax.x + .07, .84, tmax.z + .08), .03, dark)
	_b(out, "fibbia", "torso", Vector3(-.10, .72, tmax.z + .07), Vector3(.10, .86, tmax.z + .12), .02, BRASS)
	_b(out, "fibbia", "torso", Vector3(-.05, .76, tmax.z + .10), Vector3(.05, .82, tmax.z + .13), .01, dark)
	_b(out, "borsello", "torso", Vector3(.52, .58, -.16), Vector3(.68, .82, .14), .04, dark)
	_b(out, "borsello", "torso", Vector3(.53, .74, -.17), Vector3(.69, .84, .15), .03, mat)
	for s in [1, -1]:
		var m := "L" if s > 0 else "R"
		var lx: Array = L["x"] if s > 0 else [-L["x"][1], -L["x"][0]]
		# Cosciale con la cinghia scura e la fibbia.
		_b(out, "cosciale", "leg" + m + "U", Vector3(lx[0] - .02, .40, lz[0] - .04), Vector3(lx[1] + .03, .86, lz[1] + .04), .09, mat)
		_b(out, "cinghia", "leg" + m + "U", Vector3(lx[0] - .03, .54, lz[0] - .05), Vector3(lx[1] + .04, .60, lz[1] + .05), .02, dark)
		var cx := (float(lx[0]) + float(lx[1])) * .5
		_b(out, "fibbia", "leg" + m + "U", Vector3(cx - .05, .53, lz[1] + .04), Vector3(cx + .05, .61, lz[1] + .07), .01, BRASS)
		_stitch(out, "leg" + m + "U", Vector3(lx[1] + .035 if s > 0 else lx[0] - .025, .64, 0), Vector3(lx[1] + .035 if s > 0 else lx[0] - .025, .78, 0), 2)
		# Pantalone sotto il ginocchio e ginocchiera imbottita (sullo stinco).
		_b(out, "gambale", "leg" + m + "F", Vector3(lx[0] - .02, .28, lz[0] - .03), Vector3(lx[1] + .03, .46, lz[1] + .03), .08, mat)
		_b(out, "ginocchiera", "leg" + m + "F", Vector3(lx[0] + .05, .30, lz[1]), Vector3(lx[1] - .04, .50, lz[1] + .09), .05, dark)


# ---------------------------------------------------------------- piedi

static func _boots(out: Array, mat: Color, dark: Color, lite: Color) -> void:
	var L: Dictionary = HeroChargen.BODY["leg"]
	var lz: Array = L["z"]
	for s in [1, -1]:
		var m := "L" if s > 0 else "R"
		var lx: Array = L["x"] if s > 0 else [-L["x"][1], -L["x"][0]]
		# Stivale con la punta in avanti, suola scura, risvolto chiaro cucito.
		_b(out, "stivale", "leg" + m + "F", Vector3(lx[0] - .02, .03, lz[0] - .03), Vector3(lx[1] + .03, .30, lz[1] + .12), .08, mat)
		_b(out, "suola", "leg" + m + "F", Vector3(lx[0] - .03, -.02, lz[0] - .04), Vector3(lx[1] + .04, .06, lz[1] + .14), .03, SOLE)
		_b(out, "risvolto", "leg" + m + "F", Vector3(lx[0] - .05, .26, lz[0] - .06), Vector3(lx[1] + .06, .37, lz[1] + .06), .04, lite)
		_stitch(out, "leg" + m + "F", Vector3(lx[0] + .02, .315, lz[1] + .065), Vector3(lx[1] - .01, .315, lz[1] + .065), 3)
		_b(out, "fascia", "leg" + m + "F", Vector3(lx[0] - .03, .16, lz[0] - .04), Vector3(lx[1] + .04, .21, lz[1] + .05), .02, dark)
