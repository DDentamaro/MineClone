class_name Inventory
extends RefCounted
## Inventario a slot (zaino, forzieri). Ogni operazione conserva il totale degli
## oggetti: niente duplicazioni ne' perdite (test).

signal changed

var slots: Array[ItemStack] = []


func _init(size: int = 30) -> void:
	slots.resize(size)


func size() -> int:
	return slots.size()


func get_slot(i: int) -> ItemStack:
	return slots[i] if i >= 0 and i < slots.size() else null


func set_slot(i: int, s: ItemStack) -> void:
	slots[i] = s
	changed.emit()


func count(id: StringName) -> int:
	var n := 0
	for s in slots:
		if s != null and s.id == id:
			n += s.count
	return n


## Aggiunge una pila; restituisce quanti oggetti NON sono entrati.
func add(stack: ItemStack, first_slot: int = 0) -> int:
	if stack == null:
		return 0
	var left := stack.count
	var d := stack.def()
	if d == null:
		return left
	# Prima le pile uguali, poi gli slot vuoti.
	if stack.data.is_empty() and d.max_stack > 1:
		for i in range(first_slot, slots.size()):
			var s := slots[i]
			if s != null and s.can_merge(stack) and s.count < d.max_stack:
				var k := mini(left, d.max_stack - s.count)
				s.count += k
				left -= k
				if left == 0:
					break
	while left > 0:
		var free := -1
		for i in range(first_slot, slots.size()):
			if slots[i] == null:
				free = i
				break
		if free < 0:
			break
		var k := mini(left, d.max_stack)
		slots[free] = ItemStack.new(stack.id, k, stack.data)
		left -= k
	changed.emit()
	return left


func add_item(id: StringName, n: int = 1) -> int:
	return add(ItemStack.new(id, n))


## Toglie `n` oggetti del tipo; falso (e nessuna modifica) se non bastano.
func remove(id: StringName, n: int) -> bool:
	if count(id) < n:
		return false
	var left := n
	for i in range(slots.size() - 1, -1, -1):
		var s := slots[i]
		if s == null or s.id != id:
			continue
		var k := mini(left, s.count)
		s.count -= k
		left -= k
		if s.count == 0:
			slots[i] = null
		if left == 0:
			break
	changed.emit()
	return true


## Toglie `n` dallo slot `i`; restituisce la pila tolta.
func take(i: int, n: int = -1) -> ItemStack:
	var s := get_slot(i)
	if s == null:
		return null
	if n < 0 or n >= s.count:
		slots[i] = null
		changed.emit()
		return s
	s.count -= n
	changed.emit()
	return ItemStack.new(s.id, n, s.data)


## Sposta/unisce/scambia tra due slot (anche di inventari diversi).
static func move(a: Inventory, ia: int, b: Inventory, ib: int) -> void:
	if a == b and ia == ib:
		return
	var sa := a.slots[ia]
	var sb := b.slots[ib]
	if sa == null:
		return
	if sb != null and sb.can_merge(sa):
		var room := sb.def().max_stack - sb.count
		var k := mini(room, sa.count)
		sb.count += k
		sa.count -= k
		if sa.count == 0:
			a.slots[ia] = null
	else:
		a.slots[ia] = sb
		b.slots[ib] = sa
	a.changed.emit()
	if b != a:
		b.changed.emit()


## Quanti slot potrebbero ricevere ancora `id` (per le ricette).
func room_for(stack: ItemStack) -> int:
	var d := stack.def()
	var room := 0
	for s in slots:
		if s == null:
			room += d.max_stack
		elif s.can_merge(stack):
			room += d.max_stack - s.count
	return room


func total_items() -> int:
	var n := 0
	for s in slots:
		if s != null:
			n += s.count
	return n


func to_array() -> Array:
	var out := []
	for s in slots:
		out.append(s.to_dict() if s != null else null)
	return out


func load_array(a: Array) -> void:
	for i in slots.size():
		slots[i] = null
		if i < a.size() and a[i] is Dictionary:
			slots[i] = ItemStack.from_dict(a[i])
	changed.emit()
