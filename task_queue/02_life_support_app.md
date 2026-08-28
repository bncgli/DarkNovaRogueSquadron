# TASK: Sviluppo Applicazione "Life Support & Atmosphere Control" (`Applications/LifeSupport`)

> **Riferimento Standard Architetturale**: Lo sviluppo di questa applicazione deve seguire rigorosamente le direttive descritte in [`docs/APP_ARCHITECTURE_STANDARD.md`](../docs/APP_ARCHITECTURE_STANDARD.md).

## 1. Obiettivo e Panoramica
Sviluppare l'applicazione della nave **Life Support & Atmosphere Control** (`Applications/LifeSupport`) per *Dark Nova: Rogue Squadron* (GodotOS).
Il sistema consente il monitoraggio e controllo attivo dei parametri vitali (O2 %, CO2 %, pressione barometrica, temperatura, presenza incendi e fumo) per ciascun compartimento/stanza della corvetta stellare, con gestione delle paratie stagne e iniezione di gas inerte antincendio.

- **Tipologia di Applicazione**: **Applicazione del Server (Nave)**.
  - Disponibile e operativa esclusivamente a missione avviata (`SpaceWorldManager.is_ship_connected() == true`).
  - In stato offline / lobby deve mostrare l'overlay bloccante `%DisconnectedOverlay`.

---

## 2. Standard Architetturali e Flusso Git
1. **Flusso Git (Obbligatorio)**:
   - Creare ed eseguire il checkout sul branch dedicato partendo da `main`: `git checkout -b applications/LifeSupport main`.
   - Sviluppare il codice, configurazioni e test esclusivamente all'interno di tale branch.
   - Al termine dello sviluppo e dopo aver validato con successo i test:
     1. Eseguire il commit di tutte le modifiche: `git add .` e `git commit -m "feat(life-support): implementa supporto vitale e controllo atmosfera"`.
     2. Passare al branch `main`: `git checkout main`.
     3. Eseguire il merge del branch completato: `git merge applications/LifeSupport`.
2. **Struttura dei File e Cartelle**:
   ```text
   Applications/
   └── LifeSupport/
       ├── life_support_app.tscn     # Scena principale (Control UI, dimensioni 700x500)
       ├── life_support_app.gd       # Script controller interfaccia
       ├── life_support_app.tres     # Risorsa ShipAppResource con metadati, RBAC e file .dat
       └── Components/               # Componenti e widget dedicati
           ├── room_atmo_card.tscn   # Widget monitoraggio/controllo singola stanza
           └── room_atmo_card.gd

   tests/
   ├── test_life_support_app.tscn    # Scena runner per test headless
   └── test_life_support_app_node.gd # Script di test headless con asserzioni
   ```

---

## 3. Anatomia UI, Layout e Contenimento Finestra
- **Nodo Radice**: `Control` (o `PanelContainer`) con `custom_minimum_size = Vector2(700, 500)`.
- **Regole di Layout**: Nessun elemento deve sbordare dai confini della finestra. Usare `Container` responsivi (`VBoxContainer`, `HBoxContainer`, `GridContainer`, `MarginContainer`, `ScrollContainer`).
- **Gerarchia Raccomandata**:
  ```text
  LifeSupportApp (Control) [custom_minimum_size: 700x500]
  ├── VBoxContainer (MainLayout)
  │   ├── HeaderBar (HBoxContainer)          # Titolo ("SUPPORTO VITALE & ATMOSFERA"), badge stato globale, pulsante "🔄 Ricarica .DAT"
  │   ├── ContentContainer (MarginContainer) # Area operativa (Mappa schematica stanze 2D + Pannello Paratie & Antincendio)
  │   └── StatusBar (HBoxContainer)           # %StatusLabel, O2 totale medio, pressione media, allarmi attivi
  └── %DisconnectedOverlay (Panel)           # Overlay a schermo intero visibile quando disconnesso
      └── CenterContainer
          └── VBoxContainer
              ├── Label ("⚠️ SUPPORTO VITALE OFFLINE")
              └── Label ("In attesa di connessione alla nave / Avvio missione...")
  ```

---

## 4. Matrice RBAC (Role-Based Access Control)
- **Ingegnere**: **Controllo Completo** (sigillatura paratie stagne, soppressione incendi ad azoto, regolazione scrubber CO2 e flussi miscele O2/N2).
- **Capitano** / **Factotum** / **Solo Mode**: **Controllo Completo e Override**.
- **Pilota** / **Soldato** / **Hacker**: **Sola Visualizzazione** telemetrica e diagnostica ambientale dei compartimenti.

---

## 5. Pattern GDScript e Ciclo di Vita (`life_support_app.gd`)
Lo script controller deve implementare il pattern standard di `APP_ARCHITECTURE_STANDARD.md`:
- Costanti: `APP_TITLE = "SUPPORTO VITALE & CONTROLLO ATMOSFERA"`, `DEFAULT_WINDOW_SIZE = Vector2(700, 500)`.
- Riferimenti via *Unique Names* (`%DisconnectedOverlay`, `%StatusLabel`, ecc.).
- Collegamento segnali in `_connect_system_signals()`:
  - `SpaceWorldManager.ship_connection_changed` -> `_on_ship_connection_changed(is_connected: bool)`
  - `NetworkManager.player_role_changed` -> `_on_player_role_changed(peer_id: int, new_role: String)`
  - `ShipDriveManager.file_modified` -> `_on_drive_file_modified(rel_path: String)` (Hot-reloading)
