class_name PlayerItems
extends RefCounted
## Oggetti del giocatore (M5): zaino da 30 slot (i primi 6 sono la barra
## rapida), armatura, slot in mano, statistiche. L'oggetto in mano decide cosa
## fa un tocco sul mondo: blocco = posa, stazione = piazza, attrezzo/arma = colpo;
## tenere premuto scava o abbatte.

signal held_changed

const HOTBAR := 6

var inv := Inventory.new(30)
var equipment := Equipment.new()
var selected := 0
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.seed = 424242


func starter_kit() -> void:
	inv.add(Loot.make_equipment(&"sword_wood", 0, rng))


func select(i: int) -> void:
	selected = clampi(i, 0, HOTBAR - 1)
	held_changed.emit()


func held() -> ItemStack:
	return inv.get_slot(selected)


func held_def() -> ItemDefinition:
	var h := held()
	return h.def() if h != null else null


## Attrezzo in mano (per la raccolta) o null.
func tool_def() -> ItemDefinition:
	var d := held_def()
	return d if d != null and d.kind == ItemDefinition.Kind.TOOL else null


## Arma della WeaponLibrary usata dai colpi.
func weapon_id() -> StringName:
	var d := held_def()
	if d == null:
		return &"fists"
	if d.kind == ItemDefinition.Kind.WEAPON:
		return d.weapon
	if d.kind == ItemDefinition.Kind.TOOL:
		return &"tool"
	return &"fists"


## Moltiplicatore del danno dell'oggetto in mano (pugni 1; attrezzi 0,6).
func stats() -> Equipment.Stats:
	var st := equipment.stats(held())
	var d := held_def()
	if d != null and d.kind == ItemDefinition.Kind.TOOL:
		st.melee *= 0.6
	return st


## Consuma usura dell'oggetto in mano; vero se si e' rotto (e viene tolto).
func wear_held(n: int = 1) -> bool:
	var h := held()
	if h == null or not h.data.has("wear"):
		return false
	h.data["wear"] = int(h.data["wear"]) - n
	if int(h.data["wear"]) <= 0:
		inv.set_slot(selected, null)
		held_changed.emit()
		return true
	inv.changed.emit()
	return false


## Equipaggia l'armatura dello slot `i` dello zaino (scambio con quella indossata).
func equip_from(i: int) -> bool:
	var s := inv.get_slot(i)
	if s == null or Equipment.slot_for(s) == "":
		return false
	var old := equipment.equip(s)
	inv.set_slot(i, old)
	held_changed.emit()
	return true


func unequip_to_bag(slot_name: String) -> bool:
	var s := equipment.get_slot(slot_name)
	if s == null:
		return false
	if inv.room_for(s) < 1:
		return false
	equipment.unequip(slot_name)
	inv.add(s)
	held_changed.emit()
	return true


func to_dict() -> Dictionary:
	return {"inv": inv.to_array(), "eq": equipment.to_dict(), "sel": selected}


func load_dict(d: Dictionary) -> void:
	inv.load_array(d.get("inv", []))
	equipment.load_dict(d.get("eq", {}))
	selected = clampi(int(d.get("sel", 0)), 0, HOTBAR - 1)
	held_changed.emit()
