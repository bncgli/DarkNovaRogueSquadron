# Analisi del Progetto e Piano di Refactoring - Dark Nova: Rogue Squadron

Questo documento riassume l'analisi dello stato attuale del codice e propone una serie di interventi mirati a migliorare la manutenibilità, la scalabilità e la qualità complessiva del software.

## 1. Centralizzazione dei Dati Statici ed Enum
Attualmente, molti dati fondamentali sono sparsi nel progetto o duplicati in più file.

### Interventi Proposti:
- **Centralizzazione Enum**: Creare un file `Scenes/Autoloads/GlobalValues/Enums.gd` o popolare `global_values.gd` con enum globali come:
    - `Quadrant` (attualmente in `shield_matrix_app.gd` e `systemic_damage_handler.gd`)
    - `AlarmLevel` (attualmente in `systemic_damage_handler.gd`)
    - `ShipClass` (attualmente in `ship_blueprint.gd`)
    - `DeviceCategory` (attualmente in `ship_blueprint.gd`)
    - `file_type_enum` (attualmente in `desktop_folder.gd`)
- **Centralizzazione Metadati**: Spostare i metadati delle telecamere (`CAMERAS_METADATA`) e dei condotti (`DUCT_ROOMS`) da `SpaceWorldManager.gd` al `RoomDatabase`.

## 2. Refactoring dei Manager Monolitici
I manager principali violano il principio di singola responsabilità (SRP), rendendo il debug e l'estensione complessi.

### Interventi Proposti:
- **Suddivisione di `SpaceWorldManager` (2000+ linee)**:
    - Creare `DuctDroneManager` per la logica del drone di manutenzione.
    - Creare `ShipDamageManager` per la gestione dei danni strutturali.
    - Creare `CameraFeedManager` per la gestione delle telecamere e delle relative finestre.
- **Suddivisione di `NetworkManager` (1000+ linee)**:
    - Separare la gestione della ciurma e dei ruoli in un `CrewManager`.
    - Separare la logica di LAN Discovery in un componente più isolato.

## 3. Standardizzazione delle Applicazioni (BaseApp)
È stata riscontrata una forte duplicazione di codice nelle applicazioni GodotOS.

### Interventi Proposti:
- **Creazione di `BaseApp.gd`**:
    - Implementare `_parse_dat_file(rel_path)` una sola volta.
    - Gestire la configurazione standard della finestra (`_configure_window`) e il setup del `parent_window`.
    - Fornire helper comuni per le autorizzazioni RBAC (Role-Based Access Control).
- **Refactoring App Esistenti**: Far ereditare tutte le app da `BaseApp`, rimuovendo centinaia di righe di codice duplicato.

## 4. Evoluzione della ShipBlueprint
L'uso estensivo di dizionari all'interno delle risorse limita il supporto dell'editor e la robustezza del codice.

### Interventi Proposti:
- **Risorse Tipizzate**: Sostituire `Array[Dictionary]` con `Array[RoomData]`, `Array[DuctData]`, ecc.
- **Validazione**: Introdurre metodi di validazione nelle risorse per garantire che i dati del blueprint siano coerenti (es. ID unici, collegamenti validi).

## 5. Miglioramento Addon di Sviluppo
L'analisi degli addon `ship_sublayer_editor` e `star_system_editor` ha rivelato che sono strumenti potenti ma affetti da debito tecnico strutturale.

### Criticità Riscontrate:
- **UI via Codice**: L'interfaccia degli addon è costruita interamente tramite script (`new()`, `add_child()`), rendendo la manutenzione visiva e le modifiche al layout estremamente laboriose.
- **Dati non Tipizzati**: Entrambi gli editor manipolano `Array[Dictionary]`. Questo impedisce a Godot di fornire suggerimenti nell'Inspector e aumenta il rischio di errori a runtime (es. chiavi mancanti nei dizionari).
- **Integrazione Limitata**: Sebbene presenti nel pannello inferiore, non sfruttano appieno le potenzialità delle `EditorProperty` personalizzate per Godot.

### Interventi Proposti:
- **Refactoring UI con Scene**: Migrare la struttura degli addon verso scene `.tscn`. Questo permetterebbe di usare l'editor visuale di Godot per disegnare gli strumenti di sviluppo.
- **Creazione di Risorse per Entità Celesti e Blueprint**: 
    - Creare `CelestialBodyData.gd` (Resource) per sostituire i dizionari in `StarSystemData`.
    - Creare `ShipRoomData.gd`, `ShipDuctData.gd`, ecc. per `ShipBlueprint`.
- **Centralizzazione della Logica di Undo/Redo**: Estrarre la gestione della cronologia in una classe helper comune per entrambi gli editor.

## 6. Pulizia e Codice Inutilizzato
L'analisi tramite `grep` ha identificato numerosi file che non sembrano avere riferimenti diretti.

### Osservazioni:
- **Comandi Terminale**: Molti script in `Applications/Terminal/commands/` appaiono come "inutilizzati" perché caricati dinamicamente da `TerminalCommandManager.gd`. Questi sono **attivi** e non vanno rimossi.
- **Test Obsoleti**: La directory `tests/` contiene numerosi file (`test_ship_builder_node.gd`, ecc.) che non sono referenziati da scene o script di controllo. Si consiglia di migrare a un framework come GUT o rimuovere i test manuali non più funzionanti.
- **Script di Utilità Sparsi**: File come `cleanup_tres.py` o script bash nella root dovrebbero essere spostati in una cartella `tools/` o documentati meglio nel `README`.

## Stato Refactoring - [COMPLETATO]

Tutti i punti proposti nel piano sono stati implementati:

1.  **Centralizzazione**: Enum (`Quadrant`, `AlarmLevel`, `FileType`, ecc.) e metadati sono ora in `GlobalValues` e `RoomDatabase`.
2.  **Manager**: `SpaceWorldManager` e `NetworkManager` sono stati suddivisi in componenti specializzati (`DuctDroneManager`, `ShipDamageManager`, `CameraFeedManager`, `CrewManager`).
3.  **Applicazioni**: Creata `BaseApp.gd` e migrate tutte le app per ridurre la duplicazione.
4.  **Dati**: Implementate risorse tipizzate (`ShipRoomData`, `ShipDuctData`, `CelestialBodyData`) per blueprint e sistemi stellari.
5.  **Addon**: `ShipSublayerEditor` migrato verso una struttura basata su scene `.tscn`.
6.  **Pulizia**: Organizzati script in `tools/` e test obsoleti in `tests/obsolete/`.

## Prossimi Passi Consigliati
1. Continuare la migrazione della UI per `star_system_editor` verso scene.
2. Implementare test automatizzati per i nuovi manager utilizzando GUT.
3. Espandere la validazione delle risorse tipizzate.
