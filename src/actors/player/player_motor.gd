class_name PlayerMotor
extends RefCounted
## Locomozione a terra del giocatore, porting di Game.step del prototipo
## (righe 6929 e 6987–7039 dell'HTML v0_64) con collisioni autorevoli sui voxel.
##
## Regole conservate: velocita' 5,5, accelerazione 40 a terra / 14 in aria,
## controllo in aria 0,45, rampa automatica sui gradini fino a 1,05, discesa a
## passo fino a 1,08, incollaggio al suolo entro 0,08, salto con apice 2,1,
## gravita' 28, rallentamento di atterraggio dopo cadute > 1,2.
##
## Aggiunte rispetto al prototipo (D-011): il corpo ha un'altezza (1,4) e non
## attraversa i soffitti ne' le sporgenze all'altezza della testa; salendo verso
## un soffitto la testa si ferma sotto invece di "atterrare" sul tetto.
## Nuoto e alberi arrivano con M3/M2.

const SPEED := 5.5
const STEP_UP := 1.05
const STEP_DOWN := 0.08
const JUMP_H := 2.1
const GRAVITY := 28.0
const RADIUS := 0.26
const AIR_CTL := 0.45
const LAND_REC := 0.28
const RAMP := 1.15
## Altezza del corpo; e' anche quella usata dal prototipo per il controllo di
## sovrapposizione quando si piazza un blocco (riga 7101).
const HEIGHT := 1.9
## Quota degli occhi sopra i piedi (portata di costruzione, riga 7099).
const EYE := 1.6
const EPS := 0.001
const COYOTE_TIME := 0.10
const JUMP_BUFFER := 0.12
var _coyote := 0.0
var _jump_buffer := 0.0
var _jump_held := false

var world: WorldData
## Griglia 8x8 degli alberi (Vector2i -> Array[Vegetation.TreeSpot]), condivisa
## con VegetationRuntime. I tronchi sono cilindri da cui si viene spinti fuori.
var tree_grid := {}
var position := Vector3.ZERO
var velocity := Vector3.ZERO
var on_ground := false
var blocked := false
var ramp_on := false
var ramp_base := 0.0
var ramp_v := 0.0
var ramp_top := NAN
var land_t := 0.0
var down_v := 0.0
var air_time := 0.0
var fall_from := 0.0

# --- acqua (Game.stepWater, righe 6941–6982)
const SWIM_SPEED := 2.65
var swimming := false
## "dry", "wade", "swim", "fall".
var water_state := "dry"
var wade_depth := 0.0
var water: Dictionary = {}
var water_clock := 0.0
var swim_phase := 0.0
var swim_blend := 0.0
## Ingressi in acqua da trasformare in schizzi: {x, y, z, body, power}.
var water_events: Array[Dictionary] = []
var _water_contact := false

# --- guida del combattimento (M4): velocita' imposta per scatti e capriole,
# oppure scala dello stick durante i colpi.
var drive_on := false
var drive := Vector2.ZERO
var move_scale := 1.0


func _init(w: WorldData) -> void:
	world = w


## Posiziona i piedi sul suolo sotto `p` (come il bootstrap: p = spawn, y = ground()).
func place_at(p: Vector3) -> void:
	position = p
	position.y = ground(p.x, p.z)
	velocity = Vector3.ZERO
	on_ground = true
	ramp_on = false
	ramp_top = NAN
	land_t = 0.0
	down_v = 0.0
	fall_from = 0.0
	reset_jump_input()
	reset_water()


func reset_jump_input() -> void:
	_coyote = 0.0
	_jump_buffer = 0.0
	_jump_held = false


func reset_water() -> void:
	swimming = false
	water_state = "dry"
	wade_depth = 0.0
	water = {}
	water_clock = 0.0
	swim_phase = 0.0
	swim_blend = 0.0
	water_events.clear()
	_water_contact = false


func water_query(x: float = NAN, y: float = NAN, z: float = NAN) -> Dictionary:
	if world.water_level.is_empty():
		return {"wet": false, "level": 0.0, "depth": 0.0, "immersion": 0.0, "flowX": 0.0, "flowY": 0.0, "flowZ": 0.0, "body": 0, "falling": false}
	return FluidSystem.sample_water(world, position.x if is_nan(x) else x, position.y if is_nan(y) else y, position.z if is_nan(z) else z)


