# Standard Architetturale per le Applicazioni GodotOS (Dark Nova: Rogue Squadron)

> **Istruzioni per l'Agente AI**: Questo documento costituisce il set di istruzioni specifiche e vincolanti per l'agente AI incaricato della creazione, refactoring o manutenzione delle applicazioni all'interno del sistema operativo di bordo **GodotOS**.

### Flusso di Lavoro Git (Regola Obbligatoria per l'Agente AI)
Prima di eseguire qualsiasi modifica o sviluppo su un'applicazione, l'agente AI deve seguire rigorosamente questo flusso Git:
1. **Creazione Branch**: Prima di fare qualsiasi modifica, creare un nuovo branch chiamato `applications/<nome programma>` (es. `applications/NomeApp`).
2. **Checkout e Sviluppo su Branch**: Eseguire il checkout sul nuovo branch e svolgere tutte le modifiche esclusivamente all'interno di tale branch.
3. **Commit Finale**: Effettuare un commit al termine di tutte le modifiche con un messaggio descrittivo.

---

## 1. Panoramica e Concetti Chiave

In *Dark Nova: Rogue Squadron*, l'interfaccia di gioco è il desktop virtuale di GodotOS. Ogni stazione dell'equipaggio (Pilota, Ingegnere, Tattico, Sensori, Comunicazioni, ecc.) e ogni utility opera attraverso applicazioni a finestre dedicate.

### Tipologie di Applicazione e Disambiguazione (Regola per l'Agente AI)
Quando i requisiti non sono esplicitamente chiari, l'agente AI **deve chiedere all'utente** se l'applicazione da creare/modificare è un'**Applicazione del Server (Nave)** o un'**Applicazione del Terminale (Locale)**:

1. **Applicazione del Server (Nave)**:
   * Collegata ai sistemi di bordo e alla simulazione della nave.
   * **Ciclo di vita**: Deve essere disponibile e operativa **esclusivamente dopo che la missione è partita** (`is_mission_started == true` / `is_ship_connected() == true`). In lobby o offline deve mostrare l'overlay di blocco/disconnessione.
2. **Applicazione del Terminale (Locale)**:
   * Applicazione di utilità o terminale locale indipendente dalla simulazione nave.
   * **Ciclo di vita**: **Non è limitata dallo stato della missione** ed è sempre accessibile e utilizzabile.

