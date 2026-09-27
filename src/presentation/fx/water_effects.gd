class_name WaterEffects
extends Node
## Effetti d'acqua del prototipo (WATER_FX, HTML ~8013–8043): schizzi agli
## ingressi, scia e anelli quando si guada o nuota, schizzi delle bracciate,
## gocce ai piedi delle cascate vicine.

var motor: PlayerMotor
var water: FluidRuntime
var grains: Grains
var rng := RandomNumberGenerator.new()

var _wake := 0.0
var _last_stroke := -1
var _fall_clock := 0.0


func reset() -> void:
	_last_stroke = -1
	_wake = 0.0
	if water != null:
		water.clear_impulses()


func splash(x: float, y: float, z: float, power: float, body: int) -> void:
	water.add_impulse(x, y, z, power, body)
	var n := mini(22, ceili(5.0 + power * 7.0))
	for i in n:
		var a := rng.randf() * TAU
		var v := 0.4 + rng.randf() * power
		var g := Grains.Grain.new()
		g.el = "water"
		g.p = Vector3(x, y + 0.035, z)
		g.v = Vector3(cos(a) * v, 1.0 + rng.randf() * power * 1.8, sin(a) * v)
		g.g = 9.0
		g.life = 0.3 + rng.randf() * 0.35
		g.s = 0.024 + rng.randf() * 0.012
		g.t0 = 1.0
		g.cool = 0.4
		g.mode = 1
		g.water_drop = true
		grains.add(g)


func update(dt: float, facing: float) -> void:
	if motor == null or water == null or grains == null:
		return
	for e in motor.water_events:
		splash(float(e["x"]), float(e["y"]), float(e["z"]), float(e["power"]), int(e["body"]))
	motor.water_events.clear()
	var w := motor.water
	var sp := Vector2(motor.velocity.x, motor.velocity.z).length()
	_wake += dt
	if not w.is_empty() and bool(w["wet"]) and motor.wade_depth > 0.06 and sp > 0.12 and _wake > (0.24 if motor.swimming else 0.34):
		_wake = 0.0
		water.add_impulse(motor.position.x, float(w["level"]), motor.position.z, 0.65 if motor.swimming else 0.35, int(w["body"]))
		if not motor.swimming:
			splash(motor.position.x, float(w["level"]), motor.position.z, 0.18, int(w["body"]))
	# Bracciate: una mano alla volta (la posizione della mano arrivera' con l'avatar, M4).
	var stroke := floori(motor.swim_phase * 2.0)
	if motor.swimming and stroke != _last_stroke:
		_last_stroke = stroke
		var side := 1.0 if stroke % 2 != 0 else -1.0
		var fwd := Vector3(-sin(facing), 0, -cos(facing))
		var right := Vector3(cos(facing), 0, -sin(facing))
		var hand := motor.position + right * side * 0.3 + fwd * 0.25
		var q := motor.water_query(hand.x, motor.position.y, hand.z)
		if bool(q["wet"]):
			splash(hand.x, float(q["level"]), hand.z, 0.28, int(q["body"]))
	_fall_clock += dt
	if _fall_clock > 0.12:
		_fall_clock = 0.0
		var near: Array = []
		var f := water.falls
		for i in range(0, f.size(), 5):
			var d := Vector2(f[i] - motor.position.x, f[i + 2] - motor.position.z).length()
			if d < 22.0:
				near.append([d, i])
		near.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
		for k in mini(10, near.size()):
			var i: int = near[k][1]
			for j in 2:
				var g := Grains.Grain.new()
				g.el = "water"
				g.p = Vector3(f[i] + (rng.randf() - 0.5) * 0.5, f[i + 1] + 0.03, f[i + 2] + (rng.randf() - 0.5) * 0.5)
				g.v = Vector3((rng.randf() - 0.5) * 1.1, 1.0 + rng.randf() * minf(2.0, f[i + 3] * 0.35), (rng.randf() - 0.5) * 1.1)
				g.g = 7.0
				g.life = 0.35 + rng.randf() * 0.25
				g.s = 0.026
				g.t0 = 0.95
				g.cool = 0.5
				g.mode = 1
				g.water_drop = true
				grains.add(g)
