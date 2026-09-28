# Avanzamento

## Stato corrente: M5 — Sandbox persistente, equipaggiamento RPG, magia ampliata (come RMNDWN), eroe del prototipo · completata (senza prova su telefono)

Sessione del 28/09/2026 (seguito). Richieste del proprietario dopo la prova: oggetti gettati che
si possano riprendere (5 minuti), selezione delle magie più chiara, hitbox/hurtbox legate alle
armi e ai pugni, ritorno all'eroe del prototipo (più piccolo) con un passo migliore tenendo le
animazioni di combattimento (D-028).

Seguito del 28/09/2026: armatura che copre il corpo e inventario unico (D-030), magie allineate a
RMNDWN nelle regole, nella posa, nel suono e nell'aspetto (D-031).

### Fatto (D-030, D-031)
- **Armatura:** le facce del corpo dentro i pezzi indossati spariscono; l'elmo nasconde capelli,
  cappello e orecchie.
- **Inventario unico** con la miniatura dell'eroe che gira, slot dell'armatura e della mano
  attorno, statistiche sotto; niente più scheda Equipaggiamento.
- **Magie come RMNDWN:** teste Karma che viaggiano e si fermano sul primo corpo, colpo unico
  degli elementi al contatto, getti coi coni di RMNDWN, pressione a inizio raccolta, raccolta
  che finisce da sola, hitstop di pochi ms con refrattario, scossa direzionale e calcio del FOV,
  stati e stagger come RMNDWN, posa a braccio teso con rinculo (specchiata a sinistra), solo
  suoni d'impatto, glifo al palmo, Karma col colore della coerenza, fiamma di corpo nero, firme
  d'impatto. Limiti in D-031.

### Test realmente eseguiti (D-030, D-031)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 200/200 PASS, log pulito (nuovi: teste Karma sul primo corpo, svanire a fine portata, roster Karma, colpo unico del diluvio, danno pieno della palla nell'area, braci senza danno, frusta alla mira, hitstop e refrattario, ascensione che non solleva, acqua/aria che spingono; aggiornati muraglia, colonna, conduzione, ventaglio, shock termico, voci) |
| `tools/e2e_magic.gd` | OK: 19 magie lanciate col pulsante, 51 colpi, eventi di contatto/impatto/salita, nessun errore di script |
| `tools/e2e_combat.gd`, `e2e_touch`, `e2e_sandbox`, `e2e_walk`, `e2e_drop`, `e2e_armory`, `e2e_swim` | OK, nessun errore di script (dardi del prototipo: 16 colpi) |
| `tools/pose_sheet.gd --moves --cast` | Posa di lancio vista di lato e dall'alto: braccio sinistro teso in avanti, due mani, rinculo |
| Export Android debug 0.10.0-m5 (versionCode 12) + `apksigner verify` + `aapt2 dump badging` | OK; minSdk 24, targetSdk 36; mai installato su un telefono |

Non verificato: FPS su telefono; nella vista iso con l'eroe di spalle il glifo è coperto dal
corpo (si vede nelle viste di lato); confronto affiancato con RMNDWN aperto nel browser non fatto.

### Fatto (D-029)
- **Opzioni** con "Chiudi", chiusura toccando il mondo, tasto indietro/Esc; tocchi brevi nella
  zona dello stick validi sul mondo.
- **Armeria** vicino allo spawn con tutte le armi, gli attrezzi e un'armatura di ferro, esposti
  sulla rastrelliera.
- **Equipaggiare spiegato:** tocca e scegli (Impugna, Indossa, Prendi...), confronto delle
  statistiche, suggerimento d'uso per tipo, scheda Equipaggiamento con Mano + 4 pezzi.

