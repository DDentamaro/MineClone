class_name ExpeditionJournal
extends RefCounted
## Progressione introduttiva non bloccante: conta azioni riuscite, anche fuori ordine.
## Nessuna ricompensa duplicabile; il diario fa parte del salvataggio del mondo.

signal completed(title: String)

const GOALS := [
	{"id": "walk", "title": "Un mondo da scoprire", "hint": "Esplora per 24 metri. WASD / frecce o stick touch.", "target": 24.0},
	{"id": "harvest", "title": "Le prime risorse", "hint": "Raccogli 4 risorse: tieni premuto su alberi o blocchi.", "target": 4.0},
	{"id": "craft", "title": "Il tuo laboratorio", "hint": "Zaino > Craft: crea un banco con 4 pezzi di legno.", "target": 1.0},
	{"id": "build", "title": "Metti radici", "hint": "Impugna il banco e tocca un terreno libero per posarlo.", "target": 1.0},
	{"id": "hit", "title": "Prendi confidenza", "hint": "Colpisci 3 volte un manichino. R / Lock per agganciarlo.", "target": 3.0},
	{"id": "dodge", "title": "Questione di ritmo", "hint": "Esegui una schivata: Maiusc, L o Schiva.", "target": 1.0},
	{"id": "camp", "title": "Un posto dove tornare", "hint": "Crea e posa un falò, poi interagisci per salvare il ritorno.", "target": 1.0},
	{"id": "treasure", "title": "Oltre il campo", "hint": "Esplora e apri un forziere del tesoro nel mondo.", "target": 1.0},
]

var counts := {}


func record(id: String, amount: float = 1.0) -> void:
	if not is_finite(amount) or amount <= 0.0:
		return
	for goal: Dictionary in GOALS:
		if goal["id"] != id:
			continue
		var before := float(counts.get(id, 0.0))
		var target := float(goal["target"])
		counts[id] = minf(target, before + amount)
		if before < target and float(counts[id]) >= target:
			completed.emit(String(goal["title"]))
		return


func done(goal: Dictionary) -> bool:
	return float(counts.get(goal["id"], 0.0)) >= float(goal["target"])


func current() -> Dictionary:
	for goal: Dictionary in GOALS:
		if not done(goal):
			return goal
	return {}


func completed_count() -> int:
	var n := 0
	for goal: Dictionary in GOALS:
		if done(goal):
			n += 1
	return n


func to_dict() -> Dictionary:
	return counts.duplicate()


func load_dict(data: Dictionary) -> void:
	counts.clear()
	for goal: Dictionary in GOALS:
		var value: Variant = data.get(goal["id"], 0.0)
		if (value is float or value is int) and is_finite(float(value)):
			counts[goal["id"]] = clampf(float(value), 0.0, float(goal["target"]))
