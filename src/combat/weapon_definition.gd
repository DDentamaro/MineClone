class_name WeaponDefinition
extends Resource
## Arma (M4): attacchi, catena di partenza, posa di guardia e geometria usata
## per la scia. La mesh e' costruita da `WeaponMeshes` a partire da `kind`.

enum Kind { FISTS, SWORD, SPEAR, HAMMER, GREATSWORD, STAFF }

@export var id: StringName
@export var display_name := ""
@export var kind: Kind = Kind.SWORD
@export var light_start: StringName = &""
@export var heavy_start: StringName = &""
@export var dash_attack: StringName = &""
@export var air_attack: StringName = &""
## Velocita' di corsa relativa.
@export var move_mult := 1.0
## Segmento della lama per la scia (spazio arma, lungo +Y).
@export var trail_from := 0.2
@export var trail_to := 1.0
## Hitbox dell'arma (D-028): sfere lungo il tratto che ferisce (spazio arma,
## lungo +Y; valori negativi = come la scia) e loro raggio in metri.
@export var hit_from := -1.0
@export var hit_to := -1.0
@export var hit_r := 0.09
## Distanza vera (m) dal centro dell'eroe al centro del bersaglio a cui l'arma
## lo prende in pieno (D-033): l'affondo porta qui, non piu' oltre.
@export var strike_dist := 1.1
@export var guard := {}
## Slancio (D-047, spadone): ogni colpo leggero concatenato aggiunge questo
## al moltiplicatore del danno, fino a `momentum_max` passi; il forte dalla
## catena lo usa tutto; una catena nuova riparte da zero.
@export var momentum_step := 0.0
@export var momentum_max := 3
## Posa rilassata (fuori combattimento dopo 2,5 s di calma).
@export var relaxed := {}
@export var attacks := {}


func attack(attack_id: StringName) -> AttackDefinition:
	return attacks.get(attack_id)