### Test realmente eseguiti (D-029)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 191/191 PASS, log pulito (nuovi: impugna da forziere/indossa/scambio a barra piena, confronto delle statistiche; avvio: armeria piena vicino allo spawn con 7 oggetti esposti) |
| `tools/e2e_armory.gd` (tocchi reali) | OK: opzioni chiuse con "Chiudi", col tocco sul mondo e col tasto indietro; rastrelliera toccata sullo schermo → Armeria; martello impugnato, busto indossato, stivali presi e indossati dalla scheda Equipaggiamento (l'eroe è spostato accanto alla rastrelliera, non camminando) |
| Tutte le altre prove e2e | OK |

### Fatto (D-028)
- **Oggetti a terra** (`GroundItems`): "Getta" posa l'oggetto, si riprende passandoci sopra,
  sparisce dopo 5 minuti, resta nel salvataggio.
- **Magie più chiare** (`SpellIcons`): icone per forma, pulsante Magia con la magia scelta e il
  suo nome, numeri degli slot, nome al cambio, slot tenuto = libro, "Metti nello slot 1–5".
- **Eroe del prototipo** (`HeroChargen`): porting di CHARGEN con le misure del rig del prototipo
  e l'editor con le sue scelte; occlusione su un thread.
- **Passo procedurale** (`GaitLegs`): piedi piantati e IK come il CharacterRig del prototipo.
- **Hitbox sulle armi:** sfere lungo la lama o sui pugni contro la capsula del bersaglio, solo
  nella fase attiva; posa dell'eroe al passo della fisica.

### Test realmente eseguiti (D-028)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 189/189 PASS, log pulito (15 test nuovi: oggetti a terra 4, passo 5, hitbox 5, generatore dell'eroe 1; ricetta e altezza aggiornati) |
| `tools/e2e_drop.gd` (tocchi reali nello zaino) | OK: spada gettata, a terra davanti all'eroe, ripresa passandoci sopra (l'eroe è spostato sul punto: lo stick non fa parte di questa prova) |
| `tools/e2e_magic.gd` | OK: slot vuoto → libro sullo slot 5, "Metti nello slot 5", slot tenuto premuto → libro sullo slot 2, 14 magie lanciate, 61 colpi |
| `tools/e2e_walk.gd` (stick vero) | OK: 21 m di corsa, 25–32 passi, piede d'appoggio fermo (0 mm), arresto con piedi piantati, salto, colpo |
| `tools/e2e_combat.gd` | OK con le hitbox vere: catena di spada 5 colpi (combo 5), martello caricato 8, magia 16; screenshot all'istante del contatto |
| `tools/e2e_sandbox.gd`, `e2e_touch.gd`, `e2e_swim.gd` | OK |
| Prototipo aperto in Chromium (Playwright, SwiftShader) | eroe "v0.39-chargen" confrontato a occhio con il nostro alla stessa ricetta; lo zoom del prototipo non si è potuto avvicinare dallo script |


Sessione del 28/09/2026. Richiesta del proprietario: M5 senza grotte, con aspetti da gioco di
ruolo: equipaggiamento e magia ampliata dal file del proprietario (`RMNDWN_k122.html`, D-027).

### Magia ampliata (D-027)
- **Output e Pressione** al posto del mana (`MagicSystem`): tetto per lancio, pressione che
  satura, bonus d'alternanza, impegno al 78% e coda; arco della Pressione sul pulsante Magia.
- **Libro di 38 magie** (`SpellDefinition`, numeri di RMNDWN) e **forme** (`SpellRuntime`):
  raggi con coerenza, getti sostenuti, aree, onda, colpi d'aria ravvicinati, muro e colonna
  di terra fatti di voxel che crollano, salve, sfere che scoppiano, meteorite.
- **Reazioni:** Ventaglio, Conduzione, fango (più quelle del gate R).
- **Effetti** (`MagicFx`): cerchio ai piedi, raggi, getti, colonne, pioggia, ciclone, vuoto,
  anelli, archi, segni di materia (bruciature, pozze, crateri); palette Karma; voce Karma
  nell'audio; scossa per elemento; posa a due mani dai 120 di Output.
- **RPG:** pergamene nei tesori, Output che cresce con lo studio e con l'equipaggiamento;
  scheda "Magie" nello zaino; barra di 5 magie; libro e barra nel salvataggio.

### Fatto
- **Oggetti e zaino** (`ItemLibrary`, `ItemStack`, `Inventory`, `PlayerItems`): blocchi,
  materiali, 15 attrezzi, 20 armi, 12 armature, 4 stazioni; zaino da 30 slot con barra rapida da
  6; pile, spostamenti e scambi senza duplicazioni ne' perdite (test).
- **Oggetto in mano:** tocco = posa (blocco o stazione) o colpo; tenere premuto = scava o
  abbatte; l'arma o l'attrezzo in mano decide i colpi e la mesh in mano (con estrazione).
