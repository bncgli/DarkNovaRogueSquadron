class_name ShipDriveManagerSingleton
extends Node

## Singleton / Manager per la gestione dell'unità "Ship Drive" sul Desktop di GodotOS.
## Conforme allo standard architetturale di bordo (APP_ARCHITECTURE_STANDARD.md).
## Quando la nave è connessa ed operativa (SpaceWorldManager.is_ship_connected() == true / missione attiva),
## l'unità "Ship Drive" viene montata sul desktop ("user://files/Ship Drive").
## Tutti i file e le cartelle creati o modificati all'interno di Ship Drive
## vengono sincronizzati in tempo reale tra tutti i giocatori connessi.
## Quando la nave si disconnette o la missione termina, viene eseguito l'unmount della cartella.

signal ship_drive_mounted()
signal ship_drive_unmounted()
signal file_synced(path: String)
signal folder_synced(path: String)
signal folder_password_synced(path: String)
signal item_deleted(path: String)
signal item_renamed(old_path: String, new_path: String)
signal drive_synced()

const SHIP_DRIVE_NAME := "Ship Drive"
const SHIP_DRIVE_ROOT_DIR := "user://files/Ship Drive"

var is_drive_mounted: bool = false
var _is_syncing: bool = false
var _net_mgr: Node = null

func _ready() -> void:
	# All'avvio del gioco, se la nave non e' connessa (stato iniziale prima dell'avvio missione in solo o multiplayer),
	# garantiamo che Ship Drive sia smontato, che eventuali file/cartelle residue su disco siano rimosse
	# e che le finestre rimaste aperte dalla sessione precedente vengano chiuse automaticamente.
	if not is_ship_connected():
		is_drive_mounted = false
		if DirAccess.dir_exists_absolute(SHIP_DRIVE_ROOT_DIR):
			_delete_dir_recursive(SHIP_DRIVE_ROOT_DIR)
		_close_ship_drive_windows()
		var fpm := get_node_or_null("/root/FolderPasswordManager")
		if fpm:
			fpm.delete_path(SHIP_DRIVE_NAME)
	
	call_deferred("_connect_system_signals")

func _get_net_mgr() -> Node:
	if _net_mgr != null and is_instance_valid(_net_mgr):
		return _net_mgr
	if is_inside_tree():
		_net_mgr = get_node_or_null("/root/NetworkManager")
	return _net_mgr

## Verifica dello stato di connessione secondo lo standard APP_ARCHITECTURE_STANDARD.md
func is_ship_connected() -> bool:
	if SpaceWorldManager and SpaceWorldManager.has_method("is_ship_connected"):
		return SpaceWorldManager.is_ship_connected()
	var nm := _get_net_mgr()
	if nm and nm.has_method("is_ship_connected"):
		return nm.is_ship_connected()
	return false

func _connect_system_signals() -> void:
	# 1. Collegamento allo stato di connessione/missione della nave
	if SpaceWorldManager:
		if SpaceWorldManager.has_signal("ship_connection_changed") and not SpaceWorldManager.ship_connection_changed.is_connected(_on_ship_connection_changed):
			SpaceWorldManager.ship_connection_changed.connect(_on_ship_connection_changed)
	
	# 2. Collegamento a NetworkManager (segnali multiplayer e ciclo di vita missione)
	var nm := _get_net_mgr()
	if nm:
		if nm.has_signal("connection_state_changed") and not nm.connection_state_changed.is_connected(_on_network_connection_state_changed):
			nm.connection_state_changed.connect(_on_network_connection_state_changed)
		if nm.has_signal("mission_started") and not nm.mission_started.is_connected(_on_mission_started):
			nm.mission_started.connect(_on_mission_started)
		if nm.has_signal("mission_ended") and not nm.mission_ended.is_connected(_on_mission_ended):
			nm.mission_ended.connect(_on_mission_ended)
		if nm.has_signal("player_joined") and not nm.player_joined.is_connected(_on_network_player_joined):
			nm.player_joined.connect(_on_network_player_joined)
	
	_update_connection_state()

func _exit_tree() -> void:
	if SpaceWorldManager and SpaceWorldManager.has_signal("ship_connection_changed") and SpaceWorldManager.ship_connection_changed.is_connected(_on_ship_connection_changed):
		SpaceWorldManager.ship_connection_changed.disconnect(_on_ship_connection_changed)
	var nm := _get_net_mgr()
	if nm:
		if nm.has_signal("connection_state_changed") and nm.connection_state_changed.is_connected(_on_network_connection_state_changed):
			nm.connection_state_changed.disconnect(_on_network_connection_state_changed)
		if nm.has_signal("mission_started") and nm.mission_started.is_connected(_on_mission_started):
			nm.mission_started.disconnect(_on_mission_started)
		if nm.has_signal("mission_ended") and nm.mission_ended.is_connected(_on_mission_ended):
			nm.mission_ended.disconnect(_on_mission_ended)
		if nm.has_signal("player_joined") and nm.player_joined.is_connected(_on_network_player_joined):
			nm.player_joined.disconnect(_on_network_player_joined)

