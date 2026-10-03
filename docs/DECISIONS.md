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

## D-019 — Scena in valori "di schermo" e acqua fusa in spazio schermo
- **Contesto:** il prototipo scrive nel render target i colori così come li calcola e fonde lì
  l'acqua trasparente; Godot fonde in lineare. Con acqua scura sopra un fondale chiaro la
  fusione lineare fa prevalere il fondale e l'acqua risultava grigia (confronto misurato).
- **Decisione:** la `SubViewport` del mondo usa `use_hdr_2d`, che conserva i valori scritti
  senza conversioni (verificato: 0,5/0,5 fusi a metà danno esattamente 0,25/0,75). Tutti gli
  shader scrivono il colore di schermo del prototipo (`out_color`, niente `to_linear`).
- **Ordine:** il quad di post ha `render_priority = -128` e gira prima delle superfici
  trasparenti. Acqua (5) e grani (8/9) si fondono dopo e applicano da sé la parte di colore del
  blit (`post_color`: notte, vignetta, grading), condivisa in `post_common.gdshaderinc`.
  Differenza residua: i contorni del fondale sotto l'acqua vengono prima della fusione invece
  che dopo; i raggi del sole non si sommano sui pixel d'acqua.
- **Verifica:** confronto a pixel con il prototipo al lago (ora bloccata 0,35): acqua entro
  pochi valori su 255, terreno entro 0–3.
- **Da verificare:** con il renderer Compatibility (fallback senza Vulkan) `use_hdr_2d` va provato.

## D-020 — L'acqua riproduce l'ombra "sempre piena" del prototipo
- Nel prototipo il materiale dell'acqua non riceve la shadow map (HTML 6758): `worldShadow`
  legge una texture vuota e restituisce `1 - uShadowStrength` in tutto il riquadro d'ombra
  attorno al giocatore. È questo che rende l'acqua blu scura nella reference. Lo shader
  dell'acqua usa quindi ombra 0 (luce diretta al 16% di giorno) invece di `ATTENUATION`.
- Nota per i confronti: nel browser headless il prototipo gira a pochi FPS con dt limitato a
  0,05 s, quindi il suo orologio resta vicino alle 8:24; i confronti vanno fatti con l'ora
  bloccata (`--time=0.35` qui, `ISO.game.time=0.35` e `dayLen` enorme là).

## D-021 — Acqua in gioco, grani ed effetti
- `FluidRuntime`: tick di 0,25 s sul main thread come il prototipo (peggiore ~13,5 ms con acqua
  in moto in questo container), mesh per tile 16×16 su thread da una finestra 18×48×18 copiata
  (~2,4 ms), ricostruzioni al massimo ogni 100 ms; identica al prototipo (test di parità).
- Gli edit dei blocchi chiamano `editFluid` e `refreshWaterColumn` come `applyEdit`.
- `Grains` porta il pool del prototipo (2.600 grani, additivo/opaco, pixel agganciati); lo userà
  anche la magia (M4). Gli schizzi delle bracciate usano una posizione della mano stimata finché
  l'avatar (M4) non espone le mani.
- Camera: Q/E ruotano in continuo a 1,6 rad/s e Z/X zoomano come il prototipo (in M1 erano scatti).

## D-022 — Eroe, animazioni, armi e combattimento disegnati da zero (M4)
- **Richiesta del proprietario (27/09/2026):** animazioni e mesh delle armi si fanno da zero,
  senza prendere esempio da IsoTerra, con un combattimento più dinamico.
- **Eroe:** anche l'aspetto è nuovo (`AvatarRig`, 15 ossa rigide con scatole smussate
  generate in codice) invece della CHARGEN del prototipo, per avere proporzioni e assi pensati
  per le animazioni nuove. La ricetta (`AvatarRecipe`: pelle, capelli, acconciatura, veste,
  brache, corporatura) si salva in `user://settings.cfg` (sezione `avatar`), non nella chiave
  `isoterra.hero.dna`. Se servisse la CHARGEN si può aggiungere come altra fonte di mesh.
- **Animazione procedurale** (`AvatarAnimator`): guardia per arma + ciclo di corsa legato alla
  distanza percorsa + salto/atterraggio + guado/nuoto a crawl + capriola; i colpi seguono il
  tempo esatto del `CombatController` (carica → scatto → rientro) tra tre pose chiave per
  attacco; una molla smorzata per osso dà inerzia e rimbalzo. IK a due ossa per la mano
  sinistra sulle armi a due mani.
- **Armi** (`WeaponMeshes`): pugni con fasce, spada, lancia, martello, spadone, tutte a facce
  piatte con la stessa luce a bande dei blocchi (`actor.gdshader`).
- **Combattimento** (`CombatController`, dati in `WeaponLibrary`): catene diverse per arma con
  rami forti, carica tenendo premuto, aggancio morbido con scatto che copre la distanza,
  capriola con invulnerabilità che annulla il rientro, attacco dopo la capriola, picchiata
  dall'aria con urto ad area, giri con colpi ripetuti; colpi ad arco spazzato, affondo o area,
  un colpo per bersaglio per attacco, hitstop, scossa della camera, scia della lama, scintille e
  polvere con i grani. Le combo della spada del prototipo (L…LLLL, H, LH, LLH) non sono portate:
  la riga della matrice di parità diventa "sostituita".
- **Controlli:** Colpo, Forte (tenuto = carica), Schiva, Arma, Eroe; tocco sul mondo in
  esplorazione = colpo. Tastiera J / K / L o Maiusc / R / H; M rimette i manichini.

## D-023 — Manichini d'allenamento come bersagli
- Con i nemici rinviati (D-009) i colpi servono a qualcosa solo con un bersaglio: tre
  `TrainingDummy` vicino allo spawn (pannello ⚙ "Manichini" li rimette davanti al giocatore).
  Volano, oscillano, si rompono a 0 PV e ricompaiono, poi tornano al loro posto. Usano
  l'interfaccia `CombatTarget` che useranno i nemici. Il giocatore non li attraversa.

## D-024 — Magia: regole del prototipo, lancio con la mano sinistra
- `MagicSystem` porta le regole della magia v0_64 (inventario §8): quattro dardi con gli stessi
  numeri, mana 100 con rigenerazione 9/s (×0,3 durante il lancio), impegno al 35%, tocco =
  lancio automatico, mira al bersaglio o 7 unità avanti con compensazione balistica, dardi con
  collisione su bersagli, voxel e tronchi, rimbalzo del masso, aria che trapassa; stati
  (bruciatura a pile, bagnato, lento, spinto) e `status_react`; fuoco su erba/legno/foglie con
  l'automa a tick 0,25 s, bagnato che spegne e protegge, cratere del masso (mai sotto i piedi),
  vento della spina che soffia le braci, lava → pietra scura.
- **Diverso dal prototipo:** si lancia con la **mano sinistra** e l'arma resta in pugno, così la
  magia si alterna ai colpi senza cambiare modalità (il prototipo sostituiva l'arma). Animazione
  e grani della raccolta e dei dardi sono disegnati da zero (D-022). I blocchi dei crateri si
  contano (`crater_items`) ma finiscono nell'inventario solo in M5.
- **Non portato (per ora):** luci puntiformi della sfera e dei lampi, audio sintetizzato,
  vento sull'erba (`uSpellWind`) e scossa degli alberi, numeri del danno (D-009). Le scritte
  delle reazioni (VAPORE, SHOCK TERMICO, SPENTO, CRATERE, stati) ci sono (`FloatingText`).
- **Controlli:** "Magia" (tenuto = carica, rilascio = lancio) e selettore dell'elemento nella
  riga in alto; tastiera U (tenuto) e Y.

## D-025 — Gate R: cosa è stato recuperato e cosa resta dichiarato
- **Recuperato per il gate** (funzioni attive del prototipo che mancavano o erano parziali):
  colpi che non passano i muri; terza persona adattiva (contesto, Auto, alberi, suolo, orizzonte
  e sole proiettati, erba a distanza); le chiavi di preferenze del prototipo (righe, spigoli,
  terza persona, Auto, inclinazione e zoom TPS); luci puntiformi della magia, vento sull'erba e
  alberi scossi; audio sintetizzato della magia; niente contorni sui ciuffi d'erba (stencil: il
  prototipo scriveva alfa 0, in Godot un opaco non può, quindi due varianti del post);
  estrazione/rinfodero dell'arma e posa rilassata; colpo tenuto che ripete; pausa; rotazione e
  zoom a pulsante; Hitbox; cubo del cursore e clic destro; eroi predefiniti e copia/incolla della
  ricetta; contatore dei blocchi dei crateri.
- **Differenze dichiarate che restano:** raggi X a passata singola (D-016); contorni del fondale
  sotto l'acqua e raggi del sole sull'acqua (D-019); eroe, animazioni, armi e combo nuovi (D-022);
  lancio con la sinistra (D-024).
- **Mappa dei tasti:** diversa dal prototipo dove il tasto serviva a funzioni rinviate (L e Tab =
  aggancio) o dove M1 aveva già assegnato il tasto (V = camera, B = blocco). Il prototipo usa V
  per l'arma e M per la magia; qui R/Y/U. Le funzioni ci sono tutte, anche a pulsante.
- **Non verificabile qui:** telefono, FPS, renderer Compatibility. Il gate R è chiuso "senza prova
  su dispositivo", come le milestone precedenti.

## D-026 — M5: sandbox persistente senza grotte, con equipaggiamento RPG
- **Richiesta del proprietario (28/09/2026):** niente grotte in M5; al loro posto aspetti da
  gioco di ruolo: equipaggiamento (scelto) e magia da ampliare partendo da un file che
  manderà (D-027, fatto). Le grotte restano dormienti come nel prototipo.
