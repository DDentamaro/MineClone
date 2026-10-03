class_name ItemLibrary
extends RefCounted
## Tutti gli oggetti (M5): blocchi, materiali, attrezzi, armi e armature in cinque
## materiali, stazioni. I materiali sono una scala: legno < pietra < rame < ferro
## < oro (l'oro e' morbido: meno usura).

const TIERS := [
	{"key": "wood", "name": "legno", "adj": "di legno", "tier": 1, "color": Color(0.62, 0.45, 0.26), "speed": 2.0, "dur": 60, "dmg": 0.8, "mat": &"wood", "mods": {}},
	{"key": "stone", "name": "pietra", "adj": "di pietra", "tier": 2, "color": Color(0.58, 0.58, 0.60), "speed": 4.0, "dur": 130, "dmg": 1.0, "mat": &"stone", "mods": {}},
	{"key": "copper", "name": "rame", "adj": "di rame", "tier": 3, "color": Color(0.80, 0.50, 0.30), "speed": 5.0, "dur": 200, "dmg": 1.15, "mat": &"copper_ingot", "mods": {}},
	{"key": "iron", "name": "ferro", "adj": "di ferro", "tier": 4, "color": Color(0.78, 0.80, 0.84), "speed": 6.5, "dur": 320, "dmg": 1.35, "mat": &"iron_ingot", "mods": {}},
	{"key": "gold", "name": "oro", "adj": "d'oro", "tier": 5, "color": Color(0.95, 0.78, 0.30), "speed": 9.0, "dur": 90, "dmg": 1.2, "mat": &"gold_ingot", "mods": {}},
]
const TOOLS := {"pick": "Piccone", "axe": "Ascia", "shovel": "Pala"}
const WEAPONS := {"sword": "Spada", "spear": "Lancia", "hammer": "Martello", "greatsword": "Spadone"}
## Difesa per pezzo di armatura e per materiale (solo metalli).
const ARMOR := {"head": ["Elmo", 1.0], "chest": ["Corazza", 2.0], "legs": ["Gambali", 1.5], "feet": ["Stivali", 0.8]}
const ARMOR_TIER := {"copper": 1.0, "iron": 1.6, "gold": 1.2}
## Colore del cuoio (D-054).
const LEATHER := Color(0.55, 0.33, 0.19)

static var _items := {}


static func get_item(id: StringName) -> ItemDefinition:
	if _items.is_empty():
		_build()
	return _items.get(id)


static func all() -> Array:
	if _items.is_empty():
		_build()
	return _items.values()


static func _add(d: ItemDefinition) -> ItemDefinition:
	_items[d.id] = d
	return d


static func _mk(id: StringName, n: String, kind: ItemDefinition.Kind, color: Color, glyph: String) -> ItemDefinition:
	var d := ItemDefinition.new()
	d.id = id
	d.display_name = n
	d.kind = kind
	d.color = color
	d.glyph = glyph
	if kind in [ItemDefinition.Kind.TOOL, ItemDefinition.Kind.WEAPON, ItemDefinition.Kind.ARMOR]:
		d.max_stack = 1
	return _add(d)


