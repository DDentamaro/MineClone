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
// D-063 (piano grafico F7): punto nello spazio del pezzo, per la grana.
varying vec3 v_local;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_local = VERTEX;
	v_color = COLOR.rgb * tint;
	v_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (v_world.y > slice_y + 1.0) discard;
	ALBEDO = vec3(1.0);
}

// Texture dei personaggi nella resa nitida (D-063): grana a texel come le skin
// dei voxel (stoffa e cuoio), metallo che luccica sotto il sole, pelle
// liscia; luce di contorno per staccare la figura dal fondo.
vec3 hd_actor(vec3 col, vec3 lt) {
	float mx = max(col.r, max(col.g, col.b)), mn = min(col.r, min(col.g, col.b));
	float sat = (mx - mn) / max(mx, 1e-3);
	vec3 N = normalize(v_n);
	vec3 V = normalize(view_dir);
	vec3 L = normalize(sun_dir);
	bool metal = sat < 0.12 && mx > 0.35;
	bool skin = col.r > col.g && col.g > col.b && sat > 0.2 && sat < 0.62 && mx > 0.45;
	vec3 q = floor(v_local * 22.0);
	float tex = hash21(q.xy + q.z * 7.3);
	if (metal) {
		col *= 0.94 + 0.08 * tex;
		float spec = pow(max(dot(N, normalize(L + V)), 0.0), 36.0);
		col += vec3(1.0, 0.95, 0.85) * spec * 0.28 * sun_level * sun_here;
	} else if (!skin) {
		// Stoffa e cuoio: trama fine a due toni.
		float weave = hash21(floor(v_local.xy * 44.0) + floor(v_local.z * 44.0));
		col *= 0.92 + 0.10 * tex + 0.04 * weave;
	}
	vec3 c = col * lt;
	float rim = pow(1.0 - max(dot(N, V), 0.0), 3.0) * (1.0 - night) * sun_level;
	c += sun_color * rim * 0.16;
	return c;
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		vec3 lt = rustic_light_m(v_n, sun_here, blk_here, v_world, shade_tint(v_color), 3.0, ATTENUATION);
		lt = quantize(lt, FRAGCOORD.xy);
		vec3 base = look_hd > 0.5 ? hd_actor(v_color, lt) : v_color * lt;
		vec3 c = mix(base, vec3(1.0, 0.97, 0.9), clamp(flash, 0.0, 1.0));
		DIFFUSE_LIGHT += out_color(c);
	}
}
