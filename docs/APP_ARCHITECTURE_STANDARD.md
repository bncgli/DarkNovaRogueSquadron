# Standard Architetturale per le Applicazioni GodotOS (Dark Nova: Rogue Squadron)

> **Istruzioni per l'Agente AI**: Questo documento costituisce il set di istruzioni specifiche e vincolanti per l'agente AI incaricato della creazione, refactoring o manutenzione delle applicazioni all'interno del sistema operativo di bordo **GodotOS**.
> Per la progettazione di nuove funzionalità o applicazioni prima dello sviluppo, fare riferimento al modello [Feature Design Document (FDD)](FEATURE_DESIGN_TEMPLATE.md).

### Flusso di Lavoro Git (Regola Obbligatoria per l'Agente AI)
Prima di eseguire qualsiasi modifica o sviluppo su un'applicazione, l'agente AI deve seguire rigorosamente questo flusso Git:
1. **Creazione Branch**: Prima di fare qualsiasi modifica, creare un nuovo branch chiamato `applications/<nome programma>` (es. `applications/NomeApp`).
2. **Checkout e Sviluppo su Branch**: Eseguire il checkout sul nuovo branch e svolgere tutte le modifiche esclusivamente all'interno di tale branch.
3. **Commit Finale**: Effettuare un commit al termine di tutte le modifiche con un messaggio descrittivo.

---

## 1. Panoramica e Concetti Chiave

In *Dark Nova: Rogue Squadron*, l'interfaccia di gioco è il desktop virtuale di GodotOS. Ogni stazione dell'equipaggio (Pilota, Ingegnere, Tattico, Sensori, Comunicazioni, ecc.) e ogni utility opera attraverso applicazioni a finestre dedicate.

A partire dalla nuova architettura modulare, **tutte le applicazioni sono modellate come Risorse di Godot (`AppResource`, `ShipAppResource`, `TerminalAppResource`)** e gestite in modo centralizzato da due singleton dedicati:
* **`ShipSoftwareManager`**: gestisce i programmi di bordo, l'integrazione con `ShipBlueprint` (Sublayer 6: *Mainframe Installed Apps*), il popolamento automatico dei file `.dat` e cartelle protette in `Ship Drive`, il calcolo energetico e le autorizzazioni di ruolo (**RBAC**).
* **`TerminalSoftwareManager`**: gestisce i software e le utility locali del terminale/postazione (es. Terminale shell, File Manager, Editor di testo, diagnostica locale) e l'integrazione con `Terminal Drive`.

### Tipologie di Applicazione e Disambiguazione (Regola per l'Agente AI)
Quando i requisiti non sono esplicitamente chiari, l'agente AI **deve chiedere all'utente** se l'applicazione da creare/modificare è un'**Applicazione del Server (Nave)** o un'**Applicazione del Terminale (Locale)**:

1. **Applicazione del Server (Nave)**:
   * Definita tramite una risorsa `.tres` di tipo `ShipAppResource`.
   * Collegata ai sistemi di bordo e alla simulazione della nave.
   * **Ciclo di vita**: Deve essere disponibile e operativa **esclusivamente dopo che la missione è partita** (`is_mission_started == true` / `is_ship_connected() == true`). In lobby o offline deve mostrare l'overlay di blocco/disconnessione.
   * Registrata in `ShipSoftwareManager` e associata alla `ShipBlueprint` di bordo.
2. **Applicazione del Terminale (Locale)**:
   * Definita tramite una risorsa `.tres` di tipo `TerminalAppResource`.
   * Applicazione di utilità o terminale locale indipendente dalla simulazione nave.
   * **Ciclo di vita**: **Non è limitata dallo stato della missione** ed è sempre accessibile e utilizzabile.
   * Registrata in `TerminalSoftwareManager`.

### Principi Fondamentali
1. **Architettura Data-Driven basata su Risorse**: L'aggiunta di un programma richiede la definizione della sua scena UI (`.tscn`) e della corrispondente risorsa esportabile (`.tres`), demandando ai Software Manager la gestione del Drive, delle password e dello Start Menu.
2. **Server-Authoritative (Host-Centrico)**: Per le applicazioni della nave, la simulazione fisica e lo stato risiedono sul Server/Host. I client inviano richieste di comando (`request_*`) e ricevono aggiornamenti di stato.
3. **Controllo Ruoli (RBAC - Role-Based Access Control)**: Ogni applicazione della nave definisce nella propria `ShipAppResource` i ruoli autorizzati (`roles`), consentendo agli altri la sola visualizzazione (telemetria) o nascondendo il programma all'avvio della missione.

---

## 2. File di Configurazione (.dat), Drive e Cartelle Protette

Ogni applicazione deve disporre di una cartella protetta da password contenente i propri file di configurazione in formato `.dat`:

### Percorsi di Salvataggio sui Drive
* **Applicazioni della Nave (Server)**:
  * La cartella con i file deve essere salvata sotto il percorso:
    `Ship Drive/Programs/[NomeApp]/`
  * *Nota fondamentale*: Tutti i file e le cartelle in **Ship Drive** sono sincronizzati in tempo reale tra tutti i giocatori dell'equipaggio.
