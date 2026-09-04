# Project TODO List

## Tasks

- [x] **TASK-001**: Aggiornamento Documentazione Test
  - **Descrizione**: Aggiungere una sezione "Test Pipeline" nel file README.md.
  - **Criteri di accettazione**: README.md aggiornato.
  - **Stato**: Completato (2026-08-31).

- [x] **TASK-002**: Creazione File di Log Task
  - **Descrizione**: Creare un file `docs/task_log.md` per tracciare i task.
  - **Criteri di accettazione**: File creato con intestazione data.
  - **Stato**: Completato (2026-08-31).

- [x] **TASK-003**: ShipBlueprint Flux & Modifiers
  - **Descrizione**: Estendere `ShipBlueprint` con `flux` e `flux_modifiers`.
  - **Criteri di accettazione**: Campi esportati e funzionanti in `Outside/ShipSublayer/ship_blueprint.gd`.
  - **File Task**: `task_queue/001_ship_blueprint_flux.md`
  - **Stato**: Completato (2026-08-31).

- [x] **TASK-004**: App Flux Wallet
  - **Descrizione**: Creare l'app `FluxWallet` per visualizzare il flux e i modificatori.
  - **Criteri di accettazione**: App funzionale secondo `docs/APP_ARCHITECTURE_STANDARD.md`.
  - **File Task**: `task_queue/002_app_flux_wallet.md`
  - **Stato**: Completato (2026-08-31).

- [x] **TASK-005**: Ship Sublayer Editor Improvements
  - **Descrizione**: Migliorare l'editor delle blueprint (resize, fix drag, spawn pos, flux editing).
  - **Criteri di accettazione**: Tutte le migliorie e fix implementati in `@addons/ship_sublayer_editor`.
  - **File Task**: `task_queue/003_ship_editor_improvements.md`
  - **Stato**: Completato (2026-08-31).

- [x] **TASK-006**: Ship Sublayer Software Manager
  - **Descrizione**: Aggiungere pannello Software a sinistra dell'editor per installazione/disinstallazione app e gestione password.
  - **Criteri di accettazione**: Pannello "Software" funzionante con lista app, pulsanti disinstalla e modifica password.
  - **Stato**: Completato (2026-08-31).

- [x] **TASK-008**: Allineamento Password GDD/App
  - **Descrizione**: Aggiornare tutti i programmi per avere le password di default descritte nel GDD.
  - **Criteri di accettazione**: Password sincronizzate tra GDD, file .tres e blueprint della nave.
  - **Stato**: Completato (2026-08-31).

- [x] **TASK-009**: Funzionalità Copia-Incolla Editor
  - **Descrizione**: Implementare copia-incolla per elementi del ship_sublayer_editor.
  - **Criteri di accettazione**: Scorciatoie Ctrl+C/Ctrl+V funzionanti, nuovi ID univoci, supporto Undo.
  - **Stato**: Completato (2026-08-31).

- [x] **TASK-010**: Centralizzazione Password Software Manager
  - **Descrizione**: Spostare la gestione password dall'Inspector al Software Manager e aggiungere funzione installazione app.
  - **Criteri di accettazione**: Password visibili e modificabili nel pannello software, pulsanti "➕ App" e "➕ Pass" funzionanti.
  - **Stato**: Completato (2026-08-31).

- [x] **TASK-011**: Unificazione Software Manager UI
  - **Descrizione**: Unificare la lista di software e password in un layout a righe singole compatto.
  - **Criteri di accettazione**: Layout uniforme, icone distintive, rimozione sezioni separate.
  - **Stato**: Completato (2026-08-31).

- [x] **TASK-007**: Sviluppo Programma Terminale PodInfo
  - **Descrizione**: Creazione programma `PodInfo` per monitoraggio parametri vitali e gestione audio.
  - **Criteri di accettazione**: Applicazione terminale funzionante e visualizzazione dati vitali.
  - **File Task**: `task_queue/001_pod_info_program.md`
  - **Stato**: Completato (2026-08-31).

