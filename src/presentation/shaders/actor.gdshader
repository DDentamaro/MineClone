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
// D-065: normale nello spazio del pezzo e materiale (alfa del colore, vedi
// ArmorKit: 1 automatico, .9 piastra, .8 cuoio, .7 stoffa, .6 maglia,
// .5 ottone, .4 pelliccia, .3 cordino).
varying vec3 v_ln;
varying float v_mat;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_local = VERTEX;
	v_ln = NORMAL;
	v_mat = COLOR.a;
	v_color = COLOR.rgb * tint;
	v_n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (v_world.y > slice_y + 1.0) discard;
	ALBEDO = vec3(1.0);
}

// Texture dei personaggi nella resa nitida (D-063, materiali D-065): ogni
// materiale ha la sua trama sul piano della faccia del pezzo, e i metalli
// luccicano sotto il sole.
vec2 face_uv(vec3 p, vec3 n) {
	vec3 a = abs(n);
	return a.x > a.y && a.x > a.z ? p.zy : (a.y > a.z ? p.xz : p.xy);
}

float spec_of(vec3 N, vec3 V, vec3 L, float e) {
	return pow(max(dot(N, normalize(L + V)), 0.0), e);
}

vec3 hd_actor(vec3 col, vec3 lt) {
	float mx = max(col.r, max(col.g, col.b)), mn = min(col.r, min(col.g, col.b));
	float sat = (mx - mn) / max(mx, 1e-3);
	vec3 N = normalize(v_n);
	vec3 V = normalize(view_dir);
	vec3 L = normalize(sun_dir);
	vec2 uv = face_uv(v_local, v_ln);
	vec3 q = floor(v_local * 22.0);
	float tex = hash21(q.xy + q.z * 7.3);
	float m = v_mat;
	float lit = sun_level * sun_here * (1.0 - night);
	vec3 warm = vec3(1.0, 0.94, 0.82);
	vec3 add = vec3(0.0);
	if (m > 0.95) {
		// Automatico (corpo, vestiti del personaggio, armi).
		bool metal = sat < 0.12 && mx > 0.35;
		bool skin = col.r > col.g && col.g > col.b && sat > 0.2 && sat < 0.62 && mx > 0.45;
		if (metal) {
			col *= 0.94 + 0.08 * tex;
			add = warm * spec_of(N, V, L, 36.0) * 0.28 * lit;
		} else if (!skin) {
			float weave = hash21(floor(v_local.xy * 44.0) + floor(v_local.z * 44.0));
			col *= 0.92 + 0.10 * tex + 0.04 * weave;
		}
	} else if (m > 0.85) {
		// Piastra: spazzolata, graffi, macchie scure; riflesso caldo e un
		// bordo chiaro che prende il cielo.
		float brush = vnoise(vec2(uv.x * 90.0, uv.y * 6.0));
		float scratch = step(0.94, vnoise(uv * vec2(60.0, 8.0) + vec2(3.0, 1.0)));
		float stain = smoothstep(0.55, 0.8, vnoise(uv * 5.0 + vec2(9.0)));
		col = mix(col, vec3(dot(col, vec3(0.333))), 0.6);
		col *= (0.94 + 0.06 * brush) * (1.0 - 0.15 * stain) * (1.0 + 0.18 * scratch);
		add = warm * (spec_of(N, V, L, 48.0) * 0.55 + spec_of(N, V, L, 8.0) * 0.10) * lit;
		add += ambient_color * pow(1.0 - max(dot(N, V), 0.0), 2.0) * 0.12;
	} else if (m > 0.75) {
		// Cuoio: grana a pori, pieghe scure, lucido appena.
		float pore = hash21(floor(uv * 70.0));
		float crease = smoothstep(0.62, 0.78, vnoise(uv * vec2(9.0, 3.0)));
		col *= (0.90 + 0.12 * pore) * (1.0 - 0.16 * crease) * (0.94 + 0.10 * vnoise(uv * 14.0));
		add = warm * spec_of(N, V, L, 14.0) * 0.07 * lit;
	} else if (m > 0.65) {
		// Stoffa: trama a fili incrociati.
		vec2 w = uv * 60.0;
		float weave = abs(sin(w.x * 3.14159)) * 0.5 + abs(sin(w.y * 3.14159)) * 0.5;
		col *= 0.86 + 0.16 * weave + 0.05 * tex;
	} else if (m > 0.55) {
		// Maglia: anelli in file sfalsate, buchi scuri, riflesso a puntini.
		vec2 g = uv * vec2(34.0, 40.0);
		g.x += step(1.0, mod(floor(g.y), 2.0)) * 0.5;
		vec2 f = fract(g) - 0.5;
		float r = length(f * vec2(1.0, 1.3));
		float ring = smoothstep(0.16, 0.24, r) * (1.0 - smoothstep(0.38, 0.48, r));
		col = mix(col * 0.35, col * 1.12, ring);
		add = warm * spec_of(N, V, L, 20.0) * 0.30 * ring * lit;
	} else if (m > 0.45) {
		// Ottone: liscio, riflesso forte e caldo.
		col *= 0.94 + 0.08 * tex;
		add = vec3(1.0, 0.86, 0.55) * spec_of(N, V, L, 28.0) * 0.55 * lit;
	} else if (m > 0.35) {
		// Pelliccia: ciocche verso il basso, punte scure.
		float strand = vnoise(vec2(uv.x * 80.0, uv.y * 8.0));
		col *= 0.75 + 0.40 * strand;
	}
	vec3 c = col * lt + add;
	float rim = pow(1.0 - max(dot(N, V), 0.0), 3.0) * (1.0 - night) * sun_level;
	c += sun_color * rim * 0.16;
	return c;
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		// Metalli in ombra: tinta neutra (con quella automatica il ferro diventava blu).
		vec3 S = (v_mat > 0.55 && v_mat < 0.95) ? vec3(0.42, 0.42, 0.44) : shade_tint(v_color);
		vec3 lt = rustic_light_m(v_n, sun_here, blk_here, v_world, S, 3.0, ATTENUATION);
		lt = quantize(lt, FRAGCOORD.xy);
		vec3 base = look_hd > 0.5 ? hd_actor(v_color, lt) : v_color * lt;
		vec3 c = mix(base, vec3(1.0, 0.97, 0.9), clamp(flash, 0.0, 1.0));
		DIFFUSE_LIGHT += out_color(c);
	}
}