func _on_ship_connection_changed(_is_connected: bool) -> void:
	_update_connection_state()

func _on_network_connection_state_changed(_is_connected: bool, _is_host: bool) -> void:
	_update_connection_state()

func _on_mission_started() -> void:
	_update_connection_state()

func _on_mission_ended() -> void:
	_update_connection_state()

func _update_connection_state() -> void:
	var connected: bool = is_ship_connected()
	if connected and not is_drive_mounted:
		mount_drive()
	elif not connected:
		if is_drive_mounted:
			unmount_drive()
		else:
			# Assicura la rimozione di cartelle o finestre residue anche se non marcato come montato
			if DirAccess.dir_exists_absolute(SHIP_DRIVE_ROOT_DIR):
				_delete_dir_recursive(SHIP_DRIVE_ROOT_DIR)
				_refresh_desktop()
			_close_ship_drive_windows()

func _on_network_player_joined(peer_id: int, _player_data: Dictionary) -> void:
	var nm := _get_net_mgr()
	if nm and nm.get("is_host") and is_drive_mounted and is_inside_tree() and multiplayer.has_multiplayer_peer() and multiplayer.get_peers().has(peer_id):
		# Invia l'intero contenuto del Drive al nuovo peer appena connesso
		var snapshot: Array = _gather_drive_snapshot()
		_rpc_receive_full_sync.rpc_id(peer_id, snapshot)

# --- MOUNT & UNMOUNT LOGIC ---

func mount_drive() -> void:
	if is_drive_mounted:
		return
	
	is_drive_mounted = true
	
	# Crea la cartella principale se non esiste
	if not DirAccess.dir_exists_absolute(SHIP_DRIVE_ROOT_DIR):
		DirAccess.make_dir_recursive_absolute(SHIP_DRIVE_ROOT_DIR)
	
	var nm := _get_net_mgr()
	var is_host: bool = nm.get("is_host") if nm else true
	var is_solo: bool = nm.get("is_solo_mode") if nm else false
	
	if is_host or is_solo:
		_populate_default_ship_drive_files()
	elif nm and nm.get("is_connected_to_network"):
		# Chiedi la sincronizzazione completa all'Host
		_rpc_request_full_sync.rpc_id(1)
	
	_refresh_desktop()
	
	var notif := get_node_or_null("/root/NotificationManager")
	if notif and notif.has_method("spawn_notification"):
		notif.spawn_notification("Ship Drive montato sul Desktop.")
	
	ship_drive_mounted.emit()

func unmount_drive() -> void:
	if not is_drive_mounted:
		return
	
	is_drive_mounted = false
	
	# Chiudi tutte le finestre aperte relative a Ship Drive
	_close_ship_drive_windows()
	
	# Elimina localmente la cartella temporanea montata
	if DirAccess.dir_exists_absolute(SHIP_DRIVE_ROOT_DIR):
		_delete_dir_recursive(SHIP_DRIVE_ROOT_DIR)
	
	var fpm := get_node_or_null("/root/FolderPasswordManager")
	if fpm:
		fpm.delete_path(SHIP_DRIVE_NAME)
	
	_refresh_desktop()
	
	var notif := get_node_or_null("/root/NotificationManager")
	if notif and notif.has_method("spawn_notification"):
		notif.spawn_notification("Ship Drive smontato dal Desktop.")
	
	ship_drive_unmounted.emit()

