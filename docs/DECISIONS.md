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
