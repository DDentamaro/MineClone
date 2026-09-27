# IsoTerra (MineClone)

Ricostruzione in **Godot 4.7.2** del prototipo HTML *IsoTerra* e sua evoluzione in un
piccolo sandbox voxel action per telefono (orizzontale). Il piano di lavoro è diviso in
milestone M0–M8 (traguardo **R** = parità col prototipo, traguardo **G** = gioco).

Stato attuale: **M0 — Baseline** (vedi `docs/PROGRESS.md`).

## Struttura

| Percorso | Contenuto |
|---|---|
| `reference/` | HTML originale del prototipo (fonte di verità, non modificare) |
| `docs/` | `PROGRESS.md`, `PARITY_MATRIX.md`, `DECISIONS.md`, inventario del sorgente |
| `src/` | Codice GDScript tipizzato (`world/data`, `core`, …) |
| `data/` | Risorse di catalogo (`BlockDefinition`, …) |
| `scenes/` | Scene Godot (`main.tscn`) |
| `tests/` | Runner headless, test unitari, fixture estratte dal prototipo |
| `tools/` | Estrazione fixture (Node), generatori di risorse, setup ambiente |

## Comandi

```bash
tools/setup_env.sh                          # Godot 4.7.2 + template + SDK (Linux)
tools/run_tests.sh                          # test headless
node tools/extract_fixture.mjs 1931         # rigenera la fixture del seme 1931
godot --headless --path . --script res://tools/godot_gen_block_catalog.gd
godot --headless --path . --export-debug Android build/android/isoterra-debug.apk
godot --headless --path . --export-debug Linux build/linux/isoterra.x86_64
```
