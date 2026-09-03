extends BaseApp
class_name PowerGridApp

const RoomPowerEntry = preload("res://Applications/PowerGrid/Components/room_power_entry.gd")

## Applicazione GodotOS per il monitoraggio e la gestione energetica della nave.
## Gestisce l'alimentazione delle stanze, i carichi dei dispositivi e il bilanciamento energetico.
## Conforme allo standard architetturale di bordo (APP_ARCHITECTURE_STANDARD.md).

const APP_TITLE: String = "Power Grid - Rete Elettrica Nave"
const DEFAULT_WINDOW_SIZE: Vector2 = Vector2(980, 620)
const BLUEPRINT_SIZE: Vector2 = Vector2(600, 450)

const CONFIG_PATH_PRIMARY: String = "Ship Drive/Programs/PowerGrid/power_grid_config.dat"
const CONFIG_PATH_FALLBACK: String = "Ship Drive/Programs/PowerGrid/config.dat"
const TUNING_PATH_PRIMARY: String = "Ship Drive/Programs/PowerGrid/grid_tuning.dat"
const TUNING_PATH_FALLBACK: String = "Ship Drive/Programs/PowerGrid/tuning.dat"

# Riferimenti nodi UI
@onready var disconnected_overlay: Control = get_node_or_null("%DisconnectedOverlay")
@onready var status_badge: Label = get_node_or_null("%StatusBadge")
@onready var role_badge: Label = get_node_or_null("%RoleBadge")
@onready var dat_status_badge: Label = get_node_or_null("%DatStatusBadge")
@onready var total_power_label: Label = get_node_or_null("%TotalPowerLabel")
@onready var efficiency_label: Label = get_node_or_null("%EfficiencyLabel")
@onready var damage_count_label: Label = get_node_or_null("%DamageCountLabel")

# Inspector UI
@onready var inspector_title_label: Label = get_node_or_null("%InspectorTitleLabel")
@onready var inspector_desc_label: Label = get_node_or_null("%InspectorDescLabel")
@onready var inspector_inputs_label: Label = get_node_or_null("%InspectorInputsLabel")
@onready var inspector_regime_label: Label = get_node_or_null("%InspectorRegimeLabel")
@onready var inspector_regime_bar: ProgressBar = get_node_or_null("%InspectorRegimeBar")

# Mini-Terminal UI
@onready var terminal_output: RichTextLabel = get_node_or_null("%TerminalOutput")
@onready var terminal_input: LineEdit = get_node_or_null("%TerminalInput")
@onready var btn_autobalance: Button = get_node_or_null("%BtnAutobalance")
@onready var btn_diagnostics: Button = get_node_or_null("%BtnDiagnostics")
@onready var reload_config_button: Button = get_node_or_null("%ReloadConfigButton")

var can_control: bool = true

# Parametri runtime caricati dai file .dat protetti
var active_config: Dictionary = {
	"reactor_output_mw": 1200.0,
	"aux_generator_mw": 450.0,
	"overload_threshold_pct": 110.0,
	"breaker_trip_threshold": 1.4,
	"short_circuit_damping": 0.85,
	"auto_reroute_on_short": false,
	"power_efficiency_mult": 1.0,
	"regime_boost": 1.0,
	"overclock_tolerance": 1.2,
	"is_dat_loaded": false
}

# Strutture dati
var rooms_data: Array[Dictionary] = []
var room_widgets: Dictionary = {}
var system_states: Dictionary = {} # category -> bool
var selected_room_id: String = ""

# Terminal History
var terminal_history: Array[String] = []
var terminal_history_index: int = 0

# Telemetria
var total_gen_mw: float = 0.0
var total_cons_mw: float = 0.0
var net_power_mw: float = 0.0

@onready var room_list_container: VBoxContainer = %RoomListContainer

signal system_power_changed(category: String, is_powered: bool)

