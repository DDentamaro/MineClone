class_name ArenaDecor
extends Node3D
## Arredo dell'arena (D-063, piano grafico F6), dalla reference del
## proprietario: stendardi blu e oro sulle quattro colonne, lanterne accese
## sui pali agli angoli del ring, casse e barili, cespugli fioriti lungo il
## bordo, edera sulle colonne. Solo scena: niente collisioni ne' oggetti da
## usare (stanno fuori dal marmo o addosso alle colonne).

const BANNER := Color(0.16, 0.24, 0.52)
const GOLD := Color(0.86, 0.68, 0.30)
const WOOD := Color(0.42, 0.28, 0.16)
const WOOD_D := Color(0.30, 0.20, 0.12)
const IRON := Color(0.22, 0.22, 0.24)

var _actor_mat: ShaderMaterial
var _glow_mat: StandardMaterial3D
var _lights: Array[OmniLight3D] = []


func _init() -> void:
	_actor_mat = ShaderMaterial.new()
	_actor_mat.shader = preload("res://src/presentation/shaders/actor.gdshader")
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.vertex_color_use_as_albedo = true
	_glow_mat.emission_enabled = true
	_glow_mat.emission = Color(1.0, 0.66, 0.30)
	_glow_mat.emission_energy_multiplier = 1.6


func clear() -> void:
	for c in get_children():
		c.queue_free()
	_lights.clear()


## Arredo attorno al ring con centro `arena` (cella del centro, y = piano del marmo).
func build(w: WorldData, arena: Vector3i) -> void:
	clear()
	var c := Vector3(arena.x + 0.5, arena.y, arena.z + 0.5)
	var h := float(Arena.HALF)
	var kit := MeshKit.new()
	var glow := MeshKit.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = w.world_seed * 31 + 7
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var pillar := c + Vector3(sx * h, 0, sz * h)
			# Stendardo sulla faccia interna (verso il centro, lungo x).
			_banner(kit, pillar + Vector3(-sx * 0.52, 2.6, 0), Vector3(-sx, 0, 0))
			_ivy(kit, pillar, sx, sz, rng)
			# Lanterna su un palo appena fuori dall'angolo del ring.
			var post := pillar + Vector3(sx * 1.3, -1.0, -sz * 0.0) + Vector3(0, 0, sz * 1.3)
			post.y = _ground(w, post, c.y)
			_lantern(kit, glow, post)
	# Casse e barili in due angoli, cespugli fioriti lungo il bordo.
	_crates(kit, c + Vector3(h + 2.4, 0, -h + 1.5), w, c.y, rng)
	_crates(kit, c + Vector3(-h - 2.2, 0, h - 2.0), w, c.y, rng)
	for i in 26:
		var side := i % 4
		var t := rng.randf_range(-h + 1.5, h - 1.5)
		var off := h + 1.25
		var p := c + (Vector3(t, 0, off) if side == 0 else (Vector3(t, 0, -off) if side == 1 else (Vector3(off, 0, t) if side == 2 else Vector3(-off, 0, t))))
		p.y = _ground(w, p, c.y)
		_bush(kit, p, rng)
	_add(kit.commit(), _actor_mat)
	_add(glow.commit(), _glow_mat)


func _add(mesh: ArrayMesh, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)


## Quota del suolo sotto `p` (prima cella piena scendendo da poco sopra il ring).
static func _ground(w: WorldData, p: Vector3, ring_y: float) -> float:
	var x := floori(p.x)
	var z := floori(p.z)
	for y in range(int(ring_y) + 2, maxi(0, int(ring_y) - 8), -1):
		if w.is_solid_at(x, y, z):
			return float(y + 1)
	return ring_y - 1.0


func _banner(k: MeshKit, at: Vector3, n: Vector3) -> void:
	var side := Vector3(n.z, 0, -n.x)
	var yaw := atan2(side.x, side.z)
	var xf := Transform3D(Basis(Vector3.UP, yaw), at)
	# Asta, telo blu con orlo d'oro e stemma a losanga, punta in basso.
	k.box(Vector3(0, 1.05, 0), Vector3(0.08, 0.08, 1.15), WOOD_D, 0.01, 1.0, xf)
	k.box(Vector3(0, 0.0, 0), Vector3(0.05, 2.0, 0.9), BANNER, 0.01, 1.0, xf)
	for y in [0.92, -0.92]:
		k.box(Vector3(0, y, 0), Vector3(0.06, 0.07, 0.92), GOLD, 0.01, 1.0, xf)
	for sz in [-0.44, 0.44]:
		k.box(Vector3(0, 0, sz), Vector3(0.06, 1.9, 0.05), GOLD, 0.005, 1.0, xf)
	var dia := Transform3D(Basis(Vector3.RIGHT, PI * 0.25), Vector3(0, 0.15, 0))
	k.box(Vector3.ZERO, Vector3(0.07, 0.42, 0.42), GOLD, 0.01, 1.0, xf * dia)
	k.box(Vector3.ZERO, Vector3(0.08, 0.2, 0.2), Color(0.95, 0.92, 0.80), 0.01, 1.0, xf * dia)
	k.box(Vector3(0, -1.12, 0), Vector3(0.05, 0.26, 0.5), BANNER, 0.01, 0.2, xf)


