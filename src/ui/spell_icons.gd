class_name SpellIcons
extends RefCounted
## Icone delle magie disegnate (D-028): fondo nel colore della scuola, simbolo
## bianco della forma (raggio, getto, area, muro...). Usate dalla barra, dal
## pulsante Magia e dal libro. Bloccata = grigia con lucchetto.


static func draw(ci: CanvasItem, r: Rect2, s: SpellDefinition, blocked: bool = false, locked: bool = false) -> void:
	var col := s.color()
	if blocked or locked:
		col = col.lerp(Color(0.35, 0.35, 0.37), 0.7)
	ci.draw_rect(r, col.darkened(0.35))
	ci.draw_rect(r.grow(-r.size.x * 0.06), col)
	var c := r.get_center()
	var k := r.size.x * 0.34
	var w := maxf(1.5, r.size.x * 0.07)
	var ink := Color(1, 1, 1, 0.95) if not (blocked or locked) else Color(0.85, 0.85, 0.85, 0.8)
	_glyph(ci, s, c, k, w, ink)
	if locked:
		_lock(ci, r)


static func _arrow(ci: CanvasItem, a: Vector2, b: Vector2, w: float, ink: Color, head: float) -> void:
	ci.draw_line(a, b, ink, w, true)
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	ci.draw_colored_polygon(PackedVector2Array([b + d * head * 0.6, b - d * head * 0.5 + n * head * 0.55, b - d * head * 0.5 - n * head * 0.55]), ink)


