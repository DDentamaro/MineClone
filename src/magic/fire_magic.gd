class_name FireMagic
extends Node3D
## Magia del fuoco del bastone (D-055), nello stile della tavola di riferimento:
## fiamme a cubetti (nucleo giallo, corpo arancio, lingue rosse), braci e
## scintille in pixel (i grani del fuoco), cerchio di rune arancio-oro davanti
## alla gemma.
## - Dardo ("bolt"): veloce, segue un poco il bersaglio agganciato, al contatto
##   brucia e lascia una piccola bruciatura.
## - Palla ("ball"): si forma sulla gemma mentre si carica il forte (piu' grande
##   col caricamento), lenta, esplode ad area al contatto, a terra o a fine
##   corsa: onda, braci, fumo, lampo di luce, bruciatura sui colpiti.
## La logica sta qui (niente nodi per la fisica); gli eventi vanno al gioco
## per scossa della camera e numeri del danno.

const BOLT_SPEED := 19.0
const BOLT_LIFE := 0.95
const BOLT_R := 0.2
const BOLT_TURN := 5.0
const BALL_SPEED := 11.0
const BALL_LIFE := 1.6
const BALL_R := 0.3
const BALL_TURN := 2.0
## Raggio dell'esplosione: base e in piu' a carica piena.
const BLAST := 1.9
const BLAST_CHARGE := 1.1
## Bruciatura: durata, intervallo e danno per colpo.
const BURN_TIME := 3.0
const BURN_TICK := 0.5
const BURN_DMG := 2.0

class Shot:
	extends RefCounted
	var kind := "bolt"
	var p := Vector3.ZERO
	var v := Vector3.ZERO
	var t := 0.0
	var life := 1.0
	var r := 0.2
	var damage := 10.0
	var knock := 2.0
	var launch := 0.0
	var shake := 0.1
	var charge := 0.0
	var target: CombatTarget
	var node: Node3D
	var light: OmniLight3D
	var dead := false


class Flash:
	extends RefCounted
	var node: Node3D
	var t := 0.0
	var life := 0.3
	var kind := "circle"
	var grow := 1.0
	var light: OmniLight3D


var world: WorldData
var grains: Grains
var shots: Array[Shot] = []
var burns := {}
var _flashes: Array[Flash] = []
var _fire_mesh: ArrayMesh
var _circle_mesh: ArrayMesh
var _shell_mesh: ArrayMesh
var _solid_mat: StandardMaterial3D
var _add_mat: StandardMaterial3D
## Palla in formazione sulla gemma durante la carica del forte.
var _charge_node: Node3D
var _charge_circle: Node3D
var events: Array[Dictionary] = []


func _init() -> void:
	_solid_mat = StandardMaterial3D.new()
	_solid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_solid_mat.vertex_color_use_as_albedo = true
	_add_mat = StandardMaterial3D.new()
	_add_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_add_mat.vertex_color_use_as_albedo = true
	_add_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_add_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_add_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add_mat.no_depth_test = false
	_add_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_fire_mesh = build_fire_mesh()
	_circle_mesh = build_circle_mesh()
	_shell_mesh = build_shell_mesh()


## Fiamma a cubetti lungo +Z (la coda): nucleo giallo, corpo arancio, lingue
## rosse che si allungano dietro, qualche cubetto di brace staccato.
static func build_fire_mesh() -> ArrayMesh:
	var k := MeshKit.new()
	var yellow := Color(1.0, 0.95, 0.55)
	var orange := Color(1.0, 0.55, 0.12)
	var red := Color(0.9, 0.16, 0.06)
	k.box(Vector3.ZERO, Vector3(0.2, 0.2, 0.2), yellow, 0.0)
	for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, -1)]:
		k.box(d * 0.12, Vector3(0.13, 0.13, 0.13), orange, 0.0)
	for i in 7:
		var a := TAU * i / 7.0
		var off := Vector3(cos(a) * 0.12, sin(a) * 0.12, 0.16 + 0.05 * (i % 3))
		k.box(off, Vector3(0.11, 0.11, 0.14), red, 0.0)
	for i in 5:
		var a := TAU * i / 5.0 + 0.4
		var off := Vector3(cos(a) * 0.08, sin(a) * 0.08, 0.34 + 0.06 * (i % 2))
		k.box(off, Vector3(0.08, 0.08, 0.12), red.darkened(0.15), 0.0)
	for off in [Vector3(0.05, 0.02, 0.52), Vector3(-0.06, -0.04, 0.6), Vector3(0.0, 0.07, 0.68)]:
		k.box(off, Vector3(0.05, 0.05, 0.05), orange, 0.0)
	return k.commit()


