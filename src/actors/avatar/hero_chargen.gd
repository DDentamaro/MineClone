class_name HeroChargen
extends RefCounted
## Eroe del prototipo (D-028): porting di CHARGEN v2 e CHARGEN.rig (HTML
## 4246–4481). Personaggio "a cubi smussati" costruito dal codice da una
## ricetta (DNA): scatole con smusso ad arco a 3 segmenti (rbox) o piatto
## (rbox1), placche del viso, capelli, cappelli, barbe, accessori; occlusione
## cotta nella posa di riposo; pezzi riespressi nei sistemi locali delle ossa
## di `AvatarRig`.
##
## Unita' del modello: alto 2,84, +Z davanti, +X sinistra anatomica. Nel rig
## il personaggio guarda -Z con la destra su +X: dopo la mappatura del
## prototipo si ruota di 180° attorno a Y (resta anatomicamente corretto).

const C30 := 0.8660254
const S30 := 0.5
const IN := [0.7333, 0.4750, 0.4750]
const SEG := 3

const BODY := {
	"head": {"min": Vector3(-.539, 1.493, -.419), "max": Vector3(.539, 2.571, .539), "r": .12, "cutY": 1.789, "nape": .102, "napeZ": -.298},
	"torso": {"min": Vector3(-.524, .737, -.479), "max": Vector3(.524, 1.493, .269), "r": .12},
	"arm": {"x0": .515, "x1": 1.446, "y": [1.125, 1.549], "z": [-.332, .204], "r": .12, "cuts": [.794, .874, .954, 1.034], "elbow": .914, "lap": .085, "shoulder": [.54, 1.34, -.064]},
	"leg": {"x": [.010, .499], "y": [.003, .755], "z": [-.332, .204], "r": .12, "cuts": [.305, .369, .434], "knee": .369, "lap": .085},
	"ear": {"min": Vector3(.413, 1.863, .018), "max": Vector3(.678, 2.203, .190), "r": .030},
	"brow": {"min": Vector3(.202, 2.100, .424), "max": Vector3(.563, 2.212, .552), "r": .011},
	"eye": {"x": [.285, .376], "y": [1.857, 2.047], "z": .540},
	"bun": {"min": Vector3(-.421, 2.554, .188), "max": Vector3(.340, 2.839, .481), "r": .078},
	"neck": 1.493,
}
const FZ := 0.5395

const OPTIONS := {
	"hairStyle": [["none", "Rasato"], ["orig1", "Ciuffo originale"], ["orig2", "Lungo originale"], ["corto", "Corto"], ["ciuffo", "Ciuffo di lato"], ["scodella", "Scodella"], ["caschetto", "Caschetto"], ["lungo", "Lungo dietro"], ["cresta", "Cresta"], ["coda", "Coda"], ["chignon", "Chignon"], ["codini", "Codini"], ["spettinato", "Spettinato"], ["ricci", "Ricci"], ["trecce", "Trecce"], ["stempiato", "Stempiato"]],
	"hat": [["none", "Niente"], ["fascia", "Fascia"], ["cappuccio", "Cappuccio"], ["elmo", "Elmo"], ["paglia", "Cappello di paglia"], ["punta", "Cappello a punta"], ["corona", "Corona"], ["corna", "Corna"]],
	"eyes": [["alto", "Alti"], ["punto", "A punto"], ["grande", "Grandi"], ["stretto", "Stretti"], ["chiuso", "Chiusi"], ["assonnato", "Assonnati"], ["cattivo", "Taglienti"]],
	"brows": [["dritte", "Dritte"], ["spesse", "Spesse"], ["arrabbiate", "Arrabbiate"], ["tristi", "Tristi"], ["unite", "Unite"], ["none", "Niente"]],
	"nose": [["none", "Niente"], ["piccolo", "Piccolo"], ["grosso", "Grosso"], ["punta", "A punta"]],
	"mouth": [["none", "Niente"], ["linea", "Linea"], ["sorriso", "Sorriso"], ["aperta", "Aperta"], ["ghigno", "Ghigno"]],
	"beard": [["none", "Niente"], ["baffi", "Baffi"], ["manubrio", "Baffi a manubrio"], ["pizzetto", "Pizzetto"], ["mosca", "Mosca"], ["basette", "Basette"], ["corta", "Barba corta"], ["barbone", "Barbone"]],
	"scar": [["none", "Niente"], ["occhio", "Sull'occhio"], ["guancia", "Sulla guancia"], ["croce", "A croce"], ["labbro", "Sul labbro"], ["graffi", "Tre graffi"]],
	"paint": [["none", "Niente"], ["strisce", "Strisce"], ["banda", "Banda sugli occhi"], ["mezza", "Mezzo viso"], ["mento", "Mento"]],
	"face": [["none", "Niente"], ["benda", "Benda sull'occhio"], ["occhiali", "Occhiali"], ["scuri", "Occhiali scuri"], ["monocolo", "Monocolo"], ["bandana", "Bandana sul viso"], ["orecchini", "Orecchini"]],
	"sleeves": [["corte", "Corte"], ["lunghe", "Lunghe"], ["senza", "Senza"], ["guanti", "Con guanti"]],
	"legs": [["corti", "Corti"], ["lunghi", "Lunghi"], ["stivali", "Con stivali"]],
	"belt": [["none", "Niente"], ["cintura", "Cintura"], ["fusciacca", "Fusciacca"]],
	"back": [["none", "Niente"], ["mantello", "Mantello"], ["zaino", "Zaino"], ["sciarpa", "Sciarpa"]],
}
const BASE := {"v": 2, "seed": 7, "skin": "#cfa78b", "hair": "#cf9f41", "brow": "#cf9f41", "beardCol": "#cf9f41", "eye": "#297e7b",
	"shirt": "#7e260e", "pants": "#375a71", "boots": "#4b3623", "accent": "#d9a441", "paintCol": "#b3321f",
	"hairStyle": "orig1", "tuft": true, "hat": "none", "eyes": "alto", "brows": "dritte", "nose": "none", "mouth": "none",
	"beard": "none", "scar": "none", "paint": "none", "face": "none", "freckles": false, "ears": true, "sleeves": "corte",
	"legs": "corti", "belt": "none", "back": "none"}
const SKINS := ["#cfa78b", "#e8c4a0", "#b98a66", "#876e5b", "#5e4636", "#f0d2b6", "#9fb27a", "#a9a0c8"]
const HAIRS := ["#cf9f41", "#583e2a", "#1f1a17", "#8a3b1c", "#b9b4a6", "#e9e2cf", "#2f8f8a", "#7a2f6b"]
const CLOTH := ["#7e260e", "#297e7b", "#6b7a2a", "#c9a227", "#4a3a6b", "#d8d2bd", "#2a2f24", "#375a71", "#8a5a2b", "#3d647e"]
const BOOTS := ["#4b3623", "#2a2f24", "#5e4636", "#1f1a17"]
const ACCENTS := ["#d9a441", "#b3321f", "#2f8f8a", "#d8d2bd", "#4a3a6b", "#6b7a2a"]
const EYE_COLS := ["#297e7b", "#343434", "#3b5fa8", "#6b4a1f", "#5d8a3a", "#9a2d2d"]

## Misure del rig (CHARGEN.rig): anca .32, collo .80, omero .21,
## avambraccio+mano .28, coscia .15, stinco+piede .185; testa ×.54.
const S := 0.54
const HIP_Y := 0.32
const NECK_Y := 0.80
const UPPER := 0.21
const FORE_HAND := 0.28
const THIGH := 0.15
const SHIN_FOOT := 0.185


static func preset(i: int) -> Dictionary:
	var d := BASE.duplicate()
	if posmod(i, 2) == 1:
		d.merge({"skin": "#876e5b", "hair": "#583e2a", "brow": "#583e2a", "beardCol": "#583e2a", "eye": "#343434",
			"shirt": "#297e7b", "pants": "#3d647e", "hairStyle": "orig2", "tuft": false, "ears": false}, true)
	return d


# ---------------------------------------------------------------- generatore del prototipo

## Mulberry32 come `rng(seed)` del prototipo: stessi numeri per lo stesso seme.
class Mulberry:
	extends RefCounted
	var a := 1

	func _init(seed_value: int) -> void:
		a = seed_value & 0xffffffff
		if a == 0:
			a = 1

	func next() -> float:
		a = (a + 0x6D2B79F5) & 0xffffffff
		var t := _imul(a ^ (a >> 15), 1 | a)
		t = ((t + _imul(t ^ (t >> 7), 61 | t)) & 0xffffffff) ^ t
		return float((t ^ (t >> 14)) & 0xffffffff) / 4294967296.0

	static func _imul(x: int, y: int) -> int:
		return (x * y) & 0xffffffff


