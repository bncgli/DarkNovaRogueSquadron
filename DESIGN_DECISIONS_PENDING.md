# Decisioni di Design in Sospeso

Questo file raccoglie i problemi individuati durante l'audit del codice che **non sono stati corretti automaticamente** perché richiedono una decisione di design umana (non sono bug "puri", ma scelte di comportamento/architettura). Scrivi la tua risposta/decisione sotto ogni punto, nella sezione "**Risposta:**", così potremo procedere con l'implementazione coerente.

---

## 1. Stato incoerente della documentazione `NetworkManager` — ✅ RISOLTO

**Problema:** La documentazione descriveva `NetworkManager` come placeholder in alcune parti e come sistema completo in altre; non era chiaro quale fosse lo stato reale voluto.

**Domanda:** `NetworkManager` deve essere considerato un sistema multiplayer completo e mantenuto, oppure è ancora un placeholder da non usare/documentare come definitivo?

**Risposta:** `NetworkManager` rimane un sistema multiplayer completo e mantenuto da usare come definitivo, ma incapsulato per gestire eventuali improvement futuri come l'integrazione con Steam.

**Implementazione:** Il backend di trasporto (ENet) è incapsulato dietro l'interfaccia astratta `NetworkTransport` (`Scenes/Networking/network_transport.gd`), con `ENetTransport` come implementazione concreta corrente (`Scenes/Networking/enet_transport.gd`). L'API pubblica di `NetworkManager` (segnali, RPC, `player_role`, RBAC, ecc.) resta invariata; un backend alternativo (es. Steamworks) potrà essere aggiunto in futuro implementando una nuova sottoclasse di `NetworkTransport` e passandola a `set_transport()`, senza modificare i chiamanti esterni. I riferimenti alla documentazione che descrivevano il sistema come "placeholder" sono stati corretti.


---

## 2. Segnali `ShipDriveManagerSingleton` senza listener — 📋 REPORT (in attesa di conferma)

**Problema:** `ShipDriveManagerSingleton` emette dei segnali che al momento non hanno alcun listener collegato nel resto del codice.

**Domanda:** Questi segnali sono previsti per funzionalità future (da collegare in seguito) o sono residui da rimuovere?

**Risposta:** Quali sono i segnali che non vengono utilizzati? In teoria, gestendo la sincronizzazione dei file dovrebbero essere mantenuti tutti.

**Report (nessun segnale è stato rimosso, come richiesto):** dei segnali dichiarati in `Scenes/Autoloads/ShipDrive/ship_drive_manager.gd`:
- `ship_drive_mounted()` → con listener (Cams, Diagnostics, DuctDrone, FlightControl).
- `ship_drive_unmounted()` → con listener (Diagnostics).
- `file_synced(path)` → con listener (numerosissimi: Cams, CargoBay, Comms, Diagnostics, DuctDrone, FlightControl, HackExploits, LifeSupport, PowerGrid, Sensors, ServiceDrone, ShieldMatrix, StationHub, SystemMap, Weapons, cruise_drive_controller).
- `drive_synced()` → con listener (Sensors, Weapons).
- `folder_synced(path)` → **nessun listener** in tutto il codebase.
- `folder_password_synced(path)` → **nessun listener** in tutto il codebase.
- `item_deleted(path)` → **nessun listener** in tutto il codebase.
- `item_renamed(old_path, new_path)` → **nessun listener** in tutto il codebase.

Quindi i segnali attualmente senza alcun listener sono: `folder_synced`, `folder_password_synced`, `item_deleted`, `item_renamed`. Tutti i segnali sono stati mantenuti nel codice, come richiesto.


---

## 3. Refactor incompleto `DuctDroneManager` / `ShipDamageManager` — ✅ RISOLTO

**Problema:** In `space_world_manager.gd` è presente logica duplicata rispetto a `DuctDroneManager`/`ShipDamageManager`, segno di un refactor iniziato ma non completato.

**Domanda:** Vuoi che si completi il refactor spostando la logica duplicata nei manager dedicati, oppure preferisci mantenere la logica centralizzata in `space_world_manager.gd`?

**Risposta:** Sposta la logica dedicata nei manager dedicati.

