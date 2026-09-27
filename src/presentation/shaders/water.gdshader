// Acqua: porting di waterVS/waterFS (HTML ~5578). Superficie con correnti
// trasportate (due fasi sfalsate), riflesso, schiuma a riva e anelli d'impulso;
// lati delle cascate a nastri con schiuma d'impatto; lati e fondo pieni.
// CUSTOM0 = aW (profondita', riva / quota relativa, tipo), CUSTOM1 = aFlow.
// Disegnata dopo il quad di post (render_priority), quindi applica da se' la
// parte di colore del blit (post_color).
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, specular_disabled, ambient_light_disabled, fog_disabled;

#include "res://src/presentation/shaders/rustic.gdshaderinc"
#include "res://src/presentation/shaders/post_common.gdshaderinc"

global uniform float water_time;
global uniform vec3 sky_tint;
uniform vec4 impulses[16];
uniform vec2 impulse_meta[16];

varying vec3 v_w;
varying vec3 v_a;
varying vec3 v_flow;
varying vec3 v_n;
// Dal fragment alla luce: colore non illuminato e tipo (0 superficie, 1 cascata, 2 lato/fondo).
varying vec3 v_col;
varying float v_kind;

float advected(vec2 uv, vec2 velocity, float time) {
	float a = fract(time * 0.35), b = fract(time * 0.35 + 0.5), w = 1.0 - abs(2.0 * a - 1.0);
	return vnoise(uv - velocity * a * 2.857) * w + vnoise(uv - velocity * b * 2.857 + vec2(5.2, 1.7)) * (1.0 - w);
}

void vertex() {
	v_w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_a = CUSTOM0.xyz;
	v_flow = CUSTOM1.xyz;
	v_n = NORMAL;
}

void fragment() {
	float t = water_time;
	vec3 normal = normalize(v_n);
	if (v_a.z > 1.5) {
		float f = advected(v_w.xz * 1.6 + v_w.y * 0.3, v_flow.xy * 1.6, t);
		v_col = mix(vec3(0.12, 0.37, 0.46), vec3(0.18, 0.49, 0.55), f);
		v_kind = 2.0;
		ALPHA = 0.68;
	} else if (v_a.z > 0.5) {
		// Il tempo positivo in y del mondo muove i nastri VERSO IL BASSO.
		float across = dot(v_w.xz, vec2(-normal.z, normal.x));
		float travel = sqrt(max(0.0, v_a.x - v_a.y) + 0.18);
		vec2 uv = vec2(across * 2.7, travel * 2.8 - t * 3.2);
		float broad = vnoise(uv), fine = vnoise(uv * vec2(2.1, 0.7) + vec2(9.1, -t * 0.3));
		float ribbon = smoothstep(0.59, 0.82, broad * 0.72 + fine * 0.28);
		float impact = (1.0 - smoothstep(0.0, 0.65, v_a.y)) * smoothstep(0.3, 1.6, v_a.x);
		float lip = (1.0 - smoothstep(0.0, 0.16, v_a.x - v_a.y)) * 0.28;
		float foam = clamp(ribbon * 0.32 + impact * (0.58 + 0.25 * fine) + lip, 0.0, 0.9);
		vec3 col = mix(vec3(0.16, 0.46, 0.54), vec3(0.30, 0.65, 0.69), broad);
		v_col = mix(col, vec3(0.81, 0.94, 0.92), foam);
		v_kind = 1.0;
		ALPHA = 0.80 + foam * 0.12;
	} else {
		vec2 uv = v_w.xz; float speed = length(v_flow.xy);
		vec2 velocity = v_flow.xy + vec2(0.018, 0.011);
		float wave = advected(uv * 2.3, velocity * 2.3, t);
		float fine = advected(uv * 5.1, velocity * 5.1, t * 0.91);
		float dx = dFdx(wave), dy = dFdy(wave);
		float glint = clamp((dx - dy) * 2.4, -0.12, 0.12);
		float depth = max(0.0, v_a.x);
		vec3 col = mix(vec3(0.30, 0.64, 0.62), vec3(0.12, 0.39, 0.50), smoothstep(0.5, 3.8, depth));
		col *= 0.9 + wave * 0.21 + glint;
		col = mix(col, sky_tint, 0.12);
		float foam = (1.0 - smoothstep(0.18, 0.4, v_a.y)) * smoothstep(0.56, 0.78, fine) * 0.42;
		// La schiuma viaggia nel verso della corrente di nuoto.
		foam = max(foam, smoothstep(0.76, 0.9, wave) * min(speed, 0.8) * 0.3);
		for (int i = 0; i < 16; i++) {
			vec4 imp = impulses[i]; float age = water_time - imp.z;
			if (imp.w > 0.001 && age >= 0.0 && age < 2.4 && abs(impulse_meta[i].x - v_w.y) < 0.25 && abs(impulse_meta[i].y - v_flow.z) < 0.25) {
				vec2 origin = imp.xy + v_flow.xy * age * 0.45;
				float radius = 0.10 + age * (0.85 + imp.w * 0.4), dist = abs(length(uv - origin) - radius);
				foam = max(foam, (1.0 - smoothstep(0.025, 0.095, dist)) * (1.0 - age / 2.4) * min(1.0, imp.w) * 0.85);
			}
		}
		float fresnel = pow(1.0 - clamp(dot(normalize(view_dir), normal), 0.0, 1.0), 3.0);
		col = mix(col, sky_tint, 0.07 + fresnel * 0.18);
		v_col = mix(col, vec3(0.84, 0.95, 0.92), foam);
		v_kind = 0.0;
		ALPHA = mix(0.56, 0.82, smoothstep(0.5, 3.5, depth)) + foam * 0.1;
	}
	ALBEDO = vec3(1.0);
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		vec3 normal = normalize(v_n);
		// Nel prototipo il materiale dell'acqua non riceve la shadow map (HTML 6758):
		// worldShadow legge una texture vuota e vale 1 - uShadowStrength entro il
		// riquadro d'ombra attorno al giocatore. E' la resa blu scura della reference.
		vec3 lt = rustic_light_m(normal, 1.0, 0.0, v_w + normal * 0.035, vec3(0.30, 0.42, 0.62), 3.0, 0.0);
		vec3 c = v_kind > 0.5 && v_kind < 1.5 ? v_col * mix(lt, vec3(1.0), 0.16) : v_col * lt;
		vec2 suv = FRAGCOORD.xy / VIEWPORT_SIZE;
		c = post_color(c, vec2(suv.x, 1.0 - suv.y));
		DIFFUSE_LIGHT += out_color(c);
	}
}
