extends TestCase


func _rig() -> CameraRig:
	var rig := CameraRig.new()
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	rig.add_child(cam)
	(Engine.get_main_loop() as SceneTree).root.add_child(rig)
	return rig


func test_stick_avanti_si_allontana_dalla_camera() -> void:
	var rig := _rig()
	for yaw in [PI / 4.0, 0.0, 2.0, -1.3]:
		rig.yaw = yaw
		var fwd := rig.stick_to_world(Vector2(0, 1))
		var to_cam := Vector2(rig.view_dir().x, rig.view_dir().z).normalized()
		check(fwd.dot(to_cam) < -0.999, "yaw %f: avanti = lontano dalla camera" % yaw)
		var right := rig.stick_to_world(Vector2(1, 0))
		check(absf(right.dot(fwd)) < 1e-5, "destra ortogonale")
	rig.free()


func test_isometrica_ortografica_e_limiti() -> void:
	var rig := _rig()
	check_eq(rig.camera.projection, Camera3D.PROJECTION_ORTHOGONAL, "ortografica")
	rig.set_zoom(10.0)
	check_eq(rig.get_zoom(), CameraRig.ISO_ZOOM_MAX, "zoom max")
	rig.spin(0.0, 10.0)
	check_eq(rig.pitch_target, CameraRig.ISO_PITCH_MAX, "pitch max")
	rig.update_camera(10.0, Vector3(10, 5, 10))
	var to_target := (Vector3(10, 5.7, 10) - rig.camera.global_position).normalized()
	check(to_target.dot(-rig.camera.global_transform.basis.z) > 0.999, "guarda il giocatore")
	rig.toggle_mode()
	check_eq(rig.camera.projection, Camera3D.PROJECTION_PERSPECTIVE, "terza persona prospettica")
	rig.free()


func test_terza_persona_arretra_davanti_al_muro() -> void:
	var rig := _rig()
	var w := TestWorlds.flat(4)
	TestWorlds.fill(w, Vector3i(0, 4, 12), Vector3i(31, 12, 12), BlockCatalog.STONE)
	rig.world = w
	rig.opaque = BlockCatalog.load_default().opaque_table()
	rig.set_mode(CameraRig.Mode.TPS)
	rig.yaw = 0.0
	rig.yaw_target = 0.0
	for i in 60:
		rig.update_camera(1.0 / 60.0, Vector3(8.5, 4, 10.5))
	check(rig.camera.global_position.z < 12.0, "camera davanti al muro (z=%f)" % rig.camera.global_position.z)
	rig.free()


func _tps_dist_after(ctx: Dictionary, secs: float = 2.0) -> float:
	var rig := _rig()
	rig.world = TestWorlds.flat(4, 64, 32, 64)
	rig.set_mode(CameraRig.Mode.TPS)
	rig.tps_auto = false
	rig.tps_ctx = ctx
	for i in int(secs * 60.0):
		rig.update_camera(1.0 / 60.0, Vector3(32.5, 4, 32.5))
	var d := rig.tps_dist
	rig.free()
	return d


func test_terza_persona_adattiva() -> void:
	var still := _tps_dist_after({"speed": 0.0})
	var run := _tps_dist_after({"speed": 5.5})
	var cov := _tps_dist_after({"speed": 0.0, "covered": true})
	check(absf(still - 6.5) < 0.1, "esplorazione 6,5 (%f)" % still)
	check(run > still + 0.2, "in corsa si allontana (%f)" % run)
	check(cov < still - 0.8, "sotto un soffitto si avvicina (%f)" % cov)


