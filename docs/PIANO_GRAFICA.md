# Piano grafico: dalla resa attuale alla reference "diorama all'ora d'oro"

Reference del proprietario (05/10/2026): piazza di pietra a lastre in vista isometrica, eroe con
l'elmo di ferro, avversario, manichino d'allenamento con l'armatura, armeria, colonne, stendardi,
lanterne, casse, fiori. Questo documento confronta la resa di oggi con la reference, riassume la
ricerca e propone le fasi di lavoro, in ordine di guadagno visivo per costo.

## 1. Cosa vediamo nella reference

| Aspetto | Reference | IsoTerra oggi (0.38.0-m5) |
|---|---|---|
| Risoluzione | Immagine nitida, i blocchi hanno dettaglio dentro la faccia | Render target 640x360 ingrandito senza filtro (`rt_height` 360, `Screen` nearest): pixel grandi, poco dettaglio |
| Luce | Sole basso e caldo (ora d'oro), ombre lunghe; le zone in ombra sono fredde ma leggibili | Sole alto (pitch fino a 74°), luce posterizzata a 3 bande (0,56/0,76/1,0), ombre corte e azzurrine, granulose |
| Ombre | Morbide, con penombra; macchie di luce attraverso le foglie in primo piano | Mappa d'ombra direzionale con valori predefiniti (niente blur), distanza 140 m, `shadow_strength` 0,84 |
| Occlusione ambientale | Scura dove le cose toccano terra (piedi, basi, angoli di muro, fughe) | AO per vertice solo sui blocchi (0-3); attori e oggetti senza AO |
| Materiali | Lastre di pietra ognuna di tono diverso, crepe, bordi consumati e smussati, fughe con erba e muschio, terra e foglie | Atlante 16x16 px generato in codice (`proto_textures.gd`); nell'arena il marmo e' crema uniforme con fughe nere nette |
| Smusso dei blocchi | Gli spigoli prendono la luce (bordo chiaro) | Bordo "Edges" in post dalla profondita' (convesso x1,22, concavo scuro), solo in iso |
| Atmosfera | Profondita' di campo (foglie in primo piano sfocate), bagliore delle lanterne, gradazione calda, vignettatura leggera | Niente glow, DOF o tonemapping: uscita lineare; gradazione ombre/luci leggera, vignettatura solo di notte |
| Oggetti di scena | Stendardi, lanterne accese, casse, barili, fiori, edera sulle colonne, cespugli | Colonne bianche lisce; poco arredo |
| Personaggi | Stesso stile voxel, luce morbida, ombra a contatto | Stessa luce a bande dei blocchi, nessuna AO, ombra granulosa |

L'immagine di riferimento non e' pixel-art: la scelta piu' importante e' rinunciare (o rendere
opzionale) l'ingrandimento a pixel grandi. Tutto il resto si vede solo se la risoluzione lo
permette.

## 2. Vincoli tecnici (ricerca)

- **Renderer Mobile di Godot 4**: niente SSAO, SSIL, SSR, SDFGI, VoxelGI, nebbia volumetrica
  ([documentazione dei renderer](https://github.com/godotengine/godot-docs/blob/master/tutorials/rendering/renderers.rst),
  [VoxelGI](https://docs.godotengine.org/en/4.2/tutorials/3d/global_illumination/using_voxel_gi.html)).
  Ci sono invece **glow** (filtro bilineare su mobile) e **profondita' di campo** (in fragment
  shader) ([ambiente e post-processing](https://docs.godotengine.org/en/4.4/tutorials/3d/environment_and_post_processing.html)).
  L'occlusione va quindi cotta nei vertici o fatta con un post nostro sulla profondita'
  ([letture della profondita' e post avanzato](https://docs.godotengine.org/es/4.3/tutorials/shaders/advanced_postprocessing.html)).
- **Ombre morbide**: la luce direzionale ha "Blur" (penombra piu' stabile, grana del filtro piu'
  visibile) e "Angular Distance" (PCSS, ombre che si allargano lontano dall'oggetto, costose).
  Su GPU deboli si consiglia l'atlante a 2048 invece di 4096
  ([luci e ombre](https://docs.godotengine.org/en/4.4/tutorials/3d/lights_and_shadows.html),
  [guida PSSM/PCSS](https://godotlab.org/en/tutorials/3d-lights-and-shadows)).
- **AO dei voxel**: la tecnica di Minecraft ("smooth lighting") calcola l'occlusione di ogni
  vertice guardando solo gli 8 cubi attorno alla faccia: e' indipendente dalla vista e costa
  zero in gioco ([0fps, AO per mondi alla Minecraft](https://0fps.net/2013/07/03/ambient-occlusion-for-minecraft-like-worlds/)).
  Noi la abbiamo gia' (0-3 per vertice), va estesa e resa piu' marcata.
- **Diorama / HD-2D**: l'effetto "plastico" nasce dall'insieme luce dinamica, AO, profondita' di
  campo stile tilt-shift, bloom e vignettatura ([HD-2D](https://en.wikipedia.org/wiki/HD-2D),
  [Octopath Traveler II e Unreal](https://www.unrealengine.com/en-us/developer-interviews/octopath-traveler-ii-builds-a-bigger-bolder-world-in-its-stunning-hd-2d-style)).
- **Luce stilizzata**: Half Lambert (luce che "avvolge"), rampa di colore invece di bande nette,
  ombre di tinta complementare e luce di contorno: la ricetta di Team Fortress 2
  ([Valve, Stylization with a Purpose](https://cdn.steamstatic.com/apps/valve/2008/GDC2008_StylizationWithAPurpose_TF2.pdf),
  [modelli di luce](https://seasidestudios.gitbook.io/seaside-studios/3d-shader/light-models)).
- **Texture di pietra procedurali**: Voronoi per le lastre (distanza fra primo e secondo punto =
  fughe e crepe), fbm per l'usura, identificativo della cella per variare il tono di ogni lastra
  ([shader procedurali ripetibili](https://github.com/tuxalin/procedural-tileable-shaders),
  [sintesi di texture procedurali](https://pixelartcode.uk/posts/creative-coding/2026-04-23-procedural-texture-synthesis)).

## 3. Fasi

Ogni fase e' una decisione D-xxx con APK, foto prima/dopo nella stessa inquadratura della
reference e misura dei millisecondi per fotogramma sul telefono.

### F0 — Banco di prova (prima di toccare la grafica)
- Strumento `tools/look_preview.gd`: arena, ora d'oro, iso alla stessa inquadratura della
  reference, eroe in ferro, avversario, manichino, armeria; foto con e senza ogni effetto.
- Misura del costo: contatore ms/fotogramma nel pannello sviluppatore e tre livelli di qualita'
  (Basso/Medio/Alto) in Opzioni, cosi' ogni effetto ha il suo interruttore.

### F1 — Risoluzione e nitidezza (il salto piu' grande)
- Render target fino a 540 e 720 righe oltre a 270/360/450, e un'opzione "nitido" a risoluzione
  piena dello schermo.
- Ingrandimento lineare (o FSR) al posto di nearest quando non si e' in modalita' pixel;
  antialiasing (MSAA 2x o FXAA) sui bordi dei blocchi.
- Il modo "pixel" attuale resta come opzione.
- Contorni ed "Edges" riscalati: oggi sono pensati per pixel grandi e a 720 righe sarebbero linee
  sottilissime.

### F2 — Luce dell'ora d'oro e ombre
- Preset "ora d'oro" del ciclo del giorno: sole a 25-35° di altezza e luce (1,0, 0,78, 0,52);
  ombre fredde ma chiare, tinta ambiente (0,42, 0,48, 0,66); luce di rimbalzo calda dal terreno.
  Si puo' fermare l'ora (come in arena) o rallentarla attorno al tramonto.
- Luce a rampa morbida (Half Lambert + rampa di colore) al posto delle 3 bande nette.
- Mappa d'ombra: atlante 4096 (2048 sul livello Basso), distanza massima ridotta a quella che
  inquadra la camera iso (~40 m) per avere piu' definizione, blur 1,5-2, bias regolati; PCSS
  leggero (Angular Distance) solo sul livello Alto.
- Ombre di contatto sotto personaggi e oggetti (macchia scura morbida), indipendenti dalla mappa.
- Macchie di luce attraverso le foglie: motivo procedurale nel termine d'ombra vicino agli alberi
  (gia' oggi c'e' l'ombra procedurale delle nuvole da cui partire).

### F3 — Materiali e texture dei blocchi
- Atlante a 32x32 px per faccia (oggi 16) o colore procedurale in shader a risoluzione piena.
- Pietra a lastre (pavimento dell'arena): Voronoi per le lastre irregolari, tono diverso per ogni
  lastra (hash dell'ID della cella), crepe, bordi smussati e consumati, fughe scure con ciuffi di
  erba e muschio. Marmo, pietra, terra e legno con la stessa cura.
- Variazione per blocco (hash della posizione nel mondo) per rompere la ripetizione.
- Smusso finto: bordo chiaro sugli spigoli della faccia calcolato dalla distanza dal bordo in UV
  (sostituisce in parte il bordo dalla profondita' del post).

### F4 — Occlusione ambientale
- AO per vertice dei blocchi con curva piu' marcata e colorata (ombre fredde, non grigie).
- AO anche per attori e oggetti: facce in basso piu' scure nel MeshKit e cerchio d'ombra a
  contatto col suolo.
- Opzionale sul livello Alto: SSAO nostro in post sulla profondita' (mezza risoluzione, 8
  campioni), perche' quello di Godot non c'e' sul Mobile.

### F5 — Atmosfera e post-processing
- Tonemapping filmico (oggi Linear) e gradazione con LUT calda (luci ambra, ombre verde-azzurre).
- Glow sulle superfici emissive: lanterne, torce, magia del fuoco, gemme.
- Profondita' di campo "tilt-shift": a fuoco il piano del giocatore, sfocati il primo piano e il
  fondo, come la reference (vegetazione davanti sfocata).
- Vignettatura leggera anche di giorno; foschia lieve sulla distanza.

### F6 — Oggetti di scena e vegetazione dell'arena
- Stendardi, lanterne accese con luce puntiforme, casse e barili, cespugli fioriti, edera sulle
  colonne, ciuffi d'erba nelle fughe e lungo il bordo del ring.
- Prima le reference su Higgsfield, poi la ricostruzione in codice con MeshKit come per le armi.

### F7 — Personaggi
- Shader degli attori con la stessa luce a rampa, luce di contorno leggera e AO nelle pieghe;
  ombra morbida.

## 4. Ordine consigliato e costo

| Fase | Guadagno visivo | Costo sul telefono | Rischio |
|---|---|---|---|
| F1 risoluzione | Altissimo | Medio-alto (piu' pixel) | Contorni da riscalare |
| F2 luce e ombre | Altissimo | Basso-medio | Regolare bias e acne |
| F3 materiali | Alto | Basso (shader) | Tempo di lavoro |
| F5 post | Alto | Medio (glow, DOF) | Va misurato |
| F4 AO | Medio | Basso (vertici), alto (SSAO) | SSAO solo su Alto |
| F6 oggetti | Medio | Basso | Tempo di modellazione |
| F7 personaggi | Medio | Basso | — |

Proposta: F0 → F1 → F2 → F3 → F5 → F4 → F6 → F7, con un APK a ogni fase.

## 5. Decisioni da prendere

1. **Pixel-art o no?** La reference non e' pixel-art. Proposta: la nuova resa diventa quella
   predefinita e il modo pixel attuale resta come opzione.
2. **Telefono di riferimento** per il budget dei millisecondi: serve sapere il modello per fissare
   il livello predefinito (Medio o Alto).
3. **Ora del giorno nell'arena**: ora d'oro fissa come nella reference, o il ciclo del giorno
   rallentato attorno al tramonto?
