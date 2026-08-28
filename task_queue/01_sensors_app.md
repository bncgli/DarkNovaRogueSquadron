# TASK: Sviluppo Applicazione "Long-Range Sensor Array & Tactical Map" (`Applications/Sensors`)

> **Riferimento Standard Architetturale**: Lo sviluppo di questa applicazione deve seguire rigorosamente le direttive descritte in [`docs/APP_ARCHITECTURE_STANDARD.md`](../docs/APP_ARCHITECTURE_STANDARD.md).

## 1. Obiettivo e Panoramica
Sviluppare l'applicazione della nave **Long-Range Sensor Array & Tactical Map** (`Applications/Sensors`) per *Dark Nova: Rogue Squadron* (GodotOS).
Il sistema fornisce una mappa tattica spaziale 2D/3D con radar a lungo raggio fino a 50 km, tracciamento entità, modalità di scansione (Passiva / Ping Attivo), analisi spettrometrica dei minerali/relitti e trasmissione di waypoint a *Flight Control* e *Weapons*.

- **Tipologia di Applicazione**: **Applicazione del Server (Nave)**.
  - Disponibile e operativa esclusivamente a missione avviata (`SpaceWorldManager.is_ship_connected() == true`).
  - In stato offline / lobby deve mostrare l'overlay bloccante `%DisconnectedOverlay`.

---

## 2. Standard Architetturali e Flusso Git
1. **Flusso Git (Obbligatorio)**:
   - Creare ed eseguire il checkout sul branch dedicato partendo da `main`: `git checkout -b applications/Sensors main`.
   - Sviluppare il codice, configurazioni e test esclusivamente all'interno di tale branch.
   - Al termine dello sviluppo e dopo aver validato con successo i test:
     1. Eseguire il commit di tutte le modifiche: `git add .` e `git commit -m "feat(sensors): implementa array sensori e mappa tattica"`.
     2. Passare al branch `main`: `git checkout main`.
     3. Eseguire il merge del branch completato: `git merge applications/Sensors`.
2. **Struttura dei File e Cartelle**:
   ```text
   Applications/
   └── Sensors/
       ├── sensors_app.tscn          # Scena principale (Control UI, dimensioni 750x550)
       ├── sensors_app.gd            # Script controller interfaccia
       └── Components/               # Componenti e widget dedicati
           ├── radar_display.tscn    # Widget radar polare/cartesiano
           └── radar_display.gd

   tests/
   ├── test_sensors_app.tscn         # Scena runner per test headless
   └── test_sensors_app_node.gd      # Script di test headless con asserzioni
   ```

---

## 3. Anatomia UI, Layout e Contenimento Finestra
- **Nodo Radice**: `Control` (o `PanelContainer`) con `custom_minimum_size = Vector2(750, 550)`.
- **Regole di Layout**: Nessun elemento deve sbordare dai confini della finestra. Usare `Container` responsivi (`VBoxContainer`, `HBoxContainer`, `MarginContainer`, `ScrollContainer`).
- **Gerarchia Raccomandata**:
  ```text
  SensorsApp (Control) [custom_minimum_size: 750x550]
  ├── VBoxContainer (MainLayout)
  │   ├── HeaderBar (HBoxContainer)          # Titolo ("ARRAY SENSORI & MAPPA TATTICA"), badge stato, pulsante "🔄 Ricarica .DAT"
  │   ├── ContentContainer (MarginContainer) # Area operativa (Radar 2D/3D + Pannello Spettrometria & Controlli)
  │   └── StatusBar (HBoxContainer)           # %StatusLabel, frequenza sweep, consumi MW, ping
  └── %DisconnectedOverlay (Panel)           # Overlay a schermo intero visibile quando disconnesso
      └── CenterContainer
          └── VBoxContainer
              ├── Label ("⚠️ SISTEMI RADAR OFFLINE")
              └── Label ("In attesa di connessione alla nave / Avvio missione...")
  ```

---

## 4. Matrice RBAC (Role-Based Access Control)
- **Soldato** / **Hacker**: **Controllo Completo** (sweep radar, impostazione filtri, trigger Ping Attivo, analisi spettrometrica, lock e marcatura bersagli).
- **Capitano** / **Factotum** / **Solo Mode**: **Controllo Completo e Override**.
- **Pilota** / **Ingegnere**: **Sola Visualizzazione** telemetrica e ricezione automatica dei waypoint inviati.

---

