# Task Log

Registro delle attività e dei task completati nel progetto DarkNovaRogueSquadron.

## 2026-08-31

### TASK-002: Creazione File di Log Task
- **Descrizione**: Creazione del file `docs/task_log.md` per tracciare l'esecuzione dei task futuri.
- **Stato**: Completato.
- **Dettagli**: Inizializzazione del registro dei task e aggiornamento della documentazione di progetto.

### TASK-001: Aggiornamento Documentazione Test
- **Descrizione**: Aggiungere una sezione "Test Pipeline" nel file README.md.
- **Stato**: Completato.
- **Dettagli**: README.md aggiornato con le informazioni sulla pipeline di test.

### TASK-003: ShipBlueprint Flux & Modifiers
- **Descrizione**: Estendere la risorsa ShipBlueprint con dati economici.
- **Stato**: Completato.
- **Dettagli**: Aggiunti campi `flux` e `flux_modifiers` in `ship_blueprint.gd` con supporto alla serializzazione JSON (to_dict/from_dict) e integrazione con l'Inspector di Godot tramite `@export`.

### TASK-004: App Flux Wallet
- **Descrizione**: Creazione applicazione Flux Wallet.
- **Stato**: Completato.
- **Dettagli**: Implementata l'app `FluxWallet` (scena, script e risorsa) seguendo gli standard GodotOS. L'app visualizza il valore Flux della blueprint attiva e una tabella formattata dei modificatori. Registrata nei Software Manager di sistema e inclusa nella blueprint di default.

### TASK-005: Ship Sublayer Editor Improvements
- **Descrizione**: Miglioramenti UX e fix bug all'editor delle navi.
- **Stato**: Completato.
- **Dettagli**: Risolto il bug critico del "reset" posizione stanze durante il drag (aggiunto `.duplicate(true)` nello stato di undo). Implementato il pannello di editing per `flux` e `flux_modifiers` nell'inspector della blueprint. Verificato il funzionamento dei resize handles e della selezione/drag dello spawn del drone sul canvas.

### TASK-006: Ship Sublayer Software Manager
- **Stato**: Completato.
- **Dettagli**: Implementazione pannello software per gestione app e password.

### TASK-007: Sviluppo Programma Terminale PodInfo
- **Stato**: Completato.
- **Dettagli**: Creazione app `PodInfo`.

### TASK-008: Allineamento Password GDD/App
- **Stato**: Completato.
- **Dettagli**: Sincronizzazione password `-7815`.

### TASK-009: Funzionalità Copia-Incolla Editor
- **Stato**: Completato.
- **Dettagli**: Implementazione Ctrl+C/Ctrl+V.

### TASK-010: Centralizzazione Password Software Manager
- **Stato**: Completato.
- **Dettagli**: Gestione password spostata nel Software Manager.

### TASK-011: Unificazione Software Manager UI
- **Stato**: Completato.
- **Dettagli**: Layout compatto a riga singola.

### TASK-012: Standardizzazione Stanze Editor
- **Stato**: Completato.
- **Dettagli**: Integrazione `RoomDatabase`.

## 2026-09-01

### TASK-013: Sviluppo Applicazione Terminale ShipBuilder
- **Stato**: Completato.
- **Dettagli**: Sviluppo app `ShipBuilder` per la progettazione custom delle navi.

### TASK-014: Refactor di ShipBlueprint e Struttura Dati
- **Stato**: Completato.
- **Dettagli**: Ristrutturazione profonda di `ShipBlueprint.gd`. I dispositivi sono stati spostati all'interno delle stanze. Rimossi i layer obsoleti per snodi elettrici e cablaggi. Aggiunto supporto per mesh 3D e calcolo automatico della potenza per stanza. Implementata migrazione per vecchi dati.

### TASK-015: Aggiornamento Editor (ShipBuilder e Addon)
- **Stato**: Completato.
- **Dettagli**: Allineati `ShipBuilder` e l'addon `ship_sublayer_editor` alla nuova struttura. Rimossi strumenti per snodi e cavi. Integrato `RoomDatabase` per la selezione rapida delle stanze e gestione dispositivi interni dall'inspector.

### TASK-016: Overhaul Applicazione PowerGrid
- **Stato**: Completato.
- **Dettagli**: Rifacimento dell'app `PowerGrid` con gestione a liste di stanze. Implementata logica di bilanciamento energetico e sistema di notifiche per effetti sistemici (Life Support, Motori, ecc.) tramite il bus di sistema in `SpaceWorldManager`.

### TASK-017: Manutenzione Canvas e Pulizia
- **Stato**: Completato.
- **Dettagli**: Pulizia finale del progetto. Aggiornato `ShipBlueprintCanvas.gd` per mostrare lo stato energetico delle stanze. Rimossi file e script obsoleti (`power_grid_map_canvas.gd`, ecc.) e rimosso ogni riferimento alla vecchia logica di connessione elettrica.

### TASK-018: Miglioramenti Applicazione ShipBuilder
- **Stato**: Completato.
- **Dettagli**: Implementata gestione file con `FileDialog` nativo (Nuovo, Salva, Carica). Aggiunto selettore mesh scafo via UI con navigazione file.
### TASK-019: Nuove Funzionalità e Bug Fix Sublayer Editor
- **Stato**: Completato.
- **Dettagli**: Implementato generatore procedurale a 90 gradi. Aggiunta gestione e feedback visivo (bordo pulsante) per la stanza di ricarica droni. Risolto bug sparizione stanze in fase di creazione.