- **Oggetto in mano:** la barra rapida (6 slot, i primi dello zaino da 30) decide tutto: un
  blocco o una stazione si posano con un tocco, un'arma o un attrezzo colpisce, tenere premuto
  scava o abbatte. Il pulsante "Modo" e il ciclo dei blocchi del prototipo non servono più; lo
  scavo libero resta come "Scava debug" nel pannello ⚙. Tasti 1–6, I/Tab per lo zaino.
- **Raccolta:** regole dormienti del prototipo (`BLOCK_INFO`, `breakTime`, `treeTime`,
  `killTree`) rese attive, con due aggiunte: livelli dei minerali (rame da pietra, ferro da
  rame, oro da ferro) e raccolta a mani nude di terra, sabbia e legno (altrimenti non si
  potrebbe cominciare). Se il bottino non entra nello zaino il blocco non si rompe.
- **Materiali:** legno < pietra < rame < ferro < oro; l'oro si consuma prima ma dà Output alla magia (D-027). Tutti
  gli attrezzi e le armi hanno usura; le armature (rame, ferro, oro) hanno difesa.
- **Rarità e affissi:** Comune, Non comune, Raro, Epico con 0–3 affissi (forza, critico, mente,
  flusso, arcano, scavo, vento, tempra). Il craft dà per lo più oggetti comuni; i dieci forzieri
  del tesoro sparsi nel mondo (deterministici per seme) danno bottino migliore lontano dallo
  spawn. Le statistiche agiscono davvero: danno e critico dei colpi, mana/rigenerazione/danno
  delle magie, velocità di scavo e di movimento; la difesa aspetta i nemici (D-009).
- **Stazioni e contenitori:** banco da lavoro, fornace, forziere e falò sono oggetti piazzati (non
  voxel: il catalogo dei blocchi resta quello del prototipo). Il falò è il punto di ritorno e
  salva la partita.
- **Salvataggio:** un file con intestazione, controllo e zstd; scrittura su .tmp verificata, poi
  il file precedente diventa .bak; in lettura si ripiega sul .bak. Si salvano blocchi, acqua,
  superficie, giocatore, zaino, armatura, oggetti piazzati con contenuto, alberi abbattuti,
  falò, ora e mana; il resto si rigenera dal seme e la luce si ricalcola. Salvataggio automatico
  ogni 60 s, al falò, alla chiusura e quando l'app va in pausa.
- **Interfaccia:** pannello a tutto schermo (Zaino, Equipaggiamento, Craft, Forziere) disegnato
  e gestito a mano come i controlli touch, perché i Control di Godot non ricevono i tocchi senza
  l'emulazione del mouse. Il mondo si ferma mentre è aperto.

## D-027 — Magia ampliata da RMNDWN K122
Fonte: il file del proprietario `RMNDWN_k122.html` (SpellForge v78, roster Karma K29/K33,
nucleo K116, segni di materia K122). Presi regole e numeri, non il codice.
- **Niente mana.** Ogni magia ha un *Output* richiesto; si lancia solo se non supera l'Output del
  caster (base 60 + equipaggiamento + studio). Ogni lancio alza la *Pressione* del nucleo:
  `max(.12, output/tetto·.85)`, ×.55 se l'elemento cambia rispetto al lancio prima; cala di
  .24/s (×.45 mentre si lancia, più in fretta sopra .75); a 1 il nucleo è saturo e riparte sotto
  .85; sopra .75 la raccolta si allunga fino a +60%. Arco attorno al pulsante Magia (rosso da saturo).
- **Tempi RMNDWN:** impegno al 78% della raccolta, coda di un lancio dal 55% o durante il recupero;
  chi è spinto perde la raccolta non impegnata. I quattro dardi del prototipo restano con le loro
  regole (impegno al 35%, rimbalzo del masso, aria che trapassa) e Output = costo × 2.
- **Libro:** 38 magie in cinque scuole (fuoco, acqua, aria, terra, Karma) e quattro livelli, con
  i numeri del file: proiettili, raffiche a ventaglio, sfere che scoppiano, meteorite dal cielo,
  raggi Karma istantanei con *coerenza* `max(minimo, e^(−decoerenza·t))` (forti da vicino),
  getti sostenuti (danno integrato ogni 0,1 s, indipendente dal frame rate; spinta come forza),
  colonne, punte, sisma a quattro anelli, pioggia, ciclone, vuoto che attira, ascensione, onda,
  colpi d'aria ravvicinati, braci, flusso (velocità ×1,55), muro e colonna di terra.
- **Muro e colonna sono voxel veri** (terra) che fermano corpi, dardi e raggi e crollano dopo
  6–8 s; non si posano sopra corpi o giocatore e non finiscono nel salvataggio.
- **Reazioni in più** (oltre a vapore, shock termico e spinta sul bagnato del gate R):
  *Ventaglio* (aria su chi brucia: una pila in più e fiamma ai vicini entro 3,2),
  *Conduzione* (Karma sul bagnato: spinta ×1,8 e metà del danno agli altri bagnati entro 3),
  *fango* (le pozze bagnano e rallentano a ×0,70 chi ci sta dentro, giocatore compreso).
- **Segni di materia** (K122): bruciature 12 s, pozze 7,5 s, crateri 10 s, al massimo 16, fusi
  se vicini; fatti con i grani. **Grammatica d'impatto** per elemento: scossa e hitstop (terra la
  più pesante, aria la più leggera); i colpi sostenuti non fermano il tempo.
- **Due mani** dai 120 di Output: posa di raccolta e spinta con entrambe le braccia. Cerchio ai
  piedi durante la raccolta, più largo con l'Output.
- **Aggiunte RPG (non nel file, che non ha progressione):** all'inizio si conoscono le 16 magie di
  livello 1; le altre si imparano dalle *Pergamene* (nei tesori, livelli alti lontano dallo
  spawn) e ognuna alza l'Output di 5. Gli affissi "della Mente" e l'oro danno Output, quelli "del
  Flusso" accelerano la dissipazione della Pressione.
- **Interfaccia:** barra di 5 magie sul bordo destro (tocco = scelta, slot vuoto = apre il libro;
  Y scorre), scheda "Magie" nello zaino (colonne per scuola, dettagli, bloccate e oltre
  l'Output segnate, tocca una magia e poi uno slot). Libro e barra si salvano.

## D-028 — Eroe del prototipo, passo procedurale, hitbox sulle armi, oggetti a terra
Richiesta del proprietario dopo la prova della magia ampliata: locomozione dell'eroe "pessima",
tornare al personaggio di IsoTerra (più piccolo) tenendo le animazioni di combattimento; danno
legato alle armi e ai pugni per avere un tempo chiaro; oggetti gettati che si possano riprendere
(5 minuti); selezione delle magie più chiara. Supera in parte D-022 (l'aspetto e le gambe).
- **Eroe:** porting di CHARGEN v2 e CHARGEN.rig del prototipo (`HeroChargen`): scatole smussate
  ad arco, viso a placche, 16 acconciature (i due capelli "originali" estratti invariati in
  `data/hero/hair.json` da `tools/extract_hero_hair.py`), cappelli, barbe, cicatrici, pitture,
  accessori, occlusione cotta nella posa di riposo e pezzi riespressi nelle ossa. Misure del rig
  del prototipo: anca .32, collo .80, omero .21, avambraccio+mano .28, coscia .15, stinco+piede
  .185, testa ×.54 (grande). L'occlusione si calcola su un thread (l'eroe appare subito senza,
  poi si aggiorna) con una cache per ricetta. Il personaggio guarda -Z: i pezzi del modello
  (+Z davanti) sono ruotati di 180°, restando anatomicamente corretti.
- **Ricetta:** il DNA di CHARGEN (v2) sostituisce quello di M4; una ricetta v1 salvata torna a
  "Eroe 1". L'editor fa scorrere le scelte del prototipo (acconciatura, cappello, occhi,
  sopracciglia, bocca, barba, viso, maniche, gambe, schiena, cintura) e le sue palette; "Casuale"
  usa il generatore del prototipo (Mulberry32, stesso seme = stesso eroe).
- **Passo:** porting di `CharacterRig.updateAnimation` (costanti GAIT) in `GaitLegs`: piedi
  piantati nel mondo, IK a due ossa col ginocchio in avanti, cadenza e appoggio secondo la
  velocità, arco 9,48(1-u)³u, bersaglio ri-stimato ogni frame, assestamento da fermi, bacino che
  scende sui gradini, bob, ondeggio e inclinazione, gambe raccolte in aria. L'animatore di M4 tiene
  braccia, busto e colpi (le pose chiave restano); durante capriola e nuoto le gambe tornano sue.
  Verificato che il piede d'appoggio non scivola (test e prova e2e: 0 mm su 21 m di corsa).
- **Armi:** stesse mesh di M4 a scala 0,72 nella mano (la spada è ~0,7 m come nel prototipo).
  Armature del M5 rifatte a cubi smussati sulle nuove proporzioni.
