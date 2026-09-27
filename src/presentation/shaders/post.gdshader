// Post-processing del render target a bassa risoluzione: porting di blitFS
// (contorni e spigoli dalla profondita', raggi, nebbia in prospettiva, notte,
// color grading) e di skyFS per i pixel di cielo (HTML ~5214 e ~5640).
// Quad a tutto schermo figlio della camera, disegnato per ultimo.
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

#include "res://src/presentation/shaders/rustic.gdshaderinc"
#include "res://src/presentation/shaders/post_common.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;

global uniform vec3 sky_horizon;
global uniform vec3 sky_top;
global uniform vec2 sun_uv;
global uniform float sun_vis;
global uniform float sun_elev;
global uniform float horizon_v;
global uniform vec3 fog_color;
global uniform float px_h;
global uniform float persp;
global uniform float outline_on;
global uniform float edges_on;
global uniform float rays_on;

float raw_depth(vec2 uv) { return texture(depth_tex, uv).r; }

bool is_sky(float d) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return d >= 0.99999;
#else
	return d <= 0.00001;
#endif
}

// Distanza lungo la vista in unita' di mondo (lin() del prototipo).
float lin_at(vec2 uv, float d, mat4 inv_proj) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv * 2.0 - 1.0, d * 2.0 - 1.0);
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, d);
#endif
	vec4 v = inv_proj * vec4(ndc, 1.0);
	return -v.z / v.w;
}