## Nuoto e guado. Restituisce true se il passo e' stato gestito in acqua.
func step_water(dt: float, move: Vector2, jump: bool) -> bool:
	water_clock += dt
	var w := water_query()
	water = w
	var wet := bool(w["wet"])
	var immersion := float(w["immersion"])
	var depth := float(w["depth"])
	var contact := wet and immersion > 0.06
	if contact and not _water_contact:
		water_events.append({"x": position.x, "z": position.z, "y": float(w["level"]), "body": int(w["body"]),
			"power": minf(2.5, 0.35 + absf(velocity.y) * 0.15)})
	_water_contact = contact
	wade_depth = immersion if contact else 0.0
	var keep := swimming and wet and depth > 0.65 and immersion > 0.18
	var enter := wet and depth > 0.9 and immersion > 0.76 and velocity.y < 2.0
	swimming = keep or enter
	water_state = "swim" if swimming else ("wade" if contact else "dry")
	# Un solo salto a terra e sul pelo dell'acqua: slancio, poi gravita'.
	if swimming and jump and immersion <= 1.05:
		start_jump()
		swimming = false
		water_state = "fall"
	swim_blend += (float(swimming) - swim_blend) * (1.0 - exp(-dt * 8.0))
	if not swimming:
		return false
	on_ground = false
	ramp_on = false
	land_t = 0.0
	down_v = 0.0
	air_time = 0.0
	fall_from = 0.0
	var im := move.length()
	var m := maxf(1.0, im)
	var k := 1.0 - exp(-dt * 3.8)
	var tx := move.x / m * SWIM_SPEED + float(w["flowX"])
	var tz := move.y / m * SWIM_SPEED + float(w["flowZ"])
	velocity.x += (tx - velocity.x) * k
	velocity.z += (tz - velocity.z) * k
	if not _swim_move(position.x + velocity.x * dt, position.z):
		velocity.x = 0.0
	if not _swim_move(position.x, position.z + velocity.z * dt):
		velocity.z = 0.0
	var q := water_query()
	water = q
	if bool(q["wet"]) and float(q["depth"]) > 0.65 and float(q["level"]) - position.y > 0.18:
		var target := float(q["level"]) - 0.72 + sin(water_clock * 2.8) * 0.025
		if bool(q["falling"]):
			velocity.y += (float(q["flowY"]) - velocity.y) * (1.0 - exp(-dt * 4.0))
		else:
			velocity.y = clampf(velocity.y + ((target - position.y) * 28.0 - velocity.y * 9.0) * dt, -6.0, 3.0)
		position.y += velocity.y * dt
		var floor_y := ground(position.x, position.z)
		if position.y < floor_y:
			position.y = floor_y
			velocity.y = maxf(0.0, velocity.y)
	else:
		swimming = false
		water_state = "fall"
		velocity.y -= GRAVITY * dt
		position.y += velocity.y * dt
	wade_depth = maxf(0.0, float(q["level"]) - position.y) if bool(q["wet"]) else 0.0
	swim_phase += dt * (0.65 + minf(1.0, im) * 0.7)
	return true


## Le sponde restano solide finche' la traiettoria di salto non le supera.
func _swim_move(nx: float, nz: float) -> bool:
	nx = clampf(nx, 1.0, world.size_x - 1.0)
	nz = clampf(nz, 1.0, world.size_z - 1.0)
	if ground(nx, nz) > position.y + 0.12:
		return false
	if not tree_grid.is_empty():
		var cx := int(nx / 8.0)
		var cz := int(nz / 8.0)
		for gz in range(cz - 1, cz + 2):
			for gx in range(cx - 1, cx + 2):
				for t: Vegetation.TreeSpot in tree_grid.get(Vector2i(gx, gz), []):
					if not t.dead and position.y < t.y + 4.2 * t.scale and Vector2(nx - t.x, nz - t.z).length() < 0.30 * t.scale + RADIUS:
						return false
	position.x = nx
	position.z = nz
	return true


func ground(x: float, z: float, y_ref: float = NAN) -> float:
	return VoxelQuery.field_support(world, x, z, RADIUS, position.y if is_nan(y_ref) else y_ref)


## Celle all'altezza della testa non coperte dalla ricerca del suolo (che
## guarda fino a floor(y + 1,08)).
func head_blocked(x: float, z: float, y: float) -> bool:
	return VoxelQuery.solid_in_rows(world, x, z, RADIUS, floori(y + 1.08) + 1, floori(y + HEIGHT - EPS))