static func random_dna(seed_value: int) -> Dictionary:
	var R := Mulberry.new(seed_value)
	var pick := func(a: Array) -> Variant: return a[floori(R.next() * a.size())]
	var opt := func(k: String, w: float) -> String:
		var o: Array = OPTIONS[k]
		return String(o[0][0]) if R.next() < w else String(o.slice(1)[floori(R.next() * (o.size() - 1))][0])
	var hair: String = pick.call(HAIRS)
	var styles: Array = OPTIONS["hairStyle"].filter(func(o: Array) -> bool: return o[0] != "orig1" and o[0] != "orig2")
	var hs: String = pick.call(styles)[0]
	var d := BASE.duplicate()
	d["seed"] = floori(R.next() * 1e6)
	d["skin"] = pick.call(SKINS.slice(0, 6)) if R.next() < 0.85 else pick.call(SKINS)
	d["hair"] = hair
	d["brow"] = hair
	d["beardCol"] = hair if R.next() < 0.8 else pick.call(HAIRS)
	d["eye"] = pick.call(EYE_COLS)
	d["shirt"] = pick.call(CLOTH)
	d["pants"] = pick.call(CLOTH)
	d["boots"] = pick.call(BOOTS)
	d["accent"] = pick.call(ACCENTS)
	d["paintCol"] = pick.call(["#b3321f", "#1f1a17", "#e9e2cf", "#2f6f9a"])
	d["hairStyle"] = hs
	d["tuft"] = R.next() < 0.25
	d["hat"] = opt.call("hat", 0.62)
	d["eyes"] = pick.call(OPTIONS["eyes"])[0]
	d["brows"] = pick.call(OPTIONS["brows"])[0]
	d["nose"] = opt.call("nose", 0.35)
	d["mouth"] = opt.call("mouth", 0.35)
	d["beard"] = opt.call("beard", 0.5)
	d["scar"] = opt.call("scar", 0.7)
	d["paint"] = opt.call("paint", 0.85)
	d["face"] = opt.call("face", 0.72)
	d["freckles"] = R.next() < 0.2
	d["ears"] = R.next() < 0.8
	d["sleeves"] = pick.call(OPTIONS["sleeves"])[0]
	d["legs"] = pick.call(OPTIONS["legs"])[0]
	d["belt"] = opt.call("belt", 0.45)
	d["back"] = opt.call("back", 0.6)
	return d


static func hex(h: String) -> Color:
	return Color.html(h) if h.begins_with("#") and h.length() == 7 else Color.MAGENTA


static func rgb(r: int, g: int, b: int) -> Color:
	return Color8(r, g, b)


## Scatola smussata ad arco (rbox): triangoli + scatola interna per orientare le facce.
static func rbox(mn: Vector3, mx: Vector3, r0: float, color: Variant, cuts: Dictionary = {}, tweak: Callable = Callable()) -> Dictionary:
	var r := minf(r0, minf((mx.x - mn.x) / 2 - 1e-4, minf((mx.y - mn.y) / 2 - 1e-4, (mx.z - mn.z) / 2 - 1e-4)))
	var lo := mn + Vector3(r, r, r)
	var hi := mx - Vector3(r, r, r)
	var T: Array = []
	var st: Array = []
	for a in 3:
		var l: Array = [lo[a]]
		var cs: Array = []
		for v: float in cuts.get("xyz"[a], []):
			if v > lo[a] + 1e-6 and v < hi[a] - 1e-6:
				cs.append(v)
		cs.sort()
		l.append_array(cs)
		l.append(hi[a])
		st.append(l)
	# Facce piane.
	for a in 3:
		var b := (a + 1) % 3
		var c := (a + 2) % 3
		for s in [-1, 1]:
			var sb: Array = st[b]
			var sc: Array = st[c]
			for i in sb.size() - 1:
				for k in sc.size() - 1:
					var A := _q(a, b, c, mx[a] if s > 0 else mn[a], sb[i], sc[k])
					var B := _q(a, b, c, mx[a] if s > 0 else mn[a], sb[i + 1], sc[k])
					var Cc := _q(a, b, c, mx[a] if s > 0 else mn[a], sb[i + 1], sc[k + 1])
					var D := _q(a, b, c, mx[a] if s > 0 else mn[a], sb[i], sc[k + 1])
					T.append([A, B, Cc])
					T.append([A, Cc, D])
	# Spigoli ad arco.
	for a in 3:
		var b := (a + 1) % 3
		var c := (a + 2) % 3
		var sa: Array = st[a]
		for sb in [-1, 1]:
			for sc in [-1, 1]:
				for i in sa.size() - 1:
					for g in SEG:
						var t0 := g * PI / 2 / SEG
						var t1 := (g + 1) * PI / 2 / SEG
						var c0 := _q(a, b, c, sa[i], hi[b] if sb > 0 else lo[b], hi[c] if sc > 0 else lo[c])
						var c1 := _q(a, b, c, sa[i + 1], hi[b] if sb > 0 else lo[b], hi[c] if sc > 0 else lo[c])
						var d0 := _q(a, b, c, 0.0, sb * cos(t0), sc * sin(t0))
						var d1 := _q(a, b, c, 0.0, sb * cos(t1), sc * sin(t1))
						var A := c0 + d0 * r
						var B := c1 + d0 * r
						var Cc := c1 + d1 * r
						var D := c0 + d1 * r
						T.append([A, B, Cc])
						T.append([A, Cc, D])
	# Angoli: toppa a 13 triangoli misurata sul modello.
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			for sz in [-1, 1]:
				var sv := Vector3(sx, sy, sz)
				var co := Vector3(hi.x if sx > 0 else lo.x, hi.y if sy > 0 else lo.y, hi.z if sz > 0 else lo.z)
				var Dp := func(v: Vector3) -> Vector3: return co + r * v * sv
				var pole := func(ax: int) -> Vector3:
					var v := Vector3.ZERO
					v[ax] = 1.0
					return Dp.call(v)
				var near := func(ax: int, bx: int) -> Vector3:
					var v := Vector3.ZERO
					v[ax] = C30
					v[bx] = S30
					return Dp.call(v)
				var inn := func(ax: int) -> Vector3:
					var v := Vector3(IN[1], IN[1], IN[1])
					v[ax] = IN[0]
					return Dp.call(v)
				for a in 3:
					var b := (a + 1) % 3
					var cc := (a + 2) % 3
					T.append([pole.call(a), near.call(a, b), inn.call(a)])
					T.append([pole.call(a), inn.call(a), near.call(a, cc)])
					T.append([near.call(a, b), near.call(b, a), inn.call(b)])
					T.append([near.call(a, b), inn.call(b), inn.call(a)])
				T.append([inn.call(0), inn.call(1), inn.call(2)])
	return {"tris": T, "lo": lo, "hi": hi, "color": color, "tweak": tweak, "flat": false, "plate": false}


static func _q(a: int, b: int, c: int, va: float, vb: float, vc: float) -> Vector3:
	var p := Vector3.ZERO
	p[a] = va
	p[b] = vb
	p[c] = vc
	return p


## Scatola a smusso piatto (rbox1): 44 triangoli, normali piatte.
static func rbox1(mn: Vector3, mx: Vector3, r0: float, color: Variant, tweak: Callable = Callable()) -> Dictionary:
	var r := minf(r0, minf((mx.x - mn.x) / 2 - 1e-4, minf((mx.y - mn.y) / 2 - 1e-4, (mx.z - mn.z) / 2 - 1e-4)))
	var lo := mn + Vector3(r, r, r)
	var hi := mx - Vector3(r, r, r)
	var T: Array = []
	for a in 3:
		var b := (a + 1) % 3
		var c := (a + 2) % 3
		for s in [-1, 1]:
			var f: float = mx[a] if s > 0 else mn[a]
			T.append([_q(a, b, c, f, lo[b], lo[c]), _q(a, b, c, f, hi[b], lo[c]), _q(a, b, c, f, hi[b], hi[c])])
			T.append([_q(a, b, c, f, lo[b], lo[c]), _q(a, b, c, f, hi[b], hi[c]), _q(a, b, c, f, lo[b], hi[c])])
		for sb in [-1, 1]:
			for sc in [-1, 1]:
				var e1 := func(x: float) -> Vector3: return _q(a, b, c, x, mx[b] if sb > 0 else mn[b], hi[c] if sc > 0 else lo[c])
				var e0 := func(x: float) -> Vector3: return _q(a, b, c, x, hi[b] if sb > 0 else lo[b], mx[c] if sc > 0 else mn[c])
				T.append([e1.call(lo[a]), e1.call(hi[a]), e0.call(hi[a])])
				T.append([e1.call(lo[a]), e0.call(hi[a]), e0.call(lo[a])])
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			for sz in [-1, 1]:
				var sv := [sx, sy, sz]
				var tri: Array = []
				for a in 3:
					var p := Vector3.ZERO
					for i in 3:
						p[i] = hi[i] if sv[i] > 0 else lo[i]
					p[a] = mx[a] if sv[a] > 0 else mn[a]
					tri.append(p)
				T.append(tri)
	return {"tris": T, "lo": lo, "hi": hi, "color": color, "tweak": tweak, "flat": true, "plate": false}


