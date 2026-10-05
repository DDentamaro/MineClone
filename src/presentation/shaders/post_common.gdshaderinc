// Parte "colore" di blitFS (notte e grading), condivisa tra il quad di post e
// le superfici trasparenti disegnate dopo di esso (acqua, grani), che nel
// prototipo passavano dal blit insieme al resto della scena.

global uniform vec3 grade_s;
global uniform vec3 grade_h;

// v = coordinate schermo del prototipo (0..1, y in alto).
vec3 post_color(vec3 col, vec2 v) {
	if (night > 0.001) {
		float lum = dot(col, vec3(0.299, 0.587, 0.114)); vec3 cold = mix(vec3(lum) * vec3(0.62, 0.72, 1.0), col, 0.45);
		float warmn = smoothstep(0.05, 0.35, col.r - col.b); col = mix(col, cold, night * (1.0 - warmn * 0.8));
		col = mix(col, (col - 0.5) * 1.08 + 0.5, night * 0.5);
		vec2 vv = v * 2.0 - 1.0; col *= 1.0 - night * 0.22 * smoothstep(0.55, 1.45, dot(vv, vv));
	}
	float gl = dot(col, vec3(0.299, 0.587, 0.114)); col *= mix(grade_s, grade_h, smoothstep(0.12, 0.62, gl));
	// D-063: gradazione della resa nitida: un filo piu' di saturazione e di
	// contrasto di giorno (la reference e' calda e piena).
	if (look_hd > 0.5) {
		float y = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(vec3(y), col, 1.0 + 0.10 * (1.0 - night));
		col = mix(col, (col - 0.45) * 1.06 + 0.45, 1.0 - night);
	}
	// D-061: vignettatura leggera anche di giorno (effetto diorama).
	vec2 vd = v * 2.0 - 1.0; col *= 1.0 - 0.13 * (1.0 - night) * smoothstep(0.6, 1.7, dot(vd, vd));
	return col;
}
