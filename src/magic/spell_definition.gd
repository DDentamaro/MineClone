class_name SpellDefinition
extends Resource
## Un incantesimo (SPELLS del prototipo, HTML 8002–8006; inventario §8).

@export var id: StringName
@export var display_name := ""
@export var el := "fire"
@export var cost := 10.0
@export var cast_dur := 0.3
@export var recover := 0.2
@export var speed := 10.0
@export var grav := 0.0
@export var drag := 0.0
@export var life := 1.0
@export var r := 0.12
@export var wide := 0.0
@export var dmg := 10.0
@export var knock := 3.0
@export var area := 1.0
@export var status := ""


static var _all: Array[SpellDefinition] = []


## Ordine del prototipo: fuoco, acqua, terra, aria.
static func all() -> Array[SpellDefinition]:
	if _all.is_empty():
		_all = [
			_make(&"fire", "Dardo di fuoco", "fire", 14, .36, .22, 16, .16, .12, 1.4, .13, 0, 24, 3.2, 1.1, "burn"),
			_make(&"water", "Dardo d'acqua", "water", 12, .40, .24, 14, 1.0, .04, 1.7, .14, 0, 20, 4.4, 1.5, "wet"),
			_make(&"earth", "Masso", "earth", 18, .55, .30, 11, 1.0, 0, 2.2, .22, 0, 34, 6.0, 1.2, "slow"),
			_make(&"air", "Spina d'aria", "air", 9, .22, .16, 38, 0, 0, .40, .12, .45, 14, 8.0, .9, "pushed"),
		]
	return _all


static func _make(id: StringName, n: String, el: String, cost: float, cd: float, rec: float, sp: float, g: float, dr: float,
		life: float, r: float, wide: float, dmg: float, knock: float, area: float, st: String) -> SpellDefinition:
	var s := SpellDefinition.new()
	s.id = id
	s.display_name = n
	s.el = el
	s.cost = cost
	s.cast_dur = cd
	s.recover = rec
	s.speed = sp
	s.grav = g
	s.drag = dr
	s.life = life
	s.r = r
	s.wide = wide
	s.dmg = dmg
	s.knock = knock
	s.area = area
	s.status = st
	return s
