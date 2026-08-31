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