**Implementazione:** `DuctDroneManager` ora possiede realmente lo stato del drone (posizione, batteria, input, config) e la logica di fisica/movimento/riparazione. `ShipDamageManager` gestisce l'array tipizzato di danni nave (spawn/reveal/repair/sync). `space_world_manager.gd` non duplica più questa logica: le vecchie variabili sono diventate proprietà che delegano ai manager dedicati, mantenendo invariata l'API pubblica (`SpaceWorldManagerSingleton`) usata dal resto del codice. Verificato con l'intera suite GUT (290/290 test passati).


---

## 4. Campi `.dat` morti in Comms/PowerGrid — 📋 REPORT (in attesa di decisione)

**Problema:** Alcuni campi presenti nei file `.dat` di configurazione di Comms e PowerGrid non vengono letti/utilizzati da nessuna parte del codice.

**Domanda:** Questi campi sono funzionalità pianificate ma non ancora implementate, oppure vanno rimossi dai file `.dat` perché obsoleti?

**Risposta:** Elencali e lascia a me la gestione dei suddetti campi.

**Report:**

*Comms* — campi morti (mai letti nel codice) tra quelli definiti nel `.dat` di default (`comms_config.dat`/`crypto_tuning.dat`, presenti in `comms_app.tres`, `diagnostics_app.gd`, `ship_drive_manager.gd`): `app_name`, `version`, `status`, `comms_subsystem`, `subspace_relay_active`, `default_freq_mhz`, `bandwidth_hz`, `signal_amplification`, `signal_noise_ratio`, `auto_tune_sos`, `jamming_power_mw`, `jamming_radius`, `spoofing_signature`, `overclock_ew_boost`, `decryption_speed_multiplier`, `crypto_crack_speed`, `matrix_layers`, `auto_archive_decrypted`. (`decryption_key` invece è vivo: letto dai comandi Terminal `decript_command.gd`/`dataread_command.gd` per il minigioco di hacking.) `comms_app.gd` legge da `active_config` solo `auto_rotate_speed` e `reception_cone_deg`, che però non sono definiti nei `.dat` di default.

*PowerGrid* — campi morti tra quelli definiti nel `.dat` di default (`power_grid_config.dat`/`grid_tuning.dat`): `app_name`, `version`, `status`, `mode`, `reactor_output_mw`, `aux_generator_mw`, `junction_switch_delay`, `overload_threshold_pct`, `reroute_efficiency_loss`, `breaker_trip_threshold`, `short_circuit_damping`, `auto_reroute_on_short`, `power_efficiency_mult`, `backup_line_conductivity`, `switch_rate_hz`, `regime_boost`, `overclock_tolerance`. (`decryption_key` vivo, stesso discorso di Comms.) `power_grid_app.gd` legge da `active_config` solo il flag sintetico `is_dat_loaded` (non proveniente dal `.dat`); la logica di bilanciamento energetico lavora sui dati stanza della `ShipBlueprint`, non sul `.dat`.

Nessuna modifica ai file `.dat` è stata fatta: in attesa di indicazioni su quali campi rendere funzionali e quali rimuovere.


---

## 5. Assenza di Undo/Redo in `star_system_editor` — ✅ RISOLTO

**Problema:** L'editor `star_system_editor` non dispone di un sistema di Undo/Redo per le modifiche fatte alle entità dei sistemi stellari.

**Domanda:** Vuoi che venga implementato un sistema di Undo/Redo (es. tramite `EditorUndoRedoManager` di Godot) per questo editor?

**Risposta:** Lo star system editor è ancora in una fase di sviluppo. aggiungi il sistema di undo/redo.

**Implementazione:** aggiunto supporto completo a `EditorUndoRedoManager` (iniettato dal plugin tramite `get_undo_redo()`): tutte le operazioni su entità (aggiunta/rimozione/spostamento corpi celesti, modifica proprietà via inspector, creazione settori custom, aggiunta/rimozione pericoli) sono ora annullabili/ripetibili tramite `create_action`/`add_do_method`/`add_undo_method`/`commit_action`. Contestualmente è stata completata anche la migrazione a scena `.tscn` (vedi nota di documentazione più sotto).


---

## 6. `credits` locale di StationHub non sincronizzato con `FluxEconomyManager` — ✅ RISOLTO

