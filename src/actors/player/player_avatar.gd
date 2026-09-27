class_name PlayerAvatar
extends Node3D
## Presentazione provvisoria del giocatore (capsula + "naso" verso -Z) finche'
## l'avatar modulare non arriva in M4. Ruota verso la direzione di marcia.

const TURN_RATE := 14.0

var facing := 0.0


func face_towards(dir: Vector2, dt: float) -> void:
	if dir.length_squared() < 0.0004:
		return
	var target := atan2(-dir.x, -dir.y)
	facing = lerp_angle(facing, target, 1.0 - exp(-dt * TURN_RATE))
	rotation.y = facing