func _populate_default_ship_drive_files() -> void:
	var files := DirAccess.get_files_at(SHIP_DRIVE_ROOT_DIR)
	var dirs := DirAccess.get_directories_at(SHIP_DRIVE_ROOT_DIR)
	if files.size() > 0 or dirs.size() > 0:
		return
	
	_write_file_content("Ship Drive/Ship Systems.txt", "=== DARK NOVA - SISTEMI NAVE ===\nReattore Principale: ONLINE (100% Efficienza)\nPropulsione Sub-Luce: ATTIVA\nScudi Deflettori: OPERATIVI\nArray Sensori & Cams: 6 Canali Attivi (Prua, Poppa, Babordo, Tribordo, Dorsale, Ventrale)\nSottosistemi di Guida: Calibrati\n")
	_write_file_content("Ship Drive/Flight Log.txt", "=== REGISTRO DI BORDO ===\n[STARDATE 7815.4] Connessione al sistema centrale stabilita.\nTutti i sistemi della Dark Nova sono pronti alla navigazione spaziale.\nEquipaggio autorizzato ad accedere all'unita' condivisa Ship Drive.\n")
	_write_file_content("Ship Drive/Crew Directives.txt", "=== DIRETTIVE EQUIPAGGIO ===\n1. Mantenere monitorati i feed video delle telecamere esterne durante la navigazione.\n2. Coordinare le manovre di volo e la spinta propulsori con la plancia.\n3. Condividere report di missione e file di rotta all'interno dello Ship Drive.\n")
	
	# Programmi Nave e Configurazione .dat protetta
	_write_file_content("Ship Drive/Programs/FlightControls/flight_config.dat", "# DARK NOVA FLIGHT CONTROLS RUNTIME CONFIGURATION\n# WARNING: SYSTEM CONFIGURATION FILE - ACTIVE FLIGHT TUNING\n[SYSTEM]\napp_name=FlightControls\nversion=1.0.4\nstatus=OPERATIONAL\nrcs_subsystem=ACTIVE\n\n[FLIGHT_DYNAMICS]\nmax_linear_speed=20.0\nlinear_acceleration=35.0\nlinear_deceleration=20.0\nmax_angular_speed=2.5\nangular_acceleration=8.0\nangular_deceleration=6.0\n\n[SPEED_MODES]\nturbo_multiplier=2.0\nprecision_multiplier=0.4\n")
	_write_file_content("Ship Drive/Programs/FlightControls/thrusters_tuning.dat", "# RCS & MAIN THRUSTERS TUNING MATRIX\n[THRUSTERS]\nrcs_power_rate=1.0\npitch_thrust_mult=1.0\nyaw_thrust_mult=1.0\nroll_thrust_mult=1.0\nvertical_thrust_mult=1.0\noverclock_limit=1.5\n")
	
	_write_file_content("Ship Drive/Programs/Cams/cams_config.dat", "# DARK NOVA CAMS ARRAY RUNTIME CONFIGURATION\n# WARNING: SENSORS & OPTICS CONFIGURATION FILE\n[SYSTEM]\napp_name=Cams\nversion=1.0.4\nstatus=OPERATIONAL\nsensor_array=CCTV_6CH\n\n[OPTICS]\ndefault_fov=75.0\nmin_fov=30.0\nmax_fov=100.0\nzoom_step=10.0\nnight_vision_intensity=0.18\ntactical_hud_contrast=0.18\nthermal_intensity=0.22\n")
	_write_file_content("Ship Drive/Programs/Cams/optics_tuning.dat", "# OPTICS & SENSOR CALIBRATION MATRIX\n[SENSORS]\nsignal_boost=1.0\nnoise_reduction=1.0\nrefresh_rate_hz=60.0\ncrosshair_style=STANDARD\noverclock_gain=1.0\n")
	
	_write_file_content("Ship Drive/Programs/DuctDrone/duct_drone_config.dat", "# DARK NOVA DUCT DRONE RUNTIME CONFIGURATION\n# WARNING: SYSTEM CONFIGURATION FILE - MAINTENANCE & REPAIR ROBOT\n[SYSTEM]\napp_name=DuctDrone\nversion=1.0.4\nstatus=OPERATIONAL\nmaintenance_subsystem=ACTIVE\n\n[DRONE_DYNAMICS]\nlinear_speed=175.0\nlinear_acceleration=650.0\nlinear_deceleration=750.0\nrotate_speed=3.0\n\n[BATTERY_MANAGEMENT]\nbattery_max=100.0\nbattery_drain_move=0.35\nbattery_drain_lights=0.75\nbattery_drain_radar=3.5\nbattery_drain_repair=6.0\n\n[MAINTENANCE]\nradar_scan_radius_max=160.0\nrepair_range=42.0\nrepair_speed_multiplier=1.0\n")
	_write_file_content("Ship Drive/Programs/DuctDrone/drone_tuning.dat", "# DUCT DRONE CALIBRATION & EFFICIENCY MATRIX\n[TUNING]\nturbo_multiplier=2.0\nprecision_multiplier=0.5\nrepair_efficiency=1.0\nradar_intensity=1.0\noverclock_speed_gain=1.0\n")
	
	_write_file_content("Ship Drive/Programs/PowerGrid/power_grid_config.dat", "# DARK NOVA POWER GRID RUNTIME CONFIGURATION\n# WARNING: ELECTRICAL GRID AND POWER DISTRIBUTION MATRIX\n[SYSTEM]\napp_name=PowerGrid\nversion=1.0.4\nstatus=OPERATIONAL\nmode=AUTOMATIC_BALANCING\n\n[GRID_SETTINGS]\nreactor_output_mw=1200.0\naux_generator_mw=450.0\njunction_switch_delay=0.25\noverload_threshold_pct=110.0\nreroute_efficiency_loss=0.05\n\n[CIRCUIT_PROTECTION]\nbreaker_trip_threshold=1.4\nshort_circuit_damping=0.85\nauto_reroute_on_short=false\n")
	_write_file_content("Ship Drive/Programs/PowerGrid/grid_tuning.dat", "# POWER GRID CALIBRATION & TUNING MATRIX\n[TUNING]\npower_efficiency_mult=1.0\nbackup_line_conductivity=0.95\nswitch_rate_hz=10.0\nregime_boost=1.0\noverclock_tolerance=1.2\n")
	
	var fpm := get_node_or_null("/root/FolderPasswordManager")
	if fpm:
		fpm.set_password("Ship Drive/Programs/FlightControls", "FLIGHT-7815")
		fpm.set_password("Ship Drive/Programs/Cams", "CAMS-7815")
		fpm.set_password("Ship Drive/Programs/DuctDrone", "DRONE-7815")
		fpm.set_password("Ship Drive/Programs/PowerGrid", "GRID-7815")

