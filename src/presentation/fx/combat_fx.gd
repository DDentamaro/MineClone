class_name CombatFx
extends RefCounted
## Effetti dei colpi con il pool di grani (M4): scintille sul metallo, sbuffi
## per i pugni, anelli di polvere per gli urti a terra, paglia quando un
## manichino si rompe, polvere della capriola.

var grains: Grains
var world: WorldData
var _rng := RandomNumberGenerator.new()


func _g(p: Vector3, v: Vector3, el: String, mode: int, life: float, size: float, grav: float, drag: float, t0: float = 1.0) -> Grains.Grain:
	var g := Grains.Grain.new()
	g.p = p
	g.v = v
	g.el = el
	g.mode = mode
	g.life = life
	g.s = size
	g.g = grav
	g.drag = drag
	g.t0 = t0
	g.ground = true
	return grains.add(g) if grains != null else null


func hit(e: Dictionary) -> void:
	var p: Vector3 = e["position"]
	var dir: Vector3 = e["dir"]
	var a: AttackDefinition = e["attack"]
	var n := 16 + int(float(e.get("charge", 0.0)) * 16.0)
	if a.fx == "punch":
		for i in n:
			var v := (dir * 3.0 + _rand_dir() * 3.5)
			_g(p, v, "air", 0, _rng.randf_range(0.18, 0.32), 0.05, 2.0, 4.0)
	else:
		for i in n:
			var v := (dir * 5.0 + _rand_dir() * 5.5 + Vector3(0, 2.0, 0))
			var g := _g(p, v, "fire", 0, _rng.randf_range(0.16, 0.34), 0.028, 14.0, 1.5)
			if g != null:
				g.length = 0.09
				g.cool = 0.8
	# Paglia dal manichino.
	for i in 8:
		var v := dir * 2.5 + _rand_dir() * 2.0 + Vector3(0, 2.5, 0)
		_g(p, v, "earth", 1, _rng.randf_range(0.5, 0.9), 0.04, 9.0, 1.2, 0.85)


func impact(e: Dictionary) -> void:
	var c: Vector3 = e["position"]
	var a: AttackDefinition = e["attack"]
	var r := a.radial
	if world != null:
		c.y = VoxelQuery.field_height(world, c.x, c.z, c.y + 1.0)
	var n := int(26 + r * 10.0)
	for i in n:
		var ang := TAU * i / n + _rng.randf() * 0.2
		var d := Vector3(cos(ang), 0, sin(ang))
		var p := c + d * 0.35 + Vector3(0, 0.05, 0)
		_g(p, d * _rng.randf_range(r * 1.6, r * 2.6) + Vector3(0, _rng.randf_range(0.5, 2.2), 0), "earth", 1,
			_rng.randf_range(0.45, 0.8), 0.07, 5.0, 3.0, 0.7)
	for i in 10:
		_g(c + Vector3(0, 0.1, 0), _rand_dir() * 2.0 + Vector3(0, 4.0, 0), "earth", 1, 0.6, 0.05, 12.0, 1.0, 0.9)


func broke(d: TrainingDummy) -> void:
	var c := d.position + Vector3(0, 0.9, 0)
	for i in 40:
		var v := _rand_dir() * _rng.randf_range(2.0, 5.5) + Vector3(0, 3.5, 0)
		_g(c + _rand_dir() * 0.25, v, "earth", 1, _rng.randf_range(0.7, 1.2), 0.05, 12.0, 1.0, 0.95)
	for i in 14:
		_g(c, _rand_dir() * 2.0 + Vector3(0, 1.5, 0), "smoke", 1, _rng.randf_range(0.6, 1.0), 0.09, -0.5, 2.5, 0.8)


func dodge(p: Vector3, dir: Vector2) -> void:
	for i in 8:
		var v := Vector3(-dir.x, 0, -dir.y) * _rng.randf_range(1.0, 2.5) + _rand_dir() * 0.8 + Vector3(0, 0.8, 0)
		_g(p + Vector3(0, 0.05, 0), v, "smoke", 1, _rng.randf_range(0.35, 0.6), 0.06, 1.0, 3.0, 0.7)


func _rand_dir() -> Vector3:
	var v := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1))
	return v.normalized() if v.length() > 0.01 else Vector3.UP
