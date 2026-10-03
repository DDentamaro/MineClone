// Blocchi voxel: porting di chunkVS/chunkFS (HTML ~5278), stile "dipinto".
// CUSTOM0 = aData del prototipo: tile, faccia|cut<<3|ao<<4, sole, luce blocchi.
// L'illuminazione e' in light(): l'ombra direzionale di Godot (ATTENUATION)
// sostituisce la shadow map del prototipo.
shader_type spatial;
render_mode cull_back, specular_disabled, ambient_light_disabled, fog_disabled;

#include "res://src/presentation/shaders/rustic.gdshaderinc"

uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;

varying flat float v_tile;
varying flat float v_face;
varying flat float v_cut;
varying flat vec2 v_light;
varying float v_ao;
varying vec3 v_world;
// Dal fragment alla funzione light().
varying vec3 v_col;
varying vec3 v_wq;
varying vec3 v_S;
varying float v_bands;
varying float v_emissive;
varying vec2 v_sp;
varying vec3 v_n;

// D-054: marmo dell'arena (come il ring del torneo di Cell): piastrelle chiare
// di 2x2 blocchi con le fughe scure e una leggera variazione per piastrella.
vec3 marble_color(vec2 sp, int face) {
	vec2 q = sp * 0.5;
	vec2 f = fract(q);
	float seam = (f.x < 0.035 || f.y < 0.035) ? 1.0 : 0.0;
	if (face != 2) seam = (fract(sp.y) < 0.06) ? 1.0 : 0.0;
	float k = hash21(floor(q) + vec2(5.0, 11.0));
	vec3 base = mix(vec3(0.78, 0.77, 0.73), vec3(0.86, 0.85, 0.80), k);
	base *= 0.97 + 0.06 * vnoise(sp * 2.3 + vec2(1.0, 4.0));
	return mix(base, vec3(0.42, 0.42, 0.42), seam * 0.75);
}

void vertex() {
	vec4 d = round(CUSTOM0 * 255.0);
	v_tile = d.x;
	v_face = mod(d.y, 8.0);
	v_cut = step(8.0, mod(d.y, 16.0));
	v_ao = floor(d.y / 16.0);
	v_light = d.zw / 15.0;
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (v_world.y > xray_floor && xray_occludes(SCREEN_UV, FRAGCOORD.xy, -VERTEX.z, VIEWPORT_SIZE)) discard;
	float tile = v_tile;
	int face = int(v_face + 0.5);
	vec2 uv = fract(UV); if (face < 2) uv = uv.yx;
	float row = (face == 2) ? 0.0 : 1.0;
	vec3 tex = texture(atlas, vec2((tile + uv.x) / 16.0, (row + uv.y) / 2.0)).rgb;
	float lum = dot(tex, vec3(0.299, 0.587, 0.114));
	vec3 N = vec3(0.0);
	if (face == 0) N.x = 1.0; else if (face == 1) N.x = -1.0; else if (face == 2) N.y = 1.0; else if (face == 3) N.y = -1.0; else if (face == 4) N.z = 1.0; else N.z = -1.0;
	vec2 sp = (face == 2 || face == 3) ? v_world.xz : ((face < 2) ? vec2(v_world.z, v_world.y) : vec2(v_world.x, v_world.y));
	vec3 col;
	vec3 S = vec3(0.40); float bands = 3.0; vec3 wq = v_world;
	if (paint_mode > 0.5) {
		vec2 spq = (floor(sp * 16.0) + 0.5) / 16.0; float th = hash21(floor(sp * 16.0) + vec2(3.7, 9.1)); float th2 = hash21(floor(sp * 16.0) + vec2(41.0, 17.0));
		wq = (face == 2 || face == 3) ? vec3(spq.x, v_world.y, spq.y) : ((face < 2) ? vec3(v_world.x, spq.y, spq.x) : vec3(spq.x, spq.y, v_world.z));
		float n1 = vnoise((floor(sp * 8.0) + 0.5) / 8.0 * 0.62 + vec2(7.0, 1.0)) + (hash21(floor(sp * 8.0) + vec2(6.0, 4.0)) - 0.5) * 0.22 + (th - 0.5) * 0.08;
		int tone = n1 < 0.40 ? 0 : (n1 < 0.66 ? 1 : 2);
		if (tile == 1.0 && face == 2) {
			col = paint_grass_color(sp, th, th2);
			float tuft = hash21(floor(sp * 8.0) + vec2(2.0, 31.0)); if (tuft > 0.90 && th > 0.35) col *= 1.16; else if (tuft < 0.08 && th > 0.35) col *= 0.88; S = vec3(0.34, 0.52, 0.47);
		} else if (tile == 1.0 || tile == 2.0) {
			col = tone == 0 ? vec3(0.285, 0.215, 0.125) : (tone == 1 ? vec3(0.340, 0.265, 0.150) : vec3(0.395, 0.315, 0.180)); S = vec3(0.50, 0.42, 0.55);
			if (tile == 1.0) {
				float lip_h = 0.56 - floor(hash21(vec2(floor(sp.x * 16.0), 7.0)) * 4.0) / 16.0;
				if (uv.y > lip_h) {
					col = paint_grass_color((face < 2) ? vec2(v_world.x + (face == 0 ? -0.02 : 0.02), v_world.z) : vec2(v_world.x, v_world.z + (face == 4 ? -0.02 : 0.02)), 0.5, 0.5) * (uv.y > lip_h + 0.14 ? 1.0 : 0.86);
					S = vec3(0.34, 0.52, 0.47);
				}
			}
		} else if (tile == 3.0) { col = tone == 0 ? vec3(0.300, 0.295, 0.275) : (tone == 1 ? vec3(0.365, 0.350, 0.310) : vec3(0.430, 0.405, 0.345)); S = vec3(0.42, 0.47, 0.66); bands = 4.0; }
		else if (tile == 14.0) { col = tone == 0 ? vec3(0.205, 0.200, 0.200) : (tone == 1 ? vec3(0.250, 0.240, 0.230) : vec3(0.300, 0.280, 0.260)); S = vec3(0.40, 0.44, 0.66); bands = 4.0; }
		else if (tile == 4.0) { col = tone == 0 ? vec3(0.520, 0.455, 0.265) : (tone == 1 ? vec3(0.580, 0.515, 0.305) : vec3(0.635, 0.570, 0.355)); S = vec3(0.62, 0.50, 0.58); }
		else if (tile == 13.0) { float st = floor(sp.y * 16.0); float k = hash21(vec2(st, 3.0)); col = k < 0.34 ? vec3(0.415, 0.375, 0.190) : (k < 0.67 ? vec3(0.470, 0.430, 0.215) : vec3(0.520, 0.480, 0.250)); S = vec3(0.60, 0.48, 0.56); }
		else if (tile == 16.0) { col = marble_color(sp, face); S = vec3(0.46, 0.48, 0.62); bands = 4.0; }
		else { col = tex; S = shade_tint(tex); if (tile >= 5.0 && tile <= 7.0 && lum > 0.55 && th > 0.80) col *= 1.35; }
	} else {
		float speck = hash21(floor(sp * 4.0));
		if (tile == 1.0) {
			vec3 g = rustic_blend(v_world.xz); float macro = vnoise(v_world.xz * 0.11 + vec2(9.3, 2.1)); g *= 0.90 + 0.16 * macro;
			if (face == 2) col = g; else { float lip = smoothstep(0.70, 0.86, uv.y); col = mix(vec3(0.325, 0.255, 0.145) * (0.9 + 0.2 * vnoise(sp * 0.9)), g * 0.9, lip); }
		} else if (tile == 2.0) { col = vec3(0.325, 0.255, 0.145) * (0.86 + 0.24 * vnoise(sp * 0.7 + vec2(2.0, 5.0))); }
		else if (tile == 3.0) { col = mix(vec3(0.335, 0.305, 0.245), vec3(0.40, 0.36, 0.28), vnoise(sp * 0.6 + vec2(7.0, 1.0))); }
		else if (tile == 14.0) { col = mix(vec3(0.245, 0.225, 0.195), vec3(0.30, 0.27, 0.24), vnoise(sp * 0.6 + vec2(3.0, 9.0))); }
		else if (tile == 4.0) { col = vec3(0.56, 0.50, 0.30) * (0.9 + 0.18 * vnoise(sp * 0.5)); }
		else if (tile == 13.0) { col = vec3(0.445, 0.415, 0.205) * (0.86 + 0.2 * vnoise(vec2(sp.x * 0.3, sp.y * 1.4))); }
		else if (tile == 16.0) { col = marble_color(sp, face); }
		else col = tex;
		col *= 0.92 + 0.16 * (lum - 0.5) + 0.04 * speck;
	}
	v_col = col; v_wq = wq; v_S = S; v_bands = bands; v_sp = sp; v_n = N;
	v_emissive = (tile == 9.0 || tile == 10.0) ? 1.0 : 0.0;
	ALBEDO = vec3(1.0);
}

