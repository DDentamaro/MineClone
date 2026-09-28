class_name FloatingText
extends Node3D
## Scritte brevi che salgono e svaniscono sopra il mondo (reazioni: VAPORE,
## SHOCK TERMICO, SPENTO, CRATERE, stati) e numeri del danno delle magie
## (D-032): colore dell'elemento, piu' grandi per i colpi pieni e i critici.

const LIFE := 1.1
var _items: Array[Dictionary] = []


## Numero del danno, spostato un poco a caso perche' i colpi vicini non si coprano.
func number(p: Vector3, value: float, color: Color, big: bool) -> void:
	var j := Vector3(randf_range(-0.25, 0.25), randf_range(0.0, 0.2), randf_range(-0.25, 0.25))
	spawn(p + j, str(maxi(1, roundi(value))), color, 44 if big else 30)


func spawn(p: Vector3, text: String, color: Color = Color(1, 0.95, 0.8), font_size: int = 40) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.pixel_size = 0.006
	l.outline_size = 10
	l.modulate = color
	l.outline_modulate = Color(0.05, 0.04, 0.03)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.position = p
	add_child(l)
	_items.append({"n": l, "t": 0.0})
	while _items.size() > 24:
		(_items.pop_front()["n"] as Node).queue_free()


func _process(dt: float) -> void:
	var i := _items.size() - 1
	while i >= 0:
		var it := _items[i]
		it["t"] = float(it["t"]) + dt
		var l: Label3D = it["n"]
		var u := float(it["t"]) / LIFE
		l.position.y += dt * 0.9 * (1.0 - u)
		l.modulate.a = 1.0 - maxf(0.0, (u - 0.6) / 0.4)
		l.outline_modulate.a = l.modulate.a
		if u >= 1.0:
			l.queue_free()
			_items.remove_at(i)
		i -= 1


func count() -> int:
	return _items.size()
