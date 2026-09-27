# IsoTerra — piano di ricostruzione in Godot e sviluppo mobile action

Documento operativo per Opus 5.5 · 27 settembre 2026

## 1. Decisione di progetto

Realizzare un sandbox voxel in terza persona, pensato per telefono in orizzontale: esplorazione, raccolta, costruzione libera, combattimento corpo a corpo e magia che modifica il mondo. Conservare l'identità visiva di IsoTerra: terreno a blocchi, personaggi modulari, palette pittorica, vegetazione animata, acqua leggibile, possibilità di visuale isometrica.

La direzione proposta è **la libertà costruttiva di Minecraft, in un mondo più piccolo e denso, con combattimento action e interazioni elementali**. Il valore distintivo è poter costruire, scavare e usare gli elementi durante l'esplorazione e gli scontri.

Due traguardi separati:

1. **R — ricostruzione:** tutte le funzionalità attive del prototipo disponibili in Godot, con matrice di parità verificata. Le funzionalità dormienti sono censite, non considerate già giocabili.
2. **G — gioco:** completamento del ciclo raccolta → strumenti → rifugio → esplorazione → combattimento → ricompense → costruzioni migliori; controlli mobile, salvataggi robusti e prestazioni misurate.

Assunzioni operative modificabili: single player offline; Android come primo dispositivo di prova; iOS previsto nell'architettura e verificato durante lo sviluppo; terza persona come visuale principale del gioco finale, isometrica conservata; mondi finiti a seme. Nessuna esigenza di multiplayer, monetizzazione o mondo infinito è stata espressa.

“Opus 5.5” identifica qui l'agente destinatario indicato dall'utente: il piano non presume strumenti, accessi o capacità specifiche del modello. Prima di implementare, l'agente deve verificare il proprio ambiente.

## 2. Che cosa ho effettivamente analizzato

Sorgente: `isoterra_proto_v0_66_mob_combat(1).html`, 2.136.276 byte, 8.415 righe. Three.js è incorporato; le dimensioni del file non equivalgono alla quantità di codice originale del gioco.

SHA-256 sorgente:

```text
4b40454c886365988b579f48a647606ddba273c10a1c5ebe495edeae326358b3
```

Analisi statica dei sottosistemi e delle chiamate attive; esecuzione headless del nucleo `ISO_CORE` estratto dall'HTML, senza modificarlo. Non è stato eseguito un playtest grafico o su telefono. Le osservazioni sulla leggibilità e sul feeling sono quindi valutazioni di progetto da verificare giocando. Non sono disponibili misure di FPS mobile.

Verifica eseguita: mondo 192 × 48 × 192, seme 1931, `caves:false`, generato due volte. Risultati uguali per il buffer dei blocchi; spawn libero; un chunk campione ha prodotto geometria con coordinate finite.

| Dato verificato | Risultato |
|---|---|
| Celle voxel | 1.769.472 |
| Chunk logici 16³ | 432 |
| Spawn restituito dal generatore | x 96,5; y 28; z 96,5 |
| Quote biomi arrotondate | prato 40%, foresta 17%, savana 10%, deserto 7%, tundra 19%, vetta 7% |
| Laghi / tracciati fluviali | 9 / 2 |
| Colonne con acqua | 2.381 |
| Celle blocco acqua | 5.875 |
| Chunk campione (6,1,6), slice 47 | 62 quad, 248 vertici |
| SHA-256 del buffer blocchi | `ce0d3766deb04bb02b6f3e68d06bd428f1ddadd8101d7947175c15e10a071338` |

Questo hash vale per il generatore e l'ordine di memoria originali, non per qualunque implementazione che usi lo stesso numero come seme. Non verifica fluidi, AI, animazioni o intero renderer.

## 3. Inventario e matrice di migrazione

I riferimenti sono righe dell'HTML fornito. Per Opus sono punti di ingresso: seguire le chiamate reali, perché alcuni commenti appartengono a versioni precedenti.