void light() {
	if (LIGHT_IS_DIRECTIONAL) {
		vec3 lt;
		if (v_emissive > 0.5) {
			lt = vec3(1.15);
			if (paint_mode > 0.5) {
			float ph = hash21(floor(v_sp * 8.0) + vec2(12.0, 3.0)); float pulse = floor(fract(ph + world_time * 0.35) * 3.0) / 3.0; lt *= 0.86 + 0.34 * pulse;
			}
		} else {
			lt = rustic_light_m(v_n, v_light.x, v_light.y, v_wq, v_S, v_bands, ATTENUATION);
		}
		float fill = 0.30 * (1.0 - smoothstep(0.0, 5.0, slice_y - v_world.y));
		lt = max(lt, vec3(fill * 0.85, fill * 0.9, fill));
		if (v_emissive < 0.5) {
			float ao = clamp(v_ao / 3.0, 0.0, 1.0);
			float aok = ao * ao * (3.0 - 2.0 * ao) * 0.9 + 0.1 * ao;
			if (paint_mode > 0.5) lt *= mix(mix(vec3(0.62, 0.64, 0.72), v_S / 0.40 * 0.62, 0.30), vec3(1.0), aok);
			else lt *= mix(vec3(0.50, 0.54, 0.66), vec3(1.0), aok);
		}
		lt = max(min(lt, vec3(1.25)), vec3(0.030, 0.034, 0.055));
		lt = quantize(lt, FRAGCOORD.xy);
		vec3 c = v_col * lt;
		if (v_cut > 0.5) {
			c *= 0.78;
			bool chk = paint_mode > 0.5 ? mod(floor(v_sp.x * 16.0) + floor(v_sp.y * 16.0), 4.0) < 1.0 : mod(floor(FRAGCOORD.x + FRAGCOORD.y), 4.0) < 1.0;
			if (chk) c *= 0.80;
		}
		DIFFUSE_LIGHT += out_color(c);
	}
}
