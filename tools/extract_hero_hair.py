#!/usr/bin/env python3
"""Estrae i due capelli "originali" dell'eroe (ciuffo, lungo) dal prototipo
(<script id="hair-data">) in data/hero/hair.json, invariati: posizioni
quantizzate a 16 bit tra min e max, normali a 8 bit, indici a 16 bit, base64.
Uso: python3 tools/extract_hero_hair.py"""
import json, re, pathlib
root = pathlib.Path(__file__).resolve().parent.parent
html = (root / "reference/isoterra_proto_v0_64_humanoids.html").read_text(encoding="utf-8")
m = re.search(r'<script id="hair-data" type="application/json">(.*?)</script>', html, re.S)
data = json.loads(m.group(1))
(root / "data/hero/hair.json").write_text(json.dumps(data, separators=(",", ":")), encoding="utf-8")
print("capelli:", ", ".join("%s (%d vertici)" % (k, v["v"]) for k, v in data.items()))
