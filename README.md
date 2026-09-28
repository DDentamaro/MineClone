# IsoTerra (MineClone)

Ricostruzione in **Godot 4.7.2** del prototipo HTML *IsoTerra* e sua evoluzione in un
piccolo sandbox voxel action per telefono (orizzontale). Il piano di lavoro è diviso in
milestone M0–M8 (traguardo **R** = parità col prototipo, traguardo **G** = gioco).

Stato attuale: **M5 — sandbox persistente con equipaggiamento RPG** (D-026), dopo il gate R e **M4 — action** (vedi `docs/PROGRESS.md`): generatore, luce,
mesh, vegetazione e acqua identici al prototipo; resa dipinta con contorni, cielo, giorno/notte
e acqua fusa come nella reference; nuoto e guado, schizzi; camera isometrica (terza persona
facoltativa), controlli touch, costruzione e scavo di debug, pannello sviluppatore (⚙).
Eroe animato con editor, cinque armi con catene di colpi, carica, capriola e picchiata,
manichini d'allenamento (animazioni e armi disegnate da zero, D-022); magia dei quattro elementi con reazioni (D-024), ampliata a 38 magie in cinque scuole con Output,
Pressione, libro, barra delle magie e pergamene (D-027, da RMNDWN K122).

Controlli desktop: WASD/frecce, Spazio salto, trascinamento del mouse per ruotare, rotella
zoom, clic = tap (posa o colpo secondo l'oggetto in mano), clic tenuto = scava/abbatte, clic
destro = apri forziere/banco/falò, 1–6 barra rapida, I o Tab zaino, V camera, Q/E rotazione,
Z/X zoom, N nuovo seme.
Combattimento: J colpo (o clic sul mondo in esplorazione), K forte (tenuto = carica), L o Maiusc
capriola, R cambia arma, H editor dell'eroe, M rimette i manichini davanti, U magia (tenuto), Y magia successiva della barra, P pausa; clic destro = azione
opposta in costruzione/scavo; J tenuto continua la catena.

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
xvfb-run -a godot --path . --script res://tools/e2e_swim.gd -- --out=/tmp/swim.png
xvfb-run -a godot --path . --script res://tools/e2e_combat.gd -- --out=/tmp/combat.png
xvfb-run -a godot --path . --script res://tools/e2e_magic.gd -- --out=/tmp/magic.png
xvfb-run -a godot --path . --script res://tools/e2e_sandbox.gd -- --out=/tmp/sandbox.png
godot --path . -- --screenshot=bag.png --kit --bag=craft --armor=iron --fresh   # pannelli e armature
xvfb-run -a godot --path . --script res://tools/pose_sheet.gd -- --out=/tmp/pose.png --weapon=sword  # o --moves
godot --headless --path . --script res://tools/bench_fluid.gd  # tempi dell'acqua
godot --path . -- --screenshot=shot.png --zoom=0.55 --cam=tps --time=0.9 --seed=42 --dev --lake --at=86.5,142.5 --nowater
```
