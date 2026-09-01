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
