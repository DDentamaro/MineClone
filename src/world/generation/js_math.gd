class_name JsMath
extends RefCounted
## Aritmetica con la semantica esatta di JavaScript/V8, per la parita' bit a bit col
## prototipo (ISO_CORE v0_64).
##
## - Interi: gli int di GDScript sono a 64 bit; qui si emulano `|0`, `>>>`, `Math.imul`
##   (int32 con segno / uint32).
## - Math.round, Math.hypot: stesso algoritmo di V8 (ceil + correzione; somma di Kahan
##   normalizzata sul massimo).
## - Math.sin/cos/exp/atan2: V8 usa fdlibm (src/base/ieee754.cc), che NON coincide con la
##   libm di sistema usata da sin()/exp() di Godot (glibc su Linux, bionic su Android):
##   su 300.000 campioni glibc differisce nel 3-18% dei casi. Qui c'e' il porting di fdlibm,
##   verificato bit a bit contro Node 22 (vedi tests/fixtures/gen_v064/samples.json).
## - Le costanti di fdlibm si costruiscono dai bit IEEE: il tokenizer di GDScript non
##   arrotonda correttamente i letterali a 21 cifre (14 costanti su 54 risultano sbagliate
##   di 1 ulp). I letterali brevi del generatore invece sono letti correttamente (verificato).

const U32 := 0xFFFFFFFF
const TWO32 := 4294967296.0

static var _buf := _make_buf()

static var S1 := _w(0xBFC55555, 0x55555549)
static var S2 := _w(0x3F811111, 0x1110F8A6)
static var S3 := _w(0xBF2A01A0, 0x19C161D5)
static var S4 := _w(0x3EC71DE3, 0x57B1FE7D)
static var S5 := _w(0xBE5AE5E6, 0x8A2B9CEB)
static var S6 := _w(0x3DE5D93A, 0x5ACFD57C)
static var C1 := _w(0x3FA55555, 0x5555554C)
static var C2 := _w(0xBF56C16C, 0x16C15177)
static var C3 := _w(0x3EFA01A0, 0x19CB1590)
static var C4 := _w(0xBE927E4F, 0x809C52AD)
static var C5 := _w(0x3E21EE9E, 0xBDB4B1C4)
static var C6 := _w(0xBDA8FAE9, 0xBE8838D4)
static var INVPIO2 := _w(0x3FE45F30, 0x6DC9C883)
static var PIO2_1 := _w(0x3FF921FB, 0x54400000)
static var PIO2_1T := _w(0x3DD0B461, 0x1A626331)
static var PIO2_2 := _w(0x3DD0B461, 0x1A600000)
static var PIO2_2T := _w(0x3BA3198A, 0x2E037073)
static var PIO2_3 := _w(0x3BA3198A, 0x2E000000)
static var PIO2_3T := _w(0x397B839A, 0x252049C1)
static var O_THRESHOLD := _w(0x40862E42, 0xFEFA39EF)
static var U_THRESHOLD := _w(0xC0874910, 0xD52D3051)
static var LN2HI := _w(0x3FE62E42, 0xFEE00000)
static var LN2LO := _w(0x3DEA39EF, 0x35793C76)
static var INVLN2 := _w(0x3FF71547, 0x652B82FE)
static var P1 := _w(0x3FC55555, 0x5555553E)
static var P2 := _w(0xBF66C16C, 0x16BEBD93)
static var P3 := _w(0x3F11566A, 0xAF25DE2C)
static var P4 := _w(0xBEBBBD41, 0xC5D26BF1)
static var P5 := _w(0x3E663769, 0x72BEA4D0)
static var E := _w(0x4005BF0A, 0x8B145769)
static var TWO1023 := _w(0x7FE00000, 0x00000000)
static var TWOM1000 := _w(0x01700000, 0x00000000)
static var ATANHI := PackedFloat64Array([
	_w(0x3FDDAC67, 0x0561BB4F), _w(0x3FE921FB, 0x54442D18),
	_w(0x3FEF730B, 0xD281F69B), _w(0x3FF921FB, 0x54442D18)])
