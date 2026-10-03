class_name ItemDefinition
extends RefCounted
## Tipo di oggetto (M5). Le istanze concrete sono `ItemStack` (quantita' e dati
## propri: rarita', affissi, usura).

enum Kind { BLOCK, MATERIAL, TOOL, WEAPON, ARMOR, STATION }

var id: StringName
var display_name := ""
var kind: Kind = Kind.MATERIAL
var max_stack := 64
## Colore dell'icona (quadratino nella barra e negli slot).
var color := Color.WHITE
## Sigla breve per l'icona.
var glyph := ""
## BLOCK: blocco piazzato.
var block_id := -1
## TOOL: "pick", "shovel", "axe"; livello del materiale (1 legno .. 5 oro).
var tool_type := ""
var tier := 0
var speed := 1.0
## Usura massima (0 = infinita).
var durability := 0
## WEAPON: arma della WeaponLibrary e moltiplicatore del danno.
var weapon: StringName = &""
var damage := 1.0
## ARMOR: "head", "chest", "legs", "feet" e difesa.
var slot := ""
var defense := 0.0
## Bonus fisso del materiale (es. oro: Output).
var base_mods := {}
## STATION: tipo di oggetto piazzabile ("workbench", "furnace", "chest", "campfire").
var station := ""
## Materiale per il colore delle mesh (armature, armi).
var material := ""
## Forma dell'armatura sull'eroe (D-054, `AvatarRig.armor_boxes_for`): "" metallo,
## "iron" cavaliere, "leather", "leather_cap", "leather_hood".
var armor_style := ""
## Colore del pezzo sull'eroe (trasparente = quello del materiale).
var armor_color := Color(0, 0, 0, 0)


func is_equipment() -> bool:
	return kind == Kind.WEAPON or kind == Kind.ARMOR or kind == Kind.TOOL