func _close_ship_drive_windows() -> void:
	if not is_inside_tree():
		return
	
	# Chiudi finestre FileManager
	for fm in get_tree().get_nodes_in_group("file_manager_window"):
		if is_instance_valid(fm) and fm.get("file_path") != null and (fm.file_path == SHIP_DRIVE_NAME or fm.file_path.begins_with(SHIP_DRIVE_NAME + "/") or fm.file_path.begins_with(SHIP_DRIVE_NAME + "\\")):
			if fm.has_method("close_window"):
				fm.close_window()
	
	# Chiudi finestre TextEditor
	for te in get_tree().get_nodes_in_group("text_editor_window"):
		if is_instance_valid(te) and te.get("file_path") != null and (te.file_path == SHIP_DRIVE_NAME or te.file_path.begins_with(SHIP_DRIVE_NAME + "/") or te.file_path.begins_with(SHIP_DRIVE_NAME + "\\")):
			var fake_win: FakeWindow = te.get_node_or_null("../..") as FakeWindow
			if fake_win and is_instance_valid(fake_win):
				fake_win._on_close_button_pressed()
			elif is_instance_valid(te):
				var p := te.get_parent()
				while p:
					if p is FakeWindow or p.has_method("_on_close_button_pressed"):
						p._on_close_button_pressed()
						break
					p = p.get_parent()

	# Chiudi qualsiasi finestra che mostri "Ship Drive" nel titolo
	for win in get_tree().get_nodes_in_group("window"):
		if is_instance_valid(win) and win.has_node("Top Bar/Title Text"):
			var title_lbl: RichTextLabel = win.get_node("Top Bar/Title Text") as RichTextLabel
			if title_lbl and (title_lbl.text.contains(SHIP_DRIVE_NAME)):
				if win.has_method("_on_close_button_pressed"):
					win._on_close_button_pressed()

