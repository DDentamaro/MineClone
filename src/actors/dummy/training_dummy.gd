class_name TrainingDummy
extends CombatTarget
## Manichino d'allenamento (M4): bersaglio per il combattimento finche' i
## nemici sono rinviati (D-009). Scivola e vola quando colpito, oscilla su una
## molla, si rompe a 0 PV e ricompare nel suo posto; poi torna a casa da solo.

const MAX_HP := 120.0
const GRAVITY := 28.0
const RESPAWN := 2.5
const REGEN_AFTER := 3.0

var home := Vector3.ZERO
var velocity := Vector3.ZERO
var hp := MAX_HP
## Inclinazione (radianti attorno a X e Z) e sua velocita'.
var tilt := Vector2.ZERO
var tilt_v := Vector2.ZERO
var flash := 0.0
var hits := 0
var on_ground := true
var down_t := 0.0
var _quiet := 0.0
var _since_hit := 99.0
## Evento di rottura da trasformare in effetti: consumato da chi disegna.
var broke := false


func _init(p: Vector3 = Vector3.ZERO) -> void:
	home = p
	position = p
	radius = 0.34
	height = 1.55


func take_hit(impulse: Vector3, damage: float) -> void:
	if not alive:
		return
	velocity += impulse
	if impulse.y > 0.0:
		on_ground = false
	# Il colpo spinge la sommita' nella direzione dell'impulso.
	tilt_v += Vector2(-impulse.z, impulse.x) * 0.9
	flash = 1.0
	hits += 1
	_since_hit = 0.0
	_quiet = 0.0
	hp -= damage
	if hp <= 0.0:
		hp = 0.0
		alive = false
		broke = true
		down_t = RESPAWN


func step(dt: float, world: WorldData) -> void:
	flash = maxf(0.0, flash - dt * 6.0)
	_since_hit += dt
	if not alive:
		down_t -= dt
		if down_t <= 0.0:
			respawn()
		return
	if _since_hit > REGEN_AFTER:
		hp = MAX_HP
	# Molla dell'oscillazione.
	var acc := -tilt * 110.0 - tilt_v * 7.0
	tilt_v += acc * dt
	tilt += tilt_v * dt
	tilt = tilt.limit_length(1.1)
	# Moto.
	var g := ground(world, position.x, position.z)
	velocity.y -= GRAVITY * dt
	var nx := position.x + velocity.x * dt
	var nz := position.z + velocity.z * dt
	if world != null:
		nx = clampf(nx, 1.0, world.size_x - 1.0)
		nz = clampf(nz, 1.0, world.size_z - 1.0)
		# Muro: niente ingresso dove il suolo supera di oltre mezzo blocco.
		if ground(world, nx, nz) > position.y + 0.55:
			velocity.x *= -0.3
			velocity.z *= -0.3
			nx = position.x
			nz = position.z
	position.x = nx
	position.z = nz
	position.y += velocity.y * dt
	g = ground(world, position.x, position.z)
	if position.y <= g:
		position.y = g
		if velocity.y < -7.0:
			velocity.y = -velocity.y * 0.28
			tilt_v += Vector2(-velocity.z, velocity.x) * 0.25 + Vector2(1.2, -0.8)
		else:
			velocity.y = 0.0
			on_ground = true
	else:
		on_ground = position.y - g < 0.02
	var fr := 7.0 if on_ground else 0.4
	velocity.x *= exp(-fr * dt)
	velocity.z *= exp(-fr * dt)
	# Ritorno a casa quando fermo.
	var speed := Vector2(velocity.x, velocity.z).length()
	_quiet = _quiet + dt if speed < 0.4 and on_ground else 0.0
	var to_home := Vector2(home.x - position.x, home.z - position.z)
	if _quiet > 1.4 and to_home.length() > 0.3:
		var v := to_home.normalized() * minf(2.2, to_home.length() * 3.0)
		position.x += v.x * dt
		position.z += v.y * dt
		_quiet = 1.5


func respawn() -> void:
	alive = true
	hp = MAX_HP
	position = home
	velocity = Vector3.ZERO
	tilt = Vector2.ZERO
	tilt_v = Vector2(0.6, 0.0)
	down_t = 0.0
	on_ground = true


func ground(world: WorldData, x: float, z: float) -> float:
	if world == null:
		return home.y
	return VoxelQuery.field_height(world, x, z, position.y + 0.5)


## Il manichino vacilla in proporzione allo stagger (e lo conta).
var stagger_total := 0.0


func stagger(amount: float, dir: Vector2) -> void:
	if not alive:
		return
	stagger_total += amount
	var d := dir.normalized() if dir.length() > 1e-4 else Vector2(0, -1)
	tilt_v += Vector2(-d.y, d.x) * amount * 0.035


func push(dv: Vector3, max_speed: float = 6.0) -> void:
	if not alive:
		return
	velocity += dv
	var h := Vector2(velocity.x, velocity.z)
	if h.length() > max_speed:
		h = h.normalized() * max_speed
		velocity.x = h.x
		velocity.z = h.y
	if dv.y > 0.0:
		on_ground = false
	_quiet = 0.0
	tilt_v += Vector2(-dv.z, dv.x) * 0.3
