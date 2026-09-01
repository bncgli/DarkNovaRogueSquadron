# TASK-018: Miglioramenti Applicazione ShipBuilder

## Descrizione
Potenziamento dell'applicazione `ShipBuilder` (`@Applications/ShipBuilder`) per migliorare l'esperienza utente nella gestione dei file e nella selezione degli asset.

## Obiettivi
- Implementare un sistema di gestione file pi? robusto nel menu File.
- Semplificare l'inserimento dei path per le mesh dello scafo tramite dialoghi nativi.

## Criteri di Accettazione
- [ ] **Menu File (`ship_builder.gd`)**:
    - [ ] Aggiunta opzione "Nuovo" per resettare la blueprint corrente.
    - [ ] Miglioramento "Salva" e "Carica": implementare l'uso di `FileDialog` per consentire la scelta del percorso e del nome file, invece di usare un path predefinito/fisso.
- [ ] **Hull Inspector**:
    - [ ] In `_rebuild_ship_inspector`, aggiungere un `Button` accanto alla `LineEdit` di `ship_mesh_path`.
    - [ ] Il bottone deve aprire un `FileDialog` filtrato per file mesh (es. `.tres`, `.obj`, `.scn`) che popoli automaticamente la `LineEdit` al termine della selezione.

## Dettagli Tecnici
- Utilizzare i nodi `FileDialog` integrati in Godot.
- Assicurarsi che le operazioni di salvataggio/caricamento gestiscano correttamente le estensioni dei file blueprint.
- Il reset per l'opzione "Nuovo" deve svuotare la `ShipBlueprint` corrente e resettare il canvas.

## Step by Step Implementation
1. Modificare la UI del menu File in `ship_builder.gd`.
2. Collegare le azioni del menu a nuove funzioni che istanziano e configurano `FileDialog`.
3. Aggiornare `_rebuild_ship_inspector` per includere il bottone di selezione mesh.
4. Implementare la logica di callback per il `FileDialog` della mesh scafo.