- **Raccolta** (`Harvest`, `Harvester`): tempi del prototipo, livelli dei minerali, usura degli
  attrezzi, abbattimento degli alberi (`kill_tree`), schegge, contorno del bersaglio con
  l'avanzamento; niente rottura se il bottino non entra.
- **Craft** (`Recipes`): a mano, al banco da lavoro, alla fornace (lingotti); tutto o niente.
- **Oggetti piazzati** (`WorldObjects`): banco, fornace, forziere, falò (punto di ritorno e
  salvataggio) e dieci forzieri del tesoro per mondo, deterministici; solidi per il giocatore.
- **Equipaggiamento** (`Equipment`, `Loot`): quattro pezzi d'armatura visibili sull'eroe nel
  colore del materiale; rarità e affissi; statistiche applicate a colpi (danno, critico),
  magia (mana, rigenerazione, danno), scavo e movimento. Scritte "CRITICO!".
- **Salvataggio** (`SaveService`): scrittura verificata con .tmp e .bak, ripiego sul backup;
  salvataggio automatico, al falò, alla chiusura e in pausa dell'app; "Salva"/"Carica" nel ⚙.
- **Interfaccia** (`BagPanel`): Zaino, Equipaggiamento, Craft (le ricette possibili in cima),
  Forziere/Tesoro con "Prendi tutto"; tocchi e trascinamento come i controlli.

### Test realmente eseguiti (M5)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 157/157 PASS, log pulito (19 test nuovi: oggetti, zaino, ricette, raccolta, oggetti piazzati, tesori, salvataggio, abbattimento) |
| `tools/e2e_sandbox.gd` (tocchi reali) | OK: 3 alberi abbattuti a mano (12 legno) → banco creato dal pannello → posato dalla barra → bastoni e piccone di legno al banco → scavo → salvataggio → scena chiusa e riaperta con banco, piccone e bottino |
| `tools/e2e_combat.gd`, `tools/e2e_touch.gd`, `tools/e2e_swim.gd` | OK (aggiornati alla barra rapida: la pietra si sceglie col suo slot) |

| `tools/run_tests.sh` (magia ampliata) | 174/174 PASS, log pulito (18 test nuovi: pressione, alternanza, Output, impegno e coda, coerenza, raffica, orbe, getto a 60 e 20 fps, vuoto, ascensione, muro, colonna, Ventaglio, Conduzione, fango/flusso, libro salvato, pergamena, strutture fuori dal salvataggio; tolto quello sul mana) |
| `tools/e2e_magic.gd` (tocchi reali, xvfb, ~11 FPS in software) | OK: slot vuoto → libro; Giudizio scelto e messo nello slot 5 col tocco; 14 magie del libro lanciate col pulsante (raggio, getto, colonne, marea, muraglia, ciclone, meteorite, diluvio, sisma, orbe, tridente, raffica, zoltraak, ascensione); 58 colpi sui manichini nell'ultima esecuzione; la muraglia sorge davanti al giocatore, non sui manichini; eventi raggio/area/onda/struttura/anelli/segni presenti |
| `tools/e2e_combat.gd`, `e2e_sandbox.gd`, `e2e_touch.gd`, `e2e_swim.gd` dopo la magia ampliata | OK (la prova del combattimento azzera la Pressione invece del mana) |
| Export Android debug 0.7.0-m5 (versionCode 9) + `apksigner verify` + `aapt2 dump badging` | OK; minSdk 24, targetSdk 36; mai installato su un telefono |

