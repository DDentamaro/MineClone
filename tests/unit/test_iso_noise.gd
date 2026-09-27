extends TestCase
## Parita' esatta (==, confronto dei bit IEEE) di mulberry32, subSeed, hash3, noise2,
## noise3, fbm2, spline, Math.round/sin/cos/exp/atan2/hypot con i valori del prototipo
## calcolati da Node (tests/fixtures/gen_v064/samples.json).

var _s: Dictionary


func _samples() -> Dictionary:
	if _s.is_empty():
		_s = GenParity.load_json(GenParity.ROOT.path_join("samples.json"))
	return _s


static func _h(v: Variant) -> float:
	return GenParity.hex_f(str(v))


func _count_bad(rows: Array, fn: Callable) -> int:
	var bad := 0
	for r: Array in rows:
		if not fn.call(r):
			bad += 1
	return bad


func test_mulberry32() -> void:
	var m: Dictionary = _samples()["mulberry32"]
	for k: String in m:
		var r := IsoNoise.mulberry32(int(k))
		var got: Array = []
		for i in 12:
			got.append(GenParity.f_hex(r.next()))
		check_eq(got, m[k], "mulberry32(%s)" % k)


func test_sub_seed() -> void:
	var m: Dictionary = _samples()["sub_seed"]
	for k: String in m:
		var names: Dictionary = m[k]
		for n: String in names:
			check_eq(IsoNoise.sub_seed(int(k), n), int(names[n]), "subSeed(%s, %s)" % [k, n])


func test_hash3() -> void:
	var rows: Array = _samples()["hash3"]
	var bad := _count_bad(rows, func(r: Array) -> bool:
		return GenParity.f_hex(IsoNoise.hash3(int(r[0]), int(r[1]), int(r[2]), int(r[3]))) == r[4])
	check_eq(bad, 0, "hash3 diversi su %d" % rows.size())


func test_noise2_noise3_fbm2() -> void:
	var s := _samples()
	var n2: Array = s["noise2"]
	check_eq(_count_bad(n2, func(r: Array) -> bool:
		return GenParity.f_hex(IsoNoise.noise2(_h(r[0]), _h(r[1]), int(r[2]))) == r[3]), 0, "noise2 diversi su %d" % n2.size())
	var n3: Array = s["noise3"]
	check_eq(_count_bad(n3, func(r: Array) -> bool:
		return GenParity.f_hex(IsoNoise.noise3(_h(r[0]), _h(r[1]), _h(r[2]), int(r[3]))) == r[4]), 0, "noise3 diversi su %d" % n3.size())
	var fb: Array = s["fbm2"]
	check_eq(_count_bad(fb, func(r: Array) -> bool:
		return GenParity.f_hex(IsoNoise.fbm2(_h(r[0]), _h(r[1]), int(r[2]), int(r[3]))) == r[4]), 0, "fbm2 diversi su %d" % fb.size())


func test_spline() -> void:
	var pts := PackedFloat64Array([0.0, -2.0, 0.30, 0.0, 0.45, 1.0, 0.52, 2.0, 0.60, 7.0, 0.80, 9.0, 1.0, 11.0])
	var rows: Array = _samples()["spline"]
	check_eq(_count_bad(rows, func(r: Array) -> bool:
		return GenParity.f_hex(Biomes.spline(pts, _h(r[0]))) == r[1]), 0, "spline diverse")


func test_math_v8() -> void:
	var m: Dictionary = _samples()["math"]
	for fname: String in ["sin", "cos", "exp"]:
		var rows: Array = m[fname]
		var fn: Callable = Callable(JsMath, "js_" + fname)
		check_eq(_count_bad(rows, func(r: Array) -> bool:
			return GenParity.f_hex(float(fn.call(_h(r[0])))) == r[1]), 0, "Math.%s diversi su %d" % [fname, rows.size()])
	var at: Array = m["atan2"]
	check_eq(_count_bad(at, func(r: Array) -> bool:
		return GenParity.f_hex(JsMath.js_atan2(_h(r[0]), _h(r[1]))) == r[2]), 0, "Math.atan2 diversi su %d" % at.size())
	var hy: Array = m["hypot"]
	check_eq(_count_bad(hy, func(r: Array) -> bool:
		return GenParity.f_hex(JsMath.js_hypot(_h(r[0]), _h(r[1]))) == r[2]), 0, "Math.hypot diversi su %d" % hy.size())
	var rd: Array = _samples()["round"]
	check_eq(_count_bad(rd, func(r: Array) -> bool:
		return GenParity.f_hex(JsMath.js_round(_h(r[0]))) == r[1]), 0, "Math.round diversi")


func test_interi_js() -> void:
	check_eq(JsMath.i32(0x80000000), -2147483648, "|0 di 2^31")
	check_eq(JsMath.u32(-1), 4294967295, ">>>0 di -1")
	check_eq(JsMath.ushr(-8, 1), 2147483644, "-8 >>> 1")
	check_eq(JsMath.imul(0x7FFFFFFF, 0x7FFFFFFF), 1, "Math.imul")
	check_eq(JsMath.imul(-5, 0x9E3779B1), JsMath.i32(-5 * JsMath.i32(0x9E3779B1)), "Math.imul con negativi")
	check_eq(JsMath.f_to_i32(-3.7), -3, "(-3.7)|0")
	check_eq(JsMath.f_to_i32(4294967301.0), 5, "(2^32+5)|0")
	check_eq(JsMath.f_to_i32(1e20), 1661992960, "1e20|0")
