// Scia dell'arma (M4): nastro additivo che si dissolve con l'eta'.
// COLOR.a = intensita' residua; il colore passa per la stessa correzione
// notturna e di grading degli altri trasparenti.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, specular_disabled, fog_disabled;

#include "res://src/presentation/shaders/rustic.gdshaderinc"
#include "res://src/presentation/shaders/post_common.gdshaderinc"

void fragment() {
	float a = COLOR.a;
	float band = floor(a * 4.0 + 0.5) / 4.0;
	vec3 c = COLOR.rgb * band;
	ALBEDO = post_color(out_color(c), vec2(SCREEN_UV.x, 1.0 - SCREEN_UV.y));
}
