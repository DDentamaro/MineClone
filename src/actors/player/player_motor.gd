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
const HEIGHT := 1.4
## Quota degli occhi sopra i piedi (portata di costruzione, riga 7099).
const EYE := 0.7
const EPS := 0.001

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
	velocity.y = sqrt(2.0 * GRAVITY * JUMP_H)
	on_ground = false
	ramp_on = false
	down_v = 0.0
	land_t = 0.0


## `move` e' la direzione voluta nel piano XZ (x -> X, y -> Z), lunghezza 0..1.
func step(dt: float, move: Vector2, jump: bool) -> void:
	var speed := SPEED
	blocked = false
	if land_t > 0.0:
		land_t -= dt
		speed *= 0.35 + 0.65 * (1.0 - land_t / LAND_REC)
	if not on_ground:
		speed *= AIR_CTL
	if ramp_on:
		speed *= 0.72
	var acc := 40.0 if on_ground else 14.0
	var target := move * speed
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
	if jump and on_ground:
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