| Sistema | Stato nel sorgente | Destinazione Godot / criterio di parità |
|---|---|---|
| Mondo e blocchi | `ISO_CORE`, righe 4484–4519. 16 ID includendo aria; mondo finito, chunk 16³ | `WorldData`, `ChunkData`, catalogo `BlockDefinition`; ID stabili e query indipendenti dalla scena |
| Generazione | 4522–4608. Passate con semi derivati, clima, sei biomi, massiccio, laghi, fiumi, strati e minerali | Generatore versionato, passate ordinate, spawn sicuro; fixture del seme 1931 |
| Grotte | Passata presente, ma bootstrap worker a riga 5731 usa `caves:false` | Funzionalità dormiente da riattivare nel traguardo G, con collisioni e accessibilità verificate |
| Meshing e luce | 4610–4709. Greedy meshing, AO ai vertici, sole e luce blocchi flood-fill | Mesh per chunk e materiale; luce voxel; seam test ai bordi |
| Terreno smussato | 4739–4882: densità/surface nets ancora presenti; bootstrap forza `mode='blocks'` | Non blocca la parità della modalità attiva. Censire come modalità sperimentale; mantenere riferimento per eventuale ripristino |
| Vegetazione | 4893–4957: alberi procedurali a tre archetipi, erba, vento; alberi distinti dai blocchi | `TreeInstance` con identità e stato; mesh riutilizzate; raccolta e salvataggio coerenti |
| Acqua | 4965–5107: livelli 1–8, source/falling, propagazione, geometria di superficie/lati/fondo, correnti e cascate | Dati fluidi separati, coda attiva, meshing per chunk, stessa superficie per query e rendering |
| Estetica | 5112–5665 e `View`: palette, effetto dipinto, pixelizzazione, outline/spigoli, dithering, cielo, ombre/nubi, raggi, ghost e silhouette | Materiali/shader Godot equivalenti; preset visivo di riferimento e preset mobile; confronto per scene campione |
| Camera | `View` da 6718: isometrica ortografica e terza persona prospettica, rotazione, zoom, inseguimento | `CameraRig`; conservare entrambe, gestire ostacoli e lock-on |
| Movimento | 6929–7040: movimento relativo alla camera, gradini/rampa, salto, caduta, rallentamento in salita | `CharacterBody3D` + controller; preservare sensazione e regole con percorso di prova |
| Nuoto | 6941–6982: asciutto, guado, nuoto, galleggiamento, correnti, salto fuori dall'acqua | Stati locomozione distinti; transizioni con isteresi, prove su sponde e cascate |
| Avatar | `CHARGEN` da 4247; rig da 5803; eroe modulare da 6629; editor attivo da 7980 | Ricetta avatar versionata; parti modulari, colori, preset, editor unico e persistenza |
| Corpo a corpo | 7103–7110 e 7552–7908: pugni, spada, lancia, martello, spadone; mosse, combo, hitstop, contatti e pose | `CombatController`, `WeaponDefinition`, `AttackDefinition`; stesso clock per posa e finestra danno |
| Combo spada | 7625–7632: L, LL, LLL, LLLL, H, LH, LLH | Tutti i rami funzionanti; buffer tipizzato, un danno per bersaglio per attacco |
| Nemici | 7183–7501: slime, scheletro, goblin, mosse distinte, inseguimento, vista, ritorno, danno, morte/respawn | Scene per archetipo, componenti comuni; non sostituirli tutti con lo stesso inseguitore |
| Vita giocatore | 7200–7215: 100 HP, invulnerabilità breve, rigenerazione fuori combattimento, morte e ritorno | `Vitals`; HUD sempre leggibile, respawn in posizione sicura |
| Lock-on e feedback | 7524 e 7858–7868: bersaglio, barre, numeri, flash, trail; strafe da 7061 | `TargetingService`, UI e VFX; movimento resta relativo alla camera |
| Magia | 8059–8403: fuoco, acqua, terra, aria; raccolta in mano, rilascio, balistica, mana e audio sintetico | `SpellDefinition`, proiettili, pool VFX, audio equivalente e reazioni preservate |
| Reazioni | 8250 circa–8336: incendi, bagnato, spegnimento, lava solidificata, crateri, bruciatura/lentezza/spinta | `ElementReactionSystem`; unica tabella di regole, edit del mondo attraverso un servizio comune |
| Scavo | Durezza, avanzamento e crepe presenti; unico `TOOLS.fist` ha `hitsBlocks:false`, riga 7107 | Non descriverlo come raccolta già completa. Implementare attrezzi equipaggiabili nel traguardo G |
| Costruzione | 7098–7102 e 7941: piazzamento terra/pietra/sabbia/legno/torcia, portata e controllo sovrapposizione player | Preservare regole in sandbox; poi aggiungere costo inventario e anteprima |
| Inventario | 7109–7110: semplice contatore di risorse; piazzamento non ne scala i materiali | Nuovo inventario a slot/stack e transazioni atomiche per craft e costruzione |
| Persistenza | `localStorage` per avatar, risoluzione e camera; non emerge un salvataggio del mondo/progresso | Nuovo `SaveService`: mondo, inventario, attori persistenti, avatar e progressione |
| UI mobile | Stick touch, drag/pinch camera, pulsanti dedicati; molti comandi tecnici visibili | Nuova UI a contesti, ownership delle dita, safe area, layout adattivo |

Codice legacy da registrare: vecchio compositore e rig ereditati, manichini, pipeline `ISOCHAR` di animazione cotta e predoni, surface nets. Il percorso attivo `spawnDummies()` chiama `spawnBasicEnemies()` anche se vicino esiste un commento che dice il contrario. Non importare asset esterni immaginando che i file originali citati nei commenti siano allegati: in questo incarico è disponibile solo l'HTML.

