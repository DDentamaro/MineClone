# IsoTerra (MineClone)

Ricostruzione in **Godot 4.7.2** del prototipo HTML *IsoTerra* e sua evoluzione in un
piccolo sandbox voxel action per telefono (orizzontale). Il piano di lavoro è diviso in
milestone M0–M8 (traguardo **R** = parità col prototipo, traguardo **G** = gioco).

Stato attuale: **M2 — mondo e resa** (vedi `docs/PROGRESS.md`): generatore e luce portati
bit a bit dal prototipo, mesh greedy, alberi ed erba, stile dipinto con contorni e cielo,
giorno/notte, raggi X, camera isometrica (terza persona facoltativa), controlli touch,
costruzione e scavo di debug, pannello sviluppatore (⚙).

Controlli desktop: WASD/frecce, Spazio salto, trascinamento del mouse per ruotare, rotella
zoom, clic = tap, F modo, B o 1/2/3/T blocco, V camera, Q/E rotazione a scatti, N nuovo seme.

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
node tools/extract_gen_stages.mjs           # fixture di parità generatore/fluidi (gen_v064)
godot --headless --path . --script res://tools/verify_generator.gd   # parità mondi grandi + tempi
godot --headless --path . --script res://tools/godot_gen_block_catalog.gd
godot --headless --path . --export-debug Android build/android/isoterra-debug.apk
godot --headless --path . --export-debug Linux build/linux/isoterra.x86_64
godot --headless --path . --script res://tools/bench_mesh.gd   # tempi di mondo e vegetazione
node tools/extract_render_fixture.mjs 1931  # riferimenti di resa dal prototipo
xvfb-run -a godot --path . --script res://tools/e2e_touch.gd -- --out=/tmp/e2e.png
godot --path . -- --screenshot=shot.png --zoom=0.55 --cam=tps --time=0.9 --seed=42 --dev
```
