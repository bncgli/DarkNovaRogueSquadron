class_name LogbookApp
extends BaseApp

## Controller per l'applicazione di bordo "Mission Logbook & Tactical Objectives" (Applications/Logbook).
## Funge da registro di bordo ufficiale, diario delle operazioni, tracker contratti e scatola nera.

const APP_TITLE: String = "REGISTRO DI BORDO & OBIETTIVI"
const DEFAULT_WINDOW_SIZE: Vector2 = Vector2(600, 450)

const CONFIG_PATH_PRIMARY: String = "Ship Drive/Programs/Logbook/logbook_config.dat"
const CONFIG_PATH_FALLBACK: String = "Terminal Drive/Programs/Logbook/logbook_config.dat"
const TUNING_PATH_PRIMARY: String = "Ship Drive/Programs/Logbook/journal_tuning.dat"
const TUNING_PATH_FALLBACK: String = "Terminal Drive/Programs/Logbook/journal_tuning.dat"

# Riferimenti nodi UI principali (% Unique Names)
@onready var disconnected_overlay: Control = %DisconnectedOverlay
@onready var status_label: Label = %StatusLabel
@onready var active_contracts_label: Label = %ActiveContractsLabel
@onready var storage_notes_label: Label = %StorageNotesLabel
@onready var reload_dat_button: Button = %ReloadDatButton

# Scheda 1: Contratti
@onready var contracts_container: VBoxContainer = %ContractsContainer
@onready var new_contract_btn: Button = %NewContractBtn

# Scheda 2: Scatola Nera
@onready var event_log_text: RichTextLabel = %EventLogText
@onready var clear_log_btn: Button = %ClearLogBtn

# Scheda 3: Note di Plancia
@onready var notes_option_btn: OptionButton = %NotesOptionBtn
@onready var note_edit_text: TextEdit = %NoteEditText
@onready var save_note_btn: Button = %SaveNoteBtn
@onready var note_storage_type_btn: OptionButton = %NoteStorageTypeBtn

# Dati di configurazione runtime (.dat)
var config_data: Dictionary = {
	"app_name": "LogbookApp",
	"version": "1.0.0",
	"status": "OPERATIONAL",
	"auto_log_events": true,
	"max_history_entries": 200,
	"log_telemetry_errors": true
}

var tuning_data: Dictionary = {
	"sync_to_ship_drive": true,
	"timestamp_format": "STAR_DATE",
	"cloud_backup": false
}

# Ruolo e permessi RBAC
var current_role: String = "Pilota"
var is_solo_mode: bool = false
var can_manage_contracts: bool = false # Solo Capitano o Stagista

# Stato contratti ed eventi
var active_contracts: Array[Dictionary] = []
var black_box_events: Array[String] = []

func _ready() -> void:
	custom_minimum_size = DEFAULT_WINDOW_SIZE
	_connect_system_signals()
	_connect_ui_signals()
	_setup_initial_data()
	load_dat_configuration()
	_update_connection_state()
	_update_rbac_permissions()
	_refresh_contracts_ui()
	_refresh_black_box_ui()
	_load_notes_list()

func _exit_tree() -> void:
	_disconnect_system_signals()

# -----------------------------------------------------------------------------
# Connessione e Disconnessione Segnali di Sistema
# -----------------------------------------------------------------------------
func _connect_system_signals() -> void:
	if SpaceWorldManager:
		if SpaceWorldManager.has_signal("ship_connection_changed") and not SpaceWorldManager.ship_connection_changed.is_connected(_on_ship_connection_changed):
			SpaceWorldManager.ship_connection_changed.connect(_on_ship_connection_changed)
		if SpaceWorldManager.has_signal("mission_started") and not SpaceWorldManager.mission_started.is_connected(_on_mission_started):
			SpaceWorldManager.mission_started.connect(_on_mission_started)
		if SpaceWorldManager.has_signal("mission_ended") and not SpaceWorldManager.mission_ended.is_connected(_on_mission_ended):
			SpaceWorldManager.mission_ended.connect(_on_mission_ended)

	if NetworkManager:
		if NetworkManager.has_signal("player_role_changed") and not NetworkManager.player_role_changed.is_connected(_on_player_role_changed):
			NetworkManager.player_role_changed.connect(_on_player_role_changed)
		if NetworkManager.has_signal("player_list_updated") and not NetworkManager.player_list_updated.is_connected(_on_player_list_updated):
			NetworkManager.player_list_updated.connect(_on_player_list_updated)

	if ShipDriveManager:
		if ShipDriveManager.has_signal("file_modified") and not ShipDriveManager.file_modified.is_connected(_on_drive_file_modified):
			ShipDriveManager.file_modified.connect(_on_drive_file_modified)

	if TerminalDriveManager:
		if TerminalDriveManager.has_signal("file_modified") and not TerminalDriveManager.file_modified.is_connected(_on_drive_file_modified):
			TerminalDriveManager.file_modified.connect(_on_drive_file_modified)

