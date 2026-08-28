# TASK: Sviluppo Applicazione "Mission Logbook & Tactical Objectives" (`Applications/Logbook`)

> **Riferimento Standard Architetturale**: Lo sviluppo di questa applicazione deve seguire rigorosamente le direttive descritte in [`docs/APP_ARCHITECTURE_STANDARD.md`](../docs/APP_ARCHITECTURE_STANDARD.md).

## 1. Obiettivo e Panoramica
Sviluppare l'applicazione **Mission Logbook & Tactical Objectives** (`Applications/Logbook`) per *Dark Nova: Rogue Squadron* (GodotOS).
L'applicazione funge da registro di bordo ufficiale, diario delle operazioni di volo, tracker dei contratti sandbox e scatola nera (storico telemetrico degli eventi di bordo). Consente inoltre di scrivere note diegetiche condivisibili sull'equipaggio (`Ship Drive`) o private (`Terminal Drive`).

- **Tipologia di Applicazione**: **Applicazione del Server (Nave)**.
  - Disponibile e operativa a bordo della nave durante la missione (`SpaceWorldManager.is_ship_connected() == true`).
  - In stato offline / lobby deve mostrare l'overlay bloccante `%DisconnectedOverlay`.

---

## 2. Standard Architetturali e Flusso Git
1. **Flusso Git (Obbligatorio)**:
   - Creare ed eseguire il checkout sul branch dedicato partendo da `main`: `git checkout -b applications/Logbook main`.
   - Sviluppare il codice, configurazioni e test esclusivamente all'interno di tale branch.
   - Al termine dello sviluppo e dopo aver validato con successo i test:
     1. Eseguire il commit di tutte le modifiche: `git add .` e `git commit -m "feat(logbook): implementa registro di bordo e missioni"`.
     2. Passare al branch `main`: `git checkout main`.
     3. Eseguire il merge del branch completato: `git merge applications/Logbook`.
2. **Struttura dei File e Cartelle**:
   ```text
   Applications/
   └── Logbook/
       ├── logbook_app.tscn          # Scena principale (Control UI, dimensioni 600x450)
       ├── logbook_app.gd            # Script controller interfaccia
       └── logbook_app.tres          # Risorsa ShipAppResource con metadati, RBAC e file .dat

   tests/
   ├── test_logbook_app.tscn         # Scena runner per test headless
   └── test_logbook_app_node.gd      # Script di test headless con asserzioni
   ```

---

## 3. Anatomia UI, Layout e Contenimento Finestra
- **Nodo Radice**: `Control` (o `PanelContainer`) con `custom_minimum_size = Vector2(600, 450)`.
- **Regole di Layout**: Nessun elemento deve sbordare dai confini della finestra. Usare `TabContainer` o schede con `ScrollContainer` e `Container` responsivi (`VBoxContainer`, `HBoxContainer`, `MarginContainer`).
- **Gerarchia Raccomandata**:
  ```text
  LogbookApp (Control) [custom_minimum_size: 600x450]
  ├── VBoxContainer (MainLayout)
  │   ├── HeaderBar (HBoxContainer)          # Titolo ("REGISTRO DI BORDO & MISSIONI"), badge stato, pulsante "🔄 Ricarica .DAT"
  │   ├── TabContainer (ContentTabs)          # Schede operative:
  │   │   ├── Contratti & Obiettivi (MarginContainer) # Tracker contratti attivi e ricompense FLUX
  │   │   ├── Scatola Nera (MarginContainer)          # Event Log cronologico di bordo
  │   │   └── Note di Plancia (MarginContainer)       # Editor note diegetiche (Ship Drive / Terminal Drive)
  │   └── StatusBar (HBoxContainer)           # %StatusLabel, numero contratti attivi, storage note
  └── %DisconnectedOverlay (Panel)           # Overlay a schermo intero visibile quando disconnesso
      └── CenterContainer
          └── VBoxContainer
              ├── Label ("⚠️ REGISTRO DI BORDO OFFLINE")
              └── Label ("In attesa di connessione alla nave / Avvio missione...")
  ```

---

## 4. Matrice RBAC (Role-Based Access Control)
- **Capitano**: **Controllo Completo** (assegnazione/completamento contratti, modifica e approvazione log ufficiali di missione).
- **Factotum** / **Solo Mode**: **Controllo Completo e Override**.
- **Pilota**, **Soldato**, **Ingegnere**, **Hacker**: Lettura contratti, inserimento note personali/di plancia, visualizzazione scatola nera.

---

## 5. Pattern GDScript e Ciclo di Vita (`logbook_app.gd`)
Lo script controller deve implementare il pattern standard di `APP_ARCHITECTURE_STANDARD.md`:
- Costanti: `APP_TITLE = "REGISTRO DI BORDO & OBIETTIVI"`, `DEFAULT_WINDOW_SIZE = Vector2(600, 450)`.
- Riferimenti via *Unique Names* (`%DisconnectedOverlay`, `%StatusLabel`, ecc.).
- Collegamento segnali in `_connect_system_signals()`:
  - `SpaceWorldManager.ship_connection_changed` -> `_on_ship_connection_changed(is_connected: bool)`
  - `NetworkManager.player_role_changed` -> `_on_player_role_changed(peer_id: int, new_role: String)`
  - `ShipDriveManager.file_modified` -> `_on_drive_file_modified(rel_path: String)` (Hot-reloading)