- **Hitbox/hurtbox (come il prototipo):** il danno nasce dal contatto tra sfere lungo il tratto
  che ferisce dell'arma (o su mano e polso a mani nude) e la capsula verticale del bersaglio, con
  test spazzato fra un passo e l'altro. Ferisce solo nella fase attiva del colpo e nel primo 30%
  del seguito, e solo se la sfera si muove (≥1 m/s: la mano in guardia o l'elsa ferma no). Gli
  urti al suolo (martello, picchiata) restano ad area. Un colpo per bersaglio per attacco (salvo i
  giri), niente colpi attraverso i muri. La posa dell'eroe ora si calcola al passo della fisica:
  la lama che ferisce è quella che si vede anche a pochi FPS. Il pulsante Hitbox mostra le sfere
  (gialle quando feriscono) e le capsule. Senza rig (test) restano le forme astratte di M4.
- **Oggetti a terra:** "Getta" posa l'oggetto davanti all'eroe; si riprende passandoci sopra dopo
  1 s; sparisce dopo 5 minuti (lampeggia negli ultimi 10 s); resta nel salvataggio con la sua età.
- **Magie:** icone disegnate per forma nel colore della scuola (grigie oltre l'Output, lucchetto se
  sconosciute), pulsante Magia con icona e nome della magia scelta (o il motivo del blocco), numero
  dello slot sulla barra, nome al centro dello schermo al cambio, slot tenuto premuto = libro su
  quello slot, nel libro "Metti nello slot 1–5".

## D-029 — Opzioni che si chiudono, armeria, equipaggiamento spiegato
Richiesta del proprietario: le opzioni aperte "non se ne vanno più"; un tavolo con tutte le armi
da prendere e impugnare; non era chiaro come equipaggiare armi, oggetti e armature.
- **Opzioni:** il ⚙ piccolo in alto a sinistra (sotto le scritte di stato, facile da non
  ritrovare) diventa il pulsante "Opzioni"/"Chiudi" nella riga in alto; nel pannello c'è
  "Chiudi ✕"; un tocco sul mondo lo chiude; il tasto indietro di Android e Esc chiudono il
  pannello aperto (zaino, opzioni, editor dell'eroe) invece di uscire dal gioco.
- **Tocchi nella zona dello stick:** un tocco breve e fermo in basso a sinistra ora vale come
  tocco sul mondo (prima diventava uno stick fermo: gli oggetti in quella parte dello schermo non
  si potevano aprire).
- **Armeria:** una rastrelliera vicino allo spawn (fra 3 e 6 blocchi, girata verso lo spawn) con
  spada, lancia, martello, spadone, piccone, ascia, pala e un'armatura intera di ferro; armi e
  attrezzi sono esposti sulla rastrelliera e spariscono quando li prendi. Toccandola si apre la
  scheda "Armeria". Non si raccoglie come un forziere; nei salvataggi di prima viene aggiunta.
- **Tocca, poi scegli:** in zaino, forziere e armeria un tocco seleziona l'oggetto e a destra
  compaiono: come si usa quel tipo di oggetto, il confronto con l'equipaggiamento attuale (verde
  meglio, rosso peggio) e i pulsanti "Impugna", "Indossa", "Prendi", "Metti qui", "In barra",
  "Dividi", "Getta". Spostare fra slot dello zaino resta: tocco su un oggetto, poi su uno slot.
- **Impugna:** l'oggetto va nella barra rapida (primo slot libero, o al posto di quello in mano,
  che torna da dove veniva) e diventa quello in mano. Lo slot in mano è dorato con la scritta
  "in mano" anche nello zaino.
- **Scheda Equipaggiamento:** a sinistra Mano, Testa, Busto, Gambe, Piedi; toccando uno slot, al
  centro compaiono gli oggetti dello zaino che ci vanno col confronto e il pulsante per metterli,
  più "Togli" per il pezzo indossato; a destra le statistiche.

## D-030 — Armatura che copre il corpo, inventario unico con la miniatura
Richiesta del proprietario: quando si indossa l'armatura le facce del corpo coperte non devono
sovrapporsi (capelli/elmo, busto/pettorale...); equipaggiamento e inventario uniti con una
miniatura del personaggio come in Minecraft.
- **Occlusione:** `HeroChargen.cull_inside` toglie dalla mesh dell'eroe i triangoli che stanno
  per intero (tutti e tre i vertici) dentro le scatole dei pezzi indossati, allargate di 2 cm.
  Il primo tentativo col baricentro lasciava un bordo seghettato. L'elmo mette "helm" nel DNA:
  niente capelli sopra, niente cappello, niente orecchie. La cache dell'occlusione tiene conto
  dei pezzi indossati.
- **Inventario unico:** la scheda Equipaggiamento sparisce; nella scheda "Inventario" a sinistra
  c'è la miniatura dell'eroe (SubViewport con un suo mondo e un suo AvatarRig, gira da sola e si
  trascina), attorno i 4 slot dell'armatura e lo slot Mano, sotto le statistiche; a destra lo
  zaino. Un tocco su uno slot dell'eroe mostra i pezzi dello zaino che ci vanno col confronto.
  `open("equip")` apre l'inventario.

## D-031 — Magie come RMNDWN (regole, posa, suono, aspetto)
Richiesta del proprietario: rendere le magie identiche al prototipo RMNDWN. Fonte: analisi di
`RMNDWN_k122.html` con i numeri di riga (specifica nella sessione). Cosa cambia:
- **Karma:** ogni colpo è una testa che viaggia a `speed` per `speed × lifetime` (Zoltraak
  64 m/s, Ago 110), si allarga perdendo coerenza (`r0·(1 + scatter·(1 − coh))`), si ferma sul
  **primo** corpo (non trapassa più), danno e stagger × coerenza; a terra impatto e scoppio, a
  fine portata svanisce **senza** impatto. Ago e Spina sono colpi singoli (la salva copiata era di
  Prisma e Doppio); Dardo con i valori finali di K122 (r .085, fascio 2,40 m, decoerenza 5,2,
  minimo .62). Dopo il contatto il raggio si spegne verso il punto d'arrivo in .30 s.
- **Elementi:** un solo colpo all'istante di contatto della timeline v78 (colonne .57 s, punte
  .30, geyser .27, diluvio .36, ciclone e vuoto .28, sisma .31, ascensione 2,3, frusta .44,
  taglio .04, spinta .45, marea all'arrivo, masso 1,5 s dopo essersi composto davanti alla mano):
  sfera `area` sul punto mirato con danno pieno a tutti, oppure la capsula mano → mira della
  frusta (primo corpo). Palla e meteorite: danno pieno a tutti nell'area (non più colpo + scoppio
  ridotto). Braci e Muraglia (ruolo "difesa") non feriscono mai. L'Ascensione non solleva (solo
  stagger 24); Geyser e Punte non lanciano in aria. I proiettili elementali si fermano sulla mira.
  La raffica di fuoco non si apre a ventaglio (il ventaglio vale solo per i raggi del Karma).
- **Getti:** coni di SUSTAIN_TUNE (fuoco .16 → .70 fino a 6,5 m, idrante .10 → .40 fino a 7,
  pressione .06 → .16 fino a 9), feriscono solo mentre emettono (1,6 / 2,0 / 1,1 s), stagger al
  secondo, spinta come accelerazione (28 e 24 m/s², massimo 3,8 e 4,2 m/s), stati a ogni tick
  (idrante bagna, rallenta e spinge; pressione bagna e spinge).
- **Lancio:** una pressione avvia una raccolta che finisce da sola (niente carica tenuta, il
  rilascio non annulla); la Pressione sale quando la raccolta **parte**; durante tutta la magia si
  cammina al massimo a 1,75 m/s. I dardi del prototipo IsoTerra tengono le loro regole (tenere,
  tocco breve, impegno al 35%).
- **Stati:** acqua e aria con knockback ≥ .6 danno SPINTO; Conduzione (Karma sul bagnato)
  moltiplica lo **stagger** ×1,8 e non consuma il bagnato; Shock termico toglie il fuoco con 4 ×
  pile di danno silenzioso e moltiplicatore 1 (era 1,25); Ventaglio rispetta l'intervallo delle
  pile (.9 s) e accende anche il giocatore entro 3,2 m; via "aria sul bagnato ×1,8" (non esiste).
- **Stagger:** ogni magia ha il suo (tabella di RMNDWN); il manichino lo sente come oscillazione
  (`CombatTarget.stagger`). Il knockback resta ×2,4 perché il manichino ha l'attrito del
  prototipo, ed è orizzontale (via il sollevamento inventato).
- **Hitstop e scossa:** `hitstop dell'attacco × famiglia (.30) × materiale × grammatica × (.35 +
  .65 coerenza)`: 4 ms per un dardo di fuoco (era 17–48 ms). Refrattario di .16 s (sostenuti
  .22 s) in cui un colpo non dà hitstop, scossa né suono. Scossa direzionale sull'orbita lungo
  il colpo (la terra verso il basso) con frequenza per elemento e calcio del campo visivo in
  gradi. Nessuna scossa all'avvio delle aree.
- **Posa:** braccio del tutto teso in avanti (13,5° verso l'esterno, 3,4° in su), sale in .34
  della raccolta, resta finché qualcosa del lancio vive e il glifo si sfalda, poi scende in
  .34 s; spinta della spalla nell'ultimo 22% della raccolta; rinculo quando la magia colpisce,
  con attacco/rilascio/posa per magia; l'altra mano raccolta; a due mani le braccia convergono.
  **Differenza voluta:** RMNDWN lancia con la destra e l'arma nel fodero; qui la posa è
  specchiata sulla **sinistra** perché la destra tiene l'arma (D-024).
- **Suono:** solo l'impatto su un corpo, con le voci di RMNDWN (durate, colpo pesante più grave,
  zap del Karma, rombo della terra, rumore a parte), altezza × `juice.sfx`, volume × famiglia ×
  distanza. Via i suoni di raccolta e rilascio.
