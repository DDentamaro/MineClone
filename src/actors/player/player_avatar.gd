class_name PlayerAvatar
extends Node3D
## Eroe visibile (M4): scheletro a pezzi (`AvatarRig`), animazione
## procedurale (`AvatarAnimator`) e scia dell'arma. La logica sta nel motore
## e nel `CombatController`; qui si traduce il loro stato in una posa.

const TURN_RATE := 14.0
const ATTACK_TURN := 40.0

var facing := 0.0
var rig: AvatarRig
var animator := AvatarAnimator.new()
var trail: WeaponTrail
var anim_state := AvatarAnimator.State.new()
var _turn_prev := 0.0
## Consapevolezza di combattimento: colpi, magia o un manichino vicino tengono
## la guardia; dopo 2,5 s di calma ci si rilassa.
var aware_t := 0.0
var _relax := 0.0
## Cambio d'arma in corso: tempo trascorso e arma in arrivo.
const SWAP_TIME := 0.46
var _swap_t := -1.0
var _swap_to: WeaponDefinition
var _swap_mesh: ArrayMesh
## Scavo in corso: fase del colpo ripetuto (-1 = no).
var mining := -1.0


func _ready() -> void:
	for c in get_children():
		if c is MeshInstance3D:
			c.queue_free()
	rig = AvatarRig.new()
	rig.name = "Rig"
	add_child(rig)
	rig.build(AvatarRecipe.new())
	trail = WeaponTrail.new()
	trail.name = "Trail"
	add_child(trail)


func set_recipe(r: AvatarRecipe) -> void:
	rig.build(r)


func set_weapon(w: WeaponDefinition, mesh: ArrayMesh = null) -> void:
	rig.set_weapon(w, mesh)
	anim_state.weapon = w
	trail.clear()
	_swap_t = -1.0


## Cambio animato: la mano va dietro la spalla, l'arma cambia a meta'.
func swap_weapon(w: WeaponDefinition, mesh: ArrayMesh = null) -> void:
	if rig.weapon == null:
		set_weapon(w, mesh)
		return
	_swap_to = w
	_swap_mesh = mesh
	_swap_t = 0.0
	aware_t = 2.5


func swapping() -> bool:
	return _swap_t >= 0.0


func face_towards(dir: Vector2, dt: float) -> void:
	if dir.length_squared() < 0.0004:
		return
	turn_to(atan2(-dir.x, -dir.y), dt, TURN_RATE)


func turn_to(target: float, dt: float, rate: float) -> void:
	facing = lerp_angle(facing, target, 1.0 - exp(-dt * rate))
	rotation.y = facing


## Aggiorna posa e scia; `dt` = 0 durante l'hitstop (posa congelata).
func animate(dt: float, motor: PlayerMotor, combat: CombatController, magic: MagicSystem = null) -> void:
	var s := anim_state
	s.speed = Vector2(motor.velocity.x, motor.velocity.z).length()
	s.on_ground = motor.on_ground
	s.vy = motor.velocity.y
	s.swimming = motor.swimming
	s.swim_phase = motor.swim_phase
	s.wade = motor.wade_depth
	s.land = motor.land_t / PlayerMotor.LAND_REC if motor.land_t > 0.0 else 0.0
	if dt > 0.0:
		s.turn = wrapf(facing - _turn_prev, -PI, PI) / dt
	_turn_prev = facing
	s.attack = combat.attack if combat.state == CombatController.State.ATTACK else null
	s.phase = combat.phase()
	s.u = combat.phase_u()
	s.charge = combat.charge_fraction() if combat.charging else -1.0
	s.dodge = combat.dodge_u()
	s.gather = -1.0
	s.release = -1.0
	s.two_hands = false
	if magic != null:
		s.two_hands = magic.spell().two_handed()
		if magic.phase == MagicSystem.Phase.GATHER:
			s.gather = magic.w
		elif magic.phase == MagicSystem.Phase.RECOVER:
			s.release = clampf(magic.t / magic.spell().recover, 0.0, 1.0)
	# Guardia o riposo, e cambio d'arma.
	var busy := s.attack != null or s.dodge >= 0.0 or s.gather >= 0.0 or s.release >= 0.0 or combat.combo > 0
	if busy:
		aware_t = 2.5
	else:
		aware_t = maxf(0.0, aware_t - dt)
	_relax += ((1.0 if aware_t <= 0.0 else 0.0) - _relax) * (1.0 - exp(-dt * 4.0))
	s.relax = _relax
	s.mine = mining
	if mining >= 0.0:
		aware_t = 2.5
	s.reach = 0.0
	if _swap_t >= 0.0:
		var half := SWAP_TIME * 0.5
		var was := _swap_t
		_swap_t += dt
		if was < half and _swap_t >= half and _swap_to != null:
			rig.set_weapon(_swap_to, _swap_mesh)
			s.weapon = _swap_to
			trail.clear()
		s.reach = 1.0 - absf(_swap_t - half) / half
		if _swap_t >= SWAP_TIME:
			_swap_t = -1.0
	rig.ik_enabled = s.gather < 0.0 and s.release < 0.0 and _relax < 0.5 and s.reach < 0.3
	if s.dodge >= 0.0 or s.attack != null:
		s.speed = 0.0 if s.attack != null else s.speed * 0.2
	if dt > 0.0:
		rig.apply_pose(animator.update(dt, s))
	var emit := s.attack != null and s.attack.trail and (s.phase == 1 or (s.phase == 2 and s.u < 0.12))
	if s.attack != null and s.attack.plunge:
		emit = s.phase == 1
	trail.color = Color(1.0, 0.78, 0.4) if combat.charge_fraction() > 0.5 else Color(0.72, 0.86, 1.0)
	trail.push(dt, rig.blade_segment(), emit and dt > 0.0)


func set_light(sun: float, blk: float) -> void:
	rig.set_light(sun, blk)