func _disconnect_system_signals() -> void:
	if SpaceWorldManager:
		if SpaceWorldManager.has_signal("ship_connection_changed") and SpaceWorldManager.ship_connection_changed.is_connected(_on_ship_connection_changed):
			SpaceWorldManager.ship_connection_changed.disconnect(_on_ship_connection_changed)
		if SpaceWorldManager.has_signal("mission_started") and SpaceWorldManager.mission_started.is_connected(_on_mission_started):
			SpaceWorldManager.mission_started.disconnect(_on_mission_started)
		if SpaceWorldManager.has_signal("mission_ended") and SpaceWorldManager.mission_ended.is_connected(_on_mission_ended):
			SpaceWorldManager.mission_ended.disconnect(_on_mission_ended)

	if NetworkManager:
		if NetworkManager.has_signal("player_role_changed") and NetworkManager.player_role_changed.is_connected(_on_player_role_changed):
			NetworkManager.player_role_changed.disconnect(_on_player_role_changed)
		if NetworkManager.has_signal("player_list_updated") and NetworkManager.player_list_updated.is_connected(_on_player_list_updated):
			NetworkManager.player_list_updated.disconnect(_on_player_list_updated)

	if ShipDriveManager:
		if ShipDriveManager.has_signal("file_modified") and ShipDriveManager.file_modified.is_connected(_on_drive_file_modified):
			ShipDriveManager.file_modified.disconnect(_on_drive_file_modified)

	if TerminalDriveManager:
		if TerminalDriveManager.has_signal("file_modified") and TerminalDriveManager.file_modified.is_connected(_on_drive_file_modified):
			TerminalDriveManager.file_modified.disconnect(_on_drive_file_modified)

func _connect_ui_signals() -> void:
	if reload_dat_button and not reload_dat_button.pressed.is_connected(_on_reload_dat_pressed):
		reload_dat_button.pressed.connect(_on_reload_dat_pressed)
	if new_contract_btn and not new_contract_btn.pressed.is_connected(_on_new_contract_pressed):
		new_contract_btn.pressed.connect(_on_new_contract_pressed)
	if clear_log_btn and not clear_log_btn.pressed.is_connected(_on_clear_log_pressed):
		clear_log_btn.pressed.connect(_on_clear_log_pressed)
	if save_note_btn and not save_note_btn.pressed.is_connected(_on_save_note_pressed):
		save_note_btn.pressed.connect(_on_save_note_pressed)
	if notes_option_btn and not notes_option_btn.item_selected.is_connected(_on_note_selected):
		notes_option_btn.item_selected.connect(_on_note_selected)

# -----------------------------------------------------------------------------
# Gestione Stato Connessione & Ciclo di Vita
# -----------------------------------------------------------------------------
func _update_connection_state() -> void:
	var connected: bool = false
	if SpaceWorldManager and SpaceWorldManager.has_method("is_ship_connected"):
		connected = SpaceWorldManager.is_ship_connected()
	
	if disconnected_overlay:
		disconnected_overlay.visible = not connected
	
	if status_label:
		if connected:
			status_label.text = "STATO: OPERATIVO (COLLEGATO ALLA NAVE)"
			status_label.modulate = Color(0.2, 1.0, 0.4)
		else:
			status_label.text = "STATO: OFFLINE (DISCONNESSO)"
			status_label.modulate = Color(1.0, 0.3, 0.3)

func _on_ship_connection_changed(is_connected: bool) -> void:
	if disconnected_overlay:
		disconnected_overlay.visible = not is_connected
	_update_connection_state()

func _on_mission_started() -> void:
	_update_connection_state()
	log_event("MISSIONE AVVIATA - Sistemi logbook sincronizzati.")

func _on_mission_ended() -> void:
	_update_connection_state()
	log_event("MISSIONE TERMINATA - Connessione telemetrica interrotta.")