- [x] **TASK-012**: Standardizzazione Stanze Editor
  - **Descrizione**: Standardizzazione creazione stanze nel `ship_sublayer_editor` tramite database Autoload.
  - **Criteri di accettazione**: Selezione stanze da lista predefinita, auto-assegnazione dispositivi e dimensioni minime.
  - **File Task**: `task_queue/002_standardizzazione_stanze_editor.md`
  - **Stato**: Completato (2026-08-31).

- [x] **TASK-013**: Sviluppo Applicazione Terminale ShipBuilder
  - **Descrizione**: Creazione del tool terminale 'ShipBuilder' per la progettazione custom delle navi.
  - **Criteri di accettazione**: Editor funzionale con gestione sublayer, software, drive files e integrazione RoomDatabase; salvataggio/caricamento blueprint.
  - **File Task**: `task_queue/003_ship_builder_app.md`
  - **Stato**: Completato (2026-09-01).

- [x] **TASK-014**: Refactor di ShipBlueprint e Struttura Dati
  - **Descrizione**: Centralizzazione device nelle stanze e rimozione layer junctions/conduits.
  - **Criteri di accettazione**: Blueprint ristrutturata, supporto mesh 3D, calcolo power per stanza.
  - **File Task**: `task_queue/004_refactor_ship_blueprint.md`
  - **Stato**: Completato (2026-09-01).

- [x] **TASK-015**: Aggiornamento Editor (ShipBuilder e Addon)
  - **Descrizione**: Rimozione tool obsoleti, integrazione RoomDatabase e fix bug UI in ShipBuilder.
  - **Criteri di accettazione**: UI pulita, selezione mesh funzionante, fix finestre e software list.
  - **File Task**: `task_queue/005_aggiornamento_editor_shipbuilder.md`
  - **Stato**: Completato (2026-09-01).

- [x] **TASK-016**: Overhaul Applicazione PowerGrid
  - **Descrizione**: Nuova UI basata su lista stanze e implementazione effetti sistemici dell'energia.
  - **Criteri di accettazione**: Controllo On/Off per stanza, bilanciamento energetico, effetti su life support/armi/motori.
  - **File Task**: `task_queue/006_overhaul_powergrid.md`
  - **Stato**: Completato (2026-09-01).

- [x] **TASK-017**: Manutenzione Canvas e Pulizia
  - **Descrizione**: Rimozione rendering layer obsoleti e pulizia codice morto.
  - **Criteri di accettazione**: Canvas aggiornato, rimozione file e riferimenti a junctions/conduits.
  - **File Task**: `task_queue/007_manutenzione_canvas_pulizia.md`
  - **Stato**: Completato (2026-09-01).

- [x] **TASK-018**: Miglioramenti Applicazione ShipBuilder
  - **Descrizione**: Espansione menu File (Nuovo, Salva/Carica con FileDialog) e selettore mesh scafo via UI.
  - **Criteri di accettazione**: Gestione file migliorata, FileDialog per mesh scafo funzionante.
  - **File Task**: `task_queue/008_shipbuilder_improvements.md`
  - **Stato**: Completato (2026-09-01).

- [x] **TASK-019**: Nuove Funzionalità e Bug Fix Sublayer Editor
  - **Descrizione**: Generazione casuale (angoli retti), zona ricarica drone e fix sparizione stanze.
  - **Criteri di accettazione**: Algoritmo random funzionante, selezione stanza ricarica con bordo speciale, fix bug disegno.
  - **File Task**: `task_queue/009_sublayer_editor_features.md`
  - **Stato**: Completato (2026-09-01).

- [x] **TASK-021**: Aggiornamento Documentazione Post-Refactoring Resource
  - **Descrizione**: Aggiornamento di CHANGELOG.md, .junie/context e docs/architecture per riflettere il passaggio da Dictionary a Resource.
  - **Criteri di accettazione**: Tutti i file di contesto aggiornati con le nuove classi Resource e relazioni di sistema.
  - **Stato**: Completato (2026-09-02).