## 4. Problemi da affrontare esplicitamente

**Il sandbox economico è incompleto.** La presenza di `give()` e dei blocchi posabili non costituisce un inventario con ricette e progressione. Servono strumenti ottenibili, costi, drop, deposito, ricette e motivi per esplorare.

**Informazioni essenziali sono nascoste.** La regola CSS `.hud,.help{display:none!important}` nasconde anche vita, mana e contatori nel relativo contenitore. Nel gioco finale separare HUD giocabile, aiuti e debug.

**I controlli descritti non coincidono sempre con quelli attivi.** Ad esempio, il rilascio touch sul mondo non attiva la normale azione di scavo/attacco; ci sono pulsanti dedicati. Il piano deve partire dagli handler effettivi e testare il multitouch, non copiare il testo di aiuto.

**Il costo degli aggiornamenti può crescere.** Il worker richiama `computeLight(world)` per modifiche singole o batch; `view.setWater()` viene richiesto periodicamente dopo cambiamenti. In Godot usare propagazione locale, budget e chunk sporchi; verificare quanto lavoro viene realmente rifatto. Non assumere che il cambio di engine risolva da solo il problema.

**Esistono più rappresentazioni dello stesso ambiente.** Blocchi, superfici, densità, heightfield, fluidi e alberi hanno percorsi diversi. Il controller di superficie non basta come specifica per grotte, soffitti e ponti sovrapposti: questi casi richiedono collisioni volumetriche vere.

**Action e mondo distruttibile devono condividere regole.** Se un nemico attraversa un muro costruito o un fendente colpisce attraverso terra, il sandbox perde credibilità. La distruzione deve invalidare collisioni e percorsi in modo prevedibile.

## 5. Esperienza proposta e dimensione del primo gioco

### Ciclo principale

Parti in un prato sicuro, raccogli risorse semplici, costruisci un banco e un rifugio. Prepari un'arma, esplori una zona più pericolosa, combatti usando anche terreno ed elementi, recuperi materiali e torni a migliorare equipaggiamento e base. Una spedizione deve avere una piccola meta visibile e una ricompensa utile in circa 5–12 minuti; il salvataggio permette di interrompersi in qualsiasi momento sicuro.

Un esempio di incontro rappresentativo: attraversi un fiume costruendo un passaggio, affronti goblin vicino a un accampamento, usi l'acqua per spegnere un incendio che minaccia il ponte, recuperi ferro e sblocchi un nuovo attrezzo. La soluzione deve poter cambiare in base a costruzione, combattimento o magia.

### Ambito per il traguardo G

| Contenuto | Obiettivo iniziale proposto |
|---|---|
| Mondo | Mantenere 192 × 48 × 192 durante parità e prima versione; ampliarlo solo dopo profilazione |
| Biomi | Conservare i sei originali; concentrare inizialmente incontri e progressione su prato, foresta e deserto |
| Armi | Pugni + quattro armi originali, ottenibili attraverso progressione |
| Attrezzi | Ascia, piccone, pala; risorse iniziali raccoglibili senza creare un blocco nella progressione |
| Magie | Quattro elementi originali, due slot rapidi durante il combattimento |
| Nemici | Tre archetipi originali + varianti di difficoltà; un miniboss dopo la validazione del combattimento |
| Costruzione | Blocchi base, torce, banco, contenitore e punto di riposo; set decorativo piccolo |
| Ricette | Circa 12–20 ricette utili, senza moltiplicare subito i materiali |
| Esplorazione | Piccoli accampamenti, una rovina, una grotta accessibile con obiettivo e ricompensa |
| Progressione | Due livelli iniziali di attrezzatura, materiali rari che sbloccano possibilità concrete |
| Persistenza | Slot mondo, autosave, backup, ripresa dopo sospensione |

Rinviare a dopo G: multiplayer, mondo infinito, automazione tipo redstone, villaggi simulati, agricoltura profonda, cavalcature, generazione illimitata di dungeon, combattimento subacqueo. Queste aggiunte non sono necessarie per completare il prototipo originale.

### Miglioramenti action

Conservare i tempi distinguibili delle quattro armi e le combo. Aggiungere una schivata breve e controllabile, recuperi leggibili, anticipazione visiva degli attacchi e assistenza alla mira moderata. Attacchi leggeri sempre disponibili; stamina inizialmente riservata a schivata e pesante, così l'esplorazione non diventa un'attesa.

La parata perfetta è un'estensione successiva: prima verificare che attacco, pesante, schivata e magia siano comodi con due pollici. Il martello deve distinguersi tramite interruzione/postura; la lancia tramite distanza; lo spadone tramite arco e impegno; la spada tramite flessibilità delle combo.

