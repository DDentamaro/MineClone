// Acqua provvisoria (fino alla mesh dei fluidi di M3): colore e luce del
// waterFS del prototipo, trasparenza resa con dithering Bayer nel passo opaco
// (cosi' il post-processing la vede come il resto della scena).
shader_type spatial;
render_mode cull_disabled, specular_disabled, ambient_light_disabled, fog_disabled;

#include "res://src/presentation/shaders/rustic.gdshaderinc"

varying vec3 v_world;
varying vec3 v_n;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_n = NORMAL;
}

void fragment() {
	if (bayer(FRAGCOORD.xy) > 0.68) discard;
	ALBEDO = vec3(1.0);
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		vec3 lt = rustic_light_m(v_n, 1.0, 0.0, v_world + v_n * 0.035, vec3(0.30, 0.42, 0.62), 3.0, ATTENUATION);
		float wave = vnoise(v_world.xz * 2.3 + vec2(world_time * 0.35, world_time * 0.2));
		vec3 col = mix(vec3(0.30, 0.64, 0.62), vec3(0.12, 0.39, 0.50), 0.5) * (0.9 + wave * 0.21);
		DIFFUSE_LIGHT += to_linear(col * lt);
	}
}