- **Aspetto:** via il cerchio ai piedi, le luci puntiformi delle magie (restano quelle delle celle
  in fiamme, che vengono dal prototipo IsoTerra) e i lampi di rilascio. Il glifo davanti al
  palmo è il segno del lancio: figura per elemento (rosa a 5 lobi, anelli gemelli, 3 bracci a
  spirale, esagono a segmenti; rosa a 3 petali per il Karma) con cerchio, tacche e poligono,
  disegnata dal 6% al 72% della raccolta, carica a spirale e massa al centro dopo metà, poi si
  sfalda. Karma: colore funzione della coerenza (tinta 284, nucleo quasi bianco), raggio acceso
  dal glifo alla testa, fascio, sfera; bocca al rilascio; impatto con nucleo, anello, ejecta e
  tagli. Fiamma col colore di corpo nero a isoterme. Firma d'impatto per elemento su ogni colpo
  (braci che salgono, gocce, anello d'aria, zolle; Karma due anelli). Stati con la cadenza di
  RMNDWN (fumo dalla testa, gocce e anello del bagnato, zolle e anello del lento).
- **Non fatto (limiti dichiarati):** mescola MAX (Godot non l'ha negli shader spaziali: la fiamma
  e l'aria restano additive), render target di 424 px con grani agganciati alla griglia, il
  simulatore v78 completo (pennacchi di Heskestad, rottura di Plateau–Rayleigh, reticolo della
  terra), i profili di forza dell'acqua e dell'aria, le magie che nel port non ci sono (guardie,
  Prisma, Serpe, Doppio, Raffica, Sigilli, Corona...). I grani sono più grandi (2,2 cm) perché qui
  la vista è più larga del render target di RMNDWN.

## D-032 — Terra di zolle vere, accumulo nel palmo, colpi continui, barra delle magie per il telefono
Richiesta del proprietario dopo D-031: la terra deve sembrare fatta di costrutti, agglomerati di
terra che si lanciano sul bersaglio; mancano i coni di terra di RMNDWN; colpi continui per acqua e
fuoco; via il glifo, di nuovo l'accumulo della sostanza; un sistema di magia professionale; la barra
delle magie sul telefono era tagliata e non tutti e 5 gli slot si potevano premere.
- **Terra come il reticolo di RMNDWN** (`EarthFx`). Prima prova con cubetti solidi illuminati:
  al proprietario non piaceva, preferisce l'aspetto di RMNDWN, quindi ora è quello (v78 L23058,
  L26480–L26525, L27316–L27329): ogni forma è divisa in celle a passo fisso; i granelli partono dal
  suolo come polvere chiara, volano verso la loro cella a `fly·(1 + .35·distanza)` m/s e si
  bloccano entro `snap` (o tutti a `lockBy`), diventando terra compatta scura (T ≤ .14); il
  costrutto bloccato segue la magia. Allo sgretolamento la cella lascia andare il mattone con
  v = (±1,4, .6–2,0, ±1,4): gravità, attrito 2,4, rimbalzo .12, mucchio fermo e scuro che sparisce
  dopo 4–6 s. Disegno: quad opachi agganciati alla griglia dei pixel e stirati nel moto
  (stretch .14, massimo 3,5, thin .95), colore dalla rampa di sospensione RAMP_EARTH (col suo
  "#95744" letto come rgb(149,116,4), per cui la polvere in volo è ocra).
  - Masso: palla piena bitorzoluta R .28 a passo .062 (~380 granelli) che si compone davanti alla
    mano in .75 s, cresce, gira, vola e si rompe sul bersaglio.
  - **Coni gemelli** (nuova magia, RMNDWN earth_twins: T2, Output 65, R .30, lunghi 1,25, a ±1 m
    ai lati, .85 avanti): due coni pieni a passo .07 che si compongono ai lati del caster in .45 s
    puntando la mira, poi partono insieme a 14 m/s; area .55, 23 di danno ciascuno.
  - Punte: sei coni pieni (R .26, 1,5 m, passo .10) che escono dal suolo in .4 s e a .81 s si
    sgretolano.
  - Sisma: anelli di lastre (passo .22 invece di .19, per il tetto di 3200 granelli) che si
    compongono, si alzano e si inclinano al passaggio dell'onda, poi si sgretolano.
  - Muraglia e colonna restano blocchi veri del mondo; salendo e crollando buttano sabbia.
  - Impatti e firme della terra: sabbia del reticolo invece dei grani generici.
- **Accumulo nel palmo** al posto del glifo: fuoco = fiamma che arriva a spirale e brucia nella
  mano; acqua = gocce che arrivano e una sfera che gira e gocciola; aria = vortice che si stringe e
  alza la polvere; terra = pietra di zolle salite dal suolo davanti ai piedi; Karma = frammenti
  viola e nucleo chiaro. La massa cresce con la raccolta (dimensione dal livello della magia).
- **Colpi continui (fuoco e acqua):** colonne di fuoco (1,9 s), geyser (1,4 s) e diluvio (3,2 s)
  danno il 40% al contatto e poi colpiscono ogni .25 s chi resta nell'area (il 60% spalmato), con
  poca spinta e famiglia "sostenuta" (niente hitstop); i getti colpivano già di continuo. Ogni
  finestra di .22 s un colpo continuo mostra una firma piccola (braci, gocce). La bruciatura manda
  anche lei i suoi colpi. **Differenza voluta da RMNDWN**, che colpisce una volta sola.
- **Numeri del danno** delle magie, nel colore dell'elemento: i colpi pieni subito e grandi, i
  critici dorati, i colpi continui sommati per bersaglio ogni .35 s.
- **Barra delle magie:** non più una colonna sul bordo (su un telefono in orizzontale, ~390 dp di
  altezza, usciva sopra lo schermo), ma una riga di 5 slot sopra i pulsanti d'azione, larga fino
  a 56 dp e ridotta (non sotto 40 dp) finché entra fra lo stick e il bordo e fra la riga in alto e
  i pulsanti. Slot scelto più grande e dorato, bordo nel colore dell'elemento, barra della raccolta
  (azzurra) e del recupero (rossa), sopra la riga il nome con livello e Output (o il motivo del
  blocco) e la barra della Pressione. La barra rapida in basso si restringe per non finire sotto
  il pulsante Magia. Test con la scala dp di quattro schermi (fra cui 2400×1080 a 440 dpi).

## D-033 — Opzioni modali, mira assistita leggera, catene che vanno a segno, forte a terra
Richiesta del proprietario: toccando le opzioni si blocca tutto; rifinire combattimento e movimenti
delle armi, colpi forti e mani nude, con meno mira automatica e colpi che si collegano in modo
fluido; il secondo pugno non colpisce mai; il colpo forte che salta in aria non è realistico.
- **Opzioni:** su un telefono in orizzontale (~390 dp di altezza) il flusso di 25 pulsanti da
  118×48 dp usciva dal bordo in basso e copriva stick, pulsanti d'azione e barra delle magie:
  ogni tocco premeva un'opzione a caso ("Nuovo seme" rigenerava il mondo, "Pausa" fermava tutto,
  "Scava debug" cambiava i comandi). Riprodotto con `tools/e2e_options.gd --phone`. Ora è un
  pannello modale sotto la riga in alto, con la griglia adattata allo schermo (colonne da 84 a 118
  dp, righe da 30 a 48 dp); mentre è aperto il resto dei comandi è spento e il gioco si vede
  velato; un tocco fuori lo chiude; "Nuovo seme" e "Carica" chiedono un secondo tocco entro 3 s.
- **Misure prima di cambiare** (`tools/e2e_moveset.gd`, hitbox vere dell'eroe, un tocco ogni
  .12 s): al primo giro mancavano gancio e montante dei pugni, rovescio e calata della spada,
  entrambi gli affondi della lancia, il montante del martello, la calata dello spadone. Cause:
  l'affondo portava alla portata "astratta" delle armi, più lunga di quella vera delle armi ridotte
  sul nuovo eroe (colpi corti di 5–50 cm); i colpi di catena spingevano il bersaglio fuori portata
  (il primo colpo del martello a 4,6 m); gli affondi e le calate uscivano di lato (la lancia di 43°,
  le calate di mezzo metro a destra), perché l'arma sta nella mano destra.
- **Mira assistita leggera:** il bersaglio si aggancia solo entro 35° dalla direzione voluta (stick
  o sguardo) e a portata d'affondo (+0,6 m); la direzione si corregge di al massimo 20°. Prima: cono
  di 80°, rotazione piena verso il bersaglio e affondo fino a 1,8 m oltre il suo. Un bersaglio a 40°
  resta dov'è: lo si prende puntando lo stick.
- **Distanza vera di contatto:** `WeaponDefinition.strike_dist` (pugni .72, spada 1,15, lancia
  1,25, martello 1,0, spadone 1,25, attrezzi .95) e `AttackDefinition.strike` per i colpi diversi
  (montante .55, affondi della lancia 1,3, fendente dall'alto .9, montante del martello .8, calata
  dello spadone 1,05). L'affondo porta lì e non oltre l'affondo del colpo (×1,25).
- **Catene fluide:** il colpo premuto durante un attacco resta in coda fino al punto di seguito
  (prima scadeva dopo .3 s: un tocco presto su un colpo lento del martello si perdeva). I colpi di
  catena spingono poco (pugni 1,2–2, spada 1,8, lancia 1,6, martello 3,5, spadone 3), così il
  bersaglio resta a portata; spinge forte il colpo finale.
- **Pose che puntano dove colpiscono:** negli affondi della lancia e nelle calate il petto gira
  (40–55°) e porta avanti la spalla destra, come nel diretto dei pugni.