## Cerchio di rune nel piano XY (si guarda lungo Z): anello esterno a cubetti,
## anello interno sottile, sei rune a losanga fra i due.
static func build_circle_mesh() -> ArrayMesh:
	var k := MeshKit.new()
	var gold := Color(1.0, 0.68, 0.22)
	var hot := Color(1.0, 0.86, 0.5)
	for i in 32:
		var a := TAU * i / 32.0
		var p := Vector3(cos(a) * 0.42, sin(a) * 0.42, 0)
		k.box(p, Vector3(0.07, 0.025, 0.01), gold, 0.0, 1.0, MeshKit.rot_about(Vector3(0, 0, 1), a + PI * 0.5, p))
	for i in 24:
		var a := TAU * i / 24.0
		var p := Vector3(cos(a) * 0.27, sin(a) * 0.27, 0)
		k.box(p, Vector3(0.06, 0.015, 0.01), gold, 0.0, 1.0, MeshKit.rot_about(Vector3(0, 0, 1), a + PI * 0.5, p))
	for i in 6:
		var a := TAU * i / 6.0
		var p := Vector3(cos(a) * 0.345, sin(a) * 0.345, 0)
		k.box(p, Vector3(0.05, 0.05, 0.01), hot, 0.0, 1.0, MeshKit.rot_about(Vector3(0, 0, 1), PI * 0.25, p))
	return k.commit()


## Guscio dell'esplosione: sfera a cubetti (anelli di cubi), si espande e svanisce.
static func build_shell_mesh() -> ArrayMesh:
	var k := MeshKit.new()
	for j in 5:
		var lat := (float(j) / 4.0 - 0.5) * PI * 0.8
		var n := maxi(6, roundi(16 * cos(lat)))
		for i in n:
			var a := TAU * i / n
			var p := Vector3(cos(a) * cos(lat), sin(lat), sin(a) * cos(lat))
			var c: Color = [Color(1.0, 0.78, 0.3), Color(1.0, 0.45, 0.1), Color(0.88, 0.18, 0.06)][(i + j) % 3]
			k.box(p, Vector3(0.14, 0.14, 0.14), c, 0.0)
	return k.commit()


func clear() -> void:
	for s in shots:
		_free(s)
	shots.clear()
	for f in _flashes:
		if is_instance_valid(f.node):
			f.node.queue_free()
		if f.light != null and is_instance_valid(f.light):
			f.light.queue_free()
	_flashes.clear()
	burns.clear()
	charging(false, Vector3.ZERO, Vector3.FORWARD, 0.0)