static func _build() -> void:
	var cat := BlockCatalog.load_default()
	var blocks := [[&"dirt", "Terra", BlockCatalog.DIRT], [&"sand", "Sabbia", BlockCatalog.SAND], [&"stone", "Pietra", BlockCatalog.STONE],
		[&"wood", "Legno", BlockCatalog.WOOD], [&"torch", "Torcia", BlockCatalog.TORCH], [&"sandstone", "Arenaria", BlockCatalog.SANDSTONE],
		[&"darkstone", "Pietra scura", BlockCatalog.DARKSTONE]]
	for b: Array in blocks:
		var d := _mk(b[0], b[1], ItemDefinition.Kind.BLOCK, cat.get_def(b[2]).top_color, String(b[1]).substr(0, 2))
		d.block_id = b[2]
	get_item(&"torch").color = Color(1.0, 0.75, 0.3)
	_mk(&"stick", "Bastone", ItemDefinition.Kind.MATERIAL, Color(0.55, 0.40, 0.22), "Ba")
	for m in [["copper", "rame", Color(0.80, 0.50, 0.30)], ["iron", "ferro", Color(0.78, 0.66, 0.58)], ["gold", "oro", Color(0.95, 0.78, 0.30)]]:
		_mk(StringName(m[0] + "_ore"), "%s grezzo" % String(m[1]).capitalize() if m[0] != "gold" else "Oro grezzo", ItemDefinition.Kind.MATERIAL, (m[2] as Color).darkened(0.25), "G" + String(m[1]).substr(0, 1))
		_mk(StringName(m[0] + "_ingot"), "Lingotto di %s" % m[1] if m[0] != "gold" else "Lingotto d'oro", ItemDefinition.Kind.MATERIAL, m[2], "L" + String(m[1]).substr(0, 1))
	for t: Dictionary in TIERS:
		for tt: String in TOOLS:
			var d := _mk(StringName("%s_%s" % [tt, t["key"]]), "%s %s" % [TOOLS[tt], t["adj"]], ItemDefinition.Kind.TOOL, t["color"], {"pick": "Pc", "axe": "As", "shovel": "Pa"}[tt])
			d.tool_type = tt
			d.tier = t["tier"]
			d.speed = t["speed"]
			d.durability = t["dur"]
			d.material = t["key"]
			d.base_mods = t["mods"]
		for w: String in WEAPONS:
			var d := _mk(StringName("%s_%s" % [w, t["key"]]), "%s %s" % [WEAPONS[w], t["adj"]], ItemDefinition.Kind.WEAPON, t["color"], String(WEAPONS[w]).substr(0, 2))
			d.weapon = StringName(w)
			d.tier = t["tier"]
			d.damage = t["dmg"]
			d.durability = t["dur"] * 2
			d.material = t["key"]
			d.base_mods = t["mods"]
		if ARMOR_TIER.has(t["key"]):
			for s: String in ARMOR:
				var a: Array = ARMOR[s]
				var d := _mk(StringName("%s_%s" % [s, t["key"]]), "%s %s" % [a[0], t["adj"]], ItemDefinition.Kind.ARMOR, t["color"], String(a[0]).substr(0, 2))
				d.slot = s
				d.tier = t["tier"]
				d.defense = snappedf(float(a[1]) * float(ARMOR_TIER[t["key"]]), 0.1)
				d.material = t["key"]
				d.base_mods = t["mods"]
				# D-054: il ferro e' l'armatura da cavaliere.
				if t["key"] == "iron":
					d.armor_style = "iron"
					d.armor_color = Color(0.60, 0.61, 0.64)
	# D-054: armatura di cuoio, leggera (difesa al 70% del rame), due copricapo.
	for a: Array in [[&"head_leather", "Casco di cuoio", "head", "leather_cap"], [&"head_leather_hood", "Cappuccio di cuoio", "head", "leather_hood"],
			[&"chest_leather", "Giubba di cuoio", "chest", "leather"], [&"legs_leather", "Gambali di cuoio", "legs", "leather"],
			[&"feet_leather", "Stivali di cuoio", "feet", "leather"]]:
		var d := _mk(a[0], a[1], ItemDefinition.Kind.ARMOR, LEATHER, String(a[1]).substr(0, 2))
		d.slot = a[2]
		d.tier = 1
		d.defense = snappedf(float(ARMOR[a[2]][1]) * 0.7, 0.1)
		d.material = "leather"
		d.armor_style = a[3]
		d.armor_color = LEATHER
	for st in [[&"workbench", "Banco da lavoro", "workbench", Color(0.66, 0.48, 0.28), "Bn"], [&"furnace", "Fornace", "furnace", Color(0.45, 0.44, 0.46), "Fo"],
			[&"chest", "Forziere", "chest", Color(0.72, 0.52, 0.26), "Fz"], [&"campfire", "Falò", "campfire", Color(0.95, 0.55, 0.20), "Fa"]]:
		var d := _mk(st[0], st[1], ItemDefinition.Kind.STATION, st[3], st[4])
		d.station = st[2]
		d.max_stack = 8


## Oggetto raccolto rompendo un blocco (null = niente).
static func drop_for_block(id: int) -> StringName:
	match id:
		BlockCatalog.GRASS, BlockCatalog.DIRT:
			return &"dirt"
		BlockCatalog.SAND:
			return &"sand"
		BlockCatalog.STONE:
			return &"stone"
		BlockCatalog.WOOD:
			return &"wood"
		BlockCatalog.TORCH:
			return &"torch"
		BlockCatalog.SANDSTONE:
			return &"sandstone"
		BlockCatalog.DARKSTONE:
			return &"darkstone"
		BlockCatalog.COPPER:
			return &"copper_ore"
		BlockCatalog.IRON:
			return &"iron_ore"
		BlockCatalog.GOLD:
			return &"gold_ore"
	return &""