func test_terza_persona_segue_le_spalle() -> void:
	var rig := _rig()
	rig.world = TestWorlds.flat(4, 64, 32, 64)
	rig.set_mode(CameraRig.Mode.TPS)
	rig.yaw = 0.0
	rig.yaw_target = 0.0
	rig._last_spin = -99.0
	rig.tps_ctx = {"speed": 5.0, "heading": 1.2}
	for i in 240:
		rig.update_camera(1.0 / 60.0, Vector3(32.5, 4, 32.5))
	check(absf(rig.yaw_target - 1.2) < 0.2, "camera alle spalle (yaw %f)" % rig.yaw_target)
	rig.tps_auto = false
	rig.yaw_target = 0.0
	for i in 240:
		rig.update_camera(1.0 / 60.0, Vector3(32.5, 4, 32.5))
	check(absf(rig.yaw_target) < 0.01, "senza auto non gira")
	rig.free()


## D-037: prima persona. Il pulsante camera fa il giro iso -> terza -> prima;
## la camera sta negli occhi, guarda lungo lo sguardo, lo stick va dove si guarda.
func test_prima_persona() -> void:
	var rig := _rig()
	check_eq(rig.mode, CameraRig.Mode.ISO, "parte in isometrica")
	rig.toggle_mode()
	check_eq(rig.mode, CameraRig.Mode.TPS, "poi terza persona")
	rig.toggle_mode()
	check_eq(rig.mode, CameraRig.Mode.FPS, "poi prima persona")
	check_eq(rig.camera.projection, Camera3D.PROJECTION_PERSPECTIVE, "prospettica")
	check(rig.is_persp(), "prospettica per cielo ed erba")
	rig.yaw_target = 0.7
	rig.update_camera(1.0 / 60.0, Vector3(10, 4, 10))
	var eye := rig.camera.global_position
	check(absf(eye.y - (4.0 + CameraRig.FPS_EYE)) < 1e-4, "all'altezza degli occhi (%s)" % eye)
	check(Vector2(eye.x - 10.0, eye.z - 10.0).length() < 0.2, "sopra l'eroe")
	check_eq(rig.yaw, 0.7, "lo sguardo segue il dito senza ritardo")
	var fwd := -rig.camera.global_transform.basis.z
	check(fwd.dot(rig.look_forward()) > 0.999, "guarda lungo lo sguardo")
	var st := rig.stick_to_world(Vector2(0, 1))
	check(Vector2(fwd.x, fwd.z).normalized().dot(st) > 0.999, "stick avanti = dove si guarda")
	# Trascinare in giu' guarda in basso, con un limite.
	rig.drag(Vector2(0, 100))
	check(rig.fps_pitch < 0.0, "trascinare in giu' guarda in basso")
	rig.drag(Vector2(0, 100000))
	check_eq(rig.fps_pitch, CameraRig.FPS_PITCH_MIN, "limite in basso")
	rig.toggle_mode()
	check_eq(rig.mode, CameraRig.Mode.ISO, "e di nuovo isometrica")
	rig.free()


func test_segue_morbida_negli_affondi() -> void:
	# D-040: un affondo di mezzo metro non strattona la camera; un salto lontano si.
	var rig := _rig()
	rig.pixel_snap = false
	rig.update_camera(1.0, Vector3(10, 5, 10))
	var c0 := rig.camera.global_position
	rig.update_camera(1.0 / 60.0, Vector3(10.5, 5, 10))
	var moved := rig.camera.global_position.distance_to(c0)
	check(moved > 0.01 and moved < 0.15, "un fotogramma dopo l'affondo si e' mossa poco (%.3f)" % moved)
	for i in 60:
		rig.update_camera(1.0 / 60.0, Vector3(10.5, 5, 10))
	check(rig.camera.global_position.distance_to(c0 + Vector3(0.5, 0, 0)) < 0.01, "poi raggiunge l'eroe")
	rig.update_camera(1.0 / 60.0, Vector3(40, 5, 40))
	check(rig.camera.global_position.distance_to(c0 + Vector3(30, 0, 30)) < 0.01, "teletrasporto: salta subito")
	rig.shake(0.4)
	check_eq(rig.shake_amt, 0.4 * CameraRig.SHAKE_SCALE, "scossa ridotta")
	rig.free()
