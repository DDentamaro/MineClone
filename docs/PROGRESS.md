# Avanzamento

## Stato corrente: M0 — Baseline · completata (con limiti dichiarati)

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

### Punto di ripresa: M1 — Percorso giocabile minimo
Ordine proposto:
1. `ChunkMesher` a facce visibili (ArrayMesh per chunk, colori per ID) + test sui bordi dei chunk.
2. `WorldRuntime`: istanzia i 432 chunk dalla fixture, collider per chunk (`ConcavePolygonShape3D`
   o box semplificati), budget sul main thread.
3. Test del cubo a sei facce marcate (winding, normali, facing, raycast) — D-004.
4. `WorldEditService.try_apply` minimale (edit di debug) con versioni chunk e remesh dei vicini.
5. Player `CharacterBody3D` con parametri del prototipo (speed 5,5, stepUp 1,05, jumpH 2,1, g 28).
6. `CameraRig` ISO ortografica + TPS; stick virtuale e drag camera con ownership delle dita.

Criterio di uscita M1: camminare sul terreno fixture, salire/scendere gradini, collidere con
muri e soffitti, modificare un blocco in debug, nessun input bloccato.

### Decisioni da chiedere al proprietario (non bloccanti per M1)
- Esiste la v0_66 citata dal piano? Se sì, aggiungerla in `reference/` (D-006).
- Telefono più debole su cui deve girare e priorità Android/iOS.
- Peso della visuale isometrica rispetto alla terza persona.