static var ATANLO := PackedFloat64Array([
	_w(0x3C7A2B7F, 0x222F65E2), _w(0x3C81A626, 0x33145C07),
	_w(0x3C700788, 0x7AF0CBBD), _w(0x3C91A626, 0x33145C07)])
static var AT := PackedFloat64Array([
	_w(0x3FD55555, 0x5555550D), _w(0xBFC99999, 0x9998EBC4), _w(0x3FC24924, 0x920083FF),
	_w(0xBFBC71C6, 0xFE231671), _w(0x3FB745CD, 0xC54C206E), _w(0xBFB3B0F2, 0xAF749A6D),
	_w(0x3FB10D66, 0xA0D03D51), _w(0xBFADDE2D, 0x52DEFD9A), _w(0x3FA97B4B, 0x24760DEB),
	_w(0xBFA2B444, 0x2C6A6C2F), _w(0x3F90AD3A, 0xE322DA11)])
## Math.PI di JavaScript (coincide con la costante PI di GDScript).
static var JS_PI := _w(0x400921FB, 0x54442D18)
static var PI_O_2 := _w(0x3FF921FB, 0x54442D18)
static var PI_LO := _w(0x3CA1A626, 0x33145C07)
static var NPIO2_HW := PackedInt32Array([
	0x3FF921FB, 0x400921FB, 0x4012D97C, 0x401921FB, 0x401F6A7A, 0x4022D97C,
	0x4025FDBB, 0x402921FB, 0x402C463A, 0x402F6A7A, 0x4031475C, 0x4032D97C,
	0x40346B9C, 0x4035FDBB, 0x40378FDB, 0x403921FB, 0x403AB41B, 0x403C463A,
	0x403DD85A, 0x403F6A7A, 0x40407E4C, 0x4041475C, 0x4042106C, 0x4042D97C,
	0x4043A28C, 0x40446B9C, 0x404534AC, 0x4045FDBB, 0x4046C6CB, 0x40478FDB,
	0x404858EB, 0x404921FB])


static func _make_buf() -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(8)
	return b


## Double dai due word IEEE (alto, basso), come INSERT_WORDS di fdlibm.
static func _w(hi: int, lo: int) -> float:
	var b := PackedByteArray()
	b.resize(8)
	b.encode_u32(0, lo & U32)
	b.encode_u32(4, hi & U32)
	return b.decode_double(0)


## Word alto con segno (GET_HIGH_WORD).
static func high_word(x: float) -> int:
	_buf.encode_double(0, x)
	return _buf.decode_s32(4)


## Word basso senza segno (GET_LOW_WORD).
static func low_word(x: float) -> int:
	_buf.encode_double(0, x)
	return _buf.decode_u32(0)


static func from_words(hi: int, lo: int) -> float:
	_buf.encode_u32(0, lo & U32)
	_buf.encode_u32(4, hi & U32)
	return _buf.decode_double(0)


# ------------------------------------------------------------------ interi JS

## ToInt32 di un intero qualsiasi: `v|0`.
static func i32(v: int) -> int:
	v &= U32
	return v - 0x100000000 if v >= 0x80000000 else v


## ToUint32 di un intero: `v>>>0`.
static func u32(v: int) -> int:
	return v & U32


## `a >>> n` (n in 0..31).
static func ushr(a: int, n: int) -> int:
	return (a & U32) >> n


## Math.imul.
static func imul(a: int, b: int) -> int:
	return i32(i32(a) * i32(b))


## ToInt32 di un double (`x|0`): tronca verso zero, modulo 2^32; NaN/Inf -> 0.
static func f_to_i32(x: float) -> int:
	if is_nan(x) or is_inf(x):
		return 0
	var t := x
	if absf(t) >= 9.0e15:
		t = fmod(t, TWO32)
	return i32(int(t))