- **Forte della spada:** non più un balzo con il corpo alzato di mezzo metro e le gambe raccolte,
  ma un fendente dall'alto a due mani con un passo avanti, piedi a terra, caricabile. Montante dei
  pugni, montante della spada e del martello: saltelli ridotti a 4–5 cm.
- **Esito misurato:** tutte le catene vanno a segno al primo giro (pugni: jab, diretto, gancio,
  montante), tutti i colpi forti colpiscono, nessuno solleva l'eroe.

## D-034 — Lancio alla Brawl Stars, tutte le magie per la prova, moveset per arma, passo nei colpi
Richiesta del proprietario: continuare a rifinire il combattimento con un moveset proprio per ogni
arma e ritmi diversi, lancia perforante, spadone e martello più lenti, IK delle gambe nei colpi;
lasciare tutte le magie usabili per la prossima prova; lanciare le magie come in Brawl Stars
(pulsante tenuto e direzionato, con una fascia davanti al giocatore che mostra la direzione).
- **Lancio alla Brawl Stars (tolto in D-035, sostituito dal Lock):** il pulsante Magia è un joystick (raggio 72 dp, zona morta 25%).
  Tenendolo premuto compare a terra l'indicatore della magia scelta, del colore della scuola: una
  **fascia** dal giocatore nella direzione del dito per proiettili, raggi e getti (lunga quanto la
  portata, larga almeno 0,7 m); un **cerchio** sul punto scelto per le magie ad area (la distanza
  segue quanto si trascina, da 1,5 m alla portata); un **anello** attorno all'eroe per le magie su
  di sé. Al rilascio la magia parte in quella direzione: si aggancia solo un bersaglio entro 15°
  dalla fascia (prima: il più vicino nel cono di 80°). Un tocco fermo (sotto la zona morta) lancia
  con la mira automatica di prima. Trascinare e annullare il tocco non lancia. L'indicatore segue il
  terreno e si vede sopra l'erba.
  Nota: prima il lancio partiva alla pressione e la raccolta si allungava tenendo premuto; ora la
  pressione serve a mirare e la raccolta parte al rilascio (come in Brawl Stars). Tutte le magie
  del libro si lanciano da sole alla piena raccolta.
- **Tutte le magie per la prova:** `GameRoot.TEST_ALL_SPELLS` rende note tutte le 39 magie e alza
  l'Output a 200 in ogni partita; in una partita nuova la barra parte con una magia per scuola
  (Colonne di fuoco, Diluvio, Coni gemelli, Fendente d'aria, Zoltraak), il resto si mette dal libro.
  Da spegnere dopo la prova.
- **Ritmi per arma** (carica + attivo + rientro del primo colpo): pugni .28 s, lancia .34 s, spada
  .47 s, spadone .82 s, martello .94 s. Spadone e martello: carica e rientro ×1,3 e ×1,35, arresto
  sul colpo ×1,25 (non nei colpi ripetuti del turbine), quasi fermi mentre colpiscono; i giri
  tengono la loro velocità e il turbine ricolpisce dopo .1 s (prima .2: con la carica più lenta il
  secondo passaggio arrivava prima e non contava).
- **Lancia perforante:** nuovo `AttackDefinition.pierce`: la striscia colpita va oltre la punta e
  prende ogni bersaglio in fila, non solo il primo. Stoccate veloci perforanti (.6 m), spazzata
  bassa, e la nuova **infilzata** finale (carica lunga all'indietro, 1,6 m oltre la punta, spinge
  lontano); il forte in carica trapassa per 2,2 m, lo scatto dopo la capriola per 1 m.
- **IK delle gambe nei colpi:** prima nei colpi girava il passo della camminata (lo scatto del colpo
  muoveva il corpo e le gambe facevano passi di corsa). Ora `GaitLegs.hold` ferma il ciclo del
  passo durante il colpo; all'avvio di ogni colpo il piede indicato da `step_foot` (sinistro di
  norma, destro nel diretto, nel rovescio e nella seconda stoccata) fa un passo fino a 12 cm oltre
  il punto d'arrivo dello scatto; l'altro resta piantato negli scatti corti e, negli scatti oltre
  24 cm, segue saltellando un filo dopo; se è davanti all'arrivo torna dietro (cambio di guardia).
  Il bacino scende quanto serve perché la gamba tesa arrivi a terra (affondo). A fine colpo i piedi
  tornano sotto le anche col passo d'assestamento. Giri e picchiate usano il passo normale.
  Misura (`tools/e2e_moveset.gd`, nuova voce): piede del colpo davanti all'altro di 0,20–0,38 m in
  ogni colpo; prima della correzione del piede dietro si arrivava a 1,2 m con gambe da 0,3 m.

## D-035 — Lock sul bersaglio al posto della mira alla Brawl Stars, camminata laterale, acqua leggibile
Richiesta del proprietario: togliere la mira delle magie di D-034; un sistema di aggancio (lock on)
con un triangolo tridimensionale rosso sul bersaglio; con il lock la camminata diventa laterale
(strafe) e i colpi seguono il bersaglio, sia le magie sia le armi sia i pugni; le magie d'acqua si
vedono male.
- **Via la mira alla Brawl Stars (D-034):** il pulsante Magia torna a premi e tieni (raccolta alla
  pressione, lancio al rilascio o da solo al tocco). Tolti indicatore a terra (`AimIndicator`),
  joystick del pulsante, `press_aimed` e le forme di mira delle magie.
- **Lock** (`LockOn`): pulsante *Lock* sopra la Magia, tasto R, rotella del mouse. Aggancia il
  bersaglio migliore entro 14 m (distanza + 3 × angolo in radianti dallo sguardo: davanti vince,
  ma vale anche uno alle spalle); di nuovo Lock sgancia. Cade da solo se il bersaglio si rompe,
  esce dalla scena o va oltre 18 m. Il pulsante resta rosso finché è attivo.
- **Triangolo rosso** (`LockMarker`): piramide a base triangolare con la punta in giù, facce in tre
  rossi diversi e contorno scuro (scafo rovesciato), gira e ondeggia sopra la testa del bersaglio,
  si vede anche dietro alberi e muri, compare con uno scatto di scala.
- **Camminata laterale:** con il lock lo sguardo resta sul bersaglio (rotazione più rapida della
  corsa) e lo stick sposta di lato e all'indietro, al 78% della velocità; le gambe fanno i passi
  laterali col passo procedurale di D-028. Misura (`tools/e2e_lockon.gd`): 1,2 s di stick a destra,
  errore massimo dello sguardo 4°.
- **Colpi che seguono il lock:** armi e pugni partono verso il bersaglio agganciato fino a 12 m,
  a qualunque angolo (senza lock resta la mira assistita di D-033: 35° e correzione ≤ 20°), con lo
  scatto che porta alla distanza vera dell'arma; durante la carica il colpo continua a girarsi sul
  bersaglio che si sposta (non i giri e le picchiate). Le magie partono verso il bersaglio
  agganciato senza cono, e i proiettili senza gravità gli curvano incontro (4 rad/s) se si sposta.
- **Acqua leggibile:** la palette dell'acqua di RMNDWN (da blu notte .025/.09/.14 a .94/.99/1) sul
  prato e sulla terra del gioco si leggeva come sporco scuro. Ora va da un blu medio (.10/.34/.60)
  a un blu acceso (.16/.53/.92), a un celeste (.36/.76/1) e a schiuma bianca; le gocce sono 1,45
  volte più grandi (a 360 righe quelle da 2 cm sparivano). Differenza voluta da RMNDWN.

## D-036 — UI del giocatore e primo percorso di obiettivi

- **Contesto:** richiesta di migliorare professionalmente interfaccia e meccaniche.
  Un concept generato aiuta a definire palette e gerarchia; non rappresenta la build.
- **Decisione:** introdurre HUD, pausa, diario e impostazioni con una palette ardesia,
  salvia e ottone. Icone native vettoriali al posto delle sigle degli oggetti. Layout
  compatto a due colonne per mantenere le aree touch nella simulazione ad alta densità.
  La telemetria resta negli strumenti sviluppatore. Nessuna modifica alla reference.
- **Meccaniche:** obiettivi introduttivi persistenti e non bloccanti, interazione verificata
  per portata e linea libera, buffer e tolleranza del salto, azzeramento degli input nei
  pannelli. Il diario è un campo opzionale nel salvataggio versione 1.
- **Conseguenze:** questa è una base verificata in headless, non una release professionale
  conclusa. Playtest, ispezione visiva mobile, performance e contenuti di progressione
  rimangono necessari. Dettagli e limiti in `docs/PLAYER_EXPERIENCE.md` e `docs/PROGRESS.md`.
- **Integrazione (29/09/2026):** la patch è stata scritta da un altro agente (Codex) sopra D-035
  e integrata su richiesta del proprietario con l'autore originale nel commit. Correzioni fatte
  all'integrazione: l'indicazione dell'oggetto vicino ("F / Apri armeria") stava a metà schermo
  sopra l'eroe e sul telefono copriva il pulsante Lock: ora sta sotto i piedi dell'eroe, si sposta
  finché non copre i comandi touch, e su schermi touch non mostra "F /"; la barra di raccolta va
  in alto al centro. Le prove `e2e_options` e `e2e_armory` fallivano perché il pulsante ⚙ è
  nascosto (la riga aggiunta alla prova delle opzioni girava prima che il gioco fosse pronto):
  ora lo riattivano a mondo pronto. Commenti e test tradotti in italiano come il resto del codice.

