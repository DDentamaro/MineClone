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

## D-014 — Generatore e fluidi v0_64 in GDScript con parità bit a bit
- **Contesto:** il mondo va generato in Godot (non solo caricato dalla fixture) e deve
  coincidere col prototipo; l'acqua (M3) usa la stessa simulazione.
- **Decisione:** porting 1:1 in `src/world/generation/` (`WorldGenerator`, `IsoNoise`,
  `Mulberry32`, `Biomes`, `JsMath`) e `src/world/simulation/fluid_system.gd` (`FluidSystem`,
  funzioni statiche su `WorldData`).
  - Interi JS emulati (`|0`, `>>>`, `Math.imul`); il secondo prodotto di `hash3` resta in double
    come in JS. `Math.round`/`hypot` con l'algoritmo di V8.
  - `Math.sin/cos/exp/atan2` di V8 sono fdlibm e **non** coincidono con la libm di sistema
    (glibc differisce nel 3–18% dei campioni; su Android c'è bionic): `JsMath` porta fdlibm.
    Le costanti sono costruite dai bit IEEE perché il tokenizer di GDScript arrotonda male i
    letterali a 21 cifre (14 costanti su 54 sbagliate di 1 ulp); i letterali brevi sono corretti.
  - `Float32Array`/`Int8Array` → `PackedFloat32Array`/byte in complemento a due; `Int16Array`
    → `PackedInt32Array` (valori piccoli); coordinate e vettori in double (niente `Vector2/3`,
    che sono a 32 bit).
  - Stato dei fluidi su `WorldData` (`fluid_active`, `fluid_queue`, `fluid_dirty`,
    `fluid_clock`, `fluid_renew_sources`) invece di un oggetto separato: rispecchia i campi di
    `World` nel prototipo. I `Set`/`Map` JS diventano `Dictionary` (ordine d'inserimento
    conservato, anche dopo `erase` e reinserimento); le chiavi stringa `"cx,cz"` diventano `Vector2i`.
  - Array vuoto = campo assente nel prototipo (`if(W.waterGuide)` ecc.).
- **Prestazioni:** stesse operazioni ma `hash3` precalcolato su griglie (`Fbm2Lattice`,
  `Noise3Lattice`) e scansioni `find()` delle sole celle d'acqua. Mondo 192×48×192 seme 1931:
  ~2,7 s in GDScript headless contro ~1,9 s in Node (era 8,4 s senza griglie).
- **Verifica:** `tools/extract_gen_stages.mjs` (copia rattoppata di `ISO_CORE`, HTML intatto)
  scrive `tests/fixtures/gen_v064`: campioni di rumore/Math, sha per passata e per fase,
  scenario di gioco dei fluidi. Test unitari sul mondo 64×32×64 con grotte; i mondi grandi con
  `tools/verify_generator.gd` (troppo lenti per la suite).
- **Limiti noti:** `rem_pio2` per |x| > 2^19·π/2 non è portato (mai usato dal generatore);
  `-0` può diventare `+0` in alcuni clamp (irrilevante per i risultati).

## D-015 — Pipeline di resa: render target a 360 righe e illuminazione in `light()`
- **Render target:** il mondo 3D è in una `SubViewport` alta 360 righe (270/450 dal pannello),
  come `RT_H` del prototipo, scalata a schermo con filtro nearest. Ha un pixel di bordo per lato:
  la camera isometrica è agganciata alla griglia dei pixel e l'immagine viene spostata del resto
  sub-pixel (uSub del prototipo).
- **Post-processing:** un quad a tutto schermo figlio della camera (`post.gdshader`, priorità 127)
  legge `hint_screen_texture` e `hint_depth_texture`: contorni, spigoli, raggi, nebbia TPS, notte,
  grading e cielo (`skyFS`) sui pixel senza profondità.
- **Luce:** gli shader dei blocchi, degli alberi e dell'erba calcolano il colore "di schermo" del
  prototipo e lo scrivono in `DIFFUSE_LIGHT` dentro `light()`, convertito in lineare. Con luce
  ambiente e tonemap disattivati il risultato a schermo coincide con la formula del prototipo;
  `ATTENUATION` della luce direzionale di Godot sostituisce la shadow map del prototipo
  (l'ombra copre tutta la vista, non solo 34 unità attorno al giocatore).
- **Acqua provvisoria:** disegnata nel passo opaco con dithering Bayer, altrimenti il quad di post
  (che legge lo schermo prima del passo trasparente) la cancellerebbe. La mesh dei fluidi è M3.
- **Parametri condivisi:** uniform globali (`[shader_globals]` in `project.godot`), aggiornati
  da `DayCycle` (porting di `skyState`) e dalla camera.
- **Differenza nota:** il prototipo esclude i pixel d'erba dai contorni usando l'alfa del render
  target; nel passo opaco di Godot l'alfa non è scrivibile, quindi i ciuffi sui bordi hanno un
  contorno più scuro.

## D-016 — Raggi X a passata singola
- Il prototipo rende la scena due volte e sfuma verso la seconda passata senza occlusori. Qui gli
  shader scartano i frammenti davanti al giocatore dentro la capsula piedi–testa con una soglia
  Bayer che sale verso il centro. Copertura (`coverage`) e smorzamento sono quelli del prototipo,
  alberi inclusi. Costa una passata sola, ma il bordo del buco è retinato invece che sfumato.

## D-017 — Fixture numeriche in binario
- Il parser JSON di Godot non arrotonda correttamente i decimali lunghi (differenze di 1 ulp): i
  riferimenti a virgola mobile (posizioni degli alberi, template, fili d'erba) sono salvati come
  Float32/Float64 binari gzip. Il JSON resta per hash e conteggi.
- `tools/run_tests.sh` fallisce anche se il log contiene `SCRIPT ERROR`, `ERROR:` o `WARNING:`,
  perché in GDScript un errore a runtime non interrompe il test.

## D-018 — Mondo all'avvio e nuovi semi
- All'avvio si usa la fixture verificata del seme 1931 (niente generazione né calcolo della
  luce). "Nuovo seme" genera un mondo con `WorldGenerator` + `LightEngine` su un thread di lavoro
  (~4,4 s su un thread in questo container) mentre si continua a giocare nel mondo attuale; poi
  runtime e vegetazione ripartono con una nuova sessione. Seme casuale come il prototipo
  (`Math.random()*1e6`).
