# Task 003: Ship Sublayer Editor Improvements

## Descrizione
Migliorare l'usabilit? e le funzionalit? dell'editor della blueprint della nave (`ship_sublayer_editor`) e risolvere bug critici nella manipolazione delle stanze.

## File Coinvolti
- `addons/ship_sublayer_editor/ship_blueprint_canvas.gd`
- `addons/ship_sublayer_editor/ship_sublayer_editor.gd`

## Sotto-task
### 3a. Resize delle stanze tramite drag
Aggiungere handle interattivi agli angoli della stanza selezionata nel canvas dell'editor per permettere il ridimensionamento tramite trascinamento del mouse.

### 3b. Editing Flux & Modifiers
Aggiungere nell'interfaccia dell'editor (Inspector personalizzato o pannello laterale) la possibilit? di visualizzare e modificare il valore `flux` e la lista `flux_modifiers` della blueprint in modifica.

### 3c. Fix Room Dragging
Risolvere il bug per cui le stanze tornano alla posizione originale dopo essere state trascinate se le coordinate non vengono modificate manualmente nell'inspector. Lo spostamento tramite mouse deve aggiornare permanentemente la posizione nella risorsa.

### 3d. Drone Spawn Position
Aggiungere la possibilit? di visualizzare e spostare graficamente sul canvas il punto di ricarica del duct drone, che corrisponde alla propriet? `drone_spawn_pos` della blueprint.

## Criteri di Accettazione
- [ ] Le stanze possono essere ridimensionate trascinando i loro angoli.
- [ ] Lo spostamento delle stanze tramite drag aggiorna correttamente la risorsa e persiste.
- [ ] Il valore flux e i modificatori sono editabili direttamente dall'editor.
- [ ] La posizione di spawn del drone pu? essere impostata visivamente.