Mantenere le reazioni già definite: fuoco su bagnato consuma bagnato e non infligge danno in quella reazione; acqua su bruciatura spegne e moltiplica il danno per 1,25; aria su bagnato aumenta la spinta. Nuove reazioni vanno aggiunte alla tabella, mai disperse nelle classi dei singoli proiettili.

## 6. Controlli mobile

Usare layout orizzontale, HUD ad alta risoluzione anche se il mondo viene renderizzato a risoluzione ridotta. Obiettivo ergonomico iniziale: aree toccabili equivalenti ad almeno 48 dp, adattate alla scala UI reale, non 48 pixel fisici fissi. Opzioni per mancini, posizione e dimensione pulsanti, sensibilità camera, vibrazione e riduzione di shake/flash.

| Contesto | Sinistra | Destra | Comandi secondari |
|---|---|---|---|
| Esplorazione | Stick, corsa analogica | Drag camera, salto, interazione | Hotbar, zaino, cambio contesto |
| Combattimento | Stick relativo alla camera | Attacco, pesante, schivata, magia equipaggiata | Lock manuale facoltativo, cambio bersaglio/slot; salto in posizione stabile |
| Costruzione/raccolta | Stick | Mira, anteprima, azione esplicita; pressione continua per scavare | Materiale/attrezzo, uscita dal contesto |

In combattimento lo stick sceglie movimento, la mira assistita sceglie un candidato davanti al personaggio, il lock mantiene un bersaglio esplicito. Applicare un tempo minimo di mantenimento del candidato e una soglia di cambio per evitare che salti tra nemici. Il drag camera deve sempre prevalere sul tap del mondo.

Ogni dito viene assegnato a stick, camera o pulsante dal punto iniziale del contatto fino al rilascio/cancel. Non trasferire l'ownership attraversando un'altra area. Cambio focus, menu, morte e sospensione devono azzerare gli input mantenuti. Verificare movimento + rotazione + attacco simultanei e due dita rilasciate in ordine diverso.

Il pulsante pesante resta distinto nella prima implementazione: cambiare tutto in “tap/pressione lunga” rende più ambigua l'esecuzione dei rami LH e LLH. Semplificare solo dopo un confronto su telefono. I comandi tecnici del prototipo vanno in un pannello sviluppatore.

## 7. Architettura Godot

### Scelte iniziali

Godot 4.x stabile, con versione e template di export fissati in repository dopo aver verificato l'installazione. GDScript tipizzato per gameplay, UI e prima versione del nucleo. Valutare C++/GDExtension esclusivamente quando una misura individua un collo di bottiglia ripetibile; non renderlo un prerequisito della prima build.

Proporre il renderer **Mobile** per i telefoni recenti e fare uno spike comparativo con **Compatibility** sui dispositivi obiettivo. La documentazione Godot distingue le due fasce e segnala possibili adattamenti quando si cambia renderer [S1]. La scelta finale dipende dai test del gioco, non dal nome del renderer. Non progettare l'estetica attorno a SDFGI, VoxelGI o nebbia volumetrica per questa baseline.

### Moduli e responsabilità

| Modulo | Responsabilità |
|---|---|
| `world/data` | Buffer voxel, coordinate, metadati, versioni chunk; nessun nodo per blocco |
| `world/generation` | Passate pure, semi derivati, biomi, strutture e fixture |
| `world/meshing` | Facce visibili, greedy meshing, AO, acqua separata, dati collisione |
| `world/simulation` | Fluidi, luce, fuoco, code attive e budget |
| `world/runtime` | Caricamento chunk, priorità, applicazione mesh/collisioni, edit batch |
| `actors/player` | Movimento, nuoto, stati locomozione, equipaggiamento |
| `actors/enemies` | AI, attacchi, navigazione locale, spawn e ritorno |
| `combat` | Mosse, clock, contatti, danno, status, targeting |
| `items` | Cataloghi, stack, ricette, drop, inventario e transazioni |
| `presentation` | Avatar, animazioni, camera, shader, VFX e audio |
| `ui` | Touch, HUD, inventario, craft, editor avatar, impostazioni |
| `persistence` | Salvataggi versionati, backup, migrazioni e ripristino |
| `tests` | Fixture del porting, scene tecniche, test integrazione e benchmark |

`GameRoot` possiede mondo, attori e sessione. Autoload limitati a impostazioni, salvataggi e servizi effettivamente globali. Evitare un enorme event bus che nasconda la sequenza delle modifiche.

Cataloghi tramite `Resource`: `BlockDefinition`, `ItemDefinition`, `RecipeDefinition`, `WeaponDefinition`, `AttackDefinition`, `SpellDefinition`, `EnemyDefinition`, `BiomeDefinition`, `AvatarRecipe`. Le definizioni condivise sono immutabili a runtime; timer, vita, durabilità e stack appartengono alle istanze.