static func plate(x0: float, x1: float, y0: float, y1: float, z: float, color: Color, tweak: Callable = Callable()) -> Dictionary:
	var a := Vector3(x0, y0, z)
	var b := Vector3(x1, y0, z)
	var c := Vector3(x1, y1, z)
	var d := Vector3(x0, y1, z)
	return {"tris": [[a, b, c], [a, c, d]], "color": color, "tweak": tweak, "flat": true, "plate": true}


static func tri3(a: Vector3, b: Vector3, c: Vector3, color: Color) -> Dictionary:
	return {"tris": [[a, b, c]], "color": color, "flat": true, "plate": true, "tweak": Callable()}


static func rot_t(ax: int, ang: float, piv: Vector3) -> Callable:
	var c := cos(ang)
	var s := sin(ang)
	var i := (ax + 1) % 3
	var j := (ax + 2) % 3
	return func(p: Vector3) -> Vector3:
		var u := p[i] - piv[i]
		var v := p[j] - piv[j]
		p[i] = piv[i] + u * c - v * s
		p[j] = piv[j] + u * s + v * c
		return p


static func taper_t(y0: float, y1: float, s0: float, s1: float, cx: float, cz: float) -> Callable:
	return func(p: Vector3) -> Vector3:
		var t := clampf((p.y - y0) / (y1 - y0), 0.0, 1.0)
		var k := s0 + (s1 - s0) * t
		p.x = cx + (p.x - cx) * k
		p.z = cz + (p.z - cz) * k
		return p


static func _key(p: Vector3) -> Vector3i:
	return Vector3i(roundi(p.x * 1e4), roundi(p.y * 1e4), roundi(p.z * 1e4))


## finish: facce verso l'esterno, ritocco, normali morbide per posizione saldata
## (o piatte), vertici separati per colore. Triangoli con normale uscente in
## senso antiorario (come three.js); la conversione al fronte di Godot e' in `_mesh`.
static func finish(part: Dictionary) -> Dictionary:
	var nsum := {}
	var out: Array = []
	var has_inner := part.has("lo")
	var tw: Callable = part.get("tweak", Callable())
	for t: Array in part["tris"]:
		var A: Vector3 = t[0]
		var B: Vector3 = t[1]
		var C: Vector3 = t[2]
		if has_inner:
			var n0 := (B - A).cross(C - A)
			var g := (A + B + C) / 3.0
			var q := g.clamp(part["lo"], part["hi"])
			if (g - q).dot(n0) < 0.0:
				var s := B
				B = C
				C = s
		var g0 := (A + B + C) / 3.0
		var col: Color = (part["color"] as Callable).call(g0) if part["color"] is Callable else part["color"]
		if tw.is_valid():
			A = tw.call(A)
			B = tw.call(B)
			C = tw.call(C)
		var n := (B - A).cross(C - A)
		if n.length() < 1e-12:
			continue
		for p in [A, B, C]:
			var k := _key(p)
			nsum[k] = nsum.get(k, Vector3.ZERO) + n
		out.append([A, B, C, col, n])
	var pos := PackedVector3Array()
	var nor := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var vmap := {}
	var flat: bool = part.get("flat", false)
	for t: Array in out:
		for j in 3:
			var p: Vector3 = t[j]
			var c: Color = t[3]
			var nn: Vector3 = t[4]
			var k := [_key(p), c.to_rgba32(), _key(nn.normalized()) if flat else Vector3i.ZERO]
			var i: int = vmap.get(k, -1)
			if i < 0:
				i = pos.size()
				vmap[k] = i
				pos.append(p)
				var sn: Vector3 = nn if flat else nsum[_key(p)]
				nor.append(sn.normalized())
				cols.append(c)
			idx.append(i)
	return {"position": pos, "normal": nor, "color": cols, "index": idx}


# ---------------------------------------------------------------- costruzione

class Builder:
	extends RefCounted
	var parts: Array = []
	var hair_lib := {}

	func add(name: String, bone: String, part: Dictionary, occ: Variant = null, zone: String = "") -> void:
		var geo := HeroChargen.finish(part)
		if (geo["index"] as PackedInt32Array).is_empty():
			return
		parts.append({"name": name, "bone": bone, "geo": geo, "occ": (occ if occ != null else not part.get("plate", false)), "zone": zone})


static func build(dna: Dictionary, hair_lib: Dictionary = {}) -> Array:
	var W := Builder.new()
	W.hair_lib = hair_lib
	var Cl := {}
	for k in ["skin", "hair", "brow", "beardCol", "eye", "shirt", "pants", "boots", "accent", "paintCol"]:
		Cl[k] = hex(String(dna.get(k, BASE[k])))
	var dark := rgb(38, 30, 26)
	var white := rgb(236, 232, 220)
	var skin: Color = Cl["skin"]
	var scar_c := skin.lerp(rgb(150, 70, 66), 0.55)
	var metal := rgb(150, 156, 160)
	var metal_d := rgb(96, 102, 108)
	var gold := rgb(217, 164, 65)
	var H: Dictionary = BODY["head"]
	# Elmo dell'armatura (D-030): il cappello non si disegna e i capelli sopra
	# si nascondono come sotto i cappelli coprenti del prototipo.
	var helm: bool = dna.get("helm", false)
	var hat := "none" if helm else String(dna.get("hat", "none"))
	var hides_top := helm or hat in ["cappuccio", "elmo", "paglia", "punta"]
	var cut_y: float = H["cutY"]
	var nape_z: float = H["napeZ"]
	var nape: float = H["nape"]
	W.add("testa", "head", rbox(H["min"], H["max"], H["r"], skin, {"y": [cut_y]}, func(p: Vector3) -> Vector3:
		if absf(p.y - cut_y) < 1e-4 and p.z <= nape_z:
			p.z -= nape
		return p))
	var Tb: Dictionary = BODY["torso"]
	W.add("busto", "torso", rbox(Tb["min"], Tb["max"], Tb["r"], Cl["shirt"], {"x": [-.041, .041], "y": [1.057]}))
	# Arti: due scatole chiuse per arto, sovrapposte al giunto.
	var sl: float = {"corte": .874, "lunghe": 1.30, "senza": .56, "guanti": .874}.get(String(dna.get("sleeves", "corte")), .874)
	var glove := 1.18 if dna.get("sleeves") == "guanti" else 9.0
	var pl: float = {"corti": .369, "lunghi": .125, "stivali": .369}.get(String(dna.get("legs", "corti")), .369)
	var boot := .34 if dna.get("legs") == "stivali" else -9.0
	var A: Dictionary = BODY["arm"]
	var L: Dictionary = BODY["leg"]
	for s in [1, -1]:
		var t := "L" if s > 0 else "R"
		var arm_col := func(g: Vector3) -> Color:
			var x := absf(g.x)
			return Cl["shirt"] if x < sl else (Cl["boots"] if x > glove else skin)
		var acuts: Array = []
		for v: float in A["cuts"] + [sl, glove if glove < 9.0 else 0.0]:
			if v > A["x0"] + A["r"] and v < A["x1"] - A["r"]:
				acuts.append(s * v)
		var ab := func(x0: float, x1: float) -> Dictionary:
			return rbox(Vector3(x0 if s > 0 else -x1, A["y"][0], A["z"][0]), Vector3(x1 if s > 0 else -x0, A["y"][1], A["z"][1]), A["r"], arm_col, {"x": acuts})
		W.add("omero" + t, "arm" + t + "U", ab.call(A["x0"], A["elbow"] + A["lap"] + A["r"]))
		W.add("avambraccio" + t, "arm" + t + "F", ab.call(A["elbow"] - A["lap"] - A["r"], A["x1"]))
		var leg_col := func(g: Vector3) -> Color:
			return Cl["boots"] if g.y < boot else (Cl["pants"] if g.y > pl else skin)
		var lcuts: Array = []
		for v: float in L["cuts"] + [pl, boot if boot > 0.0 else 0.0]:
			if v > L["y"][0] + L["r"] and v < L["y"][1] - L["r"]:
				lcuts.append(v)
		var lx: Array = L["x"] if s > 0 else [-L["x"][1], -L["x"][0]]
		var lb := func(y0: float, y1: float) -> Dictionary:
			return rbox(Vector3(lx[0], y0, L["z"][0]), Vector3(lx[1], y1, L["z"][1]), L["r"], leg_col, {"y": lcuts})
		W.add("coscia" + t, "leg" + t + "U", lb.call(L["knee"] - L["lap"] - L["r"], L["y"][1]))
		W.add("stinco" + t, "leg" + t + "F", lb.call(L["y"][0], L["knee"] + L["lap"] + L["r"]))
	_face(W, dna, Cl, dark, white, scar_c, hat)
	_hair(W, dna, Cl, hides_top)
	_hats(W, dna, Cl, hat, metal, metal_d, gold)
	_face_acc(W, dna, Cl, white, gold)
	_body_acc(W, dna, Cl, gold)
	return W.parts


