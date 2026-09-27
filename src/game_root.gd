class_name GameRoot
extends Node3D
## Radice della sessione: possiede mondo, attori e sessione.
## M1: mondo fixture renderizzato a chunk, giocatore con collisioni voxel,
## camera isometrica (terza persona opzionale), stick touch ed edit di debug.

enum ActionMode { EXPLORE, BUILD, DIG_DEBUG }

const PLACEABLE: Array[int] = [BlockCatalog.DIRT, BlockCatalog.STONE, BlockCatalog.SAND, BlockCatalog.WOOD, BlockCatalog.TORCH]
const MODE_LABELS := {ActionMode.EXPLORE: "Esplora", ActionMode.BUILD: "Costruisci", ActionMode.DIG_DEBUG: "Scava (debug)"}
const MODE_BUTTON := {ActionMode.EXPLORE: "Esplora", ActionMode.BUILD: "Costr.", ActionMode.DIG_DEBUG: "Scava"}
## Portata di costruzione: game.reach + 1 dal punto occhi (riga 7099).
const REACH := 7.5

@onready var _status: Label = %Status
@onready var _runtime: WorldRuntime = $WorldRuntime
@onready var _camera_rig: CameraRig = $CameraRig
@onready var _avatar: PlayerAvatar = $Player
@onready var _touch: TouchControls = %TouchControls

var world: WorldData
var catalog: BlockCatalog
var edits: WorldEditService
var motor: PlayerMotor
var action_mode: ActionMode = ActionMode.EXPLORE
var block_index := 0
var last_edit := ""

var _move_world := Vector2.ZERO
var _jump_key := false
var _args := {}
var _frames_after_build := -1
var _build_ms := 0


func _ready() -> void:
	_args = _parse_user_args()
	catalog = BlockCatalog.load_default()
	var fx := WorldFixture.load_dir(WorldFixture.SEED1931_DIR, catalog)
	if not fx.ok():
		_status.text = "Fixture NON valida:\n" + "\n".join(fx.errors)
		push_error(_status.text)
		return
	world = fx.world
	edits = WorldEditService.new(world, catalog)
	edits.light = LightEngine.new(world, catalog)
	edits.chunks_changed.connect(_runtime.mark_dirty)
	motor = PlayerMotor.new(world)
	motor.place_at(world.spawn_point())
	_avatar.position = motor.position
	_runtime.focus = motor.position
	_runtime.initial_build_finished.connect(_on_initial_build)
	_runtime.setup(world, catalog)
	_camera_rig.world = world
	_camera_rig.opaque = catalog.opaque_table()
	var cam_mode: int = Settings.load_value("camera", "mode", CameraRig.Mode.ISO)
	if _args.get("cam", "") == "tps":
		cam_mode = CameraRig.Mode.TPS
	_camera_rig.set_mode(cam_mode as CameraRig.Mode)
	if _args.has("zoom"):
		_camera_rig.set_zoom(float(_args["zoom"]))
		_camera_rig.zoom = _camera_rig.zoom_target
	if _args.has("yaw"):
		_camera_rig.yaw_target += deg_to_rad(float(_args["yaw"]))
		_camera_rig.yaw = _camera_rig.yaw_target
	_touch.left_handed = bool(Settings.load_value("input", "left_handed", false))
	_touch.camera_dragged.connect(_camera_rig.drag)
	_touch.zoom_scaled.connect(func(f: float) -> void: _camera_rig.set_zoom(_camera_rig.get_zoom() * f))
	_touch.world_tapped.connect(_on_world_tap)
	_touch.button_pressed.connect(_on_button)
	_refresh_labels()
	_camera_rig.update_camera(1.0, motor.position)


func _physics_process(dt: float) -> void:
	if motor == null:
		return
	var stick := _read_stick()
	_move_world = _camera_rig.stick_to_world(stick)
	motor.step(dt, _move_world, _jump_key or _touch.is_held(&"jump"))
	_avatar.position = motor.position
	_avatar.face_towards(Vector2(motor.velocity.x, motor.velocity.z), dt)


func _process(dt: float) -> void:
	if motor == null:
		return
	var p := _avatar.get_global_transform_interpolated().origin
	_camera_rig.update_camera(dt, p)
	_runtime.focus = p
	_status.text = "%d FPS · %s · %s · chunk in coda %d%s\nposizione %.1f %.1f %.1f%s" % [
		Engine.get_frames_per_second(), MODE_LABELS[action_mode], catalog.get_def(PLACEABLE[block_index]).display_name,
		_runtime.pending_count(), (" · mondo pronto in %d ms" % _build_ms) if _build_ms > 0 else "",
		motor.position.x, motor.position.y, motor.position.z, ("\n" + last_edit) if last_edit != "" else ""]
	if _frames_after_build >= 0:
		_frames_after_build += 1
		if _frames_after_build >= int(_args.get("frames", "30")):
			_take_screenshot()