func _delete_dir_recursive(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for sub_dir in DirAccess.get_directories_at(path):
		_delete_dir_recursive("%s/%s" % [path, sub_dir])
	for file_name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute("%s/%s" % [path, file_name])
	DirAccess.remove_absolute(path)

func _write_file_content(rel_path: String, content: String) -> void:
	rel_path = _normalize_rel_path(rel_path)
	var abs_path := "user://files/%s" % rel_path
	var base_dir := abs_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(base_dir):
		DirAccess.make_dir_recursive_absolute(base_dir)
	var file := FileAccess.open(abs_path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()

func _normalize_rel_path(p: String) -> String:
	var clean := p.replace("\\", "/").strip_edges()
	while "//" in clean:
		clean = clean.replace("//", "/")
	return clean.trim_prefix("/").trim_suffix("/")

# --- SYNCHRONIZATION DISPATCHERS ---

func sync_file(rel_path: String, content: String) -> void:
	if _is_syncing or not is_drive_mounted:
		return
	rel_path = _normalize_rel_path(rel_path)
	if not _is_path_in_ship_drive(rel_path):
		return
	
	var nm := _get_net_mgr()
	if not nm or not nm.get("is_connected_to_network"):
		return
	
	if nm.get("is_host"):
		_rpc_sync_file.rpc(rel_path, content)
	else:
		_rpc_client_sync_file.rpc_id(1, rel_path, content)

func sync_folder(rel_path: String) -> void:
	if _is_syncing or not is_drive_mounted:
		return
	rel_path = _normalize_rel_path(rel_path)
	if not _is_path_in_ship_drive(rel_path):
		return
	
	var nm := _get_net_mgr()
	if not nm or not nm.get("is_connected_to_network"):
		return
	
	if nm.get("is_host"):
		_rpc_sync_folder.rpc(rel_path)
	else:
		_rpc_client_sync_folder.rpc_id(1, rel_path)

func sync_folder_password(rel_path: String, password_str: String) -> void:
	if _is_syncing or not is_drive_mounted:
		return
	rel_path = _normalize_rel_path(rel_path)
	if not _is_path_in_ship_drive(rel_path):
		return
	
	var nm := _get_net_mgr()
	if not nm or not nm.get("is_connected_to_network"):
		return
	
	if nm.get("is_host"):
		_rpc_sync_folder_password.rpc(rel_path, password_str)
	else:
		_rpc_client_sync_folder_password.rpc_id(1, rel_path, password_str)

func sync_remove_folder_password(rel_path: String) -> void:
	if _is_syncing or not is_drive_mounted:
		return
	rel_path = _normalize_rel_path(rel_path)
	if not _is_path_in_ship_drive(rel_path):
		return
	
	var nm := _get_net_mgr()
	if not nm or not nm.get("is_connected_to_network"):
		return
	
	if nm.get("is_host"):
		_rpc_sync_remove_folder_password.rpc(rel_path)
	else:
		_rpc_client_sync_remove_folder_password.rpc_id(1, rel_path)

func sync_rename(old_rel_path: String, new_rel_path: String, is_dir: bool) -> void:
	if _is_syncing or not is_drive_mounted:
		return
	old_rel_path = _normalize_rel_path(old_rel_path)
	new_rel_path = _normalize_rel_path(new_rel_path)
	if not _is_path_in_ship_drive(old_rel_path) and not _is_path_in_ship_drive(new_rel_path):
		return
	
	var nm := _get_net_mgr()
	if not nm or not nm.get("is_connected_to_network"):
		return
	
	if nm.get("is_host"):
		_rpc_sync_rename.rpc(old_rel_path, new_rel_path, is_dir)
	else:
		_rpc_client_sync_rename.rpc_id(1, old_rel_path, new_rel_path, is_dir)

func sync_delete(rel_path: String, is_dir: bool) -> void:
	if _is_syncing or not is_drive_mounted:
		return
	rel_path = _normalize_rel_path(rel_path)
	if not _is_path_in_ship_drive(rel_path):
		return
	
	var nm := _get_net_mgr()
	if not nm or not nm.get("is_connected_to_network"):
		return
	
	if nm.get("is_host"):
		_rpc_sync_delete.rpc(rel_path, is_dir)
	else:
		_rpc_client_sync_delete.rpc_id(1, rel_path, is_dir)

func sync_path_recursive(rel_path: String) -> void:
	if _is_syncing or not is_drive_mounted:
		return
	rel_path = _normalize_rel_path(rel_path)
	if not _is_path_in_ship_drive(rel_path):
		return
	
	var abs_path := "user://files/%s" % rel_path
	if DirAccess.dir_exists_absolute(abs_path):
		sync_folder(rel_path)
		for dir_name in DirAccess.get_directories_at(abs_path):
			sync_path_recursive("%s/%s" % [rel_path, dir_name])
		for file_name in DirAccess.get_files_at(abs_path):
			var file_rel := "%s/%s" % [rel_path, file_name]
			var f := FileAccess.open("user://files/%s" % file_rel, FileAccess.READ)
			if f:
				var text_content := f.get_as_text()
				f.close()
				sync_file(file_rel, text_content)
	elif FileAccess.file_exists(abs_path):
		var f := FileAccess.open(abs_path, FileAccess.READ)
		if f:
			var text_content := f.get_as_text()
			f.close()
			sync_file(rel_path, text_content)

func _is_path_in_ship_drive(path: String) -> bool:
	var norm := _normalize_rel_path(path)
	return norm == SHIP_DRIVE_NAME or norm.begins_with(SHIP_DRIVE_NAME + "/")

# --- RPC HANDLERS ---

@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_full_sync() -> void:
	var nm := _get_net_mgr()
	if not nm or not nm.get("is_host"):
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	var snapshot := _gather_drive_snapshot()
	_rpc_receive_full_sync.rpc_id(sender_id, snapshot)

@rpc("authority", "call_remote", "reliable")
func _rpc_receive_full_sync(snapshot: Array) -> void:
	_is_syncing = true
	
	if not DirAccess.dir_exists_absolute(SHIP_DRIVE_ROOT_DIR):
		DirAccess.make_dir_recursive_absolute(SHIP_DRIVE_ROOT_DIR)
	
	var fpm := get_node_or_null("/root/FolderPasswordManager")
	if fpm:
		fpm.delete_path(SHIP_DRIVE_NAME)
	
	for item in snapshot:
		if not item is Dictionary:
			continue
		var item_path: String = _normalize_rel_path(item.get("path", ""))
		var is_dir: bool = item.get("is_dir", false)
		var abs_path := "user://files/%s" % item_path
		
		if is_dir:
			if not DirAccess.dir_exists_absolute(abs_path):
				DirAccess.make_dir_recursive_absolute(abs_path)
			if item.has("password") and not str(item["password"]).is_empty() and fpm:
				fpm.set_password(item_path, str(item["password"]))
		else:
			var base_dir := abs_path.get_base_dir()
			if not DirAccess.dir_exists_absolute(base_dir):
				DirAccess.make_dir_recursive_absolute(base_dir)
			var content: String = item.get("content", "")
			var f := FileAccess.open(abs_path, FileAccess.WRITE)
			if f:
				f.store_string(content)
				f.close()
	
	_is_syncing = false
	_refresh_all_views()
	drive_synced.emit()

@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_sync_file(rel_path: String, content: String) -> void:
	var nm := _get_net_mgr()
	if not nm or not nm.get("is_host"):
		return
	rel_path = _normalize_rel_path(rel_path)
	var sender_id: int = multiplayer.get_remote_sender_id()
	_apply_file_write(rel_path, content)
	# Inoltra a tutti gli altri client
	for peer_id in multiplayer.get_peers():
		if peer_id != sender_id and peer_id != 1:
			_rpc_sync_file.rpc_id(peer_id, rel_path, content)

@rpc("authority", "call_remote", "reliable")
func _rpc_sync_file(rel_path: String, content: String) -> void:
	rel_path = _normalize_rel_path(rel_path)
	_apply_file_write(rel_path, content)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_sync_folder(rel_path: String) -> void:
	var nm := _get_net_mgr()
	if not nm or not nm.get("is_host"):
		return
	rel_path = _normalize_rel_path(rel_path)
	var sender_id: int = multiplayer.get_remote_sender_id()
	_apply_folder_create(rel_path)
	for peer_id in multiplayer.get_peers():
		if peer_id != sender_id and peer_id != 1:
			_rpc_sync_folder.rpc_id(peer_id, rel_path)

@rpc("authority", "call_remote", "reliable")
func _rpc_sync_folder(rel_path: String) -> void:
	rel_path = _normalize_rel_path(rel_path)
	_apply_folder_create(rel_path)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_sync_folder_password(rel_path: String, password_str: String) -> void:
	var nm := _get_net_mgr()
	if not nm or not nm.get("is_host"):
		return
	rel_path = _normalize_rel_path(rel_path)
	var sender_id: int = multiplayer.get_remote_sender_id()
	_apply_folder_password(rel_path, password_str)
	for peer_id in multiplayer.get_peers():
		if peer_id != sender_id and peer_id != 1:
			_rpc_sync_folder_password.rpc_id(peer_id, rel_path, password_str)

@rpc("authority", "call_remote", "reliable")
func _rpc_sync_folder_password(rel_path: String, password_str: String) -> void:
	rel_path = _normalize_rel_path(rel_path)
	_apply_folder_password(rel_path, password_str)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_sync_remove_folder_password(rel_path: String) -> void:
	var nm := _get_net_mgr()
	if not nm or not nm.get("is_host"):
		return
	rel_path = _normalize_rel_path(rel_path)
	var sender_id: int = multiplayer.get_remote_sender_id()
	_apply_remove_folder_password(rel_path)
	for peer_id in multiplayer.get_peers():
		if peer_id != sender_id and peer_id != 1:
			_rpc_sync_remove_folder_password.rpc_id(peer_id, rel_path)

@rpc("authority", "call_remote", "reliable")
func _rpc_sync_remove_folder_password(rel_path: String) -> void:
	rel_path = _normalize_rel_path(rel_path)
	_apply_remove_folder_password(rel_path)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_sync_rename(old_rel_path: String, new_rel_path: String, is_dir: bool) -> void:
	var nm := _get_net_mgr()
	if not nm or not nm.get("is_host"):
		return
	old_rel_path = _normalize_rel_path(old_rel_path)
	new_rel_path = _normalize_rel_path(new_rel_path)
	var sender_id: int = multiplayer.get_remote_sender_id()
	_apply_rename(old_rel_path, new_rel_path, is_dir)
	for peer_id in multiplayer.get_peers():
		if peer_id != sender_id and peer_id != 1:
			_rpc_sync_rename.rpc_id(peer_id, old_rel_path, new_rel_path, is_dir)

@rpc("authority", "call_remote", "reliable")
func _rpc_sync_rename(old_rel_path: String, new_rel_path: String, is_dir: bool) -> void:
	old_rel_path = _normalize_rel_path(old_rel_path)
	new_rel_path = _normalize_rel_path(new_rel_path)
	_apply_rename(old_rel_path, new_rel_path, is_dir)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_sync_delete(rel_path: String, is_dir: bool) -> void:
	var nm := _get_net_mgr()
	if not nm or not nm.get("is_host"):
		return
	rel_path = _normalize_rel_path(rel_path)
	var sender_id: int = multiplayer.get_remote_sender_id()
	_apply_delete(rel_path, is_dir)
	for peer_id in multiplayer.get_peers():
		if peer_id != sender_id and peer_id != 1:
			_rpc_sync_delete.rpc_id(peer_id, rel_path, is_dir)

@rpc("authority", "call_remote", "reliable")
func _rpc_sync_delete(rel_path: String, is_dir: bool) -> void:
	rel_path = _normalize_rel_path(rel_path)
	_apply_delete(rel_path, is_dir)

# --- LOCAL APPLICATION HELPERS ---

func _apply_file_write(rel_path: String, content: String) -> void:
	rel_path = _normalize_rel_path(rel_path)
	_is_syncing = true
	_write_file_content(rel_path, content)
	
	# Aggiorna gli editor aperti su questo file
	if is_inside_tree():
		for te in get_tree().get_nodes_in_group("text_editor_window"):
			if is_instance_valid(te):
				var te_path: String = _normalize_rel_path(te.get("file_path") if te.get("file_path") != null else "")
				if te_path == rel_path:
					te.text = content
					te.text_edited = false
					var top_bar_title = te.get_node_or_null("../../Top Bar/Title Text")
					if top_bar_title:
						top_bar_title.text = "[center]%s" % rel_path.split("/")[-1]
	
	# Ricarica file manager che visualizzano la cartella contenitrice
	var parent_dir := rel_path.get_base_dir()
	_refresh_file_managers_for_path(parent_dir)
	
	_is_syncing = false
	file_synced.emit(rel_path)

func _apply_folder_create(rel_path: String) -> void:
	rel_path = _normalize_rel_path(rel_path)
	_is_syncing = true
	var abs_path := "user://files/%s" % rel_path
	if not DirAccess.dir_exists_absolute(abs_path):
		DirAccess.make_dir_recursive_absolute(abs_path)
	
	var parent_dir := rel_path.get_base_dir()
	_refresh_file_managers_for_path(parent_dir)
	
	_is_syncing = false
	folder_synced.emit(rel_path)

func _apply_folder_password(rel_path: String, password_str: String) -> void:
	rel_path = _normalize_rel_path(rel_path)
	_is_syncing = true
	var fpm := get_node_or_null("/root/FolderPasswordManager")
	if fpm:
		fpm.set_password(rel_path, password_str)
	var parent_dir := rel_path.get_base_dir()
	_refresh_file_managers_for_path(parent_dir)
	_is_syncing = false
	folder_password_synced.emit(rel_path)

func _apply_remove_folder_password(rel_path: String) -> void:
	rel_path = _normalize_rel_path(rel_path)
	_is_syncing = true
	var fpm := get_node_or_null("/root/FolderPasswordManager")
	if fpm:
		fpm.remove_password(rel_path)
	var parent_dir := rel_path.get_base_dir()
	_refresh_file_managers_for_path(parent_dir)
	_is_syncing = false
	folder_password_synced.emit(rel_path)

func _apply_rename(old_rel_path: String, new_rel_path: String, is_dir: bool) -> void:
	old_rel_path = _normalize_rel_path(old_rel_path)
	new_rel_path = _normalize_rel_path(new_rel_path)
	_is_syncing = true
	var old_abs := "user://files/%s" % old_rel_path
	var new_abs := "user://files/%s" % new_rel_path
	
	if is_dir:
		if DirAccess.dir_exists_absolute(old_abs):
			DirAccess.rename_absolute(old_abs, new_abs)
		var fpm := get_node_or_null("/root/FolderPasswordManager")
		if fpm:
			fpm.rename_path(old_rel_path, new_rel_path)
	else:
		if FileAccess.file_exists(old_abs):
			DirAccess.rename_absolute(old_abs, new_abs)
	
	if is_inside_tree():
		for te in get_tree().get_nodes_in_group("text_editor_window"):
			if is_instance_valid(te):
				var te_path: String = _normalize_rel_path(te.get("file_path") if te.get("file_path") != null else "")
				if te_path == old_rel_path:
					te.file_path = new_rel_path
		for fm in get_tree().get_nodes_in_group("file_manager_window"):
			if is_instance_valid(fm):
				var fm_path: String = _normalize_rel_path(fm.file_path)
				if fm_path == old_rel_path or fm_path.begins_with(old_rel_path + "/"):
					fm.file_path = fm_path.replace(old_rel_path, new_rel_path)
					fm.reload_window(fm.file_path)
	
	var parent_dir := old_rel_path.get_base_dir()
	_refresh_file_managers_for_path(parent_dir)
	var new_parent_dir := new_rel_path.get_base_dir()
	if new_parent_dir != parent_dir:
		_refresh_file_managers_for_path(new_parent_dir)
	
	_is_syncing = false
	item_renamed.emit(old_rel_path, new_rel_path)

func _apply_delete(rel_path: String, is_dir: bool) -> void:
	rel_path = _normalize_rel_path(rel_path)
	_is_syncing = true
	var abs_path := "user://files/%s" % rel_path
	
	if is_dir:
		if DirAccess.dir_exists_absolute(abs_path):
			_delete_dir_recursive(abs_path)
		var fpm := get_node_or_null("/root/FolderPasswordManager")
		if fpm:
			fpm.delete_path(rel_path)
	else:
		if FileAccess.file_exists(abs_path):
			DirAccess.remove_absolute(abs_path)
	
	# Chiudi finestre associate
	if is_inside_tree():
		for fm in get_tree().get_nodes_in_group("file_manager_window"):
			if is_instance_valid(fm):
				var fm_path: String = _normalize_rel_path(fm.file_path)
				if fm_path == rel_path or fm_path.begins_with(rel_path + "/"):
					fm.close_window()
		for te in get_tree().get_nodes_in_group("text_editor_window"):
			if is_instance_valid(te):
				var te_path: String = _normalize_rel_path(te.get("file_path") if te.get("file_path") != null else "")
				if te_path == rel_path or te_path.begins_with(rel_path + "/"):
					var fake_win: FakeWindow = te.get_node_or_null("../..") as FakeWindow
					if fake_win and is_instance_valid(fake_win):
						fake_win._on_close_button_pressed()
	
	var parent_dir := rel_path.get_base_dir()
	_refresh_file_managers_for_path(parent_dir)
	
	_is_syncing = false
	item_deleted.emit(rel_path)

# --- REFRESH UTILITIES ---

func _refresh_desktop() -> void:
	if not is_inside_tree():
		return
	var desktop: DesktopFileManager = get_tree().get_first_node_in_group("desktop_file_manager") as DesktopFileManager
	if desktop and is_instance_valid(desktop):
		desktop.populate_file_manager()

func _refresh_file_managers_for_path(folder_path: String) -> void:
	if not is_inside_tree():
		return
	var norm_folder := _normalize_rel_path(folder_path)
	if norm_folder.is_empty():
		_refresh_desktop()
	for fm in get_tree().get_nodes_in_group("file_manager_window"):
		if is_instance_valid(fm):
			var norm_fm := _normalize_rel_path(fm.file_path)
			if norm_fm == norm_folder:
				fm.reload_window(fm.file_path)

func _refresh_all_views() -> void:
	_refresh_desktop()
	if is_inside_tree():
		for fm in get_tree().get_nodes_in_group("file_manager_window"):
			if is_instance_valid(fm):
				fm.reload_window("")

func _gather_drive_snapshot() -> Array:
	var snapshot: Array = []
	if not DirAccess.dir_exists_absolute(SHIP_DRIVE_ROOT_DIR):
		return snapshot
	var fpm := get_node_or_null("/root/FolderPasswordManager")
	if fpm and fpm.has_password(SHIP_DRIVE_NAME):
		snapshot.append({
			"path": SHIP_DRIVE_NAME,
			"is_dir": true,
			"password": fpm.get_password(SHIP_DRIVE_NAME)
		})
	_gather_snapshot_recursive(SHIP_DRIVE_NAME, snapshot)
	return snapshot

func _gather_snapshot_recursive(rel_path: String, snapshot: Array) -> void:
	var abs_path := "user://files/%s" % rel_path
	var fpm := get_node_or_null("/root/FolderPasswordManager")
	for dir_name in DirAccess.get_directories_at(abs_path):
		var sub_rel := "%s/%s" % [rel_path, dir_name]
		var item_dict := {
			"path": sub_rel,
			"is_dir": true
		}
		if fpm and fpm.has_password(sub_rel):
			item_dict["password"] = fpm.get_password(sub_rel)
		snapshot.append(item_dict)
		_gather_snapshot_recursive(sub_rel, snapshot)
	for file_name in DirAccess.get_files_at(abs_path):
		var file_rel := "%s/%s" % [rel_path, file_name]
		var f := FileAccess.open("user://files/%s" % file_rel, FileAccess.READ)
		var content := ""
		if f:
			content = f.get_as_text()
			f.close()
		snapshot.append({
			"path": file_rel,
			"is_dir": false,
			"content": content
		})
