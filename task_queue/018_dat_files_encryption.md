# TASK-030: Standardized Encryption Key Integration for .DAT Configuration Files

## Descrizione
Integrazione di una chiave di decriptazione standardizzata e univoca all'interno di tutti i file `.dat` di sistema e configurazione presenti nel filesystem diegetico (`Ship Drive`), predisponendo la struttura dati per le future applicazioni di violazione informatica e minigiochi di decifrazione/cracking.

## Obiettivi
- Definire e standardizzare il formato della chiave di decriptazione nei file `.dat` (es. sezione `[SECURITY]` con campo `decryption_key = "..."`).
- Aggiornare tutti i template e file `.dat` generati da `ShipDriveManagerSingleton` e memorizzati in `default_ship_blueprint.tres` per includere una chiave di decriptazione diegetica univoca.
- Assicurare che il parser `BaseApp._parse_dat_file` e le app che leggono i file `.dat` gestiscano correttamente la nuova proprietà senza errori di parsing.

## Criteri di Accettazione
- [x] **Standard Decryption Key nei file .DAT**:
  - [x] Ogni file `.dat` (es. `flight_config.dat`, `thrusters_tuning.dat`, `cams_config.dat`, `optics_tuning.dat`, `duct_drone_config.dat`, `power_grid_config.dat`, `weapons_config.dat`, `shields_config.dat`, `comms_config.dat`, `diagnostics_config.dat`, `sensors_config.dat`, `ship_blueprint.dat`, `hull_specs.dat`, ecc.) deve contenere una chiave di decriptazione valida e univoca (es. `decryption_key=HEX_O_STRINGA_CIFRATA`).
- [x] **Compatibilità Parser BaseApp**:
  - [x] `BaseApp._parse_dat_file()` deve leggere `decryption_key` senza compromettere il caricamento dei parametri numerici o booleani del file.
- [x] **Aggiornamento Template ShipDriveManager & Blueprint**:
  - [x] Le stringhe di generazione in `Scenes/Autoloads/ShipDrive/ship_drive_manager.gd` includono la chiave in ciascun file `.dat`.
  - [x] La risorsa predefinita `Outside/ShipSublayer/default_ship_blueprint.tres` contiene le chiavi aggiornate per tutti i file `.dat` del drive di bordo.

## Dettagli Tecnici
- **File coinvolti**:
  - `Scenes/Autoloads/ShipDrive/ship_drive_manager.gd`: Metodo `mount_drive()` / generazione file di default (linee 220-251).
  - `Outside/ShipSublayer/default_ship_blueprint.tres`: Risorse `ShipDriveFile` contenute nella blueprint.
  - `Outside/ShipSublayer/ShipDriveFile.gd`: Eventuale campo esplicito o gestione nel corpo testuale del file.
  - `Applications/BaseApp/base_app.gd`: Metodo `_parse_dat_file(rel_path)`.

## Step by Step Implementation
1. **Definizione dello Standard di Cifratura nei file .DAT**:
   - Stabilire la convenzione: ogni file `.dat` include nell'header o nella sezione `[SECURITY]` la voce `decryption_key = "<CHIAVE_UNIVOCA>"` (es. `decryption_key = "FCTL-78A9-99X"`, `decryption_key = "CAMS-44F1-88Z"`, ecc.).
2. **Aggiornamento di `Scenes/Autoloads/ShipDrive/ship_drive_manager.gd`**:
   - Nelle linee 220-251, aggiornare il contenuto predefinito di ciascun file `.dat` generato:
     - `flight_config.dat`: Aggiungere `decryption_key=FLIGHT-CFG-7815\n`
     - `thrusters_tuning.dat`: Aggiungere `decryption_key=THRUST-TUN-7815\n`
     - `cams_config.dat`: Aggiungere `decryption_key=CAMS-CFG-7815\n`
     - `optics_tuning.dat`: Aggiungere `decryption_key=OPTIC-TUN-7815\n`
     - `duct_drone_config.dat`: Aggiungere `decryption_key=DUCT-CFG-7815\n`
     - `drone_tuning.dat`: Aggiungere `decryption_key=DRONE-TUN-7815\n`
     - `power_grid_config.dat`: Aggiungere `decryption_key=GRID-CFG-7815\n`
     - `grid_tuning.dat`: Aggiungere `decryption_key=GRID-TUN-7815\n`
     - `weapons_config.dat`: Aggiungere `decryption_key=WEAP-CFG-7815\n`
     - `ammo_tuning.dat`: Aggiungere `decryption_key=AMMO-TUN-7815\n`
     - `shields_config.dat`: Aggiungere `decryption_key=SHLD-CFG-7815\n`
     - `deflector_tuning.dat`: Aggiungere `decryption_key=DEFL-TUN-7815\n`
     - `comms_config.dat`: Aggiungere `decryption_key=COMM-CFG-7815\n`
     - `crypto_tuning.dat`: Aggiungere `decryption_key=CRYP-TUN-7815\n`
     - `diagnostics_config.dat`: Aggiungere `decryption_key=DIAG-CFG-7815\n`
     - `security_tuning.dat`: Aggiungere `decryption_key=SECU-TUN-7815\n`
     - `sensors_config.dat`: Aggiungere `decryption_key=SENS-CFG-7815\n`
     - `radar_tuning.dat`: Aggiungere `decryption_key=RADR-TUN-7815\n`
     - `ship_blueprint.dat`: Aggiungere `decryption_key=BLUP-SYS-7815\n`
     - `hull_specs.dat`: Aggiungere `decryption_key=HULL-SYS-7815\n`
3. **Aggiornamento di `Outside/ShipSublayer/default_ship_blueprint.tres`**:
   - Inserire le medesime chiavi di decriptazione all'interno del campo `content` di ciascun sotto-elemento `ShipDriveFile` corrispondente.
4. **Verifica in `Applications/BaseApp/base_app.gd`**:
   - Assicurarsi che `_parse_dat_file(rel_path)` legga correttamente `result["decryption_key"]` come `String` preservando l'integrità dei parametri applicativi.