## Stick touch o tastiera (WASD/frecce), con zona morta e minimo del prototipo (riga 7073).
func _read_stick() -> Vector2:
	var ax := 0.0
	var ay := 0.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		ax += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		ax -= 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		ay += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		ay -= 1.0
	if _touch.stick_vector != Vector2.ZERO:
		ax = _touch.stick_vector.x
		ay = -_touch.stick_vector.y
	var v := Vector2(ax, ay)
	var l := v.length()
	if l > 1.0:
		v /= l
		l = 1.0
	if l < 0.04:
		return Vector2.ZERO
	if l < 0.13:
		v *= 0.13 / l
	return v


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.physical_keycode == KEY_SPACE:
			_jump_key = k.pressed
		if not k.pressed or k.echo:
			return
		match k.physical_keycode:
			KEY_F:
				_on_button(&"mode")
			KEY_V:
				_on_button(&"camera")
			KEY_B:
				_on_button(&"block")
			KEY_T:
				_select_block(BlockCatalog.TORCH)
			KEY_1:
				_select_block(BlockCatalog.DIRT)
			KEY_2:
				_select_block(BlockCatalog.STONE)
			KEY_3:
				_select_block(BlockCatalog.WOOD)
			KEY_Q:
				_camera_rig.rotate_step(-1)
			KEY_E:
				_camera_rig.rotate_step(1)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_rig.set_zoom(_camera_rig.get_zoom() * 1.1)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_rig.set_zoom(_camera_rig.get_zoom() / 1.1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_jump_key = false


func _on_button(id: StringName) -> void:
	match id:
		&"mode":
			action_mode = ((action_mode + 1) % ActionMode.size()) as ActionMode
		&"block":
			block_index = (block_index + 1) % PLACEABLE.size()
		&"camera":
			_camera_rig.toggle_mode()
			Settings.save_value("camera", "mode", _camera_rig.mode)
	_refresh_labels()


func _select_block(id: int) -> void:
	block_index = maxi(0, PLACEABLE.find(id))
	_refresh_labels()


func _refresh_labels() -> void:
	_touch.labels[&"mode"] = MODE_BUTTON[action_mode]
	_touch.labels[&"block"] = catalog.get_def(PLACEABLE[block_index]).display_name.capitalize()
	_touch.labels[&"camera"] = "Iso" if _camera_rig.mode == CameraRig.Mode.ISO else "3ª p."
	_touch.queue_redraw()


func _on_world_tap(screen_pos: Vector2) -> void:
	if action_mode == ActionMode.EXPLORE:
		return
	var cam := _camera_rig.camera
	var origin := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var hit := VoxelQuery.raycast(world, catalog.opaque_table(), origin, dir, 400.0)
	if hit == null:
		return
	apply_action(hit)


## Azione su un blocco colpito; separata dall'input per i test.
func apply_action(hit: VoxelQuery.VoxelHit) -> bool:
	var eye := motor.eye_position()
	if action_mode == ActionMode.BUILD:
		var cell := hit.cell + hit.normal
		var id := PLACEABLE[block_index]
		if Axes.cell_center(hit.cell).distance_to(eye) > REACH:
			last_edit = "troppo lontano"
			return false
		if catalog.is_solid(id) and motor.overlaps_cell(cell):
			last_edit = "occupato dal giocatore"
			return false
		if not edits.can_place(cell, id):
			last_edit = "non posabile"
			return false
		var r := edits.set_block(cell, id, &"build")
		last_edit = "posato %s in %s" % [catalog.get_def(id).display_name, cell] if r.ok() else "rifiutato"
		return r.ok()
	if action_mode == ActionMode.DIG_DEBUG:
		if Axes.cell_center(hit.cell).distance_to(eye) > REACH or hit.cell.y == 0:
			last_edit = "fuori portata"
			return false
		var r2 := edits.set_block(hit.cell, BlockCatalog.AIR, &"debug_dig")
		last_edit = "rimosso %s in %s" % [catalog.get_def(hit.id).display_name, hit.cell] if r2.ok() else "rifiutato"
		return r2.ok()
	return false


func _on_initial_build(ms: int) -> void:
	_build_ms = ms
	print("Mondo costruito: %d chunk in %d ms (%s)" % [world.chunk_count(), ms, _runtime.stats])
	if _args.has("screenshot"):
		_frames_after_build = 0


func _take_screenshot() -> void:
	_frames_after_build = -1
	var path: String = _args["screenshot"]
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(path)
	print("Screenshot %s (%dx%d): %d" % [path, img.get_width(), img.get_height(), err])
	get_tree().quit()


## Argomenti dopo "--" sulla riga di comando:
## --screenshot=file.png --cam=tps --frames=N --zoom=0.55 --yaw=gradi
static func _parse_user_args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			out[kv[0]] = kv[1]
	return out