# -----------------------------------------------------------------------------
# RBAC (Role-Based Access Control)
# -----------------------------------------------------------------------------
func _update_rbac_permissions() -> void:
	if NetworkManager:
		if NetworkManager.has_method("get_my_role"):
			current_role = NetworkManager.get_my_role()
		elif "current_role" in NetworkManager:
			current_role = NetworkManager.current_role
		
		if "is_solo_mode" in NetworkManager:
			is_solo_mode = bool(NetworkManager.get("is_solo_mode"))
		elif "is_solo" in NetworkManager:
			is_solo_mode = bool(NetworkManager.get("is_solo"))
	
	# Capitano o Stagista (o Solo Mode) hanno autorizzazioni complete di gestione contratti
	var role_lower := current_role.to_lower()
	can_manage_contracts = (
		is_solo_mode or 
		role_lower == "captain" or 
		role_lower == "capitano" or 
		role_lower == "stagista"
	)

	if new_contract_btn:
		new_contract_btn.disabled = not can_manage_contracts
		new_contract_btn.tooltip_text = "Assegna nuovo contratto (Solo Capitano/Stagista)" if not can_manage_contracts else ""
	
	if clear_log_btn:
		clear_log_btn.disabled = not can_manage_contracts

	_refresh_contracts_ui()

func _on_player_role_changed(peer_id: int, new_role: String) -> void:
	var my_peer_id: int = 1
	if NetworkManager and NetworkManager.has_method("get_my_peer_id"):
		my_peer_id = NetworkManager.get_my_peer_id()
	elif multiplayer and multiplayer.has_method("get_unique_id"):
		my_peer_id = multiplayer.get_unique_id()

	if peer_id == my_peer_id or peer_id == 0:
		current_role = new_role
		_update_rbac_permissions()

func _on_player_list_updated() -> void:
	_update_rbac_permissions()

# -----------------------------------------------------------------------------
# Configurazione .DAT e Hot-Reloading
# -----------------------------------------------------------------------------
func load_dat_configuration() -> void:
	var parsed_config: Dictionary = _parse_dat_file(CONFIG_PATH_PRIMARY)
	if parsed_config.is_empty():
		parsed_config = _parse_dat_file(CONFIG_PATH_FALLBACK)
	
	var parsed_tuning: Dictionary = _parse_dat_file(TUNING_PATH_PRIMARY)
	if parsed_tuning.is_empty():
		parsed_tuning = _parse_dat_file(TUNING_PATH_FALLBACK)

	_apply_configuration(parsed_config, parsed_tuning)

func _apply_configuration(parsed_config: Dictionary, parsed_tuning: Dictionary) -> void:
	if parsed_config.has("SYSTEM"):
		var sys = parsed_config["SYSTEM"]
		if sys.has("app_name"): config_data["app_name"] = str(sys["app_name"])
		if sys.has("version"): config_data["version"] = str(sys["version"])
		if sys.has("status"): config_data["status"] = str(sys["status"])

	if parsed_config.has("LOGGING"):
		var logg = parsed_config["LOGGING"]
		if logg.has("auto_log_events"): config_data["auto_log_events"] = bool(logg["auto_log_events"])
		if logg.has("max_history_entries"): config_data["max_history_entries"] = int(logg["max_history_entries"])
		if logg.has("log_telemetry_errors"): config_data["log_telemetry_errors"] = bool(logg["log_telemetry_errors"])

	if parsed_tuning.has("SYNC"):
		var sync = parsed_tuning["SYNC"]
		if sync.has("sync_to_ship_drive"): tuning_data["sync_to_ship_drive"] = bool(sync["sync_to_ship_drive"])
		if sync.has("timestamp_format"): tuning_data["timestamp_format"] = str(sync["timestamp_format"])
		if sync.has("cloud_backup"): tuning_data["cloud_backup"] = bool(sync["cloud_backup"])

func _on_drive_file_modified(rel_path: String) -> void:
	if "Logbook" in rel_path and rel_path.ends_with(".dat"):
		load_dat_configuration()

func _on_reload_dat_pressed() -> void:
	load_dat_configuration()
	if status_label:
		status_label.text = "CONFIGURAZIONE .DAT RICARICATA"