static func _face(W: Builder, dna: Dictionary, Cl: Dictionary, dark: Color, white: Color, scar_c: Color, hat: String) -> void:
	var beard := String(dna.get("beard", "none"))
	var beard_front := .612 if beard == "corta" or beard == "barbone" else FZ
	var layer := [0]
	var Z := func() -> float:
		var z: float = FZ + .003 + layer[0] * .0025
		layer[0] += 1
		return z
	var P := func(name: String, x0: float, x1: float, y0: float, y1: float, col: Color, z: float = -1.0, tw: Callable = Callable()) -> void:
		W.add(name, "head", plate(x0, x1, y0, y1, Z.call() if z < 0.0 else z, col, tw))
	var skin: Color = Cl["skin"]
	var paint_c: Color = Cl["paintCol"]
	match String(dna.get("paint", "none")):
		"strisce":
			for s in [1, -1]:
				P.call("pittura", .20 if s > 0 else -.46, .46 if s > 0 else -.20, 1.74, 1.80, paint_c)
				P.call("pittura", .24 if s > 0 else -.42, .42 if s > 0 else -.24, 1.64, 1.70, paint_c)
		"banda":
			P.call("pittura", -.539 + .12, .539 - .12, 1.80, 2.09, paint_c)
		"mezza":
			P.call("pittura", 0.0, .539 - .12, 1.493 + .12, 2.571 - .12, paint_c)
		"mento":
			P.call("pittura", -.30, .30, 1.493 + .12, 1.74, paint_c)
	if dna.get("freckles", false):
		var R := Mulberry.new(11)
		for s in [1, -1]:
			for i in 4:
				var x: float = s * (.20 + R.next() * .22)
				var y := 1.70 + R.next() * .12
				P.call("lentiggine", x - .016, x + .016, y - .016, y + .016, skin.lerp(rgb(120, 70, 40), 0.5))
	var E: Dictionary = BODY["eye"]
	var ez: float = Z.call()
	var ez2 := ez + .0025
	var ez3 := ez + .005
	var eye_c: Color = Cl["eye"]
	for s in [1, -1]:
		var pe := func(n: String, a: float, b: float, y0: float, y1: float, col: Color, z: float) -> void:
			if s > 0:
				P.call(n, a, b, y0, y1, col, z)
			else:
				P.call(n, -b, -a, y0, y1, col, z)
		match String(dna.get("eyes", "alto")):
			"alto":
				pe.call("occhio", E["x"][0], E["x"][1], E["y"][0], E["y"][1], eye_c, E["z"] + .0005)
			"punto":
				pe.call("occhio", .27, .39, 1.89, 2.01, eye_c, ez)
			"grande":
				pe.call("occhio", .20, .45, 1.83, 2.07, white, ez)
				pe.call("iride", .26, .41, 1.85, 2.04, eye_c, ez2)
				pe.call("pupilla", .30, .37, 1.89, 1.99, dark, ez3)
				pe.call("luce", .35, .39, 1.98, 2.02, white, ez3 + .002)
			"stretto":
				pe.call("occhio", .23, .43, 1.92, 1.98, eye_c, ez)
			"chiuso":
				pe.call("occhio", .23, .43, 1.93, 1.965, dark, ez)
			"assonnato":
				pe.call("occhio", E["x"][0] - .02, E["x"][1] + .02, 1.86, 2.00, eye_c, ez)
				pe.call("palpebra", E["x"][0] - .04, E["x"][1] + .04, 1.96, 2.03, skin.lerp(dark, .25), ez2)
			"cattivo":
				pe.call("occhio", .22, .42, 1.87, 2.02, white, ez)
				pe.call("iride", .27, .37, 1.87, 2.00, eye_c, ez2)
				var a := Vector3(s * .20, 2.03, ez3)
				var b := Vector3(s * .44, 2.03, ez3)
				var c := Vector3(s * .20, 1.93, ez3)
				W.add("palpebra", "head", tri3(a if s > 0 else b, b if s > 0 else a, c, skin.lerp(dark, .18)))
	layer[0] += 4
	# Sopracciglia.
	var Bw: Dictionary = BODY["brow"]
	var bs := String(dna.get("brows", "dritte"))
	var brow_c: Color = Cl["brow"]
	if bs != "none" and bs != "unite":
		for s in [1, -1]:
			var thick := .05 if bs == "spesse" else 0.0
			var ang := -.30 if bs == "arrabbiate" else (.28 if bs == "tristi" else 0.0)
			var bmin: Vector3 = Bw["min"]
			var bmax: Vector3 = Bw["max"]
			var mn := Vector3(bmin.x if s > 0 else -bmax.x, bmin.y - thick, bmin.z)
			var mx := Vector3(bmax.x if s > 0 else -bmin.x, bmax.y + thick * .4, bmax.z)
			var tw := rot_t(2, s * ang, Vector3((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, 0)) if ang != 0.0 else Callable()
			W.add("sopracciglio", "head", rbox1(mn, mx, Bw["r"], brow_c, tw), false)
	if bs == "unite":
		var bmin2: Vector3 = Bw["min"]
		var bmax2: Vector3 = Bw["max"]
		W.add("sopracciglio", "head", rbox1(Vector3(-bmax2.x, bmin2.y - .02, bmin2.z), Vector3(bmax2.x, bmax2.y, bmax2.z), Bw["r"], brow_c), false)
	var nose := String(dna.get("nose", "none"))
	if nose != "none":
		var n: Array = {"piccolo": [.07, 1.80, 1.93, .62], "grosso": [.12, 1.74, 1.95, .68], "punta": [.06, 1.80, 1.92, .78]}[nose]
		W.add("naso", "head", rbox(Vector3(-n[0], n[1], .45), Vector3(n[0], n[2], n[3]), .04, skin.lerp(rgb(190, 110, 90), .18)))
	var mz := beard_front + .004
	var lip := skin.lerp(rgb(120, 50, 45), .55)
	match String(dna.get("mouth", "none")):
		"linea":
			P.call("bocca", -.13, .13, 1.645, 1.675, lip, mz)
		"sorriso":
			P.call("bocca", -.13, .13, 1.63, 1.66, lip, mz)
			P.call("bocca", -.19, -.13, 1.66, 1.70, lip, mz)
			P.call("bocca", .13, .19, 1.66, 1.70, lip, mz)
		"aperta":
			P.call("bocca", -.11, .11, 1.60, 1.71, dark, mz)
			P.call("denti", -.08, .08, 1.68, 1.71, white, mz + .002)
		"ghigno":
			P.call("bocca", -.20, .20, 1.61, 1.70, dark, mz)
			for i in range(-3, 3):
				P.call("denti", i * .06 + .008, i * .06 + .052, 1.625, 1.685, white, mz + .002)
	var Zs := FZ + .012
	match String(dna.get("scar", "none")):
		"occhio":
			P.call("cicatrice", .31, .35, 1.72, 2.24, scar_c, Zs, rot_t(2, .12, Vector3(.33, 1.98, 0)))
		"guancia":
			P.call("cicatrice", -.44, -.16, 1.70, 1.735, scar_c, Zs, rot_t(2, .55, Vector3(-.30, 1.72, 0)))
		"croce":
			P.call("cicatrice", -.42, -.20, 1.70, 1.732, scar_c, Zs, rot_t(2, .78, Vector3(-.31, 1.716, 0)))
			P.call("cicatrice", -.42, -.20, 1.70, 1.732, scar_c, Zs + .002, rot_t(2, -.78, Vector3(-.31, 1.716, 0)))
		"labbro":
			P.call("cicatrice", .06, .095, 1.56, 1.76, scar_c, beard_front + .008, rot_t(2, -.2, Vector3(.08, 1.66, 0)))
		"graffi":
			for i in 3:
				P.call("cicatrice", .14 + i * .09, .175 + i * .09, 1.66, 2.16, scar_c, Zs, rot_t(2, -.35, Vector3(.16 + i * .09, 1.9, 0)))
	if dna.get("ears", true) and hat != "cappuccio" and hat != "elmo" and not dna.get("helm", false):
		var Er: Dictionary = BODY["ear"]
		var emin: Vector3 = Er["min"]
		var emax: Vector3 = Er["max"]
		for s in [1, -1]:
			W.add("orecchio", "head", rbox1(Vector3(emin.x if s > 0 else -emax.x, emin.y, emin.z), Vector3(emax.x if s > 0 else -emin.x, emax.y, emax.z), Er["r"], skin))
	# Barba.
	var bc: Color = Cl["beardCol"]
	var BX := func(mn: Vector3, mx: Vector3, r: float = .05, tw: Callable = Callable()) -> void:
		W.add("barba", "head", rbox(mn, mx, r, bc, {}, tw))
	var baffi := func(w: float, up: bool = false) -> void:
		for s in [1, -1]:
			var mn := Vector3(.015 if s > 0 else -w, 1.70, .50)
			var mx := Vector3(w if s > 0 else -.015, 1.80, beard_front + .035)
			BX.call(mn, mx, .035, rot_t(2, -s * .16, Vector3(0, 1.78, 0)))
			if up:
				BX.call(Vector3(w - .04 if s > 0 else -w - .06, 1.70, .50), Vector3(w + .06 if s > 0 else -w + .04, 1.86, beard_front + .03), .03)
	if beard == "baffi":
		baffi.call(.30)
	if beard == "manubrio":
		baffi.call(.40, true)
	if beard == "pizzetto" or beard == "mosca":
		BX.call(Vector3(-.13, 1.52 if beard == "mosca" else 1.40, .46), Vector3(.13, 1.60 if beard == "mosca" else 1.66, .61), .045)
	if beard in ["basette", "corta", "barbone"]:
		for s in [1, -1]:
			BX.call(Vector3(.47 if s > 0 else -.595, 1.62 if beard == "basette" else 1.47, -.06), Vector3(.595 if s > 0 else -.47, 2.02, .26 if beard == "basette" else .50), .04)
	if beard == "corta":
		BX.call(Vector3(-.56, 1.44, .28), Vector3(.56, 1.72, .612), .06)
		baffi.call(.28)
	if beard == "barbone":
		BX.call(Vector3(-.58, .98, .20), Vector3(.58, 1.74, .64), .10, taper_t(.98, 1.74, .45, 1, 0, .42))
		baffi.call(.34)


static func _hair(W: Builder, dna: Dictionary, Cl: Dictionary, hides_top: bool) -> void:
	var hs := String(dna.get("hairStyle", "none"))
	var hc: Color = Cl["hair"]
	var HB := func(mn: Vector3, mx: Vector3, r: float = .08, zone: String = "", tw: Callable = Callable()) -> void:
		if hides_top and zone == "top":
			return
		var d := mx - mn
		var small := minf(d.x, minf(d.y, d.z)) < .30
		W.add("capelli", "head", rbox1(mn, mx, r * .6, hc, tw) if small else rbox(mn, mx, r, hc, {}, tw), null, zone)
	var hm: Dictionary = W.hair_lib.get({"orig1": "ciuffo", "orig2": "lungo"}.get(hs, ""), {})
	if not hm.is_empty() and not hides_top:
		var col := PackedColorArray()
		col.resize((hm["position"] as PackedVector3Array).size())
		col.fill(hc)
		W.parts.append({"name": "capelli", "bone": "head", "geo": {"position": hm["position"], "normal": hm["normal"], "index": hm["index"], "color": col}, "occ": false, "zone": "top"})
	var cap_top := func() -> void: HB.call(Vector3(-.585, 2.30, -.60), Vector3(.585, 2.685, .585), .09, "cap")
	var cap_back := func(y0: float = 1.80) -> void: HB.call(Vector3(-.585, y0, -.60), Vector3(.585, 2.40, -.04), .08, "back")
	var cap_low := func() -> void:
		if hides_top:
			HB.call(Vector3(-.585, 1.80, -.60), Vector3(.585, 2.30, -.04), .08, "back")
	if hs in ["corto", "ciuffo", "lungo", "coda", "chignon", "codini", "spettinato", "trecce", "cresta"]:
		if hs != "cresta":
			if not hides_top:
				cap_top.call()
			cap_back.call()
		else:
			HB.call(Vector3(-.57, 1.85, -.585), Vector3(.57, 2.30, -.10), .06, "back")
		cap_low.call()
	match hs:
		"ciuffo":
			HB.call(Vector3(-.72, 2.17, .36), Vector3(.585, 2.47, .60), .07, "top", func(p: Vector3) -> Vector3:
				if p.y < 2.32:
					p.y += (p.x + .72) / 1.30 * .20
				return p)
		"scodella":
			if not hides_top:
				HB.call(Vector3(-.60, 2.22, -.61), Vector3(.60, 2.69, .60), .10, "cap")
			HB.call(Vector3(-.60, 1.95, -.61), Vector3(.60, 2.40, .30), .09, "back")
			HB.call(Vector3(-.60, 2.10, .30), Vector3(.60, 2.40, .61), .08, "back" if hides_top else "top")
		"caschetto":
			if not hides_top:
				HB.call(Vector3(-.70, 2.33, -.72), Vector3(.70, 2.665, .585), .09, "cap")
			HB.call(Vector3(-.70, 1.50, -.72), Vector3(.70, 2.42, -.30), .10, "back")
			for s in [1, -1]:
				HB.call(Vector3(.50 if s > 0 else -.70, 1.50, -.40), Vector3(.70 if s > 0 else -.50, 2.42, .36), .09, "back")
			HB.call(Vector3(-.66, 2.13, .42), Vector3(.66, 2.42, .59), .07, "top")
		"lungo":
			HB.call(Vector3(-.57, .92, -.70), Vector3(.57, 1.90, -.34), .10, "back", taper_t(.92, 1.9, .8, 1, 0, -.5))
		"cresta":
			if not hides_top:
				var hh := [.34, .50, .56, .48, .30]
				for i in 5:
					var z0 := .46 - i * .23
					HB.call(Vector3(-.13, 2.50, z0 - .22), Vector3(.13, 2.57 + hh[i], z0 + .02), .05, "top")
		"coda":
			HB.call(Vector3(-.15, 2.02, -.84), Vector3(.15, 2.30, -.56), .06, "back")
			HB.call(Vector3(-.17, 1.25, -.98), Vector3(.17, 2.12, -.70), .08, "back", taper_t(1.25, 2.12, .55, 1, 0, -.84))
			W.add("laccio", "head", rbox(Vector3(-.18, 2.06, -.72), Vector3(.18, 2.24, -.60), .03, Cl["accent"]))
		"chignon":
			if not hides_top:
				HB.call(Vector3(-.27, 2.56, -.50), Vector3(.27, 3.04, .04), .20, "top")
				W.add("laccio", "head", rbox(Vector3(-.20, 2.62, -.43), Vector3(.20, 2.72, -.03), .03, Cl["accent"]))
		"codini":
			for s in [1, -1]:
				HB.call(Vector3(.56 if s > 0 else -.92, 1.98, -.22), Vector3(.92 if s > 0 else -.56, 2.34, .14), .14, "back")
				HB.call(Vector3(.64 if s > 0 else -.90, 1.50, -.16), Vector3(.90 if s > 0 else -.64, 2.06, .08), .10, "back", taper_t(1.5, 2.06, .6, 1, s * .77, -.04))
		"spettinato":
			if not hides_top:
				var R := Mulberry.new(int(dna.get("seed", 7)))
				for i in 9:
					var x := -.45 + R.next() * .9
					var z := -.45 + R.next() * .9
					var h := .18 + R.next() * .22
					var w := .13 + R.next() * .08
					var r1 := rot_t(2, (R.next() - .5) * .9, Vector3(x, 2.62, z))
					var r2 := rot_t(0, (R.next() - .5) * .9, Vector3(x, 2.62, z))
					HB.call(Vector3(x - w, 2.58, z - w), Vector3(x + w, 2.70 + h, z + w), .06, "top", func(p: Vector3) -> Vector3: return r2.call(r1.call(p)))
				HB.call(Vector3(-.62, 2.20, .34), Vector3(.10, 2.44, .60), .07, "top", rot_t(2, .16, Vector3(-.3, 2.3, 0)))
		"ricci":
			var R2 := Mulberry.new(int(dna.get("seed", 7)) + 3)
			for i in 34:
				var u := R2.next() * TAU
				var v := R2.next() * .5 * PI
				var rad := .22 + R2.next() * .08
				var x := cos(u) * cos(v) * .62
				var y := 2.16 + sin(v) * .62
				var z := sin(u) * cos(v) * .64 - .02
				if z > .30 and y < 2.34:
					continue
				if hides_top and y > 2.30:
					continue
				HB.call(Vector3(x - rad, y - rad, z - rad), Vector3(x + rad, y + rad, z + rad), rad * .6, "back")
		"trecce":
			for s in [1, -1]:
				for i in 5:
					var y1 := 1.98 - i * .24
					var w := (.11 if i % 2 else .135) - (.03 if i == 4 else 0.0)
					HB.call(Vector3(s * .50 - w, y1 - .27, .20 - w), Vector3(s * .50 + w, y1, .20 + w), .06, "back")
					if i == 4:
						W.add("laccio", "head", rbox(Vector3(s * .50 - .11, y1 - .10, .09), Vector3(s * .50 + .11, y1 - .02, .31), .03, Cl["accent"]))
		"stempiato":
			HB.call(Vector3(-.585, 1.80, -.60), Vector3(.585, 2.30, -.02), .08, "back")
			for s in [1, -1]:
				HB.call(Vector3(.49 if s > 0 else -.585, 2.0, -.10), Vector3(.585 if s > 0 else -.49, 2.34, .22), .05, "back")
	if dna.get("tuft", false) and not hides_top and hs != "none" and hs != "stempiato":
		var Bn: Dictionary = BODY["bun"]
		HB.call(Bn["min"], Bn["max"], Bn["r"], "top")


static func _hats(W: Builder, dna: Dictionary, Cl: Dictionary, hat: String, metal: Color, metal_d: Color, gold: Color) -> void:
	var Ah := func(n: String, mn: Vector3, mx: Vector3, r: float, col: Color, tw: Callable = Callable()) -> void:
		W.add(n, "head", rbox(mn, mx, r, col, {}, tw))
	var acc: Color = Cl["accent"]
	var shirt: Color = Cl["shirt"]
	match hat:
		"fascia":
			Ah.call("fascia", Vector3(-.60, 2.22, -.615), Vector3(.60, 2.40, .60), .05, acc)
			Ah.call("fascia", Vector3(-.10, 2.20, -.72), Vector3(.10, 2.42, -.58), .04, acc)
			for s in [1, -1]:
				Ah.call("fascia", Vector3(s * .13 - .06, 1.86, -.70), Vector3(s * .13 + .06, 2.26, -.62), .03, acc, rot_t(2, s * .22, Vector3(s * .1, 2.26, 0)))
		"cappuccio":
			var col := shirt.lerp(rgb(30, 26, 22), .25)
			Ah.call("cappuccio", Vector3(-.66, 2.28, -.70), Vector3(.66, 2.76, .66), .14, col)
			Ah.call("cappuccio", Vector3(-.66, 1.42, -.70), Vector3(.66, 2.40, -.10), .12, col)
			for s in [1, -1]:
				Ah.call("cappuccio", Vector3(.52 if s > 0 else -.66, 1.42, -.20), Vector3(.66 if s > 0 else -.52, 2.40, .62), .07, col)
			Ah.call("cappuccio", Vector3(-.20, 2.60, -.98), Vector3(.20, 2.86, -.60), .10, col, rot_t(0, .5, Vector3(0, 2.7, -.7)))
		"elmo":
			Ah.call("elmo", Vector3(-.62, 2.20, -.64), Vector3(.62, 2.74, .62), .16, metal)
			Ah.call("elmo", Vector3(-.62, 1.78, -.64), Vector3(.62, 2.30, -.02), .08, metal)
			Ah.call("elmo", Vector3(-.055, 1.76, .54), Vector3(.055, 2.30, .66), .03, metal_d)
			Ah.call("elmo", Vector3(-.64, 2.18, -.66), Vector3(.64, 2.30, .64), .04, metal_d)
			for s in [1, -1]:
				Ah.call("elmo", Vector3(.50 if s > 0 else -.64, 1.66, -.02), Vector3(.64 if s > 0 else -.50, 2.22, .30), .05, metal)
			Ah.call("elmo", Vector3(-.07, 2.72, -.07), Vector3(.07, 2.92, .07), .04, gold)
		"paglia":
			var stc := rgb(196, 160, 84)
			Ah.call("cappello", Vector3(-1.02, 2.36, -1.02), Vector3(1.02, 2.47, 1.02), .05, stc)
			Ah.call("cappello", Vector3(-.58, 2.44, -.58), Vector3(.58, 2.82, .58), .14, stc)
			Ah.call("cappello", Vector3(-.60, 2.46, -.60), Vector3(.60, 2.56, .60), .04, acc)
		"punta":
			Ah.call("cappello", Vector3(-.92, 2.34, -.92), Vector3(.92, 2.45, .92), .05, shirt)
			for l in [[.56, 2.42, 2.80, 0.0], [.42, 2.76, 3.10, .05], [.28, 3.06, 3.36, .14], [.15, 3.32, 3.58, .28]]:
				Ah.call("cappello", Vector3(-l[0], l[1], -l[0] - l[3]), Vector3(l[0], l[2], l[0] - l[3]), .10, shirt)
			Ah.call("cappello", Vector3(-.58, 2.46, -.58), Vector3(.58, 2.58, .58), .04, acc)
		"corona":
			Ah.call("corona", Vector3(-.60, 2.50, -.60), Vector3(.60, 2.68, .60), .04, gold)
			for i in 8:
				var a := i / 8.0 * TAU
				var x := roundf(cos(a)) * .52
				var z := roundf(sin(a)) * .52
				Ah.call("corona", Vector3(x - .08, 2.62, z - .08), Vector3(x + .08, 2.88, z + .08), .04, gold)
			Ah.call("corona", Vector3(-.06, 2.54, .58), Vector3(.06, 2.64, .64), .02, Cl["paintCol"])
		"corna":
			var bone := rgb(226, 214, 186)
			for s in [1, -1]:
				Ah.call("corno", Vector3(s * .40 - .10, 2.45, -.12), Vector3(s * .40 + .10, 2.86, .10), .07, bone, rot_t(2, -s * .45, Vector3(s * .40, 2.5, 0)))
				Ah.call("corno", Vector3(s * .62 - .07, 2.74, -.08), Vector3(s * .62 + .07, 3.10, .06), .06, bone, rot_t(2, s * .10, Vector3(s * .62, 2.8, 0)))


static func _face_acc(W: Builder, dna: Dictionary, Cl: Dictionary, white: Color, gold: Color) -> void:
	var f := String(dna.get("face", "none"))
	var Af := func(n: String, mn: Vector3, mx: Vector3, r: float, col: Color, tw: Callable = Callable()) -> void:
		W.add(n, "head", rbox1(mn, mx, r, col, tw), false)
	var Pf := func(n: String, x0: float, x1: float, y0: float, y1: float, col: Color, z: float) -> void:
		W.add(n, "head", plate(x0, x1, y0, y1, z, col))
	var strap := rgb(44, 36, 30)
	var E: Dictionary = BODY["eye"]
	match f:
		"benda":
			Af.call("benda", Vector3(.20, 1.80, .535), Vector3(.47, 2.10, .575), .03, strap)
			W.add("benda", "head", rbox(Vector3(-.565, 1.98, -.575), Vector3(.565, 2.06, .565), .03, strap, {}, rot_t(2, .22, Vector3(0, 2.02, 0))), false)
		"occhiali", "scuri":
			var fr := rgb(30, 28, 30) if f == "scuri" else gold
			var lens := rgb(24, 26, 34) if f == "scuri" else white.lerp(rgb(150, 200, 220), .5)
			for s in [1, -1]:
				var x0 := .17 if s > 0 else -.49
				var x1 := .49 if s > 0 else -.17
				Af.call("occhiali", Vector3(x0, 1.80, .545), Vector3(x1, 2.10, .585), .025, fr)
				if f == "scuri":
					Pf.call("lente", x0 + .035, x1 - .035, 1.835, 2.065, lens, .5865)
				else:
					Pf.call("lente", x0 + .035, x1 - .035, 1.835, 2.065, Cl["skin"], .5865)
					Pf.call("occhio", E["x"][0] if s > 0 else -E["x"][1], E["x"][1] if s > 0 else -E["x"][0], E["y"][0], E["y"][1], Cl["eye"], .5885)
				Af.call("occhiali", Vector3(.49 if s > 0 else -.58, 1.93, -.05), Vector3(.58 if s > 0 else -.49, 1.99, .57), .02, fr)
			Af.call("occhiali", Vector3(-.17, 1.93, .55), Vector3(.17, 1.99, .585), .02, fr)
		"monocolo":
			Af.call("monocolo", Vector3(.19, 1.79, .545), Vector3(.47, 2.11, .58), .03, gold)
			Pf.call("lente", .225, .435, 1.825, 2.075, white.lerp(rgb(150, 200, 220), .5), .5815)
			Pf.call("occhio", E["x"][0], E["x"][1], E["y"][0], E["y"][1], Cl["eye"], .5835)
			Af.call("monocolo", Vector3(.44, 1.30, .55), Vector3(.47, 1.80, .57), .01, gold)
		"bandana":
			W.add("bandana", "head", rbox(Vector3(-.575, 1.44, -.59), Vector3(.575, 1.84, .60), .07, Cl["accent"]))
			W.add("bandana", "head", rbox(Vector3(-.20, 1.20, .40), Vector3(.20, 1.52, .60), .06, Cl["accent"], {}, taper_t(1.2, 1.52, .3, 1, 0, .5)))
		"orecchini":
			for s in [1, -1]:
				Af.call("orecchino", Vector3(s * .60 - .05, 1.74, .06), Vector3(s * .60 + .05, 1.88, .15), .02, gold)


static func _body_acc(W: Builder, dna: Dictionary, Cl: Dictionary, gold: Color) -> void:
	var Tb: Dictionary = BODY["torso"]
	var tmin: Vector3 = Tb["min"]
	var tmax: Vector3 = Tb["max"]
	var Ab := func(n: String, mn: Vector3, mx: Vector3, r: float, col: Color, tw: Callable = Callable()) -> void:
		W.add(n, "torso", rbox(mn, mx, r, col, {}, tw))
	var acc: Color = Cl["accent"]
	var boots: Color = Cl["boots"]
	match String(dna.get("belt", "none")):
		"cintura":
			Ab.call("cintura", Vector3(tmin.x - .025, .80, tmin.z - .025), Vector3(tmax.x + .025, .93, tmax.z + .025), .03, boots)
			Ab.call("fibbia", Vector3(-.09, .79, tmax.z + .01), Vector3(.09, .94, tmax.z + .05), .02, gold)
		"fusciacca":
			Ab.call("cintura", Vector3(tmin.x - .03, .78, tmin.z - .03), Vector3(tmax.x + .03, 1.0, tmax.z + .03), .05, acc)
			Ab.call("cintura", Vector3(.22, .42, tmax.z - .02), Vector3(.40, .84, tmax.z + .06), .04, acc)
	match String(dna.get("back", "none")):
		"mantello":
			Ab.call("mantello", Vector3(-.56, .22, -.62), Vector3(.56, 1.47, -.47), .06, acc, func(p: Vector3) -> Vector3:
				p.z -= (1.47 - p.y) * .22
				p.x *= 1 + (1.47 - p.y) * .18
				return p)
			Ab.call("mantello", Vector3(-.58, 1.36, -.62), Vector3(.58, 1.50, .30), .06, acc)
		"zaino":
			var dk := boots.lerp(Color.BLACK, .25)
			Ab.call("zaino", Vector3(-.36, .86, -.86), Vector3(.36, 1.44, -.46), .10, boots)
			Ab.call("zaino", Vector3(-.30, 1.30, -.90), Vector3(.30, 1.50, -.50), .08, dk)
			for s in [1, -1]:
				Ab.call("zaino", Vector3(s * .30 - .05, .90, -.50), Vector3(s * .30 + .05, 1.50, .30), .03, dk)
		"sciarpa":
			Ab.call("sciarpa", Vector3(-.50, 1.38, -.46), Vector3(.50, 1.60, .40), .09, acc)
			Ab.call("sciarpa", Vector3(.18, .95, .24), Vector3(.38, 1.46, .36), .05, acc, rot_t(2, .08, Vector3(.28, 1.46, 0)))


# ---------------------------------------------------------------- facce sotto l'armatura (D-030)

## Toglie dai pezzi i triangoli tutti dentro un volume dell'armatura dello
## stesso osso (`boxes`: osso -> [AABB], unita' del modello): quelli a cavallo
## del bordo restano, cosi' sotto l'orlo dell'armatura non si aprono buchi.
static func cull_inside(parts: Array, boxes: Dictionary) -> void:
	if boxes.is_empty():
		return
	for p: Dictionary in parts:
		var list: Array = boxes.get(p["bone"], [])
		if list.is_empty():
			continue
		var g: Dictionary = p["geo"]
		var P: PackedVector3Array = g["position"]
		var I: PackedInt32Array = g["index"]
		var keep := PackedInt32Array()
		for j in range(0, I.size(), 3):
			var inside := false
			for b0: AABB in list:
				var b := b0.grow(0.02)
				if b.has_point(P[I[j]]) and b.has_point(P[I[j + 1]]) and b.has_point(P[I[j + 2]]):
					inside = true
					break
			if not inside:
				keep.append(I[j])
				keep.append(I[j + 1])
				keep.append(I[j + 2])
		g["index"] = keep


# ---------------------------------------------------------------- occlusione cotta (CHARGEN.rig.bakeAO)

const BONES := ["head", "torso", "armLU", "armLF", "armRU", "armRF", "legLU", "legLF", "legRU", "legRF"]


static func rest_bones() -> Dictionary:
	var M := {"torso": Transform3D.IDENTITY, "head": Transform3D.IDENTITY}
	var A: Dictionary = BODY["arm"]
	for s in [1, -1]:
		var n := "L" if s > 0 else "R"
		var sh := Vector3(s * A["shoulder"][0], A["shoulder"][1], A["shoulder"][2])
		var el := Vector3(s * A["elbow"], A["shoulder"][1], A["shoulder"][2])
		var up := _about(sh, Basis(Vector3(0, 0, 1), -s * 1.36))
		M["arm" + n + "U"] = up
		M["arm" + n + "F"] = up * _about(el, Basis(Vector3.UP, -s * .22))
		M["leg" + n + "U"] = Transform3D.IDENTITY
		M["leg" + n + "F"] = Transform3D.IDENTITY
	return M


static func _about(p: Vector3, b: Basis) -> Transform3D:
	return Transform3D(Basis.IDENTITY, p) * Transform3D(b, Vector3.ZERO) * Transform3D(Basis.IDENTITY, -p)


static func _hemi() -> PackedVector3Array:
	var d := PackedVector3Array()
	for i in 18:
		var u := (i + .5) / 18.0
		var ph := i * 2.399963
		var ct := sqrt(1.0 - u)
		var st := sqrt(u)
		d.append(Vector3(cos(ph) * st, sin(ph) * st, ct))
	return d


## Occlusione per vertice (18 direzioni, distanza massima .75) contro le scatole
## degli altri pezzi e il suolo, nella posa di riposo con le braccia abbassate.
static func bake_ao(parts: Array) -> void:
	var M := rest_bones()
	var Mi := {}
	for b in BONES:
		Mi[b] = (M[b] as Transform3D).affine_inverse()
	var by_bone := {}
	for p: Dictionary in parts:
		if not p["occ"]:
			continue
		var aabb := AABB((p["geo"]["position"] as PackedVector3Array)[0], Vector3.ZERO)
		for v: Vector3 in p["geo"]["position"]:
			aabb = aabb.expand(v)
		if not by_bone.has(p["bone"]):
			by_bone[p["bone"]] = []
		by_bone[p["bone"]].append([aabb.position, aabb.end, p])
	var hemi := _hemi()
	const MAXD := 0.75
	var cache := {}
	for p: Dictionary in parts:
		var P: PackedVector3Array = p["geo"]["position"]
		var N: PackedVector3Array = p["geo"]["normal"]
		var ao := PackedFloat32Array()
		ao.resize(P.size())
		var Mw: Transform3D = M.get(p["bone"], M["torso"])
		for i in P.size():
			var ck := [p["bone"], _key(P[i]), _key(N[i])]
			if cache.has(ck):
				ao[i] = cache[ck]
				continue
			var nl := (Mw.basis * N[i]).normalized()
			var pw := Mw * (P[i] + N[i] * .025)
			var tx := Vector3.UP if absf(nl.y) < .9 else Vector3.RIGHT
			var bx := nl.cross(tx).normalized()
			var byv := nl.cross(bx)
			var loc := {}
			var locd := {}
			for b: String in by_bone:
				loc[b] = (Mi[b] as Transform3D) * pw
			var sum := 0.0
			for h in hemi:
				var dw := bx * h.x + byv * h.y + nl * h.z
				var best := MAXD
				if dw.y < -1e-3:
					var tg := -pw.y / dw.y
					if tg > 0.0 and tg < best:
						best = tg
				for b: String in by_bone:
					var o0: Vector3 = loc[b]
					var dl: Vector3 = (Mi[b] as Transform3D).basis * dw
					for o: Array in by_bone[b]:
						if o[2] == p:
							continue
						var mn: Vector3 = o[0]
						var mx: Vector3 = o[1]
						var t0 := 0.0
						var t1 := best
						var inside := true
						var ok := true
						for a in 3:
							if o0[a] < mn[a] or o0[a] > mx[a]:
								inside = false
							if absf(dl[a]) < 1e-9:
								if o0[a] < mn[a] or o0[a] > mx[a]:
									ok = false
									break
							else:
								var ta := (mn[a] - o0[a]) / dl[a]
								var tb := (mx[a] - o0[a]) / dl[a]
								if ta > tb:
									var q := ta
									ta = tb
									tb = q
								t0 = maxf(t0, ta)
								t1 = minf(t1, tb)
								if t0 > t1:
									ok = false
									break
						if ok and not inside and t0 < best:
							best = t0
				sum += (1.0 - best / MAXD) * h.z
			var a0 := maxf(0.0, 1.0 - sum / 9.0 * 1.55)
			cache[ck] = a0
			ao[i] = a0
		p["geo"]["ao"] = ao


# ---------------------------------------------------------------- nel rig (CHARGEN.rig.toRig)

## Pezzo -> osso di `AvatarRig`, origine nel modello, scala e segno del braccio.
static func slots() -> Dictionary:
	var A: Dictionary = BODY["arm"]
	var L: Dictionary = BODY["leg"]
	var neck: float = BODY["neck"]
	var d := {
		"head": {"bone": &"head", "o": Vector3(0, neck, 0), "s": Vector3(S, S, S), "arm": 0},
		"torso": {"bone": &"chest", "o": Vector3(0, .74, 0), "s": Vector3(S, (NECK_Y - HIP_Y) / (neck - .74), S), "arm": 0},
	}
	for sg in [1, -1]:
		var m := "L" if sg > 0 else "R"
		# +X del modello e' la sinistra anatomica: nel rig (guarda -Z) e' il lato _l.
		var side := "l" if sg > 0 else "r"
		d["arm" + m + "U"] = {"bone": StringName("arm_" + side), "o": Vector3(sg * .54, 1.34, -.01), "s": Vector3(S, UPPER / (A["elbow"] - .54), S), "arm": sg}
		d["arm" + m + "F"] = {"bone": StringName("fore_" + side), "o": Vector3(sg * A["elbow"], 1.34, -.03), "s": Vector3(S, FORE_HAND / (A["x1"] - A["elbow"]), S), "arm": sg}
		d["leg" + m + "U"] = {"bone": StringName("leg_" + side), "o": Vector3(sg * .2545, L["y"][1], 0), "s": Vector3(.42, THIGH / (L["y"][1] - L["knee"]), S * .9), "arm": 0}
		d["leg" + m + "F"] = {"bone": StringName("shin_" + side), "o": Vector3(sg * .2545, L["knee"], 0), "s": Vector3(.42, SHIN_FOOT / L["knee"], S * .9), "arm": 0}
	return d


## Pezzi -> una ArrayMesh per osso del rig, in coordinate dell'osso (gira di
## 180° attorno a Y: il davanti del modello va a -Z). `offset` sposta i pezzi
## di un osso (il busto sta nel `chest`, sopra le anche).
static func to_rig(parts: Array, offsets: Dictionary = {}) -> Dictionary:
	var sl := slots()
	var by := {}
	for p: Dictionary in parts:
		if not by.has(p["bone"]):
			by[p["bone"]] = []
		by[p["bone"]].append(p)
	var out := {}
	for bone: String in by:
		if not sl.has(bone):
			continue
		var T: Dictionary = sl[bone]
		var arm: int = T["arm"]
		var sc: Vector3 = T["s"]
		var o: Vector3 = T["o"]
		var off: Vector3 = offsets.get(T["bone"], Vector3.ZERO)
		var pos := PackedVector3Array()
		var nor := PackedVector3Array()
		var col := PackedColorArray()
		var idx := PackedInt32Array()
		var limb := arm != 0 or bone.begins_with("leg")
		for p: Dictionary in by[bone]:
			var g: Dictionary = p["geo"]
			var P: PackedVector3Array = g["position"]
			var N: PackedVector3Array = g["normal"]
			var C: PackedColorArray = g["color"]
			var AO: PackedFloat32Array = g.get("ao", PackedFloat32Array())
			var base := pos.size()
			for i in P.size():
				var v := P[i] - o
				var q := N[i]
				if arm != 0:
					v = Vector3(arm * v.y, -arm * v.x, v.z)
					q = Vector3(arm * q.y, -arm * q.x, q.z)
				v *= sc
				q = (q / sc).normalized()
				# Davanti del modello (+Z) -> davanti del rig (-Z), destra sul +X.
				pos.append(Vector3(-v.x, v.y, -v.z) + off)
				nor.append(Vector3(-q.x, q.y, -q.z))
				var a0 := AO[i] if i < AO.size() else 1.0
				var a := 1.0 - (1.0 - a0) * 0.5 if limb else a0
				var c: Color = C[i]
				col.append(Color(c.r * (.62 + .38 * a), c.g * (.66 + .34 * a), c.b * (.78 + .22 * a)))
			var I: PackedInt32Array = g["index"]
			for j in range(0, I.size(), 3):
				# Da antiorario uscente (three.js) al fronte orario di Godot.
				idx.append(I[j] + base)
				idx.append(I[j + 2] + base)
				idx.append(I[j + 1] + base)
		var bn: StringName = T["bone"]
		if not out.has(bn):
			out[bn] = []
		out[bn].append(_mesh(pos, nor, col, idx))
	return out


static func _mesh(pos: PackedVector3Array, nor: PackedVector3Array, col: PackedColorArray, idx: PackedInt32Array) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_NORMAL] = nor
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


