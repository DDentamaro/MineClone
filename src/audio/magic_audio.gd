class_name MagicAudio
extends Node
## Audio della magia sintetizzato, nessun campione. Magie del libro come RMNDWN
## (playCombatHitSfx L18132–L18151, D-031): solo il suono dell'impatto su un
## corpo, niente raccolta ne' rilascio. Voce per materiale (IMPACT_VOICE):
## triangolo in glissando f0 -> f1 (colpo pesante piu' grave e lungo), rumore
## bianco passa-banda a parte; il Karma aggiunge uno zap a dente di sega
## 1400 -> 380 Hz, la terra un rombo sinusoidale 34 -> 22 Hz. L'altezza segue
## `juice.sfx` della magia (pitch), il volume la famiglia e la distanza; il
## refrattario dei colpi (.16 s, sostenuti .22 s) tace i colpi ravvicinati.
## I dardi del prototipo IsoTerra suonano all'impatto come prima.
## I suoni si generano una volta, su un thread, come AudioStreamWAV.

const RATE := 22050
## [f0, f1, f0 pesante, f1 pesante, durata, durata pesante, banda, banda pesante, Q].
const VOICE := {
	"karma": [150.0, 64.0, 120.0, 48.0, .09, .14, 1900.0, 1500.0, 1.1],
	"fire": [140.0, 92.0, 110.0, 70.0, .08, .12, 2400.0, 1900.0, .45],
	"water": [96.0, 52.0, 74.0, 40.0, .13, .20, 900.0, 700.0, .5],
	"air": [130.0, 110.0, 110.0, 90.0, .08, .12, 3000.0, 2600.0, .3],
	"earth": [64.0, 38.0, 52.0, 30.0, .18, .26, 420.0, 330.0, .9],
}

## el -> [leggeri(3), pesanti(3)]
var _impacts := {}
var _task := -1
var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
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
	for el: String in VOICE:
		var light := []
		var heavy := []
		for v in 3:
			light.append(to_wav(impact_samples(el, rng.randf_range(0.9, 1.1), rng, false)))
			heavy.append(to_wav(impact_samples(el, rng.randf_range(0.9, 1.1), rng, true)))
		imp[el] = [light, heavy]
	_impacts = imp


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


## Durata della voce (s).
static func voice_dur(el: String, heavy: bool) -> float:
	var V: Array = VOICE.get(el, VOICE["karma"])
	return float(V[5] if heavy else V[4])


## Colpo su un corpo: `pv` = variazione d'altezza (.9–1,1).
static func impact_samples(el: String, pv: float, rng: RandomNumberGenerator, heavy: bool = false) -> PackedFloat32Array:
	var V: Array = VOICE.get(el, VOICE["karma"])
	var d := float(V[5] if heavy else V[4])
	var f0 := float(V[2] if heavy else V[0]) * pv
	var f1 := float(V[3] if heavy else V[1]) * pv
	var band := float(V[7] if heavy else V[6]) * pv
	var q := float(V[8])
	var master := 0.18 if heavy else 0.12
	var thud := 0.35 if el == "air" else 1.0
	var nz_g := 0.10 if heavy else 0.075
	var nz_d := 0.09 if heavy else 0.065
	var total := maxf(d, 0.12)
	if el == "earth":
		total = d * 1.8
	var n := int(total * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var bp := Bandpass.new()
	var ph := 0.0
	var zph := 0.0
	var rph := 0.0
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		if t < d:
			var g := _exp_ramp(master, 0.001, t / d)
			var f := _exp_ramp(f0, f1, t / (0.9 * d))
			ph = fmod(ph + f / RATE, 1.0)
			s += (4.0 * absf(ph - 0.5) - 1.0) * g * thud
		# Rumore bianco (.12 s con dissolvenza lineare) passa-banda, a parte.
		if t < 0.12:
			var white := rng.randf_range(-1.0, 1.0) * (1.0 - t / 0.12)
			s += bp.process(white, band, q) * _exp_ramp(nz_g, 0.001, t / nz_d)
		if el == "karma" and t < 0.07:
			var fz := _exp_ramp(1400.0 * pv, 380.0 * pv, t / 0.06)
			zph = fmod(zph + fz / RATE, 1.0)
			s += (2.0 * zph - 1.0) * _exp_ramp(0.16, 0.001, t / 0.07) * master
		if el == "earth":
			var fr := _exp_ramp(34.0 * pv, 22.0 * pv, t / (1.6 * d))
			rph = fmod(rph + fr / RATE, 1.0)
			s += sin(rph * TAU) * _exp_ramp(0.55, 0.001, t / (1.8 * d)) * master
		out[i] = s
	return out


static func to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, clampi(int(samples[i] * 32767.0 * 2.4), -32768, 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


func _play(stream: AudioStreamWAV, gain: float = 1.0, pitch: float = 1.0) -> void:
	for p in _players:
		if not p.playing:
			p.stream = stream
			p.volume_db = linear_to_db(maxf(gain, 0.001))
			p.pitch_scale = pitch
			p.play()
			return


## Suoni degli eventi della magia (chiamato con la lista degli eventi del frame).
func handle(events: Array[Dictionary], rng_index: int) -> void:
	if not ready_to_play():
		return
	for e in events:
		match String(e["type"]):
			"hit":
				# Solo i colpi con la scossa (fuori dal refrattario) suonano.
				var S: SpellDefinition = e["spell"]
				if S.is_legacy() or not e.get("juice", false):
					continue
				var fam := 0.55 if e.get("quiet", false) else 0.85
				var list: Array = _impacts[S.el][1 if S.heavy else 0]
				_play(list[rng_index % list.size()], fam * float(e.get("near", 1.0)), S.sfx)
			"impact":
				var S2: SpellDefinition = e["spell"]
				if S2.is_legacy():
					var list: Array = _impacts[S2.el][0]
					_play(list[rng_index % list.size()])
