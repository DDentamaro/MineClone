class_name DayCycle
extends Node
## Ciclo giorno/notte: porting di skyState (HTML ~5681). Aggiorna i parametri
## globali degli shader e orienta la luce direzionale (sole o luna).
## Giornata di 240 s, ora iniziale 0,35 (8:24) come il prototipo.

const DAY_LEN := 240.0
const DAY := {"sun_intensity": 0.95, "sun_color": Vector3(1.00, 0.94, 0.84), "ambient_level": 0.40,
	"ambient_tint": Vector3(0.80, 0.89, 1.00), "horizon": Vector3(0.61, 0.49, 0.44), "top": Vector3(0.30, 0.42, 0.61)}
const DUSK := {"sun_intensity": 0.74, "sun_color": Vector3(1.00, 0.50, 0.27), "ambient_level": 0.29,
	"ambient_tint": Vector3(0.60, 0.70, 1.00), "horizon": Vector3(0.72, 0.45, 0.40), "top": Vector3(0.13, 0.16, 0.31)}
const NIGHT := {"moon_yaw_deg": 38.0, "moon_pitch_deg": 52.0, "moon_intensity": 0.62, "moon_color": Vector3(0.55, 0.66, 0.98),
	"ambient_level": 0.36, "ambient_tint": Vector3(0.46, 0.56, 0.90), "horizon": Vector3(0.10, 0.11, 0.18), "top": Vector3(0.04, 0.05, 0.11)}
const SHADOW_STRENGTH := 0.84
const CLOUD_COVER := 0.73

## Ora del giorno 0..1.
@export var time := 0.35
@export var paused := false
@export var light: DirectionalLight3D

## Interruttore OMBRE del prototipo (SHADOW.strength 0,84 / 0).
var shadows_on := true
## Vero in terza persona: orizzonte e sole li calcola la camera.
var tps_sky := false
var state := {}
var clock := 0.0


func _ready() -> void:
	RenderingServer.global_shader_parameter_set(&"cloud_cover", CLOUD_COVER)
	RenderingServer.global_shader_parameter_set(&"cloud_shadow_on", 1.0)
	RenderingServer.global_shader_parameter_set(&"paint_mode", 1.0)
	apply(0.0)


func _process(dt: float) -> void:
	apply(dt)


func apply(dt: float) -> void:
	clock += dt
	if not paused:
		time = fmod(time + dt / DAY_LEN, 1.0)
	state = sky_state(time)
	var rs := RenderingServer
	rs.global_shader_parameter_set(&"world_time", clock)
	rs.global_shader_parameter_set(&"sun_dir", state["dir"])
	rs.global_shader_parameter_set(&"sun_color", state["light_color"])
	rs.global_shader_parameter_set(&"sun_intensity", state["intensity"])
	rs.global_shader_parameter_set(&"ambient_color", state["ambient"])
	rs.global_shader_parameter_set(&"night", state["night"])
	rs.global_shader_parameter_set(&"sun_level", maxf(0.05, state["daylight"]))
	rs.global_shader_parameter_set(&"shadow_strength", state["shadow"] if shadows_on else 0.0)
	if light != null:
		light.shadow_enabled = shadows_on
	rs.global_shader_parameter_set(&"sky_horizon", state["horizon"])
	rs.global_shader_parameter_set(&"sky_top", state["top"])
	rs.global_shader_parameter_set(&"fog_color", state["horizon"])
	rs.global_shader_parameter_set(&"sky_tint", (state["horizon"] as Vector3) * 0.5 + (state["top"] as Vector3) * 0.5)
	# In terza persona il sole lo proietta la camera (CameraRig._tps_sky).
	if not tps_sky:
		rs.global_shader_parameter_set(&"sun_uv", state["sun_uv"])
	rs.global_shader_parameter_set(&"sun_elev", state["elev"])
	var dk: float = state["dusk"] * state["daylight"]
	rs.global_shader_parameter_set(&"sun_vis", 0.10 * state["daylight"] * (1.0 - state["dusk"] * 0.5))
	rs.global_shader_parameter_set(&"grade_s", Vector3(lerpf(1.0, 0.90, dk), lerpf(1.0, 0.84, dk), lerpf(1.03, 1.12, dk)))
	rs.global_shader_parameter_set(&"grade_h", Vector3(lerpf(1.03, 1.15, dk), lerpf(1.01, 0.98, dk), lerpf(0.97, 0.80, dk)))
	if light != null:
		var dir: Vector3 = state["dir"]
		var up := Vector3.RIGHT if absf(dir.y) > 0.99 else Vector3.UP
		light.global_transform.basis = Basis.looking_at(-dir, up)


static func _mix(a: Vector3, b: Vector3, t: float) -> Vector3:
	return a + (b - a) * t


static func sky_state(t: float) -> Dictionary:
	var h := t * 24.0
	var day := h >= 6.0 and h <= 18.0
	var u := (h - 6.0) / 12.0
	var elev := sin(PI * clampf(u, 0.0, 1.0))
	var sun_yaw := deg_to_rad(-90.0 + u * 180.0)
	var sun_pitch := maxf(0.06, elev) * PI / 2.0 * 0.82
	var dusk := 1.0 - minf(1.0, elev / 0.35)
	var daylight := minf(1.0, elev / 0.10) if day else 0.0
	var sd := Vector3(sin(sun_yaw) * cos(sun_pitch), sin(sun_pitch), cos(sun_yaw) * cos(sun_pitch)).normalized()
	var my := deg_to_rad(NIGHT["moon_yaw_deg"])
	var mp := deg_to_rad(NIGHT["moon_pitch_deg"])
	var md := Vector3(sin(my) * cos(mp), sin(mp), cos(my) * cos(mp)).normalized()
	var night := 1.0 - daylight
	var sun_color := _mix(DAY["sun_color"], DUSK["sun_color"], dusk)
	var amb := _mix(DAY["ambient_tint"] * DAY["ambient_level"], DUSK["ambient_tint"] * DUSK["ambient_level"], dusk)
	var amb_n: Vector3 = NIGHT["ambient_tint"] * NIGHT["ambient_level"]
	var is_sun := day and daylight > 0.02
	var intensity: float = NIGHT["moon_intensity"]
	if day:
		intensity = (DAY["sun_intensity"] * (1.0 - dusk) + DUSK["sun_intensity"] * dusk) * maxf(daylight, 0.35) + NIGHT["moon_intensity"] * (1.0 - daylight)
	return {
		"daylight": daylight, "night": night, "elev": elev if day else -1.0,
		"dir": sd if is_sun else md, "is_moon": not is_sun,
		"light_color": _mix(NIGHT["moon_color"], sun_color, daylight) if day else NIGHT["moon_color"],
		"intensity": intensity,
		"ambient": _mix(amb_n, amb, daylight),
		"horizon": _mix(NIGHT["horizon"], _mix(DAY["horizon"], DUSK["horizon"], dusk), daylight),
		"top": _mix(NIGHT["top"], _mix(DAY["top"], DUSK["top"], dusk), daylight),
		"shadow": SHADOW_STRENGTH * daylight if day else SHADOW_STRENGTH * 0.5,
		"sun_uv": Vector2(0.5 + 0.42 * cos(PI * (1.0 - u)), 0.35 + 0.6 * maxf(0.0, elev)),
		"dusk": dusk,
	}