# -----------------------------------------------------------------------------
# Logica Contratti & Obiettivi
# -----------------------------------------------------------------------------
func _setup_initial_data() -> void:
	active_contracts = [
		{
			"id": "CTR-01",
			"title": "Pattugliamento Settore K-7",
			"description": "Eseguire scansione dei detriti e ripulire minacce ostili.",
			"reward_flux": 1500,
			"reward_credits": 300,
			"status": "IN_PROGRESS"
		},
		{
			"id": "CTR-02",
			"title": "Recupero Dati Relitto Orion",
			"description": "Scaricare i file di telemetria dal mainframe del relitto.",
			"reward_flux": 2200,
			"reward_credits": 500,
			"status": "IN_PROGRESS"
		}
	]
	
	black_box_events = [
		"[%s] REGISTRO INIZIALIZZATO: Sistemi di bordo operativi." % _get_formatted_timestamp(),
		"[%s] TELEMETRIA: Reattore primario a regime nominale." % _get_formatted_timestamp()
	]

func _get_formatted_timestamp() -> String:
	var tf: String = tuning_data.get("timestamp_format")
	if tf == "STAR_DATE":
		return "SD-%d.%d" % [Time.get_unix_time_from_system() / 1000, randi() % 100]
	return Time.get_time_string_from_system()

func _refresh_contracts_ui() -> void:
	if not contracts_container:
		return

	# Pulisce figli precedenti
	for child in contracts_container.get_children():
		child.queue_free()

	var active_count: int = 0
	for contract in active_contracts:
		if contract["status"] == "IN_PROGRESS":
			active_count += 1
		
		var panel := PanelContainer.new()
		var hbox := HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var vbox := VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var title_lbl := Label.new()
		title_lbl.text = "[%s] %s" % [contract["id"], contract["title"]]
		title_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
		vbox.add_child(title_lbl)
		
		var desc_lbl := Label.new()
		desc_lbl.text = "%s | Ricompensa: %d FLUX, %d CR" % [contract["description"], contract["reward_flux"], contract["reward_credits"]]
		desc_lbl.modulate = Color(0.8, 0.8, 0.8)
		vbox.add_child(desc_lbl)
		
		hbox.add_child(vbox)
		
		var status_badge := Label.new()
		status_badge.text = "[ %s ]" % contract["status"]
		if contract["status"] == "COMPLETED":
			status_badge.modulate = Color(0.2, 1.0, 0.2)
		else:
			status_badge.modulate = Color(0.3, 0.8, 1.0)
		hbox.add_child(status_badge)
		
		if can_manage_contracts and contract["status"] == "IN_PROGRESS":
			var complete_btn := Button.new()
			complete_btn.text = "Completa & Riscuoti"
			var cid = contract["id"]
			complete_btn.pressed.connect(func(): complete_contract(cid))
			hbox.add_child(complete_btn)

		panel.add_child(hbox)
		contracts_container.add_child(panel)

	if active_contracts_label:
		active_contracts_label.text = "CONTRATTI ATTIVI: %d" % active_count

func complete_contract(contract_id: String) -> void:
	if not can_manage_contracts:
		return

	for contract in active_contracts:
		if contract["id"] == contract_id and contract["status"] == "IN_PROGRESS":
			contract["status"] = "COMPLETED"
			var r_flux: int = contract.get("reward_flux")
			var r_cr: int = contract.get("reward_credits")
			
			# Accreditamento fondi persistenti nave
			if SpaceWorldManager:
				if SpaceWorldManager.has_method("add_ship_flux"):
					SpaceWorldManager.add_ship_flux(r_flux)
				elif "ship_flux" in SpaceWorldManager:
					SpaceWorldManager.ship_flux += r_flux
				
				if SpaceWorldManager.has_method("add_ship_credits"):
					SpaceWorldManager.add_ship_credits(r_cr)
				elif "ship_credits" in SpaceWorldManager:
					SpaceWorldManager.ship_credits += r_cr

			log_event("CONTRATTO COMPLETATO: %s (+%d FLUX, +%d CR)" % [contract["title"], r_flux, r_cr])
			break

	_refresh_contracts_ui()

func _on_new_contract_pressed() -> void:
	if not can_manage_contracts:
		return
	var new_id := "CTR-%02d" % (active_contracts.size() + 1)
	active_contracts.append({
		"id": new_id,
		"title": "Missione Tattica %s" % new_id,
		"description": "Scorta convoglio cargo e difesa contro incursioni pirata.",
		"reward_flux": 1800,
		"reward_credits": 400,
		"status": "IN_PROGRESS"
	})
	log_event("NUOVO CONTRATTO ASSEGNATO: %s" % new_id)
	_refresh_contracts_ui()

