#!/usr/bin/env python3
"""Pose chiave dei colpi (D-046) da pose.json di extract_pose.py.

Per ogni colpo, dalla velocita' del polso destro rispetto al bacino:
- i gesti sono separati dai punti piu' lenti fra due picchi di velocita';
- carica = inizio del tratto veloce (velocita' sopra meta' del picco);
- colpo  = fine del tratto veloce;
- seguito = punto lento seguente (al massimo 0,5 s dopo il colpo).
Le direzioni dei segmenti sono nello spazio del bacino di quel fotogramma,
con gli assi del rig (x destra dell'attore, y su, -z davanti).

Uso: keyframes.py pose.json out.json [--min-speed 0.8]
"""
import argparse, json
import numpy as np

SEG = {  # nome: (da, a) indici MediaPipe
    "spine": ("hip", "sho"),
    "sho_line": (11, 12),
    "arm_r": (12, 14), "fore_r": (14, 16), "hand_r": (16, "hand_r"),
    "arm_l": (11, 13), "fore_l": (13, 15), "hand_l": (15, "hand_l"),
    "leg_r": (24, 26), "shin_r": (26, 28), "leg_l": (23, 25), "shin_l": (25, 27),
    "head": ("sho", 0),
}


def rig(p):
    # MediaPipe mondo: x a destra dell'immagine, y in giu', z verso la profondita'.
    # Attore di fronte alla camera: la sua destra e' -x, il suo davanti e' -z.
    return np.array([-p[0], -p[1], p[2]])


def point(w, k):
    if k == "hip":
        return (rig(w[23]) + rig(w[24])) / 2
    if k == "sho":
        return (rig(w[11]) + rig(w[12])) / 2
    if k == "hand_r":
        return (rig(w[18]) + rig(w[20])) / 2
    if k == "hand_l":
        return (rig(w[17]) + rig(w[19])) / 2
    return rig(w[k])


def pelvis_frame(w):
    right = rig(w[24]) - rig(w[23])
    up = np.array([0.0, 1.0, 0.0])
    right[1] = 0
    right /= np.linalg.norm(right) + 1e-9
    fwd = np.cross(up, right)
    back = -fwd
    return np.stack([right, up, back])  # righe = assi x, y, z del rig


def smooth(a, k=2):
    out = a.copy()
    for i in range(len(a)):
        out[i] = a[max(0, i - k):i + k + 1].mean(axis=0)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("pose")
    ap.add_argument("out")
    ap.add_argument("--min-speed", type=float, default=0.8)
    a = ap.parse_args()
    d = json.load(open(a.pose))
    fps = d["fps"]
    fr = [f for f in d["frames"] if f["world"]]
    W = [f["world"] for f in fr]
    T = np.array([f["t"] for f in fr])
    # Polso destro nello spazio del bacino.
    wr = np.array([pelvis_frame(w) @ (point(w, 16) - point(w, "hip")) for w in W])
    wr = smooth(wr)
    sp = np.zeros(len(wr))
    sp[1:] = np.linalg.norm(np.diff(wr, axis=0), axis=1) * fps
    sp = smooth(sp[:, None])[:, 0]
    # Picchi: massimi locali sopra la soglia (assoluta e relativa al massimo),
    # distanti almeno 0,25 s; fra due picchi il punto piu' lento divide i gesti.
    thr = max(a.min_speed, 0.35 * float(sp.max()))
    peaks = []
    for i in range(1, len(sp) - 1):
        if sp[i] >= thr and sp[i] >= sp[i - 1] and sp[i] >= sp[i + 1]:
            if peaks and T[i] - T[peaks[-1]] < 0.25:
                if sp[i] > sp[peaks[-1]]:
                    peaks[-1] = i
                continue
            peaks.append(i)
    slow = [0]
    for n in range(len(peaks) - 1):
        slow.append(peaks[n] + int(np.argmin(sp[peaks[n]:peaks[n + 1] + 1])))
    slow.append(len(sp) - 1)
    strikes = []
    for n, p in enumerate(peaks):
        lo, hi = slow[n], slow[n + 1]
        half = 0.5 * sp[p]
        st = p
        while st > lo and sp[st - 1] >= half:
            st -= 1
        en = p
        while en < hi and sp[en + 1] >= half:
            en += 1
        # Fine del ritorno: il punto lento seguente, ma non oltre 0,5 s dal colpo.
        fol = min(hi, en + int(0.5 * fps))
        strikes.append({"start": lo, "wind": st, "strike": en, "follow": fol, "peak": p})
    out = {"fps": fps, "speed": [round(float(v), 3) for v in sp], "t": [round(float(v), 3) for v in T], "strikes": []}
    for s in strikes:
        rec = {"peak_speed": round(float(sp[s["peak"]]), 2)}
        for key in ("wind", "strike", "follow"):
            i = s[key]
            w = W[i]
            F = pelvis_frame(w)
            dirs = {}
            for name, (p0, p1) in SEG.items():
                v = F @ (point(w, p1) - point(w, p0))
                dirs[name] = [round(float(x), 4) for x in v / (np.linalg.norm(v) + 1e-9)]
            # Rotazione del bacino rispetto al primo fotogramma (gradi, attorno a y).
            r0 = pelvis_frame(W[0])[0]
            r1 = F[0]
            yaw = np.degrees(np.arctan2(np.cross(r0, r1)[1], np.dot(r0, r1)))
            # Altezza del bacino rispetto al primo fotogramma (piegamento).
            dirs["hip_drop"] = round(float(point(W[0], "hip")[1] - point(w, "hip")[1]), 3)
            rec[key] = {"frame": int(i), "t": round(float(T[i]), 3), "pelvis_yaw": round(float(yaw), 1), "dirs": dirs}
        rec["windup"] = round(float(T[s["wind"]] - T[s["start"]]), 3)
        rec["active"] = round(float(T[s["strike"]] - T[s["wind"]]), 3)
        rec["recovery"] = round(float(T[s["follow"]] - T[s["strike"]]), 3)
        out["strikes"].append(rec)
    json.dump(out, open(a.out, "w"), indent=1)
    for n, r in enumerate(out["strikes"]):
        print("colpo %d: carica %.2fs colpo %.2fs seguito %.2fs · picco %.1f m/s · preparazione %.2f attivo %.2f" % (
            n + 1, r["wind"]["t"], r["strike"]["t"], r["follow"]["t"], r["peak_speed"], r["windup"], r["active"]))


if __name__ == "__main__":
    main()
