// Alberi a clump: porting di treeVS/treeFS (HTML ~5392). Geometria gia' in
// coordinate di mondo; CUSTOM0 = vento, seme, quota del piede, luce solare.
shader_type spatial;
render_mode cull_back, specular_disabled, ambient_light_disabled, fog_disabled;

#include "res://src/presentation/shaders/rustic.gdshaderinc"

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
		DIFFUSE_LIGHT += to_linear(v_color * lt);
	}
}
