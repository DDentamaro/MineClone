class_name Harvester
extends RefCounted
## Raccolta tenendo premuto (M5): bersaglio (blocco, albero o oggetto piazzato)
## sotto il dito, avanzamento con i tempi di `Harvest`, rottura con il bottino
## nello zaino. Se il bottino non entra il blocco non si rompe (niente perdite).

const REACH := 4.5

class Target:
	extends RefCounted
	## "block", "tree", "object"
	var kind := ""
	var cell := Vector3i.ZERO
	var id := 0
	var tree: Vegetation.TreeSpot
	var object: Variant
	var point := Vector3.ZERO

	func key() -> String:
		match kind:
			"block":
				return "b%s" % cell
			"tree":
				return "t%s" % tree.get_instance_id()
		return "o%s" % point


var world: WorldData
var edits: WorldEditService
var catalog: BlockCatalog
var vegetation: VegetationRuntime
var items: PlayerItems
## Oggetti piazzati (stazioni, forzieri): li imposta il gioco.
var objects: WorldObjects
var progress := 0.0
var target: Target
var events: Array[Dictionary] = []
var _key := ""


## Bersaglio lungo il raggio (dal punto toccato), entro REACH dagli occhi.
func pick(origin: Vector3, dir: Vector3, eye: Vector3) -> Target:
	var best: Target = null
	var bt := INF
	var h := VoxelQuery.raycast(world, catalog.opaque_table(), origin, dir, 400.0)
	if h != null and Axes.cell_center(h.cell).distance_to(eye) <= REACH:
		best = Target.new()
		best.kind = "block"
		best.cell = h.cell
		best.id = h.id
		best.point = Axes.cell_center(h.cell)
		bt = h.distance
	# Tronchi: raggio contro il cilindro (resolveTarget del prototipo).
	if vegetation != null:
		for sp in vegetation.trees_near(eye.x, eye.z, 1):
			if Vector2(sp.x - eye.x, sp.z - eye.z).length() > REACH + 0.5:
				continue
			var r := 0.34 * sp.scale + 0.10
			var hgt := 4.0 * sp.scale * 0.75
			var ox := origin.x - sp.x
			var oz := origin.z - sp.z
			var a := dir.x * dir.x + dir.z * dir.z
			var bq := 2.0 * (ox * dir.x + oz * dir.z)
			var cq := ox * ox + oz * oz - r * r
			var disc := bq * bq - 4.0 * a * cq
			if a < 1e-6 or disc < 0.0:
				continue
			var t := (-bq - sqrt(disc)) / (2.0 * a)
			if t < 0.0:
				continue
			var y := origin.y + dir.y * t
			if y < sp.y - 0.2 or y > sp.y + hgt:
				continue
			if t < bt:
				bt = t
				best = Target.new()
				best.kind = "tree"
				best.tree = sp
				best.point = Vector3(sp.x, y, sp.z)
	if objects != null:
		var o: Variant = objects.pick(origin, dir)
		if o != null:
			var op: Vector3 = objects.center_of(o)
			var t := (op - origin).dot(dir)
			if t < bt and op.distance_to(eye) <= REACH:
				best = Target.new()
				best.kind = "object"
				best.object = o
				best.point = op
	return best


func time_for(t: Target, dig_mult: float) -> float:
	var tool := items.tool_def()
	match t.kind:
		"block":
			return Harvest.break_time(t.id, tool, dig_mult)
		"tree":
			return Harvest.tree_time(t.tree.scale, tool, dig_mult)
	return 0.6 / dig_mult


func reset() -> void:
	progress = 0.0
	target = null
	_key = ""


## Un passo di raccolta sul bersaglio `t`; 0..1 avanzamento.
func step(dt: float, t: Target, dig_mult: float = 1.0) -> float:
	if t == null:
		reset()
		return 0.0
	if t.key() != _key:
		_key = t.key()
		progress = 0.0
	target = t
	var tt := time_for(t, dig_mult)
	if tt == INF:
		return 0.0
	progress += dt / maxf(tt, 1e-3)
	if progress >= 1.0:
		var ok := complete(t)
		reset()
		return 1.0 if ok else 0.0
	return progress


## Rompe il bersaglio subito (regole della raccolta, niente perdite).
func complete(t: Target) -> bool:
	var tool := items.tool_def()
	match t.kind:
		"block":
			if t.cell.y == 0:
				return false
			var drop := ItemLibrary.drop_for_block(t.id) if Harvest.drops(t.id, tool) else &""
			if drop != &"" and items.inv.room_for(ItemStack.new(drop)) < 1:
				events.append({"type": "full", "p": t.point})
				return false
			var r := edits.set_block(t.cell, BlockCatalog.AIR, &"harvest")
			if not r.ok():
				return false
			if drop != &"":
				items.inv.add_item(drop, 1)
			events.append({"type": "broken", "p": t.point, "id": t.id, "drop": drop})
		"tree":
			var n := Harvest.tree_wood(t.tree.scale)
			if items.inv.room_for(ItemStack.new(&"wood")) < n:
				events.append({"type": "full", "p": t.point})
				return false
			vegetation.kill_tree(t.tree)
			items.inv.add_item(&"wood", n)
			events.append({"type": "felled", "p": t.point, "n": n, "tree": t.tree})
		"object":
			if objects == null or not objects.pick_up(t.object, items.inv):
				events.append({"type": "full", "p": t.point})
				return false
			events.append({"type": "picked", "p": t.point})
	if tool != null and t.kind != "object":
		if items.wear_held(1):
			events.append({"type": "tool_broke", "p": t.point})
	return true