## 5. Pattern GDScript e Ciclo di Vita (`sensors_app.gd`)
Lo script controller deve implementare il pattern standard di `APP_ARCHITECTURE_STANDARD.md`:
- Costanti: `APP_TITLE = "ARRAY SENSORI & RADAR"`, `DEFAULT_WINDOW_SIZE = Vector2(750, 550)`.
- Riferimenti via *Unique Names* (`%DisconnectedOverlay`, `%StatusLabel`, ecc.).
- Collegamento segnali in `_connect_system_signals()`:
  - `SpaceWorldManager.ship_connection_changed` -> `_on_ship_connection_changed(is_connected: bool)`
  - `NetworkManager.player_role_changed` -> `_on_player_role_changed(peer_id: int, new_role: String)`
  - `ShipDriveManager.file_modified` -> `_on_drive_file_modified(rel_path: String)` (Hot-reloading)
- Disconnessione pulita di tutti i segnali in `_exit_tree()`.
- Metodi di parsing standard: `_parse_dat_file(rel_path: String) -> Dictionary`, `load_dat_configuration()`, `_apply_configuration()`.

---

## 6. Configurazione `.DAT`, Drive Protetti e Hackwarfare
- **Percorso Cartella Protetta**: `Ship Drive/Programs/Sensors/` (Sincronizzata su Ship Drive).
- **Password di Debug**: `SENS-7815`.
- **File di Configurazione Standard**:
  - `Ship Drive/Programs/Sensors/sensors_config.dat`:
    ```ini
    [SYSTEM]
    app_name=SensorsApp
    version=1.0.0
    status=OPERATIONAL

    [SWEEP]
    sweep_frequency_hz=12.0
    active_ping_radius=50000.0
    noise_filter=0.92
    ```
  - `Ship Drive/Programs/Sensors/radar_tuning.dat`:
    ```ini
    [TUNING]
    spectrum_sensitivity=1.0
    iff_auto_tag=true
    stealth_detection_threshold=0.35
    ```
- **Protezione Diegetica**: I file `.dat` non sono leggibili dal File Reader standard e contengono firmware attivi a runtime.
- **Integrazione Diagnostics**: Registrare i file predefiniti e la password debug `SENS-7815` in `Applications/Diagnostics/diagnostics_app.gd` per supportare il factory reset firmware.

---

## 7. Integrazione con ShipBlueprint & Sublayer
- **Sublayer 3 (Rete Elettrica)**: Consumo associato al dispositivo `sensors_radar` (40 MW in sweep passivo, 120 MW in ping attivo).
- **Sublayer 4 (Danni)**: Generazione di falsi positivi / "radar ghosts" o zone d'ombra in caso di danni al radar.
- **Sublayer 6 (Mainframe Installed Apps)**: Registrare l'app in `installed_apps` di `ShipBlueprint`:
  - `id`: `"sensors"`
  - `title`: `"Array Sensori & Mappa Tattica"`
  - `description`: `"Mappa telemetrica spaziale a lungo raggio e spettrometria"`
  - `scene_path`: `"res://Applications/Sensors/sensors_app.tscn"`
  - `icon_color`: `Color(0.2, 0.8, 0.4)`
  - `roles`: `["Soldier", "Hacker", "Captain", "Factotum"]`

---

## 8. Suite di Test Headless (`tests/`)
Creare i file di test headless secondo lo standard:
- `tests/test_sensors_app.tscn`: Scena runner minimale.
- `tests/test_sensors_app_node.gd`: Script con test di validazione terminanti con `get_tree().quit(0)` o `get_tree().quit(1)`:
  1. **Overlay / Ciclo di Vita**: Verifica che `%DisconnectedOverlay` sia visibile offline e scompaia al segnale `ship_connection_changed(true)`.
  2. **RBAC**: Verifica che i controlli di scansione attiva siano abilitati solo per Soldato, Hacker, Capitano, Factotum e Solo Mode.
  3. **File .DAT e Hot-Reload**: Verifica parsing corretto di `sensors_config.dat` e `radar_tuning.dat` e ricaricamento su modifica.
  4. **Pulizia Segnali**: Verifica assenza di leak o segnali orfani dopo `_exit_tree()`.

---

## 9. Checklist di Verifica Finale (Conforme a APP_ARCHITECTURE_STANDARD.md)
- [ ] Flusso Git completato: sviluppo su `applications/Sensors`, commit finale e merge in `main`.
- [ ] Rispetto della tipologia Server (Nave) con blocco offline.
- [ ] Cartella protetta `Ship Drive/Programs/Sensors/` creata con password `SENS-7815`.
- [ ] File `.dat` non leggibili da File Reader e parsing tramite `_parse_dat_file`.
- [ ] Hot-reloading attivo su `file_modified` e pulsante `🔄 Ricarica .DAT` presente nella UI.
- [ ] Finestra senza sbordamento e layout responsivo (`custom_minimum_size: 750x550`).
- [ ] Registrazione in `ShipBlueprint` con filtro ruoli RBAC.
- [ ] Suite di test headless (`tests/test_sensors_app.tscn` + `tests/test_sensors_app_node.gd`) funzionante e con esito verde.