## Il corpo intero sta in (x, y, z) senza compenetrare solidi.
func space_free(x: float, z: float, y: float) -> bool:
	return not VoxelQuery.solid_in_rows(world, x, z, RADIUS, floori(y + EPS), floori(y + HEIGHT - EPS))


## Quota massima raggiungibile dai piedi salendo da `y` in (x, z): sotto il primo
## solido sopra la ricerca del suolo.
func ceiling_limit(x: float, z: float, y: float) -> float:
	var from := floori(y + 1.08) + 1
	for row in range(maxi(from, 0), world.size_y):
		if VoxelQuery.solid_in_rows(world, x, z, RADIUS, row, row):
			return row - HEIGHT
	return INF


func start_jump() -> void:
	_coyote = 0.0
	_jump_buffer = 0.0
	velocity.y = sqrt(2.0 * GRAVITY * JUMP_H)
	on_ground = false
	ramp_on = false
	down_v = 0.0
	land_t = 0.0


## `move` e' la direzione voluta nel piano XZ (x -> X, y -> Z), lunghezza 0..1.
func step(dt: float, move: Vector2, jump: bool) -> void:
	var jump_pressed := jump and not _jump_held
	_jump_held = jump
	_jump_buffer = JUMP_BUFFER if jump_pressed else maxf(0.0, _jump_buffer - dt)
	_coyote = COYOTE_TIME if on_ground else maxf(0.0, _coyote - dt)
	if step_water(dt, move, jump_pressed):
		_coyote = 0.0
		_jump_buffer = 0.0
		return
	var speed := SPEED
	blocked = false
	if land_t > 0.0:
		land_t -= dt
		speed *= 0.35 + 0.65 * (1.0 - land_t / LAND_REC)
	if not on_ground:
		speed *= AIR_CTL
	if ramp_on:
		speed *= 0.72
	if wade_depth > 0.12:
		speed *= maxf(0.52, 1.0 - wade_depth * 0.42)
	var acc := 40.0 if on_ground else 14.0
	var target := move * speed * move_scale
	if move_scale < 0.5 and on_ground:
		# Durante un colpo i piedi si piantano: frenata rapida dopo lo scatto.
		acc = 120.0
	if drive_on:
		# Lo scatto usa la sua velocita'; la direzione serve anche alla rampa.
		target = drive
		var dl := drive.length()
		move = drive / dl * minf(1.0, dl) if dl > 1e-4 else Vector2.ZERO
		acc = 400.0 if on_ground else 60.0
	var cur := Vector2(velocity.x, velocity.z)
	var dv := target - cur
	var max_step := acc * dt * 1.3
	cur = target if dv.length() <= max_step else cur + dv.normalized() * max_step
	velocity.x = cur.x
	velocity.z = cur.y

	var nx := clampf(position.x + velocity.x * dt, 1.0, world.size_x - 1.0)
	var nz := clampf(position.z + velocity.z * dt, 1.0, world.size_z - 1.0)

	# Rampa: la direzione e' quella voluta (lo stick), non la velocita'.
	var im := move.length()
	var on := false
	if on_ground and im > 0.2:
		var d := move / im
		if not ramp_on:
			ramp_base = position.y
			ramp_v = 0.0
		var base := ramp_base
		var q := 0.03
		while q <= RAMP:
			var px := position.x + d.x * q
			var pz := position.z + d.y * q
			var gg := ground(px, pz)
			if gg > base + 0.30:
				if gg <= base + STEP_UP and space_free(px, pz, gg) and space_free(position.x, position.z, gg):
					var u := 1.0 - q / RAMP
					var e := u * u * (3.0 - 2.0 * u)
					ramp_v = minf(6.5, ramp_v + 34.0 * dt)
					var y := minf(base + (gg - base) * minf(1.0, e * 1.04), position.y + ramp_v * dt)
					if y > position.y:
						position.y = y
					else:
						ramp_v = maxf(0.0, ramp_v - 60.0 * dt)
					on = true
					ramp_top = gg
				break
			q += 0.05
	if not on and ramp_on and not is_nan(ramp_top) and position.y > ramp_top - 0.12 and ground(position.x, position.z) >= ramp_top - 0.01:
		position.y = ramp_top
	ramp_on = on
	if not on:
		ramp_top = NAN

	# Pareti: dove il suolo e' piu' alto del corpo, o la testa urta, non si entra.
	var g1 := ground(nx, nz)
	var top := position.y + 0.04
	if g1 > top or head_blocked(nx, nz, position.y):
		var ax := position.x + velocity.x * dt
		var az := position.z + velocity.z * dt
		var gx := ground(ax, position.z)
		var gz := ground(position.x, az)
		var mine := ramp_on and not is_nan(ramp_top) and g1 <= ramp_top + 0.01 and not head_blocked(nx, nz, position.y)
		if mine:
			nx = position.x
			nz = position.z
		elif gx <= top and not head_blocked(ax, position.z, position.y):
			nx = ax
			nz = position.z
			velocity.z = 0.0
		elif gz <= top and not head_blocked(position.x, az, position.y):
			nx = position.x
			nz = az
			velocity.x = 0.0
		else:
			nx = position.x
			nz = position.z
			velocity.x = 0.0
			velocity.z = 0.0
		blocked = true
	position.x = nx
	position.z = nz
	_push_out_of_trees()

	# Verticale.
	if _jump_buffer > 0.0 and (on_ground or _coyote > 0.0):
		start_jump()
	var g := ground(position.x, position.z)
	if on_ground and velocity.y <= 0.0:
		if ramp_on and position.y > g:
			velocity.y = 0.0
			down_v = 0.0
		elif g < position.y - STEP_DOWN and position.y - g <= 1.08:
			down_v = minf(minf(6.5, down_v + 30.0 * dt), 1.2 + (position.y - g) * 11.0)
			position.y = maxf(g, position.y - down_v * dt)
			velocity.y = 0.0
		elif g >= position.y - STEP_DOWN:
			position.y = g
			velocity.y = 0.0
			down_v = 0.0
		else:
			on_ground = false
			velocity.y = 0.0
	if not on_ground:
		var y0 := position.y
		velocity.y -= GRAVITY * dt
		position.y += velocity.y * dt
		if velocity.y > 0.0:
			var lim := ceiling_limit(position.x, position.z, y0)
			if position.y > lim:
				position.y = maxf(y0, lim)
				velocity.y = 0.0
		air_time += dt
		fall_from = maxf(fall_from if fall_from != 0.0 else position.y, position.y)
		# Il suolo va cercato dalla quota di partenza del passo: da quella nuova,
		# dopo un salto, la ricerca includerebbe il soffitto.
		g = ground(position.x, position.z, minf(y0, position.y))
		if position.y <= g:
			var drop := (fall_from if fall_from != 0.0 else g) - g
			position.y = g
			velocity.y = 0.0
			on_ground = true
			air_time = 0.0
			fall_from = 0.0
			if drop > 1.2:
				land_t = LAND_REC * minf(1.0, drop / 4.0)
				velocity.x *= 0.4
				velocity.z *= 0.4