### Limiti aperti dopo M5
- Hitbox: tarate sui manichini; senza nemici veri non c'è ancora prova di bilanciamento.
- L'occlusione dell'eroe costa ~0,5–0,9 s su desktop (su un thread): mai misurata su telefono.
- Nessuna prova su telefono né misura di FPS.
- La difesa dell'armatura non ha ancora effetto (nemici rinviati, D-009).
- Un solo salvataggio; "Nuovo seme" sostituisce il mondo al salvataggio successivo.
- Le magie non hanno ancora nemici veri su cui misurarsi (D-009): numeri di RMNDWN non ribilanciati.
- Gli effetti della magia sono grani (niente mesh dedicate per onde, colonne, muri d'acqua).

### Punto di ripresa
M6 (mobile action: stamina, HUD finale, comfort).

## Gate R — parità · chiuso (senza prova su telefono)

Sessione del 27/09/2026. Confronto riga per riga della matrice di parità con il sorgente v0_64:
recuperate le funzioni attive che mancavano o erano parziali (D-025). Restano fuori, per scelta
del proprietario, nemici, vita del giocatore e aggancio (D-009).

### Recuperato
- **Colpi e muri:** nessun colpo corpo a corpo attraverso i blocchi opachi (raggio dal petto, o dal
  punto d'urto, al bersaglio). Test su spada, lancia e martello.
- **Terza persona adattiva** (`CameraRig._frame_tps`): esplorazione/corsa/soffitto/aggancio,
  segue le spalle con "Auto" (pulsante visibile solo in terza persona), arretra davanti a muri e
  chiome, sta sopra il suolo, orizzonte e sole proiettati dalla camera, erba lontana non disegnata.
- **Preferenze del prototipo** salvate: righe, spigoli, terza persona, Auto, inclinazione, zoom.
  I test e le prove e2e usano file di impostazioni propri.
- **Magia:** 6 luci puntiformi (sfera, dardi, lampi, fuoco a terra) nella luce comune; vento della
  spina sull'erba; alberi scossi; audio sintetizzato (`MagicAudio`: impatti, rilascio, raccolta).
- **Resa:** niente contorni sui ciuffi d'erba (stencil + `post_grass.gdshader`), verificato con
  una resa di controllo che colora i pixel dell'erba.
- **Azione:** estrazione/rinfodero al cambio d'arma, posa rilassata dopo 2,5 s di calma, colpo
  tenuto che continua la catena, Hitbox di debug, pausa (P o ⚙).
- **Costruzione e interfaccia:** cubo del cursore, clic destro per l'azione opposta, ⟲/⟳ e zoom
  nel pannello ⚙, eroi predefiniti 1/2 e copia/incolla della ricetta, contatore dei crateri.

### Test realmente eseguiti (gate R)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 138/138 PASS, log pulito (6 test nuovi: muri, TPS adattiva ×2, pausa e preferenze, ricette, voci) |
| `tools/e2e_combat.gd` | OK (spada 8 colpi, martello caricato, capriola, editor, quattro magie con le reazioni); Hitbox negli screenshot |
| `tools/e2e_touch.gd`, `tools/e2e_swim.gd` | OK |
| Screenshot in terza persona e iso | orizzonte e cielo corretti in TPS; stencil dell'erba verificato |

### Limiti aperti dopo il gate R
- Nessuna prova su telefono né misura di FPS; renderer Compatibility non provato.
- Differenze dichiarate: D-016, D-019, D-022, D-024, mappa dei tasti (D-025).
- Audio solo per la magia, come il prototipo (i colpi non avevano suoni neanche là).

### Punto di ripresa: M5 — Sandbox persistente
Attrezzi e scavo vero, raccolta, inventario a slot, craft, costo dei blocchi, contenitori,
checkpoint e salvataggio del mondo, grotte (con la lava e la reazione acqua → pietra scura).

## M4 — Action · completata (senza prova su telefono)

Sessione del 27/09/2026. Richiesta del proprietario: animazioni e mesh delle armi da zero, senza
prendere esempio da IsoTerra, e un combattimento più dinamico (D-022). Nemici rinviati (D-009):
i colpi si provano sui manichini d'allenamento (D-023). Magia con le regole del prototipo (D-024).

### Fatto
- **Eroe** (`AvatarRig`): 15 ossa rigide con scatole smussate generate in codice, luce a bande
  come i blocchi (`actor.gdshader`); editor ("Eroe": pelle, capelli, acconciatura, veste,
  brache, corporatura, casuale) con ricetta salvata nelle impostazioni.
- **Animazione procedurale** (`AvatarAnimator`): guardia per arma, corsa legata alla distanza,
  salto e atterraggio, guado, nuoto a crawl, capriola; colpi tra pose chiave con i tempi del
  combattimento; molle per osso; IK della mano sinistra sulle armi a due mani.
- **Armi** (`WeaponMeshes`, `WeaponLibrary`): pugni, spada, lancia, martello, spadone, ognuna con
  la sua catena, rami forti, carica, attacco dopo la capriola e picchiata dall'aria.
- **Combattimento** (`CombatController`): buffer 0,3 s, aggancio morbido con scatto, capriola con
  invulnerabilità e annullamento del rientro, hitstop, scossa della camera, scia della lama
  (`WeaponTrail`), scintille/polvere/paglia con i grani (`CombatFx`).
- **Manichini** (`TrainingDummy`, `TrainingGround`): volano, oscillano, si rompono e ricompaiono.
- **Controlli**: Colpo, Forte (tenuto = carica), Schiva, Arma, Eroe; tocco sul mondo = colpo in
  esplorazione; tastiera J, K, L/Maiusc, R, H, M.
- **Magia** (`MagicSystem`, `SpellDefinition`, `MagicFx`, `FloatingText`): quattro dardi con i
  numeri del prototipo, mana, raccolta/impegno/rilascio, stati e reazioni, fuoco che si propaga
  sull'erba e la brucia in terra, bagnato che spegne, crateri, rimbalzo del masso, vento che
  soffia le braci; lancio con la mano sinistra e l'arma in pugno (D-024). Pulsanti "Magia"
  (tenuto) ed elemento; tastiera U e Y.
- **Strumenti**: `tools/pose_sheet.gd` (tavole delle pose per arma e dei movimenti),
  `tools/e2e_combat.gd` (tocchi reali: catena, carica, capriola, editor, quattro magie).

### Test realmente eseguiti (M4)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 132/132 PASS, log pulito (30 test nuovi: combattimento, manichini, eroe, magia) |
| `tools/e2e_combat.gd` (tocchi reali, xvfb) | OK: catena di spada 8 colpi a segno (combo 3), cambio arma al martello, carica tenuta e terremoto (colpi su tutti i manichini), capriola, editor dell'eroe; magia con i pulsanti: acqua → BAGNATO, fuoco sul bagnato → VAPORE, BRUCIA, masso → LENTO e CRATERE, aria → SPINTO (15 colpi) |
| `tools/e2e_touch.gd`, `tools/e2e_swim.gd` | OK |
| `tools/pose_sheet.gd` | tavole controllate a occhio; corrette le pose con la lama nel suolo e la capriola |

### Limiti aperti dopo M4
- FPS non misurati: nel container si rende con llvmpipe (7–8 FPS anche senza combattimento);
  nessuna prova su telefono. Le molle dell'animazione vanno a sottopassi da 1/60 s.
- Le pose sono controllate su tavole statiche e screenshot, non ancora in un video.
- Magia senza audio, luci puntiformi, vento sull'erba e scossa degli alberi (D-024).
- Il cambio da IK della mano sinistra alla posa di lancio è istantaneo (piccolo scatto del braccio).

### Punto di ripresa: gate R, poi M5
1. Gate R: riepilogo della matrice di parità con il proprietario (differenze volute: D-022–D-024).
2. M5: inventario a slot (i blocchi dei crateri sono già contati), attrezzi di scavo, costi di
   costruzione, salvataggio del mondo, grotte.

## M3 — Acqua e locomozione · completata (senza prova su telefono)

Sessione del 27/09/2026. Richiesta del proprietario: acqua il più possibile simile alla reference.

### Fatto
- **Mesh dell'acqua** (`FluidMesher`, porting di `meshFluid`): identica al prototipo per hash su
  tutte le tile, anche dopo uno scavo con 30 tick di simulazione; finestra 18×48×18 per i thread.
- **Acqua in gioco** (`FluidRuntime`): tick 0,25 s, tile sporche ricostruite su thread ogni
  ≥100 ms, impulsi dello shader, piedi delle cascate. Gli edit risvegliano l'acqua come `applyEdit`.
- **Shader** `water.gdshader`: porting completo di `waterFS` (correnti trasportate, riflesso,
  schiuma a riva, nastri e impatto delle cascate, anelli d'impulso, fresnel).
- **Fedeltà alla reference** (D-019, D-020): scena in valori di schermo con `use_hdr_2d`, acqua
  fusa in spazio schermo dopo il post, ombra dell'acqua come nel prototipo. Confronto a pixel al
  lago: acqua entro pochi valori su 255, terreno entro 0–3.
- **Nuoto e guado** (`PlayerMotor.step_water`), eventi d'ingresso.
- **Grani ed effetti d'acqua**: schizzi, scia, anelli, gocce delle cascate.
- **Comandi**: "Al lago" nel pannello ⚙; Q/E rotazione continua, Z/X zoom.

### Test realmente eseguiti (M3)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 102/102 PASS, log pulito |
| `tools/e2e_swim.gd` (tocchi reali) | "Al lago", stick verso l'acqua → nuoto, 18 grani, anelli |
| `tools/e2e_touch.gd` | stick, costruzione, raggi X: OK dopo il cambio di pipeline |
| `tools/bench_fluid.gd` (1 thread) | mesh 144 tile 2,5 s (peggiore 84 ms, su thread); tick in moto ≤13,5 ms; finestra 2,4 ms |
| Confronti prototipo/Godot (ora 0,35) | lago, cascate, terza persona |

### Limiti aperti dopo M3
- Nessuna prova su telefono; il primo tick dopo il caricamento smaltisce tutta la coda (~50 ms una volta).
- Differenze residue: contorni sotto l'acqua applicati prima della fusione; niente raggi del sole
  sull'acqua; bordo retinato dei raggi X; posizione della mano stimata per le bracciate.
- `use_hdr_2d` con il renderer Compatibility non verificato.


## M2 — Mondo e resa · completata (senza prova su telefono)

Sessione del 27/09/2026 (stessa di M0–M1).

### Fatto
- **Generatore e fluidi** (porting in parallelo, D-014): `WorldGenerator` v0_64 con le 11
  passate, `FluidSystem` senza mesh. Il seme 1931 rigenera esattamente la fixture originale.
- **Luce** (`LightEngine`): calcolo completo identico alla fixture; aggiornamento locale sugli
  edit, uguale al calcolo completo; i chunk con luce cambiata vengono rimeshati.
- **Mesher greedy** (`ChunkMesher`): identico al prototipo per hash su tutti i 432 chunk.
- **Texture procedurali** (atlante, ciuffo d'erba) identiche pixel per pixel.
- **Vegetazione**: alberi (498, tre archetipi) ed erba (402.080 fili) identici al prototipo,
  costruiti su thread; erba rigenerata per colonna dopo gli edit; tronchi solidi per il giocatore.
- **Resa** (D-015): stile dipinto con luce a bande, AO, ombra direzionale, nubi, torce;
  post-processing con contorni, spigoli, raggi, cielo, notte e grading; render target a 360
  righe con camera iso agganciata ai pixel; ciclo giorno/notte di 240 s.
- **Raggi X** a passata singola (D-016) con copertura del prototipo.
- **Pannello sviluppatore** (⚙): nuovo seme, ora +3h, righe 270/360/450, contorni, spigoli,
  dipinto, dither, raggi, erba, ombre, nubi.
- Confronto visivo con il prototipo eseguito in Chromium headless (`--use-angle=swiftshader`).

### Test realmente eseguiti (M2)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 88/88 PASS, log senza errori né warning (il runner ora fallisce sugli errori) |
| `tools/verify_generator.gd` (dall'agente del generatore) | OK su 192×48×192 semi 1931 e 42, 96×40×80 |
| `tools/e2e_touch.gd` | stick, tap di costruzione, muro → copertura 1,00 e raggi X visibili |
| `tools/bench_mesh.gd` (1 thread) | generazione 2,7 s; luce 1,7 s; mesh 4,3 s; alberi 0,8 s; erba 5,6 s; luce locale 1,5 ms |
| Screenshot affiancati prototipo/Godot | iso vicina, iso lontana, TPS: stesse forme, palette, alberi |

### Limiti aperti dopo M2
- **Nessuna prova su telefono né misura FPS.** Il rendering software del container (3–12 FPS con
  ~400k fili d'erba) non è indicativo. L'erba è la voce più pesante: da misurare su dispositivo.
- Acqua provvisoria (dithering) fino alla mesh dei fluidi di M3; la simulazione non gira ancora in gioco.
- Contorni sui ciuffi d'erba e bordo retinato dei raggi X (D-015, D-016).
- TPS senza camera adattiva e con orizzonte fisso; giocatore ancora capsula (avatar in M4).
- Startup da fixture: mesh+erba ~10 s in questo container con 4 core e rendering software.

## M1 — Percorso giocabile minimo · completata (senza prova su telefono)

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
