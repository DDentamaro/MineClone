class_name GamePalette
extends RefCounted
## Palette comune: ardesia, salvia e ottone. Contrasto alto senza coprire il mondo.

const PANEL := Color("#13282ded")
const SURFACE := Color("#203a40f5")
const EDGE := Color("#587778")
const INK := Color("#f1f1df")
const MUTED := Color("#b2c7bf")
const ACCENT := Color("#e6bd72")
const SUCCESS := Color("#91cfb4")
static var _styles := {}


static func box(canvas: CanvasItem, rect: Rect2, selected: bool = false, radius: int = 10) -> void:
	var key := Vector2i(radius, 1 if selected else 0)
	if not _styles.has(key):
		var style := StyleBoxFlat.new()
		style.bg_color = SURFACE if selected else PANEL
		style.border_color = ACCENT if selected else EDGE
		style.set_border_width_all(2 if selected else 1)
		style.set_corner_radius_all(radius)
		style.shadow_color = Color(0, 0, 0, 0.2)
		style.shadow_size = 5
		style.shadow_offset = Vector2(0, 3)
		_styles[key] = style
	canvas.draw_style_box(_styles[key], rect)
