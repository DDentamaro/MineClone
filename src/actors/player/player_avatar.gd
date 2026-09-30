class_name PlayerAvatar
extends Node3D
## Eroe visibile (M4): scheletro a pezzi (`AvatarRig`), animazione
## procedurale (`AvatarAnimator`) e scia dell'arma. La logica sta nel motore
## e nel `CombatController`; qui si traduce il loro stato in una posa.

const TURN_RATE := 14.0
const ATTACK_TURN := 40.0
## Con il Lock (D-035) il corpo si gira sul bersaglio piu' in fretta della corsa.
const LOCK_TURN := 18.0

var facing := 0.0
var rig: AvatarRig
var animator := AvatarAnimator.new()
## Gambe del prototipo: piedi piantati e IK (D-028).
var gait := GaitLegs.new()
var _gait_w := 1.0
## Ultimo attacco visto (`CombatController.starts`): un numero nuovo = passo.
var _starts := 0
var _last_pos := Vector3.INF
var trail: WeaponTrail
var anim_state := AvatarAnimator.State.new()
var _turn_prev := 0.0
## Consapevolezza di combattimento: colpi o un manichino vicino tengono
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
func animate(dt: float, motor: PlayerMotor, combat: CombatController) -> void:
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
	# Guardia o riposo, e cambio d'arma.
	var busy := s.attack != null or s.dodge >= 0.0 or combat.combo > 0
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
	rig.ik_enabled = _relax < 0.5 and s.reach < 0.3
	if s.dodge >= 0.0 or s.attack != null:
		s.speed = 0.0 if s.attack != null else s.speed * 0.2
	if dt > 0.0:
		# Passo procedurale: piedi nel mondo, poi la posa dell'animatore sopra.
		var world := motor.world
		var xf := global_transform if is_inside_tree() else transform
		# Teletrasporto (falo', caricamento): i piedi si ripiantano sul posto.
		if xf.origin.distance_to(_last_pos) > 2.0:
			gait.reset()
		_last_pos = xf.origin
		_attack_step(motor, combat, s)
		gait.update(dt, xf, motor.velocity, motor.on_ground and not motor.swimming, PlayerMotor.SPEED,
			func(x: float, z: float) -> float:
				return VoxelQuery.field_height(world, x, z, motor.position.y + 0.6) if world != null else motor.position.y)
		var want := 0.0 if s.dodge >= 0.0 or s.swimming or motor.swimming else 1.0
		_gait_w += (want - _gait_w) * (1.0 - exp(-dt * 14.0))
		animator.gait = _gait_w > 0.5
		animator.stride_phase = gait.phase * TAU
		var pose := animator.update(dt, s)
		var gp := pose.duplicate()
		var gw := _gait_w
		gp[&"body_pos"] = (gp.get(&"body_pos", Vector3.ZERO) as Vector3) + Vector3(gait.sway, gait.body_y, 0) * gw
		gp[&"hips"] = (gp.get(&"hips", Vector3.ZERO) as Vector3) + Vector3(0, 0, -gait.sway * 1.6) * gw
		gp[&"spine"] = (gp.get(&"spine", Vector3.ZERO) as Vector3) + Vector3(-gait.lean, 0, 0) * gw
		rig.apply_pose(gp)
		gait.apply(rig, gw)
	var emit := s.attack != null and s.attack.trail and (s.phase == 1 or (s.phase == 2 and s.u < 0.12))
	if s.attack != null and s.attack.plunge:
		emit = s.phase == 1
	trail.color = Color(1.0, 0.78, 0.4) if combat.charge_fraction() > 0.5 else Color(0.72, 0.86, 1.0)
	trail.push(dt, rig.blade_segment(), emit and dt > 0.0)


## IK delle gambe nei colpi (D-034): all'avvio di ogni colpo il piede indicato
## fa un passo fin oltre il punto d'arrivo dello scatto, l'altro resta piantato
## (lo segue solo se il corpo va troppo avanti). Giri e picchiate: passo normale.
func _attack_step(motor: PlayerMotor, combat: CombatController, s: AvatarAnimator.State) -> void:
	var a := s.attack
	gait.hold = a != null and motor.on_ground and a.step_foot != 0.0 and not a.plunge
	if combat.starts == _starts:
		return
	_starts = combat.starts
	if not gait.hold:
		return
	var f := CombatController.forward(combat.facing)
	var fw := Vector3(f.x, 0, f.y)
	var rt := Vector3(-fw.z, 0, fw.x)
	var end := motor.position + fw * combat.lunge_dist()
	var to := end + fw * GaitLegs.LEAD + rt * (a.step_foot * GaitLegs.HIP_W)
	var dur := clampf(a.windup + a.active * 0.35, 0.1, 0.45)
	gait.step_to(a.step_foot, to, dur)
	# L'altro piede: resta piantato negli scatti corti; negli scatti lunghi
	# segue saltellando un filo dopo; se e' davanti all'arrivo torna dietro
	# (cambio di guardia).
	var rear := gait.legs[1] if a.step_foot < 0.0 else gait.legs[0]
	var lunge := combat.lunge_dist()
	if lunge > GaitLegs.LEASH or (rear.foot - end).dot(fw) > -GaitLegs.REAR * 0.5:
		gait.step_to(-a.step_foot, end - fw * GaitLegs.REAR - rt * (a.step_foot * GaitLegs.HIP_W), dur * 1.2)


func set_light(sun: float, blk: float) -> void:
	rig.set_light(sun, blk)
