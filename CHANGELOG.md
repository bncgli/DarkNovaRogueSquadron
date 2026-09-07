# Changelog

Tutti i cambiamenti significativi a questo progetto saranno documentati in questo file.

## [Unreleased]

### Fixed
- **DynamicSpaceSkybox**: il nodo non veniva mai istanziato nella scena di gioco reale (era presente solo nei test GUT). Aggiunto come figlio di `SpaceScene` in `Outside/space_scene.tscn`, accanto a `WorldEnvironment` e `SunLight` (già rilevati automaticamente da `_auto_detect_scene_elements()`), così la proiezione diegetica dei corpi celesti e l'illuminazione stellare dinamica ora funzionano effettivamente durante il volo.
- **DynamicSpaceSkybox non visibile da Cams**: lo skybox si centrava sulla camera "attiva del viewport" (`get_viewport().get_camera_3d()`), che in `space_scene.tscn` è una `Camera3D` statica di default e non si muove mai con la nave. I feed delle telecamere esterne (`Cams`) invece seguono la trasformazione reale dell'astronave, quindi non appena la nave si spostava dall'origine della scena, i corpi celesti proiettati restavano "indietro" e uscivano dal campo visivo dei feed. Ora lo skybox rileva automaticamente il nodo `Spaceship` (sibling in scena) e si centra sulla sua posizione globale ad ogni frame, restando quindi sempre visibile da qualsiasi camera, incluse quelle di `Cams`.

### Added
- **Cielo stellato diegetico**: aggiunto un campo stellare procedurale (`CPUParticles3D`) a `DynamicSpaceSkybox`, composto da punti luminosi non ombreggiati distribuiti sulla superficie di una sfera (raggio 380m) centrata sulla nave, per simulare stelle a distanza infinita (nessuna parallasse) attorno all'astronave, prima assente nel `ProceduralSkyMaterial` (che offriva solo un gradiente di colore).

### Documentation
- Riscritto integralmente `README.md` come guida introduttiva per i giocatori di *Dark Nova: Rogue Squadron*, riflettendo lo stato reale del progetto (concept, avvio, applicazioni giocabili, controlli).
- Allineato `docs/DARK_NOVA_FEATURES_DESIGN.md` alle implementazioni effettive delle app `Weapons`, `ShieldMatrix`, `Comms`, `Sensors` e `CargoBay`, rimuovendo funzionalità descritte ma non implementate (jamming/spoofing IFF, decodifica crypto in-app, radar a 50km, spettrometria asteroidi, FLUX/S-Net in CargoBay).
- Rimossi da `TODO.md` i riferimenti a file `task_queue/*.md` non più esistenti (TASK-003, TASK-004, TASK-005).

### Changed
- **PodInfo**: convertita da app a finestra apribile/chiudibile a widget diegetico sempre attivo, istanziato direttamente in `Scenes/Taskbar/taskbar.tscn` accanto all'orologio (analogo ai widget di sistema di un desktop environment); rimossi comando terminale `pod`, registrazione in `TerminalSoftwareManager` e voce nel menu Start/Software Manager. Rimossa la frequenza cardiaca (label, timer, calcolo, suono heartbeat) e i campi non essenziali (qualità aria, stato equipaggio testuale); il widget mostra ora solo Ossigeno, Temperatura, Pressione e G-Force in forma compatta. Restano invariati il microfono virtuale spazializzato e gli effetti fisiologici critici (Blackout/Redout/GameOver).
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
