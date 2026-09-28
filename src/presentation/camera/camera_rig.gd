class_name CameraRig
extends Node3D
## Camera del gioco (D-010): isometrica ortografica come modalita' principale,
## terza persona prospettica come opzione. Parametri dal View del prototipo
## (righe 6724, 6776–6786) e da RMD_PIX_ISO (riga 4238).

enum Mode { ISO, TPS }

# --- isometrica: yaw 45°, pitch 38° (22..62), zoom 0,55..2,4
const ISO_YAW := PI / 4.0
const ISO_PITCH := deg_to_rad(38.0)
const ISO_PITCH_MIN := deg_to_rad(22.0)
const ISO_PITCH_MAX := deg_to_rad(62.0)
const ISO_ZOOM_MIN := 0.55
const ISO_ZOOM_MAX := 2.4
## Il prototipo usa 120; qui 70 basta a stare sopra il mondo alto 48 e tiene
## piu' stretta la distanza massima dell'ombra direzionale di Godot.
const CAM_DIST := 70.0
## Semi-altezza ortografica a zoom 1: RT_H / (2 * PX_PER_UNIT) con RT_H = 360,
## TILE_W = 32 * 360 / 270, PX_PER_UNIT = TILE_W / sqrt(2).
const ISO_HALF_H := 360.0 / (2.0 * (32.0 * 360.0 / 270.0) / sqrt(2.0))

# --- terza persona: FOV 52°, distanza 6,5, pitch -0,22..1,42, zoom 0,28..3,4
const TPS_FOV := 52.0
const TPS_DIST := 6.5
const TPS_PITCH := 0.35
const TPS_PITCH_MIN := -0.22
const TPS_PITCH_MAX := 1.42
const TPS_ZOOM_MIN := 0.28
const TPS_ZOOM_MAX := 3.4

## Sensibilita' del trascinamento (prototipo: dyaw = -dx*0,006, dpitch = dy*0,004).
const DRAG_YAW := 0.006
const DRAG_PITCH := 0.004
## Il punto guardato e' sopra i piedi del giocatore.
const LOOK_OFFSET := Vector3(0, 0.7, 0)

var mode: Mode = Mode.ISO
var yaw := ISO_YAW
var yaw_target := ISO_YAW
var pitch := ISO_PITCH
var pitch_target := ISO_PITCH
var zoom := 1.0
var zoom_target := 1.0
var tps_pitch := TPS_PITCH
var tps_zoom := 1.0
var world: WorldData
var opaque := PackedByteArray()
## Pixel del render target di bordo attorno all'area visibile (per lo
## spostamento sub-pixel dell'immagine).
var border_px := 1
## Resto sub-pixel dell'aggancio alla griglia (pixel del render target, x a
## destra e y in alto): chi mostra l'immagine la sposta di questo resto.
var subpixel := Vector2.ZERO
var pixel_snap := true
## Scossa dei colpi (unita' di mondo circa), smorzata in pochi decimi di secondo.
var shake_amt := 0.0
var _shake_t := 0.0
## Scossa direzionale delle magie (RMNDWN cameraState L36278–L36315): angoli
## sull'orbita lungo l'asse del colpo e calcio del campo visivo in gradi.
var _ss := {}
var _sh_y := 0.0
var _sh_p := 0.0
var _fov_kick := 0.0

# --- terza persona adattiva (frameTPS del prototipo, HTML 6859–6888)
## Situazione riempita dal gioco: velocita', direzione dell'eroe, "coperto"
## (soffitto sopra la testa) e punto del bersaglio agganciato (o null).
var tps_ctx := {}
## Segue da sola le spalle dell'eroe (e il bersaglio agganciato).
var tps_auto := true
## Inclinazione scelta dall'utente trascinando (NAN finche' non la tocca).
var tps_user_pitch := NAN
var tps_dist := TPS_DIST
var tps_fov := TPS_FOV
var tree_grid := {}
## Sole proiettato dalla camera in terza persona (coordinate schermo 0..1, y in alto).
var tps_sun_uv := Vector2(-2, -2)
## Preferenze cambiate da salvare (le salva il GameRoot, non a ogni evento).
var prefs_dirty := false
## Direzione del sole (la imposta il gioco dal ciclo del giorno).
var sun_dir := Vector3(-0.3, 0.93, 0.22)
var _tps_zoom_cur := 1.0
var _tps_esc := 0.0
var _last_spin := -9.0

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	_apply_projection()


func set_mode(m: Mode) -> void:
	mode = m
	_apply_projection()


func toggle_mode() -> void:
	set_mode(Mode.TPS if mode == Mode.ISO else Mode.ISO)


