class_name WorldGenerator
extends RefCounted
## Generatore a passate del prototipo v0_64 (core.js r.53-124 e shapeRiverBanks r.536),
## porting con parita' bit a bit: stessa sequenza di numeri casuali, stessi arrotondamenti
## (Float32Array -> PackedFloat32Array, Int16Array -> PackedInt32Array con valori piccoli),
## Math.* di V8 tramite JsMath.
##
## Ogni passata ha il suo seme derivato: mulberry32(subSeed(seed, nome)).
## Uso: WorldGenerator.generate(world, seed, {"caves": false}).
## run_passes() si ferma prima di shapeRiverBanks/initFluid (fixture intermedia).
## gen_log: [[nome, ms], ...]; l'ultima voce e' ["stepFluid", ms, tick eseguiti].

const VERSION := "v0_64"
const PASS_NAMES: Array[String] = ["Campi", "Quote", "Laghi", "Fiumi", "Terrazze", "Argini",
	"Biomi", "Strati", "Grotte", "Minerali", "Rifinitura"]
## Tick di assestamento dei fluidi a fine generazione, con budget per tick.
const SETTLE_TICKS := 160
const SETTLE_BUDGET := 200000

const _CONT: Array[float] = [0.0, -2.0, 0.30, 0.0, 0.45, 1.0, 0.52, 2.0, 0.60, 7.0, 0.80, 9.0, 1.0, 11.0]
const _EROS: Array[float] = [0.0, 1.0, 0.35, 0.8, 0.6, 0.35, 0.8, 0.14, 1.0, 0.10]

const AIR := 0
const GRASS := 1
const STONE := 3
const SAND := 4
const COPPER := 5
const IRON := 6
const GOLD := 7
const BEDROCK := 8
const LAVA := 9
const DARKSTONE := 14
const WATER := 15


## Contesto condiviso fra le passate (l'oggetto `c` del prototipo).
class GenContext:
	extends RefCounted
	var world: WorldData
	var seed_value: int = 0
	var caves: bool = true
	var sx: int = 0
	var sy: int = 0
	var sz: int = 0
	var sea: int = 0
	## Quota per colonna (Int16Array HH).
	var hh := PackedInt32Array()
	var f_cont := PackedFloat32Array()
	var f_eros := PackedFloat32Array()
	var f_ridge := PackedFloat32Array()
	var f_temp := PackedFloat32Array()
	var f_hum := PackedFloat32Array()
	var has_massif := false
	var massif_x := 0.0
	var massif_z := 0.0
	## Livello dell'acqua per colonna (Int16Array WL), -1 = asciutto; vuoto prima dei Laghi.
	var wl := PackedInt32Array()
	## {"x", "z", "r", "level", "cells"}
	var lakes: Array[Dictionary] = []
	## {"len", "falls"}
	var rivers: Array[Dictionary] = []
	## [[nome, ms], ...]
	var pass_log: Array = []


## generate(world, seed, opts): passate, sponde dei fiumi, fluidi assestati, statistiche.
static func generate(world: WorldData, seed_value: int, opts: Dictionary = {}) -> WorldData:
	var c := run_passes(world, seed_value, opts)
	var on_stage: Callable = opts.get("on_stage", Callable())
	finish(world, c, on_stage)
	return world


## Esegue solo GEN_PASSES (stato "pre-fluidi"). Opzioni: "caves" (false = niente grotte),
## "after_pass" (Callable(nome: String, c: GenContext), per i test di parita').
static func run_passes(world: WorldData, seed_value: int, opts: Dictionary = {}) -> GenContext:
	var hook: Callable = opts.get("after_pass", Callable())
	var sx := world.size_x
	var sy := world.size_y
	var sz := world.size_z
	var n := sx * sz
	world.blocks.fill(0)
	world.world_seed = seed_value
	world.generator_version = VERSION
	world.biome = _bytes(n)
	world.climate = _bytes(n * 4)
	world.water_level = _bytes(n)
	var flow := PackedFloat32Array()
	flow.resize(n * 2)
	world.water_flow = flow
	world.river_mask = _bytes(n)
	world.waterfall_mask = _bytes(n)
	world.waterfall_base = _bytes(n)
	world.waterfall_top = _bytes(n)
	world.water_guide = _bytes(n * 2)
	# Mondo "nuovo" come in JS (new World): niente stato dei fluidi precedente.
	world.water_bodies = PackedInt32Array()
	world.fluid_active = false
	world.fluid_queue = {}
	world.fluid_dirty = {}
	var c := GenContext.new()
	c.world = world
	c.seed_value = seed_value
	c.caves = not (opts.has("caves") and opts["caves"] == false)
	c.sx = sx
	c.sy = sy
	c.sz = sz
	c.sea = JsMath.js_round_i(sy * 0.55)
	c.hh.resize(n)
	c.f_cont.resize(n)
	c.f_eros.resize(n)
	c.f_ridge.resize(n)
	c.f_temp.resize(n)
	c.f_hum.resize(n)
	for pass_name in PASS_NAMES:
		var t0 := Time.get_ticks_usec()
		var r := Mulberry32.new(IsoNoise.sub_seed(seed_value, pass_name))
		match pass_name:
			"Campi":
				_pass_campi(c)
			"Quote":
				_pass_quote(c)
			"Laghi":
				_pass_laghi(c, r)
			"Fiumi":
				_pass_fiumi(c, r)
			"Terrazze":
				_pass_terrazze(c)
			"Argini":
				_pass_argini(c)
			"Biomi":
				_pass_biomi(c)
			"Strati":
				_pass_strati(c)
			"Grotte":
				_pass_grotte(c)
			"Minerali":
				_pass_minerali(c)
			"Rifinitura":
				_pass_rifinitura(c)
		c.pass_log.append([pass_name, (Time.get_ticks_usec() - t0) / 1000.0])
		if hook.is_valid():
			hook.call(pass_name, c)
	return c


