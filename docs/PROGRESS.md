# Avanzamento

## 05/10/2026 — D-058: nemico con l'IA, parata, scontro nell'arena di Cell

### Test realmente eseguiti (D-058)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 207/207 PASS. Nuovi (`test_duel.gd`): parata perfetta, guardia tenuta, colpo alle spalle, guardia rotta, capriola, carica interrotta, IA contro IA con tre coppie di armi (tutti e due attaccano, colpiscono e si difendono). Aggiornato: nell'arena c'e' il nemico al posto del manichino |
| `tools/duel_preview.gd` (nuovo) | Nel gioco: 16 s, un round perso e uno vinto, al round 2. Corretti: lista dei bersagli tipizzata (il nemico non ci entrava), tinta arancio fissa sui personaggi |
| Export Android debug 0.36.0-m5 (versionCode 38) + `apksigner verify` + `aapt2 dump badging` | OK; non provato sul telefono |

## 03/10/2026 — D-057: fuoco leggibile sul telefono

Colori saturi (mai bianco), cerchio arancio, grani piu' grandi.

### Test realmente eseguiti (D-057)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 200/200 PASS |
| `tools/magic_preview.gd` in terza persona e isometrica | Guardate a occhio: fiamma, cerchio ed esplosione a grani arancio e rossi in tutte e due le viste |
| Export Android debug 0.35.0-m5 (versionCode 37) + `apksigner verify` + `aapt2 dump badging` | OK; non provato sul telefono |

## 03/10/2026 — D-056: fuoco a grani come in RMNDWN

Il fuoco del bastone non ha piu' mesh: e' gas caldo a grani che sale, si raffredda e cambia colore
come in RMNDWN; testa del proiettile che lascia la scia, cerchio di rune a grani, esplosione a fungo
con braci a terra.

### Test realmente eseguiti (D-056)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 200/200 PASS |
| `tools/magic_preview.gd` (ora anche la foto del fungo e il massimo dei grani; foto un fotogramma dopo) | Guardate a occhio. Corretti: bagliore additivo che sbiancava, grani freddi che restavano come macchie scure, colonna troppo alta durante la carica, dardo troppo piccolo. Grani al massimo 1240 su 1300. Danni invariati (14 e 63) |
| Banco del gas (1300 grani liberi, 20 passi) | ~3,5-4 ms a passo sul computer di sviluppo; sul telefono non misurato |
| Export Android debug 0.34.0-m5 (versionCode 36) + `apksigner verify` + `aapt2 dump badging` | OK; non provato sul telefono |

## 03/10/2026 — D-055: bastone magico e magia del fuoco

Bastone sul modello di Frieren (dalla tavola Higgsfield), dardi di fuoco col leggero e palla di
fuoco caricabile col forte, con esplosione e bruciatura.

