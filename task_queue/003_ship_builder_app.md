# TASK-013: Sviluppo Applicazione Terminale ShipBuilder

## Descrizione
Sviluppare una nuova applicazione GodotOS chiamata 'ShipBuilder'. Si tratta di un tool del terminale per la creazione e modifica custom delle navi (ShipBlueprint) all'interno dell'ambiente operativo.

## Obiettivi
- Fornire un'interfaccia user-friendly per la progettazione delle navi direttamente in-game.
- Integrare la gestione dei software e dei file della nave nel processo di progettazione.
- Garantire la compatibilità con il sistema `ShipBlueprint` esistente.

## Criteri di Accettazione
- [ ] Creazione della directory `Applications/ShipBuilder/` con scena e script principali.
- [ ] Implementazione del pannello centrale a griglia per l'editing dei sublayer.
- [ ] Implementazione della barra laterale per il controllo della visibilità dei layer (Stanze, condotti, snodi, cablaggi, spawn drone, scafo, griglia, testo).
- [ ] Implementazione dell'Inspector sul lato destro per la modifica delle proprietà degli elementi.
- [ ] Implementazione della barra superiore con pulsanti per Software, Modifica Nave e Drive Files.
- [ ] Integrazione con `RoomDatabase`: selezione stanze da lista predefinita con applicazione automatica di dimensioni minime e dispositivi.
- [ ] Menu File funzionale per il Salvataggio e Caricamento di `ShipBlueprint` (.tres).
- [ ] Test suite automatizzata in `tests/test_ship_builder.tscn`.
- [ ] Registrazione dell'app nel `TerminalSoftwareManager`.

## Dettagli Tecnici

### UI & UX
L'interfaccia deve richiamare quella dell'editor plugin `addons/ship_sublayer_editor`:
- **Pannello Centrale**: Canvas 2D con griglia per il posizionamento e ridimensionamento degli elementi dei sublayer.
- **Layer Visibility (Sinistra)**: Lista verticale di checkbox per attivare/disattivare la visualizzazione di: Stanze, condotti, snodi, cablaggi, spawn drone, scafo, griglia, testo.
- **Inspector (Destra)**: Pannello che mostra i parametri dell'elemento attualmente selezionato nel canvas.
- **Toolbar Superiore**:
    - **Software**: Apre una sotto-finestra divisa in Marketplace (sinistra) e Software installati (destra), con pulsanti a freccia per il trasferimento. Le password devono essere oscurate.
    - **Drive Files**: Apre una sotto-finestra con un `Tree` per la navigazione dei file, supportando creazione, upload, eliminazione e riorganizzazione.
    - **Modifica Nave**: Bottoni per selezionare lo strumento di editing. Il comando "Aggiungi stanza" deve mostrare una lista di tipologie basata su `RoomDatabase.gd`.
- **Menu File**: Salva/Carica ShipBlueprint.

### Architettura
- **Standard**: Seguire `docs/APP_ARCHITECTURE_STANDARD.md`.
- **Tipo**: Applicazione del Terminale (Locale).
- **Directory**: `Applications/ShipBuilder/`
- **Integrazione**: Utilizzare il sistema di salvataggio/caricamento delle risorse Godot per gestire i file `.tres` delle blueprint.

## Step by Step Implementation
1. **Setup Iniziale**:
    - Creare la struttura cartelle: `Applications/ShipBuilder/`.
    - Creare `ship_builder.tscn` (Control) e `ship_builder.gd`.
    - Creare la risorsa `ship_builder.tres` (AppResource) e registrarla in `TerminalSoftwareManager`.
2. **Layout UI Principale**:
    - Definire il `VBoxContainer` principale.
    - Implementare la `HeaderBar` con i menu e la `Toolbar`.
    - Dividere l'area centrale in `HBoxContainer`: Layer Visibility, Grid Editor, Inspector.
3. **Editor Grid & Viewport**:
    - Implementare la logica di zoom/pan nella griglia centrale.
    - Disegnare i vari layer in base alla visibilità selezionata.
4. **Moduli Toolbar**:
    - Sviluppare il modulo Software Manager integrato.
    - Sviluppare il modulo File Explorer per il drive della nave.
5. **Logica di Modifica e Persistenza**:
    - Implementare le funzioni di selezione e modifica degli elementi.
    - Implementare la validazione delle stanze rispetto ai requisiti di `RoomDatabase` (dimensioni minime).
    - Implementare l'inserimento automatico dei dispositivi predefiniti alla creazione della stanza.
    - Implementare il parser per salvare/caricare la risorsa `ShipBlueprint`.
6. **Testing**:
    - Creare `tests/test_ship_builder.tscn` e `tests/test_ship_builder_node.gd`.
    - Verificare il corretto funzionamento dell'intero ciclo di creazione e salvataggio.
