# D-036 — Esperienza del giocatore

Questa revisione rende leggibili i sistemi esistenti e corregge le interazioni che possono
confondere o intrappolare il giocatore. Conserva il mondo dipinto e i moveset
esistenti (le magie sono state tolte dopo, in D-037). Non dichiara raggiunto il traguardo G o una qualità di rilascio.

## Interfaccia

`SessionOverlay` presenta HUD e pagine Pausa, Diario, Impostazioni e Comandi.
`GamePalette` condivide colori e pannelli arrotondati con inventario e barra rapida.
`GameIcons` disegna silhouette vettoriali per azioni, blocchi, attrezzi, armi, armature,
stazioni e materiali; le icone sostituiscono le sigle dentro gli slot, conservando
quantità, usura e indicazione di rarità. I pulsanti conservano etichette testuali.
Gli stili sono riutilizzati, senza creare una risorsa per ogni slot a ogni frame.
Il menu accetta tocchi nativi e mouse tramite l'emulazione touch già attiva nel progetto;
frecce, Tab e Invio permettono di navigare i menu. Esc/P riprendono dalla pagina Pausa;
nelle pagine secondarie tornano indietro. Il tocco annullato non attiva azioni.
Su schermi ad alta densità, le pagine passano a un layout più corto a due colonne,
così i pulsanti conservano 48 dp di altezza nella simulazione telefono a scala 1,83.
Il concept generato durante la sessione ha guidato palette, gerarchia e silhouette;
è un riferimento estetico, non uno screenshot della build né un nuovo asset del mondo.

Il gioco entra in pausa alla perdita di focus. Zaino e pausa azzerano input mantenuti e
azioni in coda; gli effetti già lanciati restano nello stato di simulazione. Gli strumenti
sviluppatore sono raggiungibili dal menu o con l'argomento `--dev`.

## Meccaniche

`ExpeditionJournal` registra otto obiettivi, anche fuori ordine. Movimento, raccolta,
craft, costruzione, colpi riusciti, schivata, falò e tesori alimentano contatori limitati.
La notifica di completamento scatta una volta. Il dizionario `journal` è opzionale nel
salvataggio versione 1: le partite precedenti iniziano con un diario vuoto. La generazione
di un nuovo mondo azzera diario e checkpoint; caricare una partita ne ripristina il diario.

`SandboxController.can_use` è la regola comune per distanza e linea libera, usata da tap,
clic destro e interazione contestuale. `F` e il pulsante contestuale usano l'oggetto
raggiungibile più vicino. Non si aprono forzieri lontani o dietro un muro.

`PlayerMotor` riconosce il fronte di pressione del salto. Buffer di 120 ms e tolleranza
al bordo di 100 ms aiutano il controllo senza aggiungere un doppio salto. Il salto in
acqua resta nello stesso sistema fisico, ma richiede una nuova pressione.

## Verifica riproducibile

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tools/e2e_session.gd
# Con display e renderer disponibili, cattura la pausa:
godot --path . --script res://tools/e2e_session.gd -- --out=/tmp/session.png
```

I test aggiunti coprono salvataggio e validazione dei contatori, completamenti unici,
buffer/tolleranza/salto tenuto, portata e muri, input nei pannelli e registrazione della
costruzione. La prova di flusso passa gli eventi al viewport in coordinate locali, così
la prova headless non dipende da una finestra del sistema operativo.

Prima di integrare per una release, controllare su desktop e telefono: leggibilità delle
indicazioni lunghe, dimensione fisica dei bersagli touch, mancini, combinazione multi-touch,
perdita/ripresa del focus e compatibilità con un salvataggio reale. La verifica headless
non sostituisce l'ispezione visiva o il playtest.