**Problema:** StationHub gestisce una variabile `credits` locale che non risulta sincronizzata con la fonte di verità economica `FluxEconomyManager`, con rischio di incoerenza tra i due valori mostrati/usati.

**Domanda:** Vuoi che StationHub venga aggiornato per leggere/scrivere sempre direttamente da `FluxEconomyManager` (rimuovendo la variabile locale), oppure la duplicazione è intenzionale per un motivo specifico (es. cache locale, modalità offline)?

**Risposta:** FluxEconomyManager al momento è sbagliato, non esistono i crediti in questa ambientazione ma soltanto i crediti, la logica è come quella di scambiarsi rate della macchina venduta per pagare le rate di una moto, principalmente è un baratto di crediti/debiti. FluxEconomyManager deve essere riscritto. perciò rimuovi credidi da StationHub ma non fare nient'altro

**Implementazione:** rimossa la variabile locale `credits` da `StationHubApp`; tutte le letture/scritture passano ora dagli helper `_get_credits()`/`_spend_credits()`/`_add_credits()`, che operano direttamente su `flux_mgr.credits` (propagando anche `credits_changed`). Rimosso anche il campo `default_credits` dal `.dat` di configurazione e dal relativo parsing. Nessun'altra modifica è stata fatta a `FluxEconomyManager`, la cui riscrittura resta un compito separato da definire in seguito, come richiesto. Test aggiornati (`test_station_services_hub.gd`, `test_stations_docking.gd`) e verificati: tutti passano.



---

## Note aggiuntive di documentazione (rilevate da Archivist)

Questi punti sono relativi alla documentazione del progetto (non al codice) e sono elencati qui per completezza, se vuoi darci indicazioni su come procedere:

- **README obsoleto**: da aggiornare per riflettere lo stato attuale del progetto.
- **Design doc `DARK_NOVA_FEATURES_DESIGN.md` disallineato** su più app (Weapons/ShieldMatrix/Comms/Sensors/CargoBay): descrive funzionalità diverse da quelle effettivamente implementate.
- **Riferimenti rotti in `TODO.md`** verso vecchi file `task_queue/*.md` non più esistenti.
- **Migrazione incompleta di `star_system_editor`** a scene `.tscn`: parte dell'editor è ancora costruita a codice invece che tramite scene.

**Risposta:**
- **README obsoleto**: da aggiornare per riflettere lo stato attuale del progetto. --> Riscrivi il readme da zero come una guida introduttiva per gli utenti.
- **Design doc `DARK_NOVA_FEATURES_DESIGN.md` disallineato** su più app (Weapons/ShieldMatrix/Comms/Sensors/CargoBay): descrive funzionalità diverse da quelle effettivamente implementate. --> Aggiornalo
- **Riferimenti rotti in `TODO.md`** verso vecchi file `task_queue/*.md` non più esistenti. --> Rimuovi i riferimenti rotti
- **Migrazione incompleta di `star_system_editor`** a scene `.tscn`: parte dell'editor è ancora costruita a codice invece che tramite scene. --> Migra completamente l'editor a scene `.tscn`

**Implementazione (✅ RISOLTO):**
- `README.md` riscritto da zero come guida introduttiva per gli utenti (ambientazione, avvio, panoramica app implementate, controlli).
- `docs/DARK_NOVA_FEATURES_DESIGN.md` aggiornato per Weapons/ShieldMatrix/Comms/Sensors/CargoBay in base al codice reale delle rispettive app.
- `TODO.md`: rimossi i riferimenti ai file `task_queue/*.md` non più esistenti (`001_ship_blueprint_flux.md`, `002_app_flux_wallet.md`, `003_ship_editor_improvements.md`); gli altri 28 riferimenti sono stati verificati come validi e lasciati intatti.
- `star_system_editor`: l'intera interfaccia statica è stata migrata in `addons/star_system_editor/star_system_editor.tscn`; lo script `star_system_editor.gd` contiene ora solo riferimenti `@onready`/`%Nome` e logica di gestione eventi (le sole righe UI generate a runtime sono quelle intrinsecamente dipendenti dai dati, es. righe dell'inspector per entità/pericoli selezionati, analogamente all'Inspector nativo di Godot).
