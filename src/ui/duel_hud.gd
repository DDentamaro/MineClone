class_name DuelHud
extends Control
## Interfaccia dello scontro nell'arena (D-058): barre della vita del
## giocatore e dell'avversario in alto a sinistra (sotto, la guardia quando
## cala), punteggio e grande scritta al centro (round, conto alla rovescia,
## COMBATTI!, VITTORIA / SCONFITTA).

var player_hp := 1.0
var enemy_hp := 1.0
var player_posture := 0.0
var enemy_posture := 0.0
var enemy_name := ""
var score := ""
var banner := ""
var banner_sub := ""
var _font: Font
var _scale := 1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font


func _draw() -> void:
	if _font == null or size.x < 1.0:
		return
	_scale = clampf(minf(size.x / 960.0, size.y / 620.0), 0.6, 1.4)
	var s := size / _scale
	var w := minf(300.0, s.x * 0.36)
	var x := 18.0
	var y := 16.0
	_bar(Vector2(x, y), w, player_hp, Color("#6fcf7f"), "Tu", player_posture)
	_bar(Vector2(x, y + 40), w, enemy_hp, Color("#e2675a"), "Avversario" + ("  ·  " + enemy_name if enemy_name != "" else ""), enemy_posture)
	if score != "":
		_text(Vector2(x, y + 92), score, 14, GamePalette.MUTED)
	if banner != "":
		var big := 64 if banner.length() <= 2 else 46
		_center(Vector2(s.x * 0.5, s.y * 0.36), banner, big, GamePalette.ACCENT)
		if banner_sub != "":
			_center(Vector2(s.x * 0.5, s.y * 0.36 + 40), banner_sub, 18, GamePalette.INK)


func _bar(at: Vector2, w: float, k: float, col: Color, label: String, posture: float) -> void:
	var h := 12.0
	_text(at + Vector2(0, 12), label, 13, GamePalette.INK)
	var r := Rect2(at + Vector2(0, 17), Vector2(w, h))
	draw_rect(Rect2(r.position * _scale - Vector2(2, 2), r.size * _scale + Vector2(4, 4)), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(r.position * _scale, r.size * _scale), Color(0.16, 0.12, 0.12, 0.85))
	draw_rect(Rect2(r.position * _scale, Vector2(r.size.x * clampf(k, 0.0, 1.0), r.size.y) * _scale), col)
	if posture > 0.01:
		# Guardia consumata: una striscia gialla sotto la vita.
		var pr := Rect2(r.position + Vector2(0, h + 2), Vector2(w * clampf(posture, 0.0, 1.0), 3))
		draw_rect(Rect2(pr.position * _scale, pr.size * _scale), Color("#f2c14e"))


func _text(at: Vector2, value: String, font_size: int, color: Color) -> void:
	var fs := maxi(10, roundi(font_size * _scale))
	draw_string_outline(_font, at * _scale, value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, roundi(3 * _scale)), Color(0, 0, 0, 0.8))
	draw_string(_font, at * _scale, value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)


func _center(at: Vector2, value: String, font_size: int, color: Color) -> void:
	var fs := maxi(12, roundi(font_size * _scale))
	var tw := _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := Vector2(at.x * _scale - tw * 0.5, at.y * _scale)
	draw_string_outline(_font, p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(3, roundi(6 * _scale)), Color(0, 0, 0, 0.85))
	draw_string(_font, p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
