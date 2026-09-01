# TASK-019: Nuove Funzionalit? e Bug Fix Sublayer Editor

## Descrizione
Introduzione di funzionalit? avanzate nell'editor dei sublayer e risoluzione di bug critici relativi alla manipolazione delle stanze.

## Obiettivi
- Implementare la generazione procedurale di base per le navi.
- Gestire le zone di ricarica dei droni.
- Correggere bug nella creazione delle stanze.

## Criteri di Accettazione
- [ ] **Generazione Casuale**:
    - [ ] Aggiunta di un bottone "Genera Random" nell'interfaccia dell'editor.
    - [ ] Algoritmo di generazione che crei una struttura di stanze e corridoi.
    - [ ] Vincolo: corridoi e condotti devono essere esclusivamente orizzontali o verticali, con angoli di 90 gradi (niente diagonali).
- [ ] **Zona Ricarica Drone**:
    - [ ] Nell'ispettore del "Spawn drone", aggiungere un `OptionButton` (dropdown) che elenchi le stanze disponibili.
    - [ ] La stanza selezionata deve essere designata come zona di ricarica.
    - [ ] Feedback Visivo: La zona di ricarica deve essere evidenziata sulla mappa con un bordo grafico specifico e distintivo.
- [ ] **Bug Fix Stanze**:
    - [ ] Risolvere il problema per cui, dopo aver selezionato il tipo di stanza durante la fase di disegno sul canvas, l'anteprima o la stanza appena creata sparisce.

## Dettagli Tecnici
- La generazione randomica deve interfacciarsi con la `ShipBlueprint` corrente.
- Per la zona di ricarica, aggiungere un campo `recharge_room_id` (o simile) nei dati di spawn del drone.
- Investigare lo stato del canvas durante il cambio di tipo stanza (probabile perdita di focus o reset errato dello stato di disegno).

## Step by Step Implementation
1. Aggiungere il bottone "Genera Random" alla UI dell'addon.
2. Implementare un algoritmo di "Random Walk" o "BSP" semplificato per la generazione a griglia.
3. Aggiornare l'ispettore di spawn drone per includere la selezione della stanza.
4. Modificare il codice di drawing del canvas per aggiungere il bordo speciale alla stanza di ricarica.
5. Debuggare il processo di creazione stanza in `ship_sublayer_editor.gd` per identificare la causa della sparizione post-selezione.
