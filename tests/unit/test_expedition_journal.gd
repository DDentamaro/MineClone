extends TestCase
## Diario della spedizione (D-036): obiettivi introduttivi e salvataggio.


func test_avanzamento_limitato_e_fuori_ordine() -> void:
	var j := ExpeditionJournal.new()
	j.record("craft")
	j.record("walk", 200.0)
	j.record("walk", -10.0)
	j.record("unknown", 1.0)
	j.record("harvest", NAN)
	check_eq(j.completed_count(), 2, "obiettivi completabili fuori ordine")
	check_eq(j.counts["walk"], 24.0, "distanza limitata al traguardo")
	check_eq(j.current()["id"], "harvest", "prossimo obiettivo incompleto")
	check(not j.counts.has("unknown"), "eventi sconosciuti ignorati")
	check(not j.counts.has("harvest"), "numeri non validi rifiutati")


func test_salvataggio_e_partite_vecchie() -> void:
	var j := ExpeditionJournal.new()
	j.record("harvest", 2.0)
	j.record("camp")
	var restored := ExpeditionJournal.new()
	restored.load_dict(j.to_dict())
	check_eq(restored.counts["harvest"], 2.0, "avanzamento parziale ripristinato")
	check_eq(restored.completed_count(), 1, "obiettivo completato ripristinato")
	restored.load_dict({})
	check_eq(restored.completed_count(), 0, "le partite vecchie partono col diario vuoto")


func test_completamento_notificato_una_volta() -> void:
	var j := ExpeditionJournal.new()
	var notifications: Array[String] = []
	j.completed.connect(func(title: String) -> void: notifications.append(title))
	j.record("hit", 2.0)
	j.record("hit")
	j.record("hit", 20.0)
	check_eq(notifications.size(), 1, "una notifica per traguardo")
	j.load_dict({"hit": 9999, "walk": "invalid", "camp": -3})
	check_eq(notifications.size(), 1, "il caricamento non notifica")
	check_eq(j.counts["hit"], 3.0, "valore salvato limitato")
	check_eq(j.counts["camp"], 0.0, "valore salvato negativo")