## D-037 — Via tutto il sistema di magia; camera in prima persona
Richiesta del proprietario: togliere tutto il sistema di magia e avere il progetto pulito;
implementare una camera in prima persona.
- **Magia tolta del tutto** (D-024…D-035 superate): `src/magic` (MagicSystem, SpellDefinition,
  SpellRuntime), `MagicFx`, `EarthFx`, `MagicAudio` (era l'unico audio: il gioco resta senza
  suoni finché non se ne aggiungono di nuovi), `SpellIcons`; pulsante Magia, barra delle magie,
  Pressione e scheda "Magie" dello zaino; pergamene (oggetti e bottino dei tesori); affissi e
  statistiche Output, dissipazione e Arcano (e il bonus dell'oro); pose di lancio dell'eroe e
  `cast_point`; scossa direzionale e calcio del campo visivo della camera; luci puntiformi e
  vento degli incantesimi negli shader e nei globali del progetto; celle delle strutture magiche
  saltate nel salvataggio; palette dei grani solo magiche (karma, fiamma, vapore); test ed e2e
  della magia. Tasti U e Y liberi.
- **Salvataggi vecchi:** la chiave "magic" si ignora; le pergamene nello zaino spariscono al
  caricamento (oggetti sconosciuti già scartati); gli affissi magici rimasti negli oggetti non
  contano più e non si mostrano.
- **Pulsante Lock** al posto del pulsante Magia (a sinistra di Colpo).
- **Prima persona** (`CameraRig.Mode.FPS`): il pulsante camera (V) fa il giro isometrica → terza
  persona → prima persona. La camera sta negli occhi dell'eroe (0,86 sopra i piedi, 10 cm davanti
  alla faccia), FOV 70°, sguardo col trascinamento (dito o mouse) senza ritardo, in su e in giù
  entro −77°…+72°. La testa dell'eroe si nasconde, braccia, corpo e arma restano visibili; un
  mirino al centro (rosso col Lock). Lo stick cammina dove si guarda e il corpo guarda sempre
  dove guarda la camera; i colpi partono lungo lo sguardo anche camminando di lato
  (`CombatController.aim_view`). Col Lock la vista gira da sola sul petto del bersaglio. Niente
  raggi X in prima persona; cielo, sole ed erba come in terza persona. L'editor dell'eroe passa
  in terza persona e torna in prima alla chiusura. Avvio diretto con `--cam=fps`.

## D-038 — Prima persona: si vedono solo le braccia dritte e la mano con l'oggetto
Richiesta del proprietario: in prima persona nessuna parte del corpo nella visuale, solo la mano
con l'oggetto equipaggiato; poi (stessa sessione) anche le braccia devono vedersi, e dritte.
- **Corpo invisibile alla camera:** in prima persona tutte le mesh dell'eroe (corpo, testa,
  armatura, arma nella mano del rig) passano a "solo ombra" (`AvatarRig.set_first_person`): la
  camera non le vede, l'ombra per terra resta, e il rig continua ad animarsi e a muovere le
  hitbox, quindi i colpi restano quelli veri (D-028). Anche la scia della lama del rig è spenta.
  Riapplicato dopo ogni ricostruzione del rig (cambio d'arma, armatura, ricetta).
- **Braccio della vista** (`FirstPersonView`, figlio della camera): copie delle mesh del braccio
  destro (omero e avambraccio con la manica, in linea: braccio dritto), della mano e di quello
  che impugna (arma, attrezzo, blocco); con i pugni le due braccia coi guanti. Il braccio entra dal
  bordo in basso a destra, la spalla resta fuori dallo schermo. Scala 0,46. Versioni scartate
  nella stessa sessione: solo la mano (avambraccio tagliato al polso) e braccio piegato al gomito.
- **Animazione del braccio**, dallo stato del combattimento: guardia in basso a destra; fendenti
  da un lato all'altro (specchiati per il rovescio) passando davanti al mirino; affondi in avanti;
  colpi dall'alto e urti ad area; montanti; con i pugni il braccio che colpisce (sinistro nel
  diretto e nel gancio); carica che trema; scavo come colpo dall'alto ripetuto; capriola; cambio
  d'arma con la mano che scende fuori vista; oscillazione del passo.

## D-039 — Pugni con la forma della presa, zoom a due dita, armi a voxel più grandi, attrezzi senza combo, via la presa a due mani
Richiesta del proprietario, in ordine:
1. **Prima persona a mani nude:** le braccia hanno la stessa forma di quando si impugna un
   oggetto (stessa posa di riposo) e si muovono col moveset del combattimento dei pugni: il
   braccio che colpisce (destro o sinistro, dalle pose chiave del rig) fa fendente, diretto,
   colpo dall'alto o montante come con un'arma. Tolte le pose dedicate ai pugni.
2. **Zoom a due dita in terza persona e in isometrica:** prima, se il primo dito scendeva nella
   zona dello stick diventava stick (o scavo, se fermo) e il pinch non partiva. Ora, se un
   secondo dito sul mondo scende entro 300 ms dal primo e il primo è quasi fermo, le due dita
   diventano pinch; lo scavo appena iniziato col primo dito si annulla. Uno stick già in uso da
   più di 300 ms resta stick. Lo zoom vale in isometrica e in terza persona.
3. **Armi più grandi e nello stile del mondo:** spada, spadone, lancia, martello e attrezzi
   (piccone, ascia, pala) sono ora disegni a pixel estrusi in cubetti (lato 5,5 cm, colori a
   scacchi appena variati, nessuno smusso), come i blocchi del mondo, al posto delle mesh lisce.
   Scala delle armi nella mano dell'eroe 0,72 → 1,2 (su richiesta successiva: "più grandi in
   tutte le camere"), le hitbox seguono la lunghezza; in prima persona ancora ×1,35.
4. **Ascia e piccone senza moveset:** non sono armi da lotta, ripetono sempre lo stesso colpo
   (come lo scavo, dall'alto in avanti) senza combo: colpo leggero, pesante, in corsa e in aria
   sono tutti lo stesso "chop".
5. **Via la presa a due mani:** tolte l'IK della mano sinistra sull'impugnatura e le proprietà
   `two_handed`/`off_grip` delle armi: le braccia corte non arrivavano all'arma e la mano
   entrava nel corpo. Il braccio sinistro oscilla libero con tutte le armi.

## D-040 — Lancia solo di punta, prima persona più piccola a destra, camera più calma, colpi meno frenetici
Richiesta del proprietario:
- **Lancia perforante, non di taglio:** tolte la spazzata ad arco (`sweep`) e il giro a 360°
  (`twirl`), che erano colpi da spada. Catena leggera: stoccata, stoccata col passo, stoccata alta
  (`rise`, la punta sale e solleva), infilzata. Ramo forte della catena: affondo in avanzata
  (`drive`, passo lungo, trapassa la fila). Tutti i colpi della lancia sono di punta e perforanti
  (test); restano la carica, la stoccata in corsa e la picchiata.
- **Prima persona:** braccio e oggetto più piccoli (scala 0,46 → 0,36, oggetto in mano ×1,35 →
  ×1,1) e spostati a destra (e un filo in basso); con i pugni ogni braccio va verso il suo bordo.
  Il centro dello schermo resta libero.
- **Camera durante i colpi:** scossa dimezzata; in isometrica e in terza persona la camera segue
  l'eroe con un filo di morbidezza (gli affondi non la strattonano più, un teletrasporto oltre 4 m
  salta subito); in terza persona non gira più da sola dietro all'eroe mentre colpisce; in prima
  persona col Lock la vista segue il bersaglio più piano durante i colpi.
- **Ritmo:** carica ×1,25, colpo ×1,1, rientro ×1,3 e il colpo seguente della catena parte non
  prima del 35% del rientro, per tutte le armi. Spadone e martello, già lenti (D-034), prendono metà
  dell'effetto; giri e picchiate restano come sono. Gli attrezzi non cambiano.

## D-041 — Via i riquadri in alto, lancia dritta anche in terza persona, danno solo di punta
Richiesta del proprietario:
- **Riquadri in alto tolti:** il riquadro col titolo, l'ora e l'oggetto in mano e quello del
  Diario non si disegnano più durante il gioco (occupavano schermo). L'oggetto in mano si vede
  nella barra rapida, il Diario resta in Menu > Diario e un obiettivo completato arriva come
  avviso. Restano i pulsanti in alto a destra (Eroe, camera, Zaino, Menu).
- **Lancia dritta in terza persona:** in prima persona gli affondi si leggevano, in terza persona
  sembravano spazzate. Misurato con `tools/spear_probe.gd`: dalla carica al colpo la lancia girava
  da 36° a destra a 47° a sinistra (il petto ruotava da -40° a +55°). Nuove pose di carica, colpo e
  seguito: la lancia resta entro ±9° dall'avanti per tutto il colpo e la punta avanza di ~0,8 m
  lungo l'asta (più il passo dell'affondo). La stoccata alta sale di ~28°, non spazza di lato.
