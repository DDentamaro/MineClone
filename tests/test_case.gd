class_name TestCase
extends RefCounted
## Base dei test: asserzioni che accumulano i fallimenti senza interrompere.

var current_failures: PackedStringArray = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		current_failures.append(msg)


func check_eq(got: Variant, expected: Variant, msg: String) -> void:
	if got != expected:
		current_failures.append("%s: ottenuto %s, atteso %s" % [msg, got, expected])
