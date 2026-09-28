class_name Equipment
extends RefCounted
## Equipaggiamento del giocatore (M5): quattro pezzi d'armatura. L'arma o
## l'attrezzo e' l'oggetto in mano (slot scelto della barra rapida) e conta
## nelle statistiche se passato a `stats()`.

signal changed

const SLOTS := ["head", "chest", "legs", "feet"]
var slots := {}


func _init() -> void:
	for s in SLOTS:
		slots[s] = null


func get_slot(name: String) -> ItemStack:
	return slots.get(name)


## Slot adatto all'oggetto ("" se non si equipaggia).
static func slot_for(s: ItemStack) -> String:
	var d := s.def()
	if d.kind == ItemDefinition.Kind.ARMOR:
		return d.slot
	return ""


## Mette `s` nello slot giusto; restituisce cio' che c'era prima.
func equip(s: ItemStack) -> ItemStack:
	var k := slot_for(s)
	if k == "":
		return s
	var old: ItemStack = slots[k]
	slots[k] = s
	changed.emit()
	return old


func unequip(name: String) -> ItemStack:
	var old: ItemStack = slots.get(name)
	slots[name] = null
	changed.emit()
	return old


class Stats:
	extends RefCounted
	var defense := 0.0
	var melee := 1.0
	var crit := 0.0
	var mana_max := 0.0
	var mana_regen := 0.0
	var arcane := 1.0
	var dig := 1.0
	var speed := 1.0


func stats(held: ItemStack = null) -> Stats:
	var st := Stats.new()
	var list: Array = slots.values()
	if held != null and held.def().is_equipment():
		list.append(held)
	for s: ItemStack in list:
		if s == null:
			continue
		var d := s.def()
		st.defense += d.defense
		if d.kind == ItemDefinition.Kind.WEAPON:
			st.melee *= d.damage
		var mods: Dictionary = {}
		mods.merge(d.base_mods)
		for m: String in s.data.get("mods", {}):
			mods[m] = float(mods.get(m, 0.0)) + float(s.data["mods"][m])
		st.melee += float(mods.get("strength", 0.0))
		st.crit += float(mods.get("crit", 0.0))
		st.mana_max += float(mods.get("mana_max", 0.0))
		st.mana_regen += float(mods.get("mana_regen", 0.0))
		st.arcane += float(mods.get("arcane", 0.0))
		st.dig += float(mods.get("dig", 0.0))
		st.speed += float(mods.get("speed", 0.0))
	return st


## Colore del materiale per slot (trasparente = vuoto): per i pezzi sull'eroe.
func colors() -> Dictionary:
	var out := {}
	for k in SLOTS:
		var st: ItemStack = slots[k]
		out[k] = ItemLibrary.TIERS[st.def().tier - 1]["color"] if st != null else Color(0, 0, 0, 0)
	return out


func to_dict() -> Dictionary:
	var out := {}
	for k: String in slots:
		out[k] = (slots[k] as ItemStack).to_dict() if slots[k] != null else null
	return out


func load_dict(d: Dictionary) -> void:
	for k in SLOTS:
		slots[k] = ItemStack.from_dict(d[k]) if d.get(k) is Dictionary else null
	changed.emit()
