class_name Grains
extends Node3D
## Pool unico di grani (GAS del prototipo, HTML ~8011 e 8080–8104): gocce,
## scintille, polvere. Moto balistico con gravita' e attrito, appoggio al suolo,
## gocce che spariscono entrando in acqua, temperatura che si raffredda con la
## vita. Due mesh ricostruite a ogni frame: additiva (mode 0) e opaca (mode 1).

const CAP := 3600
## Palette per elemento: ombra, corpo, caldo, nucleo, picco (EL_RGB, HTML 7996).
const EL_RGB := {
	"fire": [Vector3(.08, .035, .018), Vector3(.42, .10, .025), Vector3(.86, .30, .04), Vector3(1.0, .72, .28), Vector3(1, .96, .78)],
	"water": [Vector3(.025, .09, .14), Vector3(.05, .25, .38), Vector3(.12, .52, .68), Vector3(.55, .84, .90), Vector3(.94, .99, 1)],
	"air": [Vector3(.28, .34, .35), Vector3(.52, .62, .64), Vector3(.72, .82, .83), Vector3(.88, .94, .95), Vector3(.98, 1, 1)],
	"earth": [Vector3(.14, .09, .055), Vector3(.30, .22, .13), Vector3(.48, .36, .21), Vector3(.66, .52, .34), Vector3(.84, .74, .58)],
	"karma": [Vector3(.08, .04, .12), Vector3(.30, .14, .50), Vector3(.60, .38, .92), Vector3(.86, .74, 1.0), Vector3(1, .97, 1)],
	"smoke": [Vector3(.06, .06, .06), Vector3(.16, .15, .14), Vector3(.30, .29, .27), Vector3(.45, .44, .42), Vector3(.6, .6, .6)],
	"steam": [Vector3(.5, .55, .6), Vector3(.66, .72, .76), Vector3(.8, .85, .88), Vector3(.9, .93, .95), Vector3(1, 1, 1)],
}


class Grain:
	extends RefCounted
	var p := Vector3.ZERO
	var v := Vector3.ZERO
	var a := 0.0
	var life := 0.5
	var s := 0.03
	var t0 := 1.0
	var t := 1.0
	var el := "fire"
	var mode := 0
	var g := 0.0
	var drag := 0.0
	var length := 0.0
	var cool := 1.6
	var ground := false
	var stick := false
	var al := 1.0
	var water_drop := false


var world: WorldData
var list: Array[Grain] = []
var _mesh_add: MeshInstance3D
var _mesh_alpha: MeshInstance3D


func _ready() -> void:
	_mesh_add = _make_instance(preload("res://src/presentation/shaders/particle_add.gdshader"), 9, true)
	_mesh_alpha = _make_instance(preload("res://src/presentation/shaders/particle.gdshader"), 8, false)


func _make_instance(shader: Shader, priority: int, additive: bool) -> MeshInstance3D:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.render_priority = priority
	mat.set_shader_parameter(&"additive", 1.0 if additive else 0.0)
	var inst := MeshInstance3D.new()
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.extra_cull_margin = 16384.0
	add_child(inst)
	return inst


## grainNew: null se il pool e' pieno.
func add(g: Grain) -> Grain:
	if list.size() >= CAP:
		return null
	g.t = g.t0
	list.append(g)
	return g


func clear() -> void:
	list.clear()
	_build()


func _process(dt: float) -> void:
	step(dt)
	_build()


func step(dt: float) -> void:
	var i := list.size() - 1
	while i >= 0:
		var g := list[i]
		g.a += dt
		if g.a >= g.life:
			list.remove_at(i)
			i -= 1
			continue
		g.v.y -= g.g * dt
		if g.drag > 0.0:
			g.v *= exp(-g.drag * dt)
		g.p += g.v * dt
		if g.ground and g.v.y < 0.0 and world != null:
			var gy := float(FluidSystem.field_height(world, g.p.x, g.p.z))
			if g.p.y < gy + 0.02:
				g.p.y = gy + 0.02
				g.v.y = 0.0
				if g.stick:
					g.v.x = 0.0
					g.v.z = 0.0
				else:
					g.v.x *= 0.4
					g.v.z *= 0.4
		if g.water_drop and g.v.y < 0.0 and world != null:
			var w := FluidSystem.sample_water(world, g.p.x, g.p.y, g.p.z)
			if bool(w["wet"]) and g.p.y < float(w["level"]):
				list.remove_at(i)
				i -= 1
				continue
		var u := g.a / g.life
		g.t = g.t0 * (1.0 - pow(u, g.cool))
		i -= 1


## Fiamma (v78, RMNDWN L22504): colore di corpo nero per temperatura, a
## isoterme (6 passi) e luminosita' e = T^(lum·.55)·.55 + .45·T.
const BLACKBODY := [[0.0, Color("#0c0b09")], [0.12, Color("#1e0c04")], [0.26, Color("#451003")], [0.42, Color("#6d1d05")],
	[0.58, Color("#93300a")], [0.72, Color("#ad4a12")], [0.84, Color("#c06a1c")], [0.93, Color("#cf9038")], [1.0, Color("#dcb96e")]]
