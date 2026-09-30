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
			_sprite(k, _sword_rows(), 2)
		WeaponDefinition.Kind.SPEAR:
			_sprite(k, _spear_rows(), 13)
		WeaponDefinition.Kind.HAMMER:
			_sprite(k, _hammer_rows(), 6)
		WeaponDefinition.Kind.GREATSWORD:
			_sprite(k, _greatsword_rows(), 6)
		_:
			_wraps(k)
	return k.commit()


# --- armi a voxel (D-039): come gli oggetti di Minecraft, un disegno a pixel
# estruso in cubetti, cosi' le armi hanno lo stesso aspetto a blocchi del mondo.
# Righe dall'alto (punta) al basso (pomo); `grip` = riga dell'impugnatura
# (y = 0). Stesse lunghezze delle vecchie mesh lisce: hitbox e scie non cambiano.

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


## Spada a una mano: lama di tre pixel col filo chiaro, guardia, manico, pomo.
static func _sword_rows() -> Array:
	var rows := ["..E.."]
	for i in 13:
		rows.append(".EBE.")
	rows.append_array(["GGGGG", "..L..", "..L..", "..L..", "..L..", ".GGG."])
	return rows


## Spadone: lama larga con la sgusciatura scura, guardia lunga, manico lungo.
static func _greatsword_rows() -> Array:
	var rows := ["...E...", "..EEE.."]
	for i in 22:
		rows.append(".EBDBE.")
	rows.append("GGGGGGG")
	for i in 7:
		rows.append("...L...")
	rows.append("..GGG..")
	return rows


## Lancia: ferro a foglia, collare, nappa, asta lunga con fasce di cuoio.
static func _spear_rows() -> Array:
	var rows := ["..E..", ".EBE.", ".EBE.", "EBDBE", "EBDBE", ".EBE.", "..D..", ".CGC."]
	for r in range(34, 0, -1):
		rows.append("..L.." if (r >= 11 and r <= 15) or r == 5 or r == 6 else "..W..")
	rows.append("..D..")
	return rows


## Martello: manico con impugnatura di cuoio, testa squadrata spessa con fascia.
static func _hammer_rows() -> Array:
	var rows := ["....E....", "....B....", "hHHHHHHHh", "hHGGGGGHh", "hHGGGGGHh", "hHGGGGGHh", "hHHHHHHHh"]
	for r in range(21, 0, -1):
		rows.append("....L...." if r >= 4 and r <= 8 else "....W....")
	rows.append("....D....")
	return rows


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
