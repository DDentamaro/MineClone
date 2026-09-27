# Decisioni di progetto

Registro delle scelte che si discostano dal piano o lo precisano. Ogni voce è
reversibile salvo dove indicato. Formato: contesto → decisione → conseguenze.

## D-001 — Versione Godot fissata: 4.7.2-stable
- **Contesto:** il piano chiede Godot 4.x stabile con versione e template fissati.
  Al 27/09/2026 l'ultima stabile pubblicata su GitHub è 4.7.2 (4.7.3 e 4.8 non esistono).
- **Decisione:** Godot `4.7.2.stable.official.ed1daf0bf`, template di export della
  stessa versione. `project.godot` dichiara la feature `4.7`.
- **Conseguenze:** aggiornare solo con una voce nuova qui e rieseguendo `tools/run_tests.sh`
  e gli export. Installazione riproducibile con `tools/setup_env.sh`.

## D-002 — Renderer: Mobile, con fallback Compatibility
- **Contesto:** piano §7, renderer Mobile per telefoni recenti, spike con Compatibility.
- **Decisione:** `rendering/renderer/rendering_method="mobile"`. Godot passa
  automaticamente a OpenGL 3 (Compatibility) se Vulkan manca.
- **Verificato:** l'export Linux gira con "Forward Mobile" su Vulkan software (llvmpipe);
  senza Vulkan il motore ripiega su OpenGL 3 e la scena si avvia comunque.
- **Aperto:** lo spike comparativo Mobile/Compatibility su telefoni reali resta da fare
  (nessun dispositivo disponibile in M0). Nessuna scelta estetica basata su SDFGI/VoxelGI.

## D-003 — Struttura del repository
- Progetto Godot nella radice del repo; `reference/`, `tools/`, `docs/` hanno `.gdignore`
  (non vengono importati né esportati, ma restano leggibili dai test tramite `FileAccess`).
- `reference/isoterra_proto_v0_64_humanoids.html` è la fonte di verità del porting
  (SHA-256 verificato da un test).
- Le fixture in `tests/fixtures/` sono incluse negli export (`include_filter`) perché M1
  cammina sul mondo fixture; i test unitari sono esclusi.

## D-004 — Convenzioni di assi e coordinate
- **Contesto:** piano §7 "Voxel, mesh e collisioni", adapter di coordinate.
- **Decisione:** Three.js e Godot sono entrambi destrorsi con +Y in alto. La cella voxel
  `(x, y, z)` occupa `[x,x+1)×[y,y+1)×[z,z+1)` in unità di mondo Godot, 1 unità = 1 blocco,
  nessuno scambio di assi. Layout di memoria identico al prototipo:
  `index = (y*Z + z)*X + x`; colonne `z*X + x`. Forward di camera/nodi Godot: −Z.
- **Codice:** `src/core/axes.gd`, `WorldData.index()`; test `test_axes.gd`, `test_layout_memoria`.
- **Aperto per M1/M4:** facing del rig e degli avatar del prototipo, mano dominante, winding
  delle facce e direzione dei raycast vanno verificati con il cubo a sei facce marcate prima
  di portare animazioni e combattimento.

## D-005 — ID blocco stabili = `ISO_CORE.B` v0_64
- 16 ID (aria inclusa), stessi valori, nomi e flag OPAQUE/SOLID/EMIT del prototipo.
  Catalogo come `Resource` (`data/blocks/block_catalog.tres`) rigenerabile da
  `tools/godot_gen_block_catalog.gd` a partire dal manifest della fixture.
- Legno e foglie esistono come ID ma la generazione v0_64 non li scrive nel buffer
  (gli alberi sono istanze separate): istogramma della fixture senza ID 9–12.

## D-006 — Sorgente di riferimento: v0_64 invece di v0_66
- **Contesto:** il piano analizza `isoterra_proto_v0_66_mob_combat(1).html` (8.415 righe,
  SHA `4b40454c…`). L'HTML fornito in questa sessione è
  `isoterra_proto_v0_64_humanoids.html` (8.333 righe, 2.128.428 byte,
  SHA `2f2f771f3a83af9b016de9e024cc38a3ce8282bb97d289809a4edc9474a5c76a`).
- **Decisione:** usare il file fornito come riferimento e rifare l'inventario su di esso
  (`docs/PARITY_MATRIX.md`). I riferimenti di riga del piano non valgono per v0_64.
- **Verificato:** il generatore v0_64 con seme 1931 e `caves:false` produce esattamente il
  buffer blocchi con SHA `ce0d3766…` riportato nel piano, e le stesse statistiche
  (biomi, laghi, fiumi, acqua, spawn, chunk campione): il nucleo del mondo coincide.
- **Da decidere col proprietario:** se esiste la v0_66, aggiungerla in `reference/` e
  aggiornare l'inventario per le funzioni che mancano in v0_64 (vedi matrice).