func _ready() -> void:
	_configure_window(APP_TITLE, DEFAULT_WINDOW_SIZE)
	_setup_ui_events()
	load_dat_configuration()
	_connect_system_signals()
	_update_connection_state()
	_update_permissions()
	_init_room_list()
	_refresh_power_logic()
	_print_terminal_welcome()

func _process(_delta: float) -> void:
	pass

func _setup_ui_events() -> void:
	if terminal_input:
		terminal_input.text_submitted.connect(_on_terminal_text_submitted)
	if btn_autobalance:
		btn_autobalance.pressed.connect(autobalance_grid)
	if btn_diagnostics:
		btn_diagnostics.pressed.connect(_run_diagnostics)
	if reload_config_button:
		reload_config_button.pressed.connect(_on_reload_config_pressed)

func _init_room_list() -> void:
	for child in room_list_container.get_children():
		child.queue_free()
	room_widgets.clear()
	
	var bp := _get_blueprint()
	if not bp:
		return
	
	rooms_data.clear()
	for r in bp.rooms:
		if r is Dictionary:
			rooms_data.append(r)
		elif r.has_method("to_dict"):
			rooms_data.append(r.to_dict())
	
	var entry_scene: PackedScene = load("res://Applications/PowerGrid/Components/room_power_entry.tscn")
	for room in rooms_data:
		var rid: String = str(room.get("id", ""))
		if rid.is_empty(): continue
		
		var entry := entry_scene.instantiate() as RoomPowerEntry
		room_list_container.add_child(entry)
		entry.setup(room)
		entry.power_toggled.connect(_on_room_power_toggled)
		if entry.has_signal("room_selected"):
			entry.room_selected.connect(_on_room_selected)
		room_widgets[rid] = entry
		entry.set_enabled(can_control)
	
	if selected_room_id.is_empty() and not rooms_data.is_empty():
		selected_room_id = str(rooms_data[0].get("id", ""))
	
	_update_selected_room_visuals()
	_update_inspector()

func _on_room_selected(room_id: String) -> void:
	selected_room_id = room_id
	_update_selected_room_visuals()
	_update_inspector()

func _update_selected_room_visuals() -> void:
	for rid in room_widgets:
		var w = room_widgets[rid]
		if w and w.has_method("set_selected_visual"):
			w.set_selected_visual(rid == selected_room_id)

func _on_room_power_toggled(room_id: String, is_on: bool) -> void:
	var room := _get_room_by_id(room_id)
	if not room.is_empty():
		room["is_on"] = is_on
		var st_col := "#33ff66" if is_on else "#ff4040"
		_print_terminal("[color=#ffffaa]Stanza %s: [color=%s]%s[/color][/color]" % [str(room.get("name", "Ignota")), st_col, "ACCESA" if is_on else "SPENTA"])
		_refresh_power_logic()
		
		# Sync with blueprint if possible
		var bp := _get_blueprint()
		if bp:
			bp.emit_changed()

func _get_room_by_id(room_id: String) -> Dictionary:
	for r in rooms_data:
		if str(r.get("id", "")) == room_id:
			return r
	return {}

func _refresh_power_logic() -> void:
	total_gen_mw = 0.0
	total_cons_mw = 0.0
	
	var categories_present := {} # category -> bool
	
	for room in rooms_data:
		var room_on: bool = bool(room.get("is_on", false))
		var devices: Array = room.get("devices", [])
		
		for dev in devices:
			var p := float(dev.get("power_mw", 0.0))
			var cat: Variant = dev.get("category", "unknown")
			
			if room_on:
				if p > 0:
					total_gen_mw += p
				else:
					total_cons_mw += abs(p)
				
				categories_present[cat] = true
	
	net_power_mw = total_gen_mw - total_cons_mw
	
	_update_ui_telemetry()
	_update_system_effects(categories_present)
	_update_inspector()

