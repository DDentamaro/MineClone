class_name GenParity
extends RefCounted
## Confronto del porting GDScript (WorldGenerator, FluidSystem) con le fixture estratte
## dal prototipo da tools/extract_gen_stages.mjs (tests/fixtures/gen_v064/<nome>).
## Controlla sha256 per passata e per fase, statistiche, e rigioca lo scenario "gameplay"
## (sampleWater, fluidSpread, editFluid + 40 tick di stepFluid).

const ROOT := "res://tests/fixtures/gen_v064"

## Nome JS del buffer -> proprieta' di WorldData.
const JS_FIELDS := {
	"blocks": "blocks", "biome": "biome", "surface": "surface", "waterLevel": "water_level",
	"climate": "climate", "riverMask": "river_mask", "waterfallMask": "waterfall_mask",
	"waterfallBase": "waterfall_base", "waterfallTop": "waterfall_top", "waterGuide": "water_guide",
	"waterFlow": "water_flow", "fluid": "fluid", "waterBodies": "water_bodies",
}

var name: String
var manifest: Dictionary = {}
var errors: PackedStringArray = []
var world: WorldData
var gen_ms := 0.0
var _pass_index := 0


static func load_json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


static func hex_f(h: String) -> float:
	return h.hex_decode().decode_double(0)


static func f_hex(v: float) -> String:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_double(0, v)
	return b.hex_encode()


static func sha(bytes: PackedByteArray) -> String:
	if bytes.is_empty():
		# HashingContext rifiuta gli update vuoti: sha256 della stringa vuota.
		return "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
	return WorldFixture.sha256_hex(bytes)


## Byte del buffer come nel TypedArray JS corrispondente.
static func js_bytes(w: WorldData, js_name: String) -> PackedByteArray:
	var v: Variant = w.get(str(JS_FIELDS[js_name]))
	if v is PackedByteArray:
		return v
	if v is PackedFloat32Array:
		var f: PackedFloat32Array = v
		return f.to_byte_array()
	var i: PackedInt32Array = v
	return i.to_byte_array()


## Int16Array (HH, WL) dai PackedInt32Array del porting.
static func int16_bytes(a: PackedInt32Array) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(a.size() * 2)
	for k in a.size():
		b.encode_s16(k * 2, a[k])
	return b


func _init(fixture_name: String) -> void:
	name = fixture_name
	var m: Variant = load_json(ROOT.path_join(name).path_join("manifest.json"))
	if m is Dictionary:
		manifest = m
	else:
		errors.append("%s: manifest mancante" % name)


func _err(msg: String) -> void:
	errors.append("%s: %s" % [name, msg])


func _eq(got: Variant, expected: Variant, msg: String) -> void:
	if got != expected:
		_err("%s: ottenuto %s, atteso %s" % [msg, got, expected])


## Confronta lo sha di un buffer; se la fixture ha il buffer completo indica la prima differenza.
func _buf(got: PackedByteArray, expected_sha: String, msg: String, file_key: String = "") -> void:
	var h := sha(got)
	if h == expected_sha:
		return
	var detail := ""
	var files: Dictionary = manifest.get("files", {})
	if file_key != "" and files.has(file_key):
		var info: Dictionary = files[file_key]
		var raw := FileAccess.get_file_as_bytes(ROOT.path_join(name).path_join(str(info["file"])))
		var exp := raw.decompress(int(info["bytes"]), FileAccess.COMPRESSION_GZIP)
		var diff := 0
		var first := -1
		for k in mini(exp.size(), got.size()):
			if exp[k] != got[k]:
				diff += 1
				if first < 0:
					first = k
		detail = " (%d byte diversi, primo a %d: %d invece di %d)" % [diff, first, got[first] if first >= 0 else -1, exp[first] if first >= 0 else -1]
	_err("%s: sha diverso%s" % [msg, detail])


## Genera il mondo della fixture confrontando tutte le fasi. Restituisce true se identico.
func run_generation(catalog: BlockCatalog) -> bool:
	if manifest.is_empty():
		return false
	var cfg: Dictionary = manifest["cfg"]
	world = WorldData.new(int(cfg["X"]), int(cfg["Y"]), int(cfg["Z"]), catalog.solid_table())
	_pass_index = 0
	var t0 := Time.get_ticks_usec()
	WorldGenerator.generate(world, int(cfg["seed"]), {"caves": bool(cfg["caves"]),
		"after_pass": _after_pass, "on_stage": _on_stage})
	gen_ms = (Time.get_ticks_usec() - t0) / 1000.0
	_check_final()
	return errors.is_empty()