## Dopo le passate: shapeRiverBanks, initFluid, fino a 160 tick di stepFluid, statistiche.
## `on_stage` (facoltativo) riceve (nome, world) a "pre_fluid", "banks", "init_fluid".
static func finish(world: WorldData, c: GenContext, on_stage: Callable = Callable()) -> void:
	if on_stage.is_valid():
		on_stage.call("pre_fluid", world)
	var t0 := Time.get_ticks_usec()
	shape_river_banks(world)
	if on_stage.is_valid():
		on_stage.call("banks", world)
	c.pass_log.append(["shapeRiverBanks", (Time.get_ticks_usec() - t0) / 1000.0])
	t0 = Time.get_ticks_usec()
	FluidSystem.init_fluid(world)
	c.pass_log.append(["initFluid", (Time.get_ticks_usec() - t0) / 1000.0])
	if on_stage.is_valid():
		on_stage.call("init_fluid", world)
	t0 = Time.get_ticks_usec()
	var ticks := 0
	while ticks < SETTLE_TICKS and not world.fluid_queue.is_empty():
		FluidSystem.step_fluid(world, SETTLE_BUDGET)
		ticks += 1
	c.pass_log.append(["stepFluid", (Time.get_ticks_usec() - t0) / 1000.0, ticks])
	var n := world.size_x * world.size_z
	var cnt := PackedInt32Array()
	cnt.resize(Biomes.count())
	for i in n:
		cnt[world.biome[i]] += 1
	var share := PackedInt32Array()
	for v in cnt:
		share.append(JsMath.js_round_i(float(v) / n * 100.0))
	world.gen_log = c.pass_log
	world.biome_share = share
	world.massif = {"x": c.massif_x, "z": c.massif_z} if c.has_massif else {}
	var cells := 0
	for v in world.water_level:
		if v != 0:
			cells += 1
	world.water_info = {"lakes": c.lakes.size(), "rivers": c.rivers.duplicate(true), "cells": cells}


