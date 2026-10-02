extends SceneTree
## Dalle direzioni dei segmenti (keyframes.py) alle pose del rig (D-046):
## per ogni posa chiave cerca gli angoli di petto, braccia, mani e gambe che
## mettono le ossa del rig lungo le direzioni misurate (discesa a coordinate
## sull'eroe vero, quindi con le convenzioni d'asse giuste per costruzione).
## Stampa i dizionari in gradi nel formato di WeaponLibrary e i tempi.
## Uso: godot --headless --path . --script res://tools/mocap/fit_poses.gd -- --in=keys.json [--out=poses.json]
##      godot ... -- --selftest   (andata e ritorno su pose esistenti)

const BONES_FIT := [
	[&"chest", [0, 1, 2]], [&"arm_r", [0, 1, 2]], [&"fore_r", [0]], [&"hand_r", [0]],
	[&"arm_l", [0, 1, 2]], [&"fore_l", [0]], [&"leg_r", [0, 2]], [&"shin_r", [0]], [&"leg_l", [0, 2]], [&"shin_l", [0]],
]
## Limiti per lo stile dell'eroe (testa grande, arma lunga): busto piegato al
## massimo di 50° in avanti e 15° di lato; il resto lo fanno braccia e mano.
const LIMITS := {"chest": [[-50, 30], [-60, 60], [-15, 15]]}
## Segmento misurato -> osso del rig e suo asse (nello spazio dell'osso).
const SEG := {
	"spine": [&"chest", Vector3.UP], "sho_line": [&"chest", Vector3.RIGHT],
	"arm_r": [&"arm_r", Vector3.DOWN], "fore_r": [&"fore_r", Vector3.DOWN], "hand_r": [&"hand_r", Vector3.DOWN],
	"arm_l": [&"arm_l", Vector3.DOWN], "fore_l": [&"fore_l", Vector3.DOWN], "hand_l": [&"hand_l", Vector3.DOWN],
	"leg_r": [&"leg_r", Vector3.DOWN], "shin_r": [&"shin_r", Vector3.DOWN], "leg_l": [&"leg_l", Vector3.DOWN], "shin_l": [&"shin_l", Vector3.DOWN],
}
const WEIGHT := {"spine": 1.0, "sho_line": 1.5, "arm_r": 2.0, "fore_r": 2.0, "hand_r": 0.7, "arm_l": 1.0, "fore_l": 1.0,
	"hand_l": 0.0, "leg_r": 0.8, "shin_r": 0.8, "leg_l": 0.8, "shin_l": 0.8}

var _rig: AvatarRig
var _done := false


func _process(_dt: float) -> bool:
	if _done:
		return true
	_done = true
	_rig = AvatarRig.new()
	root.add_child(_rig)
	_rig.build(AvatarRecipe.new())
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	if args.has("selftest"):
		_selftest()
	else:
		_fit_file(String(args.get("in", "")), String(args.get("out", "")))
	quit(0)
	return true


## Direzione (spazio del rig) dell'asse `ax` dell'osso `b` con la posa `p` (gradi).
func _dir(p: Dictionary, b: StringName, ax: Vector3) -> Vector3:
	_rig.apply_pose(WeaponLibrary.pose(p))
	return (_rig.rig_xf(_rig.bones[b]).basis * ax).normalized()


func measure(p: Dictionary) -> Dictionary:
	_rig.apply_pose(WeaponLibrary.pose(p))
	var out := {}
	for s: String in SEG:
		var b: StringName = SEG[s][0]
		out[s] = (_rig.rig_xf(_rig.bones[b]).basis * (SEG[s][1] as Vector3)).normalized()
	return out


## Testa grande dell'eroe (chibi): mani e avambracci devono restarne fuori
## (un umano vero porta le mani dove il nostro eroe ha la testa).
const HEAD_R := 0.33
## Continuita': piccola penalita' per grado di distanza dalla posa precedente,
## cosi' fra carica e colpo gli angoli non saltano su soluzioni equivalenti.
const CONT_K := 0.00008
## Lunghezza dell'arma piu' lunga nella presa (martello 1,0 x scala 1,2), per il suolo.
const ARM_LEN := 1.25

var _ref := {}


func _cost(p: Dictionary, target: Dictionary) -> float:
	var m := measure(p)
	var c := 0.0
	for s: String in target:
		if not m.has(s):
			continue
		var w: float = WEIGHT.get(s, 0.0)
		c += w * (1.0 - clampf(m[s].dot(target[s]), -1.0, 1.0))
	# (measure ha gia' applicato la posa al rig)
	var hc := _rig.rig_xf(_rig.bones[&"head"]).origin + Vector3(0, 0.27, 0)
	for b in [&"hand_r", &"hand_l", &"fore_r", &"fore_l"]:
		var x := _rig.rig_xf(_rig.bones[b])
		for q: Vector3 in [x.origin, x * Vector3(0, -0.1, 0)]:
			var d := q.distance_to(hc)
			if d < HEAD_R:
				c += 2.0 * (HEAD_R - d)
	# Punta dell'arma sopra terra anche per busto e braccia (con la mano dritta
	# lungo l'avambraccio come stima; la mano la rifinisce _fit_blade).
	var fx := _rig.rig_xf(_rig.bones[&"fore_r"])
	var tip_y := (fx * Vector3(0, -AvatarRig.FOREARM - ARM_LEN, 0)).y
	if tip_y < 0.2:
		c += (0.2 - tip_y) * 1.5
	for b: String in _ref:
		if p.has(b):
			var r0: Array = _ref[b]
			var r1: Array = p[b]
			c += CONT_K * (absf(r1[0] - r0[0]) + absf(r1[1] - r0[1]) + absf(r1[2] - r0[2]))
	return c