### Contratti fondamentali

```text
WorldData.get_block(cell) -> block_id
WorldEditService.try_apply(batch, source, expected_versions) -> EditResult
VoxelQuery.raycast(origin, direction, max_distance) -> VoxelHit
FluidSystem.sample(position) -> WaterSample
CombatResolver.resolve(attack_id, attacker, contact) -> DamageResult
InventoryService.try_transaction(costs, rewards) -> TransactionResult
SaveService.checkpoint(snapshot) -> SaveResult
```

Un edit riuscito aggiorna i dati una volta e marca i chunk interessati, compresi i vicini per facce/AO/fluidi. Costruzione, piccone e magia usano lo stesso percorso. Inventario e piazzamento sono una transazione: niente blocco gratuito se il costo fallisce e niente materiale perso se il piazzamento viene rifiutato.

### Voxel, mesh e collisioni

Buffer compatti, inizialmente compatibili con gli ID originali. Generare mesh tramite `ArrayMesh` [S2], una mesh per chunk e superfici per le poche categorie di materiale. Non creare un `Node3D`, un cubo o un collider per ogni cella. Separare opachi, eventuali alpha-cutout e acqua.

Prima facce visibili, poi greedy meshing verificando materiale, luce e AO: non fondere facce che devono restare visivamente diverse. La collisione può avere mesh semplificata dedicata per chunk; il controller deve reagire a pareti e soffitti, non solo all'altezza della colonna.

Le modifiche sotto il giocatore o vicino a un attacco richiedono priorità di collisione. Se la collisione fisica è ancora vecchia, bloccare temporaneamente l'azione che ne dipende oppure usare query voxel autorevoli: non lasciare un intervallo in cui si attraversa un muro appena costruito.

Le coordinate e l'orientamento richiedono un adapter: il prototipo usa Y verso l'alto e propri facing/assi del rig, mentre i nodi e gli asset Godot possono assumere un forward diverso. Testare un cubo con sei facce marcate, winding/normal, quaternion, mano dominante e direzione dei raycast prima di portare animazioni e combattimento.

### Thread e simulazione

Lavori in background su snapshot immutabili dei dati; risultati contenenti coordinate chunk, versione, ID sessione e array. Applicazione di nodi, mesh e collider sul main thread con budget. Scartare risultati obsoleti se il chunk è cambiato, scaricato o il mondo è stato rigenerato. Godot non rende automaticamente thread-safe l'intero scene tree [S3].

Il mondo finito non richiede subito streaming infinito: limitare chunk renderizzati/collider e simulazione attiva per distanza, pur potendo conservare tutti i dati compatti. Fluidi, luce e fuoco lavorano su code; le modifiche ai confini devono riattivare entrambi i lati quando tornano attivi.

Fisica a passo fisso; interpolazione della presentazione. Clock del combattimento condiviso tra animazione e hitbox. Hitstop locale a chi combatte, con politica esplicita per AI e proiettili; UI e salvataggi non si fermano. Testare a 30/60/120 Hz di rendering.

### Portabilità del generatore

Per parità esatta non sostituire subito noise e RNG con `FastNoiseLite` e RNG Godot. JavaScript usa operazioni bitwise a 32 bit, `Math.imul`, moltiplicazioni floating point e conversioni typed-array: una traduzione ingenua può cambiare il mondo. Riprodurre le conversioni e l'ordine di calcolo dove necessario.

Strategia: prima caricare una fixture del mondo originale e validare rendering/movimento; poi portare le passate e confrontare buffer, quote, spawn e acqua. Se si sceglie un nuovo algoritmo per il gioco finale, conservarlo come `generator_version=2`, senza rigenerare salvataggi v1 con il nuovo generatore.

### Acqua ed elementi

Conservare il modello originale alimentato da sorgenti, livelli 1–8 e flag di caduta. Non promettere conservazione del volume: il sorgente lo esclude esplicitamente. Tick logico iniziale di riferimento 0,25 s, con coda e budget misurabili. Geometria e galleggiamento usano la stessa funzione di superficie.

Separare simulazione ed effetti: onde, schiuma e schizzi non modificano il livello logico. Pool con limiti, priorità agli effetti vicini. Salvare metadati delle sorgenti e uno stato coerente dei fluidi; al caricamento ricostruire le code necessarie senza duplicare acqua.

### Animazioni, contatti e AI

Per la parità usare rig modulare e pose equivalenti, con schema dati per i tempi. Passare eventualmente a `Skeleton3D`/`AnimationTree` senza cambiare le definizioni di danno. Clip visiva e finestra attiva non devono usare due timer indipendenti.

