// Personaggi, armi e manichini (M4): pezzi a facce piatte con colore nei
// vertici, stessa luce "rustica" a bande dei blocchi e degli alberi.
// sun_here/blk_here: luce del voxel dove sta l'attore (0..1); flash: lampo
// bianco del colpo; tint: moltiplicatore (bersaglio agganciato, carica).
shader_type spatial;
render_mode cull_back, specular_disabled, ambient_light_disabled, fog_disabled;

#include "res://src/presentation/shaders/rustic.gdshaderinc"

instance uniform float sun_here = 1.0;
instance uniform float blk_here = 0.0;
instance uniform float flash = 0.0;
instance uniform vec3 tint = vec3(1.0);

varying vec3 v_world;
varying vec3 v_color;
varying vec3 v_n;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_color = COLOR.rgb * tint;
	v_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (v_world.y > slice_y + 1.0) discard;
	ALBEDO = vec3(1.0);
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		vec3 lt = rustic_light_m(v_n, sun_here, blk_here, v_world, shade_tint(v_color), 3.0, ATTENUATION);
		lt = quantize(lt, FRAGCOORD.xy);
		vec3 c = mix(v_color * lt, vec3(1.0, 0.97, 0.9), clamp(flash, 0.0, 1.0));
		DIFFUSE_LIGHT += out_color(c);
	}
}