# ------------------------------------------------------------------ Math.*

## Math.round di V8: ceil e correzione (pareggi verso +inf, esatto anche per 0.49999999999999994).
static func js_round(x: float) -> float:
	var r := ceilf(x)
	if r - 0.5 > x:
		r -= 1.0
	return r


## Math.round come int.
static func js_round_i(x: float) -> int:
	return int(js_round(x))


## Math.hypot a due argomenti di V8 (math.tq): normalizza sul massimo, poi somma di Kahan.
## Con due termini la compensazione del primo passo e' sempre 0, quindi basta
## sqrt(a'^2 + b'^2) * max.
static func js_hypot(a: float, b: float) -> float:
	a = absf(a)
	b = absf(b)
	if is_inf(a) or is_inf(b):
		return INF
	if is_nan(a) or is_nan(b):
		return NAN
	var m := a if a > b else b
	if m == 0.0:
		return 0.0
	var na := a / m
	var nb := b / m
	return sqrt(na * na + nb * nb) * m


## Math.hypot a tre argomenti di V8: normalizza sul massimo, somma di Kahan.
static func js_hypot3(a: float, b: float, c: float) -> float:
	a = absf(a)
	b = absf(b)
	c = absf(c)
	if is_inf(a) or is_inf(b) or is_inf(c):
		return INF
	if is_nan(a) or is_nan(b) or is_nan(c):
		return NAN
	var m := maxf(a, maxf(b, c))
	if m == 0.0:
		return 0.0
	var sum := 0.0
	var comp := 0.0
	for v in [a, b, c]:
		var n: float = v / m
		var summand := n * n - comp
		var prelim := sum + summand
		comp = (prelim - sum) - summand
		sum = prelim
	return sqrt(sum) * m


static func _kernel_sin(x: float, y: float, iy: int) -> float:
	var ix := high_word(x) & 0x7FFFFFFF
	if ix < 0x3E400000 and int(x) == 0:
		return x
	var z := x * x
	var v := z * x
	var r := S2 + z * (S3 + z * (S4 + z * (S5 + z * S6)))
	if iy == 0:
		return x + v * (S1 + z * r)
	return x - ((z * (0.5 * y - v * r) - y) - v * S1)


static func _kernel_cos(x: float, y: float) -> float:
	var ix := high_word(x) & 0x7FFFFFFF
	if ix < 0x3E400000 and int(x) == 0:
		return 1.0
	var z := x * x
	var r := z * (C1 + z * (C2 + z * (C3 + z * (C4 + z * (C5 + z * C6)))))
	if ix < 0x3FD33333:
		return 1.0 - (0.5 * z - (z * r - x * y))
	var qx := 0.28125
	if ix <= 0x3FE90000:
		qx = from_words(ix - 0x00200000, 0)
	var iz := 0.5 * z - qx
	var a := 1.0 - qx
	return a - (iz - (z * r - x * y))