### Test realmente eseguiti (D-055)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 200/200 PASS. Aggiornato: l'armeria espone cinque armi |
| `tools/magic_preview.gd` (nuovo: dardo, carica, palla, esplosione, bruciatura sul manichino dell'arena) | Guardate a occhio. Corretti: la palla partiva dalla posa del passo prima (bastone alzato dietro), l'esplosione additiva sul marmo era bianca. Dardo 14 di danno con la bruciatura, palla caricata 63 con la bruciatura |
| Export Android debug 0.33.0-m5 (versionCode 35) + `apksigner verify` + `aapt2 dump badging` | OK; non provato sul telefono |

Su richiesta del proprietario niente suite e2e completa questa volta.

## 03/10/2026 — D-051, D-052, D-053: armature in anteprima, armi dai modelli Higgsfield, martello a terra

Armature di cuoio (casco o cappuccio) e di ferro da cavaliere con forma propria, per ora solo in
anteprima. Spada, spadone, lancia e martello ricostruiti nel codice dai modelli Higgsfield.
L'onda dei colpi a terra del martello parte quando tocca il suolo; sotto l'elmo non escono capelli.

### Test realmente eseguiti (D-051…D-053)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 197/197 PASS, log pulito. Nuovo: nessun capello sotto l'elmo per tutte le 16 acconciature. Aggiornato: il test dello slancio dello spadone preme il forte nel rientro (col nuovo ritmo delle spazzate il tocco a tempo fisso scadeva) |
| `tools/armor_preview.gd` (cuoio con casco e con cappuccio, ferro; spada, lancia, spadone, martello) | Guardate a occhio; prima versione del casco con parti scoperte, rifatta come guscio unico |
| Prova dei movimenti durante D-052 | `sweep2` dello spadone da solo falliva 2 volte su 3: la lama passava a 9–12 cm dal manichino a finestra quasi chiusa. Dopo il nuovo ritmo delle spazzate entra di 0,3–0,4 m, 4 corse su 4 OK. La prova ora stampa la distanza anche per i colpi da soli |
| Suite e2e completa (movimenti, passo, nuoto, terza e prima persona, combattimento, aggancio, sessione, touch, sandbox, oggetti a terra, armeria, opzioni e opzioni sul telefono) | OK, nessun errore di script. Onda dei colpi a terra: catena 0,07 s dopo l'inizio della fase attiva con la testa a 0,14 m dal suolo; terremoto, colpo caricato e onda 0,08–0,09 s dopo, con la testa gia' a terra (prima: subito, con la testa in alto) |
| Export Android debug 0.31.0-m5 (versionCode 33) + `apksigner verify` + `aapt2 dump badging` | OK; non provato sul telefono (la 0.30.0-m5 e' stata provata dal proprietario) |

Crediti Higgsfield spesi: ~8,5 (tavole di cuoio e ferro, immagini delle armi, 3D con SAM 3).

## 02/10/2026 — D-050: spada, via il quinto colpo dopo il giro

La catena leggera della spada torna a quattro colpi (fendente → rovescio → calata → giro), poi da
capo. Tolto il rovescio orizzontale preso dal video.

### Test realmente eseguiti (D-050)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 196/196 PASS, log pulito. Aggiornati: dopo il giro la catena finisce e riparte dal fendente; tabella dei forti della spada a quattro punti |
| Suite e2e completa (movimenti, passo, nuoto, terza e prima persona, combattimento, aggancio, sessione, touch, sandbox, oggetti a terra, armeria, opzioni e opzioni sul telefono) | OK, nessun errore di script. Movimenti: catena della spada fendente, rovescio, calata, giro, di nuovo fendente, tutti a segno |
| Export Android debug 0.29.0-m5 (versionCode 31) + `apksigner verify` + `aapt2 dump badging` | OK; non provato sul telefono |

## 02/10/2026 — D-049: martello, Leggero-Leggero-Forte come colpo pesante caricato

Il forte dopo il montante del martello non viene più dal video: carica alta col busto inarcato
indietro (caricabile tenendo premuto), colpo secco a terra vicino ai piedi, busto poco chinato.

### Test realmente eseguiti (D-049)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 196/196 PASS, log pulito. Nuovo: il colpo si carica, martello sopra la testa e busto indietro nella carica, busto chinato meno di 30° nel colpo, poca spinta, carica più lunga del colpo a terra leggero. La prima versione durava 1,64 s (limite 1,6): rientro accorciato |
| `tools/pose_sheet.gd --weapon=hammer` | Prima versione: nella carica il martello pendeva dietro la schiena; corretta in due passi fino al martello alto dietro la testa |
| Suite e2e completa (movimenti, passo, nuoto, terza e prima persona, combattimento, aggancio, sessione, touch, sandbox, oggetti a terra, armeria, opzioni e opzioni sul telefono) | OK, nessun errore di script (sulla prima versione delle pose). Dopo la correzione delle pose rifatti movimenti (colpo nuovo da solo a segno) e combattimento: OK |
| Export Android debug 0.28.0-m5 (versionCode 30) + `apksigner verify` + `aapt2 dump badging` | OK; non provato sul telefono |

## 02/10/2026 — D-048: via l'inclinazione laterale in curva

Girando con l'analogico il corpo non si inclina più di lato (era invertito e troppo marcato).

### Test realmente eseguiti (D-048)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 195/195 PASS, log pulito. Nuovo: in corsa il corpo ha la stessa inclinazione laterale con rotazione nulla, a destra e a sinistra |
| Suite e2e completa (movimenti, passo, nuoto, terza e prima persona, combattimento, aggancio, sessione, touch, sandbox, oggetti a terra, armeria, opzioni e opzioni sul telefono) | OK al primo colpo, nessun errore di script |
| Export Android debug 0.27.0-m5 (versionCode 29) + `apksigner verify` + `aapt2 dump badging` | OK; non provato sul telefono |

## 02/10/2026 — D-047: catene di combo per stile d'arma

Ogni arma ha uno stile: pugni rissa (raffica), spada equilibrio, lancia distanza (passo indietro e
stoccata), martello distruzione (onda larga), spadone slancio (+10% per leggero concatenato, fino
a +30%). Ogni punto della catena leggera ha il suo forte. Base per le statistiche alla Elden Ring.

### Test realmente eseguiti (D-047)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 194/194 PASS, log pulito. Nuovi: tabella catena leggera e forte per punto per ogni arma; slancio dello spadone (sale a 3, il finale lo usa, una catena nuova lo azzera); passo indietro della lancia |
| Suite e2e completa (movimenti, passo, nuoto, terza e prima persona, combattimento, aggancio, sessione, touch, sandbox, oggetti a terra, armeria, opzioni e opzioni sul telefono) | Prima corsa: tutto OK tranne movimenti: la raffica dei pugni lanciata da sola non colpiva. Corretta (vedi D-047); seconda corsa di movimenti: la raffica colpiva da sola ma non dopo il montante (manichino sollevato), e il tornado dello spadone non è andato a segno (nella prima corsa, codice dello spadone identico, aveva colpito 4 volte: prova sensibile al tempo dei fotogrammi). Dopo la seconda correzione: movimenti OK (raffica nella catena e da sola 3 colpi, tornado 3 colpi, tutti i colpi nuovi a segno con le hitbox vere); combattimento e aggancio rifatti OK |
| Export Android debug 0.26.0-m5 (versionCode 28) + `apksigner verify` + `aapt2 dump badging` | OK; non provato sul telefono |

## 02/10/2026 — D-046: prova pilota Higgsfield, colpi dai video di riferimento

Catena `tools/mocap` (MediaPipe + adattamento sul rig vero) e tre colpi nuovi presi dai video:
rovescio orizzontale della spada dopo il giro, fendente saltato come forte dal rovescio, colpo a
terra del martello col sollevamento lento come forte dopo il montante. Il proprietario ha provato
l'APK e lo tiene.

### Test realmente eseguiti (D-046)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 191/191 PASS, log pulito. Nuovo: colpi dai video collegati alle catene (giro → rovescio → fendente; rovescio forte → fendente saltato; montante forte → colpo a terra) |
| `fit_poses.gd --selftest` | andata e ritorno sulle pose esistenti: 1–5° (un caso 16° sul busto) |
| Suite e2e completa (movimenti, passo, nuoto, terza e prima persona, combattimento, aggancio, sessione, touch, sandbox, oggetti a terra, armeria, opzioni e opzioni sul telefono) | OK, nessun errore di script. Movimenti: la prima corsa segnalava il rovescio dopo il giro "a vuoto" (il giro sbalza lontano il manichino); il primo giro della catena ora si ferma ai colpi che sbalzano (spinta ≥ 8) e la prova rifatta è OK; i tre colpi dai video lanciati da soli vanno a segno con le hitbox vere |
| Export Android debug 0.25.0-m5 (versionCode 27) + `apksigner verify` + `aapt2 dump badging` | OK; provato dal proprietario |

Crediti Higgsfield spesi: ~16 (4 video umani, 3 immagini dell'eroe, 1 video con l'eroe).

## 02/10/2026 — D-045: ritorno all'eroe basso, arti un poco più lunghi

Tornati altezza e testa grande dell'eroe del prototipo (~1,5 m coi capelli); braccia e gambe
~15% più lunghe a parità d'altezza (busto un poco più corto). Annullate per il corpo le versioni
snelle D-043 e D-044.

### Test realmente eseguiti (D-045)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 190/190 PASS, log pulito (altezza col ciuffo sotto 1,56 m, collo a .80) |
| Suite e2e completa (movimenti, passo, nuoto, terza persona, prima persona, combattimento, aggancio, sessione, touch, sandbox, oggetti a terra, armeria, opzioni e opzioni sul telefono) | OK, nessun errore di script; tutti i colpi del primo giro di ogni arma a segno |
| Tavola delle pose della spada | controllata a occhio: proporzioni del prototipo, arti appena più lunghi |
| Export Android debug 0.24.0-m5 (versionCode 26) + `apksigner verify` + `aapt2 dump badging` | OK; mai installato su un telefono |

## 30/09/2026 — D-044: eroe snello a metà strada, ~1,76 m

Con D-043 l'eroe era troppo alto: stesse proporzioni snelle, misure ×0,875, alto ~1,76 m coi
capelli (fra il chibi di ~1,5 m e i due blocchi).

### Test realmente eseguiti (D-044)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 190/190 PASS, log pulito (altezza col ciuffo fra 1,68 e 1,82 m, testa < 22% dell'altezza, anca oltre il 45%) |
| Suite e2e completa (movimenti, passo, nuoto, terza persona, prima persona, combattimento, aggancio, sessione, touch, sandbox, oggetti a terra, armeria, opzioni e opzioni sul telefono) | OK, nessun errore di script, tranne una volta la prima persona: "Lock gira la vista a 60°" con errore 10° al limite dopo 1 s (durante un colpo la vista segue più piano, D-040, e i colpi sono più lenti); controllo portato a 1,5 s e prova rifatta: errore 0°, OK. Movimenti: tutti i colpi del primo giro di ogni arma a segno |
| Export Android debug 0.23.0-m5 (versionCode 25) + `apksigner verify` + `aapt2 dump badging` | OK; mai installato su un telefono |

## 30/09/2026 — D-043: eroe snello e slanciato alto due blocchi

L'eroe è alto 1,99 m coi capelli: testa piccola, gambe e braccia lunghe e sottili, busto stretto.
Scheletro, passo, collisione (1,9 m), occhi, camere, prima persona e distanze dei colpi adeguati.

### Test realmente eseguiti (D-043)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 190/190 PASS, log pulito. Il test dello scheletro controlla ora altezza ≤ 2,02 (misurata 1,99), collo a 1,62, testa < 20% dell'altezza, anca oltre il 45%, sagoma entro 0,75 × 0,5 m |
| Suite e2e completa, terza corsa pulita (movimenti, passo, nuoto, terza persona, prima persona, combattimento, aggancio, sessione, touch, sandbox, oggetti a terra, armeria, opzioni e opzioni sul telefono) | OK, nessun errore di script. Le prime due corse hanno trovato: piedi "troppo larghi" col limite pensato per gambe da 0,3 m, montante del martello che mancava il manichino, affondi che si fermavano alla distanza dell'eroe chibi; corretti |
| Screenshot controllati | tavola delle pose (proporzioni), terza persona, prima persona (spada, pugni), nuoto, anteprima dello zaino con armatura |
| Export Android debug 0.22.0-m5 (versionCode 24) + `apksigner verify` + `aapt2 dump badging` | OK; mai installato su un telefono |

Non verificato: il passo delle gambe lunghe a occhio in movimento su un telefono (solo prove e
screenshot fermi); i manichini (1,55 m) ora sono più bassi dell'eroe.

## 30/09/2026 — D-042: spadone e martello più pesanti, terza persona fissa come l'isometrica

Spadone e martello: carica più lunga, colpo più secco, arresto sul colpo, spinta e scossa più
forti. Terza persona senza adattamento né "zoom dietro al player": inclinazione e distanza fisse,
ruota e zooma solo l'utente, i muri fra camera ed eroe si aprono coi raggi X; tolto il pulsante Auto.

### Test realmente eseguiti (D-042)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 190/190 PASS, log pulito. Tolti i tre test della terza persona adattiva (rientro davanti al muro, distanza per corsa/soffitto, camera alle spalle); nuovo: terza persona fissa (distanza 6,5 anche col muro dietro, non gira camminando, zoom ×2 → 3,25 m, rotazione di 45°, inclinazione mai sotto il minimo). Il test dei ritmi controlla anche il peso di spadone e martello |
| `tools/e2e_tps.gd` (nuova, tocchi veri) | OK: un tocco → terza persona, nessun pulsante Auto; camminando di lato 2 s la camera gira di 0,0° e la distanza resta 6,50 → 6,59 m; due dita → zoom 2,5, camera a 2,60 m; muro di pietra fra camera ed eroe → camera a 6,47 m (non si avvicina), raggi X al 100% |
| Suite e2e completa (terza persona, movimenti, prima persona, combattimento, aggancio, sessione, touch, sandbox, passo, oggetti a terra, armeria, nuoto, opzioni e opzioni sul telefono) | OK, nessun errore di script. Martello `swing, upswing, slam` e spadone `sweep, return, cleave` tutti a segno, forti a segno |
| Export Android debug 0.21.0-m5 (versionCode 23) + `apksigner verify` + `aapt2 dump badging` | OK; mai installato su un telefono |

Non verificato: la sensazione di peso dei colpi e la terza persona fissa su un telefono vero.

## 30/09/2026 — D-041: via i riquadri in alto, lancia dritta anche in terza persona, danno solo di punta

Tolti dal gioco i riquadri in alto a sinistra (titolo con l'oggetto in mano e Diario). In terza
persona la lancia affonda dritta invece di spazzare, e ferisce solo con la punta di ferro.

### Test realmente eseguiti (D-041)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 192/192 PASS, log pulito. Nuovo: per ogni colpo di punta della lancia, scarto massimo dall'avanti < 12° e punta che avanza di oltre 0,5 m; sfere che feriscono tutte sulla testa della lancia |
| `tools/spear_probe.gd` (nuovo) | prima: la lancia girava da +36° a -47° durante il colpo; dopo: entro ±9° per stoccate, stoccata alta, infilzata, affondo, carica e stoccata in corsa |
| Suite e2e completa (movimenti, prima persona, combattimento, aggancio, sessione, touch, sandbox, passo, oggetti a terra, armeria, nuoto, opzioni e opzioni sul telefono) | OK, nessun errore di script. Lancia col solo danno di punta: catena `thrust, thrust2, rise, impale` tutta a segno, infilzata su due in fila [1, 1] |
| Screenshot controllati | lancia in isometrica: stoccata e stoccata alta dritte sul manichino; niente riquadri in alto |
| Export Android debug 0.20.0-m5 (versionCode 22) + `apksigner verify` + `aapt2 dump badging` | OK; mai installato su un telefono |

Non verificato: come si legge l'affondo della lancia in terza persona su un telefono vero.

## 30/09/2026 — D-040: lancia solo di punta, prima persona più piccola a destra, camera più calma, colpi meno frenetici

La lancia non taglia più: stoccata, stoccata col passo, stoccata alta, infilzata; ramo forte
affondo in avanzata. Braccio e oggetto in prima persona più piccoli e a destra. Scossa della
camera dimezzata, camera che segue morbida negli affondi e non gira da sola mentre si colpisce.
Tutti i colpi più lenti (carica, rientro, catena).

### Test realmente eseguiti (D-040)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 191/191 PASS, log pulito. Nuovo: la camera segue morbida un affondo, raggiunge l'eroe, salta subito su un teletrasporto, scossa dimezzata. Il test della lancia ora controlla che ogni colpo sia di punta e perforante; la catena della lancia è premuta a 0,4 s (il ritmo nuovo) |
| Suite e2e completa (prima persona, movimenti, combattimento, aggancio, sessione, touch, sandbox, passo, oggetti a terra, armeria, nuoto, opzioni e opzioni sul telefono) | OK, nessun errore di script. Movimenti: tutti i colpi del primo giro di ogni catena a segno anche col ritmo più lento; lancia `thrust, thrust2, rise, impale`; infilzata su due in fila [1, 1] |
| Screenshot controllati | prima persona (spada, pugni, piccone) più piccola e a destra; lancia: stoccata e stoccata alta di punta |
| Export Android debug 0.19.0-m5 (versionCode 21) + `apksigner verify` + `aapt2 dump badging` | OK; mai installato su un telefono |

Non verificato: la sensazione del ritmo nuovo e della camera su un telefono vero; l'affondo in
avanzata (`drive`) non ha uno screenshot (solo il test che è di punta e perforante).

## 30/09/2026 — D-039: pugni con la forma della presa, zoom a due dita, armi a voxel più grandi, attrezzi senza combo

In prima persona a mani nude le braccia hanno la forma della presa e fanno i colpi dei pugni;
lo zoom a due dita parte anche se il primo dito cade nella zona dello stick; spada, spadone,
lancia, martello, piccone, ascia e pala sono ora a cubetti come il mondo e più grandi in tutte
le camere (scala 0,72 → 1,2; in prima persona ancora ×1,35); ascia e piccone ripetono un solo
colpo; tolta la presa a due mani.

### Test realmente eseguiti (D-039)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 190/190 PASS, log pulito. Nuovi: pinch che parte dalla zona dello stick, pinch che annulla lo scavo appena iniziato, stick in uso che non diventa pinch, attrezzo che ripete sempre lo stesso colpo; tolto il test della mano sinistra sull'impugnatura |
| Suite e2e completa (prima persona, sessione, aggancio, combattimento, touch, sandbox, passo, oggetti a terra, armeria, nuoto, opzioni e opzioni sul telefono, movimenti) | OK, nessun errore di script, con le armi alla scala nuova (i colpi del moveset prendono ancora i manichini) |
| Screenshot controllati | prima persona: spada a cubetti, pugni, piccone; isometrica: spada di ferro, martello, spadone, rastrelliera dell'armeria |
| Export Android debug 0.18.0-m5 (versionCode 20) + `apksigner verify` + `aapt2 dump badging` | OK; mai installato su un telefono |

Non verificato: pinch su un telefono vero (i test simulano i tocchi), leggibilità delle armi sullo
schermo del telefono.

## 30/09/2026 — D-038: prima persona con le sole braccia dritte e l'oggetto in mano

In prima persona il corpo dell'eroe non si vede più (resta l'ombra); si vedono solo le braccia
dritte e la mano con l'oggetto impugnato, animate dai colpi.

### Test realmente eseguiti (D-038)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 187/187 PASS, log pulito (il test della prima persona ora controlla che tutte le mesh del corpo siano "solo ombra" e che si veda il braccio con l'oggetto, e che in isometrica tutto torni visibile) |
| `tools/e2e_fps.gd` | OK, con due controlli nuovi: pugni → due braccia; piccone → un braccio con l'attrezzo |
| Suite e2e completa (prima persona, sessione, aggancio, combattimento, touch, sandbox, passo, oggetti a terra, armeria, nuoto, opzioni e opzioni sul telefono, movimenti) | OK, nessun errore di script (corsa completa con la versione "solo mano"; dopo braccia e braccia dritte, che cambiano solo `FirstPersonView`, rifatti test ed `e2e_fps`) |
| Export Android debug 0.17.0-m5 (versionCode 19) + `apksigner verify` | OK; mai installato su un telefono |

## 30/09/2026 — D-037: via tutto il sistema di magia, camera in prima persona

Tolta la magia in ogni sua parte (codice, interfaccia, pergamene, statistiche, pose, audio,
effetti, luci e vento degli shader, test); il pulsante Lock prende il posto del pulsante Magia.
Nuova camera in prima persona: terzo stato del pulsante camera.

### Test realmente eseguiti (D-037)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 187/187 PASS, log pulito (tolti i test della magia, delle zolle di terra, della pergamena, delle strutture magiche nel salvataggio e del dardo col Lock; nuovi: prima persona della camera, prima persona nel gioco; il test dei pulsanti sul telefono ora controlla tutti i pulsanti e il Lock) |
| `tools/e2e_fps.gd` (nuova, tocchi veri) | OK: due tocchi su camera → prima persona, mirino e testa nascosta, trascinare gira lo sguardo (50°), lo stick avanti cammina dove si guarda (7 m, allineamento 1,00), il corpo guarda dove guarda la camera, i colpi prendono il manichino nel mirino, Lock gira la vista su un bersaglio a 60° (errore 1°), sguardo in basso, terzo tocco → isometrica con la testa |
| `e2e_session`, `e2e_lockon`, `e2e_combat`, `e2e_touch`, `e2e_sandbox`, `e2e_walk`, `e2e_drop`, `e2e_armory`, `e2e_swim`, `e2e_options` (e `--phone`), `e2e_moveset` | OK, nessun errore di script. La prima corsa di `e2e_options` ha trovato un errore vero (la conferma di "Nuovo seme" usava un avviso tolto insieme alla magia): corretto e rifatto |
| Export Android debug 0.16.0-m5 (versionCode 18) + `apksigner verify` + `aapt2 dump badging` | OK; mai installato su un telefono |

Non verificato: la prima persona su un telefono vero (sensibilità del trascinamento, mal di
movimento), FPS su telefono. Il gioco ora non ha suoni (l'unico audio era quello della magia).

## 29/09/2026 — D-036: prima revisione dell'esperienza del giocatore

- HUD con identità visiva comune a menu, zaino e barra rapida; telemetria visibile solo
  negli strumenti sviluppatore. Indicazioni di interazione, raccolta e notifiche brevi.
- Icone vettoriali per oggetti e azioni, con etichette, quantità, rarità e usura conservate;
  layout di pausa compatto per schermi ad alta densità.
- Pausa con diario, comandi, impostazioni persistenti, salvataggio e ritorno al campo.
  Input pendenti azzerati quando si entra nei pannelli o si perde il focus.
- Otto obiettivi introduttivi basati su azioni riuscite, salvati con il mondo e compatibili
  con le partite precedenti; nessuna ricompensa duplicabile e nessun blocco dell'esplorazione.
- Interazioni con verifica centralizzata di portata e linea libera. Salto con buffer di
  120 ms, tolleranza al bordo di 100 ms e una sola attivazione per pressione.
- Movimento ridotto disattiva scosse e impulsi di campo visivo; impostazioni audio,
  dettaglio, suggerimenti e disposizione mancina accessibili senza aprire i comandi tecnici.

Verifiche: Godot 4.7.2, **229 test unitari/integrati, 0 falliti**; import senza errori
di script; `tools/e2e_session.gd` verifica tocchi attraverso il viewport, pausa effettiva,
contenimento dei pulsanti, impostazioni, annullamento del tocco, salvataggio e ritorno
al gioco. Verificati anche i quattro menu a scala telefono 1,83 (pulsanti di almeno
48 dp, senza sovrapposizioni) e il disegno di tutte le categorie di icone del catalogo.
Il runtime headless emette un avviso di ambiente su `/proc/self/exe`;
nessun errore GDScript. Non è stato usato `tools/run_tests.sh` come gate pulito, perché
quel wrapper considera fallimento anche questo avviso di ambiente.

Limiti: nessuna ispezione visiva renderizzata, export Android o prova su telefono in questa
sessione. Prima del rilascio servono una prova visiva delle pagine a densità mobile,
playtest del movimento e del percorso iniziale, profiling e bilanciamento. Combattimento
contro nemici, progressione lunga e qualità degli asset restano lavoro successivo.

### Verifica all'integrazione (D-036, 29/09/2026)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 229/229 PASS, log pulito (l'avviso `/proc/self/exe` citato sopra qui non compare) |
| `tools/e2e_session.gd` con rendering vero (xvfb) | OK: pausa, pagine, impostazioni, tocco annullato, salvataggio, ripresa, scala telefono 1,83; nuovo controllo: l'indicazione dell'oggetto vicino non copre i comandi touch |
| Suite e2e completa (sessione, aggancio, magia, combattimento, touch, sandbox, passo, oggetti a terra, armeria, nuoto, opzioni, movimenti, magia e opzioni sul telefono) | OK, nessun errore di script. Prima delle correzioni `e2e_armory`, `e2e_options` e `e2e_options --phone` fallivano (pulsante ⚙ nascosto) |
| Export Android debug 0.15.0-m5 (versionCode 17) + `apksigner verify` + `aapt2 dump badging` | OK; mai installato su un telefono |

Non verificato: pausa per perdita del focus e tasto indietro su un telefono vero; leggibilità
dell'HUD alla densità reale di un telefono (solo la scala dp simulata).

## Stato corrente: M5 — Sandbox persistente, equipaggiamento RPG, magia ampliata (come RMNDWN), eroe del prototipo · completata (senza prova su telefono)

Sessione del 28/09/2026 (seguito). Richieste del proprietario dopo la prova: oggetti gettati che
si possano riprendere (5 minuti), selezione delle magie più chiara, hitbox/hurtbox legate alle
armi e ai pugni, ritorno all'eroe del prototipo (più piccolo) con un passo migliore tenendo le
animazioni di combattimento (D-028).

Seguito del 28/09/2026 (D-035): tolta la mira alla Brawl Stars di D-034; Lock sul bersaglio con
triangolo rosso 3D, camminata laterale, colpi d'arma, pugni e magie che seguono il bersaglio
agganciato; magie d'acqua più chiare e gocce più grandi.

### Test realmente eseguiti (D-035)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 219/219 PASS, log pulito (tolti i 4 test della mira; nuovi: scelta e sgancio del Lock, sgancio automatico, colpo di spada/pugni/lancia verso il bersaglio agganciato a 70°, carica che segue il bersaglio che si sposta, dardo che curva verso il bersaglio agganciato, pulsante Lock dentro lo schermo su 4 schermi, acqua blu acceso) |
| `tools/e2e_lockon.gd` (nuova, tocchi veri) | OK: Lock aggancia il manichino a 65°, triangolo visibile, sguardo sul bersaglio durante 1,2 s di camminata laterale (errore massimo 4°), 3 colpi a segno con il manichino a 70° di lato, magia a segno (4 colpi), sgancio col pulsante, triangolo nascosto |
| `e2e_magic` (e `--phone`), `e2e_combat`, `e2e_touch`, `e2e_sandbox`, `e2e_walk`, `e2e_drop`, `e2e_armory`, `e2e_swim`, `e2e_options` (e `--phone`), `e2e_moveset` | OK, nessun errore di script |
| Export Android debug 0.14.0-m5 (versionCode 16) + `apksigner verify` + `aapt2 dump badging` | OK; mai installato su un telefono |

Non verificato: sensazione del Lock e della camminata laterale su un telefono vero; FPS su telefono.

Seguito del 28/09/2026 (D-034): magie lanciate alla Brawl Stars (pulsante tenuto e direzionato,
fascia, cerchio o anello a terra), tutte le magie note per la prova, ritmi e moveset per arma
(spadone e martello più lenti, lancia perforante con l'infilzata), passo delle gambe nei colpi.

### Test realmente eseguiti (D-034)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 218/218 PASS, log pulito (nuovi: mira direzionata sul bersaglio di lato, tocco secco a mira automatica, punto delle aree alla distanza trascinata, pulsante Magia come joystick, lancia perforante, ritmi per arma, passo d'attacco con piede piantato) |
| `tools/e2e_magic.gd` completo | OK: 21 magie, una su due mirata trascinando il pulsante (fascia o cerchio visibili, spariti al rilascio), 85 colpi, nessun errore di script |
| `tools/e2e_magic.gd --phone` | OK |
| `tools/e2e_moveset.gd` (nuove voci: passo e infilzata) | OK: tutte le catene e i forti a segno; piede del colpo avanti di 0,20–0,38 m (prima della correzione fino a 1,2 m); infilzata su due manichini in fila: [1, 1] |
| `e2e_combat`, `e2e_touch`, `e2e_sandbox`, `e2e_walk`, `e2e_drop`, `e2e_armory`, `e2e_swim`, `e2e_options`, `e2e_options --phone` | OK, nessun errore di script |
| Export Android debug 0.13.0-m5 (versionCode 15) + `apksigner verify` + `aapt2 dump badging` | OK; mai installato su un telefono |

Non verificato: sensazione del joystick della magia su un telefono vero; FPS su telefono.
Da ricordare: `GameRoot.TEST_ALL_SPELLS` è acceso solo per questa prova.

Seguito del 28/09/2026 (D-033): opzioni come pannello modale che entra nel telefono, mira
assistita leggera, catene che vanno a segno con ogni arma, forte della spada a terra.

### Test realmente eseguiti (D-033)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 211/211 PASS, log pulito (nuovi: mira assistita leggera, correzione massima 20°, colpo in coda fino al seguito, catena di pugni a segno) |
| `tools/e2e_options.gd` e `--phone` (nuova) | OK: pannello dentro lo schermo, stick spento col pannello aperto, un tocco su Nuovo seme non rigenera, chiusura con Opzioni, Chiudi e tocco fuori; nessun fotogramma bloccato |
| `tools/e2e_moveset.gd` (nuova, hitbox vere) | Prima: 9 colpi del primo giro a vuoto. Dopo: OK, tutte le catene e tutti i forti a segno, salto 0 m |
| `e2e_combat`, `e2e_touch`, `e2e_sandbox`, `e2e_walk`, `e2e_drop`, `e2e_swim`, `e2e_magic` | OK, nessun errore di script |
| `tools/e2e_armory.gd` | OK dopo aver spostato il tocco "sul mondo" fuori dal pannello modale (prima toccava il centro dello schermo, ora dentro il pannello) |
| Export Android debug 0.12.0-m5 (versionCode 14) + `apksigner verify` | OK; mai installato su un telefono |

Seguito del 28/09/2026 (D-032): terra come il reticolo di granelli di RMNDWN (dopo una prova con
cubetti solidi che non è piaciuta) con i Coni gemelli, accumulo della sostanza nel palmo al posto
del glifo, colpi continui di fuoco e acqua, numeri del danno, barra delle magie che entra nel
telefono.

### Test realmente eseguiti (D-032)
| Prova | Esito |
|---|---|
| `tools/run_tests.sh` | 208/208 PASS, log pulito (nuovi: barra delle magie e barra rapida dentro lo schermo e premibili su 4 schermi, fra cui 2400×1080 a 440 dpi; reticolo della terra: composizione, blocco scuro, rottura, mucchio, sgretolamento, rampa; coni gemelli; diluvio al contatto e poi continuo; aria a colpo singolo; bruciatura che manda colpi) |
| `tools/e2e_magic.gd` completo | OK: 21 magie col pulsante, 73 colpi, nessun errore di script |
| `tools/e2e_magic.gd --phone` (scala dp di un telefono) | OK: tutti e 5 gli slot premuti |
| `tools/e2e_combat.gd`, `e2e_touch`, `e2e_sandbox`, `e2e_walk`, `e2e_drop`, `e2e_armory`, `e2e_swim` | OK, nessun errore di script (la prima corsa di `e2e_touch` è caduta perché partita a metà di una modifica; rifatta a codice finito: OK) |
| Export Android debug 0.11.0-m5 (versionCode 13) + `apksigner verify` + `aapt2 dump badging` | OK; minSdk 24, targetSdk 36; mai installato su un telefono |

Non verificato: FPS su telefono (il reticolo arriva a ~3200 granelli ricostruiti a ogni frame);
schermo vero di un telefono (solo la scala dp simulata).

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