* **Applicazioni del Terminale**:
  * La cartella con i file deve essere salvata sotto il percorso:
    `Terminal Drive/Programs/[NomeApp]/`
  * I file risiedono localmente nel drive del terminale specifico.

### Proprietà e Comportamento dei File `.dat`
* **Non leggibili dal File Reader**: I file `.dat` non sono leggibili tramite il lettore file / visualizzatore di testo standard del sistema operativo (blocco in `cat` e text editor per file protetti/binari).
* **Natura Protetta e Modifica "Illegale" (Hackwarfare)**:
  - All'interno dell'esperienza diegetica di gioco, i file `.dat` rappresentano i firmware critici di bordo e **non possono essere modificati tramite canali o editor "legali" standard**.
  - Qualsiasi alterazione, overclock o manomissione a runtime dei parametri `.dat` costituisce un'azione clandestina/illecita che sarà gestita e approfondita all'interno della meccanica di **Hackwarfare (Cyber Warfare & Electronic Warfare)**.
* **Valori attivi di runtime**: Contengono parametri e valori effettivi che il programma legge e utilizza attivamente durante l'esecuzione.
* **Impatto sulle prestazioni**: La modifica di tali valori influenza direttamente le prestazioni, l'efficienza e il comportamento del programma, in positivo o in negativo (tuning, sovraccarico, hacking o contromisure).

### Tabella Password di Debug (Sviluppo & Test)
Per agevolare il testing e il debugging interno da parte dello sviluppatore, di seguito è riportata la lista delle password predefinite per le cartelle protette dei programmi in `Ship Drive/Programs/`:

| Applicazione / Directory | Password di Debug | Note |
| :--- | :---: | :--- |
| `Ship Drive/Programs/FlightControls` | `FLIGHT-7815` | Sottosistemi propulsione e RCS |
| `Ship Drive/Programs/Cams` | `CAMS-7815` | Array ottiche e CCTV 6CH |
| `Ship Drive/Programs/DuctDrone` | `DRONE-7815` | Dinamiche drone e radar manutenzione |
| `Ship Drive/Programs/PowerGrid` | `GRID-7815` | Reattore e soglie di rete elettrica |
| `Ship Drive/Programs/Weapons` | `WEAP-7815` | Armi primarie e torrette difensive |
| `Ship Drive/Programs/Sensors` | `SENS-7815` | Scansione stellare a lungo raggio |
| `Ship Drive/Programs/ShieldMatrix` | `SHLD-7815` | Matrice deflettori e scudi quadrante |
| `Ship Drive/Programs/Comms` | `COMM-7815` | Crittografia e guerra elettronica |
| `Ship Drive/Programs/LifeSupport` | `LIFE-7815` | Supporto vitale e pressurizzazione |
| `Ship Drive/Programs/Logbook` | `LOGS-7815` | Registro di bordo e diari |
| `Ship Drive/Programs/Diagnostics` | `DIAG-7815` | Antivirus e scansione registri |
| *Master Debug Override* | `ROOT-7815` | Bypass globale per test suites |

### Struttura Standard del Formato `.dat`
I file `.dat` utilizzano un formato strutturato **INI / Key-Value** leggibile e configurabile:
* Supporto per intestazioni di sezione tra parentesi quadre: `[SYSTEM]`, `[TUNING]`, `[NETWORK]`, ecc.
* Commenti su riga singola che iniziano con `#` o `;`.
* Coppie chiave-valore nel formato `chiave=valore`.
* Esempio di file `.dat`:
```ini
# CONFIGURAZIONE RUNTIME APPLICAZIONE
[SYSTEM]
app_name=NomeApp
version=1.0.0
status=OPERATIONAL

[PARAMETERS]
power_rate=1.0
max_efficiency=0.95
update_interval=0.5
overclock_enabled=true
```

### Metodo Standard di Parsing (`_parse_dat_file`)
Ogni applicazione deve implementare o utilizzare il parser standard a riga singola con type-casting automatico:

```gdscript
## Effettua il parsing di un file .dat (formato INI/Key-Value) dallo storage virtuale
func _parse_dat_file(rel_path: String) -> Dictionary:
	var result: Dictionary = {}
	var abs_path := "user://files/%s" % rel_path
	if not FileAccess.file_exists(abs_path):
		return result
	
	var file := FileAccess.open(abs_path, FileAccess.READ)
	if not file:
		return result
	
	var current_section := ""
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#") or line.begins_with(";"):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			current_section = line.substr(1, line.length() - 2).strip_edges()
			continue
		
		var eq_pos := line.find("=")
		if eq_pos != -1:
			var key := line.substr(0, eq_pos).strip_edges()
			var val_str := line.substr(eq_pos + 1).strip_edges()
			if val_str.is_valid_float():
				result[key] = val_str.to_float()
			elif val_str.is_valid_int():
				result[key] = val_str.to_int()
			else:
				result[key] = val_str
	
	file.close()
	return result
```