- [x] **TASK-022**: GodotOS Window Management & Z-Order Fixes
  - **Descrizione**: Correzione z-order barra del titolo, focus click su intera superficie finestra e rimozione semi-trasparenza finestre in background.
  - **Criteri di accettazione**: Titoli finestre non sovrapposti a finestre superiori, focus su click interno e finestre in background completamente opache.
  - **File Task**: `task_queue/010_godotos_window_management.md`
  - **Stato**: Completato (2026-09-03).

- [x] **TASK-023**: Overhaul Flight Control & Propulsione di Crociera
  - **Descrizione**: Nuovi comandi velocità R/F, rimozione reset position, toggle inerzia (on default/off deriva), potenza da ShipBlueprint e fix rotazione/attivazione Hyperdrive.
  - **Criteri di accettazione**: Tasti R/F funzionanti, inerzia disattivabile, lettura potenza MW da blueprint, orientamento nave e transito settore iperdrive funzionanti.
  - **File Task**: `task_queue/011_flight_control_overhaul.md`
  - **Stato**: Completato (2026-09-03).

- [x] **TASK-024**: Filtri Cams, Fari & Fix Dynamic Skybox
  - **Descrizione**: Ripristino visualizzazione corpi celesti nello skybox 3D, riduzione filtri telecamere a Normale (con tasto fari), Termico (shader scie) e Lidar (shader raycast).
  - **Criteri di accettazione**: Skybox 3D funzionante con corpi celesti, fari commutabili e shader termico e lidar attivi.
  - **File Task**: `task_queue/012_cams_filters_and_lighting.md`
  - **Stato**: Completato (2026-09-03).

- [x] **TASK-025**: Miglioramenti System Map, Calcolo Rotta & Ombre Planetarie
  - **Descrizione**: Estensione livello di zoom, sequenza calcolo rotta di 3-5s con feedback testuali e visualizzazione 2D delle zone d'ombra proiettate dai pianeti.
  - **Criteri di accettazione**: Zoom massimo aumentato, calcolo rotta con delay e feedback diegetici, rendering coni d'ombra planetari rispetto alla stella.
  - **File Task**: `task_queue/013_system_map_improvements.md`
  - **Stato**: Completato (2026-09-03).

- [x] **TASK-026**: Differenziazione Cromatica Stanze PowerGrid
  - **Descrizione**: Evidenziazione visiva delle stanze consumatrici in colore rosso e stanze generatrici in colore verde in tutta la UI di PowerGrid.
  - **Criteri di accettazione**: Stanze con consumo negativo in rosso evidente, stanze produttrici in verde, stanze spente in grigio neutro.
  - **File Task**: `task_queue/014_powergrid_status_colors.md`
  - **Stato**: Completato (2026-09-03).

- [x] **TASK-027**: Service Drone Collider 3D & Controlli Rotazione
  - **Descrizione**: Aggiunta di collider solido e logica di collisione 3D al drone di servizio, con controlli di rotazione su se stesso mappati sui tasti freccia.
  - **Criteri di accettazione**: Drone con collisioni attive su scafo/ostacoli e rotazione tramite tasti freccia (pitch/yaw).
  - **File Task**: `task_queue/015_service_drone_controls_collision.md`
  - **Stato**: Completato (2026-09-03).

- [x] **TASK-028**: Meccaniche Duct Drone, Tasto Radar & Recupero Emergenza
  - **Descrizione**: Allineamento spawn e ricarica a ShipBlueprint, tasto R per radar, rimozione pulsante reset e timer 1m per ritorno automatico a batteria esaurita.
  - **Criteri di accettazione**: Spawn e ricarica vincolati alla stanza blueprint, tasto R per radar, pulsante reset rimosso e auto-ritorno dopo 60s senza carica.
  - **File Task**: `task_queue/016_duct_drone_mechanics.md`
  - **Stato**: Completato (2026-09-03).

