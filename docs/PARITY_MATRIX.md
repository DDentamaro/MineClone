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
| Estetica (pixel RT, outline, dipinto, dithering, cielo, ombre, x-ray) | 5112–5665, 6718–6922 | attivo | `chunk`/`post`/`tree`/`grass.gdshader`, `DayCycle`, pannello sviluppatore | M2 | parziale | Screenshot affiancati al prototipo (Chromium headless) in iso e TPS: stesse forme, palette e posizioni. Differenze note: acqua provvisoria (M3), contorni anche sui ciuffi d'erba, raggi X a passata singola (D-016), orizzonte TPS fisso |
| Camera ISO + TPS | 6718–6922 | attivo | `CameraRig` | M1–M3 | parziale | Iso con aggancio ai pixel; Q/E rotazione continua e Z/X zoom come il prototipo; TPS senza il contesto adattivo |
| Movimento (gradini, rampa, salto) | 6929, 6987–7039 | attivo | `PlayerMotor` con query voxel (D-011) | M1/M2 | fatto | 12 test: velocità, rampa, muro, salto, soffitto, galleria, caduta, tronchi |
| Nuoto / guado | 6941–6982 | attivo | `PlayerMotor.step_water`, `AvatarAnimator` | M3/M4 | fatto | Soglie, galleggiamento, correnti, salto fuori dall'acqua, rallentamento nel guado: 4 test + e2e con tocchi. Crawl e braccia alzate nel guado (M4) |
| Avatar CHARGEN + editor eroe | 4246–4481, 6629–6677, 7898–7917 | attivo | `AvatarRig`, `AvatarRecipe`, editor, persistenza | M4 | sostituito (D-022) | Eroe nuovo a 15 ossa; editor (pelle, capelli, acconciatura, veste, brache, corporatura, casuale) salvato nelle impostazioni; test ricetta/altezza/IK |
| Corpo a corpo: pugni + spada, lancia, martello, spadone | 7107, 7490–7834 | attivo | `CombatController`, `WeaponDefinition`, `AttackDefinition`, `WeaponLibrary` | M4 | fatto, ridisegnato (D-022) | Stesse cinque armi e stessi principi (hitstop, sweep, un colpo per bersaglio, spada all'avvio) con movimenti nuovi: 15 test + e2e con tocchi sui manichini |
| Combo spada L, LL, LLL, LLLL, H, LH, LLH | 7543–7550, 7616–7620 | attivo | catene in `WeaponLibrary` | M4 | sostituito (D-022) | Nuove catene per ogni arma (anche L-forte, L L-forte, dopo capriola, in aria); test su catena e ramo forte |
| Magia: fuoco, acqua, terra, aria | 7977–8322 | attivo | `SpellDefinition`, `MagicSystem`, `MagicFx`, `FloatingText` | M4 | fatto, senza audio né luci (D-024) | Numeri del prototipo; lancio con la sinistra; 10 test + e2e con tocchi |
| Reazioni elementali | 8171–8255 | attivo | `MagicSystem.status_react` + fuoco/bagnato/cratere/vento | M4 | fatto (D-024) | Vapore, shock termico, spinta ×1,8, erba bruciata → terra, spegnimento, cratere, rimbalzo: test |
| Costruzione (terra, pietra, sabbia, legno, torcia) | 4885, 7098–7102, 7858–7860 | attivo, gratuita | `WorldEditService`, `GameRoot.apply_action` | M1 (edit debug) / M5 (costo) | fatto (gratuita) | Portata 7,5; rifiuto se sovrapposta al player |
| Inventario (contatore) | 7109–7110 | parziale | `InventoryService` a slot | M5 | — | Si riempie solo dai crateri; nascosto |
| Persistenza impostazioni/avatar/camera | 8 chiavi `isoterra.*` | parziale | `SaveService` / impostazioni | M4/M5 | — | Nessun salvataggio del mondo |
| UI touch (stick flottante, drag, pinch, pulsanti) | 7835–7870 | attivo | `TouchControls` con ownership delle dita (D-012) | M1/M2 | fatto | 6 test + prova e2e con tocchi iniettati. Interruttori grafici del prototipo nel pannello sviluppatore (⚙) |

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
| Grotte (e quindi lava nel mondo) | 4593–4596; `caves:false` a 5731 | dormiente | Riattivare in M5 con collisioni volumetriche; la reazione acqua→lava diventa raggiungibile solo allora |
| Terreno smussato (surface nets, `meshChunkSmooth`) | 4739–4882, 5422–5476 | dormiente (densità ancora calcolata) | Non portare; conservato come riferimento |
| Classi di pendenza | 4788–4796 | dormiente (`fieldNormal` restituisce sempre "su") | Non portare |
| Scavo/raccolta (`breakTarget`, crepe, `killTree`) | 7757–7775, 6747, 7832 | dormiente (unico attrezzo `fist` con `hitsBlocks:false`) | Implementare attrezzi in M5; in M1 solo edit di debug |
| Manichini `Dummy`, predoni `Humanoid`/`ISOCHAR` | 7434–7441 | dormiente (asset da 1,09 MB decodificato e mai usato) | Non portare |
| Compositore vecchio (`#composer`, tasti C/H/O) | 7875–7924 | legacy | Non portare; l'editor valido è CHARGEN |
| `moveAABB`, `reliefAhead`, `CLIMB`, `View.rotate`, `meleeHit`, `CharacterRigV2` | vedi inventario §2 | dormiente | Non portare |

## Stato verifiche M0

- [x] HTML di riferimento integro (dimensione e SHA verificati da test)
- [x] Fixture seme 1931 estratta dal core originale, deterministica su due esecuzioni
- [x] Fixture caricata in Godot con SHA per buffer, istogramma, layout, spawn
- [x] Catalogo blocchi come `Resource`, coincidente col prototipo
- [ ] Parità visiva e di gameplay: da M1 in poi

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
