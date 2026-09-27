# Avanzamento

## Stato corrente: M1 — Percorso giocabile minimo · completata (senza prova su telefono)

Sessione del 27/09/2026 (stessa di M0).

### Fatto
- `ChunkMesher`: facce visibili per chunk 16³, winding frontale verificato, acqua in una
  superficie trasparente separata, torce come paletti, colori base dell'atlante del prototipo.
- `WorldRuntime`: meshing su `WorkerThreadPool` con snapshot dei blocchi, priorità ai chunk
  vicini al giocatore, applicazione a budget sul main thread, scarto dei risultati obsoleti o
  di un mondo precedente (D-013).
- `WorldEditService`: edit atomici, versioni per chunk (vicini inclusi), `surface` aggiornata,
  rifiuto su conflitto di versione; `can_place` del prototipo.
- `VoxelQuery`: raycast DDA del prototipo, `field_height`/`field_support`.
- `PlayerMotor`: porting di `Game.step` con collisioni volumetriche (D-011).
- `CameraRig`: isometrica ortografica con i parametri del prototipo, terza persona facoltativa
  con arretramento davanti ai muri, input relativo alla camera (D-010).
- `TouchControls`: stick flottante, drag camera, pinch, pulsanti Salto/Modo/Blocco/Camera con
  ownership delle dita (D-012). Tastiera: WASD, Spazio, F modo, B/1/2/3/T blocco, V camera,
  Q/E rotazione, rotella zoom.
- Modi: Esplora (il tap non fa nulla, come nel prototipo), Costruisci (terra, pietra, sabbia,
  legno, torcia; portata 7,5; mai dentro il giocatore), Scava (debug; y=0 protetto).

### Test realmente eseguiti (M1)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 58/58 PASS, log senza warning |
| `tools/e2e_touch.gd` sotto Xvfb (tocchi iniettati: stick 60 frame, tap in Costruisci) | giocatore spostato, blocco posato e rimeshato, screenshot |
| `tools/bench_mesh.gd` (headless, 1 thread) | 432 chunk in ~1,3 s, 85.865 quad, chunk peggiore 7 ms |
| Avvio con Xvfb + Vulkan software (llvmpipe) | mondo completo in ~9 s a 5–8 FPS: rendering software, non indicativo di un telefono |
| Export Android debug (arm64) + `apksigner verify`; export Linux avviato | OK; test e tool esclusi dal pacchetto |

### Limiti aperti dopo M1
- **Nessuna prova su telefono reale né misura FPS.** La costruzione iniziale in container è
  limitata dal rendering software.
- Acqua attraversabile e ferma (niente nuoto/fluidi: M3); il giocatore cammina sul fondo.
- Nessun albero né erba (M2); luce/AO del prototipo non ancora usate (resa piatta + ombra
  direzionale di Godot).
- Scavo solo di debug; costruzione gratuita (inventario in M5).
- Pixel-art render target, outline, x-ray e pixel snap della camera: M2.

### Punto di ripresa: M2 — Mondo e resa
1. Greedy meshing con AO per vertice e luce sole/blocchi dai buffer `sun`/`blk`, rispettando i
   confronti del prototipo (chunk (6,1,6) = 62 quad greedy).
2. Propagazione locale della luce sugli edit (non ricalcolo globale come il worker originale).
3. Alberi (3 archetipi, collisione cilindrica) ed erba, ricavati dal seme come nel prototipo.
4. Porting del generatore (`generator_version=v0_64`) confrontato con la fixture.
5. Estetica: render target a bassa risoluzione, palette dipinta, outline, cielo e ciclo giorno,
   x-ray/silhouette per l'occlusione in isometrica.

## M0 — Baseline · completata (con limiti dichiarati)

Sessione del 27/09/2026. Ambiente: container Linux x86_64 senza GPU né telefono.

### Fatto
- Repository inizializzato; progetto Godot 4.7.2 nella radice (`project.godot`, renderer Mobile,
  orientamento orizzontale, avvisi di tipizzazione GDScript attivi).
- HTML di riferimento in `reference/`, integro (test su dimensione e SHA-256).
- Inventario del sorgente v0_64 (`docs/INVENTORY_v064.md`) e matrice di parità (`docs/PARITY_MATRIX.md`).
- Fixture del seme 1931 (`caves:false`, 192×48×192) estratta dal core originale con
  `tools/extract_fixture.mjs`: buffer `blocks`, `fluid`, `sun`, `blk`, `surface`, `biome`,
  `waterLevel` compressi gzip, con manifest e SHA-256. Hash dei blocchi `ce0d3766…`, uguale a
  quello del piano.
- Codice: `WorldData` (layout del prototipo, `spawn_point()` portato), `WorldFixture` (carica e
  verifica gli SHA), `BlockDefinition`/`BlockCatalog` (`.tres` generato), `Axes`, `GameRoot`
  con la scena `main.tscn` che carica la fixture e ne mostra lo stato.
- Test headless: 11 test, tutti passano (`tools/run_tests.sh`). Controllato che un'asserzione
  alterata a mano faccia fallire il runner con codice di uscita 1.
- Export: APK Android di debug (arm64-v8a, firmato v2/v3, `apksigner verify` OK, fixture inclusa
  negli asset); build Linux esportata e avviata sotto Xvfb con renderer Forward Mobile
  (Vulkan software llvmpipe): la fixture viene caricata e verificata dal `.pck`.

### Test realmente eseguiti
| Prova | Esito |
|---|---|
| `node tools/extract_fixture.mjs 1931` (2 generazioni) | deterministica; statistiche = piano §2 |
| `tools/run_tests.sh` | 11/11 PASS |
| Avvio editor/progetto headless (`--import`) | nessun errore |
| Export Android debug + `apksigner verify` + `aapt dump badging` | OK; minSdk 24, targetSdk 36 |
| Export Linux + avvio con `xvfb-run` | fixture verificata in ~60 ms, spawn (96,5; 28; 96,5) |

### Non verificato / bloccato
- **APK mai installato su un telefono**: nessun dispositivo. Nessuna misura di FPS.
- Android SDK ufficiale non scaricabile (`dl.google.com` bloccato): firma fatta con build-tools
  29.0.3 di Ubuntu (D-007). Per le build di rilascio serve l'SDK ufficiale.
- iOS: nessun Mac/Xcode; export non tentato.
- Renderer Mobile provato solo su Vulkan software; lo spike Mobile vs Compatibility su hardware reale resta aperto.

### Decisioni del proprietario (27/09/2026)
- v0_66 non necessaria; nemici rinviati (D-009).
- Dispositivo minimo non vincolante; isometrica principale con terza persona facoltativa (D-010).
