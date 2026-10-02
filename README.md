# IsoTerra (MineClone)

Ricostruzione in **Godot 4.7.2** del prototipo HTML *IsoTerra* e sua evoluzione in un
piccolo sandbox voxel action per telefono (orizzontale). Il piano di lavoro è diviso in
milestone M0–M8 (traguardo **R** = parità col prototipo, traguardo **G** = gioco).

### Esperienza del giocatore — D-036

Il gioco ora presenta un HUD compatto con oggetto impugnato, ora, obiettivo attivo e
avanzamento della raccolta. **Menu**, **Esc** o **P** aprono una pausa completa con diario,
comandi, salvataggio, ritorno al campo e impostazioni persistenti: dettaglio, volume,
movimento ridotto, controlli mancini e suggerimenti. Gli strumenti di sviluppo sono nel menu.

Il diario propone otto traguardi introduttivi, completabili anche fuori ordine: esplorare,
raccogliere, creare e posare un banco, colpire, schivare, fissare il ritorno al falò e trovare
un tesoro. Il progresso resta nella partita; i vecchi salvataggi rimangono leggibili.
**F** o il suggerimento sullo schermo usa l'oggetto vicino. Anche il clic destro richiede
portata e linea libera. Il salto ricorda una pressione nei 120 ms prima dell'atterraggio e
consente 100 ms di tolleranza dopo un bordo; tenerlo premuto non provoca salti ripetuti.

È un primo passaggio sull'esperienza, non una release finale: restano da verificare resa
visiva e usabilità su dispositivi reali, prestazioni mobile e bilanciamento complessivo.

Stato attuale: **M5 — sandbox persistente con equipaggiamento RPG** (D-026), dopo il gate R e **M4 — action** (vedi `docs/PROGRESS.md`): generatore, luce,
mesh, vegetazione e acqua identici al prototipo; resa dipinta con contorni, cielo, giorno/notte
e acqua fusa come nella reference; nuoto e guado, schizzi; camera isometrica (terza persona
e prima persona facoltative, D-037), controlli touch, costruzione e scavo di debug, pannello sviluppatore (⚙).
Eroe animato con editor, cinque armi con catene di colpi, carica, capriola e picchiata,
manichini d'allenamento (animazioni e armi disegnate da zero, D-022); eroe del prototipo (CHARGEN) con passo procedurale e danno dal contatto della lama (D-028), mira assistita leggera e catene che vanno a segno con ogni arma (D-033); moveset e ritmi per arma, lancia perforante e passo delle gambe nei colpi, Lock sul bersaglio con triangolo rosso, camminata laterale e colpi che seguono il bersaglio agganciato (D-035);
inventario unico con la miniatura dell'eroe e armatura che copre il corpo (D-030). Il sistema di magia (D-024…D-035) è stato tolto
del tutto in D-037.

Controlli desktop: WASD/frecce, Spazio salto, trascinamento del mouse per ruotare, rotella
zoom, clic = tap (posa o colpo secondo l'oggetto in mano), clic tenuto = scava/abbatte, clic
destro = apri forziere/banco/falò, F = interagisci con l'oggetto vicino, 1–6 barra rapida,
I o Tab zaino, V camera (isometrica → terza persona → prima persona), Q/E rotazione, Z/X zoom, N nuovo seme (con conferma),
Esc (o indietro su Android) chiude il pannello aperto oppure apre la pausa.
Equipaggiare: nello zaino tocca un oggetto e usa "Impugna" (armi, attrezzi, blocchi: vanno nella
barra rapida e in mano) o "Indossa" (armature); la scheda Equipaggiamento mostra Mano e i quattro
pezzi con i confronti. Un'armeria con tutte le armi è accanto al punto di partenza.
Combattimento: J colpo (o clic sul mondo in esplorazione), K forte (tenuto = carica), L o Maiusc
capriola, R o clic centrale aggancia/sgancia il bersaglio, H editor dell'eroe, M rimette
i manichini davanti, P pausa; J tenuto continua la catena. In prima persona si guarda
trascinando (dito o mouse), lo stick cammina dove si guarda, i colpi partono verso il mirino e
del corpo si vedono solo le braccia dritte e la mano con l'oggetto impugnato (D-038).
Armi e attrezzi sono a cubetti come i blocchi del mondo; ascia e piccone ripetono sempre lo
stesso colpo; sul telefono due dita zoomano in isometrica e in terza persona (D-039). La lancia
colpisce solo di punta; i colpi hanno un ritmo più calmo e la camera non balla (D-040).
La lancia affonda dritta anche in terza persona e ferisce solo con la punta; durante il gioco
non ci sono più riquadri in alto, il Diario è in Menu > Diario (D-041). La terza persona è fissa
come l'isometrica (ruota e zooma solo l'utente, i muri si aprono coi raggi X); spadone e martello
colpiscono più pesanti (D-042). L'eroe ha l'altezza e la testa grande del prototipo, con arti un poco più lunghi (D-045).

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
godot --headless --path . --script res://tools/e2e_session.gd  # menu, tocchi e salvataggio
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
xvfb-run -a godot --path . --script res://tools/e2e_fps.gd -- --out=/tmp/fps.png
xvfb-run -a godot --path . --script res://tools/e2e_walk.gd -- --out=/tmp/walk.png
xvfb-run -a godot --path . --script res://tools/e2e_armory.gd -- --out=/tmp/armory.png
xvfb-run -a godot --path . --script res://tools/e2e_drop.gd -- --out=/tmp/drop.png
xvfb-run -a godot --path . --script res://tools/gait_sheet.gd -- --out=/tmp/gait.png
xvfb-run -a godot --path . --script res://tools/e2e_sandbox.gd -- --out=/tmp/sandbox.png
godot --path . -- --screenshot=bag.png --kit --bag=craft --armor=iron --fresh   # pannelli e armature
xvfb-run -a godot --path . --script res://tools/pose_sheet.gd -- --out=/tmp/pose.png --weapon=sword  # o --moves
godot --headless --path . --script res://tools/bench_fluid.gd  # tempi dell'acqua
godot --path . -- --screenshot=shot.png --zoom=0.55 --cam=tps --time=0.9 --seed=42 --dev --lake --at=86.5,142.5 --nowater
```