## Lancio dalla gemma `origin` verso `dir` (o verso il bersaglio agganciato).
func cast(a: AttackDefinition, origin: Vector3, dir: Vector3, charge: float, target: CombatTarget, damage_mult: float = 1.0) -> Shot:
	var s := Shot.new()
	s.kind = a.cast
	s.p = origin
	s.charge = charge
	s.target = target if target != null and target.alive else null
	var aim := dir.normalized()
	if s.target != null:
		aim = (_chest(s.target) - origin).normalized()
	s.damage = a.damage * damage_mult * (1.0 + charge * a.charge_bonus)
	s.knock = a.knockback * (1.0 + charge * 0.5)
	s.launch = a.launch
	s.shake = a.shake * (1.0 + charge * 0.6)
	if s.kind == "ball":
		s.v = aim * (BALL_SPEED + charge * 3.0)
		s.life = BALL_LIFE
		s.r = BALL_R + charge * 0.15
	else:
		s.v = aim * BOLT_SPEED
		s.life = BOLT_LIFE
		s.r = BOLT_R
	s.node = MeshInstance3D.new()
	(s.node as MeshInstance3D).mesh = _fire_mesh
	(s.node as MeshInstance3D).material_override = _solid_mat
	(s.node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(s.node)
	var sc := (1.6 + charge * 1.2) if s.kind == "ball" else 1.0
	s.node.scale = Vector3.ONE * sc
	s.light = OmniLight3D.new()
	s.light.light_color = Color(1.0, 0.55, 0.2)
	s.light.light_energy = 1.4 if s.kind == "ball" else 0.8
	s.light.omni_range = 3.5 if s.kind == "ball" else 2.2
	s.light.shadow_enabled = false
	add_child(s.light)
	_place(s)
	shots.append(s)
	# Cerchio di rune davanti alla gemma e scintille del lancio.
	_flash("circle", origin + aim * 0.15, aim, 0.32 if s.kind == "bolt" else 0.5, 0.9 if s.kind == "bolt" else 1.4 + charge * 0.6)
	for i in (10 if s.kind == "bolt" else 26):
		_grain(origin, aim * randf_range(2.0, 5.0) + _rand_dir() * 1.6, "fire", randf_range(0.18, 0.4), randf_range(0.03, 0.06))
	return s


## Palla in formazione sulla gemma durante la carica (e cerchio che cresce).
func charging(on: bool, gem: Vector3, dir: Vector3, cf: float) -> void:
	if not on:
		if _charge_node != null:
			_charge_node.queue_free()
			_charge_circle.queue_free()
			_charge_node = null
			_charge_circle = null
		return
	if _charge_node == null:
		var mi := MeshInstance3D.new()
		mi.mesh = _fire_mesh
		mi.material_override = _solid_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_charge_node = mi
		var ci := MeshInstance3D.new()
		ci.mesh = _circle_mesh
		ci.material_override = _add_mat
		ci.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ci)
		_charge_circle = ci
	var t := Time.get_ticks_msec() / 1000.0
	_charge_node.global_position = gem
	_charge_node.rotation = Vector3(t * 3.0, t * 4.0, 0)
	_charge_node.scale = Vector3.ONE * (0.35 + 1.1 * cf) * (1.0 + 0.08 * sin(t * 18.0))
	_orient(_charge_circle, gem + dir * 0.2, dir)
	_charge_circle.rotate_object_local(Vector3(0, 0, 1), t * 2.5)
	_charge_circle.scale = Vector3.ONE * (0.8 + 0.9 * cf)
	if randf() < 0.6:
		# Braci risucchiate verso la gemma.
		var from := gem + _rand_dir() * (0.5 + 0.3 * cf)
		_grain(from, (gem - from) * 3.0, "fire", 0.25, 0.035)


func step(dt: float, targets: Array) -> void:
	for s in shots:
		if s.dead:
			continue
		s.t += dt
		# Un poco di guida verso il bersaglio agganciato.
		if s.target != null and s.target.alive:
			var want := (_chest(s.target) - s.p).normalized()
			var turn := (BOLT_TURN if s.kind == "bolt" else BALL_TURN) * dt
			s.v = s.v.normalized().slerp(want, clampf(turn, 0.0, 1.0)) * s.v.length()
		var prev := s.p
		s.p += s.v * dt
		_place(s)
		_trail(s, prev, dt)
		var hit: CombatTarget = null
		for o in targets:
			var tg := o as CombatTarget
			if tg != null and tg.alive and CombatController.sphere_capsule(s.p, s.r, tg):
				hit = tg
				break
		if hit != null:
			_hit_shot(s, hit, targets)
		elif _solid(s.p) or s.t >= s.life:
			if s.kind == "ball":
				_explode(s, targets)
			else:
				_fizzle(s)
	for i in range(shots.size() - 1, -1, -1):
		if shots[i].dead:
			_free(shots[i])
			shots.remove_at(i)
	_step_burns(dt)
	_step_flashes(dt)


