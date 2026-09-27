class_name ProtoTextures
extends RefCounted
## Texture procedurali del prototipo, pixel per pixel: atlante dei blocchi
## (makeAtlas, HTML ~5704) e ciuffo dei fili d'erba (HTML 6734). Verificate per
## hash contro il canvas emulato di tools/extract_render_fixture.mjs.


## mulberry32 con la semantica a 32 bit di JavaScript.
class Mulberry32:
	extends RefCounted
	var a: int

	func _init(s: int) -> void:
		a = _i32(s)

	func next() -> float:
		a = _i32(a + 0x6D2B79F5)
		var t := _imul(a ^ ((a & 0xFFFFFFFF) >> 15), 1 | a)
		t = _i32(_i32(t + _imul(t ^ ((t & 0xFFFFFFFF) >> 7), 61 | t)) ^ t)
		return float((t ^ ((t & 0xFFFFFFFF) >> 14)) & 0xFFFFFFFF) / 4294967296.0

	static func _i32(v: int) -> int:
		return ((v & 0xFFFFFFFF) ^ 0x80000000) - 0x80000000

	static func _imul(x: int, y: int) -> int:
		return _i32(_i32(x) * _i32(y))


class Canvas:
	extends RefCounted
	var w: int
	var h: int
	var px := PackedByteArray()
	var style := PackedByteArray([0, 0, 0, 255])

	func _init(width: int, height: int) -> void:
		w = width
		h = height
		px.resize(w * h * 4)

	func fill_hex(c: String) -> void:
		var col := Color(c)
		style = PackedByteArray([col.r8, col.g8, col.b8, 255])

	func fill_rect(x: int, y: int, fw: int, fh: int) -> void:
		for yy in range(y, y + fh):
			for xx in range(x, x + fw):
				if xx < 0 or yy < 0 or xx >= w or yy >= h:
					continue
				var k := (yy * w + xx) * 4
				px[k] = style[0]
				px[k + 1] = style[1]
				px[k + 2] = style[2]
				px[k + 3] = style[3]

	func image() -> Image:
		return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, px)


static func atlas_bytes() -> PackedByteArray:
	var g := Canvas.new(256, 32)
	var rng := Mulberry32.new(7)
	var px := func(x: int, y: int, c: String) -> void:
		g.fill_hex(c)
		g.fill_rect(x, y, 1, 1)
	var speck := func(tx: int, row: int, base: String, dark: String, light: String, dens: float) -> void:
		for y in 16:
			for x in 16:
				var r := rng.next()
				px.call(tx * 16 + x, row * 16 + y, dark if r < dens else (light if r > 1.0 - dens * 0.6 else base))
	var both := func(t: int, b: String, d: String, l: String, dens: float) -> void:
		speck.call(t, 0, b, d, l, dens)
		speck.call(t, 1, b, d, l, dens)
	var ore := func(t: int, dot_c: String) -> void:
		both.call(t, "#6f7478", "#565b60", "#858a8f", 0.16)
		for row in 2:
			for i in 7:
				var x := 1 + floori(rng.next() * 13)
				var y := 1 + floori(rng.next() * 13)
				px.call(t * 16 + x, row * 16 + y, dot_c)
				px.call(t * 16 + x + 1, row * 16 + y, dot_c)
				px.call(t * 16 + x, row * 16 + y + 1, dot_c)
	both.call(0, "#f0f", "#f0f", "#f0f", 0.0)
	speck.call(1, 0, "#5aa63b", "#478a2d", "#77c14e", 0.2)
	speck.call(1, 1, "#8a6a45", "#6f5335", "#a3805a", 0.18)
	both.call(2, "#8a6a45", "#6f5335", "#a3805a", 0.18)
	both.call(3, "#6f7478", "#565b60", "#858a8f", 0.16)
	both.call(4, "#d9c47e", "#c4ae66", "#ecd996", 0.14)
	ore.call(5, "#d9843a")
	ore.call(6, "#d8c3a5")
	ore.call(7, "#f2d43a")
	both.call(8, "#2e3236", "#202326", "#3c4045", 0.3)
	both.call(9, "#f0782a", "#d5511c", "#ffd05a", 0.25)
	both.call(10, "#c9973a", "#8a5a24", "#ffe680", 0.2)
	both.call(11, "#a37c4f", "#7e5c37", "#c39a66", 0.12)
	both.call(12, "#3f7d2f", "#2f6222", "#5a9a42", 0.28)
	both.call(13, "#c9a86a", "#b09056", "#dcc084", 0.12)
	both.call(14, "#45484d", "#33363a", "#55595e", 0.2)
	return g.px


static func leaf_bytes() -> PackedByteArray:
	var g := Canvas.new(32, 16)
	var tuft := func(ox: int, blades: Array) -> void:
		for b: Array in blades:
			var x: int = b[0]
			var hh: int = b[1]
			var ln: int = b[2]
			for y in hh:
				var t := float(y) / hh
				# Math.round: arrotonda .5 verso +infinito.
				var xx := ox + x + floori(ln * t * t * 2.0 + 0.5)
				var tone := 255 if t > 0.72 else (214 if t > 0.30 else 176)
				g.style = PackedByteArray([tone, 0, 0, 255])
				g.fill_rect(xx, y, 2 if (t < 0.45 and hh > 7) else 1, 1)
	tuft.call(0, [[1, 7, -1], [3, 11, 0], [5, 14, 1], [7, 10, -1], [9, 15, 0], [11, 9, 1], [13, 12, -1], [14, 6, 1]])
	tuft.call(16, [[0, 6, 1], [2, 12, -1], [4, 9, 0], [6, 15, 1], [8, 11, 0], [10, 13, -1], [12, 8, 1], [14, 10, 0]])
	return g.px


static func atlas_texture() -> ImageTexture:
	return ImageTexture.create_from_image(Image.create_from_data(256, 32, false, Image.FORMAT_RGBA8, atlas_bytes()))


static func leaf_texture() -> ImageTexture:
	return ImageTexture.create_from_image(Image.create_from_data(32, 16, false, Image.FORMAT_RGBA8, leaf_bytes()))
