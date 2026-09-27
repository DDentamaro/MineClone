class_name WeaponDefinition
extends Resource
## Arma (M4): attacchi, catena di partenza, posa di guardia e geometria usata
## per la scia. La mesh e' costruita da `WeaponMeshes` a partire da `kind`.

enum Kind { FISTS, SWORD, SPEAR, HAMMER, GREATSWORD }

@export var id: StringName
@export var display_name := ""
@export var kind: Kind = Kind.SWORD
## La mano sinistra afferra l'impugnatura (IK a due ossa).
@export var two_handed := false
## Punto dell'impugnatura per la mano sinistra (spazio arma, lungo +Y).
@export var off_grip := -0.2
@export var light_start: StringName = &""
@export var heavy_start: StringName = &""
@export var dash_attack: StringName = &""
@export var air_attack: StringName = &""
## Velocita' di corsa relativa.
@export var move_mult := 1.0
## Segmento della lama per la scia (spazio arma, lungo +Y).
@export var trail_from := 0.2
@export var trail_to := 1.0
@export var guard := {}
@export var attacks := {}


func attack(attack_id: StringName) -> AttackDefinition:
	return attacks.get(attack_id)
