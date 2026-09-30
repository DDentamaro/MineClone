// Fili d'erba a billboard: porting di grassVS/grassFS (HTML ~5342), stile dipinto.
// VERTEX = (x, y suolo, z) del filo; CUSTOM0 = angolo (u, v), seme, luce;
// CUSTOM1 = larghezza, altezza (negativa = ciuffo pendente).
shader_type spatial;
render_mode cull_disabled, specular_disabled, ambient_light_disabled, fog_disabled;
// Segna i propri pixel per il post (niente contorni sull'erba).
stencil_mode write, compare_always, 2;

#include "res://src/presentation/shaders/rustic.gdshaderinc"

uniform sampler2D leaf_tex : source_color, filter_nearest, repeat_disable;
uniform float wind_climate = 0.72;

varying vec2 v_uv;
varying vec2 v_origin;
varying float v_seed;
varying float v_light;
varying float v_gy;
varying float v_hang;
varying vec3 v_wpos;

void vertex() {
	vec2 corner = CUSTOM0.xy;
	float seed = CUSTOM0.z;
	vec2 size = CUSTOM1.xy;
	vec2 off = VERTEX.xz;
	float gy = VERTEX.y;
	float fr = 5.0; float phase = fract(seed * 13.731) / fr; float qt = floor((world_time + phase) * fr + 0.5) / fr;
	vec2 wind_dir = normalize(vec2(0.22, 1.0));
	float gust = vnoise(off * 0.085 + wind_dir * qt * 0.055 + vec2(seed * 1.7));
	float wave = sin(qt * 1.15 + off.x * 0.095 + off.y * 0.071 + seed * 12.7);
	float wind = ((gust - 0.5) * 0.75 + wave * 0.34) * (0.55 + 0.75 * wind_climate);
	float dry = vnoise(off * 0.075 + vec2(5.1, 11.7));
	float height_mul = 1.0 + (fract(seed * 9.17) - 0.5) * 0.15 - dry * 0.08; float width_mul = 0.96 + fract(seed * 5.31) * 0.10;
	float x = (corner.x - 0.5) * size.x * width_mul; float y = corner.y * size.y * height_mul; float top = corner.y * corner.y;
	float view_sway = sin((qt + seed * 2.0) * 0.62) * 0.025; float cs = cos(view_sway), sn = sin(view_sway);
	vec2 local = mat2(vec2(cs, -sn), vec2(sn, cs)) * vec2(x, y);
	vec3 cam_right = INV_VIEW_MATRIX[0].xyz;
	vec3 cam_up = INV_VIEW_MATRIX[1].xyz;
	vec3 pos = vec3(off.x, gy + 0.015, off.y);
	pos += cam_right * local.x; pos += cam_up * local.y; pos.xz += wind_dir * wind * 0.046 * top;
	pos.xz += vec2(cos(seed * 17.0), sin(seed * 19.0)) * (dry - 0.5) * 0.020 * top;
	if (gy > slice_y + 0.5) pos = vec3(0.0, -1000.0, 0.0);
	VERTEX = pos;
	v_wpos = pos;
	NORMAL = vec3(0.0, 1.0, 0.0);
	v_uv = corner; v_origin = off; v_seed = seed; v_light = CUSTOM0.w; v_gy = gy; v_hang = step(size.y, 0.0);
}

void fragment() {
	if (xray_occludes(SCREEN_UV, FRAGCOORD.xy, -VERTEX.z, VIEWPORT_SIZE)) discard;
	vec4 leaf = texture(leaf_tex, vec2((v_uv.x + step(0.5, fract(v_seed * 7.31))) * 0.5, v_uv.y));
	if (leaf.a < 0.5) discard;
	ALBEDO = vec3(1.0);
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		if (paint_mode > 0.5) {
			vec4 leaf = texture(leaf_tex, vec2((v_uv.x + step(0.5, fract(v_seed * 7.31))) * 0.5, v_uv.y));
			vec3 gc = paint_grass_color(v_origin, 0.5, 0.5);
			float tone = leaf.r > 0.92 ? 1.07 : (leaf.r > 0.76 ? 1.0 : 0.94); tone *= mix(1.0, 0.80, v_hang);
			vec3 gl = rustic_light_m(vec3(0.0, 1.0, 0.0), v_light, 0.0, vec3(v_origin.x, v_gy + 0.04, v_origin.y), vec3(0.34, 0.52, 0.47), 3.0, ATTENUATION);
			DIFFUSE_LIGHT += out_color(gc * tone * gl);
		} else {
			float cls = patch_class(v_origin); vec3 col = rustic_patch_color(cls);
			float rv = hash21(floor(v_origin * 7.0) + v_seed);
			col *= mix(0.79, 1.16, v_uv.y); col *= 0.85 + 0.17 * rv;
			float a = v_seed * 31.4159; float lean = cls < 0.5 ? 0.18 : (cls < 1.5 ? 0.25 : 0.21);
			vec3 N = normalize(vec3(cos(a) * lean, 1.0, sin(a) * lean));
			vec3 lt = rustic_light_m(N, v_light, 0.0, v_wpos, vec3(0.34, 0.52, 0.47), 3.0, ATTENUATION);
			lt = quantize(lt, FRAGCOORD.xy);
			DIFFUSE_LIGHT += out_color(col * lt);
		}
	}
}