- **Danno solo di punta:** le sfere che feriscono della lancia coprono solo la testa di ferro
  (da 1,2 a 1,62 lungo l'arma), non più l'asta (prima da 0,95). Test: lancia dritta per ogni
  colpo di punta, punta che avanza, sfere tutte sulla testa.

## D-042 — Spadone e martello più pesanti, terza persona fissa come l'isometrica
Richiesta del proprietario:
- **Colpi pesanti** (spadone e martello, sopra il ritmo di D-034/D-040): carica ×1,15, colpo
  ×0,8 (la massa arriva tutta insieme, carica lunga e colpo secco), rientro ×1,05, arresto sul
  colpo ×1,5, spinta ×1,25, lancio in aria ×1,15, scossa della camera ×1,6 (la scossa generale
  resta dimezzata da D-040: le armi pesanti tornano a farsi sentire). Giri e picchiate cambiano
  solo nell'impatto. Test: arresto e spinta ben oltre la spada, colpo breve rispetto alla carica.
- **Terza persona fissa:** tolta la terza persona adattiva (distanza e campo che cambiavano in
  corsa, sotto un soffitto e con l'aggancio; camera che girava da sola alle spalle, pulsante
  Auto; rientro davanti ai muri e alle chiome, cioè lo "zoom dietro al player"). Ora è come
  l'isometrica ma in prospettiva: inclinazione 34° (trascinando 0,15..1,3 rad, mai sotto
  l'orizzonte), distanza 6,5 divisa per lo zoom (due dita, Zoom ±, Z/X), rotazione con Q/E, i
  pulsanti ⟲/⟳ o trascinando. Quello che copre l'eroe si apre con la trasparenza a raggi X già
  usata in isometrica; la camera resta solo sopra il suolo. Nuova prova `tools/e2e_tps.gd`.

## D-043 — Eroe snello e slanciato alto due blocchi
Richiesta del proprietario: personaggio più snello e slanciato, alto due blocchi. Scostamento
voluto dal prototipo (l'eroe chibi di CHARGEN, testa grande, alto ~1,5 m coi capelli).
- **Proporzioni** (mesh generate dagli stessi pezzi del prototipo, cambiano solo le scale in
  `HeroChargen.slots()`): alto 1,99 m coi capelli (testa senza capelli a 1,92); testa 0,30 m
  (scala 0,278, prima 0,54), collo a 1,62, anca a 0,95 (gambe 0,45 + 0,465 + piede), omero 0,34,
  avambraccio 0,30 (mano fino a 0,44), busto largo 0,40 (scala 0,38), braccia e gambe sottili
  (scale di larghezza 0,27 e 0,30). Le armature seguono da sole (stesse scale).
- **Scheletro e movimento:** `AvatarRig` (anca, spalle a ±0,265, petto, collo), `GaitLegs`
  (lunghezze delle gambe dal rig; cadenza più bassa, arco del passo, assestamento, abbassamento
  del bacino e distanze dei piedi nei colpi circa raddoppiati), pose con spostamento del corpo
  (atterraggio, nuoto, capriola, affondo e accosciata) in scala.
- **Collisione e camere:** altezza del corpo 1,4 → 1,9 (passa in un varco di due blocchi), occhi
  0,7 → 1,6 per la portata; prima persona dagli occhi a 1,74; isometrica e terza persona guardano
  a 1,0 m (prima 0,7); punti del corpo dei raggi X fino a 1,85; anteprima dello zaino più alta.
  Prima persona: scala del braccio 0,36 → 0,30, oggetto ×1,32 (stessa misura sullo schermo).
- **Colpi:** con le braccia lunghe le punte delle armi arrivano ~1,35 volte più lontano
  (misurate con `tools/spear_probe.gd`): le distanze a cui l'affondo si ferma (`strike_dist` e
  `strike` dei colpi) sono ×1,35 per tutte le armi tranne i pugni. Il montante del martello
  finiva sopra la testa e mancava il manichino: carica più bassa e colpo che si ferma davanti al
  petto. La prova dei movimenti accetta piedi fino a 1,0 m di distanza nel colpo (prima 0,55 per
  gambe da 0,3 m).

## D-044 — Eroe snello a metà strada: ~1,76 m
Richiesta del proprietario: con D-043 l'eroe era troppo alto, via di mezzo. Stesse proporzioni
snelle, tutte le misure ×0,875 (testa un filo più grande in proporzione): alto ~1,76 m coi
capelli (1,70 senza), fra il chibi del prototipo (~1,5) e i due blocchi di D-043. Anca 0,83,
collo 1,42, testa 0,28 m, omero 0,30, avambraccio 0,26, busto largo 0,37. Di conseguenza:
collisione 1,72 m (passa sempre in un varco di due blocchi), occhi 1,4 (portata) e 1,53 (prima
persona), camere puntate a 0,9 m, punti dei raggi X fino a 1,62, cadenza e passi fra i valori del
chibi e quelli di D-043, distanze degli affondi ×1,2 rispetto al chibi (erano ×1,35), prima
persona scala 0,34 con oggetto ×1,16, anteprima dello zaino riquadrata. Limite dei piedi nella
prova dei movimenti 0,9 m.

## D-045 — Ritorno all'eroe basso, arti un poco più lunghi
Richiesta del proprietario: tornare all'altezza dell'eroe basso di prima (quello del prototipo,
~1,5 m coi capelli, testa grande) e allungare solo leggermente gli arti. D-043 e D-044 sono
annullati per il corpo: tornano scale, collisione (1,4 m), occhi, camere, raggi X, passo, pose,
prima persona, anteprima dello zaino e distanze dei colpi di D-042. Restano di quei giri gli
strumenti e le prove (`tools/spear_probe.gd`, controllo del Lock dopo 1,5 s in `e2e_fps`).
Arti ~+15% a parità d'altezza: omero .21 → .24, avambraccio .19 → .22 (con la mano .28 → .32),
coscia .15 → .175, stinco .15 → .175 (con il piede .185 → .21); l'anca sale da .32 a .37 e il
busto si accorcia (petto più basso di .03) per tenere il collo a .80 e la testa dov'era.

## D-046 — Prova pilota Higgsfield: colpi delle combo dai video di riferimento
Richiesta del proprietario: provare Higgsfield solo per i movimenti delle combo delle armi.
- **Video:** 4 clip da 6 s generati con Seedance 2.0 Mini (3 crediti l'uno; Seedance 2.5 richiede
  il piano Plus): spada combo leggera, spada combo pesante, lancia, martello. Il dominio dei video
  è bloccato dalla rete dell'ambiente: i file li ha caricati il proprietario.
- **Catena di strumenti** (`tools/mocap`, fuori dal gioco, Python + Godot): `extract_pose.py`
  (MediaPipe, 33 punti per fotogramma e foglio con lo scheletro; il modello `.task` non è nel
  repository), `keyframes.py` (gesti separati dai punti lenti del polso destro; carica = inizio
  del tratto veloce, colpo = fine, seguito = punto lento seguente; tempi veri), `fit_poses.gd`
  (angoli del rig cercati sull'eroe vero: direzioni dei segmenti, mani fuori dalla testa grande,
  continuità fra le pose, punta dell'arma sopra terra, busto al massimo 50° in avanti e 15° di
  lato; la mano gira la lama lungo la linea spalla-mano perché il video non vede la lama),
  `render_fit.gd` (tavola di controllo), `emit_gd.py` (scrive `src/combat/mocap_moves.gd`).
- **Cosa entra nel gioco** (solo i colpi che reggono il controllo a occhio e coi numeri): spada,
  rovescio orizzontale dopo il giro della catena leggera (`m_cross`, poi si torna al fendente) e
  fendente saltato come forte dal rovescio (`m_leap`); martello, colpo a terra col sollevamento
  lento come forte dopo il montante (`m_smash`). Busto, braccia e mano libera dal video; gambe
  dalle pose d'appoggio del gioco e dal passo; tempi del video nella scala del gioco.
- **Scartati:** il fendente obliquo e la spazzata della spada (la lama non si può orientare come
  nel video con le braccia corte dell'eroe: 40–72° di scarto), i colpi girati di schiena (destra
  e sinistra si scambiano), la lancia (nessun colpo diverso da quelli che ha già).
- **Video col nostro eroe come riferimento** (immagine dell'eroe generata su Higgsfield, perché il
  caricamento è bloccato dalla rete): il rilevatore di pose umano trova la posa in 67 fotogrammi
  su 145 e sbaglia spalle e gomiti sul corpo a blocchi; il video stesso muove poco. Strada
  abbandonata: i crediti non si spendono più per ricavare movimenti in automatico.
- **Limiti onesti:** la lama non si misura; le braccia corte e la testa grande dell'eroe chibi
  obbligano a correggere le pose umane (fino a ~30–50° sul fendente saltato); il bacino non si
  misura (coordinate centrate lì). Il guadagno vero è nei tempi e nel coinvolgimento del busto e
  della mano libera.

## D-047 — Catene di combo per stile d'arma
Richiesta del proprietario: catene di combo diverse per arma, per avere stili di combattimento
diversi (base per le statistiche alla Elden Ring e poi per i colpi speciali). Regola comune: ogni
colpo della catena leggera ha il suo forte (Leggero-Forte, Leggero-Leggero-Forte… danno mosse
diverse); il forte tenuto resta la carica; corsa e aria come prima.
- **Pugni — rissa** (veloci, tanti colpi): diretto → diretto → gancio → montante → raffica (nuova,
  colpi ripetuti ogni 0,07 s). Forti: spinta col palmo (nuova, allontana), gomitata girata
  (nuova), montante alto che solleva (nuovo), pugno a razzo (dopo montante e raffica).
- **Spada — equilibrio**: fendente → rovescio → calata → giro → rovescio orizzontale (D-046) → di
  nuovo fendente. Forti: montante, affondo perforante, fendente saltato (D-046), affondo.
- **Lancia — distanza**: stoccata → stoccata → stoccata alta → infilzata. Forti: passo indietro
  e stoccata (nuova, `backstep` 0,9 m nella prima parte della carica), affondo in avanzata,
  carica lunga, carica lunga.
- **Martello — distruzione**: spazzata → montante → colpo a terra. Forti: terremoto, colpo a
  terra col sollevamento lento (D-046), secondo colpo a terra più forte con onda larga 3,6 m (nuovo).
- **Spadone — slancio**: spazzata → ritorno → spazzata → ritorno… senza fine; ogni leggero
  concatenato aggiunge +10% di danno fino a +30% (`momentum_step`, `momentum_max`), il forte dalla
  catena lo usa, una catena nuova lo azzera. Forti: fendente dall'alto, tornado, calata finale
  (nuova, 26 di danno base, usa tutto lo slancio).
- Correzione dopo l'e2e: la raffica partiva da troppo lontano e il montante sollevava il manichino
  sopra i pugni. Raffica con più avanzamento (1,0) e busto girato in avanti, braccia un poco più
  alte; il montante solleva meno (launch 7 → 4), così la raffica lo raggiunge ancora.

## D-048 — Via l'inclinazione laterale in curva
Richiesta del proprietario: spostando l'analogico a destra o a sinistra il corpo si inclinava di
lato in modo invertito e troppo marcato. L'inclinazione veniva dalla velocità di rotazione
(`AvatarAnimator`, fino a 20° sul corpo in corsa). Tolta del tutto: in curva il corpo resta
dritto. Restano il leggero ondeggiamento del passo e l'inclinazione in avanti della corsa.

## D-049 — Martello: Leggero-Leggero-Forte come vero colpo pesante caricato
Richiesta del proprietario: nel forte dopo il montante del martello (spazzata → montante → Forte)
martello e corpo finivano troppo in avanti; deve sembrare un colpo pesante caricato. Le pose
venivano dal video (`m_smash`, D-046): busto chinato di 36° già nella carica e di 50° nel colpo.
Sostituito da `smash`, disegnato a mano:
- carica: martello alto dietro la testa (circa 45° sopra l'orizzontale) con entrambe le braccia, busto
  inarcato indietro (+26°),
  corpo sollevato; tenendo premuto Forte si carica (fino a 1 s, danno fino a ×2) come il terremoto;
- colpo: secco a terra poco davanti ai piedi (braccia più basse del colpo a terra leggero), busto
  chinato solo di 20°, spinta in avanti ridotta
  (0,6 → 0,3 m), si resta piantati;
- durata senza carica sotto 1,6 s come gli altri colpi.
Le pose `hammer_smash` restano in `MocapMoves` ma non sono più usate.
Pose controllate con `tools/pose_sheet.gd --weapon=hammer`: la prima versione della carica teneva il
martello appeso dietro la schiena, corretta prima della consegna.

## D-050 — Spada: via il quinto colpo dopo il giro
Richiesta del proprietario: togliere il quinto colpo della spada dopo la spazzata larga (il giro).
Era il rovescio orizzontale preso dal video (`m_cross`, D-046). Tolto del tutto: la catena leggera
della spada torna a quattro colpi (fendente → rovescio → calata → giro), poi si riparte dal
fendente. Il fendente saltato dal video (`m_leap`) resta come forte dopo la calata. Le pose
`sword_cross` restano in `MocapMoves` ma non sono più usate.

## D-051 — Armature di cuoio e di ferro con forma propria (in anteprima)
Richiesta del proprietario: migliorare i personaggi modulari con Higgsfield, partendo da
un'armatura di cuoio basilare. Higgsfield serve solo per le tavole di concept (eroe chibi come
riferimento, 0,25 crediti l'una); i pezzi sono costruiti nel codice a blocchi smussati, agganciati
alle ossa come il corpo. Quattro slot come prima: busto, spalle e braccia sono un unico pezzo.
- `AvatarRig` accetta una forma per slot (`styles`, parallela ai colori): "" metallo di D-030,
  "leather" (`LeatherArmor`, testa "leather_cap" casco unico fino alla mascella o
  "leather_hood" cappuccio a punta), "iron" (`IronArmor`, set da cavaliere: elmo chiuso con
  feritoia, corazza col bordo d'ottone, spallacci tondi, guanti, scarselle, ginocchiere a punta).
- Le decorazioni sottili e i pezzi ruotati non nascondono il corpo (`armor_boxes`); una mesh
  rimasta vuota (il cappuccio copre tutti i capelli) non si costruisce.
- `tools/armor_preview.gd`: l'eroe nel gioco vero con un set, davanti, di lato e dietro.
- Non ancora tra gli oggetti: si integrano quando il proprietario sceglie come (cuoio da
  forzieri/banco, ferro al posto delle forme attuali).

## D-052 — Armi ricostruite nel codice dai modelli Higgsfield
Prima prova: immagini delle armi (stile del set da cavaliere) e modelli 3D con SAM 3 (1 credito
l'uno; Tripo 9, Hunyuan 14, Meshy 30–38); il CDN di Higgsfield e' bloccato dalla rete della
sessione, il proprietario ha scaricato i GLB. Convertiti e messi in gioco funzionavano, ma su
richiesta del proprietario ("evitiamo rogne") niente file esterni: spada, spadone, lancia e
martello sono ricostruiti in `WeaponMeshes` con `MeshKit` (lame a rombo con sgusciatura, guardie
e collari d'ottone, cuoio, legno, testa del martello con fasce d'ottone), prendendo immagini e
modelli come riferimento. Stesse lunghezze e impugnatura delle armi a cubetti: hitbox, scie e
pose invariate. Il materiale dell'oggetto colora solo l'acciaio. Gli attrezzi restano a cubetti.
- Trovato nel frattempo: le spazzate dello spadone passavano davanti al bersaglio a finestra di
  contatto quasi chiusa (il braccio arriva in ritardo sulla posa) e contavano a seconda del ritmo
  dei fotogrammi. Spazzate: carica 0,2 -> 0,28, fase attiva 0,15 -> 0,2, rientro 0,3 -> 0,26.

## D-053 — Onda del martello sincronizzata all'impatto; niente capelli sotto l'elmo
Richiesta del proprietario: l'ultimo colpo della catena del martello e i suoi colpi pesanti
facevano danno e sbalzavano i nemici prima che il martello toccasse terra.
- I colpi a terra (forma RADIAL, non le picchiate) partivano al primo fotogramma della fase
  attiva, mentre la posa arriva in ritardo. Ora l'onda (danno, spinta, arresto, scossa, polvere)
  parte quando la sfera piu' bassa dell'arma e' a meno di 0,32 m dal suolo e almeno 0,35 m davanti
  ai piedi; al piu' tardi a meta' del rientro. "Davanti" serve perche' nella carica alta il
  martello pende dietro la schiena con la testa in basso. Senza hitbox (test) resta come prima.
- Con alcune acconciature le ciocche laterali uscivano dai lati dell'elmo: con un pezzo in testa
  tutti i capelli (e i lacci di code e codini) non si costruiscono.

## D-054 — Partita nuova nell'arena (come il torneo di Cell), armature come oggetti
Richiesta del proprietario: ricominciare da zero in un'arena tipo quella del torneo di Cell di
Dragon Ball, con al centro l'armeria e le armi ben separate, un manichino a forma di personaggio
e i due set d'armatura.
- Blocco nuovo `MARBLE` (id 16, "marmo"): solido, opaco, indistruttibile (non e' in
  `Harvest.INFO`). Niente modifica all'atlante verificato del prototipo: lo shader dei blocchi lo
  disegna con un ramo suo (piastrelle chiare 2x2 con le fughe scure), in entrambe le modalita'.
  Il test del catalogo ora conta 17 blocchi (i 16 del prototipo piu' il marmo).
- `Arena.stamp`: nei mondi da giocare (partita nuova e mondo rigenerato; non nella fixture ne'
  nel generatore, che restano identici al prototipo) cerca entro 40 blocchi dal centro il punto
  piu' asciutto e piano, spiana 31x31 blocchi a terra battuta, posa il ring 19x19 di marmo
  rialzato di un blocco e quattro colonne agli angoli, toglie l'acqua, ricalcola la luce.
  `WorldData.arena` e' il centro; con l'arena si nasce sul ring 5 blocchi a sud del centro.
  Un salvataggio ha l'arena nei blocchi: al caricamento la si ritrova controllando il marmo.
- Armeria al centro: rastrelliera larga 2,1 m, solo le quattro armi esposte, una ogni mezzo
  metro; attrezzi dentro ma non esposti; le armature non stanno piu' nell'armeria.
- Espositori (`armor_stand`) a ovest e a est, girati verso il centro: un manichino di legno
  (rig dell'eroe senza capelli ne' viso) che indossa i pezzi contenuti; prendendone uno sparisce
  dal manichino. Cuoio: casco, cappuccio, giubba, gambali, stivali. Ferro: i quattro pezzi.
- Oggetti: `ItemDefinition.armor_style` e `armor_color`. Il ferro esistente ha la forma da
  cavaliere (D-051); cinque oggetti di cuoio (difesa al 70% del rame), non ancora ottenibili
  altrove. `Equipment.styles()` e `color_of()`; eroe e anteprima dello zaino passano le forme.
- Manichino a forma di personaggio: `TrainingGround.add_dummy(p, humanoid, yaw)` usa un rig
  dell'eroe con un'altra ricetta (pelle scura, cresta nera, casacca viola) al posto della paglia;
  stesso bersaglio (hurtbox, punti vita, ritorno a casa). Uno solo, a nord del centro, girato
  verso lo spawn. Fuori dall'arena restano i tre di paglia.
- Menu > "Nuova partita": due tocchi entro 4 s, cancella il salvataggio e ricarica la scena;
  niente salvataggi automatici durante la ricarica.