func _update_ui_telemetry() -> void:
	if total_power_label:
		total_power_label.text = "GEN: %.0f / CONS: %.0f MW" % [total_gen_mw, total_cons_mw]
	
	if efficiency_label:
		var net_text := "BILANCIO: %.0f MW" % net_power_mw
		efficiency_label.text = net_text
		if net_power_mw >= 0:
			efficiency_label.modulate = Color(0.2, 1.0, 0.4, 1.0) # #33ff66
		else:
			efficiency_label.modulate = Color(1.0, 0.25, 0.25, 1.0) # #ff4040
	
	# Update room widgets power display
	for room_id in room_widgets:
		var room := _get_room_by_id(room_id)
		if not room.is_empty():
			var room_p := 0.0
			for dev in room.get("devices", []):
				room_p += float(dev.get("power_mw", 0.0))
			if room_p == 0.0 and room.has("power_mw"):
				room_p = float(room.get("power_mw", 0.0))
			room_widgets[room_id].update_power(room_p)

func _update_inspector() -> void:
	if selected_room_id.is_empty() and not rooms_data.is_empty():
		selected_room_id = str(rooms_data[0].get("id", ""))
	
	var room := _get_room_by_id(selected_room_id)
	if room.is_empty():
		if inspector_title_label:
			inspector_title_label.text = "Seleziona Stanza / Dispositivo"
		if inspector_desc_label:
			inspector_desc_label.text = "Seleziona una stanza per visualizzare i dettagli energetici."
		if inspector_inputs_label:
			inspector_inputs_label.text = "Input: --"
			inspector_inputs_label.modulate = Color(0.65, 0.65, 0.65, 1.0)
		if inspector_regime_label:
			inspector_regime_label.text = "Regime: --"
			inspector_regime_label.modulate = Color(0.65, 0.65, 0.65, 1.0)
		if inspector_regime_bar:
			inspector_regime_bar.value = 0
			inspector_regime_bar.modulate = Color(0.65, 0.65, 0.65, 1.0)
		return
	
	var r_name: String = str(room.get("name", "Stanza"))
	var r_cat: String = str(room.get("category", "")).to_upper()
	var is_on: bool = bool(room.get("is_on", false))
	var devices: Array = room.get("devices", [])
	
	var room_p: float = 0.0
	for dev in devices:
		room_p += float(dev.get("power_mw", 0.0))
	if room_p == 0.0 and room.has("power_mw"):
		room_p = float(room.get("power_mw", 0.0))
	
	if inspector_title_label:
		inspector_title_label.text = "%s [%s]" % [r_name, r_cat]
	
	if inspector_desc_label:
		var status_str := "ALIMENTATA (ON)" if is_on else "OFFLINE (OFF)"
		inspector_desc_label.text = "Stato: %s | Dispositivi installati: %d" % [status_str, devices.size()]
	
	if inspector_inputs_label:
		if room_p > 0.0:
			inspector_inputs_label.text = "Produzione: +%.1f MW" % room_p
			inspector_inputs_label.modulate = Color(0.2, 1.0, 0.4, 1.0) # #33ff66
		elif room_p < 0.0:
			inspector_inputs_label.text = "Consumo: %.1f MW" % room_p
			inspector_inputs_label.modulate = Color(1.0, 0.25, 0.25, 1.0) # #ff4040
		else:
			inspector_inputs_label.text = "Carico: 0.0 MW"
			inspector_inputs_label.modulate = Color(0.65, 0.65, 0.65, 1.0)
	
	if inspector_regime_label:
		if room_p > 0.0:
			inspector_regime_label.text = "GENERAZIONE ATTIVA"
			inspector_regime_label.modulate = Color(0.2, 1.0, 0.4, 1.0)
		elif room_p < 0.0:
			inspector_regime_label.text = "CARICO ATTIVO"
			inspector_regime_label.modulate = Color(1.0, 0.25, 0.25, 1.0)
		else:
			inspector_regime_label.text = "STANDBY"
			inspector_regime_label.modulate = Color(0.65, 0.65, 0.65, 1.0)
	
	if inspector_regime_bar:
		inspector_regime_bar.value = abs(room_p)
		if room_p > 0.0:
			inspector_regime_bar.modulate = Color(0.2, 1.0, 0.4, 1.0)
		elif room_p < 0.0:
			inspector_regime_bar.modulate = Color(1.0, 0.25, 0.25, 1.0)
		else:
			inspector_regime_bar.modulate = Color(0.65, 0.65, 0.65, 1.0)

