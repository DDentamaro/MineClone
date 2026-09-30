class_name LockOn
extends RefCounted
## Aggancio del bersaglio (D-035). Premendo Lock (tasto R o rotella) si
## aggancia il bersaglio migliore attorno all'eroe: vicino e davanti pesa di
## piu', ma vale anche uno alle spalle entro la portata. Premendo di nuovo si
## sgancia. L'aggancio cade da solo se il bersaglio si rompe o va oltre
## BREAK_RANGE. Mentre e' attivo l'eroe guarda il bersaglio (camminata laterale),
## e colpi d'arma e pugni partono verso di lui.
##
## Nessun nodo: gira nei test headless.

const RANGE := 14.0
const BREAK_RANGE := 18.0
## Peso dell'angolo (rad) rispetto alla distanza (m) nella scelta.
const ANGLE_W := 3.0

var target: CombatTarget


func active() -> bool:
	return target != null and target.alive


## Aggancia (ritorna vero) o sgancia (falso).
func toggle(from: Vector3, facing: float, targets: Array) -> bool:
	if active():
		target = null
		return false
	target = pick(from, facing, targets)
	return target != null


func clear() -> void:
	target = null


static func pick(from: Vector3, facing: float, targets: Array) -> CombatTarget:
	var best: CombatTarget = null
	var best_score := INF
	for o in targets:
		var tg := o as CombatTarget
		if tg == null or not tg.alive:
			continue
		var v := Vector2(tg.position.x - from.x, tg.position.z - from.z)
		var d := v.length()
		if d > RANGE or absf(tg.position.y - from.y) > 4.0:
			continue
		var ang := absf(wrapf(CombatController.heading(v) - facing, -PI, PI)) if d > 0.05 else 0.0
		var score := d + ang * ANGLE_W
		if score < best_score:
			best_score = score
			best = tg
	return best


## Un passo: l'aggancio cade se il bersaglio non c'e' piu' (rotto, tolto dalla
## scena) o e' troppo lontano.
func step(from: Vector3, targets: Array) -> void:
	if target == null:
		return
	if not target.alive or not targets.has(target) or flat_dist(from) > BREAK_RANGE:
		target = null


func flat_dist(from: Vector3) -> float:
	return Vector2(target.position.x - from.x, target.position.z - from.z).length()


## Direzione (rotazione Y) dall'eroe al bersaglio.
func heading_from(from: Vector3) -> float:
	return CombatController.heading(Vector2(target.position.x - from.x, target.position.z - from.z))
