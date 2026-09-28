class_name SandboxController
extends RefCounted
## Collante del sandbox (M5): cosa fa l'oggetto in mano quando si tocca o si
## tiene premuto sul mondo, effetti della raccolta. Il GameRoot lo chiama con i
## raggi gia' calcolati dallo schermo.

const REACH := 7.5
const USE_REACH := 3.2

var world: WorldData
var edits: WorldEditService
var catalog: BlockCatalog
var motor: PlayerMotor
var objects: WorldObjects
var vegetation: VegetationRuntime
var items := PlayerItems.new()
var harvester := Harvester.new()
var grains: Grains
## Messaggio dell'ultima azione (riga di stato).
var message := ""
var _rng := RandomNumberGenerator.new()


func setup(w: WorldData, e: WorldEditService, cat: BlockCatalog, m: PlayerMotor, objs: WorldObjects, veg: VegetationRuntime) -> void:
	world = w
	edits = e
	catalog = cat
	motor = m
	objects = objs
	vegetation = veg
	harvester.world = w
	harvester.edits = e
	harvester.catalog = cat
	harvester.vegetation = veg
	harvester.items = items
	harvester.objects = objs
	harvester.reset()


## Tocco sul mondo: "placed", "open" (in `opened`), "attack" o "".
var opened: WorldObjects.Obj


func tap(origin: Vector3, dir: Vector3) -> String:
	opened = null
	var d := items.held_def()
	var o := objects.pick(origin, dir)
	if o != null and objects.center_of(o).distance_to(motor.eye_position()) <= USE_REACH and (d == null or d.kind != ItemDefinition.Kind.BLOCK):
		opened = o
		return "open"
	if d != null and (d.kind == ItemDefinition.Kind.BLOCK or d.kind == ItemDefinition.Kind.STATION):
		var hit := VoxelQuery.raycast(world, catalog.opaque_table(), origin, dir, 400.0)
		if hit != null and place(hit):
			return "placed"
		return ""
	return "attack"


## Posa l'oggetto in mano sulla faccia colpita (consuma 1).
func place(hit: VoxelQuery.VoxelHit) -> bool:
	var s := items.held()
	if s == null:
		return false
	var d := s.def()
	var cell := hit.cell + hit.normal
	if Axes.cell_center(hit.cell).distance_to(motor.eye_position()) > REACH:
		message = "troppo lontano"
		return false
	if objects.at(cell) != null:
		message = "occupato"
		return false
	if d.kind == ItemDefinition.Kind.BLOCK:
		if catalog.is_solid(d.block_id) and motor.overlaps_cell(cell):
			message = "occupato dal giocatore"
			return false
		if not edits.can_place(cell, d.block_id):
			message = "non posabile"
			return false
		if not edits.set_block(cell, d.block_id, &"build").ok():
			message = "rifiutato"
			return false
	elif d.kind == ItemDefinition.Kind.STATION:
		if motor.overlaps_cell(cell):
			message = "occupato dal giocatore"
			return false
		var f := atan2(motor.position.x - (cell.x + 0.5), motor.position.z - (cell.z + 0.5))
		if objects.place(d.station, cell, roundi(f / (PI * 0.5))) == null:
			message = "serve un appoggio libero"
			return false
	else:
		return false
	items.inv.take(items.selected, 1)
	items.held_changed.emit()
	message = "posato %s" % d.display_name
	return true


## Raccolta tenendo premuto; restituisce il bersaglio (o null) e aggiorna gli effetti.
func mine(dt: float, origin: Vector3, dir: Vector3, dig_mult: float) -> Harvester.Target:
	var t := harvester.pick(origin, dir, motor.eye_position())
	if t != null and t.kind == "block" and objects.at(t.cell + Vector3i.UP) != null:
		message = "sopra c'e' un oggetto"
		harvester.reset()
		return null
	harvester.step(dt, t, dig_mult)
	return t


## Effetti e messaggi degli eventi della raccolta.
func handle_events() -> Array[Dictionary]:
	var out := harvester.events.duplicate()
	for e in harvester.events:
		match String(e["type"]):
			"broken":
				var dn: StringName = e["drop"]
				message = "+1 %s" % ItemLibrary.get_item(dn).display_name if dn != &"" else "niente da raccogliere senza l'attrezzo giusto"
				_dust(e["p"], catalog.get_def(int(e["id"])).top_color, 14)
			"felled":
				message = "+%d legno" % int(e["n"])
				_dust(e["p"], Color(0.55, 0.38, 0.2), 24)
			"picked":
				message = "raccolto"
			"full":
				message = "zaino pieno"
			"tool_broke":
				message = "l'attrezzo si e' rotto!"
	harvester.events.clear()
	return out


## Schegge durante lo scavo (una manciata a ogni colpo).
func chips(p: Vector3, color: Color) -> void:
	_dust(p, color, 5)


func _dust(p: Vector3, color: Color, n: int) -> void:
	if grains == null:
		return
	var el := "earth"
	if color.g > color.r * 1.1:
		el = "earth"
	for i in n:
		var g := Grains.Grain.new()
		g.p = p + Vector3(_rng.randf_range(-.4, .4), _rng.randf_range(-.2, .4), _rng.randf_range(-.4, .4))
		g.v = Vector3(_rng.randf_range(-2, 2), _rng.randf_range(1.5, 4.0), _rng.randf_range(-2, 2))
		g.el = el
		g.mode = 1
		g.life = _rng.randf_range(0.4, 0.8)
		g.s = _rng.randf_range(0.03, 0.06)
		g.g = 16.0
		g.t0 = 0.6
		g.ground = true
		grains.add(g)