const FLAME_STEPS := 6.0
const FLAME_LUM := 5.5
## Karma (RMNDWN karmaRamp L18922): tinta viola 284, colore funzione della coerenza.
const KARMA_HUE := 284.0
const KARMA_WHITE := 0.40


static func blackbody(t: float) -> Vector3:
	var tb := roundf(clampf(t, 0.0, 1.0) * FLAME_STEPS) / FLAME_STEPS
	var c: Color = BLACKBODY[0][1]
	for i in range(1, BLACKBODY.size()):
		var a: Array = BLACKBODY[i - 1]
		var b: Array = BLACKBODY[i]
		if tb <= float(b[0]):
			c = (a[1] as Color).lerp(b[1], (tb - float(a[0])) / (float(b[0]) - float(a[0])))
			break
	var e := pow(tb, FLAME_LUM * 0.55) * 0.55 + 0.45 * tb
	# Il fattore 2,2 compensa la mescola MAX di RMNDWN, qui additiva e piu' rada.
	return Vector3(c.r, c.g, c.b) * e * 2.2


static func _hsl(h: float, s: float, l: float) -> Vector3:
	h = fposmod(h, 360.0) / 360.0
	var q := l * (1.0 + s) if l < 0.5 else l + s - l * s
	var p := 2.0 * l - q
	var f := func(t: float) -> float:
		t = fposmod(t, 1.0)
		if t < 1.0 / 6.0:
			return p + (q - p) * 6.0 * t
		if t < 0.5:
			return q
		if t < 2.0 / 3.0:
			return p + (q - p) * (2.0 / 3.0 - t) * 6.0
		return p
	return Vector3(f.call(h + 1.0 / 3.0), f.call(h), f.call(h - 1.0 / 3.0))


## Colore del Karma per coerenza C (24 bande): nucleo quasi bianco sopra .86.
static func karma_color(c: float, hue_shift: float = 0.0) -> Vector3:
	c = floorf(clampf(c, 0.0, 1.0) * 24.0) / 24.0
	var w := (0.88 if c > 0.86 else 0.18) * KARMA_WHITE
	var top := 0.56 + 0.44 * w
	var l := 0.045 + top * pow(c, 1.18)
	var sa := clampf(1.02 - w * 1.05 * pow(c, 3.0), 0.0, 1.0)
	return _hsl(KARMA_HUE + hue_shift + (c - 0.55) * -26.0 * (0.35 + 0.65 * w), sa, l)


## elColor: temperatura 0..1 quantizzata a 24 livelli sulla palette dell'elemento
## ("flame" = corpo nero, "karma" = rampa della coerenza).
static func el_color(el: String, u: float) -> Vector3:
	if el == "flame":
		return blackbody(u)
	if el == "karma":
		return karma_color(u)
	var r: Array = EL_RGB.get(el, EL_RGB["fire"])
	u = floorf(clampf(u, 0.0, 1.0) * 24.0) / 24.0
	var a: Vector3
	var b: Vector3
	var t: float
	if u > 0.90:
		a = r[3]; b = r[4]; t = (u - 0.9) / 0.1
	elif u > 0.55:
		a = r[2]; b = r[3]; t = (u - 0.55) / 0.35
	elif u > 0.2:
		a = r[1]; b = r[2]; t = (u - 0.2) / 0.35
	else:
		a = r[0]; b = r[1]; t = u / 0.2
	return a + (b - a) * t


func _build() -> void:
	if _mesh_add == null:
		return
	var corners := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
	for mode in 2:
		var pos := PackedVector3Array()
		var cols := PackedColorArray()
		var c0 := PackedFloat32Array()
		var c1 := PackedFloat32Array()
		var idx := PackedInt32Array()
		var n := 0
		for g in list:
			if (1 if g.mode != 0 else 0) != mode:
				continue
			var col := el_color(g.el, g.t)
			var al := g.al * clampf(g.t * 1.4, 0.0, 1.0) if mode == 0 else g.al * (1.0 if g.a / g.life < 0.7 else 1.0 - (g.a / g.life - 0.7) / 0.3)
			var dir := Vector3.ZERO
			var ln := g.s
			if g.length > 0.0:
				ln = g.length
				dir = g.v.normalized() if g.v.length() > 0.0 else Vector3.ZERO
			for k in 4:
				var cr: Vector2 = corners[k]
				pos.append(g.p)
				cols.append(Color(col.x, col.y, col.z, al))
				c0.append_array(PackedFloat32Array([cr.x, cr.y, g.s, ln]))
				c1.append_array(PackedFloat32Array([dir.x, dir.y, dir.z, 0.0]))
			var b := n * 4
			idx.append_array(PackedInt32Array([b, b + 2, b + 1, b, b + 3, b + 2]))
			n += 1
		var inst := _mesh_add if mode == 0 else _mesh_alpha
		if n == 0:
			inst.mesh = null
			continue
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = pos
		a[Mesh.ARRAY_COLOR] = cols
		a[Mesh.ARRAY_CUSTOM0] = c0
		a[Mesh.ARRAY_CUSTOM1] = c1
		a[Mesh.ARRAY_INDEX] = idx
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {},
			(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT))
		inst.mesh = mesh


func count() -> int:
	return list.size()
