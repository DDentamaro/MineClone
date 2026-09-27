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


func set_weapon(w: WeaponDefinition) -> void:
	rig.set_weapon(w)
	anim_state.weapon = w
	trail.clear()


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
	if magic != null:
		if magic.phase == MagicSystem.Phase.GATHER:
			s.gather = magic.w
		elif magic.phase == MagicSystem.Phase.RECOVER:
			s.release = clampf(magic.t / magic.spell().recover, 0.0, 1.0)
	rig.ik_enabled = s.gather < 0.0 and s.release < 0.0
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
