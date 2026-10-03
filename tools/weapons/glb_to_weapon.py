#!/usr/bin/env python3
"""Arma da Higgsfield (GLB con texture) a mesh del gioco (D-052).

- colori della texture portati sui vertici (lo shader degli attori usa i
  colori dei vertici, niente texture);
- poligoni ridotti per il telefono (`--faces`, 1800 di default);
- orientata nello spazio arma di `WeaponMeshes`: impugnatura nell'origine,
  lama/asta lungo +Y, piatto della lama sul piano XY (filo verso +-X);
- stessa lunghezza e stessa impugnatura dell'arma a cubetti che sostituisce
  (D-039), cosi' hitbox, scie e pose non cambiano.

Uscita .json (letta da `WeaponMeshes`): vertici, normali, colori, indici.
Uscita .glb: per guardarla in un visualizzatore.
Uso: python3 tools/weapons/glb_to_weapon.py --kind=sword in.glb data/weapons/sword.json
     (lancia: --girth=0.55, D-052: a parita' di lunghezza era troppo grossa)
"""
import argparse
import json
import sys

import numpy as np
import trimesh
import fast_simplification
from scipy.spatial import cKDTree

# Estremi lungo Y dell'arma a cubetti (WeaponMeshes.build, impugnatura in 0).
TARGET = {
	"sword": (-0.1375, 0.9625),
	"spear": (-0.7425, 1.6225),
	"hammer": (-0.3575, 1.2375),
	"greatsword": (-0.3575, 1.4575),
}


def load(path: str) -> trimesh.Trimesh:
	scene = trimesh.load(path, force="scene")
	# Ogni mesh con la trasformazione del suo nodo; colori della texture sui
	# vertici (to_color campiona la texture agli UV).
	dumped = []
	for node in scene.graph.nodes_geometry:
		tf, gname = scene.graph[node]
		g = scene.geometry[gname].copy()
		if hasattr(g.visual, "to_color"):
			g.visual = g.visual.to_color()
		g.apply_transform(tf)
		dumped.append(g)
	return trimesh.util.concatenate(dumped)


def colors_of(m: trimesh.Trimesh) -> np.ndarray:
	c = np.asarray(m.visual.vertex_colors, dtype=np.float64)[:, :3] / 255.0
	return c


def main() -> int:
	ap = argparse.ArgumentParser()
	ap.add_argument("--kind", required=True, choices=list(TARGET))
	ap.add_argument("--faces", type=int, default=1800)
	ap.add_argument("--flip", action="store_true", help="capovolge la punta (se la regola automatica sbaglia)")
	ap.add_argument("--girth", type=float, default=1.0, help="spessore (X/Z) rispetto alla scala della lunghezza: <1 = arma piu' snella")
	ap.add_argument("src")
	ap.add_argument("dst")
	a = ap.parse_args()

	m = load(a.src)
	v = np.asarray(m.vertices, dtype=np.float64)
	f = np.asarray(m.faces, dtype=np.int64)
	col = colors_of(m)
	print(f"origine: {len(v)} vertici, {len(f)} triangoli, ingombro {np.ptp(v, axis=0)}")

	# Asse lungo -> Y.
	ext = np.ptp(v, axis=0)
	long_ax = int(np.argmax(ext))
	rest = [i for i in range(3) if i != long_ax]
	# Asse sottile della parte alta (la lama) -> Z, l'altro -> X. Per il
	# martello la testa e' lunga lungo X come l'arma a cubetti.
	top = v[v[:, long_ax] > np.percentile(v[:, long_ax], 70)]
	thin = rest[0] if np.ptp(top[:, rest[0]]) < np.ptp(top[:, rest[1]]) else rest[1]
	wide = rest[1] if thin == rest[0] else rest[0]
	v = v[:, [wide, long_ax, thin]]

	# Punta in alto: l'estremita' d'acciaio (grigia, poco satura) e' la punta o
	# la testa; l'altra e' cuoio, legno o ottone (impugnatura, pomo, calcio).
	mx, mn_ = col.max(axis=1), col.min(axis=1)
	sat = np.where(mx > 1e-6, (mx - mn_) / np.maximum(mx, 1e-6), 0.0)
	lo, hi = v[:, 1].min(), v[:, 1].max()
	top = v[:, 1] > hi - 0.15 * (hi - lo)
	bot = v[:, 1] < lo + 0.15 * (hi - lo)
	if (sat[top].mean() > sat[bot].mean()) != a.flip:
		v[:, 1] *= -1.0
		v[:, 0] *= -1.0  # rotazione di 180 gradi attorno a Z, niente specchio

	# Asse dell'impugnatura: centro in X/Z della parte bassa (impugnatura/asta).
	lo, hi = v[:, 1].min(), v[:, 1].max()
	t0, t1 = TARGET[a.kind]
	k = (t1 - t0) / (hi - lo)
	low = v[v[:, 1] < lo + (hi - lo) * 0.12]
	cx, cz = np.median(low[:, 0]), np.median(low[:, 2])
	g = k * a.girth
	v = np.column_stack([(v[:, 0] - cx) * g, (v[:, 1] - lo) * k + t0, (v[:, 2] - cz) * g])

	# Poligoni ridotti, colori ripresi dal vertice originale piu' vicino.
	if len(f) > a.faces:
		red = 1.0 - a.faces / len(f)
		v2, f2 = fast_simplification.simplify(v.astype(np.float32), f.astype(np.int32), target_reduction=red)
		_, idx = cKDTree(v).query(v2)
		col = col[idx]
		v, f = np.asarray(v2, dtype=np.float64), np.asarray(f2, dtype=np.int64)
	rgba = np.clip(np.column_stack([col, np.ones(len(col))]) * 255.0, 0, 255).astype(np.uint8)
	out = trimesh.Trimesh(vertices=v, faces=f, vertex_colors=rgba, process=True)
	out.fix_normals()
	if a.dst.endswith(".json"):
		c = np.asarray(out.visual.vertex_colors, dtype=np.float64)[:, :3] / 255.0
		data = {
			"kind": a.kind,
			"vertices": np.round(out.vertices, 4).ravel().tolist(),
			"normals": np.round(out.vertex_normals, 3).ravel().tolist(),
			"colors": np.round(c, 3).ravel().tolist(),
			"indices": out.faces.ravel().astype(int).tolist(),
		}
		with open(a.dst, "w") as fh:
			json.dump(data, fh, separators=(",", ":"))
	else:
		out.export(a.dst)
	print(f"uscita: {len(out.vertices)} vertici, {len(out.faces)} triangoli, Y {out.vertices[:, 1].min():.3f}..{out.vertices[:, 1].max():.3f}, ingombro {np.ptp(out.vertices, axis=0)}")
	return 0


if __name__ == "__main__":
	sys.exit(main())