### Pipeline di Caricamento, Applicazione e Ricarica a Caldo (Hot-Reloading)
1. **Dizionario di Fallback Predefinito**: L'app deve mantenere un dizionario di configurazione con valori di fabbrica/default pronti all'uso se i file non esistono ancora.
2. **Caricamento e Overwrite (`load_dat_configuration`)**:
   * Legge il percorso primario (`Ship Drive/Programs/[NomeApp]/config.dat`) e/o i percorsi secondari di tuning.
   * Sovrascrive la configurazione attiva con i valori estratti.
   * Chiama una funzione dedicata `_apply_configuration()` per propagare immediatamente i nuovi parametri alla logica dell'app o alla simulazione fisica.
3. **Ascolto Modifiche Live (`file_modified`)**:
   * Connettersi al segnale `file_modified` del gestore drive (`ShipDriveManager` o `BaseFileManager`).
   * Se il file modificato corrisponde al percorso di configurazione dell'app, ricaricare automaticamente la configurazione senza riavviare l'app.
4. **Interfaccia Utente (UI)**:
   * Includere un pulsante dedicato `🔄 Ricarica .DAT` o badge di stato per consentire all'utente/equipaggio di forzare il ricaricamento manuale e visualizzare i parametri attivi.

---

## 3. Struttura delle Cartelle e File (Resource-Driven)

Ogni applicazione deve risiedere in una propria sottocartella all'interno di `Applications/`, definendo sia la scena/script UI sia la corrispondente risorsa esportata (`.tres`), mentre tutte le suite di test automatizzati risiedono nella cartella `tests/`:

```text
Applications/
└── NomeApp/
    ├── nome_app.tscn          # Scena principale dell'applicazione (Control UI)
    ├── nome_app.gd            # Script controller dell'interfaccia
    ├── nome_app.tres          # Risorsa ShipAppResource o TerminalAppResource
    ├── SubComponent/          # Eventuali componenti interni, widget, finestre figlie
    │   ├── sub_comp.tscn
    │   └── sub_comp.gd
    └── Assets/                # Risorse grafiche, icone o temi dedicati (opzionali)

Scenes/Autoloads/SoftwareManager/
├── app_resource.gd            # Classe base AppResource
├── ship_app_resource.gd       # Classe ShipAppResource (RBAC, energia, sottosistemi)
├── terminal_app_resource.gd   # Classe TerminalAppResource (CLI, utility locali)
├── ship_software_manager.gd   # Singleton ShipSoftwareManager
└── terminal_software_manager.gd # Singleton TerminalSoftwareManager

tests/                         # Suite di test automatizzati headless
├── test_nome_app.tscn         # Scena runner per il test dell'applicazione
├── test_nome_app_node.gd      # Script con asserzioni e scenari di test
└── ...
```

---

## 4. Definizione delle Risorse Software (`AppResource`, `ShipAppResource`, `TerminalAppResource`)

### A. Classe Base: `AppResource`
Definita in `Scenes/Autoloads/SoftwareManager/app_resource.gd`:
* `app_id: String`: identificativo univoco (es. `"sensors"`, `"flight_control"`, `"terminal"`).
* `title: String`: titolo visualizzato nella barra del titolo della finestra e nello Start Menu.
* `description: String`: descrizione diegetica del programma.
* `category: String`: categoria ("Sistemi Nave", "Terminale Locale", ecc.).
* `icon: Texture2D`: icona visualizzata nel menu e nella taskbar.
* `icon_color: Color`: colore di accento per la taskbar e i pulsanti.
* `scene_path: String` / `scene: PackedScene`: riferimento alla scena `.tscn` dell'interfaccia.
* `default_window_size: Vector2` & `min_window_size: Vector2`: dimensioni finestra predefinite e minime.
* `drive_folder: String`: percorso relativo della cartella sul Drive (es. `"Programs/Sensors"`).
* `default_password: String`: password per sbloccare la cartella protetta sul Drive.
* `default_files: Array[Dictionary]`: lista dei file `.dat` di default da generare automaticamente all'installazione o al montaggio del Drive (`{ "path": "Ship Drive/...", "content": "...", "is_protected": true, "desc": "..." }`).

### B. Risorsa per Sistemi Nave: `ShipAppResource`
Definita in `Scenes/Autoloads/SoftwareManager/ship_app_resource.gd`:
* `roles: Array[String]`: elenco dei ruoli autorizzati ad accedere o visualizzare il programma (es. `["Soldier", "Hacker", "Captain", "Factotum"]`).
* `power_draw_mw: float`: consumo energetico in megawatt dalla rete elettrica della nave.
* `required_subsystems: Array[String]`: sottosistemi hardware richiesti (es. `["sensors_array"]`, `["nav_computer"]`).
* `is_critical: bool`: contrassegna se l'app è critica per la navigazione o il combattimento.
* Metodo `is_role_allowed(role_name: String, is_solo: bool) -> bool`: verifica se il ruolo del giocatore ha i permessi di accesso.

### C. Risorsa per Terminale Locale: `TerminalAppResource`
Definita in `Scenes/Autoloads/SoftwareManager/terminal_app_resource.gd`:
* `is_system_app: bool`: flag per applicazioni core dell'OS.
* `terminal_command: String`: comando CLI opzionale associato all'utility nella shell.
* `is_pinned_to_taskbar: bool`: se l'applicazione deve essere visualizzata permanentemente sulla barra delle applicazioni.