- Disconnessione pulita di tutti i segnali in `_exit_tree()`.
- Metodi di parsing standard: `_parse_dat_file(rel_path: String) -> Dictionary`, `load_dat_configuration()`, `_apply_configuration()`.

---

## 6. Configurazione `.DAT`, Drive Protetti e Hackwarfare
- **Percorso Cartella Protetta**: `Ship Drive/Programs/Logbook/` (Sincronizzata su Ship Drive).
- **Password di Debug**: `LOGS-7815`.
- **File di Configurazione Standard**:
  - `Ship Drive/Programs/Logbook/logbook_config.dat`:
    ```ini
    [SYSTEM]
    app_name=LogbookApp
    version=1.0.0
    status=OPERATIONAL

    [LOGGING]
    auto_log_events=true
    max_history_entries=200
    log_telemetry_errors=true
    ```
  - `Ship Drive/Programs/Logbook/journal_tuning.dat`:
    ```ini
    [SYNC]
    sync_to_ship_drive=true
    timestamp_format=STAR_DATE
    cloud_backup=false
    ```
- **Protezione Diegetica**: I file `.dat` non sono leggibili dal File Reader standard e contengono impostazioni attive a runtime.
- **Integrazione Diagnostics**: Registrare i file predefiniti e la password debug `LOGS-7815` in `Applications/Diagnostics/diagnostics_app.gd` per supportare il factory reset firmware.

---

## 7. Integrazione con ShipSoftwareManager, ShipBlueprint & Sessione di Gioco
- **ShipAppResource (`logbook_app.tres`)**:
  - `app_id`: `"logbook"`
  - `title`: `"Registro di Bordo & Obiettivi"`
  - `description`: `"Diario di volo, contratti sandbox, scatola nera ed eventi"`
  - `scene_path`: `"res://Applications/Logbook/logbook_app.tscn"`
  - `icon_color`: `Color(0.8, 0.7, 0.2)`
  - `roles`: `["Captain", "Factotum", "Pilot", "Soldier", "Engineer", "Hacker"]`
  - `power_draw_mw`: `5.0`
  - `required_subsystems`: `[]`
  - `drive_folder`: `"Programs/Logbook"`
  - `default_password`: `"LOGS-7815"`
  - `default_files`: configurazioni `logbook_config.dat` e `journal_tuning.dat`.
- **Sublayer 6 (Mainframe Installed Apps)**: Registrare la risorsa in `DEFAULT_SHIP_APP_PATHS` di `ShipSoftwareManager` e in `installed_apps` di `ShipBlueprint`.
- **Economia Persistente**: Connessione con il registro di fondi FLUX e crediti nave per riscossione contratti.

---

## 8. Suite di Test Headless (`tests/`)
Creare i file di test headless secondo lo standard:
- `tests/test_logbook_app.tscn`: Scena runner minimale.
- `tests/test_logbook_app_node.gd`: Script con test di validazione terminanti con `get_tree().quit(0)` o `get_tree().quit(1)`:
  1. **Overlay / Ciclo di Vita**: Verifica che `%DisconnectedOverlay` sia visibile offline e scompaia al segnale `ship_connection_changed(true)`.
  2. **RBAC**: Verifica che le azioni contrattuali siano riservate al Capitano/Factotum mentre la lettura e l'inserimento note siano aperti a tutti.
  3. **File .DAT e Hot-Reload**: Verifica parsing corretto di `logbook_config.dat` e `journal_tuning.dat` e hot-reloading su modifica.
  4. **Risorsa e Software Manager**: Verifica che `logbook_app.tres` sia registrata e gestita correttamente da `ShipSoftwareManager`.
  5. **Pulizia Segnali**: Verifica assenza di memory leak o segnali orfani dopo `_exit_tree()`.

---

## 9. Checklist di Verifica Finale (Conforme a APP_ARCHITECTURE_STANDARD.md)
- [ ] Flusso Git completato: sviluppo su `applications/Logbook`, commit finale e merge in `main`.
- [ ] Rispetto della tipologia Server (Nave) con blocco offline.
- [ ] Creata risorsa `ShipAppResource` (`logbook_app.tres`) e registrata in `ShipSoftwareManager` e `ShipBlueprint`.
- [ ] Cartella protetta `Ship Drive/Programs/Logbook/` creata con password `LOGS-7815`.
- [ ] File `.dat` non leggibili da File Reader e parsing tramite `_parse_dat_file`.
- [ ] Hot-reloading attivo su `file_modified` e pulsante `🔄 Ricarica .DAT` presente nella UI.
- [ ] Finestra senza sbordamento e layout responsivo (`custom_minimum_size: 600x450`).
- [ ] Registrazione in `ShipBlueprint` con filtro ruoli RBAC.
- [ ] Suite di test headless (`tests/test_logbook_app.tscn` + `tests/test_logbook_app_node.gd`) funzionante e con esito verde.