func fit(target: Dictionary, start: Dictionary = {}) -> Dictionary:
	_ref = start
	var p := {}
	for e: Array in BONES_FIT:
		p[String(e[0])] = (start.get(String(e[0]), [0, 0, 0]) as Array).duplicate()
	if not start.has("fore_r"):
		p["fore_r"] = [20, 0, 0]
		p["fore_l"] = [20, 0, 0]
		p["hand_r"] = [-90, 0, 0]
	var best := _cost(p, target)
	for step: float in [24.0, 12.0, 6.0, 3.0, 1.5]:
		var improved := true
		var rounds := 0
		while improved and rounds < 30:
			improved = false
			rounds += 1
			for e: Array in BONES_FIT:
				var b := String(e[0])
				for ax: int in e[1]:
					for sg: float in [1.0, -1.0]:
						var arr: Array = p[b]
						var old: float = arr[ax]
						var lim: Array = LIMITS.get(b, [[-180, 180], [-180, 180], [-180, 180]])
						arr[ax] = clampf(old + sg * step, lim[ax][0], lim[ax][1])
						var c := _cost(p, target)
						if c < best - 1e-6:
							best = c
							improved = true
						else:
							arr[ax] = old
	if target.has("arm_r") and target.has("fore_r"):
		_fit_blade(p, target)
	for b: String in p:
		var arr: Array = p[b]
		p[b] = [roundi(arr[0]), roundi(arr[1]), roundi(arr[2])]
	return p


## Il video non vede la lama: la mano si gira perche' la lama continui la
## linea spalla -> mano misurata (come una spada che allunga il braccio nel
## colpo). Cerca x e z della mano destra sul rig vero.
func _fit_blade(p: Dictionary, target: Dictionary) -> void:
	var want := ((target["arm_r"] as Vector3) * AvatarRig.UPPER_ARM + (target["fore_r"] as Vector3) * AvatarRig.FOREARM).normalized()
	var best := -2.0
	var best_h := [-90.0, 0.0, 0.0]
	var hx := -180.0
	while hx < 180.0:
		var hz := -60.0
		while hz <= 60.0:
			p["hand_r"] = [hx, 0.0, hz]
			_rig.apply_pose(WeaponLibrary.pose(p))
			var sx := _rig.rig_xf(_rig.socket)
			var d := (sx.basis * Vector3.UP).normalized().dot(want)
			# A parita', meglio una mano poco piegata di lato.
			d -= absf(hz) * 0.0005
			# L'arma dell'eroe e' lunga per il suo corpo: la punta non va sotto
			# terra (nei colpi a terra il video si piega e punta in basso).
			var tip_y := (sx * Vector3(0, ARM_LEN, 0)).y
			# (+0,2: nei colpi a terra il gioco abbassa il corpo accosciandolo)
			if tip_y < 0.2:
				d -= (0.2 - tip_y) * 2.0
			if d > best:
				best = d
				best_h = [hx, 0.0, hz]
			hz += 15.0
		hx += 10.0
	p["hand_r"] = best_h
	p["_blade_err"] = [roundi(rad_to_deg(acos(clampf(best, -1.0, 1.0)))), 0, 0]


func _err_deg(p: Dictionary, target: Dictionary) -> Dictionary:
	var m := measure(p)
	var out := {}
	for s: String in target:
		if m.has(s) and WEIGHT.get(s, 0.0) > 0.0:
			out[s] = roundi(rad_to_deg(acos(clampf(m[s].dot(target[s]), -1.0, 1.0))))
	return out


func _selftest() -> void:
	var sw := WeaponLibrary.by_id(&"sword")
	for id in [&"slash", &"backhand", &"cleave"]:
		var a := sw.attack(id)
		for key in ["key_wind", "key_strike"]:
			var deg := {}
			var pose: Dictionary = a.get(key)
			for b: StringName in pose:
				if b != &"body_pos":
					var r: Vector3 = pose[b]
					deg[String(b)] = [rad_to_deg(r.x), rad_to_deg(r.y), rad_to_deg(r.z)]
			var target := measure(deg)
			var got := fit(target)
			var err := _err_deg(got, target)
			var worst := 0
			for s: String in err:
				worst = maxi(worst, err[s])
			print("%s %s: errore massimo %d° %s" % [id, key, worst, err])


func _fit_file(path: String, out_path: String) -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var all := []
	var prev := {}
	for n in (d["strikes"] as Array).size():
		var st: Dictionary = d["strikes"][n]
		var rec := {"windup": st["windup"], "active": st["active"], "recovery": st["recovery"], "peak_speed": st["peak_speed"]}
		for key in ["wind", "strike", "follow"]:
			var dirs: Dictionary = st[key]["dirs"]
			var target := {}
			for s: String in SEG:
				if dirs.has(s):
					var v: Array = dirs[s]
					target[s] = Vector3(v[0], v[1], v[2]).normalized()
			var p := fit(target, prev)
			prev = p
			rec[key] = {"pose": p, "err": _err_deg(p, target), "hip_drop": dirs.get("hip_drop", 0.0), "pelvis_yaw": st[key]["pelvis_yaw"]}
		all.append(rec)
		print("colpo %d · tempi %.2f/%.2f/%.2f" % [n + 1, rec["windup"], rec["active"], rec["recovery"]])
		for key in ["wind", "strike", "follow"]:
			print("   %s %s  errori %s" % [key, JSON.stringify(rec[key]["pose"]), rec[key]["err"]])
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify(all, " "))