func _after_pass(pass_name: String, c: WorldGenerator.GenContext) -> void:
	var passes: Array = manifest["passes"]
	var e: Dictionary = passes[_pass_index]
	_pass_index += 1
	_eq(pass_name, str(e["name"]), "ordine delle passate")
	var p := "passata %s" % pass_name
	_buf(c.world.blocks, str(e["blocks"]), p + " blocks")
	_buf(int16_bytes(c.hh), str(e["hh"]), p + " HH")
	if e.has("wl"):
		_buf(int16_bytes(c.wl), str(e["wl"]), p + " WL")
	if pass_name == "Campi":
		_buf(c.f_cont.to_byte_array(), str(e["f_cont"]), p + " F.cont")
		_buf(c.f_eros.to_byte_array(), str(e["f_eros"]), p + " F.eros")
		_buf(c.f_ridge.to_byte_array(), str(e["f_ridge"]), p + " F.ridge")
		_buf(c.f_temp.to_byte_array(), str(e["f_temp"]), p + " F.temp")
		_buf(c.f_hum.to_byte_array(), str(e["f_hum"]), p + " F.hum")
		_eq([f_hex(c.massif_x), f_hex(c.massif_z)], e["massif"], p + " massiccio")
	if pass_name == "Laghi":
		var got: Array = []
		for l in c.lakes:
			got.append([f_hex(float(l["x"])), f_hex(float(l["z"])), f_hex(float(l["r"])), int(l["level"]), int(l["cells"])])
		var exp_lakes: Array = []
		for l: Array in e["lakes"]:
			exp_lakes.append([l[0], l[1], l[2], int(l[3]), int(l[4])])
		_eq(got, exp_lakes, p + " laghi")
	if pass_name == "Fiumi":
		_eq(_rivers_json(c.rivers), _rivers_json(e["rivers"] as Array), p + " fiumi")
		for k: String in ["river_mask", "water_flow", "water_guide", "waterfall_mask", "waterfall_base", "waterfall_top"]:
			var v: Variant = c.world.get(k)
			var bytes: PackedByteArray = (v as PackedFloat32Array).to_byte_array() if v is PackedFloat32Array else v
			_buf(bytes, str(e[k]), p + " " + k)
	if pass_name == "Biomi":
		_buf(c.world.biome, str(e["biome"]), p + " biome")
		_buf(c.world.climate, str(e["climate"]), p + " climate")
	if pass_name == "Strati":
		_buf(c.world.surface, str(e["surface"]), p + " surface")
		_buf(c.world.water_level, str(e["water_level"]), p + " waterLevel")


static func _rivers_json(rivers: Array) -> String:
	var out: Array = []
	for r: Dictionary in rivers:
		out.append([int(r["len"]), int(r["falls"])])
	return JSON.stringify(out)


static func _dirty_keys(d: Dictionary) -> Array:
	var out: Array = []
	for k: Vector2i in d:
		out.append("%d,%d" % [k.x, k.y])
	return out


static func _int_list(v: Variant) -> Array:
	var out: Array = []
	for x: Variant in v:
		out.append(int(x))
	return out


func _on_stage(stage: String, w: WorldData) -> void:
	var stages: Dictionary = manifest["stages"]
	var s: Dictionary = stages[stage]
	for js_name: String in s:
		if JS_FIELDS.has(js_name):
			_buf(js_bytes(w, js_name), str(s[js_name]), "fase %s %s" % [stage, js_name], "%s.%s" % [stage, js_name])
	if stage == "banks":
		_eq(w.bank_blocks, int(s["bank_blocks"]), "bankBlocks")
	if stage == "init_fluid":
		var keys := w.fluid_queue.keys()
		_eq(keys.size(), int(s["queue_size"]), "initFluid: dimensione coda")
		_eq(_int_list(keys.slice(0, 20)), _int_list(s["queue_head"]), "initFluid: testa della coda")
		_eq(_int_list(keys.slice(-20)), _int_list(s["queue_tail"]), "initFluid: coda della coda")
		_eq(_dirty_keys(w.fluid_dirty), s["dirty"], "initFluid: chunk sporchi")


func _check_final() -> void:
	var fin: Dictionary = manifest["final"]
	for js_name: String in fin:
		if JS_FIELDS.has(js_name):
			_buf(js_bytes(world, js_name), str(fin[js_name]), "finale " + js_name, "final." + js_name)
	_eq(world.fluid_queue.size(), int(fin["queue_size"]), "finale: dimensione coda")
	_eq(_dirty_keys(world.fluid_dirty), fin["dirty"], "finale: chunk sporchi")
	var st: Dictionary = manifest["stats"]
	var last: Array = world.gen_log[world.gen_log.size() - 1]
	_eq(int(last[2]), int(st["ticks"]), "tick di assestamento")
	var sp: Dictionary = st["spawn"]
	_eq(world.spawn_point(), Vector3(float(sp["x"]), float(sp["y"]), float(sp["z"])), "spawnPoint")
	_eq(_int_list(world.biome_share), _int_list(st["biome_share"]), "biomeShare")
	_eq([f_hex(float(world.massif["x"])), f_hex(float(world.massif["z"]))], st["massif"], "massif")
	_eq(int(world.water_info["lakes"]), int(st["lakes"]), "waterInfo.lakes")
	_eq(_rivers_json(world.water_info["rivers"] as Array), _rivers_json(st["rivers"] as Array), "waterInfo.rivers")
	_eq(int(world.water_info["cells"]), int(st["cells"]), "waterInfo.cells")
	_eq(world.bank_blocks, int(st["bank_blocks"]), "bankBlocks")