## Tronchi: cilindro di raggio 0,30*scala fino a 4,2*scala (riga ~7020).
func _push_out_of_trees() -> void:
	if tree_grid.is_empty():
		return
	var cx := int(position.x / 8.0)
	var cz := int(position.z / 8.0)
	for gz in range(cz - 1, cz + 2):
		for gx in range(cx - 1, cx + 2):
			for t: Vegetation.TreeSpot in tree_grid.get(Vector2i(gx, gz), []):
				if t.dead or position.y > t.y + 4.2 * t.scale:
					continue
				var r := 0.30 * t.scale + RADIUS
				var dx := position.x - t.x
				var dz := position.z - t.z
				var d2 := dx * dx + dz * dz
				if d2 < r * r and d2 > 1e-6:
					var d := sqrt(d2)
					position.x = t.x + dx / d * r
					position.z = t.z + dz / d * r
					var vn := (velocity.x * dx + velocity.z * dz) / d
					if vn < 0.0:
						velocity.x -= dx / d * vn
						velocity.z -= dz / d * vn


func eye_position() -> Vector3:
	return position + Vector3(0, EYE, 0)


## Controllo di sovrapposizione del prototipo (riga 7101) per piazzare un blocco solido.
func overlaps_cell(cell: Vector3i) -> bool:
	var hw := RADIUS
	return cell.x + 1 > position.x - hw and cell.x < position.x + hw \
		and cell.z + 1 > position.z - hw and cell.z < position.z + hw \
		and cell.y + 1 > position.y and cell.y < position.y + HEIGHT
