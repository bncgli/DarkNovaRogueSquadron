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
