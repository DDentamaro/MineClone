// Porting di RUSTIC_GLSL e LIGHT_GLSL del prototipo (HTML ~5117–5190).
// Convenzione: tutti i colori calcolati qui sono valori "di schermo" come nel
// prototipo (che scrive outColor senza conversioni); chi scrive l'output li
// converte in lineare con to_linear(), perche' Godot poi ricodifica in sRGB.

global uniform vec3 sun_dir;
global uniform vec3 sun_color;
global uniform vec3 ambient_color;
global uniform float sun_intensity;
global uniform float sun_level;
global uniform float night;
global uniform float world_time;
global uniform float cloud_cover;
global uniform float cloud_shadow_on;
global uniform float shadow_strength;
global uniform vec3 view_dir;
global uniform float paint_mode;
global uniform float dither_amount;
global uniform float slice_y;
global uniform vec2 world_xz;
global uniform sampler2D climate_tex : filter_linear, repeat_disable;
// Raggi X: capsula piedi-testa in SCREEN_UV, profondita' di vista del giocatore.
global uniform vec2 xray_a;
global uniform vec2 xray_b;
global uniform float xray_r;
global uniform float xray_amt;
global uniform float xray_depth;
global uniform float xray_floor;

vec3 to_linear(vec3 c) {
	c = max(c, vec3(0.0));
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

float hash21(vec2 p) { p = fract(p * vec2(123.34, 456.21)); p += dot(p, p + 45.32); return fract(p.x * p.y); }
float vnoise(vec2 p) {
	vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i), b = hash21(i + vec2(1.0, 0.0)), c = hash21(i + vec2(0.0, 1.0)), d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
vec4 rustic_weights(vec2 p) {
	vec2 warp = vec2(vnoise(p * 0.055 + vec2(3.1, 7.3)), vnoise(p * 0.055 + vec2(13.4, 1.9)));
	vec2 q = p + (warp - 0.5) * 10.0;
	float dry_base = vnoise(q * 0.085 + vec2(5.1, 11.7)); float dirt_base = vnoise(q * vec2(0.12, 0.09) + vec2(19.3, 2.4));
	float moss_base = vnoise(q * 0.11 + vec2(-7.0, 14.3)); float stripe = vnoise(vec2(q.x * 0.035 + 3.2, q.y * 0.11 - 2.8));
	float dry = smoothstep(0.48, 0.74, dry_base + stripe * 0.18 - 0.06); float dirt = smoothstep(0.60, 0.84, dirt_base + (1.0 - dry) * 0.06 - stripe * 0.12);
	float moss = smoothstep(0.54, 0.80, moss_base - dry * 0.22 + (1.0 - dirt) * 0.08); float olive = max(0.12, 1.0 - (dry * 0.75 + dirt * 0.95 + moss * 0.55));
	vec4 w = max(vec4(olive, dry, dirt, moss), 0.0); w /= max(dot(w, vec4(1.0)), 1e-4); return w;
}
vec3 paint_grass_color(vec2 sp, float th, float th2) {
	vec2 cl = floor(sp * 4.0);
	vec4 w = rustic_weights((cl + 0.5) / 4.0) + vec4(hash21(cl + vec2(1.0, 5.0)), hash21(cl + vec2(8.0, 2.0)), hash21(cl + vec2(5.0, 77.0)), hash21(cl + vec2(91.0, 13.0))) * 0.16 + vec4(th, th2, th, th2) * 0.05;
	vec2 cj = vec2(hash21(cl + vec2(33.0, 7.0)), hash21(cl + vec2(4.0, 61.0))) - 0.5;
	vec3 cm = texture(climate_tex, ((cl + 0.5) / 4.0) / world_xz).rgb; float t = cm.r + cj.x * 0.07, u = cm.g + cj.y * 0.07;
	int k = 0; if (w.y > w.x) k = 1; float m = max(w.x, w.y); if (w.z > m) { m = w.z; k = 2; } if (w.w > m) k = 3;
	if (cm.b > 0.5) return k == 1 ? vec3(0.46, 0.47, 0.42) : vec3(0.38, 0.41, 0.36);
	if (t < 0.27) return k == 0 ? vec3(0.520, 0.600, 0.520) : (k == 1 ? vec3(0.640, 0.700, 0.640) : (k == 2 ? vec3(0.450, 0.540, 0.480) : vec3(0.380, 0.480, 0.440)));
	if (t > 0.62 && u < 0.45) return k == 0 ? vec3(0.560, 0.500, 0.200) : (k == 1 ? vec3(0.640, 0.560, 0.240) : (k == 2 ? vec3(0.500, 0.440, 0.175) : vec3(0.430, 0.420, 0.160)));
	if (u > 0.62) return k == 0 ? vec3(0.175, 0.360, 0.135) : (k == 1 ? vec3(0.235, 0.400, 0.140) : (k == 2 ? vec3(0.150, 0.310, 0.125) : vec3(0.120, 0.290, 0.140)));
	return k == 0 ? vec3(0.290, 0.420, 0.125) : (k == 1 ? vec3(0.470, 0.460, 0.195) : (k == 2 ? vec3(0.300, 0.395, 0.130) : vec3(0.215, 0.365, 0.150)));
}

const int BAYER[16] = {0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5};
float bayer(vec2 p) { int x = int(mod(p.x, 4.0)), y = int(mod(p.y, 4.0)); return (float(BAYER[y * 4 + x]) + 0.5) / 16.0; }

float cloud_shadow(vec3 wp) {
	if (cloud_shadow_on < 0.5) return 1.0;
	vec3 S = normalize(sun_dir); vec2 wind = vec2(0.2148, 0.9767) * 0.57;
	vec2 cp = wp.xz + S.xz / max(S.y, 0.15) * (30.0 - wp.y);
	float q = vnoise(cp * 0.018 + wind * world_time * 0.022);
	float detail = vnoise(cp * 0.0396 - wind * world_time * 0.013 + vec2(17.2, -9.4));
	float density = q * 0.78 + detail * 0.22; float threshold = mix(0.69, 0.53, cloud_cover);
	float c = smoothstep(threshold, threshold + 0.15, density); return 1.0 - c * (0.40 + 0.20 * cloud_cover) * (1.0 - night * 0.7);
}

// rusticLightM con l'ombra direzionale di Godot (0..1) al posto di worldShadow.
vec3 rustic_light_m(vec3 n, float sun, float blk, vec3 wp, vec3 S, float bands, float shadow) {
	vec3 N = normalize(n); float ndl = max(dot(N, normalize(sun_dir)), 0.0);
	float band = ndl < 0.18 ? 0.56 : (ndl < 0.52 ? 0.76 : 1.0);
	float wsh = mix(1.0, shadow, shadow_strength);
	float sh = pow(sun, 1.35) * wsh * cloud_shadow(wp);
	if (paint_mode > 0.5) { float d = band * smoothstep(0.12, 0.58, sun) * wsh * cloud_shadow(wp); d = floor(d * bands + 0.5) / bands; band = d; sh = 1.0; }
	vec3 amb = ambient_color * (mix(0.35, 0.55, night) + mix(0.65, 0.45, night) * pow(sun, 1.35));
	if (paint_mode > 0.5) amb *= S / 0.40 * mix(1.0, 0.85, night);
	float rim = pow(1.0 - max(dot(N, normalize(view_dir)), 0.0), 2.5) * night * pow(sun, 0.8);
	vec3 l = amb + sun_color * (sun_intensity * band * sh) + vec3(0.30, 0.40, 0.62) * rim * 0.35 + vec3(1.0, 0.72, 0.42) * pow(blk, 1.4) * 0.95;
	if (paint_mode > 0.5) l = min(l, vec3(1.12));
	return l;
}

vec3 shade_tint(vec3 c) {
	float warm = smoothstep(0.02, 0.28, c.r - c.b); float green = smoothstep(0.0, 0.15, c.g - max(c.r, c.b));
	return mix(mix(vec3(0.40, 0.46, 0.64), vec3(0.60, 0.43, 0.50), warm), vec3(0.36, 0.54, 0.50), green);
}
vec3 quantize(vec3 l, vec2 fc) {
	if (dither_amount < 0.5) return l;
	float b = bayer(fc); float y = max(dot(l, vec3(0.299, 0.587, 0.114)), 1e-4); float L = mix(24.0, 30.0, night);
	float q = sqrt(y) * L; float amp = dither_amount * mix(0.72, 0.55, night);
	float qq = max(floor(q + (b - 0.5) * amp + 0.5), 1.0) / L; return min(l * (qq * qq / y), vec3(1.0));
}

// Raggi X a passata singola: i frammenti davanti al giocatore dentro la capsula
// vengono scartati con una soglia Bayer che sale verso il centro.
bool xray_occludes(vec2 screen_uv, vec2 frag, float view_depth, vec2 vp) {
	if (xray_amt <= 0.001) return false;
	vec2 p = screen_uv * vp, a = xray_a * vp, b = xray_b * vp; vec2 ab = b - a;
	float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-4), 0.0, 1.0);
	float d = length(p - (a + ab * t)); float R = xray_r * (0.25 + 0.75 * xray_amt);
	if (d > R || view_depth > xray_depth - 0.9) return false;
	float w = (1.0 - smoothstep(R * 0.30, R, d)) * min(1.0, xray_amt * 1.35);
	return bayer(frag) < w;
}
