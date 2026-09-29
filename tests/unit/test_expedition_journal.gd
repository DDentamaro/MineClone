extends TestCase


func test_progress_is_bounded_and_out_of_order() -> void:
	var j := ExpeditionJournal.new()
	j.record("craft")
	j.record("walk", 200.0)
	j.record("walk", -10.0)
	j.record("unknown", 1.0)
	j.record("harvest", NAN)
	check_eq(j.completed_count(), 2, "goals can be completed out of order")
	check_eq(j.counts["walk"], 24.0, "bounded distance")
	check_eq(j.current()["id"], "harvest", "next incomplete goal")
	check(not j.counts.has("unknown"), "ignore unknown events")
	check(not j.counts.has("harvest"), "reject invalid numbers")


func test_save_roundtrip_and_legacy() -> void:
	var j := ExpeditionJournal.new()
	j.record("harvest", 2.0)
	j.record("camp")
	var restored := ExpeditionJournal.new()
	restored.load_dict(j.to_dict())
	check_eq(restored.counts["harvest"], 2.0, "partial progress restored")
	check_eq(restored.completed_count(), 1, "completed goal restored")
	restored.load_dict({})
	check_eq(restored.completed_count(), 0, "old saves start with an empty journal")


func test_completion_only_emitted_once() -> void:
	var j := ExpeditionJournal.new()
	var notifications: Array[String] = []
	j.completed.connect(func(title: String) -> void: notifications.append(title))
	j.record("hit", 2.0)
	j.record("hit")
	j.record("hit", 20.0)
	check_eq(notifications.size(), 1, "one notification per milestone")
	j.load_dict({"hit": 9999, "walk": "invalid", "camp": -3})
	check_eq(notifications.size(), 1, "loading is silent")
	check_eq(j.counts["hit"], 3.0, "clamped save input")
	check_eq(j.counts["camp"], 0.0, "negative save input")
