# TASK: Sviluppo Applicazione "External Service Drone & EVA Operations" (`Applications/ServiceDrone`)

> **Riferimento Standard Architetturale**: Lo sviluppo di questa applicazione deve seguire rigorosamente le direttive descritte in [`docs/APP_ARCHITECTURE_STANDARD.md`](../docs/APP_ARCHITECTURE_STANDARD.md).

## 1. Obiettivo e Panoramica
Sviluppare l'applicazione **External Service Drone & EVA Operations** (`Applications/ServiceDrone`) per *Dark Nova: Rogue Squadron* (GodotOS).
L'applicazione controlla un drone teleguidato extra-veicolare (EVA) per ispezioni e riparazioni esterne allo scafo, saldatura di falle (`dmg_breach`), raccolta cargo/detriti nello spazio profondo tramite raggio traente (Harpoon magnetico) e sabotaggio/taglio laser di componenti su navi e relitti disabilitati.

- **Tipologia di Applicazione**: **Applicazione del Server (Nave)**.
  - Disponibile e operativa a bordo della corvetta a missione attiva (`SpaceWorldManager.is_ship_connected() == true`).
  - In stato offline / lobby deve mostrare l'overlay bloccante `%DisconnectedOverlay`.

---

## 2. Standard Architetturali e Flusso Git
1. **Flusso Git (Obbligatorio)**:
   - Prima di iniziare qualsiasi modifica, creare ed eseguire il checkout sul branch dedicato: `applications/ServiceDrone`.
   - Eseguire tutte le modifiche esclusivamente all'interno di tale branch e concludere con un commit descrittivo.
2. **Struttura dei File e Cartelle**:
   ```text
   Applications/
   └── ServiceDrone/
       ├── service_drone_app.tscn         # Scena principale (Control UI, dimensioni 720x520)
       ├── service_drone_app.gd           # Script controller interfaccia
       └── Components/                    # Componenti e widget UI di controllo braccio/thruster
           ├── manipulator_control.tscn
           └── manipulator_control.gd

   Outside/
   └── ServiceDrone/
       ├── service_drone_entity.tscn      # Scena entità fisica 3D nello spazio
       └── service_drone_entity.gd        # Script simulazione fisica e telecamera 3D

   tests/
   ├── test_service_drone_app.tscn        # Scena runner per test headless
   └── test_service_drone_app_node.gd     # Script di test headless con asserzioni
   ```

---

## 3. Anatomia UI, Layout e Contenimento Finestra
- **Nodo Radice**: `Control` (o `PanelContainer`) con `custom_minimum_size = Vector2(720, 520)`.
- **Regole di Layout**: Nessun elemento deve sbordare dai confini della finestra. Usare `Container` responsivi (`VBoxContainer`, `HBoxContainer`, `MarginContainer`, `ScrollContainer`) per racchiudere feed `SubViewport` e telemetria.
- **Gerarchia Raccomandata**:
  ```text
  ServiceDroneApp (Control) [custom_minimum_size: 720x520]
  ├── VBoxContainer (MainLayout)
  │   ├── HeaderBar (HBoxContainer)          # Titolo ("DRONE DI SERVIZIO EVA"), badge stato, pulsante "🔄 Ricarica .DAT"
  │   ├── ContentContainer (MarginContainer) # Area operativa (Feed 3D SubViewport + Pannello Telemetria & Braccio Manipolatore)
  │   └── StatusBar (HBoxContainer)           # %StatusLabel, distanza nave madre, batteria %, slot cargo
  └── %DisconnectedOverlay (Panel)           # Overlay a schermo intero visibile quando disconnesso
      └── CenterContainer
          └── VBoxContainer
              ├── Label ("⚠️ BAIA DRONI EVA OFFLINE")
              └── Label ("In attesa di connessione alla nave / Avvio missione...")
  ```

---

## 4. Matrice RBAC (Role-Based Access Control)
- **Ingegnere**: **Controllo Completo** (riparazioni esterne scafo, saldatura falle, recupero risorse cargo, docking).
- **Hacker**: **Controllo Completo** (sabotaggio moduli esterni, taglio laser paratie relitti, hacking ravvicinato).
- **Capitano** / **Factotum** / **Solo Mode**: **Controllo Completo e Override**.
- **Pilota** / **Soldato**: **Sola Visualizzazione** del feed telecamera EVA e telemetria drone.

---

## 5. Pattern GDScript e Ciclo di Vita (`service_drone_app.gd`)
Lo script controller deve implementare il pattern standard di `APP_ARCHITECTURE_STANDARD.md`:
- Costanti: `APP_TITLE = "DRONE DI SERVIZIO EVA"`, `DEFAULT_WINDOW_SIZE = Vector2(720, 520)`.
- Riferimenti via *Unique Names* (`%DisconnectedOverlay`, `%StatusLabel`, ecc.).
- Collegamento segnali in `_connect_system_signals()`:
  - `SpaceWorldManager.ship_connection_changed` -> `_on_ship_connection_changed(is_connected: bool)`
  - `NetworkManager.player_role_changed` -> `_on_player_role_changed(peer_id: int, new_role: String)`
  - `ShipDriveManager.file_modified` -> `_on_drive_file_modified(rel_path: String)` (Hot-reloading)