static func _bytes(n: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(n)
	return b


static func _clamp01(v: float) -> float:
	if v < 0.0:
		return 0.0
	if v > 1.0:
		return 1.0
	return v


## sm(a, b, t) del prototipo: smoothstep con clamp.
static func _sm(a: float, b: float, t: float) -> float:
	t = _clamp01((t - a) / (b - a))
	return t * t * (3.0 - 2.0 * t)


# ------------------------------------------------------------------ passate

## Campi: continentalita', erosione, creste, temperatura, umidita' + regole di geografia
## (gradiente climatico, prato attorno allo spawn, massiccio a ~62 blocchi).
## Nota: usa un suo generatore mulberry32(subSeed(seed, "geografia")), non quello della passata.
static func _pass_campi(c: GenContext) -> void:
	var r := Mulberry32.new(IsoNoise.sub_seed(c.seed_value, "geografia"))
	var sx := c.sx
	var sz := c.sz
	var seed_value := c.seed_value
	var ga := r.next() * JsMath.JS_PI * 2.0
	var gx := JsMath.js_cos(ga)
	var gz := JsMath.js_sin(ga)
	var ma := r.next() * JsMath.JS_PI * 2.0
	var hx := sx / 2.0
	var hz := sz / 2.0
	var mx := hx + JsMath.js_cos(ma) * 62.0
	var mz := hz + JsMath.js_sin(ma) * 62.0
	c.has_massif = true
	c.massif_x = mx
	c.massif_z = mz
	var fsx := float(sx)
	var fsz := float(sz)
	var lx := float(sx - 1)
	var lz := float(sz - 1)
	var n_cont := Fbm2Lattice.new(seed_value, 3, 0.0, lx / 64.0, 0.0, lz / 64.0)
	var n_eros := Fbm2Lattice.new(seed_value + 9, 2, 13.0, lx / 52.0 + 13.0, -7.0, lz / 52.0 - 7.0)
	var n_temp := Fbm2Lattice.new(seed_value + 31, 2, 3.0, lx / 90.0 + 3.0, -7.0, lz / 90.0 - 7.0)
	var n_hum := Fbm2Lattice.new(seed_value + 47, 2, -11.0, lx / 80.0 - 11.0, 5.0, lz / 80.0 + 5.0)
	var n_ridge := Fbm2Lattice.new(seed_value + 17, 3, 0.0, lx / 38.0, 0.0, lz / 38.0)
	var f_cont := n_cont.field(Fbm2Lattice.axis(sx, 64.0, 0.0), Fbm2Lattice.axis(sz, 64.0, 0.0))
	var f_eros := n_eros.field(Fbm2Lattice.axis(sx, 52.0, 13.0), Fbm2Lattice.axis(sz, 52.0, -7.0))
	var f_temp := n_temp.field(Fbm2Lattice.axis(sx, 90.0, 3.0), Fbm2Lattice.axis(sz, 90.0, -7.0))
	var f_hum := n_hum.field(Fbm2Lattice.axis(sx, 80.0, -11.0), Fbm2Lattice.axis(sz, 80.0, 5.0))
	var f_ridge := n_ridge.field(Fbm2Lattice.axis(sx, 38.0, 0.0), Fbm2Lattice.axis(sz, 38.0, 0.0))
	for z in sz:
		var fz := float(z)
		for x in sx:
			var fx := float(x)
			var i := z * sx + x
			var u := (fx - hx) / fsx
			var v := (fz - hz) / fsz
			var cont := _clamp01((f_cont[i] - 0.5) * 1.9 + 0.5)
			var eros := _clamp01((f_eros[i] - 0.5) * 1.9 + 0.5)
			var temp := _clamp01((f_temp[i] - 0.5) * 1.9 + 0.5) + (u * gx + v * gz) * 0.75
			var hum := _clamp01((f_hum[i] - 0.5) * 1.9 + 0.5) + (-u * gz + v * gx) * 0.6
			var rd := 1.0 - absf(2.0 * f_ridge[i] - 1.0)
			var ks := 1.0 - _sm(14.0, 40.0, JsMath.js_hypot(fx - hx, fz - hz))
			cont = cont + (0.46 - cont) * ks
			eros = eros + (0.82 - eros) * ks
			temp = temp + (0.5 - temp) * ks
			hum = hum + (0.52 - hum) * ks
			var km := JsMath.js_exp(-((fx - mx) * (fx - mx) + (fz - mz) * (fz - mz)) / (26.0 * 26.0))
			cont = cont + (0.97 - cont) * km
			eros = eros + (0.04 - eros) * km
			c.f_cont[i] = cont
			c.f_eros[i] = eros
			c.f_ridge[i] = rd
			c.f_temp[i] = _clamp01(temp)
			c.f_hum[i] = _clamp01(hum)


## Quote: altezza da spline di continentalita'/erosione + dettaglio + picchi sulle creste.
static func _pass_quote(c: GenContext) -> void:
	var sx := c.sx
	var sz := c.sz
	var sy := c.sy
	var cont_pts := PackedFloat64Array(_CONT)
	var eros_pts := PackedFloat64Array(_EROS)
	var hh := c.hh
	var n_detail := Fbm2Lattice.new(c.seed_value + 9, 3, 0.0, (sx - 1) / 14.0, 0.0, (sz - 1) / 14.0)
	var f_detail := n_detail.field(Fbm2Lattice.axis(sx, 14.0, 0.0), Fbm2Lattice.axis(sz, 14.0, 0.0))
	for z in sz:
		for x in sx:
			var i := z * sx + x
			var e := c.f_eros[i]
			var amp := Biomes.spline(eros_pts, e)
			var detail := (f_detail[i] - 0.5) * 10.0 * amp
			var rg := c.f_ridge[i]
			var peaks := rg * rg * 14.0 * _sm(0.55, 0.85, c.f_cont[i]) * (1.0 - e)
			var h := JsMath.js_round_i(c.sea + Biomes.spline(cont_pts, c.f_cont[i]) + detail + peaks)
			hh[i] = maxi(6, mini(sy - 5, h))


## Laghi: un lago vicino allo spawn + fino a 8 siti; conca scavata con sponda.
static func _pass_laghi(c: GenContext, r: Mulberry32) -> void:
	var sx := c.sx
	var sz := c.sz
	var hh := c.hh
	var wl := PackedInt32Array()
	wl.resize(sx * sz)
	wl.fill(-1)
	c.wl = wl
	c.lakes = []
	var hx := sx / 2.0
	var hz := sz / 2.0
	var sites: Array[PackedFloat64Array] = []
	var a0 := r.next() * JsMath.JS_PI * 2.0
	var s0x := hx + JsMath.js_cos(a0) * 23.0
	var s0z := hz + JsMath.js_sin(a0) * 23.0
	sites.append(PackedFloat64Array([s0x, s0z, 7.0 + r.next() * 2.0]))
	var t := 0
	while t < 260 and sites.size() < 9:
		t += 1
		var x := 14.0 + r.next() * (sx - 28)
		var z := 14.0 + r.next() * (sz - 28)
		if JsMath.js_hypot(x - hx, z - hz) < 34.0:
			continue
		var near := false
		for s in sites:
			if JsMath.js_hypot(s[0] - x, s[1] - z) < 40.0:
				near = true
				break
		if near:
			continue
		var i := int(z) * sx + int(x)
		if c.f_eros[i] < 0.30 or hh[i] > c.sea + 9:
			continue
		sites.append(PackedFloat64Array([x, z, 6.0 + r.next() * 5.0]))
	for s in sites:
		var cx := s[0]
		var cz := s[1]
		var rad := s[2]
		var ci := int(cz) * sx + int(cx)
		var lv := hh[ci] - 1
		var p1 := r.next() * 6.28
		var p2 := r.next() * 6.28
		var n := 0
		var zlim := minf(float(sz - 2), cz + rad * 1.6)
		var xlim := minf(float(sx - 2), cx + rad * 1.6)
		var z := maxi(2, JsMath.f_to_i32(cz - rad * 1.6))
		while z < zlim:
			var x := maxi(2, JsMath.f_to_i32(cx - rad * 1.6))
			while x < xlim:
				var dx := x + 0.5 - cx
				var dz := z + 0.5 - cz
				var th := JsMath.js_atan2(dz, dx)
				var q := JsMath.js_hypot(dx, dz) / (rad * (1.0 + 0.25 * JsMath.js_sin(3.0 * th + p1) + 0.15 * JsMath.js_sin(5.0 * th + p2)))
				var i := z * sx + x
				if q < 1.0:
					var dep := 1 + JsMath.js_round_i(2.2 * (1.0 - q * q))
					hh[i] = mini(hh[i], lv - dep)
					wl[i] = lv
					n += 1
				elif q < 1.35 and hh[i] < lv + 1:
					hh[i] = lv + 1
				x += 1
			z += 1
		c.lakes.append({"x": cx, "z": cz, "r": rad, "level": lv, "cells": n})


## Fiumi: due fiumi dal massiccio verso il bordo, livelli che scendono a gradini (cascate).
static func _pass_fiumi(c: GenContext, r: Mulberry32) -> void:
	var sx := c.sx
	var sz := c.sz
	var hh := c.hh
	var wl := c.wl
	var w := c.world
	c.rivers = []
	if not c.has_massif:
		return
	var h0 := hh.duplicate()
	var hx := sx / 2.0
	var hz := sz / 2.0
	var mx := c.massif_x
	var mz := c.massif_z
	var river_mask := w.river_mask
	var water_flow := w.water_flow
	var water_guide := w.water_guide
	var wf_mask := w.waterfall_mask
	var wf_top := w.waterfall_top
	var wf_base := w.waterfall_base
	for k in 2:
		var a := r.next() * JsMath.JS_PI * 2.0
		var px := mx + JsMath.js_cos(a) * 9.0
		var pz := mz + JsMath.js_sin(a) * 9.0
		px = maxf(6.0, minf(sx - 7.0, px))
		pz = maxf(6.0, minf(sz - 7.0, pz))
		var tx := hx + (hx - mx) * 1.9 + (r.next() - 0.5) * 70.0
		var tz := hz + (hz - mz) * 1.9 + (r.next() - 0.5) * 70.0
		if k == 1:
			var ox := mx - hx
			var oz := mz - hz
			var ol := JsMath.js_hypot(ox, oz)
			if ol == 0.0:
				ol = 1.0
			var sg := -1.0 if r.next() < 0.5 else 1.0
			tx = mx + (ox / ol * 0.4 - oz / ol * sg) * 140.0
			tz = mz + (oz / ol * 0.4 + ox / ol * sg) * 140.0
		var dx := tx - px
		var dz := tz - pz
		var dl := JsMath.js_hypot(dx, dz)
		dx /= dl
		dz /= dl
		var lv := h0[int(pz) * sx + int(px)] - 1
		var length := 0
		var falls := 0
		var ph := r.next() * 100.0
		for s in 420:
			var ix := JsMath.f_to_i32(px)
			var iz := JsMath.f_to_i32(pz)
			if ix < 3 or iz < 3 or ix > sx - 4 or iz > sz - 4:
				break
			var i := iz * sx + ix
			if wl[i] >= 0:
				var in_lake := false
				for l in c.lakes:
					if JsMath.js_hypot(float(l["x"]) - px, float(l["z"]) - pz) < float(l["r"]) * 1.2:
						in_lake = true
						break
				if in_lake:
					break
			var g := h0[i]
			var upper := lv
			var drop := 0
			if g - 1 < lv:
				lv = maxi(3, g - 1)
				drop = upper - lv
				falls += 1
			for oz in range(-3, 4):
				for ox in range(-3, 4):
					var x := ix + ox
					var z := iz + oz
					if x < 2 or z < 2 or x > sx - 3 or z > sz - 3:
						continue
					var d := JsMath.js_hypot(ox, oz)
					var j := z * sx + x
					if d <= 1.6:
						hh[j] = mini(hh[j], lv - 2)
						wl[j] = mini(wl[j], lv) if wl[j] >= 0 else lv
						river_mask[j] = 1
						water_flow[j * 2] = dx * 0.65
						water_flow[j * 2 + 1] = dz * 0.65
						water_guide[j * 2] = JsMath.js_round_i(dx * 127.0) & 0xFF
						water_guide[j * 2 + 1] = JsMath.js_round_i(dz * 127.0) & 0xFF
						# Un salto ottiene una gola stretta e orientata: cima e base codificano
						# il velo verticale separato dalla pozza sottostante.
						if drop > 0:
							var along := ox * dx + oz * dz
							var side := absf(-ox * dz + oz * dx)
							if side <= 1.05 and along >= -0.75 and along <= 1.25:
								wf_mask[j] = 1
								wf_top[j] = maxi(wf_top[j], upper + 1)
								var base := lv + 1
								wf_base[j] = mini(wf_base[j], base) if wf_base[j] != 0 else base
					elif d <= 2.5:
						hh[j] = mini(hh[j], lv - 1)
						wl[j] = mini(wl[j], lv) if wl[j] >= 0 else lv
			# Direzione: verso la meta + discesa del terreno + meandro; lo spawn resta asciutto.
			var gx := h0[i + 2] - h0[i - 2]
			var gz := h0[i + 2 * sx] - h0[i - 2 * sx]
			var sdx := px - hx
			var sdz := pz - hz
			var sd := JsMath.js_hypot(sdx, sdz)
			if sd == 0.0:
				sd = 1.0
			var rep := maxf(0.0, 1.0 - sd / 20.0) * 2.2
			var tdx := tx - px
			var tdz := tz - pz
			var tl := JsMath.js_hypot(tdx, tdz)
			if tl == 0.0:
				tl = 1.0
			var m := JsMath.js_sin(s * 0.11 + ph) * 0.9
			var ndx := tdx / tl * 1.0 - gx * 0.2 + (-tdz / tl) * m + sdx / sd * rep
			var ndz := tdz / tl * 1.0 - gz * 0.2 + (tdx / tl) * m + sdz / sd * rep
			var nl := JsMath.js_hypot(ndx, ndz)
			if nl == 0.0:
				nl = 1.0
			dx = dx * 0.6 + ndx / nl * 0.4
			dz = dz * 0.6 + ndz / nl * 0.4
			var l2 := JsMath.js_hypot(dx, dz)
			dx /= l2
			dz /= l2
			px += dx
			pz += dz
			length += 1
		c.rivers.append({"len": length, "falls": falls})


## Terrazze: nessuna cella supera di piu' di 2 le vicine (vincolo della salita a rampa).
static func _pass_terrazze(c: GenContext) -> void:
	var sx := c.sx
	var sz := c.sz
	var hh := c.hh
	for it in 40:
		var ch := 0
		for z in sz:
			for x in sx:
				var i := z * sx + x
				var m := 999
				if x > 0:
					m = mini(m, hh[i - 1])
				if x < sx - 1:
					m = mini(m, hh[i + 1])
				if z > 0:
					m = mini(m, hh[i - sx])
				if z < sz - 1:
					m = mini(m, hh[i + sx])
				if hh[i] > m + 2:
					hh[i] = m + 2
					ch += 1
		if ch == 0:
			break


## Argini: l'acqua non si affaccia su terra piu' bassa (si alza la sponda); acqua senza
## fondo tolta; bordi del mondo asciutti.
static func _pass_argini(c: GenContext) -> void:
	var sx := c.sx
	var sz := c.sz
	var hh := c.hh
	var wl := c.wl
	for it in 3:
		var ch := 0
		for z in range(1, sz - 1):
			for x in range(1, sx - 1):
				var i := z * sx + x
				var lv := wl[i]
				if lv < 0:
					continue
				if hh[i] >= lv:
					wl[i] = -1
					continue
				for j: int in [i - 1, i + 1, i - sx, i + sx]:
					if wl[j] >= 0:
						continue
					if hh[j] < lv:
						hh[j] = lv
						ch += 1
		if ch == 0:
			break
	for x in sx:
		wl[x] = -1
		wl[(sz - 1) * sx + x] = -1
	for z in sz:
		wl[z * sx] = -1
		wl[z * sx + sx - 1] = -1


## Biomi: tabella temperatura (corretta con la quota) x umidita'; niente deserto/savana
## vicino all'acqua.
static func _pass_biomi(c: GenContext) -> void:
	var sx := c.sx
	var sz := c.sz
	var hh := c.hh
	var wl := c.wl
	var bio := c.world.biome
	var cl := c.world.climate
	var sea := c.sea
	for i in sx * sz:
		var h := hh[i]
		var t := _clamp01(c.f_temp[i] - (h - sea) * 0.022)
		var u := c.f_hum[i]
		var b := Biomes.PRATO
		if h >= sea + 15:
			b = Biomes.VETTA
		elif t < 0.27:
			b = Biomes.TUNDRA
		elif t > 0.74 and u < 0.30:
			b = Biomes.DESERTO
		elif t > 0.62 and u < 0.45:
			b = Biomes.SAVANA
		elif u > 0.62:
			b = Biomes.FORESTA
		var tt := t
		var uu := u
		if not wl.is_empty() and (b == Biomes.DESERTO or b == Biomes.SAVANA):
			var x := i % sx
			@warning_ignore("integer_division")
			var z := i / sx
			var near := false
			var oz := -4
			while oz <= 4 and not near:
				for ox in range(-4, 5):
					var xx := x + ox
					var zz := z + oz
					if xx >= 0 and zz >= 0 and xx < sx and zz < sz and wl[zz * sx + xx] >= 0 and ox * ox + oz * oz <= 18:
						near = true
						break
				oz += 1
			if near:
				b = Biomes.PRATO
				tt = 0.5
				uu = 0.56
		bio[i] = b
		cl[i * 4] = JsMath.js_round_i(tt * 255.0)
		cl[i * 4 + 1] = JsMath.js_round_i(uu * 255.0)
		cl[i * 4 + 2] = 255 if b == Biomes.VETTA else 0
		cl[i * 4 + 3] = 255


## Strati: colonne di blocchi per bioma, sporgenze di pietra, acqua ferma e rive di sabbia.
static func _pass_strati(c: GenContext) -> void:
	var sx := c.sx
	var sy := c.sy
	var sz := c.sz
	var n := sx * sz
	var plane := n
	var hh := c.hh
	var wl := c.wl
	var has_wl := not wl.is_empty()
	var w := c.world
	var bl := w.blocks
	var bio := w.biome
	var surf := w.surface
	var wf_top := w.waterfall_top
	var has_wf := not wf_top.is_empty()
	var dark_lim := sy * 0.22
	var n_ledge := Fbm2Lattice.new(c.seed_value + 9, 3, 0.0, (sx - 1) / 14.0, 0.0, (sz - 1) / 14.0)
	var n_sand := Fbm2Lattice.new(c.seed_value + 61, 2, 0.0, (sx - 1) / 5.0, 0.0, (sz - 1) / 5.0)
	var f_ledge := n_ledge.field(Fbm2Lattice.axis(sx, 14.0, 0.0), Fbm2Lattice.axis(sz, 14.0, 0.0))
	var f_sand := n_sand.field(Fbm2Lattice.axis(sx, 5.0, 0.0), Fbm2Lattice.axis(sz, 5.0, 0.0))
	for z in sz:
		for x in sx:
			var i := z * sx + x
			var h := hh[i]
			var bm := bio[i]
			var top: int = Biomes.TOP[bm]
			var fill: int = Biomes.FILL[bm]
			var fill_depth: int = Biomes.FILL_DEPTH[bm]
			var drop := 0
			if x > 0:
				drop = maxi(drop, h - hh[i - 1])
			if x < sx - 1:
				drop = maxi(drop, h - hh[i + 1])
			if z > 0:
				drop = maxi(drop, h - hh[i - sx])
			if z < sz - 1:
				drop = maxi(drop, h - hh[i + sx])
			var ledge := drop >= 2 and f_ledge[i] > 0.5 and top == GRASS
			surf[i] = h
			for y in h + 1:
				var id := STONE
				if y == 0:
					id = BEDROCK
				elif y == h:
					id = STONE if ledge else top
				elif y > h - fill_depth:
					id = SAND if (bm == Biomes.DESERTO and y > h - 2) else fill
				elif y < dark_lim:
					id = DARKSTONE
				bl[y * plane + i] = id
			var l0 := wl[i] if has_wl else -1
			var wf := wf_top[i] if has_wf else 0
			var lv := maxi(l0, wf - 1) if wf != 0 else l0
			if lv > h:
				var shore := STONE if h > c.sea + 9 else SAND
				bl[h * plane + i] = shore
				if h > 1:
					bl[(h - 1) * plane + i] = shore
				for y in range(h + 1, lv + 1):
					bl[y * plane + i] = WATER
				w.water_level[i] = lv + 1
			elif has_wl and top == GRASS and not ledge:
				var sh := false
				for j: int in [i - 1, i + 1, i - sx, i + sx]:
					if j >= 0 and j < n and wl[j] >= 0 and wl[j] >= h - 1:
						sh = true
				if sh and f_sand[i] > 0.42:
					bl[h * plane + i] = SAND


## Grotte: gallerie a doppio rumore 3D e caverne; lava sul fondo. Salta con caves:false.
static func _pass_grotte(c: GenContext) -> void:
	if not c.caves:
		return
	var sx := c.sx
	var sy := c.sy
	var sz := c.sz
	var plane := sx * sz
	var bl := c.world.blocks
	var surf := c.world.surface
	var lx := float(sx - 1)
	var ly := float(sy - 1)
	var lz := float(sz - 1)
	var n_a := Noise3Lattice.new(c.seed_value + 101, 0.0, lx / 13.0, 0.0, ly / 9.0, 0.0, lz / 13.0)
	var n_b := Noise3Lattice.new(c.seed_value + 202, 40.0, lx / 9.0 + 40.0, 0.0, ly / 7.0, 0.0, lz / 9.0)
	var n_c := Noise3Lattice.new(c.seed_value + 303, 0.0, lx / 22.0, 0.0, ly / 12.0, 0.0, lz / 22.0)
	n_a.set_rows(Fbm2Lattice.axis(sy, 9.0, 0.0))
	n_b.set_rows(Fbm2Lattice.axis(sy, 7.0, 0.0))
	n_c.set_rows(Fbm2Lattice.axis(sy, 12.0, 0.0))
	# Riferimenti locali (i Packed*Array sono condivisi): interpolazione su y inline.
	var a_col := n_a.col_a
	var a_colb := n_a.col_b
	var a_k := n_a.row_k
	var a_f := n_a.row_f
	var width := PackedFloat64Array()
	width.resize(sy)
	for y in sy:
		width[y] = 0.055 + 0.02 * (1.0 - float(y) / sy)
	var cav_lim := sy * 0.3
	for z in sz:
		var fz := float(z)
		for x in sx:
			var fx := float(x)
			var col := z * sx + x
			var h := surf[col]
			var b_ready := false
			n_a.prepare_column(fx / 13.0, fz / 13.0)
			var a_ok := n_a.col_ok
			var a_fz := n_a.col_fz
			for y in range(1, h - 2):
				var nv := 0.0
				var k := a_k[y]
				if a_ok and k >= 0:
					var fy := a_f[y]
					var a0 := a_col[k]
					var b0 := a_colb[k]
					var c0 := a0 + (a_col[k + 1] - a0) * fy
					nv = c0 + (b0 + (a_colb[k + 1] - b0) * fy - c0) * a_fz
				else:
					nv = n_a.at_row(y)
				var wv := width[y]
				if absf(nv - 0.5) < wv:
					if not b_ready:
						n_b.prepare_column(fx / 9.0 + 40.0, fz / 9.0)
						b_ready = true
					if absf(n_b.at_row(y) - 0.5) < wv + 0.09:
						bl[y * plane + col] = LAVA if y < 4 else AIR
			if 1 < minf(h - 3, cav_lim):
				n_c.prepare_column(fx / 22.0, fz / 22.0)
			var y2 := 1
			while y2 < minf(h - 3, cav_lim):
				if n_c.at_row(y2) > 0.66:
					bl[y2 * plane + col] = LAVA if y2 < 3 else AIR
				y2 += 1


## Minerali: rame, ferro e oro nella pietra, con soglie di profondita'.
static func _pass_minerali(c: GenContext) -> void:
	var sx := c.sx
	var sy := c.sy
	var sz := c.sz
	var plane := sx * sz
	var bl := c.world.blocks
	var surf := c.world.surface
	var lx := float(sx - 1)
	var ly := float(sy - 1)
	var lz := float(sz - 1)
	var n_cu := Noise3Lattice.new(c.seed_value + 404, 0.0, lx / 5.0, 0.0, ly / 5.0, 0.0, lz / 5.0)
	var n_fe := Noise3Lattice.new(c.seed_value + 505, 9.0, lx / 5.0 + 9.0, 0.0, ly / 5.0, 0.0, lz / 5.0)
	var n_au := Noise3Lattice.new(c.seed_value + 606, 19.0, lx / 4.0 + 19.0, 0.0, ly / 4.0, 0.0, lz / 4.0)
	n_cu.set_rows(Fbm2Lattice.axis(sy, 5.0, 0.0))
	n_fe.set_rows(Fbm2Lattice.axis(sy, 5.0, 0.0))
	n_au.set_rows(Fbm2Lattice.axis(sy, 4.0, 0.0))
	var cu_a := n_cu.col_a
	var cu_b := n_cu.col_b
	var cu_k := n_cu.row_k
	var cu_f := n_cu.row_f
	var iron_lim := sy * 0.4
	var gold_lim := sy * 0.2
	for z in sz:
		var fz := float(z)
		for x in sx:
			var fx := float(x)
			var col := z * sx + x
			var h := surf[col]
			# Colonne preparate solo al primo uso (il rumore dipende solo dalle coordinate).
			var cu := false
			var cu_ok := false
			var cu_fz := 0.0
			var fe := false
			var au := false
			var i := plane + col
			for y in range(1, h):
				var id := bl[i]
				if id != STONE and id != DARKSTONE:
					i += plane
					continue
				if y < h - 3:
					if not cu:
						n_cu.prepare_column(fx / 5.0, fz / 5.0)
						cu = true
						cu_ok = n_cu.col_ok
						cu_fz = n_cu.col_fz
					var nv := 0.0
					var k := cu_k[y]
					if cu_ok and k >= 0:
						var fy := cu_f[y]
						var a0 := cu_a[k]
						var b0 := cu_b[k]
						var c0 := a0 + (cu_a[k + 1] - a0) * fy
						nv = c0 + (b0 + (cu_b[k + 1] - b0) * fy - c0) * cu_fz
					else:
						nv = n_cu.at_row(y)
					if nv > 0.74:
						bl[i] = COPPER
						i += plane
						continue
				if y < iron_lim:
					if not fe:
						n_fe.prepare_column(fx / 5.0 + 9.0, fz / 5.0)
						fe = true
					if n_fe.at_row(y) > 0.76:
						bl[i] = IRON
						i += plane
						continue
				if y < gold_lim:
					if not au:
						n_au.prepare_column(fx / 4.0 + 19.0, fz / 4.0)
						au = true
					if n_au.at_row(y) > 0.78:
						bl[i] = GOLD
				i += plane


## Rifinitura: roccia madre a y = 0.
static func _pass_rifinitura(c: GenContext) -> void:
	var bl := c.world.blocks
	for i in c.sx * c.sz:
		bl[i] = BEDROCK


# ------------------------------------------------------------------ sponde

@warning_ignore("integer_division")
## shapeRiverBanks (core.js r.536): chiude di pietra le celle d'aria accanto all'acqua
## (fuori dalle cascate disegnate) e riallinea `surface` alla roccia reale.
static func shape_river_banks(w: WorldData) -> void:
	var sx := w.size_x
	var sy := w.size_y
	var sz := w.size_z
	var plane := sx * sz
	var bl := w.blocks
	var caps := PackedInt32Array()
	caps.resize(plane)
	caps.fill(-1)
	# Solo le celle d'acqua contano (find nativo); caps prende il massimo, quindi l'ordine
	# di visita (indice invece di z, x, y) non cambia il risultato.
	var i := bl.find(WATER)
	while i != -1:
		var y := i / plane
		var r := i - y * plane
		var z := r / sx
		var x := r - z * sx
		i = bl.find(WATER, i + 1)
		if x < 1 or z < 1 or y < 1 or x > sx - 2 or z > sz - 2 or y > sy - 2:
			continue
		if FluidSystem.authored_fall(w, x, y, z):
			continue
		for d in 4:
			var xx := x + FluidSystem.DIR_X[d]
			var zz := z + FluidSystem.DIR_Z[d]
			if bl[y * plane + zz * sx + xx] != AIR or FluidSystem.authored_fall(w, xx, y, zz):
				continue
			var cc := zz * sx + xx
			caps[cc] = maxi(caps[cc], y)
	var placed := 0
	var surf := w.surface
	for z in range(1, sz - 1):
		for x in range(1, sx - 1):
			var cc := z * sx + x
			var h := caps[cc]
			if h < 0:
				continue
			for y in range(surf[cc] + 1, h + 1):
				if FluidSystem.authored_fall(w, x, y, z):
					continue
				if y < sy:
					bl[y * plane + cc] = STONE
				placed += 1
			# La cache della superficie resta coerente con la roccia reale, gola inclusa.
			for y in range(sy - 1, 0, -1):
				if FluidSystem.is_solid_id(bl[y * plane + cc]):
					surf[cc] = y
					break
	w.bank_blocks = placed