func _update_system_effects(active_categories: Dictionary) -> void:
	var categories := [
		"defence", "mainframe", "comms", "tactical", "propulsion", 
		"service", "sensors", "life_support", "command", "engineering", "cargo"
	]
	
	# Basic logic: if net power is negative, we start losing systems from lowest priority.
	# For now, let's just say if net < 0, all systems are at risk, or we just follow room status.
	
	var is_deficit := net_power_mw < 0
	
	for cat in categories:
		var should_be_on := active_categories.has(cat) and not is_deficit
		
		# If it's a critical system, maybe it stays on longer?
		if is_deficit:
			if cat in ["life_support", "command"] and net_power_mw > -200:
				should_be_on = active_categories.has(cat)
		
		if not system_states.has(cat) or system_states[cat] != should_be_on:
			system_states[cat] = should_be_on
			system_power_changed.emit(cat, should_be_on)
			_notify_system_managers(cat, should_be_on)

func _notify_system_managers(category: String, is_powered: bool) -> void:
	# Notifica tramite il bus centrale (SpaceWorldManager)
	if SpaceWorldManager:
		SpaceWorldManager.ship_system_power_changed.emit(category, is_powered)
	
	_print_terminal("[color=#88bbdd]Sistema %s: %s[/color]" % [category.to_upper(), "ALIMENTATO" if is_powered else "OFFLINE"])

func autobalance_grid() -> void:
	if not can_control: return
	_print_terminal("[color=#ffaa00]Bilanciamento automatico: spegnimento stanze non essenziali...[/color]")
	
	# Simple heuristic: shut down until net_power >= 0
	var priority_order := ["cargo", "service", "mainframe", "engineering", "comms", "sensors", "tactical", "defence", "propulsion", "command", "life_support"]
	
	for cat_to_cut in priority_order:
		if net_power_mw >= 0: break
		
		for room in rooms_data:
			if not bool(room.get("is_on", false)): continue
			
			# If room only contains devices of this category (or lower), shut it down
			var only_low_priority := true
			var devices: Array = room.get("devices", [])
			for dev in devices:
				var dev_cat: Variant = dev.get("category", "unknown")
				if priority_order.find(dev_cat) > priority_order.find(cat_to_cut):
					only_low_priority = false
					break
			
			if only_low_priority and not devices.is_empty():
				room["is_on"] = false
				var rid: String = str(room.get("id", ""))
				if room_widgets.has(rid):
					room_widgets[rid].power_switch.button_pressed = false
				_refresh_power_logic()
				if net_power_mw >= 0: break

func _get_blueprint() -> ShipBlueprint:
	if SpaceWorldManager and SpaceWorldManager.has_method("get_ship_blueprint"):
		return SpaceWorldManager.get_ship_blueprint()
	return null

func _on_reload_config_pressed() -> void:
	load_dat_configuration()
	_init_room_list()
	_refresh_power_logic()