Contatti melee con sweep tra posa precedente e corrente della lama, maschere fisiche, ostacoli e insieme dei bersagli già colpiti da quell'attacco. Non affidarsi solo a `Area3D.body_entered`, che può perdere un contatto rapido. Lo spostamento dell'attacco passa dal controller collisioni.

AI a stati: idle/pattuglia, allerta, avvicinamento, anticipazione, attivo, recupero, stagger, ritorno, morte. Conservare l'idea già presente di limitare gli attaccanti simultanei. Per il primo mondo usare ricerca su celle camminabili locali e aggiornamenti alla modifica dei blocchi; considerare una navmesh dinamica solo dopo uno spike. Nessun rebake dell'intero mondo per ogni picconata.

## 8. Salvataggio come requisito del gioco

Formato con `schema_version`, `generator_version`, seed, dimensioni, revisione del mondo, player, inventario, equipaggiamento, ricetta avatar, tempo, progressione, contenitori, alberi modificati e nemici persistenti. Non serializzare direttamente l'albero di nodi.

Per la prima versione usare snapshot dei chunk modificati; seed e versione ricostruiscono quelli intatti. Preservare ID stabili. Salvataggio su file temporaneo, verifica integrità e sostituzione con backup; manifest coerente con i chunk. Gestire spazio insufficiente, slot danneggiato e versione più recente non supportata senza distruggere il salvataggio precedente.

Autosave incrementale, dopo progressi importanti e su pausa/sospensione quando possibile. Non contare sull'ultimo evento di chiusura dell'app: il sistema operativo può terminarla. Alla ripresa azzerare input pendenti, aggiornare audio e ripristinare lo stato senza simulare tutti i minuti trascorsi in background.

## 9. Prestazioni: obiettivi da validare

Questi sono budget iniziali proposti, non risultati misurati e non promesse per qualunque telefono.

| Area | Gate iniziale |
|---|---|
| Profilo base | 30 FPS stabili; frame time p95 ≤ 33,3 ms nella scena di stress |
| Profilo alto | 60 FPS; p95 ≤ 16,7 ms su dispositivo capace |
| Durata test | 20 minuti su dispositivo fisico; registrare surriscaldamento e cali progressivi |
| Lavori world sul main thread | Budget indicativo 2 ms/frame, da adattare al profilo |
| Memoria | Obiettivo iniziale processo < 500 MB; registrare picco e memoria dopo più rigenerazioni |
| Avvio | Primo ingresso giocabile entro 8 s sul dispositivo base scelto, con caricamento visibile |
| Modifica locale | Feedback visivo immediato; mesh locale aggiornata idealmente entro 100 ms, senza collisioni incoerenti |
| Popolazione iniziale | Cap indicativo 12 nemici attivi, AI distante rallentata/disattivata |
| VFX | Pool e limiti per piattaforma; nessuna allocazione illimitata durante fuoco/acqua |

La scena di stress comprende acqua in propagazione, incendio, più nemici, combo, modifiche al confine di chunk e camera in movimento. Registrare build, renderer, modello dispositivo, OS, risoluzione, qualità, p50/p95/p99, CPU/GPU e memoria. Un contatore FPS medio non basta.

Scegliere almeno due Android fisici (uno di fascia inferiore e uno recente) e un iPhone se iOS resta obiettivo. Per export iOS prevedere Mac con Xcode e configurazione di firma [S4]. In assenza di hardware dichiarare “non verificato”, non “compatibile”.

## 10. Roadmap eseguibile per Opus

Ogni milestone produce una build avviabile, un breve report e una matrice aggiornata. Implementare una milestone per volta; non partire dalle funzionalità più appariscenti.

