// Alberi a clump: porting di treeVS/treeFS (HTML ~5392). Geometria gia' in
// coordinate di mondo; CUSTOM0 = vento, seme, quota del piede, luce solare.
shader_type spatial;
render_mode cull_back, specular_disabled, ambient_light_disabled, fog_disabled;

#include "res://src/presentation/shaders/rustic.gdshaderinc"

global uniform vec3 tree_hit;
global uniform vec2 tree_hit_dir;

varying vec3 v_world;
varying vec3 v_color;
varying float v_light;
varying vec3 v_n;

void vertex() {
	float wind_k = CUSTOM0.x, seed = CUSTOM0.y, base_y = CUSTOM0.z;
	float qt = floor((world_time + seed * 0.37) * 5.0 + 0.5) / 5.0;
	float sway = (sin(qt * 1.15 + seed * 6.283) + sin(qt * 0.63 + seed * 11.7) * 0.45) * 0.5;
	float w = clamp(wind_k, 0.0, 1.0);
	VERTEX.xz += normalize(vec2(0.22, 1.0)) * sway * 0.085 * w * w;
	// Albero colpito (shakeTree): oscillazione smorzata di quello con questo seme.
	if (abs(seed - tree_hit.x) < 1e-4) { float dth = world_time - tree_hit.y;
		if (dth >= 0.0 && dth < 1.2) { float amp = tree_hit.z * exp(-dth * 5.5) * sin(dth * 34.0); float hk = clamp((VERTEX.y - base_y) / 5.0, 0.0, 1.0); VERTEX.xz += tree_hit_dir * amp * 0.16 * hk; } }
	if (base_y > slice_y + 0.5) VERTEX = vec3(0.0, -1000.0, 0.0);
	v_world = VERTEX;
	v_color = COLOR.rgb;
	v_light = CUSTOM0.w;
	v_n = NORMAL;
}

void fragment() {
	if (v_world.y > slice_y + 1.0) discard;
	if (v_world.y > xray_floor && xray_occludes(SCREEN_UV, FRAGCOORD.xy, -VERTEX.z, VIEWPORT_SIZE)) discard;
	ALBEDO = vec3(1.0);
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		vec3 lt = rustic_light_m(v_n, v_light, 0.0, v_world, shade_tint(v_color), 3.0, ATTENUATION);
		if (paint_mode > 0.5) {
			float leaf = smoothstep(0.0, 0.12, v_color.g - max(v_color.r, v_color.b));
			float back = max(dot(-normalize(v_n), normalize(sun_dir)), 0.0); back = floor(back * 2.0 + 0.5) / 2.0;
			lt += sun_color * vec3(1.0, 1.05, 0.55) * (sun_intensity * 0.26 * back * leaf * pow(v_light, 1.35) * (1.0 - night));
		}
		lt = quantize(lt, FRAGCOORD.xy);
		vec3 col = v_color;
		if (look_hd > 0.5) {
			// D-063: foglie con macchie di luce e ombra, corteccia a solchi.
			float leafy = step(max(v_color.r, v_color.b), v_color.g);
			vec3 cell = floor(v_world * 11.0);
			float spots = vnoise(v_world.xz * 4.0 + v_world.y * 2.3) * 0.7 + hash21(cell.xy + cell.z * 5.1) * 0.3;
			float ridges = vnoise(vec2((v_world.x + v_world.z) * 18.0, v_world.y * 2.5));
			col *= mix(0.88 + 0.22 * ridges, 0.80 + 0.32 * spots, leafy);
		}
		DIFFUSE_LIGHT += out_color(col * lt);
	}
}