- [x] **TASK-029**: Semplificazione CargoBay & Vista Inventario Pura
  - **Descrizione**: Rimozione schede trasferimenti, rating FLUX e hack S-Net da CargoBay, mantenendo un'interfaccia inventario stiva pulita ed essenziale.
  - **Criteri di accettazione**: Applicazione limitata a inventario stiva (lista oggetti, dettagli, peso/volume, espulsione merci).
  - **File Task**: `task_queue/017_cargobay_inventory_cleanup.md`
  - **Stato**: Completato (2026-09-03).

- [x] **TASK-030**: Integrazione Chiavi di Decriptazione File .DAT
  - **Descrizione**: Inserimento di una chiave di decriptazione standardizzata in tutti i file .dat di configurazione diegetici per futuri minigiochi di hacking.
  - **Criteri di accettazione**: Tutti i file .dat in ShipDriveManager e nella blueprint contengono chiavi di decriptazione univoche compatibili con BaseApp.
  - **File Task**: `task_queue/018_dat_files_encryption.md`
  - **Stato**: Completato (2026-09-03).

- [x] **TASK-031**: Overhaul Torretta Weapons, Puntatore Mouse & Classi Munizioni
  - **Descrizione**: Conversione di Weapons in torretta con puntamento mouse, cattura puntatore con Spazio, selettore munizioni 1..4 (Mitragliatrice, Cannone, Missili con lock, Probe) e HUD traiettoria/lead indicator.
  - **Criteri di accettazione**: Puntamento mouse fluido con Spazio per cattura, tasti 1-4 per cambio classe proiettile, lock missile a tempo/radar, HUD con lead indicator diegetico.
  - **File Task**: `task_queue/019_weapons_turret_mouse_aim_ammo_types.md`
  - **Stato**: Completato (2026-09-04).

- [x] **TASK-032**: Ricostruzione ShieldMatrix & Dispositivi Difensivi Direzionali
  - **Descrizione**: Layout bipartito (ologramma 4 settori a sinistra, dispositivi difensivi a destra), gestione dinamica di Gatling Auto e Flack Angel-Hair con assegnazione a singolo settore protetto.
  - **Criteri di accettazione**: UI split sinistra/destra, lista estensibile dispositivi di difesa, assegnazione per settore, intercettazione automatica specifica per tipologia di minaccia.
  - **File Task**: `task_queue/020_shield_matrix_directional_defense_systems.md`
  - **Stato**: Completato (2026-09-04).

- [x] **TASK-033**: Telemetria LifeSupport, Pressione/Temperatura & Dinamica Brecce/Fuoco
  - **Descrizione**: Estensione del monitoraggio a Pressione e Temperatura per stanza, decompressione da brecce, azzeramento termico automatico nel vuoto, corti caldaia e ustioni letali da incendio.
  - **Criteri di accettazione**: Telemetria 4 parametri per stanza, svuotamento pressione da brecce con caduta termica a zero, blocco riscaldamento su corto circuito, danni fisiologici da fuoco/asfissia.
  - **File Task**: `task_queue/021_lifesupport_pressure_temp_fire_breaches.md`
  - **Stato**: Completato (2026-09-04).

- [x] **TASK-034**: DuctDrone: Danno Incendio, Barriere Stanze Sigillate & Fix Spawn/Luci
  - **Descrizione**: Aggiunta danno Incendio, barriere invalicabili per il drone in caso di stanze sigillate dal LifeSupport, fix spawn su coordinate blueprint e avvio con luce spenta di default.
  - **Criteri di accettazione**: Tipo danno FIRE riconosciuto e riparabile, paratie sigillate impediscono entrata/uscita al drone, spawn rigoroso da blueprint e luci spente all'avvio.
  - **File Task**: `task_queue/022_duct_drone_fire_hazard_room_sealing_fixes.md`
  - **Stato**: Completato (2026-09-04).

