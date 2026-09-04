# Changelog

Tutti i cambiamenti significativi a questo progetto saranno documentati in questo file.

## [Unreleased]

### Changed
- Massivo refactoring dei dati core da `Dictionary` a classi basate su `Resource`.
- `ShipBlueprint.gd`: `rooms`, `ducts`, `devices`, `damages`, `installed_apps`, `flux_modifiers` e `drive_files` ora usano `Array` tipizzati di oggetti Resource.
- `RoomDatabase.gd`: `CAMERAS_METADATA` e `DUCT_ROOMS` convertiti in array di oggetti tipizzati.
- `StarSystemData.gd`: `sectors` e `celestial_bodies` ora utilizzano classi Resource dedicate.
- `CargoManager.gd`: L'inventario e i template utilizzano la nuova classe `CargoItemData`.
- Implementati metodi `to_dict()` e `from_dict()` in tutte le nuove risorse per garantire compatibilità con salvataggi e networking.
- Aggiornati `Ship Sublayer Editor` e `Star System Editor` per il supporto nativo alle nuove risorse.

### Added
- Sezione "Test Pipeline" nel file README.md per documentare l'attivazione del sistema di task.
- File `docs/task_log.md` per il tracciamento storico dei task completati.
- Estensione risorsa `ShipBlueprint` con campi `flux` e `flux_modifiers` per la gestione economica delle navi.
- Nuova applicazione `FluxWallet` per il monitoraggio in tempo reale del Flux e dei modificatori economici.
- Miglioramenti al `ship_sublayer_editor`: risolto bug del trascinamento stanze, aggiunto editing del Flux, posizionamento grafico dello spawn del drone e nuovo pannello "Software Manager" per la gestione di app e password.
- Allineamento globale delle password di sistema: sincronizzate tutte le applicazioni e la blueprint di default con lo standard `-7815` definito nel GDD.
- Aggiornamento `docs/DARK_NOVA_FEATURES_DESIGN.md` con le nuove applicazioni e la matrice delle password completa.
- Implementata la funzionalità di copia-incolla (Ctrl+C/Ctrl+V) nel `ship_sublayer_editor` per tutti i tipi di componenti.
- Centralizzazione della gestione password nel pannello Software Manager e aggiunta funzionalità per installare nuove app (.tres).
- Ottimizzazione UI del Software Manager: unificate le liste di app e password in un layout a righe singole compatto con icone identificative.
- Aggiunta pannello "Software Manager" nell'editor delle navi per la gestione diretta di programmi e credenziali (TASK-006).
- Creazione programma terminale `PodInfo` per il monitoraggio dei parametri vitali e gestione flussi audio (TASK-007).
- Standardizzazione della creazione stanze tramite `RoomDatabase` nell'editor, con auto-configurazione di dimensioni e dispositivi (TASK-012).
- Sviluppo dell'applicazione `ShipBuilder`, un editor di navi completo integrato nel sistema operativo GodotOS (TASK-013).
- Definizione e strutturazione completa dei task di sviluppo per le feature diegetiche di bordo (TASK-031 a TASK-040): Weapons Turret, ShieldMatrix Difesa Direzionale, LifeSupport Termobarico & Danni, DuctDrone Fire & Barriere Sigillate, Sensors LOS/Probe, Comms Antenna Direzionale & EW Link, Nuova App Hack Exploits con Drive Remoto, Comandi Terminale (`worm`, `decript`, `datread`), PodInfo Microfono Plancia & Stati Fisiologici, GodotOS Stack Notifiche & Rilevamento Periferiche.