func _hit_shot(s: Shot, tg: CombatTarget, targets: Array) -> void:
	if s.kind == "ball":
		_explode(s, targets)
		return
	var dir := Vector3(s.v.x, 0, s.v.z).normalized()
	tg.take_hit(dir * s.knock + Vector3(0, s.launch, 0), s.damage)
	_burn(tg)
	events.append({"type": "spell_hit", "p": s.p, "damage": s.damage, "shake": s.shake, "target": tg})
	for i in 18:
		_grain(s.p, -s.v.normalized() * randf_range(1.0, 3.0) + _rand_dir() * 2.5, "fire", randf_range(0.2, 0.45), randf_range(0.03, 0.06))
	_flash("pop", s.p, s.v.normalized(), 0.18, 0.5)
	s.dead = true


func _explode(s: Shot, targets: Array) -> void:
	var radius := BLAST + BLAST_CHARGE * s.charge
	var total := 0.0
	for o in targets:
		var tg := o as CombatTarget
		if tg == null or not tg.alive:
			continue
		var c := _chest(tg)
		var d := c.distance_to(s.p) - tg.radius
		if d > radius:
			continue
		var k := clampf(1.0 - maxf(d, 0.0) / radius * 0.5, 0.5, 1.0)
		var dir := Vector3(c.x - s.p.x, 0, c.z - s.p.z)
		dir = dir.normalized() if dir.length() > 0.05 else Vector3(s.v.x, 0, s.v.z).normalized()
		tg.take_hit(dir * s.knock * k + Vector3(0, s.launch * k, 0), s.damage * k)
		_burn(tg)
		total += s.damage * k
		events.append({"type": "spell_hit", "p": c, "damage": s.damage * k, "shake": 0.0, "target": tg})
	events.append({"type": "blast", "p": s.p, "shake": s.shake, "radius": radius})
	# Onda di cubi, braci in tutte le direzioni, fumo, lampo.
	_flash("shell", s.p, Vector3.UP, 0.36, radius)
	_flash("pop", s.p, Vector3.UP, 0.3, 1.2 + s.charge)
	for i in int(60 + 40 * s.charge):
		var d := _rand_dir()
		d.y = absf(d.y) * 0.8 + 0.2
		_grain(s.p, d * randf_range(3.0, 7.0) * (0.8 + 0.4 * s.charge), "fire", randf_range(0.35, 0.8), randf_range(0.04, 0.09), 6.0)
	for i in 18:
		_grain(s.p + _rand_dir() * 0.4, Vector3(randf_range(-0.6, 0.6), randf_range(1.0, 2.2), randf_range(-0.6, 0.6)), "smoke", randf_range(0.9, 1.5), randf_range(0.08, 0.14), -0.6, 1)
	s.dead = true


func _fizzle(s: Shot) -> void:
	for i in 10:
		_grain(s.p, _rand_dir() * 1.5, "fire", randf_range(0.15, 0.3), 0.04)
	s.dead = true


## Bruciatura: chi e' preso dal fuoco perde punti per qualche secondo.
func _burn(tg: CombatTarget) -> void:
	burns[tg] = {"t": BURN_TIME, "tick": BURN_TICK}


func _step_burns(dt: float) -> void:
	for tg: CombatTarget in burns.keys():
		var b: Dictionary = burns[tg]
		if not tg.alive:
			burns.erase(tg)
			continue
		b["t"] = float(b["t"]) - dt
		b["tick"] = float(b["tick"]) - dt
		if randf() < 0.5:
			# Fiammelle che salgono dal bersaglio.
			var p := tg.position + Vector3(randf_range(-tg.radius, tg.radius), randf_range(0.2, tg.height * 0.9), randf_range(-tg.radius, tg.radius))
			_grain(p, Vector3(0, randf_range(1.0, 2.0), 0), "fire", randf_range(0.25, 0.45), randf_range(0.03, 0.05), -1.5)
		if float(b["tick"]) <= 0.0:
			b["tick"] = BURN_TICK
			tg.take_hit(Vector3.ZERO, BURN_DMG)
			events.append({"type": "burn", "p": _chest(tg), "damage": BURN_DMG, "target": tg})
		if float(b["t"]) <= 0.0:
			burns.erase(tg)