---

## 4. Anatomia della Scena UI (`.tscn`)

La radice dell'applicazione deve essere un nodo di tipo **`Control`** (o derivato come `PanelContainer`, `MarginContainer`).

### Regole di Layout e Contenimento Finestra
* **Nessun Sbordamento**: Il contenuto della finestra dell'applicazione non deve mai sbordare all'esterno dei bordi della finestra.
* **Adattamento Dimensioni**: Le dimensioni predefinite e minime della finestra (`DEFAULT_WINDOW_SIZE` e `custom_minimum_size`) devono essere calibrate e adattate specificamente per contenere interamente tutti gli elementi della UI senza tagli, occlusioni o sovrapposizioni indesiderate.
* **Layout Responsivo**: Utilizzare sempre i nodi `Container` di Godot (`VBoxContainer`, `HBoxContainer`, `GridContainer`, `MarginContainer`, ecc.) con le corrette flag di espansione (`Size Flags`), oppure uno `ScrollContainer` dedicato nei casi di contenuto a estensione dinamica o variabile.

### Struttura Nodi Raccomandata
```text
NomeApp (Control) [custom_minimum_size, theme/layout]
├── VBoxContainer (MainLayout)
│   ├── HeaderBar (HBoxContainer)       # Titolo app, status indicator, info ruolo
│   ├── ContentContainer (MarginContainer) # Area operativa dell'applicazione
│   └── StatusBar (HBoxContainer)        # Log di stato, ping, telemetria rapida
└── %DisconnectedOverlay (Panel)        # Overlay di blocco a tutto schermo (solo per App della Nave)
    └── CenterContainer
        └── VBoxContainer
            ├── WarningIcon / Label ("⚠️ SISTEMI OFFLINE")
            └── SubLabel ("In attesa di connessione / Avvio missione...")
```

> **Nota UI**: Usa i *Unique Names* (es. `%DisconnectedOverlay`, `%StatusLabel`) per accedere rapidamente ai nodi chiave da script in modo robusto.

---

## 5. Pattern dello Script (`.gd`)

Di seguito il template standard per lo script controller di una nuova app:

```gdscript
extends Control

## Titolo e dimensioni preferite per la finestra di GodotOS
const APP_TITLE: String = "NOME SISTEMA / APPLICAZIONE"
const DEFAULT_WINDOW_SIZE: Vector2 = Vector2(600, 400)

## Riferimenti ai nodi UI (utilizzando Unique Names %)
@onready var disconnected_overlay: Control = get_node_or_null("%DisconnectedOverlay")
@onready var status_label: Label = get_node_or_null("%StatusLabel")

func _ready() -> void:
	_configure_window()
	_connect_system_signals()
	_update_connection_state()
	load_dat_configuration()

func _configure_window() -> void:
	custom_minimum_size = DEFAULT_WINDOW_SIZE
	# Se istanziata all'interno di una FakeWindow di GodotOS:
	var parent_window = get_parent()
	if parent_window and "window_title" in parent_window:
		parent_window.window_title = APP_TITLE

func _connect_system_signals() -> void:
	# 1. Collegamento allo stato di connessione/missione della nave
	if SpaceWorldManager:
		SpaceWorldManager.ship_connection_changed.connect(_on_ship_connection_changed)
	
	# 2. Collegamento a NetworkManager (opzionale se servono ruoli o chat)
	if NetworkManager:
		NetworkManager.player_role_changed.connect(_on_player_role_changed)
	
	# 3. Ascolto modifiche live ai file .dat (Hot-Reloading)
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm and sdm.has_signal("file_modified"):
		sdm.file_modified.connect(_on_drive_file_modified)

func _exit_tree() -> void:
	# Disconnessione segnali e pulizia risorse / timer
	if SpaceWorldManager and SpaceWorldManager.ship_connection_changed.is_connected(_on_ship_connection_changed):
		SpaceWorldManager.ship_connection_changed.disconnect(_on_ship_connection_changed)
	if NetworkManager and NetworkManager.player_role_changed.is_connected(_on_player_role_changed):
		NetworkManager.player_role_changed.disconnect(_on_player_role_changed)
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm and sdm.has_signal("file_modified") and sdm.file_modified.is_connected(_on_drive_file_modified):
		sdm.file_modified.disconnect(_on_drive_file_modified)

## Gestione del file di configurazione .dat a Runtime
func _on_drive_file_modified(rel_path: String) -> void:
	if "Programs/NomeApp" in rel_path and rel_path.ends_with(".dat"):
		load_dat_configuration()

func load_dat_configuration() -> void:
	var config_data := _parse_dat_file("Ship Drive/Programs/NomeApp/config.dat")
	if config_data.is_empty():
		config_data = _parse_dat_file("Terminal Drive/Programs/NomeApp/config.dat")
	
	# Aggiorna i parametri attivi con fallback ai default
	# active_param = config_data.get("param_key", default_param)
	_apply_configuration()

func _apply_configuration() -> void:
	# Applica i parametri estratti al sistema o alla simulazione
	pass

func _parse_dat_file(rel_path: String) -> Dictionary:
	var result: Dictionary = {}
	var abs_path := "user://files/%s" % rel_path
	if not FileAccess.file_exists(abs_path):
		return result
	var file := FileAccess.open(abs_path, FileAccess.READ)
	if not file:
		return result
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#") or line.begins_with(";"):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			continue
		var eq_pos := line.find("=")
		if eq_pos != -1:
			var key := line.substr(0, eq_pos).strip_edges()
			var val_str := line.substr(eq_pos + 1).strip_edges()
			if val_str.is_valid_float():
				result[key] = val_str.to_float()
			elif val_str.is_valid_int():
				result[key] = val_str.to_int()
			else:
				result[key] = val_str
	file.close()
	return result

## Gestione dello stato Operativo / Disconnesso
func _on_ship_connection_changed(is_connected: bool) -> void:
	_update_connection_state()

func _update_connection_state() -> void:
	var is_operational: bool = false
	if SpaceWorldManager and SpaceWorldManager.has_method("is_ship_connected"):
		is_operational = SpaceWorldManager.is_ship_connected()
	elif NetworkManager and NetworkManager.has_method("is_ship_connected"):
		is_operational = NetworkManager.is_ship_connected()
	
	# Mostra o nasconde l'overlay di blocco
	if disconnected_overlay:
		disconnected_overlay.visible = not is_operational
	
	# Abilita/disabilita l'input di processing
	set_process(is_operational)
	set_process_input(is_operational)
	set_physics_process(is_operational)

## Gestione autorizzazioni basate sul Ruolo
func _on_player_role_changed(peer_id: int, new_role: String) -> void:
	_update_permissions()

func _update_permissions() -> void:
	var my_role := ""
	if NetworkManager:
		my_role = NetworkManager.get_local_player_role()
	
	# Esempio: disabilita pulsanti di comando per chi non ha il ruolo designato
	var can_control := (my_role == "Ingegnere" or my_role == "Capitano" or NetworkManager.is_solo_mode)
	# %ActionButton.disabled = not can_control
```

