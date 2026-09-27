class_name Mulberry32
extends RefCounted
## Porting esatto di mulberry32 (ISO_CORE, core.js r.15): la chiusura JS diventa un
## oggetto con lo stato int32 `a`; next() restituisce un double in [0, 1).

const _U32 := 0xFFFFFFFF

var a: int = 0


func _init(seed_value: int) -> void:
	a = JsMath.i32(seed_value)


func next() -> float:
	var s := a + 0x6D2B79F5
	s &= _U32
	if s >= 0x80000000:
		s -= 0x100000000
	a = s
	var t := JsMath.imul(s ^ ((s & _U32) >> 15), 1 | s)
	t = JsMath.i32(t + JsMath.imul(t ^ ((t & _U32) >> 7), 61 | t)) ^ t
	return float((t ^ ((t & _U32) >> 14)) & _U32) / 4294967296.0