## Rigioca lo scenario gameplay registrato (dopo run_generation). True se identico.
func run_gameplay() -> bool:
	var g: Variant = manifest.get("gameplay")
	if not g is Dictionary:
		return errors.is_empty()
	var gp: Dictionary = g
	var w := world
	var k := 0
	for s: Dictionary in gp["samples"]:
		var p: Array = s["p"]
		var got := FluidSystem.sample_water(w, hex_f(str(p[0])), hex_f(str(p[1])), hex_f(str(p[2])))
		var lbl := "sampleWater #%d" % k
		_eq(got["wet"], s["wet"], lbl + " wet")
		_eq(f_hex(float(got["level"])), s["level"], lbl + " level")
		_eq(f_hex(float(got["depth"])), s["depth"], lbl + " depth")
		_eq(f_hex(float(got["immersion"])), s["immersion"], lbl + " immersion")
		_eq([f_hex(float(got["flowX"])), f_hex(float(got["flowY"])), f_hex(float(got["flowZ"]))], s["flow"], lbl + " flow")
		_eq(int(got["body"]), int(s["body"]), lbl + " body")
		_eq(got["falling"], s["falling"], lbl + " falling")
		if s["floor"] != null:
			_eq(int(got.get("floor", -1)), int(s["floor"]), lbl + " floor")
		k += 1
	var cache := {}
	for e: Array in gp["spread"]:
		var x := int(e[0])
		var y := int(e[1])
		var z := int(e[2])
		var lbl := "cella %d,%d,%d" % [x, y, z]
		_eq(FluidSystem.fluid_spread(w, x, y, z, cache), int(e[3]), lbl + " fluidSpread")
		_eq(f_hex(FluidSystem.fluid_corner(w, x, y, z)), e[4], lbl + " fluidCorner")
		_eq(f_hex(FluidSystem.fluid_height(w, x, y, z)), e[5], lbl + " fluidHeight")
		_eq(f_hex(FluidSystem.fluid_surface(w, x + 0.3, y, z + 0.6)), e[6], lbl + " fluidSurface")
		var v := FluidSystem.fluid_velocity(w, x, y, z)
		_eq([f_hex(v[0]), f_hex(v[1]), f_hex(v[2])], [e[7], e[8], e[9]], lbl + " fluidVelocity")
	for e: Array in gp["edits"]:
		var x := int(e[0])
		var y := int(e[1])
		var z := int(e[2])
		if w.inside(x, y, z):
			w.blocks[w.index(x, y, z)] = int(e[3])
		FluidSystem.edit_fluid(w, x, y, z, int(e[3]))
	var ae: Dictionary = gp["after_edit"]
	_eq(w.fluid_queue.size(), int(ae["queue_size"]), "editFluid: dimensione coda")
	_eq(_int_list(w.fluid_queue.keys().slice(0, 30)), _int_list(ae["queue_head"]), "editFluid: testa della coda")
	_eq(_dirty_keys(w.fluid_dirty), ae["dirty"], "editFluid: chunk sporchi")
	var t := 0
	for tick: Dictionary in gp["ticks"]:
		var upd := FluidSystem.step_fluid(w)
		var lbl := "stepFluid tick %d" % t
		_eq(upd.size() >> 1, int(tick["updates"]), lbl + " aggiornamenti")
		_buf(upd.to_byte_array(), str(tick["upd_sha"]), lbl + " elenco aggiornamenti")
		_eq(w.fluid_queue.size(), int(tick["queue"]), lbl + " coda")
		_buf(w.fluid, str(tick["fluid"]), lbl + " fluid")
		_buf(w.blocks, str(tick["blocks"]), lbl + " blocks")
		_buf(w.water_level, str(tick["water_level"]), lbl + " waterLevel")
		_buf(w.water_flow.to_byte_array(), str(tick["water_flow"]), lbl + " waterFlow")
		_buf(w.water_bodies.to_byte_array(), str(tick["water_bodies"]), lbl + " waterBodies")
		t += 1
	_eq(_dirty_keys(w.fluid_dirty), gp["final_dirty"], "scenario: chunk sporchi finali")
	return errors.is_empty()