| Fase | Dipendenze e lavoro | Criterio di uscita |
|---|---|---|
| M0 — Baseline | Inventario completo, estrazione fixture e tabelle, installazione Godot/export, decisioni renderer/assi | HTML di riferimento integro; progetto vuoto avviabile; fixture e checklist parità presenti; primo export minimo su Android |
| M1 — Percorso giocabile minimo | M0. Chunk, facce visibili, collider, movimento/salto, camera ISO/TPS, stick e azioni touch | Camminare su un terreno fixture, salire/scendere, collidere con muri/soffitto, modificare un blocco in debug; nessun input bloccato |
| M2 — Mondo e resa | M1. Generatore, biomi, vegetazione, greedy mesh, AO/luce, cielo/giorno, occlusione, shader base | Seme 1931 confrontato; nessuna fessura tra chunk; riferimenti visivi delle due camere; edit locale senza ricostruire tutto |
| M3 — Acqua e locomozione | M2. Fluidi, cascate, guado/nuoto, correnti, effetti essenziali | Test sorgente/bacino/canale/diga e confine chunk; uscita dall'acqua senza teleport; profilo stabile durante propagazione |
| M4 — Action originale | M3. Avatar, pugni/quattro armi, combo, lock/strafe, tre nemici, vita/morte, quattro magie/reazioni, audio | Arena di prova: tutte le mosse/reazioni; contatti senza colpire attraverso pareti; editor avatar e ricetta persistente |
| R — Gate parità | M0–M4. Recupero funzionalità attive mancanti e preset visivo originale | Tutte le righe attive della matrice verificate; dormienti censite separatamente; nessun miglioramento usato per mascherare una funzione mancante |
| M5 — Sandbox persistente | R. Attrezzi, raccolta, inventario, craft, costi piazzamento, contenitori, checkpoint, grotte | Raccogliere → craftare → costruire → chiudere → riaprire; nessuna duplicazione/perdita; percorsi sotterranei corretti |
| M6 — Mobile action migliorato | M5. Schivata, stamina mirata, targeting assistito, HUD finale, comfort input, progressione e punti d'interesse | Sessione di 15–20 minuti solo touch: una spedizione completa e ritorno; nessun comando essenziale richiede tastiera |
| M7 — Contenuti e rifinitura | M6. Miniboss, ricette finali, audio/VFX, tutorial breve, qualità scalabile | Obiettivo iniziale completabile in un mondo nuovo; tutti gli oggetti chiave ottenibili; sei biomi preservati |
| M8 — Verifica mobile | M7. Profilazione termica, lifecycle, recovery salvataggi, export Android/iOS | Gate prestazioni, sospensione/ripresa e regressioni superati sui dispositivi registrati; limiti residui dichiarati |

Non stimare giorni sulla base della sola quantità di codice generabile. Dopo M1 e dopo M4 stimare il restante lavoro usando numero di difetti, costo dei contenuti e velocità reale di verifica. Una build visivamente promettente non equivale a una ricostruzione completa.

## 11. Test che proteggono i rischi reali

| Prova | Risultato atteso |
|---|---|
| Generazione ripetuta | Stessi buffer per stesso seme/versione; confronto separato per blocchi, acqua, biomi |
| Edit su faccia/spigolo/angolo chunk | Tutti i vicini necessari aggiornati; nessuna faccia invisibile o duplicata |
| Tunnel, soffitto, ponte sopra terreno | Movimento e raycast selezionano il volume corretto, senza risalire al tetto |
| Due edit rapidi e risultato worker fuori ordine | Il risultato vecchio viene scartato |
| Rigenerazione mondo con job pendenti | Nessuna mesh/entità del mondo precedente ricompare |
| Scavo/piazzamento durante transazione | Materiali coerenti; player e nemici non intrappolati in un blocco nuovo |
| Luce: torcia aggiunta/rimossa dietro muro | Propagazione e rimozione corrette; niente luce residua |
| Acqua bloccata, deviazione, cascata | Coda converge o rimane limitata; nessuna fessura; nuoto segue la superficie |
| Combo LLLL/LH/LLH e input rapido | Sequenza corretta; limite buffer; un danno per bersaglio/attacco |
| Melee/proiettile a basso frame rate | Nessun attraversamento dovuto a campionamento insufficiente |
| Incendio → acqua; acqua → fuoco; bagnato → aria | Reazioni tabellate e durate corrette |
| Nemico e muro appena costruito | Aggiornamento del percorso oppure attesa/ritorno; mai attraversamento |
| Tre contatti touch e pointer cancel | Nessuna azione duplicata o mantenuta dopo il rilascio |
| Salvataggio/riapertura e crash simulato | Stato coerente o recupero backup, senza perdere anche l'ultima versione valida |
| Morte con punto di ritorno modificato | Ricerca di posizione sicura, nessuno spawn dentro solidi/acqua profonda |

Le verifiche visive includono immagini comparabili in prato, bosco, deserto, tramonto, notte con torcia, fiume/cascata, occlusione del player, attacco e magia. Non richiedere identità pixel-per-pixel tra due renderer diversi: confrontare silhouette, palette, scala, leggibilità e comportamenti. Conservare un preset di riferimento prima di modernizzare la resa.

## 12. Prompt principale da consegnare a Opus 5.5

Incollare il testo seguente e allegare sia l'HTML originale sia questo documento.