---

## 6. Comunicazione di Rete e Autoloads Disponibili

### Autoload Principali del Progetto

1. **`ShipSoftwareManager` (`Scenes/Autoloads/SoftwareManager/ship_software_manager.gd`)**:
   * Gestisce il catalogo centralizzato dei programmi di bordo basati su `ShipAppResource`.
   * Registra ed esporta le app, installa i software sulle istanze di `ShipBlueprint`.
   * Popola automaticamente le cartelle protette e i file `.dat` di default su `Ship Drive`.
   * Gestisce l'apertura e il layout delle finestre software nel desktop di GodotOS.
   * Filtra le applicazioni operative in base al ruolo del giocatore locale (`get_installed_apps_for_role`).

2. **`TerminalSoftwareManager` (`Scenes/Autoloads/SoftwareManager/terminal_software_manager.gd`)**:
   * Gestisce il catalogo delle utility e programmi locali del terminale basati su `TerminalAppResource`.
   * Popola cartelle e file di configurazione predefiniti su `Terminal Drive`.
   * Gestisce l'avvio delle finestre locali e l'integrazione con comandi CLI della shell.

3. **`SpaceWorldManager` (`Outside/space_world_manager.gd`)**:
   * Gestisce l'ambiente 3D dello spazio, la simulazione fisica della nave (`Spaceship`), telecamere esterne (CCTV) e ostacoli.
   * `SpaceWorldManager.is_ship_connected() -> bool`: Indica se la nave è attiva e la missione è in corso.
   * `SpaceWorldManager.ship_connection_changed(is_connected: bool)`: Segnale emesso all'attivazione/disattivazione dei sistemi.
   * **Integrazione Blueprint**:
     * `SpaceWorldManager.get_ship_blueprint() -> ShipBlueprint`: Ritorna l'istanza attiva di `ShipBlueprint`.
     * `SpaceWorldManager.get_duct_rooms() -> Array[Dictionary]`: Ritorna le stanze/settori della nave.
     * `SpaceWorldManager.get_duct_corridors() -> Array[Dictionary]`: Ritorna i condotti di manutenzione per il drone.
     * `SpaceWorldManager.get_power_devices() -> Array[Dictionary]`: Ritorna i generatori e le utenze della rete elettrica.
     * `SpaceWorldManager.get_power_junctions() -> Array[Dictionary]`: Ritorna gli snodi e le biforcazioni elettriche.
     * `SpaceWorldManager.get_damage_zones() -> Array[Dictionary]`: Ritorna le zone di danno predefinite.
     * `SpaceWorldManager.get_ship_bounds() -> Rect2`: Ritorna i limiti dimensionali dello scafo.
     * `SpaceWorldManager.get_drone_spawn_pos() -> Vector2` & `get_drone_spawn_heading() -> float`: Ritorna le coordinate iniziali del Duct Drone.
     * `SpaceWorldManager.get_ship_drive_files() -> Array[Dictionary]`: Ritorna l'elenco dei file iniziali del drive (`.txt`, `.dat`).
     * `SpaceWorldManager.get_ship_drive_passwords() -> Dictionary`: Ritorna le password delle cartelle protette di bordo.
     * `SpaceWorldManager.get_installed_apps() -> Array[Dictionary]`: Ritorna l'elenco delle applicazioni mainframe installate sulla nave.
     * `SpaceWorldManager.get_installed_apps_for_role(role, is_solo) -> Array[Dictionary]`: Ritorna le applicazioni mainframe filtrate per il ruolo specificato.

