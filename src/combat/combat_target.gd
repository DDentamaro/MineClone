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


## Forza continua (getti, vuoto, ciclone, correnti): cambia la velocita' senza
## contare come colpo. `max_speed` limita la velocita' orizzontale risultante.
func push(_dv: Vector3, _max_speed: float = 6.0) -> void:
	pass


## Stagger (poise) di un colpo: fa vacillare il corpo senza spostarlo.
func stagger(_amount: float, _dir: Vector2) -> void:
	pass