vec3 sky_color(vec2 v) {
	float hv = (v.y - horizon_v) / max(1.0 - horizon_v, 0.05); float up = clamp(hv, 0.0, 1.0); float horizon_band = exp(-abs(hv) * 7.5);
	vec3 col = mix(sky_horizon, sky_top, pow(up, 0.52)); col = mix(col, sky_horizon, horizon_band * 0.55);
	float low = 1.0 - smoothstep(0.0, 0.35, abs(sun_elev)); col += sun_color * exp(-abs(hv) * 9.0) * low * 0.35;
	vec2 wp = v * vec2(120.0, 60.0) + vec2(0.2148, 0.9767) * world_time * 0.6;
	float q = vnoise(wp * 0.06), detail = vnoise(wp * 0.13 + vec2(17.2, -9.4)); float density = q * 0.78 + detail * 0.22;
	float clouds = smoothstep(0.62, 0.77, density) * smoothstep(0.15, 0.6, hv);
	vec3 cloud_shade = mix(vec3(0.48, 0.50, 0.52), vec3(0.79, 0.73, 0.62), 0.6) * (0.15 + 0.85 * sun_level); cloud_shade = mix(cloud_shade, vec3(0.12, 0.14, 0.22), night * 0.8);
	col = mix(col, cloud_shade, clouds * 0.36);
	vec2 p = floor(v * vec2(480.0, 270.0)); vec2 sp = floor(sun_uv * vec2(480.0, 270.0)); float dd = length(p - sp);
	if (sun_elev > -0.05) { float disc = 1.0 - smoothstep(4.0, 5.0, dd); float halo = exp(-dd * 0.08) * 0.25; col += sun_color * (disc * 0.9 + halo) * (1.0 - clouds * 0.5); }
	else { float disc = 1.0 - smoothstep(3.0, 4.0, dd); col += vec3(0.75, 0.80, 0.92) * disc * 0.8; }
	float h = fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); col += vec3(step(0.997, h) * night * 0.8 * (1.0 - clouds));
	float lum = dot(col, vec3(0.299, 0.587, 0.114)); col = mix(col, vec3(lum), horizon_band * 0.10);
	return col;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 res = VIEWPORT_SIZE;
	vec2 px = 1.0 / res;
	vec2 uv = (floor(SCREEN_UV * res) + 0.5) * px;
	vec2 v = vec2(uv.x, 1.0 - uv.y); // coordinate del prototipo (y in alto)
	mat4 ip = INV_PROJECTION_MATRIX;
	float dc = raw_depth(uv);
	bool sky = is_sky(dc);
	vec3 col = sky ? sky_color(v) : (texture(screen_tex, uv).rgb);
	if (outline_on > 0.5 && !sky) {
		float lc = lin_at(uv, dc, ip); float m = 0.0;
		vec2 oR = vec2(px.x, 0.0), oU = vec2(0.0, px.y);
		float dR = raw_depth(uv + oR), dL = raw_depth(uv - oR), dU = raw_depth(uv + oU), dD = raw_depth(uv - oU);
		float lR = is_sky(dR) ? 0.0 : lin_at(uv + oR, dR, ip) - lc, lL = is_sky(dL) ? 0.0 : lin_at(uv - oR, dL, ip) - lc;
		float lU = is_sky(dU) ? 0.0 : lin_at(uv + oU, dU, ip) - lc, lD = is_sky(dD) ? 0.0 : lin_at(uv - oU, dD, ip) - lc;
		if (!is_sky(dR)) m = max(m, lR); if (!is_sky(dL)) m = max(m, lL); if (!is_sky(dU)) m = max(m, lU); if (!is_sky(dD)) m = max(m, lD);
		vec2 q1 = uv + px, q2 = uv - px, q3 = uv + vec2(px.x, -px.y), q4 = uv + vec2(-px.x, px.y);
		float d1 = raw_depth(q1), d2 = raw_depth(q2), d3 = raw_depth(q3), d4 = raw_depth(q4);
		if (!is_sky(d1)) m = max(m, (lin_at(q1, d1, ip) - lc) * 0.8); if (!is_sky(d2)) m = max(m, (lin_at(q2, d2, ip) - lc) * 0.8);
		if (!is_sky(d3)) m = max(m, (lin_at(q3, d3, ip) - lc) * 0.8); if (!is_sky(d4)) m = max(m, (lin_at(q4, d4, ip) - lc) * 0.8);
		float thr = persp > 0.5 ? 0.42 * (1.0 + lc * 0.10) : 0.42; float e = smoothstep(thr, thr * 2.4, m);
		float warm = smoothstep(0.02, 0.28, col.r - col.b), green = smoothstep(0.0, 0.15, col.g - max(col.r, col.b));
		vec3 ink = mix(mix(vec3(0.34, 0.40, 0.62), vec3(0.56, 0.34, 0.42), warm), vec3(0.28, 0.46, 0.44), green); col = mix(col, col * ink, e * 0.86);
		if (edges_on > 0.5 && persp < 0.5 && e < 0.05 && !is_sky(dR) && !is_sky(dL) && !is_sky(dU) && !is_sky(dD)) {
			float mx = max(max(abs(lR), abs(lL)), max(abs(lU), abs(lD)));
			if (mx < thr * 0.5) {
				float lx = lR + lL, ly = lU + lD; bool hor = abs(lx) > abs(ly); float lap = hor ? lx : ly; float k = max(px_h * 1.05, 0.012);
				vec2 ax = hor ? oR : oU;
				float dP2 = raw_depth(uv + ax * 2.0), dM2 = raw_depth(uv - ax * 2.0), dP1 = hor ? dR : dU, dM1 = hor ? dL : dD;
				float lP1 = lin_at(uv + ax, dP1, ip), lM1 = lin_at(uv - ax, dM1, ip);
				float flatP = abs((lin_at(uv + ax * 2.0, dP2, ip) - lP1) - (lP1 - lc)), flatM = abs((lin_at(uv - ax * 2.0, dM2, ip) - lM1) - (lM1 - lc));
				if (is_sky(dP2) || is_sky(dM2) || min(flatP, flatM) > k * 0.35) lap = 0.0;
				if (abs(dP1 - dc) < 1e-7 || abs(dM1 - dc) < 1e-7) lap = 0.0;
				vec3 W = vec3(0.299, 0.587, 0.114); float y0 = dot(col, W);
				float yA = dot((texture(screen_tex, uv + ax).rgb), W), yB = dot((texture(screen_tex, uv - ax).rgb), W);
				float yN = max(yA, yB), yn = min(yA, yB);
				if (lap > k && y0 >= yN - 0.004) col = min(col * 1.22 + vec3(0.030, 0.028, 0.018) * (1.0 - night), vec3(1.0));
				else if (lap < -k && y0 <= yn + 0.004) col *= mix(vec3(1.0), ink * 1.55, 0.55);
			}
		}
	}
	if (persp > 0.5 && !sky) { float fz = lin_at(uv, dc, ip); col = mix(col, fog_color, smoothstep(38.0, 90.0, fz) * 0.96); }
	if (rays_on > 0.5 && sun_vis > 0.0) {
		vec2 d = sun_uv - v; float dist = length(d); vec2 stp = d / 12.0; float acc = 0.0, wsum = 0.0, w = 1.0; vec2 q = v;
		for (int i = 0; i < 12; i++) {
			q += stp; vec2 qs = (floor(vec2(q.x, 1.0 - q.y) * res) + 0.5) * px;
			float skyq = is_sky(raw_depth(qs)) ? 1.0 : 0.0; acc += skyq * w; wsum += w; w *= 0.90;
		}
		acc /= wsum; float fall = exp(-dist * 2.4); col += sun_color * fall * acc * sun_vis * 0.3;
	}
	col = post_color(col, v);
	ALBEDO = out_color(col);
}