4. **`NetworkManager` (`Scenes/Networking/network_manager.gd`)**:
   * Gestisce socket ENet / P2P, stanze, equipaggio e chat.
   * `NetworkManager.is_ship_connected() -> bool`: `true` se connesso/solo E missione avviata.
   * `NetworkManager.is_mission_active() -> bool`: `true` se la missione è in corso (`mission_started`).
   * `NetworkManager.get_local_player_role() -> String`: Ruolo locale del giocatore.
   * `NetworkManager.is_solo_mode: bool`: `true` se si gioca offline da soli.
   * Segnali chiave: `mission_started`, `mission_ended`, `connection_state_changed`, `player_role_changed`, `lobby_updated`.

5. **`NotificationManager` (`Scenes/Autoloads/Notification Manager/notification_manager.gd`)**:
   * `NotificationManager.send_notification(title, body)`: Mostra toast OS a comparsa in basso a destra.

---

## 7. Registrazione dell'App in GodotOS (Software Managers & Start Menu)

Grazie all'architettura Resource-driven, la registrazione delle applicazioni non richiede più modifiche manuali hardcoded alla scena della Taskbar:

### A. Registrazione per Applicazioni della Nave (`ShipAppResource`)
1. Creare il file di risorsa `.tres` dedicato nella cartella del programma (es. `res://Applications/Sensors/sensors_app.tres`).
2. Configurare nell'Inspector di Godot:
   * **Identificazione**: `app_id` (es. `"sensors"`), `title`, `description`, `icon`, `icon_color`.
   * **Interfaccia**: `scene_path` (es. `"res://Applications/Sensors/sensors_app.tscn"`), `default_window_size`, `min_window_size`.
   * **Integrazione Drive & Sicurezza**: `drive_folder` (es. `"Programs/Sensors"`), `default_password` (es. `"SENS-7815"`), `default_files` (array di dizionari con i file `.dat` e i relativi contenuti).
   * **Matrice Nave & RBAC**: `roles` (es. `["Soldier", "Hacker", "Captain", "Factotum"]`), `power_draw_mw`, `required_subsystems`.
3. Inserire il percorso della risorsa in:
   * `DEFAULT_SHIP_APP_PATHS` in `ship_software_manager.gd` (per caricamento nel catalogo globale).
   * `installed_apps` di `default_ship_blueprint.tres` (o programmaticamente via `ShipSoftwareManager.install_app_on_blueprint`).
4. Al decollo della missione, lo Start Menu leggerà automaticamente la `ShipBlueprint` tramite `SpaceWorldManager.get_installed_apps_for_role()` e popolerà i collegamenti con filtro RBAC.

### B. Registrazione per Applicazioni del Terminale (`TerminalAppResource`)
1. Creare la risorsa `.tres` (es. `res://Applications/Terminal/terminal_app.tres`).
2. Configurare `app_id`, `title`, `scene_path`, `drive_folder` e proprietà del terminale locale (`is_system_app`, `terminal_command`, `is_pinned_to_taskbar`).
3. Registrare il percorso della risorsa in `DEFAULT_TERMINAL_APP_PATHS` in `terminal_software_manager.gd`.

---

## 8. Checklist di Verifica per Nuove App

Prima di considerare completata una nuova applicazione, verificare:

- [ ] **Flusso Git / Branch Dedicato**: Le modifiche e lo sviluppo sono stati svolti sul branch dedicato `applications/<nome programma>` (creato prima di iniziare e con checkout effettuato), concludendo con il commit finale.
- [ ] **Tipo di Applicazione (Server/Nave vs Terminale)**: Se il tipo non era chiaro, è stato confermato con l'utente; il comportamento di accesso segue le regole appropriate (vincolata alla missione per la nave, sempre disponibile per il terminale).
- [ ] **Risorsa `.tres` Creata e Registrata**: Creata l'apposita risorsa `ShipAppResource` o `TerminalAppResource` con tutti i metadati, dimensioni finestra, percorsi drive, ruoli RBAC e file `.dat` predefiniti; registrata in `ShipSoftwareManager` o `TerminalSoftwareManager`.
- [ ] **Cartella Protetta e File `.dat`**: L'applicazione dispone di una cartella protetta da password con i file `.dat` di configurazione salvati nel percorso corretto (`Ship Drive/Programs/[NomeApp]/` sincronizzato per app della nave, o `Terminal Drive/Programs/[NomeApp]/` per app del terminale).
- [ ] **Utilizzo Runtime dei File `.dat`**: I file `.dat` non sono leggibili dal File Reader e i valori contenuti vengono usati dal programma per influenzarne attivamente le prestazioni o il comportamento.
- [ ] **Stato Offline/Lobby**: Per le app della nave, all'avvio in Lobby o a gioco disconnesso, l'app mostra l'overlay *"Connettersi alla nave"* o *"Sistemi Offline"* e blocca l'input.
- [ ] **Avvio Missione**: Al decollo (`start_mission()`), per le app della nave l'overlay scompare istantaneamente e l'app diventa operativa.
- [ ] **Disconnessione / Fine Missione**: Se il server si chiude o si torna alla lobby, l'app torna immediatamente in stato bloccato e chiude finestre/timer orfani.
- [ ] **Multiplayer / Solo**: L'app funziona regolarmente sia in modalità **Solo (Locale)** che in **Multiplayer (Host + Client)**.
- [ ] **Contenimento Finestra e No Sbordamento**: Il contenuto dell'applicazione non sborda all'esterno della finestra; le dimensioni minime e predefinite (`DEFAULT_WINDOW_SIZE` / `custom_minimum_size`) sono state opportunamente adattate per contenere tutti gli elementi UI senza tagli né overflow.
- [ ] **Resistenza al Resize**: Il layout UI usa Containers (`VBoxContainer`, `HBoxContainer`, `GridContainer`) e si adatta al ridimensionamento della finestra `ApplicationWindow`.
- [ ] **Integrazione ShipBlueprint**: Se l'applicazione interagisce con settori, condotti, impianti elettrici o danni della nave, i dati geometrici e topologici vengono estratti dinamicamente da `SpaceWorldManager.get_ship_blueprint()` o dai relativi helper di `SpaceWorldManager`, con fallback locale in caso di assenza.
- [ ] **Test Automatizzati (tests/)**: L'applicazione dispone di una suite di test headless collocata nella cartella `tests/` (es. `tests/test_[nome_app].tscn`) per validare il ciclo di vita, la risorsa `.tres`, i permessi RBAC e la configurazione `.dat`.
- [ ] **Pulizia `_exit_tree()`**: Tutti i segnali globali collegati vengono disconnessi alla chiusura della finestra per prevenire memory leak o crash.

---

## 9. Suite di Test Automatizzati (`tests/`)

Tutti i test automatizzati del progetto devono essere collocati all'interno della directory `tests/`.

### Struttura Standard dei Test
Ogni suite di test è composta da:
* **Scena Runner (`tests/test_[modulo].tscn`)**: Scena Godot minimale che istanzia lo script di test.
* **Script di Test (`tests/test_[modulo]_node.gd`)**: Script GDScript che esegue i test in modalità headless, verifica lo stato con `assert()`, testa le funzionalità sia offline che connesse, e termina l'esecuzione con `get_tree().quit(0)` in caso di successo o `get_tree().quit(1)` in caso di errore.

### Esecuzione dei Test Headless
I test possono essere eseguiti da riga di comando o in pipeline CI/CD tramite Godot Engine in modalità headless:
```bash
# Esecuzione di un singolo test
godot --headless --path . tests/test_cams_system.tscn

# Esecuzione di tutti i test della cartella tests/
for t in tests/*.tscn; do echo "=== Running $t ==="; godot --headless --path . "$t"; done
```

### Requisiti di Copertura per Nuove Applicazioni
I test all'interno di `tests/` per una nuova applicazione devono verificare:
1. **Overlay / Ciclo di Vita**: Verifica del blocco con overlay quando offline/in lobby e sblocco automatico all'avvio della missione (`SpaceWorldManager.is_ship_connected()`).
2. **File `.dat` & Cartelle Protette**: Verifica dell'esistenza della cartella protetta (`Ship Drive/Programs/[NomeApp]`), parsing dei file `.dat` e hot-reloading su sincronizzazione/modifica.
3. **Controllo Ruoli (RBAC)**: Verifica che i comandi attivi siano consentiti solo ai ruoli autorizzati.
4. **Pulizia Segnali**: Verifica che alla chiusura dell'app tutti i segnali e timer vengano ripuliti senza errori in `_exit_tree()`.

---

## 10. Integrazione con ShipBlueprint / Sublayer della Nave

### A. Panoramica del Sublayer Unificato
La risorsa centrale **`ShipBlueprint`** (`Outside/ShipSublayer/ship_blueprint.gd` e `default_ship_blueprint.tres`) definisce l'intera configurazione e geometria della nave attraverso 6 sublayer coordinati:

1. **Sublayer 1: Stanze e Settori (`rooms`)**:
   - Geometria dei compartimenti dello scafo (`Rect2`), nomi identificativi, categoria (`command`, `engineering`, `propulsion`, `sensors`, ecc.), colori primari e bordi.
2. **Sublayer 2: Condotti di Manutenzione (`ducts`)**:
   - Segmenti di navigazione interna per il Duct Drone (`from`, `to`, `width`), nomi dei condotti e flag di ostruzione (`is_blocked`).
3. **Sublayer 3: Rete Elettrica (`devices`, `junctions`, `conduits`)**:
   - Dispositivi generatori e consumatori (potenza in MW, porte di alimentazione `inputs_count`).
   - Snodi a commutazione dinamica (`junctions` con rami e linee `conduits`).
4. **Sublayer 4: Zone di Danno e Vulnerabilità (`damages`)**:
   - Punti di danno strutturale (falle, cortocircuiti), gravità (`severity`), costi di riparazione e impatto sui sistemi.