## __ieee754_rem_pio2 (percorsi piccolo e medio, |x| <= 2^19*pi/2). Scrive y0, y1 in `out`
## e restituisce n. Per |x| maggiori (mai usati dal generatore) ripiega su fmod,
## documentato come non bit-esatto.
static func _rem_pio2(x: float, out: PackedFloat64Array) -> int:
	var hx := high_word(x)
	var ix := hx & 0x7FFFFFFF
	var z := 0.0
	if ix <= 0x3FE921FB:
		out[0] = x
		out[1] = 0.0
		return 0
	if ix < 0x4002D97C:
		if hx > 0:
			z = x - PIO2_1
			if ix != 0x3FF921FB:
				out[0] = z - PIO2_1T
				out[1] = (z - out[0]) - PIO2_1T
			else:
				z -= PIO2_2
				out[0] = z - PIO2_2T
				out[1] = (z - out[0]) - PIO2_2T
			return 1
		z = x + PIO2_1
		if ix != 0x3FF921FB:
			out[0] = z + PIO2_1T
			out[1] = (z - out[0]) + PIO2_1T
		else:
			z += PIO2_2
			out[0] = z + PIO2_2T
			out[1] = (z - out[0]) + PIO2_2T
		return -1
	if ix <= 0x413921FB:
		var t := absf(x)
		var n := int(t * INVPIO2 + 0.5)
		var fn := float(n)
		var r := t - fn * PIO2_1
		var w := fn * PIO2_1T
		if n < 32 and ix != NPIO2_HW[n - 1]:
			out[0] = r - w
		else:
			var j := ix >> 20
			out[0] = r - w
			var i := j - ((high_word(out[0]) >> 20) & 0x7FF)
			if i > 16:
				t = r
				w = fn * PIO2_2
				r = t - w
				w = fn * PIO2_2T - ((t - r) - w)
				out[0] = r - w
				i = j - ((high_word(out[0]) >> 20) & 0x7FF)
				if i > 49:
					t = r
					w = fn * PIO2_3
					r = t - w
					w = fn * PIO2_3T - ((t - r) - w)
					out[0] = r - w
		out[1] = (r - out[0]) - w
		if hx < 0:
			out[0] = -out[0]
			out[1] = -out[1]
			return -n
		return n
	# Argomenti enormi: fuori dal dominio del prototipo.
	var q := floorf(x / (JS_PI * 0.5) + 0.5)
	out[0] = x - q * (JS_PI * 0.5)
	out[1] = 0.0
	return int(fmod(q, 4.0))


## Math.sin di V8 (fdlibm).
static func js_sin(x: float) -> float:
	var ix := high_word(x) & 0x7FFFFFFF
	if ix <= 0x3FE921FB:
		return _kernel_sin(x, 0.0, 0)
	if ix >= 0x7FF00000:
		return x - x
	var y := PackedFloat64Array([0.0, 0.0])
	var n := _rem_pio2(x, y)
	match n & 3:
		0:
			return _kernel_sin(y[0], y[1], 1)
		1:
			return _kernel_cos(y[0], y[1])
		2:
			return -_kernel_sin(y[0], y[1], 1)
		_:
			return -_kernel_cos(y[0], y[1])


## Math.cos di V8 (fdlibm).
static func js_cos(x: float) -> float:
	var ix := high_word(x) & 0x7FFFFFFF
	if ix <= 0x3FE921FB:
		return _kernel_cos(x, 0.0)
	if ix >= 0x7FF00000:
		return x - x
	var y := PackedFloat64Array([0.0, 0.0])
	var n := _rem_pio2(x, y)
	match n & 3:
		0:
			return _kernel_cos(y[0], y[1])
		1:
			return -_kernel_sin(y[0], y[1], 1)
		2:
			return -_kernel_cos(y[0], y[1])
		_:
			return _kernel_sin(y[0], y[1], 1)


## Math.exp di V8 (fdlibm e_exp.c).
static func js_exp(x: float) -> float:
	var hi := 0.0
	var lo := 0.0
	var k := 0
	var hx := high_word(x) & U32
	var xsb := (hx >> 31) & 1
	hx &= 0x7FFFFFFF
	if hx >= 0x40862E42:
		if hx >= 0x7FF00000:
			if ((hx & 0xFFFFF) | low_word(x)) != 0:
				return x + x
			return x if xsb == 0 else 0.0
		if x > O_THRESHOLD:
			return INF
		if x < U_THRESHOLD:
			return 0.0
	if hx > 0x3FD62E42:
		if hx < 0x3FF0A2B2:
			if x == 1.0:
				return E
			hi = x - (LN2HI if xsb == 0 else -LN2HI)
			lo = LN2LO if xsb == 0 else -LN2LO
			k = 1 - xsb - xsb
		else:
			k = int(INVLN2 * x + (0.5 if xsb == 0 else -0.5))
			var tk := float(k)
			hi = x - tk * LN2HI
			lo = tk * LN2LO
		x = hi - lo
	elif hx < 0x3E300000:
		return 1.0 + x
	else:
		k = 0
	var t := x * x
	var twopk := 0.0
	if k >= -1021:
		twopk = from_words(0x3FF00000 + (k << 20), 0)
	else:
		twopk = from_words(0x3FF00000 + ((k + 1000) << 20), 0)
	var c := x - t * (P1 + t * (P2 + t * (P3 + t * (P4 + t * P5))))
	if k == 0:
		return 1.0 - ((x * c) / (c - 2.0) - x)
	var y := 1.0 - ((lo - (x * c) / (2.0 - c)) - hi)
	if k >= -1021:
		if k == 1024:
			return y * 2.0 * TWO1023
		return y * twopk
	return y * twopk * TWOM1000