- Disconnessione pulita di tutti i segnali in `_exit_tree()`.
- Metodi di parsing standard: `_parse_dat_file(rel_path: String) -> Dictionary`, `load_dat_configuration()`, `_apply_configuration()`.

---

## 6. Configurazione `.DAT`, Drive Protetti e Hackwarfare
- **Percorso Cartella Protetta**: `Ship Drive/Programs/ServiceDrone/` (Sincronizzata su Ship Drive).
- **Password di Debug**: `SERV-7815`.
- **File di Configurazione Standard**:
  - `Ship Drive/Programs/ServiceDrone/service_drone_config.dat`:
    ```ini
    [SYSTEM]
    app_name=ServiceDroneApp
    version=1.0.0
    status=OPERATIONAL

    [FLIGHT]
    max_thrust=35.0
    battery_capacity_sec=240.0
    tether_range=1500.0
    auto_dock_speed=12.0
    ```
  - `Ship Drive/Programs/ServiceDrone/manipulator_tuning.dat`:
    ```ini
    [TOOLS]
    repair_rate=15.0
    cutting_laser_power=25.0
    cargo_capacity_kg=500.0
    magnet_range=18.0
    ```
- **Protezione Diegetica**: I file `.dat` non sono leggibili dal File Reader standard e contengono parametri fisici attivi a runtime.
- **Integrazione Diagnostics**: Registrare i file predefiniti e la password debug `SERV-7815` in `Applications/Diagnostics/diagnostics_app.gd` per supportare il factory reset firmware.

---

## 7. Integrazione con Sublayer ed Entità 3D
- **Simulazione 3D (`SpaceWorldManager`)**: Spawning e gestione dell'entità 3D `ServiceDrone` attorno alla corvetta (raggio max 1500 m).
- **Sublayer 3 (Rete Elettrica)**: Baia droni esterna (`service_bay`, 80 MW in standby, 140 MW in ricarica rapida).
- **Sublayer 4 (Danni)**: Interazione diretta con le coordinate di breccia scafo per la saldatura e il ripristino.
- **Sublayer 6 (Mainframe Installed Apps)**: Registrare l'app in `installed_apps` di `ShipBlueprint`:
  - `id`: `"service_drone"`
  - `title`: `"Drone di Servizio EVA"`
  - `description`: `"Controllo drone extra-veicolare per riparazioni esterne, salvataggio e taglio laser"`
  - `scene_path`: `"res://Applications/ServiceDrone/service_drone_app.tscn"`
  - `icon_color`: `Color(0.9, 0.5, 0.2)`
  - `roles`: `["Engineer", "Hacker", "Captain", "Factotum"]`

---

## 8. Suite di Test Headless (`tests/`)
Creare i file di test headless secondo lo standard:
- `tests/test_service_drone_app.tscn`: Scena runner minimale.
- `tests/test_service_drone_app_node.gd`: Script con test di validazione terminanti con `get_tree().quit(0)` o `get_tree().quit(1)`:
  1. **Overlay / Ciclo di Vita**: Verifica che `%DisconnectedOverlay` sia visibile offline e scompaia al segnale `ship_connection_changed(true)`.
  2. **RBAC**: Verifica che i comandi di decollo drone e braccio siano attivi solo per Ingegnere, Hacker, Capitano, Factotum e Solo Mode.
  3. **File .DAT e Hot-Reload**: Verifica parsing corretto di `service_drone_config.dat` e `manipulator_tuning.dat` e hot-reloading su modifica.
  4. **Pulizia Segnali**: Verifica assenza di memory leak o segnali orfani dopo `_exit_tree()`.

---

## 9. Checklist di Verifica Finale (Conforme a APP_ARCHITECTURE_STANDARD.md)
- [ ] Flusso Git su branch `applications/ServiceDrone` con commit finale.
- [ ] Rispetto della tipologia Server (Nave) con blocco offline.
- [ ] Cartella protetta `Ship Drive/Programs/ServiceDrone/` creata con password `SERV-7815`.
- [ ] File `.dat` non leggibili da File Reader e parsing tramite `_parse_dat_file`.
- [ ] Hot-reloading attivo su `file_modified` e pulsante `🔄 Ricarica .DAT` presente nella UI.
- [ ] Finestra senza sbordamento e layout responsivo (`custom_minimum_size: 720x520`).
- [ ] Registrazione in `ShipBlueprint` con filtro ruoli RBAC.
- [ ] Suite di test headless (`tests/test_service_drone_app.tscn` + `tests/test_service_drone_app_node.gd`) funzionante e con esito verde.
