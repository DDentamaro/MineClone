class_name AttackDefinition
extends Resource
## Un colpo (M4, disegno nuovo — D-022). Tempi in secondi, distanze in unita'
## di mondo, angoli in gradi rispetto alla direzione del giocatore (positivo =
## verso la sua sinistra). Le pose chiave (`key_wind`, `key_strike`,
## `key_follow`) sono dizionari osso -> Vector3 in radianti: l'animatore passa
## da guardia a carica durante `windup`, scatta sul colpo durante `active` e
## rientra durante `recovery`.

enum Shape { ARC, THRUST, RADIAL }

@export var id: StringName
@export var display_name := ""
@export var windup := 0.12
@export var active := 0.10
@export var recovery := 0.25
## Frazione del recupero oltre la quale l'input bufferizzato parte subito.
@export var chain_at := 0.0
@export var shape: Shape = Shape.ARC
@export var arc_from := -80.0
@export var arc_to := 70.0
@export var reach_min := 0.3
@export var reach := 1.9
## Semi-larghezza della striscia colpita dagli affondi.
@export var width := 0.45
## Centro dell'area circolare (davanti al giocatore) e raggio.
@export var radial_ahead := 1.0
@export var radial := 2.0
@export var y_min := -0.2
@export var y_max := 1.8
@export var damage := 10.0
## Velocita' impressa al bersaglio in orizzontale e in verticale.
@export var knockback := 4.0
@export var launch := 0.0
@export var hitstop := 0.07
@export var shake := 0.15
## Scatto in avanti: distanza percorsa tra l'ultimo 30% della carica e la fine
## del colpo; con un bersaglio agganciato si adatta alla distanza.
@export var lunge := 0.6
## Distanza di contatto di questo colpo (m); < 0 = quella dell'arma (D-033).
@export var strike := -1.0
@export var move_scale := 0.12
## Affondo perforante (D-034, lancia): la striscia colpita continua per questi
## metri oltre la punta e prende ogni bersaglio in fila, non solo il primo.
@export var pierce := 0.0
## Piede che fa il passo d'attacco (-1 sinistro, +1 destro, 0 = nessun passo:
## giri e picchiate); l'altro resta piantato finche' il corpo non lo trascina.
@export var step_foot := -1.0
## Passo indietro (m) nella prima parte della carica, prima del colpo (D-047,
## lancia: tenere la distanza).
@export var backstep := 0.0
@export var next_light: StringName = &""
@export var next_heavy: StringName = &""
## > 0: lo stesso bersaglio puo' essere ricolpito dopo questo intervallo.
@export var rehit := 0.0
## Rotazione del corpo durante il colpo (gradi, multipli di 360).
@export var spin := 0.0
## Colpo in picchiata: la fase attiva dura fino all'atterraggio.
@export var plunge := false
## Carica tenendo premuto (secondi massimi, 0 = no) e moltiplicatore pieno.
@export var charge_max := 0.0
@export var charge_bonus := 1.0
## "spark" (metallo), "dust" (urto a terra), "punch".
@export var fx := "spark"
## Magia (D-055): "bolt" (dardo) o "ball" (palla); niente colpi di mischia,
## all'inizio della fase attiva parte il proiettile (evento "cast").
@export var cast := ""
@export var trail := true
@export var key_wind := {}
@export var key_strike := {}
@export var key_follow := {}


func total() -> float:
	return windup + active + recovery