func _connect_system_signals() -> void:
	if SpaceWorldManager:
		if not SpaceWorldManager.ship_connection_changed.is_connected(_on_ship_connection_changed):
			SpaceWorldManager.ship_connection_changed.connect(_on_ship_connection_changed)
		if SpaceWorldManager.has_signal("ship_damages_updated") and not SpaceWorldManager.ship_damages_updated.is_connected(_on_ship_damages_updated):
			SpaceWorldManager.ship_damages_updated.connect(_on_ship_damages_updated)
	
	if NetworkManager:
		if NetworkManager.has_signal("player_role_changed") and not NetworkManager.player_role_changed.is_connected(_on_player_role_changed):
			NetworkManager.player_role_changed.connect(_on_player_role_changed)
		if NetworkManager.has_signal("mission_started") and not NetworkManager.mission_started.is_connected(_on_mission_started):
			NetworkManager.mission_started.connect(_on_mission_started)
		if NetworkManager.has_signal("mission_ended") and not NetworkManager.mission_ended.is_connected(_on_mission_ended):
			NetworkManager.mission_ended.connect(_on_mission_ended)
	
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm:
		if sdm.has_signal("file_synced") and not sdm.file_synced.is_connected(_on_drive_file_modified):
			sdm.file_synced.connect(_on_drive_file_modified)
		if sdm.has_signal("file_modified") and not sdm.file_modified.is_connected(_on_drive_file_modified):
			sdm.file_modified.connect(_on_drive_file_modified)

func _exit_tree() -> void:
	if SpaceWorldManager:
		if SpaceWorldManager.ship_connection_changed.is_connected(_on_ship_connection_changed):
			SpaceWorldManager.ship_connection_changed.disconnect(_on_ship_connection_changed)
		if SpaceWorldManager.has_signal("ship_damages_updated") and SpaceWorldManager.ship_damages_updated.is_connected(_on_ship_damages_updated):
			SpaceWorldManager.ship_damages_updated.disconnect(_on_ship_damages_updated)
	
	if NetworkManager:
		if NetworkManager.has_signal("player_role_changed") and NetworkManager.player_role_changed.is_connected(_on_player_role_changed):
			NetworkManager.player_role_changed.disconnect(_on_player_role_changed)
		if NetworkManager.has_signal("mission_started") and NetworkManager.mission_started.is_connected(_on_mission_started):
			NetworkManager.mission_started.disconnect(_on_mission_started)
		if NetworkManager.has_signal("mission_ended") and NetworkManager.mission_ended.is_connected(_on_mission_ended):
			NetworkManager.mission_ended.disconnect(_on_mission_ended)
	
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm:
		if sdm.has_signal("file_synced") and sdm.file_synced.is_connected(_on_drive_file_modified):
			sdm.file_synced.disconnect(_on_drive_file_modified)
		if sdm.has_signal("file_modified") and sdm.file_modified.is_connected(_on_drive_file_modified):
			sdm.file_modified.disconnect(_on_drive_file_modified)

# --- GESTIONE MINI-TERMINALE ---
func _print_terminal_welcome() -> void:
	_print_terminal("[color=#00e5ff]=== DARK NOVA POWER GRID OS v2.0.0 ===[/color]")
	_print_terminal("[color=#88bbdd]Gestione energetica a compartimenti stagne.[/color]")
	_print_terminal("[color=#88bbdd]Digita [color=#ffffaa]help[/color] per la guida comandi.[/color]\n")

func _print_terminal(text: String) -> void:
	if terminal_output:
		terminal_output.append_text(text + "\n")

func _on_terminal_text_submitted(cmd: String) -> void:
	cmd = cmd.strip_edges()
	if cmd.is_empty():
		return
	
	terminal_history.append(cmd)
	terminal_history_index = terminal_history.size()
	if terminal_input:
		terminal_input.clear()
	
	execute_terminal_command(cmd)

