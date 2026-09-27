class_name CombatTarget
extends RefCounted
## Qualcosa che i colpi del giocatore possono raggiungere: cilindro verticale
## (piedi in `position`). Oggi solo i manichini; i nemici (D-009) useranno la
## stessa interfaccia.

var position := Vector3.ZERO
var radius := 0.35
var height := 1.5
var alive := true


## `impulse`: velocita' impressa (orizzontale + lancio verticale).
func take_hit(_impulse: Vector3, _damage: float) -> void:
	pass