5. **Sublayer 5: File di Sistema e Ship Drive (`drive_files`, `drive_passwords`)**:
   - File iniziali montati sul desktop (`.txt` di log/direttive e configurazioni binarie protette `.dat` per ogni programma di bordo).
   - Mappa delle password di cartella (`FolderPasswordManager`) per le directory protette di bordo.
6. **Sublayer 6: Applicazioni Mainframe Installate e Filtro Ruoli (`installed_apps`)**:
   - Collezione di risorse `ShipAppResource` installate nel mainframe della nave (`id`, `title`, `description`, `scene_path`, `icon_color`, `roles`, `power_draw_mw`, `required_subsystems`, `drive_folder`, `default_files`).
   - All'avvio della missione (`mission_started`), il menu Start di GodotOS popola dinamicamente solo le applicazioni installate autorizzate per il ruolo del giocatore locale (`SpaceWorldManager.get_installed_apps_for_role(role, is_solo)`). Prima del decollo, le applicazioni della nave non appaiono nel menu, eliminando aperture accidentali e il problema dell'overlay *"connettiti ad una nave"*.

Inoltre, la risorsa contiene i metadati dimensionali dello scafo (`ship_bounds`), le coordinate di spawn del drone (`drone_spawn_pos`) e l'orientamento iniziale (`drone_spawn_heading`).

### B. Come un'Applicazione si Connette ed Estrae i Dati della Blueprint

Le applicazioni non devono includere coordinate o topologie hardcoded. Devono invece interrogare l'istanza attiva tramite l'autoload **`SpaceWorldManager`**.

#### Metodi Helper di `SpaceWorldManager`
* `SpaceWorldManager.get_ship_blueprint() -> ShipBlueprint`: Ritorna l'istanza di risorsa attiva (o la blueprint di default).
* `SpaceWorldManager.get_duct_rooms() -> Array[Dictionary]`: Ritorna l'elenco delle stanze dello scafo.
* `SpaceWorldManager.get_duct_corridors() -> Array[Dictionary]`: Ritorna l'elenco dei condotti di transito.
* `SpaceWorldManager.get_power_devices() -> Array[Dictionary]`: Ritorna l'elenco dei dispositivi elettrici.
* `SpaceWorldManager.get_power_junctions() -> Array[Dictionary]`: Ritorna l'elenco degli snodi di derivazione.
* `SpaceWorldManager.get_damage_zones() -> Array[Dictionary]`: Ritorna l'elenco dei punti di danno predefiniti.
* `SpaceWorldManager.get_ship_bounds() -> Rect2`: Ritorna i confini dimensionali della nave.
* `SpaceWorldManager.get_drone_spawn_pos() -> Vector2`: Ritorna la posizione di spawn del drone.
* `SpaceWorldManager.get_ship_drive_files() -> Array[Dictionary]`: Ritorna l'elenco dei file iniziali del drive.
* `SpaceWorldManager.get_ship_drive_passwords() -> Dictionary`: Ritorna le password delle cartelle protette di bordo.
* `SpaceWorldManager.get_installed_apps() -> Array[Dictionary]`: Ritorna l'elenco dei programmi installati nel mainframe.
* `SpaceWorldManager.get_installed_apps_for_role(role_name, is_solo) -> Array[Dictionary]`: Ritorna i programmi installati filtrati per ruolo.

#### Pattern GDScript Consigliato per le Applicazioni

```gdscript
func _init_ship_topology() -> void:
	# 1. Recupero dell'istanza Blueprint o fallback
	var bp: ShipBlueprint = null
	if SpaceWorldManager and SpaceWorldManager.has_method("get_ship_blueprint"):
		bp = SpaceWorldManager.get_ship_blueprint()
	
	if bp != null:
		_load_from_blueprint(bp)
	else:
		_load_fallback_topology()

func _load_from_blueprint(bp: ShipBlueprint) -> void:
	# Esempio: Caricamento stanze e condotti
	for room in bp.rooms:
		var room_id: String = room.get("id", "")
		var room_rect: Rect2 = room.get("rect", Rect2())
		var room_name: String = room.get("name", "Settore")
		# Inizializza elementi UI / logica...

	# Esempio: Caricamento dispositivi elettrici
	for dev in bp.devices:
		var dev_id: String = dev.get("id", "")
		var dev_pos: Vector2 = dev.get("pos", Vector2.ZERO)
		var is_gen: bool = dev.get("is_generator", false)
		# Popola la mappa o il controller...

	# Esempio: Metodi di query rapida forniti dalla Blueprint
	var bridge_room := bp.get_room_by_id("bridge")
	var room_at_cursor := bp.get_room_at(Vector2(300, 80))
	var reactor_device := bp.get_device_by_id("reactor_main")
```

### C. Editor Visivo dei Sublayer (`addons/ship_sublayer_editor/`)
Gli sviluppatori possono progettare, modificare, testare e serializzare i sublayer della nave direttamente dall'Editor di Godot:
* Il plugin aggiunge una scheda **Ship Blueprint** nel pannello inferiore.
* Supporta navigazione Pan/Zoom, Snap alla griglia, manipolazione interattiva (trascinamento e ridimensionamento), ispettore delle proprietà e salvataggio in `.tres` o esportazione/importazione `.json`.
