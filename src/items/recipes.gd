class_name Recipes
extends RefCounted
## Ricette (M5). Stazione: "" a mano, "workbench" banco da lavoro, "furnace"
## fornace (entro 3 unita' dal giocatore).

class Recipe:
	extends RefCounted
	var out: StringName
	var count := 1
	var inputs := {}
	var station := ""


static var _list: Array[Recipe] = []


static func _r(out: StringName, n: int, inputs: Dictionary, station: String) -> void:
	var r := Recipe.new()
	r.out = out
	r.count = n
	r.inputs = inputs
	r.station = station
	_list.append(r)


static func all() -> Array[Recipe]:
	if not _list.is_empty():
		return _list
	_r(&"stick", 4, {&"wood": 1}, "")
	_r(&"workbench", 1, {&"wood": 4}, "")
	_r(&"campfire", 1, {&"wood": 3, &"stone": 2}, "")
	_r(&"torch", 2, {&"stick": 1, &"wood": 1}, "")
	_r(&"chest", 1, {&"wood": 6}, "workbench")
	_r(&"furnace", 1, {&"stone": 8}, "workbench")
	_r(&"sandstone", 1, {&"sand": 4}, "workbench")
	for m in ["copper", "iron", "gold"]:
		_r(StringName(m + "_ingot"), 1, {StringName(m + "_ore"): 1, &"wood": 1}, "furnace")
	var tools := {"pick": 3, "axe": 3, "shovel": 1}
	var weapons := {"sword": [2, 1], "spear": [1, 3], "hammer": [5, 2], "greatsword": [4, 1]}
	var armor := {"head": 5, "chest": 8, "legs": 7, "feet": 4}
	for t: Dictionary in ItemLibrary.TIERS:
		var mat: StringName = t["mat"]
		for k: String in tools:
			_r(StringName("%s_%s" % [k, t["key"]]), 1, {mat: tools[k], &"stick": 2}, "workbench")
		for k: String in weapons:
			var a: Array = weapons[k]
			_r(StringName("%s_%s" % [k, t["key"]]), 1, {mat: a[0], &"stick": a[1]}, "workbench")
		if ItemLibrary.ARMOR_TIER.has(t["key"]):
			for k: String in armor:
				_r(StringName("%s_%s" % [k, t["key"]]), 1, {mat: armor[k]}, "workbench")
	return _list


static func find(out: StringName) -> Recipe:
	for r in all():
		if r.out == out:
			return r
	return null


static func can_craft(r: Recipe, inv: Inventory, stations: Array) -> bool:
	if r.station != "" and not stations.has(r.station):
		return false
	for k: StringName in r.inputs:
		if inv.count(k) < int(r.inputs[k]):
			return false
	return true


## Esegue la ricetta: toglie gli ingredienti e aggiunge il prodotto (con rarita'
## tirata per l'equipaggiamento). Tutto o niente: se il prodotto non entra, nulla cambia.
static func craft(r: Recipe, inv: Inventory, stations: Array, rng: RandomNumberGenerator) -> ItemStack:
	if not can_craft(r, inv, stations):
		return null
	var d := ItemLibrary.get_item(r.out)
	var product: ItemStack
	if d.is_equipment():
		product = Loot.make_equipment(r.out, Loot.roll_rarity(rng, [80.0, 17.0, 3.0, 0.0]), rng)
	else:
		product = ItemStack.new(r.out, r.count)
	# Spazio: simulato su una copia prima di toccare l'inventario vero.
	var copy := Inventory.new(inv.size())
	for i in inv.size():
		copy.slots[i] = inv.slots[i].duplicate_stack() if inv.slots[i] != null else null
	for k: StringName in r.inputs:
		copy.remove(k, int(r.inputs[k]))
	if copy.add(product.duplicate_stack()) > 0:
		return null
	for k: StringName in r.inputs:
		inv.remove(k, int(r.inputs[k]))
	inv.add(product)
	return product