func spin(dyaw: float, dpitch: float) -> void:
	_last_spin = _now()
	yaw_target += dyaw
	if mode == Mode.TPS:
		if dpitch != 0.0:
			var base := tps_pitch if is_nan(tps_user_pitch) else tps_user_pitch
			tps_user_pitch = clampf(base + dpitch, TPS_PITCH_MIN, TPS_PITCH_MAX)
			prefs_dirty = true
	else:
		pitch_target = clampf(pitch_target + dpitch, ISO_PITCH_MIN, ISO_PITCH_MAX)


## Rotazione a scatti (tasti Q/E): 90° in isometrica, 45° in terza persona.
func rotate_step(step: int) -> void:
	_last_spin = _now()
	yaw_target += step * (PI / 4.0 if mode == Mode.TPS else PI / 2.0)


func drag(delta_px: Vector2) -> void:
	spin(-delta_px.x * DRAG_YAW, delta_px.y * DRAG_PITCH)


func shake(amount: float) -> void:
	shake_amt = maxf(shake_amt, amount)


## `amp` in radianti (juice.shake × famiglia × vicinanza × grammatica), `axis`
## nel mondo (spinta o direzione del colpo), `down` = asse verso il basso (terra).
## Una nuova scossa sostituisce la corrente solo se piu' forte.
func spell_shake(amp: float, axis: Vector3, dur: float, freq: float, fov_deg: float, down: bool = false) -> void:
	if amp <= 0.0:
		return
	if not _ss.is_empty() and float(_ss["amp"]) * _ss_k(float(_ss["t"]), float(_ss["dur"])) > amp:
		return
	var dir := view_dir()
	var basis := Basis.looking_at(-dir, Vector3.UP)
	var fl := Vector3(-dir.x, 0, -dir.z).normalized()
	var ax := axis.normalized() if axis.length() > 1e-4 else fl
	var side := ax.dot(basis.x)
	var fwd := ax.dot(fl)
	var dy := side
	var dp := -ax.y * 0.6 + fwd * 0.22
	if down:
		dy = side * 0.35
		dp = -(0.85 + 0.15 * absf(fwd))
	var l := Vector2(dy, dp).length()
	if l < 1e-4:
		dy = 0.0
		dp = -1.0
		l = 1.0
	_ss = {"amp": amp, "dy": dy / l, "dp": dp / l, "dur": dur, "freq": freq, "t": 0.0, "ph": randf() * TAU, "fov": fov_deg}


static func _ss_k(t: float, dur: float) -> float:
	return exp(-t * 26.0 / maxf(0.35, dur / 0.14))


func _step_spell_shake(dt: float) -> void:
	_sh_y = 0.0
	_sh_p = 0.0
	_fov_kick = 0.0
	if _ss.is_empty():
		return
	var t := float(_ss["t"]) + dt
	_ss["t"] = t
	var dur := float(_ss["dur"])
	var k := _ss_k(t, dur)
	if k < 0.01 and t > dur:
		_ss = {}
		return
	var w := float(_ss["freq"]) * 38.0
	var along := cos(t * w) * k
	var cross := sin(float(_ss["ph"]) + 1.9 * t * w) * k * 0.22
	var amp := float(_ss["amp"]) * 2.2
	_sh_y = (float(_ss["dy"]) * along - float(_ss["dp"]) * cross) * amp
	_sh_p = (float(_ss["dp"]) * along + float(_ss["dy"]) * cross) * amp
	var u := clampf(t / maxf(dur, 1e-3), 0.0, 1.0)
	_fov_kick = float(_ss["fov"]) * (1.0 - u) * (1.0 - u)


func get_zoom() -> float:
	return tps_zoom if mode == Mode.TPS else zoom_target


func set_zoom(z: float) -> void:
	if mode == Mode.TPS:
		tps_zoom = clampf(z, TPS_ZOOM_MIN, TPS_ZOOM_MAX)
		prefs_dirty = true
	else:
		zoom_target = clampf(z, ISO_ZOOM_MIN, ISO_ZOOM_MAX)


## Direzione dal punto guardato verso la camera.
func view_dir() -> Vector3:
	var p := (tps_pitch if mode == Mode.TPS else pitch) + _sh_p
	var y := yaw + _sh_y
	return Vector3(cos(p) * sin(y), sin(p), cos(p) * cos(y)).normalized()


## Base orizzontale della camera per l'input relativo (groundBasis del prototipo).
func ground_right() -> Vector3:
	return Vector3(cos(yaw), 0, -sin(yaw))


func ground_forward() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))


## Converte lo stick (x destra, y avanti) in direzione nel piano XZ del mondo.
func stick_to_world(stick: Vector2) -> Vector2:
	var w := ground_right() * stick.x + ground_forward() * stick.y
	return Vector2(w.x, w.z)