```text
Agisci come sviluppatore Godot e technical game designer del progetto IsoTerra.
Devi ricostruire il prototipo HTML allegato in un vero progetto Godot 4.x,
poi trasformarlo in un piccolo sandbox voxel action per telefono.

Usa IsoTerra_Piano_Godot_Opus_5_5.md come specifica di lavoro. Le scelte
proposte sono default: registra le variazioni motivate. Non considerare questo
documento la prova che il codice sia già implementato o testato.

OBIETTIVO
Conserva tutte le funzionalità attive del prototipo: mondo finito a chunk,
sei biomi, costruzione, acqua/correnti/cascate, nuoto, due camere, avatar
modulare, pugni e quattro armi, combo, lock-on, tre nemici, vita/morte,
quattro magie e reazioni, estetica e feedback. Completa poi raccolta,
strumenti, inventario, craft, salvataggi e progressione, aggiungendo
schivata e controlli mobile più comodi.

METODO
1. Leggi l'HTML e segui bootstrap e call site. Separa funzionalità attive,
   dormienti, incomplete e commenti obsoleti. Non usare commenti come
   prova di una funzione giocabile.
2. Non tradurre il monolite riga per riga. Separa dati, simulazione,
   presentazione, input e persistenza. Nessun nodo/collider per voxel.
3. Crea docs/PARITY_MATRIX.md con fonte, destinazione, stato e verifica;
   docs/DECISIONS.md; docs/PROGRESS.md; tests/fixtures e scene tecniche.
4. Fissa versione Godot, renderer, convenzioni assi e template export.
   Verifica gli strumenti presenti prima di citarne risultati.
5. Procedi una milestone alla volta secondo M0–M8, mantenendo una build
   avviabile. Prima completa R, poi i miglioramenti del traguardo G.
6. Per ogni milestone fornisci: cambiamenti, istruzioni per provarla,
   test realmente eseguiti, limiti, aggiornamento matrice e prossima fase.
7. Non dichiarare una feature completa se è solo una classe vuota,
   un pulsante, una simulazione finta o un TODO.
8. Non dichiarare FPS, export mobile o playtest se non li hai misurati.
   Se mancano telefono, Mac, SDK o firma, prosegui con la parte verificabile
   e registra esattamente quale gate resta bloccato.

VINCOLI TECNICI
- GDScript tipizzato iniziale; risorse dati per armi, mosse, magie,
  blocchi, oggetti, ricette, nemici, biomi e avatar.
- Chunk 16^3 e mondo originale 192x48x192 come baseline.
- Una fonte autorevole dei dati mondo; edit atomici con versioni chunk.
- Background su snapshot; scene tree e applicazione risultati sul main thread.
- Clock condiviso per animazioni di attacco e contatti, sweep delle armi,
  query ostacoli e deduplicazione danno per attacco.
- Acqua source-fed a livelli, non fluidodinamica realistica.
- Due modalità camera, occlusione leggibile, input camera-relative.
- Nessun mondo infinito o multiplayer prima del gate G.
- UI mobile orizzontale, multitouch con ownership, HUD vita/mana visibile.
- Salvataggi versionati e recuperabili; niente serialization del scene tree.

PRIMA SESSIONE
Esegui M0. Crea il repository/progetto se l'ambiente lo permette, la matrice
di parità e le fixture. Estrai dal core originale una fixture del seme 1931
con caves:false e conserva buffer originali e checksum. Avvia un progetto
minimo e verifica il primo export disponibile. Prepara la scena per M1.
Non iniziare contemporaneamente crafting, boss e shader finali.

Concludi la sessione con un punto di ripresa preciso e con una lista breve
di prove manuali per me. Chiedi solo decisioni che blocchino realmente
la milestone; per quelle reversibili applica i default e documentali.
```

### Prompt di continuazione

```text
Leggi docs/PROGRESS.md, docs/PARITY_MATRIX.md e docs/DECISIONS.md e confrontali
con lo stato reale del progetto. Continua dalla prossima milestone incompleta
del piano IsoTerra. Riproduci prima eventuali regressioni bloccanti, completa
la milestone e verifica i suoi criteri di uscita. Non riscrivere sistemi
funzionanti senza una motivazione concreta. Aggiorna i tre documenti e riporta
solo verifiche realmente eseguite e limiti ancora aperti.
```

## 13. Ordine delle decisioni da prendere con il proprietario

Il piano è eseguibile con i default indicati. La prima informazione che migliora materialmente i budget è **il telefono più debole su cui deve funzionare**, insieme alla priorità Android/iOS. La seconda è quanto la visuale isometrica debba restare centrale rispetto alla terza persona. Non serve risolvere monetizzazione o multiplayer per iniziare M0–M1.

## 14. Fonti tecniche

La descrizione del prototipo deriva dal sorgente allegato e dalla verifica headless indicata. Le seguenti pagine ufficiali sono state consultate per le scelte Godot il 27 settembre 2026; la documentazione `stable` è mobile nel tempo, quindi Opus deve usare quella corrispondente alla versione fissata nel progetto.

- [S1 — Godot: Overview of renderers](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)
- [S2 — Godot: Using the ArrayMesh](https://docs.godotengine.org/en/stable/tutorials/3d/procedural_geometry/arraymesh.html)
- [S3 — Godot: Thread-safe APIs](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html)
- [S4 — Godot: Exporting for iOS](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html)
