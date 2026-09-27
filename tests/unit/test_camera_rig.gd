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
	rig.update_camera(1.0, Vector3(8.5, 4, 10.5))
	check(rig.camera.global_position.z < 12.0, "camera davanti al muro (z=%f)" % rig.camera.global_position.z)
	rig.free()
