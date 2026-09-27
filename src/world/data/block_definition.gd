class_name BlockDefinition
extends Resource
## Definizione immutabile di un tipo di blocco. Gli ID sono stabili e
## compatibili con ISO_CORE.B del prototipo v0_64 (docs/DECISIONS.md, D-005).

@export var id: int = 0
@export var key: StringName = &""
@export var display_name: String = ""
## Nasconde le facce adiacenti (ISO_CORE.OPAQUE).
@export var opaque: bool = false
## Blocca il movimento (ISO_CORE.SOLID).
@export var solid: bool = false
## Livello di luce emessa 0..15 (ISO_CORE.EMIT).
@export_range(0, 15) var emit: int = 0
