# Matrice di parità — prototipo v0_64 → Godot

Fonte: `reference/isoterra_proto_v0_64_humanoids.html` (SHA-256 `2f2f771f…c76a`).
Righe = righe di quel file (dettagli in `docs/INVENTORY_v064.md`). Il piano originale
citava la v0_66: fino alla riga ~7430 i numeri coincidono, oltre sono sfalsati di ~80 righe.

**Stato prototipo:** `attivo` (raggiunto da `boot()`, dal frame loop o da un input) ·
`dormiente` (definito ma spento o mai chiamato) · `parziale` · `legacy` (gira ma senza effetto).
**Stato Godot:** `—` non iniziato · `dati` solo dati/fixture · `parziale` · `fatto` (criterio
verificato) · `verificato` (verificato anche su dispositivo).

## Funzionalità attive (gate R)

| Sistema | Fonte v0_64 | Prototipo | Destinazione Godot | Milestone | Godot | Verifica / criterio |
|---|---|---|---|---|---|---|
| Mondo e blocchi | 4489–4520 | attivo | `WorldData`, `BlockDefinition`, `BlockCatalog`, `WorldEditService` | M0/M1 | fatto | Test: 16 ID/flag = `ISO_CORE`; layout `(y*Z+z)*X+x`; 432 chunk |
| Generazione (6 biomi, laghi, fiumi, strati, minerali) | 4522–4608 | attivo | `WorldGenerator` (`world/generation`), passate versionate | M2 | fatto | Porting bit a bit (D-014): sha per passata/fase = prototipo su 64×32×64 (grotte), 96×40×80, 192×48×192 semi 1931 e 42; fixture seme 1931 rigenerata identica (`tools/verify_generator.gd`) |
| Luce sole + blocchi (flood-fill) | 4613–4633 | attivo | `LightEngine` (calcolo completo + aggiornamento locale) | M2 | fatto | `compute_all` = fixture per SHA; aggiornamento locale = calcolo completo su 160 edit casuali; ~1,5 ms per un blocco (il prototipo ricalcolava tutto il mondo) |
| Greedy meshing + AO + cutaway | 4638–4709, 6811 | attivo | `ChunkMesher`, `WorldRuntime` (`ArrayMesh` per chunk) | M2 | fatto | Identico al prototipo per hash su tutti i 432 chunk (41.172 quad): vertici, UV, dati, indici. Sezione (`slice`) supportata, nessun comando attivo la usa |
| Vegetazione: alberi (3 archetipi) ed erba | 4893–4957, 6819–6854 | attivo | `Vegetation`, `VegetationRuntime`, `tree`/`grass.gdshader` | M2 | fatto | 498 alberi, 6 template e 402.080 fili identici al prototipo (hash/float64). Tronchi respingono il giocatore; alberi nella copertura dei raggi X. Abbattimento dormiente anche nel prototipo |
| Acqua a livelli, correnti, cascate | 4965–5103, 6799–6808, 6943–6982 | attivo | `FluidSystem`, `FluidMesher`, `FluidRuntime`, `water.gdshader` | M3 | fatto | Simulazione e mesh identiche al prototipo (iniziale e canale + 30 tick); shader `waterFS` completo con impulsi, schiuma, cascate; resa confrontata a pixel al lago (D-019, D-020) |
| Estetica (pixel RT, outline, dipinto, dithering, cielo, ombre, x-ray) | 5112–5665, 6718–6922, 8294–8301 | attivo | `chunk`/`post`/`post_grass`/`tree`/`grass.gdshader`, `DayCycle`, pannello sviluppatore | M2/R | fatto, differenze dichiarate (D-016, D-019, D-025) | Screenshot affiancati al prototipo in iso e TPS; preset di partenza = valori del prototipo (360 righe, contorni, spigoli, dipinto, raggi, ombre, nubi, erba ON, dither OFF). Gate R: niente contorni sui ciuffi d'erba (stencil, verificato), orizzonte e sole veri in TPS (le 6 luci puntiformi della magia sono tolte in D-037). Restano: raggi X a passata singola, contorni sotto l'acqua prima della fusione, raggi non sui pixel d'acqua |
| Camera ISO + TPS (+ prima persona, D-037) | 6718–6922, 7967–7968 | attivo | `CameraRig` | M1–R | fatto | Iso con aggancio ai pixel; Q/E e pulsanti ⟲/⟳ (tenuti) rotazione continua, Z/X e Zoom ± come il prototipo. TPS adattiva (gate R): distanza/inclinazione/campo per esplorazione, corsa, soffitto, aggancio; segue le spalle (Auto ON/OFF); arretra davanti a muri e chiome (rientro rapido, uscita lenta), resta sopra il suolo; erba oltre 46 + 1,2 × distanza non disegnata. 3 test nuovi. D-042 (scostamento voluto dal prototipo): TPS fissa come l'isometrica (niente adattamento, niente Auto, niente rientro davanti ai muri), occlusione coi raggi X, rotazione e zoom dell'utente; `tools/e2e_tps.gd`. D-037 (oltre il prototipo): prima persona negli occhi dell'eroe (FOV 70°), sguardo col trascinamento, mirino, Lock che gira la vista; D-038: corpo invisibile alla camera (resta l'ombra), si vedono solo le braccia dritte e la mano con l'oggetto (`FirstPersonView`); D-039: a mani nude la stessa forma della presa coi colpi dei pugni, oggetto in mano ×1,35, pinch a due dita anche dalla zona dello stick; D-040: braccio più piccolo e a destra, camera che segue morbida negli affondi, scossa dimezzata; `tools/e2e_fps.gd` |
| Movimento (gradini, rampa, salto) | 6929, 6987–7039 | attivo | `PlayerMotor` con query voxel (D-011) | M1/M2 | fatto | 12 test: velocità, rampa, muro, salto, soffitto, galleria, caduta, tronchi |
| Nuoto / guado | 6941–6982 | attivo | `PlayerMotor.step_water`, `AvatarAnimator` | M3/M4 | fatto | Soglie, galleggiamento, correnti, salto fuori dall'acqua, rallentamento nel guado: 4 test + e2e con tocchi. Crawl e braccia alzate nel guado (M4) |
| Avatar CHARGEN + editor eroe | 4246–4481, 6629–6677, 7898–7917 | attivo | `HeroChargen`, `AvatarRig`, `AvatarRecipe`, editor, persistenza | M4/R/M5 | fatto (D-028; prima sostituito da D-022) | Porting di CHARGEN v2 e CHARGEN.rig: stesse forme, opzioni, palette, generatore casuale, capelli originali, occlusione cotta, misure del rig (D-045: altezza e testa del prototipo, arti ~+15%; le versioni snelle D-043/D-044 sono annullate); editor con le scelte del prototipo, eroi 1/2, casuale, copia/incolla; salvato nelle impostazioni; test |
| Locomozione procedurale (GAIT) | 5775, 6221–6357 | attivo | `GaitLegs`, `PlayerAvatar` | M5 | fatto (D-028) | Piedi piantati, IK, cadenza/appoggio per velocità, arco, assestamento, bacino, bob, ondeggio, inclinazione, gambe raccolte; 5 test + `tools/e2e_walk.gd` + `tools/gait_sheet.gd`. D-045: gambe un poco più lunghe (.175 + .175), stessi parametri del passo del prototipo. D-048: niente inclinazione laterale in curva |
| Corpo a corpo: pugni + spada, lancia, martello, spadone | 7107, 7490–7834 | attivo | `CombatController`, `WeaponDefinition`, `AttackDefinition`, `WeaponLibrary` | M4/R | fatto, ridisegnato (D-022) | Stesse cinque armi e stessi principi (hitstop, sweep, un colpo per bersaglio, spada all'avvio, colpo tenuto che ripete, estrazione/rinfodero al cambio, posa rilassata dopo 2,5 s di calma, Hitbox di debug) con movimenti nuovi. Niente colpi attraverso i muri (test). 16 test + e2e. Dal gate M5 (D-028) danno da contatto hitbox (sfere sulla lama o sui pugni) / hurtbox (capsula) come `contactUpdate`/`sweptHit` del prototipo (HTML 7784–7792), solo nella fase attiva; 5 test in più. D-033: mira assistita leggera (35°, correzione ≤ 20°), distanza vera di contatto per arma e per colpo, catene con il colpo in coda e poca spinta, forte della spada a terra; `tools/e2e_moveset.gd`. D-034: ritmi per arma (spadone e martello lenti), lancia perforante (`pierce`, infilzata), passo delle gambe nei colpi (`GaitLegs.hold`, `step_foot`). D-035: Lock sul bersaglio (`LockOn`, `LockMarker`), camminata laterale, colpi che seguono il bersaglio agganciato; `tools/e2e_lockon.gd`. D-039: armi e attrezzi a cubetti come il mondo e più grandi (scala 1,2), ascia e piccone con un solo colpo ripetuto (`chop`), via la presa a due mani (IK della mano sinistra). D-040: lancia solo di punta (via spazzata e giro), ritmo generale più lento, camera più calma nei colpi. D-041: lancia dritta anche in terza persona (pose misurate con `tools/spear_probe.gd`), danno solo sulla punta. D-042: spadone e martello più pesanti (carica lunga, colpo secco, arresto, spinta e scossa forti). D-046: tre colpi da video di riferimento (`MocapMoves`, `tools/mocap`). D-047: catene per stile d'arma, un forte per ogni punto della catena, raffica dei pugni, passo indietro della lancia (`backstep`), onda del martello, slancio dello spadone (`momentum_step`). D-049: forte del martello dopo il montante (`smash`) disegnato a mano e caricabile, al posto di quello dal video. D-050: tolto il rovescio dal video dopo il giro della spada (catena di quattro colpi). D-052: armi ricostruite nel codice dai modelli Higgsfield, spazzate dello spadone con finestra di contatto piu' lunga. D-053: l'onda dei colpi a terra parte quando l'arma tocca il suolo. D-054: manichino a forma di personaggio nell'arena |
| Combo spada L, LL, LLL, LLLL, H, LH, LLH | 7543–7550, 7616–7620 | attivo | catene in `WeaponLibrary` | M4 | sostituito (D-022) | Nuove catene per ogni arma (anche L-forte, L L-forte, dopo capriola, in aria); test su catena e ramo forte |
| Magia: fuoco, acqua, terra, aria | 7977–8322 | attivo | — | M4/R/M5 | **rimossa (D-037)** | Fatta in D-024, ampliata in D-027…D-035; tolta del tutto su richiesta del proprietario (codice, interfaccia, pergamene, statistiche Output/Arcano, luci e vento degli shader, test) |
| Magia ampliata (oltre il prototipo, da RMNDWN K122) | — | nuovo | — | M5 | **rimossa (D-037)** | 39 magie in 5 scuole (D-027…D-035), tolte del tutto in D-037 |
| Reazioni elementali | 8171–8255 | attivo | — | M4/M5 | **rimosse (D-037)** | Legate alla magia, tolte con lei |
| Bastone magico e magia del fuoco (oltre il prototipo) | — | nuovo | `FireMagic`, `FireGas`, `WeaponMeshes._staff`, `AttackDefinition.cast` | M5 | fatto (D-055) | Bastone dalla tavola Higgsfield; dardo di fuoco (catena di tre) e palla di fuoco caricabile con esplosione e bruciatura. D-056: fuoco solo a grani di gas caldo come in RMNDWN (`FireGas`), niente mesh; D-057 colori saturi e grani piu' grandi per il telefono. Gemme come oggetti e altri elementi ancora da fare |
| Costruzione (terra, pietra, sabbia, legno, torcia) | 4885, 7098–7102, 7858–7860 | attivo, gratuita | `SandboxController.place`, `WorldEditService` | M1/R/M5 | fatto, con costo (D-026) | Portata 7,5; rifiuto se sovrapposta al player o a un oggetto; consuma il blocco in mano; cubo del cursore |
| Inventario (contatore) | 7109–7110 | parziale | `Inventory`, `PlayerItems`, `BagPanel` (M5) | R/M5 | superato (D-026, D-030) | Il contatore del prototipo diventa uno zaino da 30 slot con barra rapida; i crateri riempiono lo zaino. D-030: inventario ed equipaggiamento in un'unica scheda con la miniatura dell'eroe e i pezzi indossati che nascondono le facce del corpo coperte |
| Persistenza impostazioni/avatar/camera | 8 chiavi `isoterra.*` | parziale | `Settings` + `SaveService` (M5) | M4/R/M5 | fatto e ampliato | Chiavi del prototipo nelle impostazioni; in più il mondo intero (blocchi, acqua, oggetti, zaino, armatura, alberi, falò) con backup (test di crash e ripresa) |
| UI touch (stick flottante, drag, pinch, pulsanti) | 7835–7870 | attivo | `TouchControls` con ownership delle dita (D-012) | M1/R | fatto | 6 test + e2e con tocchi iniettati. Interruttori grafici e comandi tecnici del prototipo nel pannello ⚙ (ruota, zoom, Hitbox, pausa); pausa anche con P. Mappa dei tasti diversa dove i tasti servivano a funzioni rinviate o nuove (D-025) |

| Manichini d'allenamento | — (nuovo) | — | `TrainingDummy`, `TrainingGround` | M4 | fatto (D-023) | Bersagli finché i nemici sono rinviati |

## Rinviate dal proprietario (fuori dal gate R, D-009)

| Sistema | Fonte v0_64 | Prototipo | Destinazione Godot | Milestone | Godot | Note |
|---|---|---|---|---|---|---|
| Lock-on, strafe, numeri danno, barre HP | 7061–7089, 7442–7469, 7776–7783 | attivo | `TargetingService`, UI, VFX | da decidere | — | Portata 7,5, rilascio 9,5 |
| Vita giocatore | 7188–7207 | attivo (HUD nascosto dal CSS, riga 14) | `Vitals` + HUD visibile | da decidere | — | 100 HP, invul. 0,65 s, morte 2,6 s, rigenerazione 5 HP/s dopo 7 s |
| Nemici: slime, scheletro, goblin | 7183–7431 | attivo | scene per archetipo + componenti comuni | da decidere | — | Fino a 9 nemici (raggi 8/21/34); leash 13; respawn 25 s |

## Funzionalità dormienti o legacy (censite, non contate come giocabili)

| Elemento | Fonte v0_64 | Stato | Decisione |
|---|---|---|---|
| Grotte (e quindi lava nel mondo) | 4593–4596; `caves:false` a 5731 | dormiente | Restano spente per scelta del proprietario (D-026); il generatore le sa già fare (test) |
| Terreno smussato (surface nets, `meshChunkSmooth`) | 4739–4882, 5422–5476 | dormiente (densità ancora calcolata) | Non portare; conservato come riferimento |
| Classi di pendenza | 4788–4796 | dormiente (`fieldNormal` restituisce sempre "su") | Non portare |
| Scavo/raccolta (`breakTarget`, crepe, `killTree`) | 7757–7775, 6747, 7832 | dormiente (unico attrezzo `fist` con `hitsBlocks:false`) | **Attivato in M5** (`Harvest`, `Harvester`, `VegetationRuntime.kill_tree`): stessi tempi, livelli dei minerali aggiunti (D-026) |
| Manichini `Dummy`, predoni `Humanoid`/`ISOCHAR` | 7434–7441 | dormiente (asset da 1,09 MB decodificato e mai usato) | Non portare |
| Compositore vecchio (`#composer`, tasti C/H/O) | 7875–7924 | legacy | Non portare; l'editor valido è CHARGEN |
| `moveAABB`, `reliefAhead`, `CLIMB`, `View.rotate`, `meleeHit`, `CharacterRigV2` | vedi inventario §2 | dormiente | Non portare |

## Stato verifiche M0

- [x] HTML di riferimento integro (dimensione e SHA verificati da test)
- [x] Fixture seme 1931 estratta dal core originale, deterministica su due esecuzioni
- [x] Fixture caricata in Godot con SHA per buffer, istogramma, layout, spawn
- [x] Catalogo blocchi come `Resource`, coincidente col prototipo
- [ ] Parità visiva e di gameplay: da M1 in poi

## Gate R (27/09/2026)

- [x] Tutte le righe attive della tabella sono "fatto" o "sostituito" con decisione del proprietario
  (D-022: animazioni, armi, combo ed eroe nuovi) e con test automatici e prove e2e.
- [x] Dormienti e legacy censiti a parte; le tre righe rinviate dal proprietario (nemici, vita,
  lock-on/numeri del danno: D-009) restano fuori dal gate.
- [x] Nessun miglioramento maschera una funzione mancante: le aggiunte (capriola, manichini,
  catene nuove, lancio con la sinistra) sono dichiarate in D-022–D-024.
- [x] Preset visivo originale: i valori di partenza sono quelli del prototipo.
- [ ] Prova su telefono e misure FPS: **non verificato** (nessun dispositivo in questo ambiente).
- [ ] Renderer Compatibility (senza Vulkan): **non verificato**.

## Stato verifiche M3

- [x] Mesh dell'acqua identica al prototipo (40 tile, 2.463 quad, 34 cascate) e dopo uno scenario dinamico
- [x] Nessun teletrasporto uscendo dall'acqua: salto dal pelo, atterraggio sulla riva (test)
- [x] Resa dell'acqua confrontata a pixel con il prototipo al lago e alle cascate
- [x] Effetti: schizzi, scia/anelli, gocce delle cascate (grani)
- [ ] Profilo su telefono durante la propagazione dell'acqua

## Stato verifiche M2

- [x] Seme 1931 rigenerato dal generatore portato = fixture originale (sha dei blocchi `ce0d3766…`)
- [x] Nessuna fessura tra chunk: mesh greedy identica al prototipo su tutti i chunk
- [x] Riferimenti visivi delle due camere confrontati con il prototipo in Chromium headless
- [x] Edit locale: luce e mesh solo nei chunk toccati, erba solo nelle colonne cambiate
- [ ] Prova su telefono reale e misure FPS

## Stato verifiche M1

- [x] Chunk a facce visibili da snapshot su thread, nessuna faccia doppia ai bordi (test)
- [x] Edit su faccia/spigolo/angolo di chunk: vicini rimeshati (test 8 chunk)
- [x] Risultati obsoleti e cambio di mondo scartati (test)
- [x] Camminare, gradini, muri, soffitti, gallerie sul mondo fixture (test)
- [x] Costruire/scavare in debug; niente blocco dentro il giocatore (test + e2e)
- [x] Multitouch: stick + camera + pulsanti, rilascio in ordine diverso, annullamento, reset (test)
- [ ] Prova su telefono reale
| Nemico con l'IA, parata e scontro nell'arena (oltre il prototipo) | — | nuovo | `Fighter`, `FighterAI`, `FighterBody`, `ArenaDuel`, `DuelHud`, `CombatController` (GUARD, STUN) | M5 | fatto (D-058) | Il nemico ha tutte le azioni del giocatore; parata e parata perfetta; round e K.O. (D-059: niente sconfitta per uscita dal ring). D-060: postura, deviazione, clash delle lame, attacchi pericolosi, IA a turni |
