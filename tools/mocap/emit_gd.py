#!/usr/bin/env python3
"""Scrive src/combat/mocap_moves.gd (D-046) dalle pose adattate al rig
(fit_poses.gd): busto, braccia e avambracci dai video; la mano dell'arma
girata da fit_poses perche' la lama continui la linea spalla -> mano (il
video non vede la lama); testa che compensa il
busto; le gambe le mettono le pose d'appoggio del gioco e il passo.

Uso: emit_gd.py out.gd nome=poses.json:colpo [nome=...]
"""
import json, sys

BONES = ["chest", "arm_r", "fore_r", "arm_l", "fore_l"]


def pose(p, hip_drop):
    out = {b: [int(v) for v in p[b]] for b in BONES}
    out["hand_r"] = [int(v) for v in p["hand_r"]]
    out["head"] = [0, -int(p["chest"][1] * 0.6), 0]
    # Il bacino non si misura (le coordinate del video sono centrate li'):
    # appoggio e abbassamento li mettono le pose delle gambe del gioco.
    return out


def main():
    out_path = sys.argv[1]
    moves = {}
    for spec in sys.argv[2:]:
        name, src = spec.split("=")
        path, n = src.rsplit(":", 1)
        rec = json.load(open(path))[int(n) - 1]
        moves[name] = {
            "time": [rec["windup"], rec["active"], rec["recovery"]],
            "wind": pose(rec["wind"]["pose"], rec["wind"]["hip_drop"]),
            "strike": pose(rec["strike"]["pose"], rec["strike"]["hip_drop"]),
            "follow": pose(rec["follow"]["pose"], rec["follow"]["hip_drop"]),
        }
    lines = ["class_name MocapMoves", "extends RefCounted",
             "## Pose chiave ricavate dai video di riferimento generati con Higgsfield (D-046):",
             "## tools/mocap (extract_pose.py -> keyframes.py -> fit_poses.gd -> emit_gd.py).",
             "## File generato: non modificare a mano. Gradi [x, y, z] per osso come in",
             "## WeaponLibrary; \"time\" = [preparazione, colpo, ritorno] misurati nel video (s).",
             "", "const MOVES := {"]
    for name, m in moves.items():
        lines.append('\t"%s": {' % name)
        lines.append('\t\t"time": [%s],' % ", ".join("%.3f" % t for t in m["time"]))
        for k in ("wind", "strike", "follow"):
            items = ", ".join('"%s": %s' % (b, json.dumps(v)) for b, v in m[k].items())
            lines.append('\t\t"%s": {%s},' % (k, items))
        lines.append("\t},")
    lines.append("}")
    open(out_path, "w").write("\n".join(lines) + "\n")
    print("scritto %s: %s" % (out_path, ", ".join(moves)))


if __name__ == "__main__":
    main()