# ---------------------------------------------------------------- capelli originali

static var _hair_lib := {}


## I due capelli "originali" del prototipo (data/hero/hair.json).
static func hair_lib() -> Dictionary:
	if not _hair_lib.is_empty():
		return _hair_lib
	var f := FileAccess.open("res://data/hero/hair.json", FileAccess.READ)
	if f == null:
		return {}
	var j: Variant = JSON.parse_string(f.get_as_text())
	if not (j is Dictionary):
		return {}
	for k: String in j:
		var h: Dictionary = j[k]
		var n: int = h["v"]
		var q := Marshalls.base64_to_raw(h["p"])
		var nb := Marshalls.base64_to_raw(h["n"])
		var ib := Marshalls.base64_to_raw(h["i"])
		var mn: Array = h["min"]
		var mx: Array = h["max"]
		var P := PackedVector3Array()
		var N := PackedVector3Array()
		for i in n:
			var v := Vector3.ZERO
			var w := Vector3.ZERO
			for a in 3:
				v[a] = mn[a] + q.decode_u16((i * 3 + a) * 2) / 65535.0 * (mx[a] - mn[a])
				w[a] = nb.decode_s8(i * 3 + a) / 127.0
			P.append(v)
			N.append(w)
		var I := PackedInt32Array()
		for i in ib.size() / 2:
			I.append(ib.decode_u16(i * 2))
		_hair_lib[k] = {"position": P, "normal": N, "index": I}
	return _hair_lib
