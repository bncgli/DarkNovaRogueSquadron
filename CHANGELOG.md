# Changelog

Tutti i cambiamenti significativi a questo progetto saranno documentati in questo file.

## [Unreleased]

### Added
- **Pericoli Spaziali Dinamici & Eventi Meteo Settore (Fase L / TASK-045)**: introdotto `SpaceWeatherManager` con ciclo vitale a 4 stati (`DORMANT`, `WARNING`, `ACTIVE`, `DISSIPATING`), tipologie di minaccia estreme (`SOLAR_CME`, `ION_EMP_STORM`, `COSMIC_RAD_BURST`), calcolo geometrico del riparo su doppia scala (cono d'ombra planetario macro e cilindro 3D micro dietro asteroidi e relitti), banner diegetico d'allerta `WeatherAlertBanner` in `SensorsApp`, contromisure con deflessione energetica orientata verso la stella in `ShieldMatrixApp` e feedback sensoriali d'impatto con screen shake (16.0) e tachicardia (+35 BPM) in `PodInfoApp`.
- **Propulsione di Crociera Avanzata & Proximity Drop (Fase K / TASK-044)**: integrata la propulsione di crociera avanzata (`CruiseDriveController`) a 160 m/s (8.0x) con blocco attuatori RCS, sequenza deterministica di warmup di 4.0s vincolata al reattore di `PowerGridApp` (160 MW) con aborto su calo energetico, e arresto forzato d'emergenza Proximity Drop (< 250m) con frenata newtoniana violenta, picco di decelerazione longitudinale a $-5.8\,\text{G}$ con smorzamento esponenziale, surriscaldamento $+60^\circ\text{C}$, screen shake 22.0, allarmi acustici e picco tachicardico nei pod.
- **Intercettazione Corrieri Dati S-Net & Caveau DataVault (Fase J / TASK-041)**: aggiunti convogli corrieri dati nemici (`DATA_COURIER`) intercettabili su frequenza 1920.0 MHz via antenna direzionale in `CommsApp`, montaggio cartella protetta `Target Drive/DataVault/`, exploit `dump_vault` in `HackExploitsApp` per espulsione fisica del nucleo quantistico `snet_quantum_core` (1800 FLUX) e recupero con Service Drone.
- **Deep Core Asteroid Mining & Raffinazione Vitale (Fase H / TASK-042)**: implementata l'estrazione mineraria nello spazio con frantumazione fisica 3D degli asteroidi anti-tunneling, generazione nodi fisici `MineralDepositEntity` espulsi nello spazio, aggancio magnetico con Service Drone, intake al portello cargo corvetta e conversione blocchi di ghiaccio in riserve idriche/ossigeno per Life Support.

### Changed
- **Delega Volo & Telemetria in FlightControlApp (Fase K / TASK-044)**: sostituito il toggle semplificato con delega diretta a `CruiseDriveController`, barra di avanzamento warmup in tempo reale, telemetria a 160 m/s (8.0x), indicatore cooldown residuo e inibizione selettiva dei comandi RCS in crociera.
- **Riscrittura Flux Economy & Baratto Titoli Debito (Fase I / TASK-043)**: eliminata la valuta fiat convenzionale a favore del modello Freemium-punk con saldo netto contabile ($\text{Net} = \text{Liquid} + \sum \text{Modifiers}$), baratto di titoli e quote di debito/credito corporativo (`ShipFluxModifier`), credit score dinamico della nave, pagamento rateale o a fido in `StationHubApp` e sgravio debito dalle ricompense contrattuali in `MissionManager`.

### Fixed
- **Caricamento Zona 3D con Salto Hyperdrive**: risolto il problema per cui l'indicatore sulla System Map si spostava ma la nave non caricava l'ambiente del nuovo settore. Connesso `StarSystemGridManager` a `SpaceWorldManager` tramite `load_sector_zone()`, implementando il riposizionamento e l'arresto cinematico dell'astronave, il caricamento/scaricamento delle stazioni e dei relitti spaziali, la riconfigurazione dinamica del campo asteroidi, l'aggiornamento diegetico dei waypoint di navigazione e il corretto filtraggio dei contatti radar nel nuovo settore.
- **DynamicSpaceSkybox**: il nodo non veniva mai istanziato nella scena di gioco reale (era presente solo nei test GUT). Aggiunto come figlio di `SpaceScene` in `Outside/space_scene.tscn`, accanto a `WorldEnvironment` e `SunLight` (già rilevati automaticamente da `_auto_detect_scene_elements()`), così la proiezione diegetica dei corpi celesti e l'illuminazione stellare dinamica ora funzionano effettivamente durante il volo.
- **DynamicSpaceSkybox non visibile da Cams**: lo skybox si centrava sulla camera "attiva del viewport" (`get_viewport().get_camera_3d()`), che in `space_scene.tscn` è una `Camera3D` statica di default e non si muove mai con la nave. I feed delle telecamere esterne (`Cams`) invece seguono la trasformazione reale dell'astronave, quindi non appena la nave si spostava dall'origine della scena, i corpi celesti proiettati restavano "indietro" e uscivano dal campo visivo dei feed. Ora lo skybox rileva automaticamente il nodo `Spaceship` (sibling in scena) e si centra sulla sua posizione globale ad ogni frame, restando quindi sempre visibile da qualsiasi camera, incluse quelle di `Cams`.

### Added
- **Transizione Hyperdrive in @Applications/Cams con Sincronizzazione Equipaggio**: durante il salto Hyperdrive i feed e l'applicazione di controllo delle telecamere esterne (`Cams`) entrano in modalità di perdita di contatto e distorsione tachionica. Creato lo shader video dedicato `hyperdrive_loss.gdshader` (rumore bianco ad alta frequenza, salti di fase e scanlines CRT), integrato l'overlay `HyperdriveLossOverlay` in `CameraFeedWindow` con disattivazione dei comandi ottici locali e badge `NO SIGNAL`, e aggiunto il banner `HyperdriveTransitBanner` in `CamsApp` con conteggio in tempo reale della sincronizzazione dei giocatori. La transizione dura finché tutti i membri dell'equipaggio non hanno completato il caricamento del nuovo settore 3D.
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
