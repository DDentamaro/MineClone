class_name Fighter
extends Node3D
## Nemico che combatte come il giocatore (D-058): gli stessi pezzi
## (`PlayerMotor`, `CombatController`, `PlayerAvatar`, `FireMagic` per il
## bastone) guidati da `FighterAI` invece che dai tasti. Il passo segue lo
## stesso ordine di quello del giocatore in `GameRoot._physics_process`.

var world: WorldData
var objects: WorldObjects
var motor: PlayerMotor
var combat: CombatController
var body: FighterBody
var avatar: PlayerAvatar
var magic: FireMagic
var ai: FighterAI
## Eventi del controller e della magia da trasformare in effetti dal gioco.
var events: Array[Dictionary] = []
var _pending_casts: Array = []


func setup(w: WorldData, objs: WorldObjects, recipe: AvatarRecipe, catalog: BlockCatalog) -> void:
	world = w
	objects = objs
	motor = PlayerMotor.new(w)
	combat = CombatController.new(WeaponLibrary.by_id(&"sword"))
	combat.world = w
	combat.opaque = catalog.opaque_table() if catalog != null else PackedByteArray()
	body = FighterBody.new(motor, combat, 100.0)
	if avatar == null:
		avatar = PlayerAvatar.new()
		avatar.name = "Avatar"
		add_child(avatar)
		magic = FireMagic.new()
		magic.name = "Magic"
		add_child(magic)
	avatar.set_recipe(recipe)
	magic.world = w
	ai = FighterAI.new()


func set_weapon(id: StringName) -> void:
	var wd := WeaponLibrary.by_id(id)
	combat.set_weapon(wd)
	avatar.set_weapon(wd)


## Pronto a un round: in `p`, girato verso `face`, vita piena.
func place(p: Vector3, face: float, hp: float = 100.0) -> void:
	motor.place_at(p)
	combat.cancel()
	combat.release_guard()
	combat.release_heavy()
	combat.hitstop = 0.0
	body.reset(hp)
	body.sync()
	avatar.facing = face
	avatar.rotation.y = face
	avatar.position = motor.position
	avatar.gait.reset()
	ai.reset()
	magic.clear()
	visible = true


## Un passo di fisica. `foe`: il corpo da colpire; `foe_c`: il suo controller
## (l'IA guarda cosa prepara); `foe_shots`: i suoi proiettili; ring per l'IA.
func step(dt: float, foe: FighterBody, foe_c: CombatController, foe_shots: Array, center: Vector3, half: float, active: bool) -> void:
	var stick := Vector2.ZERO
	var jump := false
	if active and body.alive:
		ai.think(dt, combat, motor, foe, foe_c, foe_shots, center, half)
		stick = ai.stick
		jump = ai.jump
	elif combat.guarding():
		combat.release_guard()
	var targets: Array = [foe] if foe != null and foe.alive and active else []
	if not combat.is_busy():
		combat.facing = avatar.facing
	combat.forced = foe if foe != null and foe.alive and active else null
	# Clash delle lame (D-060) contro il controller dell'avversario.
	combat.rival = foe_c if active else null
	if foe != null:
		combat.rival_position = foe.position
	combat.hitboxes = avatar.rig.hitboxes()
	if body.alive:
		combat.step(dt, motor, targets, stick)
	for e in combat.events:
		if String(e["type"]) == "cast":
			var f := CombatController.forward(float(e["facing"]))
			_pending_casts.append([e["attack"], Vector3(f.x, 0, f.y), float(e["charge"]), e.get("target")])
		events.append(e)
	combat.events.clear()
	var frozen := combat.hitstop > 0.0
	if not frozen:
		motor.drive_on = combat.drive_on
		motor.drive = combat.drive
		motor.move_scale = combat.move_scale * combat.weapon.move_mult
		# Passo laterale piu' lento girando attorno; si corre attaccando o inseguendo.
		if combat.state == CombatController.State.IDLE and not ai.mode in ["offense", "counter", "dash", "leap"]:
			motor.move_scale *= GameRoot.STRAFE_SPEED
		if not body.alive:
			motor.drive_on = false
			stick = Vector2.ZERO
		motor.step(dt, stick, jump and not combat.is_busy())
		if objects != null:
			motor.position = objects.push_out(motor.position, PlayerMotor.RADIUS)
		avatar.position = motor.position
		if combat.is_busy():
			avatar.turn_to(combat.facing, dt, PlayerAvatar.ATTACK_TURN)
		elif foe != null and foe.alive and active:
			var v := Vector2(foe.position.x - motor.position.x, foe.position.z - motor.position.z)
			if v.length() > 0.2:
				avatar.turn_to(CombatController.heading(v), dt, PlayerAvatar.LOCK_TURN)
		else:
			avatar.face_towards(Vector2(motor.velocity.x, motor.velocity.z), dt)
	avatar.aware_t = 2.5
	avatar.animate(0.0 if frozen else dt, motor, combat)
	body.step(dt)
	# Bastone: la magia parte dalla gemma nella posa appena calcolata.
	var fw := CombatController.forward(combat.facing)
	magic.set_gem(combat.weapon.kind == WeaponDefinition.Kind.STAFF, gem(), Vector3(fw.x, 0, fw.y))
	for c: Array in _pending_casts:
		magic.cast(c[0], gem(), c[1], c[2], c[3], combat.damage_mult, body)
	_pending_casts.clear()
	var ca := combat.attack if combat.state == CombatController.State.ATTACK else null
	if ca != null and ca.cast != "" and combat.phase() == 0:
		var u := combat.t / maxf(ca.windup, 0.01)
		magic.casting(ca.cast, u, maxf(combat.charge_fraction(), u * 0.35) if ca.cast == "ball" else 0.0)
	else:
		magic.casting("", 0.0, 0.0)
	magic.step(0.0 if frozen else dt, targets)
	for e in magic.events:
		events.append(e)
	magic.events.clear()


func gem() -> Vector3:
	var rig := avatar.rig
	if rig.socket != null and rig.weapon != null and rig.weapon.kind == WeaponDefinition.Kind.STAFF:
		return rig.socket.global_transform * Vector3(0, WeaponMeshes.STAFF_GEM_Y, 0)
	return motor.position + Vector3(0, 1.0, 0)


func set_light(sun: float, blk: float) -> void:
	avatar.set_light(sun, blk)
	avatar.rig.set_flash(body.flash * 0.85, Color.WHITE)


## I due rivali si tengono a vicenda (bersaglio agganciato, proiettili visti):
## si spezza il giro prima di sparire, o restano in memoria.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and combat != null:
		combat.forced = null
		combat.lock_target = null
		combat.forget_targets()
		combat.events.clear()
		if ai != null:
			ai.reset()
		if magic != null:
			magic.clear()
		events.clear()
		_pending_casts.clear()