- [x] **TASK-035**: Realismo Sensors: Ombre Ostacoli, Sweep 1km, Feed Probe & Ping Energetico
  - **Descrizione**: Portata standard ridotta a 1km, ombre radar dietro asteroidi (Line of Sight), blip anonimi non identificati, rimozione dropdown bersagli, radar della probe integrato e ping 2km gated dall'energia.
  - **Criteri di accettazione**: Raggio radar 1km, occlusione da ostacoli, blip diegetici puri, rimozione menu tendina, feed radar della sonda a schermo e ping subordinato ai MW disponibili.
  - **File Task**: `task_queue/023_sensors_los_radar_probe_feed_energy_ping.md`
  - **Stato**: Completato (2026-09-04).

- [x] **TASK-036**: Overhaul Comms: Antenna Direzionale, Interazione Stazioni & Link EW
  - **Descrizione**: Rimozione vecchio jamming/decripting, parte inferiore divisa in 2 (antenna direzionale con sweep manuale/auto/lock a sinistra, opzioni frequenza/stazioni a destra) e pulsante Connect per segnali EW stabili.
  - **Criteri di accettazione**: Rimozione controlli obsoleti, antenna direzionale con ricezione ad angolo e auto-lock, menu attracco stazioni, abilitazione connessione Drive su segnale potente.
  - **File Task**: `task_queue/024_comms_directional_antenna_station_docking_ew.md`
  - **Stato**: Completato (2026-09-04).

- [x] **TASK-037**: Nuova Applicazione 'Hack Exploits' & Suite Sottoprogrammi Drive Remoto
  - **Descrizione**: Nuova app GodotOS per violazione informatica, montaggio icona "Target Drive" sul Desktop al Connect, sottoprogrammi con prerequisiti password/chiavi (spammer, blind_eye, 8loops, gout) e file sentinella di disattivazione.
  - **Criteri di accettazione**: Montaggio Target Drive, validazione prerequisiti diegetici (.dat/password), esecuzione attacchi su OS bersaglio (popup, cams kill, loop G, rotazione sbloccata) e cessazione su eliminazione file.
  - **File Task**: `task_queue/025_hack_exploits_subprograms_remote_drive.md`
  - **Stato**: Completato (2026-09-04).

- [x] **TASK-038**: Comandi Terminale: 'worm', 'decript' & 'datread'
  - **Descrizione**: Introduzione minigioco Mastermind `worm` per password cartelle, cifrario interattivo `decript` per chiavi file .dat con frase pangramma e visualizzatore/editor `datread` per file di configurazione protetti.
  - **Criteri di accettazione**: Comando `worm` con turni di indizio, `decript` con rivelazione graduale del testo in chiaro, `datread` integrato con il Text Editor per modifica controllata dei file .dat.
  - **File Task**: `task_queue/026_terminal_commands_worm_decript_datread.md`
  - **Stato**: Completato (2026-09-04).

- [x] **TASK-039**: PodInfo: Telemetria Vitale, Microfono Virtuale Plancia & Stati Fisiologici
  - **Descrizione**: Monitoraggio 4 parametri vitali reali (O2, Pressione, Temperatura, G), audio diegetico spazializzato/ovattato per eventi di bordo, suoni personaggio (asfissia, ustione, ipotermia) ed effetti visivi Blackout/Redout con GameOver.
  - **Criteri di accettazione**: Parametri vitali sincronizzati con la nave, microfono virtuale con attenuazione diegetica per distanza, vocali/rantoli fisiologici, overlay e collasso vitale da G/anomalie.
  - **File Task**: `task_queue/027_podinfo_vitals_spatial_audio_crew_effects.md`
  - **Stato**: Completato (2026-09-04).

- [x] **TASK-040**: GodotOS: Impilamento Notifiche in Coda & Riconoscimento Periferiche
  - **Descrizione**: Layout dinamico per impilare verticalmente le notifiche simultanee senza sovrapposizioni visive e rilevamento automatico della connessione/disconnessione di controller/gamepad con notifica diegetica.
  - **Criteri di accettazione**: Notifiche multiple separate e ordinate in stack verticale con transizioni fluide, rilevamento automatico connessione joystick/gamepad con nome periferica.
  - **File Task**: `task_queue/028_godotos_notification_stacking_peripheral_detect.md`
  - **Stato**: Completato (2026-09-04).