## Iniezione diretta di un contratto accettato (da StationHub o eventi diegetici)
func add_contract(contract_data: Dictionary) -> bool:
	var cid: String = str(contract_data.get("id"))
	for c in active_contracts:
		if c.get("id") == cid:
			# Aggiorna lo stato se già presente
			c["status"] = contract_data.get("status")
			_refresh_contracts_ui()
			return true
	
	var new_entry := {
		"id": cid,
		"title": contract_data.get("title"),
		"description": contract_data.get("description"),
		"reward_flux": contract_data.get("reward_flux"),
		"reward_credits": contract_data.get("reward_credits"),
		"status": contract_data.get("status"),
		"issuer": contract_data.get("issuer")
	}
	active_contracts.append(new_entry)
	log_event("NUOVO CONTRATTO ACQUISITO: %s" % new_entry["title"])
	_refresh_contracts_ui()
	return true

# -----------------------------------------------------------------------------
# Scatola Nera (Event Log)
# -----------------------------------------------------------------------------
func log_event(message: String) -> void:
	var entry := "[%s] %s" % [_get_formatted_timestamp(), message]
	black_box_events.append(entry)
	var max_entries: int = config_data.get("max_history_entries")
	if black_box_events.size() > max_entries:
		black_box_events.pop_front()
	_refresh_black_box_ui()

func _refresh_black_box_ui() -> void:
	if not event_log_text:
		return
	var text_content := ""
	for event in black_box_events:
		text_content += event + "\n"
	event_log_text.text = text_content

func _on_clear_log_pressed() -> void:
	if not can_manage_contracts:
		return
	black_box_events.clear()
	log_event("LOG SCATOLA NERA RESETTATO DAL COMANDO.")
	_refresh_black_box_ui()

# -----------------------------------------------------------------------------
# Note di Plancia & Gestione Drive
# -----------------------------------------------------------------------------
func _load_notes_list() -> void:
	if not notes_option_btn:
		return
	notes_option_btn.clear()
	notes_option_btn.add_item("--- Nuova Nota ---", 0)
	notes_option_btn.add_item("Diario del Capitano", 1)
	notes_option_btn.add_item("Rapporto Danni Ingegneria", 2)
	notes_option_btn.add_item("Appunti Personali Stazione", 3)
	
	if storage_notes_label:
		var target_drive := "Ship Drive" if (note_storage_type_btn and note_storage_type_btn.selected == 0) else "Terminal Drive"
		storage_notes_label.text = "STORAGE: %s" % target_drive

func _on_note_selected(index: int) -> void:
	if not note_edit_text:
		return
	if index == 1:
		note_edit_text.text = "Rapporto di bordo: Sistemi reattore stabili. Procediamo verso il punto di salto."
	elif index == 2:
		note_edit_text.text = "Pressione condotti O2 al 98%. Necessaria ispezione filtro secondario."
	elif index == 3:
		note_edit_text.text = "Promemoria: verificare le frequenze criptate prima della manovra di attracco."
	elif index == 0:
		note_edit_text.text = ""

func _on_save_note_pressed() -> void:
	if not note_edit_text or note_edit_text.text.strip_edges().is_empty():
		return
	
	var is_ship_drive: bool = (note_storage_type_btn == null or note_storage_type_btn.selected == 0)
	var content: String = note_edit_text.text
	var filename: String = "note_%d.txt" % Time.get_unix_time_from_system()
	
	if is_ship_drive and ShipDriveManager:
		var target_path := "Ship Drive/Documents/%s" % filename
		if ShipDriveManager.has_method("write_file"):
			ShipDriveManager.write_file(target_path, content)
		elif ShipDriveManager.has_method("create_file"):
			ShipDriveManager.create_file("Ship Drive/Documents", filename, content)
	elif not is_ship_drive and TerminalDriveManager:
		var target_path := "Terminal Drive/Documents/%s" % filename
		if TerminalDriveManager.has_method("write_file"):
			TerminalDriveManager.write_file(target_path, content)
		elif TerminalDriveManager.has_method("create_file"):
			TerminalDriveManager.create_file("Terminal Drive/Documents", filename, content)

	log_event("NOTA SALVATA: %s su %s" % [filename, "Ship Drive" if is_ship_drive else "Terminal Drive"])
	if status_label:
		status_label.text = "NOTA SALVATA CON SUCCESSO"
