class_name ItemStack
extends RefCounted
## Una pila di oggetti in uno slot. Gli oggetti con dati propri (rarita',
## affissi, usura) non si impilano.

var id: StringName
var count := 1
## rarity (0..3), mods {nome: valore}, wear (usura residua).
var data := {}


func _init(item_id: StringName = &"", n: int = 1, d: Dictionary = {}) -> void:
	id = item_id
	count = n
	data = d.duplicate(true)


func def() -> ItemDefinition:
	return ItemLibrary.get_item(id)


func can_merge(o: ItemStack) -> bool:
	return o != null and o.id == id and data.is_empty() and o.data.is_empty() and def().max_stack > 1


func duplicate_stack() -> ItemStack:
	return ItemStack.new(id, count, data)


func rarity() -> int:
	return int(data.get("rarity", 0))


func wear() -> int:
	return int(data.get("wear", def().durability))


func to_dict() -> Dictionary:
	return {"id": String(id), "n": count, "d": data}


static func from_dict(d: Dictionary) -> ItemStack:
	var id := StringName(String(d.get("id", "")))
	if ItemLibrary.get_item(id) == null:
		return null
	var s := ItemStack.new(id, maxi(1, int(d.get("n", 1))), d.get("d", {}))
	return s
