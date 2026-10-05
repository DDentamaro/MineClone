class_name ArenaDuel
extends RefCounted
## Scontro nell'arena (D-058): si vince mettendo l'avversario K.O. (D-059:
## niente sconfitta per uscita dal ring, si combatte anche fuori dal marmo).
## Round dopo round: conto alla rovescia, combattimento,
## esito; chi vince un round affronta un avversario piu' sveglio, con
## un'arma presa a caso fra quelle dell'armeria.

enum Phase { INTRO, FIGHT, END }

const INTRO_TIME := 3.2
const END_TIME := 3.6
## Il banner "COMBATTI!" resta per questo tempo all'inizio del combattimento.
const GO_TIME := 0.9

var phase: Phase = Phase.INTRO
var t := 0.0
var round_n := 0
var wins := 0
var losses := 0
## Livello dell'avversario (0..3): sale quando si vince.
var level := 0
var enemy_weapon := &"sword"
## Testo grande al centro e riga sotto (vuoti = niente).
var banner := ""
var banner_sub := ""
## Esito dell'ultimo round: "win", "lose" o "".
var result := ""
var rng := RandomNumberGenerator.new()
var center := Vector3.ZERO
## Mezzo lato del ring in metri (dal centro al bordo del marmo).
var half := 9.5


func _init(arena_cell: Vector3i = Vector3i.ZERO, seed_value: int = 0) -> void:
	center = Vector3(arena_cell.x + 0.5, arena_cell.y, arena_cell.z + 0.5)
	half = Arena.HALF + 0.5
	rng.seed = seed_value if seed_value != 0 else randi()


## Nuovo round: sceglie l'arma del rivale e riparte il conto alla rovescia.
func start_round(weapons: Array) -> void:
	round_n += 1
	phase = Phase.INTRO
	t = 0.0
	result = ""
	enemy_weapon = weapons[rng.randi() % weapons.size()]
	banner = "Round %d" % round_n


func active() -> bool:
	return phase == Phase.FIGHT


## Un passo. Restituisce "fight" all'inizio dello scontro, "win"/"lose" alla
## fine di un round, "next" quando si puo' preparare il round seguente.
func step(dt: float, player: FighterBody, enemy: FighterBody) -> String:
	t += dt
	match phase:
		Phase.INTRO:
			var left := INTRO_TIME - t
			banner = "Round %d" % round_n if left > 2.0 else str(ceili(left))
			banner_sub = "Avversario: %s" % _weapon_name(enemy_weapon) if left > 2.0 else ""
			if t >= INTRO_TIME:
				phase = Phase.FIGHT
				t = 0.0
				banner = "COMBATTI!"
				banner_sub = ""
				return "fight"
		Phase.FIGHT:
			if t > GO_TIME and banner == "COMBATTI!":
				banner = ""
			var out := ""
			var how := ""
			if not enemy.alive:
				out = "win"
				how = "K.O."
			elif not player.alive:
				out = "lose"
				how = "K.O."
			if out != "":
				phase = Phase.END
				t = 0.0
				result = out
				if out == "win":
					wins += 1
					level = mini(level + 1, FighterAI.LEVELS.size() - 1)
					banner = "VITTORIA"
				else:
					losses += 1
					banner = "SCONFITTA"
				banner_sub = "%s   Tu %d - %d Avversario" % [how, wins, losses]
				return out
		Phase.END:
			if t >= END_TIME:
				banner = ""
				banner_sub = ""
				return "next"
	return ""


static func _weapon_name(id: StringName) -> String:
	var names := {&"fists": "pugni", &"sword": "spada", &"spear": "lancia", &"hammer": "martello",
		&"greatsword": "spadone", &"staff": "bastone"}
	return String(names.get(id, String(id)))
