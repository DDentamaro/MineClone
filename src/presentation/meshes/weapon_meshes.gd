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
		_:
			_wraps(k)
	return k.commit()


## Spada a una mano: lama con sguscio, guardia a becchi, pomo a disco.
static func _sword(k: MeshKit) -> void:
	k.prism(Vector3.ZERO, -0.12, 0.09, 0.028, 0.026, 6, LEATHER)
	k.prism(Vector3.ZERO, -0.17, -0.12, 0.045, 0.04, 8, BRASS)
	k.box(Vector3(0, 0.11, 0), Vector3(0.26, 0.04, 0.06), BRASS, 0.012)
	k.box(Vector3(0.14, 0.13, 0), Vector3(0.04, 0.06, 0.05), BRASS, 0.01)
	k.box(Vector3(-0.14, 0.13, 0), Vector3(0.04, 0.06, 0.05), BRASS, 0.01)
	k.blade(0.13, 0.84, 0.1, 0.028, 0.16, _steel, _edge, Transform3D.IDENTITY, 0.085)
	# Sguscio: una lista scura sottile al centro delle due facce.
	k.box(Vector3(0, 0.42, 0), Vector3(0.018, 0.5, 0.032), _dark, 0.0)


## Lancia: asta lunga con fasce di cuoio, puntale e ferro a foglia con alette.
static func _spear(k: MeshKit) -> void:
	k.prism(Vector3.ZERO, -0.62, 1.3, 0.03, 0.028, 6, WOOD)
	k.prism(Vector3.ZERO, -0.7, -0.62, 0.02, 0.034, 6, _dark)
	for y in [-0.08, 0.1, -0.44]:
		k.prism(Vector3.ZERO, y, y + 0.07, 0.036, 0.036, 6, LEATHER)
	k.prism(Vector3.ZERO, 1.26, 1.34, 0.04, 0.034, 6, BRASS)
	k.box(Vector3(0, 1.3, 0), Vector3(0.12, 0.03, 0.04), _dark, 0.008)
	k.blade(1.33, 1.48, 0.12, 0.034, 0.2, _steel, _edge, Transform3D.IDENTITY, 0.1)
	# Nappa rossa sotto il ferro.
	k.box(Vector3(0.0, 1.18, 0.0), Vector3(0.07, 0.12, 0.07), CLOTH, 0.02, 0.6)


## Martello da guerra: manico lungo, testa squadrata con fasce e punta.
static func _hammer(k: MeshKit) -> void:
	k.prism(Vector3.ZERO, -0.28, 0.9, 0.034, 0.032, 6, WOOD)
	k.prism(Vector3.ZERO, -0.34, -0.28, 0.045, 0.045, 6, _dark)
	k.prism(Vector3.ZERO, -0.1, 0.12, 0.04, 0.04, 6, LEATHER)
	k.box(Vector3(0, 0.98, 0), Vector3(0.44, 0.26, 0.26), _dark, 0.035)
	k.box(Vector3(0.23, 0.98, 0), Vector3(0.05, 0.3, 0.3), _steel, 0.02)
	k.box(Vector3(-0.23, 0.98, 0), Vector3(0.05, 0.3, 0.3), _steel, 0.02)
	k.box(Vector3(0, 0.98, 0), Vector3(0.1, 0.28, 0.28), BRASS, 0.015)
	k.prism(Vector3(0, 1.1, 0), 0.0, 0.14, 0.05, 0.0, 4, _steel)


## Spadone a due mani: lama larga e lunga, ricasso, guardia dritta.
static func _greatsword(k: MeshKit) -> void:
	k.prism(Vector3.ZERO, -0.3, 0.1, 0.032, 0.03, 6, LEATHER)
	k.box(Vector3(0, -0.34, 0), Vector3(0.09, 0.08, 0.09), BRASS, 0.02)
	k.box(Vector3(0, 0.12, 0), Vector3(0.42, 0.05, 0.07), _dark, 0.014)
	k.box(Vector3(0.21, 0.12, 0), Vector3(0.05, 0.08, 0.08), BRASS, 0.012)
	k.box(Vector3(-0.21, 0.12, 0), Vector3(0.05, 0.08, 0.08), BRASS, 0.012)
	k.box(Vector3(0, 0.22, 0), Vector3(0.1, 0.16, 0.04), _dark, 0.008)
	k.blade(0.3, 1.36, 0.17, 0.04, 0.2, _steel, _edge, Transform3D.IDENTITY, 0.14)
	k.box(Vector3(0, 0.78, 0), Vector3(0.028, 0.86, 0.046), _dark, 0.0)


## Pugni: fasce di cuoio con borchie (vanno su entrambe le mani).
static func _wraps(k: MeshKit) -> void:
	# Spazio mano: il pugno scende lungo -Y, le nocche guardano -Y.
	k.box(Vector3(0, -0.01, 0), Vector3(0.13, 0.06, 0.135), LEATHER, 0.018)
	k.box(Vector3(0, -0.075, 0), Vector3(0.125, 0.07, 0.13), LEATHER.lightened(0.12), 0.018)
	for x in [-0.035, 0.0, 0.035]:
		k.box(Vector3(x, -0.113, -0.02), Vector3(0.026, 0.02, 0.026), _steel, 0.006)


## Attrezzi da raccolta (M5): impugnatura in legno lungo +Y, testa del materiale.
static func build_tool(tool_type: String, mat: Color) -> ArrayMesh:
	_set_material(mat)
	var k := MeshKit.new()
	k.prism(Vector3.ZERO, -0.16, 0.62, 0.028, 0.026, 6, WOOD)
	k.prism(Vector3.ZERO, -0.06, 0.08, 0.034, 0.034, 6, LEATHER)
	match tool_type:
		"pick":
			# Testa ricurva: due bracci inclinati verso il basso.
			for sx in [-1.0, 1.0]:
				var xf := MeshKit.rot_about(Vector3(0, 0, 1), sx * -0.35, Vector3(0, 0.6, 0))
				k.box(Vector3(0.14 * sx, 0.6, 0), Vector3(0.26, 0.06, 0.06), _steel, 0.015, 1.0, xf)
				k.prism(Vector3(0.28 * sx, 0.55, 0), 0.0, 0.0001, 0.02, 0.02, 4, _edge)
			k.box(Vector3(0, 0.6, 0), Vector3(0.08, 0.09, 0.08), _dark, 0.015)
		"axe":
			k.box(Vector3(0.1, 0.55, 0), Vector3(0.16, 0.16, 0.04), _steel, 0.01, 0.75)
			k.box(Vector3(0.19, 0.55, 0), Vector3(0.03, 0.2, 0.045), _edge, 0.006)
			k.box(Vector3(0, 0.55, 0), Vector3(0.07, 0.1, 0.07), _dark, 0.015)
		_:
			k.box(Vector3(0, 0.72, 0), Vector3(0.16, 0.2, 0.025), _steel, 0.01, 1.0)
			k.box(Vector3(0, 0.83, 0), Vector3(0.14, 0.03, 0.03), _edge, 0.006)
			k.box(Vector3(0, 0.6, 0), Vector3(0.06, 0.05, 0.05), _dark, 0.01)
	return k.commit()
