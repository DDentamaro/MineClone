class_name RenderFixture
extends RefCounted
## Riferimenti di resa estratti da tools/extract_render_fixture.mjs.

const DIR := "res://tests/fixtures/seed1931_v064_render"

static var _manifest: Dictionary = {}


static func manifest() -> Dictionary:
	if _manifest.is_empty():
		var gz := FileAccess.get_file_as_bytes(DIR.path_join("manifest.json.gz"))
		var raw := gz.decompress_dynamic(64 * 1024 * 1024, FileAccess.COMPRESSION_GZIP)
		_manifest = JSON.parse_string(raw.get_string_from_utf8())
	return _manifest


static func buffer(name: String) -> PackedByteArray:
	var info: Dictionary = manifest()["files"][name]
	var gz := FileAccess.get_file_as_bytes(DIR.path_join(str(info["file"])))
	return gz.decompress(int(info["bytes"]), FileAccess.COMPRESSION_GZIP)
