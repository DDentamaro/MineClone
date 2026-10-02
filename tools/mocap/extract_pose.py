#!/usr/bin/env python3
"""Pose dai video di riferimento (D-046): per ogni fotogramma i 33 punti del
corpo di MediaPipe (immagine e mondo, metri, centro anche), in JSON, piu' un
foglio di fotogrammi con lo scheletro disegnato per controllarli a occhio.

Uso: extract_pose.py video.mp4 out_dir [--model pose_landmarker_full.task]
"""
import argparse, json, os
import cv2
import mediapipe as mp
from mediapipe.tasks import python as mpt
from mediapipe.tasks.python import vision

EDGES = [(11, 12), (11, 13), (13, 15), (12, 14), (14, 16), (11, 23), (12, 24), (23, 24),
         (23, 25), (25, 27), (24, 26), (26, 28), (27, 31), (28, 32), (0, 11), (0, 12)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("out")
    ap.add_argument("--model", default=os.path.join(os.path.dirname(__file__), "pose_landmarker_full.task"))
    ap.add_argument("--sheet", type=int, default=24, help="fotogrammi nel foglio")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    opts = vision.PoseLandmarkerOptions(base_options=mpt.BaseOptions(model_asset_path=a.model),
                                        running_mode=vision.RunningMode.VIDEO, num_poses=1)
    lm = vision.PoseLandmarker.create_from_options(opts)
    cap = cv2.VideoCapture(a.video)
    fps = cap.get(cv2.CAP_PROP_FPS) or 24.0
    frames, imgs = [], []
    i = 0
    while True:
        ok, bgr = cap.read()
        if not ok:
            break
        rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
        res = lm.detect_for_video(mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb), int(i * 1000 / fps))
        f = {"t": i / fps, "img": None, "world": None}
        if res.pose_landmarks:
            f["img"] = [[p.x, p.y, p.z, p.visibility] for p in res.pose_landmarks[0]]
            f["world"] = [[p.x, p.y, p.z, p.visibility] for p in res.pose_world_landmarks[0]]
            h, w = bgr.shape[:2]
            pts = [(int(p[0] * w), int(p[1] * h)) for p in f["img"]]
            for e0, e1 in EDGES:
                cv2.line(bgr, pts[e0], pts[e1], (0, 0, 255) if e0 in (12, 14) or e1 in (14, 16) else (0, 220, 0), 2)
        cv2.putText(bgr, "%.2fs" % f["t"], (8, 20), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 0), 2)
        frames.append(f)
        imgs.append(bgr)
        i += 1
    json.dump({"fps": fps, "frames": frames}, open(os.path.join(a.out, "pose.json"), "w"))
    # Foglio: N fotogrammi equidistanti in una griglia 6 colonne.
    n = min(a.sheet, len(imgs))
    sel = [imgs[int(k * (len(imgs) - 1) / max(1, n - 1))] for k in range(n)]
    sel = [cv2.resize(s, (320, int(320 * s.shape[0] / s.shape[1]))) for s in sel]
    rows = [cv2.hconcat(sel[r:r + 6] + [sel[0] * 0] * (6 - len(sel[r:r + 6]))) for r in range(0, n, 6)]
    cv2.imwrite(os.path.join(a.out, "sheet.jpg"), cv2.vconcat(rows))
    found = sum(1 for f in frames if f["img"])
    print("fotogrammi %d, con posa %d, fps %.1f" % (len(frames), found, fps))


if __name__ == "__main__":
    main()


def key_strip(video, keys_json, out_jpg):
    """Fotogrammi delle pose chiave (righe = colpi, colonne = carica/colpo/seguito)."""
    k = json.load(open(keys_json))
    cap = cv2.VideoCapture(video)
    imgs = []
    while True:
        ok, f = cap.read()
        if not ok:
            break
        imgs.append(f)
    rows = []
    for n, s in enumerate(k["strikes"]):
        cells = []
        for key in ("wind", "strike", "follow"):
            f = imgs[s[key]["frame"]].copy()
            cv2.putText(f, "%d %s %.2fs" % (n + 1, key, s[key]["t"]), (8, 24), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 0), 2)
            cells.append(cv2.resize(f, (400, int(400 * f.shape[0] / f.shape[1]))))
        rows.append(cv2.hconcat(cells))
    cv2.imwrite(out_jpg, cv2.vconcat(rows))