func _ivy(k: MeshKit, pillar: Vector3, sx: float, sz: float, rng: RandomNumberGenerator) -> void:
	# Foglie d'edera sulla faccia esterna della colonna, piu' fitte in basso.
	for i in 22:
		var y := pillar.y + rng.randf_range(0.0, 3.6) * rng.randf()
		var along := rng.randf_range(-0.45, 0.45)
		var p := pillar + Vector3(sx * 0.53, y - pillar.y, along) if i % 2 == 0 else pillar + Vector3(along, y - pillar.y, sz * 0.53)
		var g := Color(0.20, 0.36, 0.13).lerp(Color(0.32, 0.48, 0.17), rng.randf())
		k.box(p, Vector3(0.16, 0.16, 0.16) * rng.randf_range(0.7, 1.2), g, 0.03)


func _lantern(k: MeshKit, glow: MeshKit, at: Vector3) -> void:
	k.prism(at, 0.0, 2.3, 0.07, 0.06, 6, WOOD_D)
	k.box(at + Vector3(0, 2.3, 0.18), Vector3(0.07, 0.07, 0.42), WOOD_D, 0.01)
	var lp := at + Vector3(0, 2.0, 0.36)
	k.box(lp + Vector3(0, 0.22, 0), Vector3(0.3, 0.06, 0.3), IRON, 0.01)
	k.box(lp + Vector3(0, -0.2, 0), Vector3(0.26, 0.05, 0.26), IRON, 0.01)
	for o in [Vector3(0.12, 0, 0.12), Vector3(-0.12, 0, 0.12), Vector3(0.12, 0, -0.12), Vector3(-0.12, 0, -0.12)]:
		k.box(lp + o, Vector3(0.03, 0.4, 0.03), IRON, 0.0)
	glow.box(lp, Vector3(0.2, 0.32, 0.2), Color(1.0, 0.78, 0.42), 0.02)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.7, 0.4)
	l.light_energy = 0.9
	l.omni_range = 4.5
	l.shadow_enabled = false
	add_child(l)
	l.position = lp
	_lights.append(l)


func _crates(k: MeshKit, at: Vector3, w: WorldData, ring_y: float, rng: RandomNumberGenerator) -> void:
	at.y = _ground(w, at, ring_y)
	for i in 3:
		var p := at + Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8))
		var s := rng.randf_range(0.55, 0.75)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * 0.6), p + Vector3(0, s * 0.5, 0))
		k.box(Vector3.ZERO, Vector3(s, s, s), WOOD, 0.03, 1.0, xf)
		for e in [-1.0, 1.0]:
			k.box(Vector3(0, 0, e * s * 0.49), Vector3(s * 0.96, s * 0.14, 0.03), WOOD_D, 0.005, 1.0, xf)
			k.box(Vector3(e * s * 0.49, 0, 0), Vector3(0.03, s * 0.96, s * 0.14), WOOD_D, 0.005, 1.0, xf)
	for i in 2:
		var p := at + Vector3(1.1 + i * 0.7, 0, rng.randf_range(-0.6, 0.6))
		k.prism(p, 0.0, 0.85, 0.30, 0.30, 10, WOOD)
		for y in [0.15, 0.7]:
			k.prism(p, y - 0.03, y + 0.03, 0.315, 0.315, 10, IRON)
		k.prism(p, 0.85, 0.87, 0.27, 0.27, 10, WOOD_D)


func _bush(k: MeshKit, at: Vector3, rng: RandomNumberGenerator) -> void:
	var n := rng.randi_range(4, 7)
	for i in n:
		var o := Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(0.1, 0.4), rng.randf_range(-0.35, 0.35))
		var g := Color(0.22, 0.38, 0.13).lerp(Color(0.34, 0.50, 0.18), rng.randf())
		k.box(at + o, Vector3(0.3, 0.3, 0.3) * rng.randf_range(0.8, 1.3), g, 0.04)
	var fl: Color = [Color(0.96, 0.95, 0.88), Color(0.98, 0.84, 0.32), Color(0.86, 0.52, 0.70)][rng.randi() % 3]
	for i in rng.randi_range(3, 6):
		var o := Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(0.35, 0.6), rng.randf_range(-0.4, 0.4))
		k.box(at + o, Vector3(0.08, 0.08, 0.08), fl, 0.0)


## Lanterne piu' forti di notte.
func set_daylight(day: float) -> void:
	for l in _lights:
		l.light_energy = lerpf(1.6, 0.5, day)
