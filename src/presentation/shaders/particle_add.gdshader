// Grani: porting di particleVS/particleFS (HTML ~5508). Quad (o streak lungo
// aDir) in spazio vista, centro agganciato alla griglia dei pixel del render
// target e lati in mezzi pixel interi, cosi' i grani non tremano.
// VERTEX = centro; CUSTOM0 = (angolo u, angolo v, lato, lunghezza); CUSTOM1 = direzione.
// Il materiale additivo e quello opaco differiscono solo per render_mode.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled, blend_add;

#include "res://src/presentation/shaders/rustic.gdshaderinc"
#include "res://src/presentation/shaders/post_common.gdshaderinc"

global uniform float px_h;
uniform float additive = 0.0;

varying vec2 v_uv;
varying vec4 v_col;

void vertex() {
	vec4 c = VIEW_MATRIX * vec4(VERTEX, 1.0);
	vec3 d = mat3(VIEW_MATRIX) * CUSTOM1.xyz;
	vec2 ax = vec2(0.0, 1.0);
	float dl = length(d.xy);
	if (dl > 1e-4) ax = d.xy / dl;
	vec2 pp = vec2(-ax.y, ax.x);
	float px = max(px_h, 1e-4);
	c.xy = (floor(c.xy / px) + 0.5) * px;
	float sw = max(0.5, floor(CUSTOM0.z / px * 2.0 + 0.5) * 0.5), sl = max(sw, floor(CUSTOM0.w / px * 2.0 + 0.5) * 0.5);
	vec2 p = c.xy + ax * CUSTOM0.y * sl * px + pp * CUSTOM0.x * sw * px;
	POSITION = PROJECTION_MATRIX * vec4(p, c.z, 1.0);
	v_uv = CUSTOM0.xy;
	v_col = COLOR;
}

void fragment() {
	float f = 1.0 - dot(v_uv, v_uv);
	if (f <= 0.0) discard;
	vec2 suv = SCREEN_UV;
	vec3 col = post_color(v_col.rgb, vec2(suv.x, 1.0 - suv.y));
	if (additive > 0.5) {
		ALBEDO = out_color(col);
		ALPHA = v_col.a * f * f;
	} else {
		ALBEDO = out_color(col);
		ALPHA = v_col.a;
	}
}