func _trail(s: Shot, prev: Vector3, dt: float) -> void:
	var n := 3 if s.kind == "bolt" else 6
	for i in n:
		var p := prev.lerp(s.p, randf())
		_grain(p, -s.v * 0.08 + _rand_dir() * 0.8 + Vector3(0, 0.6, 0), "fire", randf_range(0.15, 0.35), randf_range(0.03, 0.055) * (1.4 if s.kind == "ball" else 1.0), -1.0)
	if s.kind == "ball" and randf() < 0.5:
		_grain(s.p, Vector3(0, 0.8, 0) + _rand_dir() * 0.3, "smoke", 0.8, 0.07, -0.5, 1)


func _place(s: Shot) -> void:
	if s.node == null:
		return
	_orient(s.node, s.p, -s.v.normalized())
	s.node.rotate_object_local(Vector3(0, 0, 1), s.t * 9.0)
	if s.light != null:
		s.light.global_position = s.p


## Orienta `n` in `p` con l'asse +Z verso `back` (la coda della fiamma).
static func _orient(n: Node3D, p: Vector3, back: Vector3) -> void:
	var up := Vector3.UP if absf(back.normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	n.global_transform = Transform3D(Basis.looking_at(-back, up), p)


func _flash(kind: String, p: Vector3, dir: Vector3, life: float, grow: float) -> void:
	var f := Flash.new()
	f.kind = kind
	f.life = life
	f.grow = grow
	var mi := MeshInstance3D.new()
	mi.mesh = _circle_mesh if kind == "circle" else (_shell_mesh if kind == "shell" else _fire_mesh)
	# Il guscio e' pieno: in additivo sul marmo bianco diventava bianco.
	mi.material_override = _solid_mat if kind == "shell" else _add_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_orient(mi, p, -dir)
	f.node = mi
	if kind == "shell":
		f.light = OmniLight3D.new()
		f.light.light_color = Color(1.0, 0.6, 0.25)
		f.light.light_energy = 1.8
		f.light.omni_range = grow * 2.5
		add_child(f.light)
		f.light.global_position = p + Vector3(0, 0.3, 0)
	_flashes.append(f)
	_step_flash(f)


func _step_flashes(dt: float) -> void:
	for i in range(_flashes.size() - 1, -1, -1):
		var f := _flashes[i]
		f.t += dt
		if f.t >= f.life:
			f.node.queue_free()
			if f.light != null:
				f.light.queue_free()
			_flashes.remove_at(i)
			continue
		_step_flash(f)


func _step_flash(f: Flash) -> void:
	var u := clampf(f.t / f.life, 0.0, 1.0)
	match f.kind:
		"circle":
			f.node.scale = Vector3.ONE * f.grow * (0.6 + 0.4 * minf(u * 3.0, 1.0)) * (1.0 - 0.3 * u)
			f.node.rotate_object_local(Vector3(0, 0, 1), 0.12)
		"shell":
			f.node.scale = Vector3.ONE * f.grow * (0.25 + 0.75 * sqrt(u))
			if f.light != null:
				f.light.light_energy = 1.8 * (1.0 - u)
		_:
			f.node.scale = Vector3.ONE * f.grow * (1.0 + 2.0 * u)
	# Svanire: i colori additivi si spengono scalando verso il centro alla fine.
	if u > 0.7:
		f.node.scale *= 1.0 - (u - 0.7) / 0.3 * 0.9


func _grain(p: Vector3, v: Vector3, el: String, life: float, size: float, grav: float = 2.0, mode: int = 0) -> void:
	if grains == null:
		return
	var g := Grains.Grain.new()
	g.p = p
	g.v = v
	g.el = el
	g.mode = mode
	g.life = life
	g.s = size
	g.g = grav
	g.drag = 1.5
	g.t0 = 1.0
	g.ground = true
	grains.add(g)


func _solid(p: Vector3) -> bool:
	return world != null and world.is_solid_at(floori(p.x), floori(p.y), floori(p.z))


func _free(s: Shot) -> void:
	if s.node != null and is_instance_valid(s.node):
		s.node.queue_free()
	if s.light != null and is_instance_valid(s.light):
		s.light.queue_free()


static func _chest(tg: CombatTarget) -> Vector3:
	return tg.position + Vector3(0, tg.height * 0.55, 0)


static func _rand_dir() -> Vector3:
	var v := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
	return v.normalized() if v.length() > 0.01 else Vector3.UP
