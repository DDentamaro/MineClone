# IsoTerra (MineClone)

Ricostruzione in **Godot 4.7.2** del prototipo HTML *IsoTerra* e sua evoluzione in un
piccolo sandbox voxel action per telefono (orizzontale). Il piano di lavoro è diviso in
milestone M0–M8 (traguardo **R** = parità col prototipo, traguardo **G** = gioco).

Stato attuale: **M1 — percorso giocabile minimo** (vedi `docs/PROGRESS.md`): mondo del seme
1931 a chunk, giocatore con collisioni voxel, camera isometrica (terza persona facoltativa),
controlli touch, costruzione e scavo di debug.

Controlli desktop: WASD/frecce, Spazio salto, trascinamento del mouse per ruotare, rotella
zoom, clic = tap, F modo, B o 1/2/3/T blocco, V camera, Q/E rotazione a scatti.

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
godot --headless --path . --script res://tools/bench_mesh.gd   # tempo di meshing
xvfb-run -a godot --path . --script res://tools/e2e_touch.gd -- --out=/tmp/e2e.png
godot --path . -- --screenshot=shot.png --zoom=0.55 --cam=tps  # screenshot automatico
```
