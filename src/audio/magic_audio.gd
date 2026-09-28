class_name MagicAudio
extends Node
## Audio della magia sintetizzato (HTML 8304–8313, voci RMNDWN): nessun campione.
## - impatto: onda triangolare in glissando f0 -> f1 + rumore passa-banda, decadimento
##   esponenziale; la terra aggiunge un rombo sinusoidale 34 -> 22 Hz;
## - rilascio: soffio di rumore passa-banda che scende (2600 -> 600, terra 300 -> 90);
## - raccolta: rumore passa-banda che sale durante cast_dur, poi resta finche' si tiene.
## I suoni si generano una volta, su un thread, come AudioStreamWAV.

const RATE := 22050
const VOICE := {
	"fire": {"f0": 140.0, "f1": 92.0, "band": 2400.0, "q": .45, "dur": .16},
	"water": {"f0": 96.0, "f1": 52.0, "band": 900.0, "q": .5, "dur": .22},
	"air": {"f0": 130.0, "f1": 110.0, "band": 3000.0, "q": .3, "dur": .12},
	"earth": {"f0": 64.0, "f1": 38.0, "band": 420.0, "q": .9, "dur": .30, "rumble": true},
	"karma": {"f0": 240.0, "f1": 170.0, "band": 3800.0, "q": .7, "dur": .13},
}
const GATHER := {"fire": [700.0, 2200.0, 1.2], "water": [500.0, 1400.0, 1.2], "air": [1800.0, 3600.0, 1.2], "earth": [120.0, 260.0, 2.0], "karma": [900.0, 2800.0, 1.6]}

var _impacts := {}
var _releases := {}
var _gathers := {}
var _task := -1
var _players: Array[AudioStreamPlayer] = []
var _gather_player: AudioStreamPlayer
var _gather_fade := 0.0


func _ready() -> void:
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_gather_player = AudioStreamPlayer.new()
	add_child(_gather_player)
	_task = WorkerThreadPool.add_task(_build_all)


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func ready_to_play() -> bool:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	return _task < 0 and not _impacts.is_empty()


func _build_all() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var imp := {}
	var rel := {}
	var gat := {}
	for el: String in VOICE:
		var list := []
		for v in 3:
			list.append(to_wav(impact_samples(el, rng.randf_range(0.9, 1.1), rng)))
		imp[el] = list
		rel[el] = to_wav(release_samples(el, rng))
		var s: SpellDefinition = null
		for sd in SpellDefinition.all():
			if sd.el == el:
				s = sd
		gat[el] = to_wav(gather_samples(el, s.cast_dur, rng))
	_impacts = imp
	_releases = rel
	_gathers = gat


## Filtro passa-banda (RBJ, guadagno di picco 0 dB) con frequenza variabile.
class Bandpass:
	extends RefCounted
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0

	func process(x: float, f: float, q: float) -> float:
		var w0 := TAU * f / RATE
		var alpha := sin(w0) / (2.0 * q)
		var a0 := 1.0 + alpha
		var y := (alpha * x - alpha * x2 + 2.0 * cos(w0) * y1 - (1.0 - alpha) * y2) / a0
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		return y


static func _exp_ramp(a: float, b: float, u: float) -> float:
	return a * pow(b / a, clampf(u, 0.0, 1.0))


static func impact_samples(el: String, pv: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var V: Dictionary = VOICE[el]
	var dur: float = V["dur"]
	var rumble := V.has("rumble")
	var total := dur * (1.4 if rumble else 1.0)
	var n := int(total * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var bp := Bandpass.new()
	var ph := 0.0
	var rph := 0.0
	for i in n:
		var t := float(i) / RATE
		var u := t / dur
		var s := 0.0
		if u < 1.0:
			var g := _exp_ramp(0.14, 0.001, u)
			var f := _exp_ramp(float(V["f0"]) * pv, float(V["f1"]) * pv, u)
			ph = fmod(ph + f / RATE, 1.0)
			var tri := 4.0 * absf(ph - 0.5) - 1.0
			var nz := bp.process(rng.randf_range(-1.0, 1.0), float(V["band"]), float(V["q"]))
			s += (tri + nz) * g
		if rumble:
			var ur := t / (dur * 1.4)
			var fr := _exp_ramp(34.0, 22.0, ur)
			rph = fmod(rph + fr / RATE, 1.0)
			s += sin(rph * TAU) * _exp_ramp(0.18, 0.001, ur)
		out[i] = s
	return out


static func release_samples(el: String, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(0.25 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var bp := Bandpass.new()
	var f0 := 300.0 if el == "earth" else 2600.0
	var f1 := 90.0 if el == "earth" else 600.0
	for i in n:
		var u := float(i) / RATE / 0.22
		out[i] = bp.process(rng.randf_range(-1.0, 1.0), _exp_ramp(f0, f1, u), 1.5) * _exp_ramp(0.09, 0.001, u)
	return out


static func gather_samples(el: String, cast_dur: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var g: Array = GATHER[el]
	var n := int((cast_dur + 1.8) * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var bp := Bandpass.new()
	for i in n:
		var u := float(i) / RATE / cast_dur
		out[i] = bp.process(rng.randf_range(-1.0, 1.0), _exp_ramp(float(g[0]), float(g[1]), u), float(g[2])) * _exp_ramp(0.001, 0.06, u)
	return out


static func to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, clampi(int(samples[i] * 32767.0 * 1.6), -32768, 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


func _play(stream: AudioStreamWAV, gain_db: float = 0.0) -> void:
	for p in _players:
		if not p.playing:
			p.stream = stream
			p.volume_db = gain_db
			p.play()
			return


## Suoni degli eventi della magia (chiamato con la lista degli eventi del frame).
func handle(events: Array[Dictionary], rng_index: int) -> void:
	if not ready_to_play():
		return
	for e in events:
		match String(e["type"]):
			"impact":
				var list: Array = _impacts[e["el"]]
				_play(list[rng_index % list.size()])
			"burst":
				if e["el"] == "earth":
					var list: Array = _impacts["earth"]
					_play(list[rng_index % list.size()], -6.0)
			"release", "beam", "close":
				stop_gather()
				_play(_releases[e["el"]], -3.0 if e["type"] == "close" else 0.0)
			"area", "burst_ring":
				var list: Array = _impacts[e["el"]]
				_play(list[rng_index % list.size()], -2.0)
			"struct", "crumble":
				var list: Array = _impacts["earth"]
				_play(list[rng_index % list.size()], -4.0)
			"gather":
				_gather_player.stream = _gathers[e["el"]]
				_gather_player.volume_db = 0.0
				_gather_fade = 0.0
				_gather_player.play()
			"cancel":
				stop_gather()


func stop_gather() -> void:
	if _gather_player.playing:
		_gather_fade = 0.08


func _process(dt: float) -> void:
	if _gather_fade > 0.0:
		_gather_fade -= dt
		_gather_player.volume_db = linear_to_db(maxf(0.001, _gather_fade / 0.08))
		if _gather_fade <= 0.0:
			_gather_player.stop()