func execute_terminal_command(raw_cmd: String) -> void:
	_print_terminal("[color=#ffffff]> %s[/color]" % raw_cmd)
	var parts := raw_cmd.split(" ", false)
	if parts.is_empty():
		return
	
	var verb: String = parts[0].to_lower()
	
	match verb:
		"help", "?":
			_print_terminal("[color=#ffffaa]--- COMANDI DISPONIBILI ---[/color]")
			_print_terminal("[color=#00e5ff]status / stat[/color]        : Report bilancio energetico")
			_print_terminal("[color=#00e5ff]rooms / list[/color]        : Stato delle stanze e dispositivi")
			_print_terminal("[color=#00e5ff]set <room> <on|off>[/color] : Accendi o spegni una stanza")
			_print_terminal("[color=#00e5ff]autobalance[/color]          : Bilanciamento automatico del carico")
			_print_terminal("[color=#00e5ff]clear / cls[/color]          : Pulisce il terminale")
		
		"status", "stat":
			_print_terminal("[color=#ffffaa]=== BILANCIO ENERGETICO ===[/color]")
			_print_terminal("Produzione: [color=#33ff66]%.0f MW[/color]" % total_gen_mw)
			_print_terminal("Consumo: [color=#ff4040]%.0f MW[/color]" % total_cons_mw)
			var col := "#33ff66" if net_power_mw >= 0 else "#ff4040"
			_print_terminal("Netto: [color=%s]%.0f MW[/color]" % [col, net_power_mw])
		
		"rooms", "list":
			_print_terminal("[color=#ffffaa]=== STATO STANZE ===[/color]")
			for r in rooms_data:
				var is_on: bool = bool(r.get("is_on", false))
				var st := "ON" if is_on else "OFF"
				var st_col := "#33ff66" if is_on else "#ff4040"
				var p_mw: float = 0.0
				for dev in r.get("devices", []):
					p_mw += float(dev.get("power_mw", 0.0))
				if p_mw == 0.0 and r.has("power_mw"):
					p_mw = float(r.get("power_mw", 0.0))
				var p_col := "#33ff66" if p_mw > 0.0 else ("#ff4040" if p_mw < 0.0 else "#a6a6a6")
				_print_terminal(" • %s: [color=%s]%s[/color] ([color=%s]%.0f MW[/color])" % [str(r.get("name", "Ignota")), st_col, st, p_col, p_mw])
		
		"set":
			if parts.size() < 3:
				_print_terminal("[color=#ff5555]Uso: set <room_id> <on|off>[/color]")
				return
			var rid: String = parts[1]
			var val: Variant = parts[2].to_lower() == "on"
			_on_room_power_toggled(rid, val)
			if room_widgets.has(rid):
				room_widgets[rid].power_switch.button_pressed = val
		
		"autobalance":
			autobalance_grid()
		
		"clear", "cls":
			if terminal_output:
				terminal_output.clear()
		
		_:
			_print_terminal("[color=#ff5555]Comando non riconosciuto: '%s'.[/color]" % verb)

func _run_diagnostics() -> void:
	_print_terminal("[color=#ffffaa]=== DIAGNOSTICA ENERGETICA ===[/color]")
	if net_power_mw < 0:
		_print_terminal("[color=#ff4040]⚠ DEFICIT ENERGETICO RILEVATO: %.0f MW[/color]" % abs(net_power_mw))
		_print_terminal("Disattivare stanze non critiche per ripristinare i sistemi.")
	else:
		_print_terminal("[color=#33ff66]✔ Rete stabile. Margine operativo: %.0f MW[/color]" % net_power_mw)

# --- GESTIONE CLICK E INTERAZIONE ---
# Rimosso perché la mappa 2D non è più presente.

# --- PARSING E GESTIONE .DAT CONFIGURATION ---
func _on_drive_file_modified(rel_path: String) -> void:
	if "Programs/PowerGrid" in rel_path and rel_path.ends_with(".dat"):
		load_dat_configuration()

