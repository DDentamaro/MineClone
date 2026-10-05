// Materiali della resa nitida (D-062, piano grafico F3): colore procedurale a
// piena risoluzione al posto dei 16 texel per blocco della pixel-art.
// Richiede rustic.gdshaderinc (hash21, vnoise).
//
// - Lastre di pietra (pavimento dell'arena): Voronoi per lastre irregolari
//   (distanza fra primo e secondo punto = fuga), tono per lastra, bordi
//   consumati, crepe su alcune lastre, macchie, fughe di terra con erba.
// - Fianchi del ring: corsi di pietra sfalsati.
// - Pietra, pietra scura, terra, sabbia, legno: grana fine, variazione per
//   blocco, spigoli che prendono la luce.

vec2 hd_hash22(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float hd_fbm(vec2 p) {
	float a = 0.5, s = 0.0;
	for (int i = 0; i < 4; i++) { s += a * vnoise(p); p = p * 2.03 + vec2(17.1, 9.2); a *= 0.5; }
	return s;
}

// Voronoi: x = distanza dal punto piu' vicino, y = distanza dal bordo della
// cella (F2-F1), z = valore casuale della cella.
vec3 hd_voronoi(vec2 p) {
	vec2 n = floor(p), f = fract(p);
	float d1 = 8.0, d2 = 8.0; vec2 id = vec2(0.0);
	for (int j = -1; j <= 1; j++) for (int i = -1; i <= 1; i++) {
		vec2 g = vec2(float(i), float(j));
		vec2 o = 0.15 + 0.7 * hd_hash22(n + g);
		float d = length(g + o - f);
		if (d < d1) { d2 = d1; d1 = d; id = n + g; } else if (d < d2) { d2 = d; }
	}
	return vec3(d1, d2 - d1, hash21(id + vec2(3.3, 7.7)));
}

// Fughe di terra con l'erba che ci cresce (piu' fitta a chiazze).
vec3 hd_grout(vec2 sp) {
	vec3 dirt = mix(vec3(0.30, 0.25, 0.18), vec3(0.40, 0.34, 0.24), vnoise(sp * 9.0));
	float moss = smoothstep(0.50, 0.72, hd_fbm(sp * 0.7 + vec2(3.0, 8.0)) + (hash21(floor(sp * 24.0)) - 0.5) * 0.4);
	vec3 grass = mix(vec3(0.30, 0.42, 0.14), vec3(0.45, 0.56, 0.20), hash21(floor(sp * 32.0) + vec2(1.0, 2.0)));
	return mix(dirt, grass, moss);
}

// Lastre del pavimento: file sfalsate di lastre quasi rettangolari (larghe
// 1-2 blocchi, a volte divise in due), bordi mossi e spigoli scheggiati.
// Colore e quanto e' fuga (0..1, per l'occlusione).
vec3 hd_flagstone(vec2 sp, out float grout) {
	vec2 w = sp + (vec2(vnoise(sp * 2.7), vnoise(sp * 2.7 + vec2(7.0, 3.0))) - 0.5) * 0.05;
	const float RH = 1.25;
	const float SX = 0.5;
	float row = floor(w.y / RH);
	float x = w.x * SX + hash21(vec2(row, 3.0)) * 3.0;
	float col = floor(x);
	float k = hash21(vec2(col, row) + vec2(11.0, 5.0));
	vec2 f = vec2(fract(x) / SX, fract(w.y / RH) * RH);
	vec2 size = vec2(1.0 / SX, RH);
	// Una lastra su quattro e' divisa in due lungo la fila.
	if (k < 0.25) {
		float half_x = size.x * (0.4 + 0.2 * fract(k * 13.0));
		if (f.x > half_x) { f.x -= half_x; size.x -= half_x; k = fract(k * 7.7 + 0.31); } else { size.x = half_x; }
	}
	vec2 d = min(f, size - f);
	float e = min(d.x, d.y);
	// Spigoli scheggiati: la fuga si allarga verso gli angoli.
	float corner = 1.0 - smoothstep(0.0, 0.22, max(d.x, d.y) - min(d.x, d.y) + min(d.x, d.y) * 0.0);
	float gw = 0.028 + 0.02 * vnoise(sp * 5.0) + 0.05 * (1.0 - smoothstep(0.0, 0.2, d.x)) * (1.0 - smoothstep(0.0, 0.2, d.y));
	grout = 1.0 - smoothstep(gw, gw + 0.02, e);
	// Toni caldi della pietra, qualche lastra piu' fredda, piu' chiara o piu' scura.
	vec3 c = mix(vec3(0.68, 0.62, 0.52), vec3(0.84, 0.79, 0.68), fract(k * 7.13));
	if (k > 0.85) c = mix(c, vec3(0.70, 0.70, 0.66), 0.6);
	if (k < 0.10) c *= 0.86;
	float st = hd_fbm(sp * 1.6 + k * 10.0);
	c *= 0.90 + 0.16 * st;
	c *= 0.96 + 0.07 * hash21(floor(sp * 48.0));
	c = mix(c, c * vec3(0.84, 0.82, 0.76), smoothstep(0.55, 0.8, hd_fbm(sp * 0.45 + vec2(11.0, 2.0))) * 0.5);
	// Smusso consumato: un filo chiaro che prende la luce, poi scuro verso la fuga.
	float rim = 1.0 - smoothstep(gw + 0.02, gw + 0.10, e);
	c *= 1.0 + 0.12 * rim * (1.0 - grout);
	c *= 1.0 - 0.20 * (1.0 - smoothstep(gw, gw + 0.035, e)) * (1.0 - grout);
	// Crepe su una lastra su cinque, corte e leggere.
	if (fract(k * 3.71) < 0.2) {
		vec3 cr = hd_voronoi(w * 1.7 + k * 31.0);
		float crack = (1.0 - smoothstep(0.0, 0.018, cr.y)) * smoothstep(0.55, 0.72, vnoise(w * 1.3 + k * 9.0));
		c *= 1.0 - 0.32 * crack;
	}
	return mix(c, hd_grout(sp), grout);
}

// Fianchi di pietra a corsi sfalsati (spessore mezzo blocco).
vec3 hd_coursed(vec2 sp, out float grout) {
	float row = floor(sp.y * 2.0);
	float x = sp.x * 1.0 + hash21(vec2(row, 5.0)) * 0.7;
	float bx = fract(x), by = fract(sp.y * 2.0);
	float e = min(min(bx, 1.0 - bx) * 1.0, min(by, 1.0 - by) * 0.5);
	grout = 1.0 - smoothstep(0.012, 0.03, e);
	float k = hash21(vec2(floor(x), row));
	vec3 c = mix(vec3(0.64, 0.59, 0.50), vec3(0.78, 0.73, 0.63), k);
	c *= 0.90 + 0.16 * hd_fbm(sp * 2.2 + k * 7.0);
	c *= 1.0 + 0.08 * (1.0 - smoothstep(0.03, 0.08, e)) * (1.0 - grout);
	return mix(c, vec3(0.24, 0.21, 0.17), grout);
}

// Smusso finto degli spigoli di un blocco: chiaro sopra, scuro sotto.
float hd_bevel(vec2 uv) {
	vec2 d = min(uv, 1.0 - uv);
	return 1.0 - smoothstep(0.0, 0.07, min(d.x, d.y));
}

// Colore della resa nitida per i materiali che la conoscono; `ok` falso =
// resta il colore della pixel-art.
vec3 hd_material(float tile, int face, vec2 sp, vec2 uv, vec3 wp, vec3 col, out bool ok, out float occl) {
	ok = true;
	occl = 0.0;
	vec3 cell = floor(wp - vec3(face == 0 ? 0.5 : 0.0, face == 2 ? 0.5 : 0.0, face == 4 ? 0.5 : 0.0));
	float blk = hash21(cell.xz + vec2(cell.y * 1.7, cell.y * 0.3));
	float g = 0.0;
	if (tile == 16.0) {
		vec3 c = face == 2 ? hd_flagstone(sp, g) : hd_coursed(sp, g);
		occl = g;
		return c;
	}
	if (tile == 3.0 || tile == 14.0) {
		bool dark = tile == 14.0;
		vec3 a = dark ? vec3(0.20, 0.20, 0.20) : vec3(0.33, 0.32, 0.30);
		vec3 b = dark ? vec3(0.31, 0.29, 0.27) : vec3(0.47, 0.44, 0.39);
		float n = hd_fbm(sp * 1.4 + blk * 5.0);
		vec3 c = mix(a, b, n);
		vec3 cr = hd_voronoi(sp * 2.6 + blk * 13.0);
		c *= 1.0 - 0.32 * (1.0 - smoothstep(0.0, 0.03, cr.y));
		c *= 0.92 + 0.12 * blk;
		c *= 1.0 + (face == 3 ? -0.12 : 0.10) * hd_bevel(uv);
		return c;
	}
	if (tile == 2.0 || (tile == 1.0 && face != 2 && col.g < col.r)) {
		vec3 c = mix(vec3(0.27, 0.20, 0.12), vec3(0.40, 0.31, 0.18), hd_fbm(sp * 2.0 + blk * 3.0));
		float peb = hash21(floor(sp * 16.0) + blk);
		if (peb > 0.975) c = mix(c, vec3(0.44, 0.39, 0.32), 0.5);
		c *= 0.94 + 0.10 * blk;
		return c;
	}
	if (tile == 4.0) {
		vec3 c = mix(vec3(0.60, 0.53, 0.33), vec3(0.70, 0.63, 0.41), hd_fbm(sp * 3.0));
		c *= 0.95 + 0.08 * hash21(floor(sp * 40.0));
		return c;
	}
	if (tile == 13.0) {
		// Tavole: quattro per blocco, venatura lungo la tavola, fughe scure.
		float pl = floor(sp.y * 4.0);
		float k = hash21(vec2(pl, floor(sp.x * 0.5) + blk));
		float grain = sin((sp.x + vnoise(vec2(sp.x * 0.8, pl)) * 0.6) * 22.0 + k * 9.0) * 0.5 + 0.5;
		vec3 c = mix(vec3(0.38, 0.27, 0.15), vec3(0.52, 0.38, 0.21), k) * (0.92 + 0.10 * grain);
		float seam = 1.0 - smoothstep(0.0, 0.04, min(fract(sp.y * 4.0), 1.0 - fract(sp.y * 4.0)));
		occl = seam;
		return mix(c, vec3(0.17, 0.12, 0.08), seam * 0.8);
	}
	if (tile == 1.0 && face == 2) {
		// Prato: il colore del bioma con ciuffi e chiazze a piena risoluzione.
		float tuft = hash21(floor(sp * 28.0));
		vec3 c = col * (0.90 + 0.14 * hd_fbm(sp * 1.3)) * (0.94 + 0.12 * tuft);
		return c;
	}
	ok = false;
	return col;
}