### Principi Fondamentali
1. **Server-Authoritative (Host-Centrico)**: Per le applicazioni della nave, la simulazione fisica e lo stato risiedono sul Server/Host. I client inviano richieste di comando (`request_*`) e ricevono aggiornamenti di stato.
2. **Controllo Ruoli (RBAC - Role-Based Access Control)**: Ogni applicazione può limitare le azioni di comando in base al ruolo ricoperto dal giocatore (es. solo il Pilota può manovrare, solo l'Ingegnere può alterare il flusso del reattore), consentendo agli altri la sola visualizzazione (telemetria).

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
* **Valori attivi di runtime**: Contengono parametri e valori effettivi che il programma legge e utilizza attivamente durante l'esecuzione.
* **Impatto sulle prestazioni**: La modifica di tali valori influenza direttamente le prestazioni, l'efficienza e il comportamento del programma, in positivo o in negativo (meccanica di tuning, sovraccarico, hacking o manomissione).

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

## 3. Struttura delle Cartelle e File

Ogni applicazione deve risiedere in una propria sottocartella all'interno di `Applications/`, mentre tutte le suite di test automatizzati risiedono nella cartella `.tests/`:

```text
Applications/
└── NomeApp/
    ├── nome_app.tscn          # Scena principale dell'applicazione (Control UI)
    ├── nome_app.gd            # Script controller dell'interfaccia
    ├── SubComponent/          # Eventuali componenti interni, widget, finestre figlie
    │   ├── sub_comp.tscn
    │   └── sub_comp.gd
    └── Assets/                # Risorse grafiche, icone o temi dedicati (opzionali)

.tests/                        # Suite di test automatizzati headless
├── test_nome_app.tscn         # Scena runner per il test dell'applicazione
├── test_nome_app_node.gd      # Script con asserzioni e scenari di test
└── ...
```

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

1. **`SpaceWorldManager` (`Outside/space_world_manager.gd`)**:
   * Gestisce l'ambiente 3D dello spazio, la simulazione fisica della nave (`Spaceship`), telecamere esterne (CCTV) e ostacoli.
   * `SpaceWorldManager.is_ship_connected() -> bool`: Indica se la nave è attiva e la missione è in corso.
   * `SpaceWorldManager.ship_connection_changed(is_connected: bool)`: Segnale emesso all'attivazione/disattivazione dei sistemi.

2. **`NetworkManager` (`Scenes/Networking/network_manager.gd`)**:
   * Gestisce socket ENet / P2P, stanze, equipaggio e chat.
   * `NetworkManager.is_ship_connected() -> bool`: `true` se connesso/solo E missione avviata.
   * `NetworkManager.is_mission_active() -> bool`: `true` se la missione è in corso (`mission_started`).
   * `NetworkManager.get_local_player_role() -> String`: Ruolo locale del giocatore.
   * `NetworkManager.is_solo_mode: bool`: `true` se si gioca offline da soli.
   * Segnali chiave: `mission_started`, `mission_ended`, `connection_state_changed`, `player_role_changed`, `lobby_updated`.

3. **`NotificationManager` (`Scenes/Autoloads/Notification Manager/notification_manager.gd`)**:
   * `NotificationManager.send_notification(title, body)`: Mostra toast OS a comparsa in basso a destra.

---

## 7. Registrazione dell'App in GodotOS

Per rendere l'applicazione avviabile dall'utente:

### A. Registrazione nello Start Menu
1. Apri la scena `Scenes/Taskbar/taskbar.tscn`.
2. Nella gerarchia del menu Start, aggiungi un'istanza di `start_menu_option.tscn`.
3. Nell'Inspector, configura:
   * **`title`**: Nome visualizzato (es. `"Controllo Reattore"`).
   * **`app_scene`**: Trascina il file `.tscn` della nuova app (es. `res://Applications/ReactorControl/reactor_control_app.tscn`).
   * **`icon`**: Icona quadrata (SVG/PNG).

### B. Registrazione come Icona Desktop (Opzionale)
Se l'app deve risiedere sul desktop:
* Aggiungi un file `.desktop` virtuale o inseriscila nella cartella `Desktop` predefinita gestita da `Scenes/Desktop/desktop_folder.gd`.

---

## 8. Checklist di Verifica per Nuove App

Prima di considerare completata una nuova applicazione, verificare:

- [ ] **Flusso Git / Branch Dedicato**: Le modifiche e lo sviluppo sono stati svolti sul branch dedicato `applications/<nome programma>` (creato prima di iniziare e con checkout effettuato), concludendo con il commit finale.
- [ ] **Tipo di Applicazione (Server/Nave vs Terminale)**: Se il tipo non era chiaro, è stato confermato con l'utente; il comportamento di accesso segue le regole appropriate (vincolata alla missione per la nave, sempre disponibile per il terminale).
- [ ] **Cartella Protetta e File `.dat`**: L'applicazione dispone di una cartella protetta da password con i file `.dat` di configurazione salvati nel percorso corretto (`Ship Drive/Programs/[NomeApp]/` sincronizzato per app della nave, o `Terminal Drive/Programs/[NomeApp]/` per app del terminale).
- [ ] **Utilizzo Runtime dei File `.dat`**: I file `.dat` non sono leggibili dal File Reader e i valori contenuti vengono usati dal programma per influenzarne attivamente le prestazioni o il comportamento.
- [ ] **Stato Offline/Lobby**: Per le app della nave, all'avvio in Lobby o a gioco disconnesso, l'app mostra l'overlay *"Connettersi alla nave"* o *"Sistemi Offline"* e blocca l'input.
- [ ] **Avvio Missione**: Al decollo (`start_mission()`), per le app della nave l'overlay scompare istantaneamente e l'app diventa operativa.
- [ ] **Disconnessione / Fine Missione**: Se il server si chiude o si torna alla lobby, l'app torna immediatamente in stato bloccato e chiude finestre/timer orfani.
- [ ] **Multiplayer / Solo**: L'app funziona regolarmente sia in modalità **Solo (Locale)** che in **Multiplayer (Host + Client)**.
- [ ] **Contenimento Finestra e No Sbordamento**: Il contenuto dell'applicazione non sborda all'esterno della finestra; le dimensioni minime e predefinite (`DEFAULT_WINDOW_SIZE` / `custom_minimum_size`) sono state opportunamente adattate per contenere tutti gli elementi UI senza tagli né overflow.
- [ ] **Resistenza al Resize**: Il layout UI usa Containers (`VBoxContainer`, `HBoxContainer`, `GridContainer`) e si adatta al ridimensionamento della finestra `ApplicationWindow`.
- [ ] **Test Automatizzati (.tests/)**: L'applicazione dispone di una suite di test headless collocata nella cartella `.tests/` (es. `.tests/test_[nome_app].tscn`) per validare il ciclo di vita, i permessi RBAC e la configurazione `.dat`.
- [ ] **Pulizia `_exit_tree()`**: Tutti i segnali globali collegati vengono disconnessi alla chiusura della finestra per prevenire memory leak o crash.

---

## 9. Suite di Test Automatizzati (`.tests/`)

Tutti i test automatizzati del progetto devono essere collocati all'interno della directory `.tests/`.

### Struttura Standard dei Test
Ogni suite di test è composta da:
* **Scena Runner (`.tests/test_[modulo].tscn`)**: Scena Godot minimale che istanzia lo script di test.
* **Script di Test (`.tests/test_[modulo]_node.gd`)**: Script GDScript che esegue i test in modalità headless, verifica lo stato con `assert()`, testa le funzionalità sia offline che connesse, e termina l'esecuzione con `get_tree().quit(0)` in caso di successo o `get_tree().quit(1)` in caso di errore.

### Esecuzione dei Test Headless
I test possono essere eseguiti da riga di comando o in pipeline CI/CD tramite Godot Engine in modalità headless:
```bash
# Esecuzione di un singolo test
godot --headless --path . .tests/test_cams_system.tscn

# Esecuzione di tutti i test della cartella .tests/
for t in .tests/*.tscn; do echo "=== Running $t ==="; godot --headless --path . "$t"; done
```

### Requisiti di Copertura per Nuove Applicazioni
I test all'interno di `.tests/` per una nuova applicazione devono verificare:
1. **Overlay / Ciclo di Vita**: Verifica del blocco con overlay quando offline/in lobby e sblocco automatico all'avvio della missione (`SpaceWorldManager.is_ship_connected()`).
2. **File `.dat` & Cartelle Protette**: Verifica dell'esistenza della cartella protetta (`Ship Drive/Programs/[NomeApp]`), parsing dei file `.dat` e hot-reloading su sincronizzazione/modifica.
3. **Controllo Ruoli (RBAC)**: Verifica che i comandi attivi siano consentiti solo ai ruoli autorizzati.
4. **Pulizia Segnali**: Verifica che alla chiusura dell'app tutti i segnali e timer vengano ripuliti senza errori in `_exit_tree()`.