## Math.atan di V8 (fdlibm s_atan.c).
static func js_atan(x: float) -> float:
	var hx := high_word(x)
	var ix := hx & 0x7FFFFFFF
	var id := -1
	if ix >= 0x44100000:
		if is_nan(x):
			return x + x
		return ATANHI[3] + ATANLO[3] if hx > 0 else -ATANHI[3] - ATANLO[3]
	if ix < 0x3FDC0000:
		if ix < 0x3E400000:
			return x
		id = -1
	else:
		x = absf(x)
		if ix < 0x3FF30000:
			if ix < 0x3FE60000:
				id = 0
				x = (2.0 * x - 1.0) / (2.0 + x)
			else:
				id = 1
				x = (x - 1.0) / (x + 1.0)
		elif ix < 0x40038000:
			id = 2
			x = (x - 1.5) / (1.0 + 1.5 * x)
		else:
			id = 3
			x = -1.0 / x
	var z := x * x
	var w := z * z
	var s1 := z * (AT[0] + w * (AT[2] + w * (AT[4] + w * (AT[6] + w * (AT[8] + w * AT[10])))))
	var s2 := w * (AT[1] + w * (AT[3] + w * (AT[5] + w * (AT[7] + w * AT[9]))))
	if id < 0:
		return x - x * (s1 + s2)
	z = ATANHI[id] - ((x * (s1 + s2) - ATANLO[id]) - x)
	return -z if hx < 0 else z


## Math.atan2 di V8 (fdlibm e_atan2.c).
static func js_atan2(y: float, x: float) -> float:
	if is_nan(x) or is_nan(y):
		return x + y
	var hx := high_word(x)
	var lx := low_word(x)
	var ix := hx & 0x7FFFFFFF
	var hy := high_word(y)
	var ly := low_word(y)
	var iy := hy & 0x7FFFFFFF
	if x == 1.0:
		return js_atan(y)
	var m := ((hy >> 31) & 1) | ((hx >> 30) & 2)
	if (iy | ly) == 0:
		match m:
			0, 1:
				return y
			2:
				return JS_PI
			_:
				return -JS_PI
	if (ix | lx) == 0:
		return -PI_O_2 if hy < 0 else PI_O_2
	if ix == 0x7FF00000:
		if iy == 0x7FF00000:
			var q := [PI_O_2 * 0.5, -PI_O_2 * 0.5, 3.0 * PI_O_2 * 0.5, -3.0 * PI_O_2 * 0.5]
			return float(q[m])
		var r := [0.0, -0.0, JS_PI, -JS_PI]
		return float(r[m])
	if iy == 0x7FF00000:
		return -PI_O_2 if hy < 0 else PI_O_2
	var k := (iy - ix) >> 20
	var z := 0.0
	if k > 60:
		z = PI_O_2 + 0.5 * PI_LO
		m &= 1
	elif hx < 0 and k < -60:
		z = 0.0
	else:
		z = js_atan(absf(y / x))
	match m:
		0:
			return z
		1:
			return -z
		2:
			return JS_PI - (z - PI_LO)
		_:
			return (z - PI_LO) - JS_PI
