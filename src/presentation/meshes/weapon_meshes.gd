class_name WeaponMeshes
extends RefCounted
## Mesh procedurali delle armi (M4, disegno nuovo). Spazio arma: impugnatura
## della mano destra nell'origine, lama/asta lungo +Y, piatto della lama sul
## piano XY (filo verso ±X). Nessun asset esterno.

const STEEL := Color(0.72, 0.76, 0.80)
const STEEL_EDGE := Color(0.92, 0.95, 0.97)
const DARK_STEEL := Color(0.38, 0.40, 0.44)
const BRASS := Color(0.80, 0.62, 0.26)
const LEATHER := Color(0.36, 0.22, 0.13)
const WOOD := Color(0.52, 0.36, 0.20)
const CLOTH := Color(0.70, 0.18, 0.14)


## Colori del materiale in uso (acciaio se non indicato).
static var _steel := STEEL
static var _edge := STEEL_EDGE
static var _dark := DARK_STEEL


static func _set_material(c: Color) -> void:
	if c.a <= 0.0:
		_steel = STEEL
		_edge = STEEL_EDGE
		_dark = DARK_STEEL
	else:
		_steel = c
		_edge = c.lightened(0.3)
		_dark = c.darkened(0.35)


## Mesh dell'oggetto in mano (arma o attrezzo nel colore del materiale), o null.
static func for_item(d: ItemDefinition) -> ArrayMesh:
	if d == null:
		return null
	if d.kind == ItemDefinition.Kind.WEAPON:
		return build(WeaponLibrary.by_id(d.weapon).kind, ItemLibrary.TIERS[d.tier - 1]["color"])
	if d.kind == ItemDefinition.Kind.TOOL:
		return build_tool(d.tool_type, ItemLibrary.TIERS[d.tier - 1]["color"])
	return null


## `mat` colora le parti "di metallo" col materiale dell'oggetto (legno, pietra, rame...).
static func build(kind: WeaponDefinition.Kind, mat: Color = Color(0, 0, 0, 0)) -> ArrayMesh:
	_set_material(mat)
	var k := MeshKit.new()
	match kind:
		WeaponDefinition.Kind.SWORD:
			_sword(k)
		WeaponDefinition.Kind.SPEAR:
			_spear(k)
		WeaponDefinition.Kind.HAMMER:
			_hammer(k)
		WeaponDefinition.Kind.GREATSWORD:
			_greatsword(k)
		WeaponDefinition.Kind.STAFF:
			_staff(k, GEM_FIRE)
		_:
			_wraps(k)
	return k.commit()


# --- armi dai modelli Higgsfield (D-052): le tavole e i modelli 3D generati
# fanno da riferimento, le armi sono ricostruite qui a pezzi smussati nello
# stile dell'armatura da cavaliere (acciaio, ottone, cuoio, legno). Stesse
# lunghezze e stessa impugnatura delle armi a cubetti (D-039): hitbox, scie e
# pose non cambiano. Il materiale dell'oggetto colora solo l'acciaio.

## Spada a una mano: lama larga a rombo con la sgusciatura scura, guardia
## d'ottone con le estremita' squadrate, manico di cuoio fasciato, pomo tondo.
static func _sword(k: MeshKit) -> void:
	k.blade(0.17, 0.84, 0.13, 0.040, 0.12, _steel, _edge)
	k.box(Vector3(0, 0.50, 0), Vector3(0.022, 0.56, 0.044), _dark, 0.004)
	k.box(Vector3(0, 0.145, 0), Vector3(0.26, 0.05, 0.075), BRASS, 0.015)
	for x in [-0.125, 0.125]:
		k.box(Vector3(x, 0.145, 0), Vector3(0.045, 0.085, 0.09), BRASS.darkened(0.08), 0.012)
	k.box(Vector3(0, 0.015, 0), Vector3(0.062, 0.21, 0.062), LEATHER, 0.02)
	for y in [-0.04, 0.03, 0.10]:
		k.box(Vector3(0, y, 0), Vector3(0.07, 0.022, 0.07), LEATHER.darkened(0.25), 0.008)
	k.box(Vector3(0, -0.125, 0), Vector3(0.10, 0.09, 0.10), BRASS, 0.04)


