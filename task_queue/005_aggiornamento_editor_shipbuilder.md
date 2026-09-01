# TASK-015: Aggiornamento Editor (ShipBuilder e Addon)

## Descrizione
Aggiornamento degli strumenti di editing (sia l'app in-game `ShipBuilder` che l'addon Godot `ship_sublayer_editor`) per allinearli alla nuova struttura dati e rimuovere i tool obsoleti.

## Obiettivi
- Pulizia dell'interfaccia utente dai componenti rimossi (snodi, cablaggi).
- Miglioramento dell'integrazione con il Database delle Stanze.
- Supporto alla gestione della mesh 3D e delle collisioni.
- Risoluzione di bug noti in `ShipBuilder`.

## Criteri di Accettazione
- [ ] Rimozione pulsanti/tool "Add Device", "Add Junction", "Add Conduit", "Add Damage" in entrambi gli editor.
- [ ] Integrazione `RoomDatabase.gd`:
    - [ ] Lista stanze predefinite funzionante.
    - [ ] Supporto per stanze custom con gestione device interni.
    - [ ] Calcolo automatico e visualizzazione del wattaggio totale della stanza nell'inspector.
- [ ] Campo selezione `ship_mesh_path` nell'inspector della nave.
- [ ] Implementazione logica per la generazione automatica della collision mesh dalla mesh 3D (se fattibile).
- [ ] Fix bug ShipBuilder:
    - [ ] Chiusura corretta delle finestre "Software" e "Drive Files".
    - [ ] Visualizzazione corretta nella lista Software (installati vs installabili).

## Dettagli Tecnici
- **UI Update**: Rimuovere i layer corrispondenti nel selettore di visibilit?.
- **Room Management**: Quando si seleziona una stanza, l'inspector deve mostrare una lista di device contenuti con possibilit? di aggiunta/rimozione.

## Step by Step Implementation
1. Rimuovere il codice UI obsoleto in `ship_sublayer_editor.gd` e `ship_builder.gd`.
2. Aggiornare l'Inspector per gestire l'array di dispositivi nelle stanze.
3. Implementare il selettore di file per la mesh della nave.
4. Debuggare e correggere la gestione delle finestre popup in `ShipBuilder`.
5. Implementare la logica di filtraggio per la lista software.