- Disconnessione pulita di tutti i segnali in `_exit_tree()`.
- Metodi di parsing standard: `_parse_dat_file(rel_path: String) -> Dictionary`, `load_dat_configuration()`, `_apply_configuration()`.

---

## 6. Configurazione `.DAT`, Drive Protetti e Hackwarfare
- **Percorso Cartella Protetta**: `Ship Drive/Programs/LifeSupport/` (Sincronizzata su Ship Drive).
- **Password di Debug**: `LIFE-7815`.
- **File di Configurazione Standard**:
  - `Ship Drive/Programs/LifeSupport/life_support_config.dat`:
    ```ini
    [SYSTEM]
    app_name=LifeSupportApp
    version=1.0.0
    status=OPERATIONAL

    [OXYGEN]
    o2_generation_rate=1.2
    seal_door_speed=0.5
    auto_fire_suppress=false
    ```
  - `Ship Drive/Programs/LifeSupport/atmo_tuning.dat`:
    ```ini
    [PARAMETERS]
    decompression_rate=1.8
    fire_suppression_co2_level=0.45
    scrubber_efficiency=0.98
    ```
- **Protezione Diegetica**: I file `.dat` non sono leggibili dal File Reader standard e contengono firmware attivi a runtime.
- **Integrazione Diagnostics**: Registrare i file predefiniti e la password debug `LIFE-7815` in `Applications/Diagnostics/diagnostics_app.gd` per supportare il factory reset firmware.

---

## 7. Integrazione con ShipSoftwareManager, ShipBlueprint & Sublayers
- **ShipAppResource (`life_support_app.tres`)**:
  - `app_id`: `"life_support"`
  - `title`: `"Supporto Vitale & Atmosfera"`
  - `description`: `"Monitoraggio e controllo parametri vitali, O2, paratie e antincendio"`
  - `scene_path`: `"res://Applications/LifeSupport/life_support_app.tscn"`
  - `icon_color`: `Color(0.2, 0.7, 0.9)`
  - `roles`: `["Engineer", "Captain", "Factotum"]`
  - `power_draw_mw`: `20.0`
  - `required_subsystems`: `["life_support_generator"]`
  - `drive_folder`: `"Programs/LifeSupport"`
  - `default_password`: `"LIFE-7815"`
  - `default_files`: configurazioni `life_support_config.dat` e `atmo_tuning.dat`.
- **Sublayer 1 (Stanze)**: Corrispondenza diretta 1:1 con le stanze della blueprint per calcolo volumetrico aria, pressione e O2.
- **Sublayer 2 (Condotti)**: Propagazione fumo e fiamme attraverso i condotti tecnici in caso di incendi nei compartimenti adiacenti.
- **Sublayer 4 (Danni)**: Reazione dinamica alle brecce nello scafo (`dmg_breach`) con rapida perdita di pressione locale.
- **Sublayer 6 (Mainframe Installed Apps)**: Registrare la risorsa in `DEFAULT_SHIP_APP_PATHS` di `ShipSoftwareManager` e in `installed_apps` di `ShipBlueprint`.

---

## 8. Suite di Test Headless (`tests/`)
Creare i file di test headless secondo lo standard:
- `tests/test_life_support_app.tscn`: Scena runner minimale.
- `tests/test_life_support_app_node.gd`: Script con test di validazione terminanti con `get_tree().quit(0)` o `get_tree().quit(1)`:
  1. **Overlay / Ciclo di Vita**: Verifica che `%DisconnectedOverlay` sia visibile offline e scompaia al segnale `ship_connection_changed(true)`.
  2. **RBAC**: Verifica che i controlli di paratie, estintori e regolatori siano abilitati solo per Ingegnere, Capitano, Factotum e Solo Mode.
  3. **File .DAT e Hot-Reload**: Verifica parsing corretto di `life_support_config.dat` e `atmo_tuning.dat` e hot-reloading su modifica.
  4. **Risorsa e Software Manager**: Verifica che `life_support_app.tres` sia registrata e caricata correttamente da `ShipSoftwareManager`.
  5. **Pulizia Segnali**: Verifica assenza di memory leak o segnali orfani dopo `_exit_tree()`.

---

## 9. Checklist di Verifica Finale (Conforme a APP_ARCHITECTURE_STANDARD.md)
- [ ] Flusso Git completato: sviluppo su `applications/LifeSupport`, commit finale e merge in `main`.
- [ ] Rispetto della tipologia Server (Nave) con blocco offline.
- [ ] Creata risorsa `ShipAppResource` (`life_support_app.tres`) e registrata in `ShipSoftwareManager` e `ShipBlueprint`.
- [ ] Cartella protetta `Ship Drive/Programs/LifeSupport/` creata con password `LIFE-7815`.
- [ ] File `.dat` non leggibili da File Reader e parsing tramite `_parse_dat_file`.
- [ ] Hot-reloading attivo su `file_modified` e pulsante `🔄 Ricarica .DAT` presente nella UI.
- [ ] Finestra senza sbordamento e layout responsivo (`custom_minimum_size: 700x500`).
- [ ] Registrazione in `ShipBlueprint` con filtro ruoli RBAC.
- [ ] Suite di test headless (`tests/test_life_support_app.tscn` + `tests/test_life_support_app_node.gd`) funzionante e con esito verde.