static func _glyph(ci: CanvasItem, s: SpellDefinition, c: Vector2, k: float, w: float, ink: Color) -> void:
	match s.kind:
		"dart", "bolt":
			_arrow(ci, c + Vector2(-k, k * 0.6), c + Vector2(k * 0.7, -k * 0.5), w, ink, k * 0.55)
		"shaft":
			_arrow(ci, c + Vector2(-k, k * 0.2), c + Vector2(k * 0.8, -k * 0.2), w * 0.7, ink, k * 0.45)
		"volley":
			for i in 3:
				var o := Vector2(0, (i - 1) * k * 0.6)
				_arrow(ci, c + o + Vector2(-k * 0.8, 0), c + o + Vector2(k * 0.6, -o.y * 0.3), w * 0.7, ink, k * 0.35)
		"ball", "orb":
			ci.draw_circle(c, k * 0.55, ink)
			for i in 8:
				var a := TAU * i / 8.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * k * 0.72, c + Vector2(cos(a), sin(a)) * k, ink, w * 0.6, true)
		"meteor":
			ci.draw_circle(c + Vector2(k * 0.35, k * 0.35), k * 0.42, ink)
			for i in 3:
				var o := Vector2(-1, 1).normalized() * (i - 1) * k * 0.25
				ci.draw_line(c + o + Vector2(k * 0.1, k * 0.1), c + o + Vector2(-k, -k), ink, w * 0.6, true)
		"throw":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-k * 0.7, k * 0.1), c + Vector2(-k * 0.2, -k * 0.6), c + Vector2(k * 0.6, -k * 0.4),
				c + Vector2(k * 0.75, k * 0.3), c + Vector2(0, k * 0.7)]), ink)
		"beam":
			ci.draw_line(c + Vector2(-k, 0), c + Vector2(k, 0), Color(ink, 0.45), w * 2.6, true)
			ci.draw_line(c + Vector2(-k, 0), c + Vector2(k, 0), ink, w, true)
			ci.draw_circle(c + Vector2(-k, 0), w * 1.4, ink)
		"jet", "spray":
			for i in 5:
				var a := deg_to_rad(-22.0 + i * 11.0)
				var d := Vector2(cos(a), sin(a))
				ci.draw_line(c + Vector2(-k, 0), c + Vector2(-k, 0) + d * k * (1.6 + 0.2 * (i % 2)), ink, w * 0.6, true)
		"column":
			for i in 3:
				var x := (i - 1) * k * 0.6
				ci.draw_line(c + Vector2(x, k), c + Vector2(x, -k * (0.6 + 0.3 * (i % 2))), ink, w * 1.2, true)
		"spikes":
			for i in 3:
				var x := (i - 1) * k * 0.6
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(x - k * 0.28, k), c + Vector2(x + k * 0.28, k), c + Vector2(x, -k * (0.4 + 0.4 * (i % 2)))]), ink)
		"quake":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-k, -k * 0.2), c + Vector2(-k * 0.4, k * 0.2), c + Vector2(0, -k * 0.3),
				c + Vector2(k * 0.35, k * 0.3), c + Vector2(k, -k * 0.1)]), ink, w, true)
			ci.draw_line(c + Vector2(-k, k * 0.7), c + Vector2(k, k * 0.7), ink, w * 0.7, true)
		"rain":
			ci.draw_circle(c + Vector2(-k * 0.3, -k * 0.55), k * 0.35, ink)
			ci.draw_circle(c + Vector2(k * 0.25, -k * 0.5), k * 0.42, ink)
			for i in 4:
				var x := (i - 1.5) * k * 0.45
				ci.draw_line(c + Vector2(x, 0), c + Vector2(x - k * 0.1, k * 0.8), ink, w * 0.6, true)
		"cyclone":
			var pts := PackedVector2Array()
			for i in 28:
				var u := i / 27.0
				var a := u * TAU * 2.2
				pts.append(c + Vector2(cos(a), sin(a)) * k * (0.12 + 0.88 * u))
			ci.draw_polyline(pts, ink, w * 0.8, true)
		"vacuum":
			for i in 4:
				var a := TAU * i / 4.0 + PI * 0.25
				var d := Vector2(cos(a), sin(a))
				_arrow(ci, c + d * k, c + d * k * 0.3, w * 0.7, ink, k * 0.35)
		"updraft":
			for i in 3:
				var x := (i - 1) * k * 0.6
				_arrow(ci, c + Vector2(x, k), c + Vector2(x, -k * 0.5), w * 0.7, ink, k * 0.4)
		"wave":
			var pts := PackedVector2Array()
			for i in 24:
				var u := i / 23.0
				pts.append(c + Vector2(-k + 2.0 * k * u, sin(u * TAU * 1.5) * k * 0.45))
			ci.draw_polyline(pts, ink, w, true)
		"lash":
			ci.draw_arc(c + Vector2(-k * 0.2, k * 0.4), k, -PI * 0.5, 0.1, 16, ink, w, true)
		"slash":
			ci.draw_arc(c, k, -PI * 0.8, PI * 0.2, 20, ink, w * 1.4, true)
		"push":
			for i in 3:
				var y := (i - 1) * k * 0.6
				_arrow(ci, c + Vector2(-k * 0.6, y), c + Vector2(k * 0.7, y), w * 0.7, ink, k * 0.35)
		"buff":
			for i in 2:
				var x := (i - 0.5) * k * 0.7
				ci.draw_polyline(PackedVector2Array([c + Vector2(x - k * 0.3, -k * 0.6), c + Vector2(x + k * 0.3, 0), c + Vector2(x - k * 0.3, k * 0.6)]), ink, w, true)
		"wall":
			var b := Rect2(c - Vector2(k, k * 0.6), Vector2(k * 2.0, k * 1.2))
			ci.draw_rect(b, ink, false, w)
			ci.draw_line(Vector2(b.position.x, c.y), Vector2(b.end.x, c.y), ink, w * 0.6)
			ci.draw_line(Vector2(c.x - k * 0.3, b.position.y), Vector2(c.x - k * 0.3, c.y), ink, w * 0.6)
			ci.draw_line(Vector2(c.x + k * 0.4, c.y), Vector2(c.x + k * 0.4, b.end.y), ink, w * 0.6)
		"pillar":
			ci.draw_rect(Rect2(c + Vector2(-k * 0.35, -k * 0.1), Vector2(k * 0.7, k * 1.1)), ink)
			ci.draw_circle(c + Vector2(0, -k * 0.55), k * 0.22, ink)
		_:
			ci.draw_circle(c, k * 0.5, ink)


static func _lock(ci: CanvasItem, r: Rect2) -> void:
	var s := r.size.x * 0.34
	var o := r.end - Vector2(s * 1.05, s * 1.1)
	ci.draw_rect(Rect2(o + Vector2(0, s * 0.45), Vector2(s, s * 0.6)), Color(0.1, 0.1, 0.1, 0.9))
	ci.draw_arc(o + Vector2(s * 0.5, s * 0.45), s * 0.32, PI, TAU, 10, Color(0.1, 0.1, 0.1, 0.9), maxf(1.5, s * 0.14), true)
	ci.draw_rect(Rect2(o + Vector2(s * 0.42, s * 0.6), Vector2(s * 0.16, s * 0.25)), Color(0.95, 0.85, 0.4))
