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

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	_apply_projection()


func set_mode(m: Mode) -> void:
	mode = m
	_apply_projection()


func toggle_mode() -> void:
	set_mode(Mode.TPS if mode == Mode.ISO else Mode.ISO)


func spin(dyaw: float, dpitch: float) -> void:
	yaw_target += dyaw
	if mode == Mode.TPS:
		tps_pitch = clampf(tps_pitch + dpitch, TPS_PITCH_MIN, TPS_PITCH_MAX)
	else:
		pitch_target = clampf(pitch_target + dpitch, ISO_PITCH_MIN, ISO_PITCH_MAX)


## Rotazione a scatti (tasti Q/E): 90° in isometrica, 45° in terza persona.
func rotate_step(step: int) -> void:
	yaw_target += step * (PI / 4.0 if mode == Mode.TPS else PI / 2.0)


func drag(delta_px: Vector2) -> void:
	spin(-delta_px.x * DRAG_YAW, delta_px.y * DRAG_PITCH)


func shake(amount: float) -> void:
	shake_amt = maxf(shake_amt, amount)


func get_zoom() -> float:
	return tps_zoom if mode == Mode.TPS else zoom_target


func set_zoom(z: float) -> void:
	if mode == Mode.TPS:
		tps_zoom = clampf(z, TPS_ZOOM_MIN, TPS_ZOOM_MAX)
	else:
		zoom_target = clampf(z, ISO_ZOOM_MIN, ISO_ZOOM_MAX)


## Direzione dal punto guardato verso la camera.
func view_dir() -> Vector3:
	var p := tps_pitch if mode == Mode.TPS else pitch
	return Vector3(cos(p) * sin(yaw), sin(p), cos(p) * cos(yaw)).normalized()


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
		var dist := TPS_DIST * tps_zoom
		# Arretramento davanti ai muri: raycast voxel dal bersaglio verso la camera.
		if world != null and not opaque.is_empty():
			var hit := VoxelQuery.raycast(world, opaque, look, dir, dist)
			if hit != null:
				dist = maxf(0.4, hit.distance - 0.2)
		camera.global_position = look + dir * dist
	camera.global_transform.basis = Basis.looking_at(look - camera.global_position, Vector3.UP)
	var rs := RenderingServer
	rs.global_shader_parameter_set(&"view_dir", dir)
	rs.global_shader_parameter_set(&"persp", 1.0 if mode == Mode.TPS else 0.0)
	if mode == Mode.ISO:
		rs.global_shader_parameter_set(&"px_h", camera.size / _viewport_height())


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
		camera.fov = TPS_FOV
		camera.near = 0.05
		camera.far = 300.0