## D-007 — Toolchain Android usata in M0 (provvisoria)
- `dl.google.com` non è raggiungibile da questo ambiente: l'Android SDK ufficiale non è
  installabile. Usato il pacchetto Ubuntu `android-sdk` (build-tools 29.0.3) solo per
  firmare l'APK con il template precompilato di Godot (niente build Gradle).
- Godot avvisa: "Could not find version of build tools that matches Target SDK" (target 36).
  L'APK firmato verifica con schema v2/v3. Per la distribuzione usare l'SDK ufficiale con
  build-tools allineati al target.
- Keystore di debug generato da Godot, fuori dal repo (`*.keystore` in `.gitignore`).

## D-008 — Test headless con runner interno
- `tests/run_tests.gd` (SceneTree) esegue i metodi `test_*` di `tests/unit/*.gd`, esce con
  codice ≠ 0 se qualcosa fallisce. Nessun addon esterno (GUT/gdUnit) finché non serve.
- `tools/extract_fixture.mjs` (Node ≥ 18) estrae `ISO_CORE` dall'HTML senza modificarlo,
  lo esegue in un contesto `vm` isolato e scrive buffer gzip + manifest con SHA-256.

## D-009 — Nemici rinviati (decisione del proprietario, 27/09/2026)
- I nemici (slime, scheletro, goblin, `BasicEnemy`, `spawnBasicEnemies`) escono dal gate R.
  Restano censiti nella matrice come "rinviati", con le righe sorgente, per poterli
  riprendere più avanti. Vita del giocatore, lock-on e numeri del danno, che servono
  soprattutto contro i nemici, seguono la stessa sorte finché non si decide diversamente.
- La v0_66 non viene aggiunta: il proprietario conferma che cambia poco rispetto alla v0_64.

## D-010 — Camera: isometrica principale, terza persona facoltativa (proprietario)
- Si avvia in isometrica ortografica (yaw 45°, pitch 38°, zoom 0,55–2,4, parametri del
  prototipo). La terza persona (FOV 52°, distanza 6,5, arretramento davanti ai muri) è
  un'opzione dal pulsante "Camera" o dal tasto V; la scelta resta salvata in `user://settings.cfg`.
- Il dispositivo minimo non è vincolante (proprietario): i budget del piano §9 restano
  indicativi.

## D-011 — Collisioni del giocatore autorevoli sui voxel, senza collider fisici
- **Contesto:** il piano propone `CharacterBody3D` e segnala il rischio di collider in
  ritardo rispetto agli edit.
- **Decisione:** il giocatore usa `PlayerMotor`, porting delle regole di `Game.step`
  (rampa sui gradini, discesa a passo, salto, atterraggio) che interroga direttamente
  `WorldData`. Nessun `CollisionShape` per i chunk in M1. Così un blocco appena posato
  blocca il giocatore dal frame successivo, senza finestre di incoerenza.
- **Aggiunte rispetto al prototipo:** corpo alto 1,4 (lo stesso valore del controllo di
  sovrapposizione per piazzare, riga 7101). Testa ferma sotto i soffitti, sporgenze all'altezza
  della testa trattate come muri, ricerca del suolo dopo un salto fatta dalla quota di partenza.
  Nel prototipo, saltando sotto un soffitto, ci si ritrovava sul tetto (piano §4).
- **Da rivedere:** se nemici o proiettili fisici richiederanno Godot Physics, si
  aggiungeranno collider per chunk, ma il giocatore resterà su query voxel.

## D-012 — Controlli touch disegnati a mano, non Button di Godot
- I `Button` reagiscono agli eventi mouse emulati, quindi solo al primo dito.
  `TouchControls` gestisce direttamente `InputEventScreenTouch/Drag` per indice e assegna a
  ogni dito un ruolo (stick, camera, pulsante) fino al rilascio.
- `emulate_mouse_from_touch=false`, `emulate_touch_from_mouse=true`: sul desktop il mouse usa
  lo stesso percorso di un dito. Le dimensioni sono in dp: pulsanti da 52–83 dp.
- Reset di tutti gli input mantenuti alla perdita del focus o alla pausa dell'app.

## D-013 — Meshing su WorkerThreadPool con snapshot copiati
- In Godot 4 i `Packed*Array` sono condivisi per riferimento: il runtime passa ai job una
  copia `duplicate()` dei blocchi, rifatta solo quando cambia `world.revision` (1,77 MB).
- Ogni risultato porta versione del chunk e sessione del mondo: se non corrispondono viene
  scartato e il chunk rimesso in coda. Le mesh si applicano sul main thread entro un budget:
  2 ms/frame in gioco, 12 ms/frame durante il caricamento iniziale.
- M1 usa facce visibili senza greedy (85.865 quad per il mondo fixture). Greedy meshing, AO e
  luce voxel arrivano in M2.