## Spadone: lama lunga e larghissima con la sgusciatura, guardia d'ottone
## larga con le punte angolate, impugnatura lunga a due mani, pomo pesante.
static func _greatsword(k: MeshKit) -> void:
	k.blade(0.26, 1.30, 0.20, 0.052, 0.16, _steel, _edge)
	k.box(Vector3(0, 0.76, 0), Vector3(0.036, 0.94, 0.056), _dark, 0.005)
	k.box(Vector3(0, 0.22, 0), Vector3(0.34, 0.07, 0.09), BRASS, 0.02)
	for s in [-1.0, 1.0]:
		k.box(Vector3(s * 0.175, 0.245, 0), Vector3(0.05, 0.11, 0.10), BRASS.darkened(0.08), 0.015, 1.0, MeshKit.rot_about(Vector3.FORWARD, s * 0.35, Vector3(s * 0.175, 0.22, 0)))
	k.box(Vector3(0, -0.04, 0), Vector3(0.07, 0.45, 0.07), LEATHER, 0.02)
	for y in [-0.20, -0.08, 0.04, 0.14]:
		k.box(Vector3(0, y, 0), Vector3(0.078, 0.024, 0.078), LEATHER.darkened(0.25), 0.008)
	k.box(Vector3(0, -0.31, 0), Vector3(0.14, 0.10, 0.11), BRASS, 0.035)


## Lancia: asta di legno con due fasce di cuoio, puntale d'acciaio, collare
## d'ottone, ferro a foglia con la nervatura centrale.
static func _spear(k: MeshKit) -> void:
	k.box(Vector3(0, 0.29, 0), Vector3(0.05, 2.0, 0.05), WOOD, 0.015)
	for y in [0.0, 0.62]:
		k.box(Vector3(0, y, 0), Vector3(0.058, 0.16, 0.058), LEATHER, 0.012)
	k.box(Vector3(0, -0.705, 0), Vector3(0.064, 0.075, 0.064), _steel, 0.02, 0.7)
	k.box(Vector3(0, 1.315, 0), Vector3(0.075, 0.07, 0.075), BRASS, 0.02)
	# Ferro: si allarga dal collare e poi si stringe fino alla punta.
	k.blade(1.35, 1.44, 0.07, 0.07, 0.0, _steel, _edge, Transform3D.IDENTITY, 0.16)
	k.blade(1.44, 1.47, 0.16, 0.08, 0.155, _steel, _edge)
	k.box(Vector3(0, 1.47, 0), Vector3(0.02, 0.22, 0.07), _dark, 0.004)


## Colori delle gemme degli elementi (D-055, tavola di riferimento).
const GEM_FIRE := Color(0.92, 0.16, 0.10)
const IVORY := Color(0.90, 0.86, 0.76)
const SILVER := Color(0.74, 0.76, 0.80)

## Altezza (spazio arma) del centro della gemma: da qui parte la magia.
const STAFF_GEM_Y := 1.24


## Bastone magico (D-055), dalla tavola Higgsfield ispirata a Frieren: asta
## d'avorio con fasce d'argento, impugnatura di cuoio, puntale; in cima una
## mezzaluna d'argento aperta in alto con due volute ai lati che tiene sospesa
## la gemma sfaccettata dell'elemento. Il materiale colora l'argento.
static func _staff(k: MeshKit, gem: Color) -> void:
	var silver := SILVER if _steel == STEEL else _steel
	k.prism(Vector3.ZERO, -0.80, 1.00, 0.030, 0.028, 8, IVORY)
	k.prism(Vector3.ZERO, -0.13, 0.13, 0.037, 0.037, 8, LEATHER)
	for y in [-0.16, 0.16, 0.42, 0.90]:
		k.prism(Vector3.ZERO, y - 0.018, y + 0.018, 0.040, 0.040, 8, silver)
	k.box(Vector3(0, -0.83, 0), Vector3(0.075, 0.07, 0.075), silver, 0.02, 0.7)
	k.prism(Vector3.ZERO, 0.97, 1.05, 0.048, 0.042, 8, silver)
	k.prism(Vector3.ZERO, 1.05, 1.09, 0.036, 0.036, 8, silver.darkened(0.2))
	# Mezzaluna: segmenti lungo un cerchio nel piano XY, aperta in alto.
	var c := Vector3(0, STAFF_GEM_Y, 0)
	var r := 0.17
	var a := 115.0
	while a <= 425.0:
		var t := deg_to_rad(a)
		var p := c + Vector3(cos(t) * r, sin(t) * r, 0)
		var xf := MeshKit.rot_about(Vector3(0, 0, 1), t, p)
		k.box(p, Vector3(0.065, 0.062, 0.05), silver if a < 400.0 and a > 140.0 else silver.lightened(0.1), 0.012, 1.0, xf)
		a += 15.0
	# Volute ai lati della mezzaluna.
	for sx in [-1.0, 1.0]:
		var vp := c + Vector3(sx * 0.225, -0.02, 0)
		k.box(vp, Vector3(0.06, 0.05, 0.04), silver, 0.015, 1.0, MeshKit.rot_about(Vector3(0, 0, 1), sx * 0.5, vp))
		k.box(vp + Vector3(sx * 0.035, 0.035, 0), Vector3(0.035, 0.035, 0.035), silver.lightened(0.08), 0.01)
	# Gemma sfaccettata: due tronchi di cono a otto facce.
	k.prism(c, -0.085, 0.0, 0.025, 0.075, 8, gem.darkened(0.15), Transform3D.IDENTITY, 0.2)
	k.prism(c, 0.0, 0.085, 0.075, 0.025, 8, gem.lightened(0.15), Transform3D.IDENTITY, 0.2)