func load_dat_configuration() -> Dictionary:
	_ensure_default_dat_files()
	
	var cfg := _parse_dat_file(CONFIG_PATH_PRIMARY)
	if cfg.is_empty():
		cfg = _parse_dat_file(CONFIG_PATH_FALLBACK)
	
	var tuning := _parse_dat_file(TUNING_PATH_PRIMARY)
	if tuning.is_empty():
		tuning = _parse_dat_file(TUNING_PATH_FALLBACK)
	
	for k in cfg:
		active_config[k] = cfg[k]
	for k in tuning:
		active_config[k] = tuning[k]
	
	if not cfg.is_empty() or not tuning.is_empty():
		active_config["is_dat_loaded"] = true
	
	_apply_configuration()
	return active_config

func _ensure_default_dat_files() -> void:
	var abs_dir := "user://files/Ship Drive/Programs/PowerGrid"
	if not DirAccess.dir_exists_absolute(abs_dir):
		DirAccess.make_dir_recursive_absolute(abs_dir)
	
	var cfg_abs := "%s/power_grid_config.dat" % abs_dir
	if not FileAccess.file_exists(cfg_abs):
		var f := FileAccess.open(cfg_abs, FileAccess.WRITE)
		if f:
			f.store_string("# DARK NOVA POWER GRID RUNTIME CONFIGURATION\n[SYSTEM]\napp_name=PowerGrid\nversion=2.0.0\nstatus=OPERATIONAL\nmode=ROOM_BASED\n\n[GRID_SETTINGS]\nreactor_output_mw=1200.0\naux_generator_mw=450.0\n")
			f.close()

func is_operational() -> bool:
	if SpaceWorldManager and SpaceWorldManager.has_method("is_ship_connected"):
		return SpaceWorldManager.is_ship_connected()
	return false

func _apply_configuration() -> void:
	if dat_status_badge:
		if active_config.get("is_dat_loaded"):
			dat_status_badge.text = "DAT: ATTIVO"
			dat_status_badge.modulate = Color(0.2, 1.0, 0.4, 1.0)
		else:
			dat_status_badge.text = "DAT: DEFAULT"
			dat_status_badge.modulate = Color(0.7, 0.8, 0.9)
	
	_refresh_power_logic()

func _on_ship_connection_changed(is_connected: bool) -> void:
	_update_connection_state()

func _on_ship_damages_updated(_damages: Array) -> void:
	_refresh_power_logic()

func _on_mission_started(_role: String = "", _is_solo: bool = false) -> void:
	_update_connection_state()

func _on_mission_ended() -> void:
	_update_connection_state()

func _update_connection_state() -> void:
	var connected: bool = is_operational()
	if disconnected_overlay:
		disconnected_overlay.visible = not connected
	
	if status_badge:
		status_badge.text = "ONLINE" if connected else "OFFLINE"
		status_badge.modulate = Color(0.2, 1.0, 0.4, 1.0) if connected else Color(1.0, 0.25, 0.25, 1.0)
	
	set_process(connected)

func _on_player_role_changed(_peer_id: int, _new_role: String) -> void:
	_update_permissions()

func _update_permissions() -> void:
	var my_role := ""
	var is_solo := true
	if NetworkManager:
		if NetworkManager.has_method("get_local_player_role"):
			my_role = NetworkManager.get_local_player_role()
		if "is_solo_mode" in NetworkManager:
			is_solo = NetworkManager.is_solo_mode
	
	var role_lower := my_role.to_lower()
	if not my_role.is_empty():
		can_control = role_lower in ["ingegnere", "engineer", "capitano", "captain", "stagista", "admin", "host"]
	else:
		can_control = is_solo
	
	if role_badge:
		var role_txt := my_role if my_role != "" else ("SOLO" if is_solo else "SPETTATORE")
		role_badge.text = "RUOLO: %s" % role_txt
		role_badge.modulate = Color(0.2, 1.0, 0.5) if can_control else Color(1.0, 0.8, 0.2)
	
	for widget in room_widgets.values():
		if widget and widget.has_method("set_enabled"):
			widget.set_enabled(can_control)

func _get_net_mgr() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/NetworkManager")
	return null
