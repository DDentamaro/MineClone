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


static func build(kind: WeaponDefinition.Kind) -> ArrayMesh:
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
	k.blade(0.13, 0.84, 0.1, 0.028, 0.16, STEEL, STEEL_EDGE, Transform3D.IDENTITY, 0.085)
	# Sguscio: una lista scura sottile al centro delle due facce.
	k.box(Vector3(0, 0.42, 0), Vector3(0.018, 0.5, 0.032), DARK_STEEL, 0.0)


## Lancia: asta lunga con fasce di cuoio, puntale e ferro a foglia con alette.
static func _spear(k: MeshKit) -> void:
	k.prism(Vector3.ZERO, -0.62, 1.3, 0.03, 0.028, 6, WOOD)
	k.prism(Vector3.ZERO, -0.7, -0.62, 0.02, 0.034, 6, DARK_STEEL)
	for y in [-0.08, 0.1, -0.44]:
		k.prism(Vector3.ZERO, y, y + 0.07, 0.036, 0.036, 6, LEATHER)
	k.prism(Vector3.ZERO, 1.26, 1.34, 0.04, 0.034, 6, BRASS)
	k.box(Vector3(0, 1.3, 0), Vector3(0.12, 0.03, 0.04), DARK_STEEL, 0.008)
	k.blade(1.33, 1.48, 0.12, 0.034, 0.2, STEEL, STEEL_EDGE, Transform3D.IDENTITY, 0.1)
	# Nappa rossa sotto il ferro.
	k.box(Vector3(0.0, 1.18, 0.0), Vector3(0.07, 0.12, 0.07), CLOTH, 0.02, 0.6)


## Martello da guerra: manico lungo, testa squadrata con fasce e punta.
static func _hammer(k: MeshKit) -> void:
	k.prism(Vector3.ZERO, -0.28, 0.9, 0.034, 0.032, 6, WOOD)
	k.prism(Vector3.ZERO, -0.34, -0.28, 0.045, 0.045, 6, DARK_STEEL)
	k.prism(Vector3.ZERO, -0.1, 0.12, 0.04, 0.04, 6, LEATHER)
	k.box(Vector3(0, 0.98, 0), Vector3(0.44, 0.26, 0.26), DARK_STEEL, 0.035)
	k.box(Vector3(0.23, 0.98, 0), Vector3(0.05, 0.3, 0.3), STEEL, 0.02)
	k.box(Vector3(-0.23, 0.98, 0), Vector3(0.05, 0.3, 0.3), STEEL, 0.02)
	k.box(Vector3(0, 0.98, 0), Vector3(0.1, 0.28, 0.28), BRASS, 0.015)
	k.prism(Vector3(0, 1.1, 0), 0.0, 0.14, 0.05, 0.0, 4, STEEL)


## Spadone a due mani: lama larga e lunga, ricasso, guardia dritta.
static func _greatsword(k: MeshKit) -> void:
	k.prism(Vector3.ZERO, -0.3, 0.1, 0.032, 0.03, 6, LEATHER)
	k.box(Vector3(0, -0.34, 0), Vector3(0.09, 0.08, 0.09), BRASS, 0.02)
	k.box(Vector3(0, 0.12, 0), Vector3(0.42, 0.05, 0.07), DARK_STEEL, 0.014)
	k.box(Vector3(0.21, 0.12, 0), Vector3(0.05, 0.08, 0.08), BRASS, 0.012)
	k.box(Vector3(-0.21, 0.12, 0), Vector3(0.05, 0.08, 0.08), BRASS, 0.012)
	k.box(Vector3(0, 0.22, 0), Vector3(0.1, 0.16, 0.04), DARK_STEEL, 0.008)
	k.blade(0.3, 1.36, 0.17, 0.04, 0.2, STEEL, STEEL_EDGE, Transform3D.IDENTITY, 0.14)
	k.box(Vector3(0, 0.78, 0), Vector3(0.028, 0.86, 0.046), DARK_STEEL, 0.0)


## Pugni: fasce di cuoio con borchie (vanno su entrambe le mani).
static func _wraps(k: MeshKit) -> void:
	# Spazio mano: il pugno scende lungo -Y, le nocche guardano -Y.
	k.box(Vector3(0, -0.01, 0), Vector3(0.13, 0.06, 0.135), LEATHER, 0.018)
	k.box(Vector3(0, -0.075, 0), Vector3(0.125, 0.07, 0.13), LEATHER.lightened(0.12), 0.018)
	for x in [-0.035, 0.0, 0.035]:
		k.box(Vector3(x, -0.113, -0.02), Vector3(0.026, 0.02, 0.026), STEEL, 0.006)