## Martello da guerra: testa d'acciaio squadrata con le facce scure e due
## fasce d'ottone, manico lungo di legno con l'impugnatura di cuoio e il
## puntale d'acciaio.
static func _hammer(k: MeshKit) -> void:
	k.box(Vector3(0, 0.32, 0), Vector3(0.06, 1.34, 0.06), WOOD.darkened(0.15), 0.018)
	k.box(Vector3(0, -0.04, 0), Vector3(0.072, 0.40, 0.072), LEATHER, 0.02)
	for y in [-0.20, -0.06, 0.08]:
		k.box(Vector3(0, y, 0), Vector3(0.08, 0.022, 0.08), LEATHER.darkened(0.25), 0.008)
	k.box(Vector3(0, -0.33, 0), Vector3(0.08, 0.06, 0.08), _steel, 0.02)
	k.box(Vector3(0, 1.10, 0), Vector3(0.40, 0.26, 0.22), _steel, 0.035)
	for s in [-1.0, 1.0]:
		k.box(Vector3(s * 0.215, 1.10, 0), Vector3(0.05, 0.28, 0.24), _dark, 0.03)
		k.box(Vector3(s * 0.10, 1.10, 0), Vector3(0.045, 0.275, 0.235), BRASS, 0.01)
	k.box(Vector3(0, 1.235, 0), Vector3(0.10, 0.03, 0.10), _edge, 0.01)


# --- attrezzi a voxel (D-039): come gli oggetti di Minecraft, un disegno a
# pixel estruso in cubetti. Le armi dal D-052 sono modellate sopra.
# Righe dall'alto (punta) al basso; `grip` = riga dell'impugnatura (y = 0).

## Lato di un pixel nello spazio arma.
const PX := 0.055
## Spessore (in pixel) per lettera; le altre lettere sono spesse un pixel.
const DEPTH := {"G": 1.4, "H": 4.4, "h": 4.4, "L": 1.2}


static func _pal(ch: String) -> Color:
	match ch:
		"B", "H":
			return _steel
		"E":
			return _edge
		"D", "h":
			return _dark
		"W":
			return WOOD
		"L":
			return LEATHER
		"G":
			return BRASS
		"C":
			return CLOTH
	return Color.MAGENTA


## Estrude il disegno: un cubetto per pixel, con una leggera variazione a
## scacchi del colore come la tessitura dei blocchi.
static func _sprite(k: MeshKit, rows: Array, grip: int) -> void:
	var n := rows.size()
	for i in n:
		var row: String = rows[i]
		var r := n - 1 - i
		var w := row.length()
		for c in w:
			var ch := row[c]
			if ch == ".":
				continue
			var col := _pal(ch)
			col = col.lightened(0.05) if (r + c) % 2 == 0 else col.darkened(0.05)
			var d := PX * float(DEPTH.get(ch, 1.0))
			k.box(Vector3((c - (w - 1) * 0.5) * PX, (r - grip) * PX, 0), Vector3(PX, PX, d), col, 0.0)


## Pugni: fasce di cuoio con borchie (vanno su entrambe le mani).
static func _wraps(k: MeshKit) -> void:
	# Spazio mano: il pugno scende lungo -Y, le nocche guardano -Y.
	k.box(Vector3(0, -0.01, 0), Vector3(0.13, 0.06, 0.135), LEATHER, 0.018)
	k.box(Vector3(0, -0.075, 0), Vector3(0.125, 0.07, 0.13), LEATHER.lightened(0.12), 0.018)
	for x in [-0.035, 0.0, 0.035]:
		k.box(Vector3(x, -0.113, -0.02), Vector3(0.026, 0.02, 0.026), _steel, 0.006)


## Attrezzi da raccolta (M5, a voxel da D-039): manico in legno lungo +Y,
## testa del materiale.
static func build_tool(tool_type: String, mat: Color) -> ArrayMesh:
	_set_material(mat)
	var k := MeshKit.new()
	var head: Array
	match tool_type:
		"pick":
			head = [".EBBBBBE.", "E...D...E"]
		"axe":
			head = ["....WBBE.", "....DBBBE", "....WBBBE", "....WBBE."]
		_:
			head = ["..EBBBE..", "..BBBBB..", "..BBBBB..", "...BBB...", "....D...."]
	var rows: Array = head.duplicate()
	for r in range(18 - head.size(), 0, -1):
		rows.append("....L...." if r >= 2 and r <= 4 else "....W....")
	rows.append("....D....")
	_sprite(k, rows, 3)
	return k.commit()
