class_name SaveService
extends RefCounted
## Salvataggio del mondo (M5). Un file per partita: intestazione + dizionario
## serializzato e compresso (zstd). Scrittura sicura: prima un file .tmp,
## riletto e verificato, poi il file corrente diventa .bak e il .tmp prende il
## suo posto. In lettura, se il file principale e' rovinato si usa il .bak.

const MAGIC := "ISOT"
const VERSION := 1
static var path := "user://saves/world.save"


static func exists() -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")


static func encode(state: Dictionary) -> PackedByteArray:
	var raw := var_to_bytes(state)
	var packed := raw.compress(FileAccess.COMPRESSION_ZSTD)
	var out := PackedByteArray()
	out.append_array(MAGIC.to_ascii_buffer())
	var head := PackedByteArray()
	head.resize(12)
	head.encode_u32(0, VERSION)
	head.encode_u32(4, raw.size())
	head.encode_u32(8, hash(packed) & 0xffffffff)
	out.append_array(head)
	out.append_array(packed)
	return out


## Dizionario salvato, o {} se i byte non sono un salvataggio valido.
static func decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 16 or bytes.slice(0, 4).get_string_from_ascii() != MAGIC:
		return {}
	var version := bytes.decode_u32(4)
	var raw_size := bytes.decode_u32(8)
	var check := bytes.decode_u32(12)
	if version != VERSION:
		return {}
	var packed := bytes.slice(16)
	if (hash(packed) & 0xffffffff) != check:
		return {}
	var raw := packed.decompress(raw_size, FileAccess.COMPRESSION_ZSTD)
	if raw.size() != raw_size:
		return {}
	var v: Variant = bytes_to_var(raw)
	return v if v is Dictionary else {}


static func save(state: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var bytes := encode(state)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer(bytes)
	f.close()
	# Verifica: il file scritto si rilegge ed e' identico.
	if decode(FileAccess.get_file_as_bytes(tmp)).is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		return false
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(abs_path + ".bak")
		DirAccess.rename_absolute(abs_path, abs_path + ".bak")
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), abs_path) == OK


## Il salvataggio piu' recente leggibile ({} se nessuno).
static func load_state() -> Dictionary:
	for p in [path, path + ".bak"]:
		if FileAccess.file_exists(p):
			var d := decode(FileAccess.get_file_as_bytes(p))
			if not d.is_empty():
				return d
	return {}


static func delete_all() -> void:
	for p in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


## Stato del mondo modificabile (blocchi e acqua); il resto si rigenera dal seme.
## `skip`: celle di passaggio (muri e colonne delle magie) salvate come aria.
static func world_state(w: WorldData, skip: Array[Vector3i] = []) -> Dictionary:
	if skip.is_empty():
		return {"seed": w.world_seed, "size": [w.size_x, w.size_y, w.size_z], "blocks": w.blocks, "fluid": w.fluid,
			"water_level": w.water_level, "water_flow": w.water_flow, "surface": w.surface}
	var old_blocks := w.blocks.duplicate()
	var old_surface := w.surface.duplicate()
	var cols := {}
	for c in skip:
		if w.inside(c.x, c.y, c.z):
			w.blocks[w.index(c.x, c.y, c.z)] = BlockCatalog.AIR
			cols[Vector2i(c.x, c.z)] = true
	for k: Vector2i in cols:
		var top := 0
		for y in range(w.size_y - 1, -1, -1):
			if w.is_solid_at(k.x, y, k.y):
				top = y
				break
		w.surface[k.y * w.size_x + k.x] = top
	var d := {"seed": w.world_seed, "size": [w.size_x, w.size_y, w.size_z], "blocks": w.blocks.duplicate(), "fluid": w.fluid,
		"water_level": w.water_level, "water_flow": w.water_flow, "surface": w.surface.duplicate()}
	w.blocks = old_blocks
	w.surface = old_surface
	return d


## Applica lo stato salvato a un mondo appena generato dallo stesso seme e ne
## ricalcola la luce; falso se le dimensioni non tornano.
static func apply_world_state(w: WorldData, d: Dictionary, catalog: BlockCatalog) -> bool:
	var size: Array = d.get("size", [])
	if size.size() != 3 or int(size[0]) != w.size_x or int(size[1]) != w.size_y or int(size[2]) != w.size_z:
		return false
	var b: PackedByteArray = d.get("blocks", PackedByteArray())
	if b.size() != w.blocks.size():
		return false
	w.blocks = b
	w.surface = d.get("surface", w.surface)
	w.water_level = d.get("water_level", w.water_level)
	w.water_flow = d.get("water_flow", w.water_flow)
	var fl: PackedByteArray = d.get("fluid", PackedByteArray())
	if fl.size() == w.blocks.size():
		w.fluid = fl
	LightEngine.new(w, catalog).compute_all()
	return true