func update_camera(dt: float, target: Vector3) -> void:
	var k := 1.0 - exp(-dt * 9.0)
	yaw += (yaw_target - yaw) * k
	pitch += (pitch_target - pitch) * k
	zoom += (zoom_target - zoom) * k
	_step_spell_shake(dt)
	var look := target + LOOK_OFFSET
	var dir := view_dir()
	if shake_amt > 0.002:
		_shake_t += dt
		var sb := Basis.looking_at(-dir, Vector3.UP)
		look += (sb.x * sin(_shake_t * 83.0) + sb.y * cos(_shake_t * 67.0) * 0.8) * shake_amt * 0.2
		shake_amt *= exp(-dt * 10.0)
	else:
		shake_amt = 0.0
	subpixel = Vector2.ZERO
	if mode == Mode.ISO:
		var vp_h := _viewport_height()
		var inner_h := maxf(1.0, vp_h - 2.0 * border_px)
		# Semi-altezza riferita alle righe visibili; il bordo si aggiunge fuori.
		camera.size = 2.0 * ISO_HALF_H / zoom * vp_h / inner_h
		camera.global_position = look + dir * CAM_DIST
		if pixel_snap:
			var px := camera.size / vp_h
			var basis := Basis.looking_at(-dir, Vector3.UP)
			var right := basis.x
			var up := basis.y
			var cr := camera.global_position.dot(right)
			var cu := camera.global_position.dot(up)
			var rx := cr - roundf(cr / px) * px
			var ry := cu - roundf(cu / px) * px
			camera.global_position -= right * rx + up * ry
			subpixel = Vector2(rx / px, ry / px)
	else:
		_frame_tps(dt, look)
		dir = view_dir()
	if mode == Mode.ISO:
		camera.global_transform.basis = Basis.looking_at(look - camera.global_position, Vector3.UP)
	if mode == Mode.TPS:
		_tps_sky()
	else:
		RenderingServer.global_shader_parameter_set(&"horizon_v", 0.0)
	var rs := RenderingServer
	rs.global_shader_parameter_set(&"view_dir", dir)
	rs.global_shader_parameter_set(&"persp", 1.0 if mode == Mode.TPS else 0.0)
	if mode == Mode.ISO:
		rs.global_shader_parameter_set(&"px_h", camera.size / _viewport_height())


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Terza persona adattiva: la situazione sceglie distanza, inclinazione e campo
## (esplorazione 6,5 u / 20°; corsa: piu' lontana e larga; sotto un soffitto:
## vicina e bassa; aggancio: si alza e tiene in quadro eroe e bersaglio), la
## scelta dell'utente (zoom, inclinazione) resta la base. Un raggio nei voxel e
## tra gli alberi la accorcia prima che entri in un muro (rientro rapido, uscita lenta).
func _frame_tps(dt: float, look_feet: Vector3) -> void:
	dt = minf(0.05, dt)
	var c := tps_ctx
	var now := _now()
	var d_want := 6.5
	var p_want := 0.35
	var f_want := 52.0
	var sp := float(c.get("speed", 0.0))
	var covered := bool(c.get("covered", false))
	var lock: Variant = c.get("lock", null)
	if sp > 3.6:
		d_want = 7.4
		f_want = 57.0
		p_want = 0.32
	if covered:
		d_want = 4.2
		p_want = 0.20
		f_want = 58.0
	if lock is Vector3:
		var lv: Vector3 = lock
		var dx := lv.x - look_feet.x
		var dz := lv.z - look_feet.z
		d_want = clampf(5.2 + Vector2(dx, dz).length() * 0.5, 6.0, 11.0)
		p_want = 0.45
		f_want = 54.0
		if tps_auto and now - _last_spin > 1.5:
			var df := wrapf(atan2(-dx, -dz) - yaw_target, -PI, PI)
			yaw_target += df * minf(1.0, dt * 2.2)
	elif tps_auto and sp > 1.2 and now - _last_spin > 3.0 and c.has("heading"):
		# Alle spalle dell'eroe: la camera sta dalla parte opposta allo sguardo.
		var df := wrapf(float(c["heading"]) - yaw_target, -PI, PI)
		if absf(df) < 2.5:
			yaw_target += df * minf(1.0, dt * 0.55)
	_tps_zoom_cur += (tps_zoom - _tps_zoom_cur) * (1.0 - exp(-dt * 9.0))
	var k_ad := d_want / 6.5
	var dist := 6.5 / _tps_zoom_cur * (0.55 + 0.45 * k_ad)
	var user := not is_nan(tps_user_pitch)
	if user:
		p_want = tps_user_pitch + (0.06 if lock is Vector3 else 0.0) - (0.08 if covered else 0.0)
	var k := 1.0 - exp(-dt * (12.0 if user else 3.2))
	tps_pitch += (p_want - tps_pitch) * k
	tps_fov += (f_want - tps_fov) * k
	var look := look_feet + Vector3(0, 0.45, 0)
	var dir := view_dir()
	var free := dist
	if world != null:
		var t := 0.7
		while t <= dist:
			var q := look + dir * t
			var id := world.get_block_xyz(floori(q.x), floori(q.y), floori(q.z)) if world.inside(floori(q.x), floori(q.y), floori(q.z)) else 0
			if id != BlockCatalog.AIR and id != BlockCatalog.TORCH and id != BlockCatalog.LEAVES and id != BlockCatalog.WATER:
				free = maxf(0.5, t - 0.45)
				break
			if _tree_blocks(q):
				free = maxf(1.2, t - 0.5)
				break
			t += 0.2
	if free < 1.7:
		_tps_esc = 0.8
	else:
		_tps_esc = maxf(0.0, _tps_esc - dt)
	if _tps_esc > 0.0:
		tps_pitch += (1.22 - tps_pitch) * (1.0 - exp(-dt * 7.0))
	var rate := 18.0 if free < tps_dist else (6.0 if free >= dist - 0.01 else 2.5)
	tps_dist += (free - tps_dist) * (1.0 - exp(-dt * rate))
	if absf(camera.fov - tps_fov - _fov_kick) > 0.01:
		camera.fov = tps_fov + _fov_kick
	var pos := look + view_dir() * tps_dist
	if world != null:
		var gy := VoxelQuery.field_height(world, clampf(pos.x, 1.0, world.size_x - 2.0), clampf(pos.z, 1.0, world.size_z - 2.0), float(world.size_y))
		pos.y = maxf(pos.y, gy + 0.35)
	camera.global_position = pos
	# Il punto guardato e' quello del prototipo (0,45 sopra il bersaglio).
	camera.global_transform.basis = Basis.looking_at(look - pos, Vector3.UP)


