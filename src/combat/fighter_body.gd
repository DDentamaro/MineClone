class_name FighterBody
extends CombatTarget
## Corpo di chi combatte (D-058): il giocatore e il nemico dell'arena. Ha la
## vita e decide l'esito dei colpi con il proprio `CombatController`: schivata
## (invulnerabilita' della capriola), parata (guardia, danno ridotto e postura
## che cala), parata perfetta (nessun danno, l'attaccante stordito), colpo
## preso (danno, sollevamento, reazione). Gli eventi servono al gioco per
## numeri, scintille e suoni.

## Danno che passa comunque attraverso la guardia.
const CHIP := 0.15

var motor: PlayerMotor
var combat: CombatController
var max_hp := 100.0
var hp := 100.0
var flash := 0.0
## {type: "damage"/"block"/"parry"/"ko", p, damage}: consumati dal gioco.
var events: Array[Dictionary] = []


func _init(m: PlayerMotor, c: CombatController, hp_max: float = 100.0) -> void:
	motor = m
	combat = c
	max_hp = hp_max
	hp = hp_max
	radius = 0.3
	height = 1.5
	sync()


func sync() -> void:
	if motor != null:
		position = motor.position


func reset(hp_max: float = -1.0) -> void:
	if hp_max > 0.0:
		max_hp = hp_max
	hp = max_hp
	alive = true
	flash = 0.0
	events.clear()


func chest() -> Vector3:
	return position + Vector3(0, height * 0.6, 0)


func receive_hit(attacker: CombatController, from: Vector3, impulse: Vector3, damage: float, parryable: bool = true) -> int:
	if not alive:
		return EVADE
	var unblockable := attacker != null and attacker.perilous
	var res := combat.defend(from, position, parryable, unblockable)
	var push := Vector2(impulse.x, impulse.z)
	match res:
		EVADE:
			return res
		PARRY:
			# Deviazione (D-060): poca postura a chi devia, mai rotta.
			combat.add_posture(damage * CombatController.POSTURE_DEFLECT, Vector2.ZERO, true)
			events.append({"type": "parry", "p": chest()})
			return res
		BLOCK:
			var chip := damage * CHIP
			_damage(chip)
			combat.absorb(damage, push * 0.6)
			events.append({"type": "block", "p": chest(), "damage": chip})
			return res
	if combat.broken:
		# Colpo mortale sulla postura rotta (D-060).
		damage *= CombatController.DEATHBLOW_MULT
		combat.broken = false
		combat.posture = 0.0
		events.append({"type": "deathblow", "p": chest()})
		_damage(damage)
		if alive:
			combat.stun(0.7, push * 1.5, "stagger")
		return HIT
	_damage(damage)
	if alive:
		if impulse.y > 0.5:
			motor.velocity.y = maxf(motor.velocity.y, impulse.y)
			motor.on_ground = false
		if attacker == null and damage < 16.0:
			# Dardi di magia (D-060): feriscono e sbilanciano, ma non fanno
			# barcollare (a raffica bloccavano chi si avvicina).
			combat.add_posture(damage * CombatController.POSTURE_HIT, push)
		else:
			combat.react(damage, push)
	return HIT


## Colpi senza un attaccante (magia): da dove spinge l'impulso. La bruciatura
## (impulso nullo) passa sempre, senza reazione.
func take_hit(impulse: Vector3, damage: float) -> void:
	if not alive:
		return
	var h := Vector2(impulse.x, impulse.z)
	if h.length() < 0.01 and impulse.y <= 0.0:
		_damage(damage)
		return
	var from := position - Vector3(h.x, 0, h.y).normalized() * 2.0 if h.length() > 0.01 else position + Vector3(0, 0, -1)
	receive_hit(null, from, impulse, damage, false)


func push(dv: Vector3, max_speed: float = 6.0) -> void:
	if not alive:
		return
	motor.velocity += dv
	var h := Vector2(motor.velocity.x, motor.velocity.z)
	if h.length() > max_speed:
		h = h.normalized() * max_speed
		motor.velocity.x = h.x
		motor.velocity.z = h.y


func _damage(d: float) -> void:
	if d <= 0.0:
		return
	hp = maxf(0.0, hp - d)
	flash = 1.0
	events.append({"type": "damage", "p": chest(), "damage": d})
	if hp <= 0.0:
		alive = false
		events.append({"type": "ko", "p": chest()})


func step(dt: float) -> void:
	flash = maxf(0.0, flash - dt * 6.0)
	sync()
