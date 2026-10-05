extends TestCase
## Duello (D-058): parata, parata perfetta, guardia rotta, schivata, reazione
## ai colpi e il nemico con l'IA che combatte da solo.

const DT := 1.0 / 60.0


class Duelist:
	extends RefCounted
	var motor: PlayerMotor
	var combat: CombatController
	var body: FighterBody
	var stick := Vector2.ZERO

	func _init(world: WorldData, p: Vector3, face: float, weapon: StringName) -> void:
		motor = PlayerMotor.new(world)
		motor.place_at(p)
		combat = CombatController.new(WeaponLibrary.by_id(weapon))
		combat.world = world
		combat.facing = face
		body = FighterBody.new(motor, combat, 100.0)


class Pair:
	extends RefCounted
	var world: WorldData
	var a: Duelist
	var b: Duelist

	func _init(wa: StringName = &"sword", wb: StringName = &"sword", dist: float = 1.3) -> void:
		world = TestWorlds.flat(4, 48, 16, 48)
		# a guarda verso -Z (facing 0), b sta davanti e lo guarda (facing PI).
		a = Duelist.new(world, Vector3(24.5, 4, 26.0), 0.0, wa)
		b = Duelist.new(world, Vector3(24.5, 4, 26.0 - dist), PI, wb)

	## I due corpi si tengono attraverso i controller: si sciolgono a fine prova.
	func dispose() -> void:
		a.combat.forget_targets()
		b.combat.forget_targets()

	func step(n: int = 1) -> void:
		for i in n:
			for s: Duelist in [a, b]:
				var foe: Duelist = b if s == a else a
				s.combat.step(DT, s.motor, [foe.body] if foe.body.alive else [], s.stick)
				s.combat.events.clear()
				if s.combat.hitstop <= 0.0:
					s.motor.drive_on = s.combat.drive_on
					s.motor.drive = s.combat.drive
					s.motor.move_scale = s.combat.move_scale
					s.motor.step(DT, s.stick, false)
				s.body.step(DT)


## Passi fino a poco prima che il colpo di `a` arrivi (fine della carica - `early`).
func _until_windup(p: Pair, early: float) -> void:
	for i in 120:
		var at := p.a.combat.attack
		if at != null and p.a.combat.phase() == 0 and at.windup - p.a.combat.t <= early:
			return
		p.step()


func test_parata_perfetta_stordisce_chi_attacca() -> void:
	var p := Pair.new()
	p.a.combat.press_light()
	p.step()
	_until_windup(p, 0.06)
	p.b.combat.press_guard()
	p.step(40)
	check_eq(p.b.body.hp, 100.0, "parata perfetta: nessun danno")
	check(p.a.combat.stunned(), "chi attacca resta stordito")
	check(p.b.combat.riposte_t > 0.0, "si apre la risposta")
	p.dispose()


func test_guardia_tenuta_riduce_il_danno() -> void:
	var p := Pair.new()
	p.b.combat.press_guard()
	p.step(40)
	check(p.b.combat.guarding(), "in guardia")
	p.a.combat.press_light()
	p.step(60)
	var lost := 100.0 - p.b.body.hp
	check(lost > 0.0 and lost < 3.0, "parato: passa solo una scheggia (%.2f)" % lost)
	check(not p.a.combat.stunned(), "la parata normale non stordisce")
	check(p.b.combat.posture > 0.0, "la postura cala")
	p.dispose()


func test_colpo_alle_spalle_passa() -> void:
	var p := Pair.new()
	p.b.combat.facing = 0.0
	p.b.combat.press_guard()
	p.step(40)
	p.b.combat.facing = 0.0
	p.a.combat.press_light()
	p.step(60)
	check(100.0 - p.b.body.hp > 5.0, "da dietro la guardia non para (%.1f)" % (100.0 - p.b.body.hp))
	p.dispose()


func test_la_guardia_si_rompe() -> void:
	var p := Pair.new(&"greatsword", &"sword", 1.6)
	p.b.combat.press_guard()
	p.step(40)
	var broke := false
	for i in 8:
		p.a.combat.press_heavy()
		p.a.combat.release_heavy()
		for k in 120:
			p.step()
			p.b.combat.facing = PI
			if p.b.combat.stunned():
				broke = true
		if broke:
			break
	check(broke, "colpi forti parati di fila rompono la guardia")
	p.dispose()


func test_la_capriola_schiva() -> void:
	var p := Pair.new()
	p.a.combat.press_light()
	p.step()
	_until_windup(p, 0.1)
	p.b.stick = Vector2(1, 0)
	p.b.combat.press_dodge()
	p.step(60)
	check_eq(p.b.body.hp, 100.0, "colpo nella capriola: schivato")
	p.dispose()


func test_un_colpo_forte_interrompe_la_carica() -> void:
	var p := Pair.new(&"sword", &"greatsword", 1.3)
	p.b.combat.press_heavy()
	p.step(3)
	check(p.b.combat.charging, "b carica il forte")
	p.a.combat.press_light()
	p.step(40)
	check(p.b.body.hp < 100.0, "b colpito")
	check(p.b.combat.attack == null or not p.b.combat.charging, "la carica e' interrotta")
	p.dispose()


func test_il_nemico_combatte_da_solo() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var world := TestWorlds.flat(4, 48, 16, 48)
	for pair in [[&"sword", &"hammer"], [&"staff", &"spear"], [&"fists", &"greatsword"]]:
		var f1 := Fighter.new()
		var f2 := Fighter.new()
		tree.root.add_child(f1)
		tree.root.add_child(f2)
		f1.setup(world, null, AvatarRecipe.preset(0), null)
		f2.setup(world, null, TrainingGround.sparring_recipe(), null)
		f1.ai = FighterAI.new(2, 11)
		f2.ai = FighterAI.new(3, 22)
		f1.set_weapon(pair[0])
		f2.set_weapon(pair[1])
		f1.place(Vector3(24.5, 4, 30.0), 0.0)
		f2.place(Vector3(24.5, 4, 20.0), PI)
		var starts := [0, 0]
		var defended := 0
		for i in int(25.0 / DT):
			f1.step(DT, f2.body, f2.combat, f2.magic.shots, Vector3(24.5, 4, 25), 0.0, true)
			f2.step(DT, f1.body, f1.combat, f1.magic.shots, Vector3(24.5, 4, 25), 0.0, true)
			for f: Fighter in [f1, f2]:
				for e in f.events:
					if e["type"] in ["dodge", "guard"]:
						defended += 1
				f.events.clear()
			if not f1.body.alive or not f2.body.alive:
				break
		starts = [f1.combat.starts, f2.combat.starts]
		check(starts[0] > 3 and starts[1] > 3, "%s contro %s: tutti e due attaccano (%s)" % [pair[0], pair[1], starts])
		check(f1.body.hp < 100.0 or f2.body.hp < 100.0, "%s contro %s: qualcuno e' colpito (%.0f, %.0f)" % [pair[0], pair[1], f1.body.hp, f2.body.hp])
		check(defended > 0, "%s contro %s: si difendono (capriole o guardia)" % [pair[0], pair[1]])
		f1.free()
		f2.free()