## Chioma o tronco di un albero nel punto (test del raggio della camera).
func _tree_blocks(q: Vector3) -> bool:
	if tree_grid.is_empty():
		return false
	var gx := int(q.x / 8.0)
	var gz := int(q.z / 8.0)
	for az in range(gz - 1, gz + 2):
		for ax in range(gx - 1, gx + 2):
			for tr: Vegetation.TreeSpot in tree_grid.get(Vector2i(ax, az), []):
				if tr.dead:
					continue
				var sc := tr.scale
				var dx := q.x - tr.x
				var dz := q.z - tr.z
				var dy := q.y - (tr.y + 3.0 * sc)
				if (q.y > tr.y + 1.7 * sc and dx * dx + dz * dz + dy * dy * 0.7 < (1.9 * sc) * (1.9 * sc)) \
						or (dx * dx + dz * dz < 0.2 and q.y < tr.y + 3.0 * sc):
					return true
	return false


## Orizzonte e sole veri in terza persona: si proiettano un punto lontano
## all'altezza degli occhi e la direzione del sole.
func _tps_sky() -> void:
	var vs := camera.get_viewport().get_visible_rect().size if camera.is_inside_tree() else Vector2(640, 360)
	var d := view_dir()
	var cp := camera.global_position
	var far := Vector3(cp.x - d.x * 900.0, cp.y, cp.z - d.z * 900.0)
	var hv := 0.0
	if not camera.is_position_behind(far):
		hv = 1.0 - camera.unproject_position(far).y / vs.y
	RenderingServer.global_shader_parameter_set(&"horizon_v", clampf(hv, -0.5, 0.95))
	var sd := sun_dir
	var fwd := -camera.global_transform.basis.z
	var sp := cp + sd.normalized() * 900.0
	if fwd.dot(sd.normalized()) > 0.05 and not camera.is_position_behind(sp):
		var q := camera.unproject_position(sp)
		tps_sun_uv = Vector2(q.x / vs.x, 1.0 - q.y / vs.y)
	else:
		tps_sun_uv = Vector2(-2, -2)
	RenderingServer.global_shader_parameter_set(&"sun_uv", tps_sun_uv)


func _viewport_height() -> float:
	if camera != null and camera.is_inside_tree():
		return maxf(1.0, camera.get_viewport().get_visible_rect().size.y)
	return 360.0


func _apply_projection() -> void:
	if camera == null:
		return
	if mode == Mode.ISO:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.near = 1.0
		camera.far = 160.0
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = tps_fov
		camera.near = 0.05
		camera.far = 300.0
