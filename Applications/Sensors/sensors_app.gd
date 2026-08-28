class_name SensorsApp
extends Control

## Applicazione della Nave: Long-Range Sensor Array & Tactical Map (Applications/Sensors)
## Fornisce radar a lungo raggio fino a 50 km, sweep passivo/attivo, analisi spettrometrica
## e trasmissione coordinate waypoint a Flight Control e Weapons.

const APP_TITLE: String = "ARRAY SENSORI & RADAR"
const DEFAULT_WINDOW_SIZE: Vector2 = Vector2(750, 550)

const CONFIG_PATH_PRIMARY: String = "Ship Drive/Programs/Sensors/sensors_config.dat"
const CONFIG_PATH_FALLBACK: String = "Terminal Drive/Programs/Sensors/sensors_config.dat"
const TUNING_PATH_PRIMARY: String = "Ship Drive/Programs/Sensors/radar_tuning.dat"
const TUNING_PATH_FALLBACK: String = "Terminal Drive/Programs/Sensors/radar_tuning.dat"

# --- RIFERIMENTI UI (Unique Names) ---
@onready var disconnected_overlay: Control = get_node_or_null("%DisconnectedOverlay")
@onready var status_badge: Label = get_node_or_null("%StatusBadge")
@onready var role_badge: Label = get_node_or_null("%RoleBadge")
@onready var dat_status_badge: Label = get_node_or_null("%DatBadge")
@onready var btn_reload_dat: Button = get_node_or_null("%BtnReloadDat")

@onready var radar_display: RadarDisplay = get_node_or_null("%RadarDisplay")
@onready var option_display_mode: OptionButton = get_node_or_null("%OptionDisplayMode")
@onready var option_range: OptionButton = get_node_or_null("%OptionRange")
@onready var option_filter: OptionButton = get_node_or_null("%OptionFilter")
@onready var btn_sweep_toggle: Button = get_node_or_null("%BtnSweepToggle")
@onready var btn_active_ping: Button = get_node_or_null("%BtnActivePing")

@onready var target_option: OptionButton = get_node_or_null("%TargetOption")
@onready var target_details_label: RichTextLabel = get_node_or_null("%TargetDetailsLabel")
@onready var spectrometry_label: RichTextLabel = get_node_or_null("%SpectrometryLabel")
@onready var btn_lock_target: Button = get_node_or_null("%BtnLockTarget")
@onready var btn_transmit_waypoint: Button = get_node_or_null("%BtnTransmitWaypoint")
@onready var btn_clear_waypoint: Button = get_node_or_null("%BtnClearWaypoint")

@onready var status_label: Label = get_node_or_null("%StatusLabel")
@onready var power_label: Label = get_node_or_null("%PowerLabel")
@onready var sweep_label: Label = get_node_or_null("%SweepLabel")
@onready var ping_label: Label = get_node_or_null("%PingLabel")
@onready var radar_damage_badge: Label = get_node_or_null("%RadarDamageBadge")

# --- CONFIGURAZIONE RUNTIME (.DAT) ---
var active_config: Dictionary = {
	"app_name": "SensorsApp",
	"version": "1.0.0",
	"status": "OPERATIONAL",
	"sweep_frequency_hz": 12.0,
	"active_ping_radius": 50000.0,
	"noise_filter": 0.92,
	"spectrum_sensitivity": 1.0,
	"iff_auto_tag": true,
	"stealth_detection_threshold": 0.35,
	"is_dat_loaded": false
}

# --- STATO INTERNO ---
var can_control_sensors: bool = false
var detected_entities: Array[Dictionary] = []
var selected_entity_id: String = ""
var locked_entity_id: String = ""
var is_target_locked: bool = false

var is_passive_sweep_active: bool = true
var ping_timer: float = 0.0
var ping_cooldown: float = 0.0
var is_pinging: bool = false

var current_power_mw: float = 40.0 # 40 MW base sweep, 120 MW ping attivo
var is_radar_powered: bool = true
var has_radar_damage: bool = false

func _ready() -> void:
	_configure_window()
	_init_ui_elements()
	_connect_system_signals()
	_connect_ui_signals()
	load_dat_configuration()
	_update_connection_state()
	_update_permissions()
	_refresh_entities()

func _process(delta: float) -> void:
	if not _is_ship_operational():
		return
	
	_update_ping_timers(delta)
	_update_power_and_damage_state(delta)
	_refresh_entities()
	_update_telemetry_ui()

func _configure_window() -> void:
	custom_minimum_size = DEFAULT_WINDOW_SIZE
	var parent_win = get_parent()
	while parent_win:
		if "window_title" in parent_win:
			parent_win.window_title = APP_TITLE
			break
		parent_win = parent_win.get_parent()

func _init_ui_elements() -> void:
	if option_display_mode:
		option_display_mode.clear()
		option_display_mode.add_item("Vista Polare 2D", 0)
		option_display_mode.add_item("Griglia Cartesiana", 1)
		option_display_mode.add_item("Elevazione Spaziale 3D", 2)
		option_display_mode.selected = 0
	
	if option_range:
		option_range.clear()
		option_range.add_item("Portata: 5 KM", 0)
		option_range.add_item("Portata: 10 KM", 1)
		option_range.add_item("Portata: 25 KM", 2)
		option_range.add_item("Portata: 50 KM", 3)
		option_range.selected = 3 # Default 50 km
	
	if option_filter:
		option_filter.clear()
		option_filter.add_item("Filtro: Tutti i Contatti", 0)
		option_filter.add_item("Filtro: Minerali & Asteroidi", 1)
		option_filter.add_item("Filtro: Relitti Spaziali", 2)
		option_filter.add_item("Filtro: Minacce & Ostili", 3)
		option_filter.add_item("Filtro: Fari & Stazioni", 4)
		option_filter.selected = 0

func _connect_system_signals() -> void:
	if SpaceWorldManager:
		if SpaceWorldManager.has_signal("ship_connection_changed") and not SpaceWorldManager.ship_connection_changed.is_connected(_on_ship_connection_changed):
			SpaceWorldManager.ship_connection_changed.connect(_on_ship_connection_changed)
		if SpaceWorldManager.has_signal("ship_damages_updated") and not SpaceWorldManager.ship_damages_updated.is_connected(_on_ship_damages_updated):
			SpaceWorldManager.ship_damages_updated.connect(_on_ship_damages_updated)
		if SpaceWorldManager.has_signal("waypoint_updated") and not SpaceWorldManager.waypoint_updated.is_connected(_on_waypoint_updated):
			SpaceWorldManager.waypoint_updated.connect(_on_waypoint_updated)
	
	var nm := _get_net_mgr()
	if nm:
		if nm.has_signal("player_role_changed") and not nm.player_role_changed.is_connected(_on_player_role_changed):
			nm.player_role_changed.connect(_on_player_role_changed)
		if nm.has_signal("mission_started") and not nm.mission_started.is_connected(_on_mission_started):
			nm.mission_started.connect(_on_mission_started)
		if nm.has_signal("mission_ended") and not nm.mission_ended.is_connected(_on_mission_ended):
			nm.mission_ended.connect(_on_mission_ended)
	
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm:
		if sdm.has_signal("file_synced") and not sdm.file_synced.is_connected(_on_drive_file_event):
			sdm.file_synced.connect(_on_drive_file_event)
		if sdm.has_signal("file_modified") and not sdm.file_modified.is_connected(_on_drive_file_event):
			sdm.file_modified.connect(_on_drive_file_event)
		if sdm.has_signal("drive_synced") and not sdm.drive_synced.is_connected(_on_drive_synced):
			sdm.drive_synced.connect(_on_drive_synced)

func _connect_ui_signals() -> void:
	if btn_reload_dat and not btn_reload_dat.pressed.is_connected(load_dat_configuration):
		btn_reload_dat.pressed.connect(load_dat_configuration)
	
	if radar_display:
		if not radar_display.entity_selected.is_connected(_on_radar_entity_selected):
			radar_display.entity_selected.connect(_on_radar_entity_selected)
		if not radar_display.waypoint_placed.is_connected(_on_radar_waypoint_placed):
			radar_display.waypoint_placed.connect(_on_radar_waypoint_placed)
	
	if option_display_mode and not option_display_mode.item_selected.is_connected(_on_display_mode_selected):
		option_display_mode.item_selected.connect(_on_display_mode_selected)
	if option_range and not option_range.item_selected.is_connected(_on_range_selected):
		option_range.item_selected.connect(_on_range_selected)
	if option_filter and not option_filter.item_selected.is_connected(_on_filter_selected):
		option_filter.item_selected.connect(_on_filter_selected)
	
	if btn_sweep_toggle and not btn_sweep_toggle.pressed.is_connected(_on_sweep_toggle_pressed):
		btn_sweep_toggle.pressed.connect(_on_sweep_toggle_pressed)
	if btn_active_ping and not btn_active_ping.pressed.is_connected(_on_active_ping_pressed):
		btn_active_ping.pressed.connect(_on_active_ping_pressed)
	
	if target_option and not target_option.item_selected.is_connected(_on_target_dropdown_selected):
		target_option.item_selected.connect(_on_target_dropdown_selected)
	if btn_lock_target and not btn_lock_target.pressed.is_connected(_on_lock_target_pressed):
		btn_lock_target.pressed.connect(_on_lock_target_pressed)
	if btn_transmit_waypoint and not btn_transmit_waypoint.pressed.is_connected(_on_transmit_waypoint_pressed):
		btn_transmit_waypoint.pressed.connect(_on_transmit_waypoint_pressed)
	if btn_clear_waypoint and not btn_clear_waypoint.pressed.is_connected(_on_clear_waypoint_pressed):
		btn_clear_waypoint.pressed.connect(_on_clear_waypoint_pressed)

func _exit_tree() -> void:
	if SpaceWorldManager:
		if SpaceWorldManager.has_signal("ship_connection_changed") and SpaceWorldManager.ship_connection_changed.is_connected(_on_ship_connection_changed):
			SpaceWorldManager.ship_connection_changed.disconnect(_on_ship_connection_changed)
		if SpaceWorldManager.has_signal("ship_damages_updated") and SpaceWorldManager.ship_damages_updated.is_connected(_on_ship_damages_updated):
			SpaceWorldManager.ship_damages_updated.disconnect(_on_ship_damages_updated)
		if SpaceWorldManager.has_signal("waypoint_updated") and SpaceWorldManager.waypoint_updated.is_connected(_on_waypoint_updated):
			SpaceWorldManager.waypoint_updated.disconnect(_on_waypoint_updated)
	
	var nm := _get_net_mgr()
	if nm:
		if nm.has_signal("player_role_changed") and nm.player_role_changed.is_connected(_on_player_role_changed):
			nm.player_role_changed.disconnect(_on_player_role_changed)
		if nm.has_signal("mission_started") and nm.mission_started.is_connected(_on_mission_started):
			nm.mission_started.disconnect(_on_mission_started)
		if nm.has_signal("mission_ended") and nm.mission_ended.is_connected(_on_mission_ended):
			nm.mission_ended.disconnect(_on_mission_ended)
	
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm:
		if sdm.has_signal("file_synced") and sdm.file_synced.is_connected(_on_drive_file_event):
			sdm.file_synced.disconnect(_on_drive_file_event)
		if sdm.has_signal("file_modified") and sdm.file_modified.is_connected(_on_drive_file_event):
			sdm.file_modified.disconnect(_on_drive_file_event)
		if sdm.has_signal("drive_synced") and sdm.drive_synced.is_connected(_on_drive_synced):
			sdm.drive_synced.disconnect(_on_drive_synced)

func _get_net_mgr() -> Node:
	return get_node_or_null("/root/NetworkManager")

func _is_ship_operational() -> bool:
	if SpaceWorldManager and SpaceWorldManager.has_method("is_ship_connected"):
		return SpaceWorldManager.is_ship_connected()
	return false

# --- GESTIONE STATO CONNESSIONE E RBAC ---

func _on_ship_connection_changed(_is_connected: bool) -> void:
	_update_connection_state()
	_update_permissions()

func _on_mission_started() -> void:
	_update_connection_state()
	_update_permissions()

func _on_mission_ended() -> void:
	_update_connection_state()
	_update_permissions()

func _on_player_role_changed(_peer_id: int, _role: String) -> void:
	_update_permissions()

func _update_connection_state() -> void:
	var is_op := _is_ship_operational()
	if disconnected_overlay:
		disconnected_overlay.visible = not is_op
	
	if status_badge:
		if is_op:
			status_badge.text = "STATO: OPERATIVO"
			status_badge.modulate = Color(0.3, 0.9, 0.5)
		else:
			status_badge.text = "STATO: OFFLINE"
			status_badge.modulate = Color(0.9, 0.3, 0.3)

func _update_permissions() -> void:
	var nm := _get_net_mgr()
	var my_role := ""
	var is_solo := true
	
	if nm:
		my_role = nm.get_local_player_role()
		is_solo = nm.is_solo_mode
	
	# Matrice RBAC:
	# - Soldato, Hacker, Captain, Factotum, Solo Mode: Controllo Completo
	# - Pilota, Ingegnere: Sola Visualizzazione
	var role_lower := my_role.to_lower()
	can_control_sensors = (
		is_solo or
		role_lower in ["soldier", "soldato", "hacker", "captain", "capitano", "factotum", "sensori / radar", "admin", "host"] or
		my_role.is_empty()
	)
	
	if role_badge:
		var display_role := my_role if not my_role.is_empty() else ("SOLO MODE" if is_solo else "SPETTATORE")
		role_badge.text = "RUOLO: %s" % display_role
		if can_control_sensors:
			role_badge.modulate = Color(0.3, 0.9, 0.6)
		else:
			role_badge.text += " (SOLA LETTURA)"
			role_badge.modulate = Color(0.85, 0.85, 0.4)
	
	# Applica abilitazione controlli UI
	if btn_sweep_toggle:
		btn_sweep_toggle.disabled = not can_control_sensors
	if btn_active_ping:
		btn_active_ping.disabled = not can_control_sensors or ping_cooldown > 0.0
	if btn_lock_target:
		btn_lock_target.disabled = not can_control_sensors or selected_entity_id.is_empty()
	if btn_transmit_waypoint:
		btn_transmit_waypoint.disabled = not can_control_sensors or selected_entity_id.is_empty()
	if btn_clear_waypoint:
		btn_clear_waypoint.disabled = not can_control_sensors

# --- GESTIONE FILE .DAT E HOT-RELOADING ---

func _on_drive_file_event(path: String) -> void:
	if "Programs/Sensors" in path and path.ends_with(".dat"):
		load_dat_configuration()

func _on_drive_synced() -> void:
	load_dat_configuration()

func load_dat_configuration() -> void:
	var cfg_primary := _parse_dat_file(CONFIG_PATH_PRIMARY)
	var cfg_fallback := _parse_dat_file(CONFIG_PATH_FALLBACK)
	var tuning_primary := _parse_dat_file(TUNING_PATH_PRIMARY)
	var tuning_fallback := _parse_dat_file(TUNING_PATH_FALLBACK)
	
	var loaded_any := false
	if not cfg_primary.is_empty():
		_apply_dict_to_config(cfg_primary)
		loaded_any = true
	elif not cfg_fallback.is_empty():
		_apply_dict_to_config(cfg_fallback)
		loaded_any = true
	
	if not tuning_primary.is_empty():
		_apply_dict_to_config(tuning_primary)
		loaded_any = true
	elif not tuning_fallback.is_empty():
		_apply_dict_to_config(tuning_fallback)
		loaded_any = true
	
	active_config["is_dat_loaded"] = loaded_any
	_apply_configuration()
	
	if dat_status_badge:
		if loaded_any:
			dat_status_badge.text = "DAT: ATTIVO (FIRMWARE V1.0.0)"
			dat_status_badge.modulate = Color(0.3, 1.0, 0.4)
		else:
			dat_status_badge.text = "DAT: STANDARD (FALLBACK)"
			dat_status_badge.modulate = Color(1.0, 0.8, 0.2)

func _apply_dict_to_config(data: Dictionary) -> void:
	for k in data:
		active_config[k] = data[k]

func _apply_configuration() -> void:
	if radar_display:
		radar_display.sweep_frequency_hz = float(active_config.get("sweep_frequency_hz", 12.0))
		radar_display.noise_filter = float(active_config.get("noise_filter", 0.92))
		radar_display.spectrum_sensitivity = float(active_config.get("spectrum_sensitivity", 1.0))
		radar_display.iff_auto_tag = bool(active_config.get("iff_auto_tag", true))
		radar_display.stealth_threshold = float(active_config.get("stealth_detection_threshold", 0.35))
	
	if sweep_label:
		sweep_label.text = "SWEEP: %.1f Hz" % float(active_config.get("sweep_frequency_hz", 12.0))

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
			current_section = line.substr(1, line.length() - 2).strip_edges().to_upper()
			continue
		
		var eq_idx := line.find("=")
		if eq_idx != -1:
			var key := line.substr(0, eq_idx).strip_edges().to_lower()
			var raw_val := line.substr(eq_idx + 1).strip_edges()
			
			var val: Variant = raw_val
			if raw_val.to_lower() == "true":
				val = true
			elif raw_val.to_lower() == "false":
				val = false
			elif raw_val.is_valid_int():
				val = raw_val.to_int()
			elif raw_val.is_valid_float():
				val = raw_val.to_float()
			
			result[key] = val
	
	file.close()
	return result

# --- PROCESSO TELEMETRIA, RETE ELETTRICA E DANNI ---

func _update_ping_timers(delta: float) -> void:
	if ping_cooldown > 0.0:
		ping_cooldown -= delta
		if ping_cooldown <= 0.0:
			ping_cooldown = 0.0
			_update_permissions()
	
	if is_pinging:
		ping_timer += delta
		if ping_timer >= 2.0:
			is_pinging = false
			ping_timer = 0.0
	
	if ping_label:
		if is_pinging:
			ping_label.text = "PING: IMPULSO ATTIVO..."
			ping_label.modulate = Color(0.2, 0.9, 1.0)
		elif ping_cooldown > 0.0:
			ping_label.text = "PING: RICARICA (%.1fs)" % ping_cooldown
			ping_label.modulate = Color(1.0, 0.8, 0.2)
		else:
			ping_label.text = "PING: PRONTO (50 km)"
			ping_label.modulate = Color(0.3, 0.9, 0.5)

func _update_power_and_damage_state(_delta: float) -> void:
	is_radar_powered = true
	has_radar_damage = false
	
	if SpaceWorldManager:
		if SpaceWorldManager.has_method("is_sensors_powered"):
			is_radar_powered = SpaceWorldManager.is_sensors_powered()
		if SpaceWorldManager.has_method("has_radar_damage"):
			has_radar_damage = SpaceWorldManager.has_radar_damage()
	
	if radar_display:
		radar_display.is_powered = is_radar_powered
		radar_display.has_radar_ghosts = has_radar_damage
	
	# Calcolo potenza elettrica (Sublayer 3)
	current_power_mw = active_ping_power_mw if is_pinging else (base_power_mw if is_passive_sweep_active else 10.0)
	
	if power_label:
		if is_radar_powered:
			power_label.text = "PWR: %.0f MW (%s)" % [current_power_mw, "PING ATTIVO" if is_pinging else ("SWEEP" if is_passive_sweep_active else "STANDBY")]
			power_label.modulate = Color(0.3, 0.9, 0.5)
		else:
			power_label.text = "⚠️ PWR: 0 MW (SOTTOALIMENTATO)"
			power_label.modulate = Color(1.0, 0.25, 0.25)
	
	if radar_damage_badge:
		if has_radar_damage:
			radar_damage_badge.text = "⚠️ RADAR: SEGNALI FANTASMA (GHOSTS)"
			radar_damage_badge.modulate = Color(1.0, 0.35, 0.2)
		else:
			radar_damage_badge.text = "RADAR: INTEGRITÀ 100%"
			radar_damage_badge.modulate = Color(0.3, 0.85, 0.9)
	
	if status_label:
		if not is_radar_powered:
			status_label.text = "STATO RADAR: OFFLINE (RETE ELETTRICA)"
		elif has_radar_damage:
			status_label.text = "STATO RADAR: DEGRADATO (DANNI STRUTTURALI)"
		else:
			status_label.text = "STATO RADAR: SCANSIONE OPERATIVA"

func _refresh_entities() -> void:
	if SpaceWorldManager and SpaceWorldManager.has_method("get_sensor_entities"):
		detected_entities = SpaceWorldManager.get_sensor_entities()
	
	if radar_display:
		radar_display.entities = detected_entities
		radar_display.selected_entity_id = selected_entity_id
		radar_display.locked_entity_id = locked_entity_id
	
	_populate_target_dropdown()

func _populate_target_dropdown() -> void:
	if not target_option:
		return
	
	var cur_sel := target_option.selected
	var prev_id := selected_entity_id
	
	target_option.clear()
	target_option.add_item("-- NESSUN CONTATTO SELEZIONATO --", 0)
	
	var idx_to_select := 0
	for i in range(detected_entities.size()):
		var e: Dictionary = detected_entities[i]
		var e_id: String = e.get("id", "")
		var e_name: String = e.get("name", e_id)
		var dist_km: float = float(e.get("distance", 0.0)) / 1000.0
		var iff: String = e.get("iff_tag", "NEUTRAL")
		
		var label_item := "%s [%.1f km] (%s)" % [e_name, dist_km, iff]
		target_option.add_item(label_item, i + 1)
		
		if e_id == prev_id:
			idx_to_select = i + 1
	
	target_option.selected = idx_to_select

func _update_telemetry_ui() -> void:
	var cur_entity := _get_entity_data(selected_entity_id)
	
	if target_details_label:
		if cur_entity.is_empty():
			target_details_label.text = "[color=#7799aa]Nessun bersaglio o contatto selezionato sul radar.[/color]\n[color=#557788]Fai clic sul radar o scegli dal menu a tendina.[/color]"
		else:
			var e_id: String = cur_entity.get("id", "")
			var e_name: String = cur_entity.get("name", e_id)
			var dist_km: float = float(cur_entity.get("distance", 0.0)) / 1000.0
			var bearing: float = float(cur_entity.get("bearing_deg", 0.0))
			var elev: float = float(cur_entity.get("elevation_deg", 0.0))
			var vel: Vector3 = cur_entity.get("velocity", Vector3.ZERO)
			var iff: String = cur_entity.get("iff_tag", "NEUTRAL")
			var e_type: String = cur_entity.get("type", "CONTACT")
			var mass: float = float(cur_entity.get("mass_tons", 0.0))
			var sig: float = float(cur_entity.get("signal_signature", 0.0))
			
			var iff_color := "#55ff55"
			if iff == "HAZARD": iff_color = "#ffaa33"
			elif iff == "HOSTILE": iff_color = "#ff4444"
			elif iff == "FRIENDLY": iff_color = "#33ccff"
			elif iff == "WAYPOINT": iff_color = "#ee44ff"
			
			var lock_txt := " [color=#ff3333]● LOCKED[/color]" if (e_id == locked_entity_id and is_target_locked) else ""
			
			target_details_label.text = (
				"[b]Identificativo:[/b] %s%s\n" % [e_name, lock_txt] +
				"[b]Tipologia:[/b] %s | [b]IFF:[/b] [color=%s]%s[/color]\n" % [e_type, iff_color, iff] +
				"[b]Distanza:[/b] %.2f km | [b]Azimut:[/b] %.1f° | [b]Elevazione:[/b] %.1f°\n" % [dist_km, bearing, elev] +
				"[b]Velocità Relativa:[/b] %.1f m/s (%s)\n" % [vel.length(), str(vel)] +
				"[b]Massa Stimata:[/b] %.0f tonnellate | [b]Segnatura EM:[/b] %.0f%%" % [mass, sig * 100.0]
			)
	
	_update_spectrometry_display(cur_entity)

func _update_spectrometry_display(entity: Dictionary) -> void:
	if not spectrometry_label:
		return
	
	if entity.is_empty():
		spectrometry_label.text = "[color=#557788]In attesa di scansione spettrometrica...[/color]"
		return
	
	var comp: Dictionary = entity.get("composition", {})
	var integ: float = float(entity.get("integrity", 100.0))
	var rad: float = float(entity.get("radiation_level", 0.0))
	var val_cr: int = int(entity.get("estimated_value_cr", 0))
	var e_type: String = entity.get("type", "")
	
	var spec_text := "[b]Analisi Spettrometrica Materiali & Minerali:[/b]\n"
	
	if comp.is_empty():
		if e_type == "WAYPOINT":
			spec_text += "- Nessun corpo solido (Coordinate Vettore Waypoint)\n"
		else:
			spec_text += "- Composizione sconosciuta o non rilevabile a questo raggio\n"
	else:
		for mat_name in comp:
			var pct: float = float(comp[mat_name])
			var col := "#44ddaa" if pct > 30.0 else "#aaddcc"
			spec_text += "- [color=%s]● %s[/color]: %.1f%%\n" % [col, mat_name, pct]
	
	spec_text += "\n[b]Stato Strutturale & Dati Radiologici:[/b]\n"
	spec_text += "- Integrità Scafo/Massa: %.1f%%\n" % integ
	spec_text += "- Radiazioni Rilevate: %.2f Sv/h\n" % rad
	spec_text += "- Valore Commerciale Stimato: [color=#ffdd44]%d Crediti[/color]" % val_cr
	
	spectrometry_label.text = spec_text

func _get_entity_data(e_id: String) -> Dictionary:
	if e_id.is_empty():
		return {}
	for e in detected_entities:
		if e.get("id", "") == e_id:
			return e
	return {}

# --- GESTIONE CONTROLLI RADAR & TATTICA ---

func _on_display_mode_selected(index: int) -> void:
	if radar_display:
		radar_display.current_mode = index as RadarDisplay.DisplayMode

func _on_range_selected(index: int) -> void:
	var r := 50000.0
	match index:
		0: r = 5000.0
		1: r = 10000.0
		2: r = 25000.0
		3: r = 50000.0
	if radar_display:
		radar_display.set_range(r)

func _on_filter_selected(index: int) -> void:
	var f := "ALL"
	match index:
		0: f = "ALL"
		1: f = "MINERALS"
		2: f = "WRECKS"
		3: f = "THREATS"
		4: f = "BEACONS"
	if radar_display:
		radar_display.filter_category = f

func _on_sweep_toggle_pressed() -> void:
	if not can_control_sensors:
		return
	is_passive_sweep_active = not is_passive_sweep_active
	if radar_display:
		radar_display.is_sweep_active = is_passive_sweep_active
	if btn_sweep_toggle:
		btn_sweep_toggle.text = "📡 Sweep: ATTIVO" if is_passive_sweep_active else "📡 Sweep: IN PAUSA"

func _on_active_ping_pressed() -> void:
	if not can_control_sensors or ping_cooldown > 0.0 or not is_radar_powered:
		return
	
	var r := float(active_config.get("active_ping_radius", 50000.0))
	is_pinging = true
	ping_timer = 0.0
	ping_cooldown = 4.0 # 4 secondi di ricarica
	
	if radar_display:
		radar_display.trigger_ping(r)
	
	if SpaceWorldManager and SpaceWorldManager.has_method("trigger_active_ping"):
		SpaceWorldManager.trigger_active_ping(r)
	
	var notif := get_node_or_null("/root/NotificationManager")
	if notif and notif.has_method("spawn_notification"):
		notif.spawn_notification("📡 Ping Radar Attivo emesso (Raggio: %.0f km)" % (r / 1000.0))
	
	_update_permissions()

func _on_radar_entity_selected(entity_data: Dictionary) -> void:
	selected_entity_id = str(entity_data.get("id", ""))
	_update_permissions()
	_update_telemetry_ui()

func _on_radar_waypoint_placed(world_pos: Vector3) -> void:
	if not can_control_sensors:
		return
	
	var wp_data := {
		"id": "TACTICAL_WP",
		"name": "WAYPOINT TATTICO SENSORI",
		"pos": world_pos,
		"type": "WAYPOINT"
	}
	
	if SpaceWorldManager and SpaceWorldManager.has_method("set_active_waypoint"):
		SpaceWorldManager.set_active_waypoint(wp_data)
	
	var notif := get_node_or_null("/root/NotificationManager")
	if notif and notif.has_method("spawn_notification"):
		notif.spawn_notification("🛰️ Waypoint fissato a coordinate (%.0f, %.0f)" % [world_pos.x, world_pos.z])

func _on_target_dropdown_selected(index: int) -> void:
	if index <= 0:
		selected_entity_id = ""
	else:
		var target_idx := index - 1
		if target_idx >= 0 and target_idx < detected_entities.size():
			selected_entity_id = detected_entities[target_idx].get("id", "")
	
	_update_permissions()
	_update_telemetry_ui()

func _on_lock_target_pressed() -> void:
	if not can_control_sensors or selected_entity_id.is_empty():
		return
	
	if is_target_locked and locked_entity_id == selected_entity_id:
		is_target_locked = false
		locked_entity_id = ""
		if btn_lock_target:
			btn_lock_target.text = "🎯 Lock Bersaglio"
	else:
		is_target_locked = true
		locked_entity_id = selected_entity_id
		if btn_lock_target:
			btn_lock_target.text = "🔓 Rilascia Lock"
		
		var notif := get_node_or_null("/root/NotificationManager")
		if notif and notif.has_method("spawn_notification"):
			var e := _get_entity_data(locked_entity_id)
			notif.spawn_notification("🎯 Bersaglio agganciato: %s" % e.get("name", locked_entity_id))
	
	if radar_display:
		radar_display.locked_entity_id = locked_entity_id
	
	_update_telemetry_ui()

func _on_transmit_waypoint_pressed() -> void:
	if not can_control_sensors or selected_entity_id.is_empty():
		return
	
	var e := _get_entity_data(selected_entity_id)
	if e.is_empty():
		return
	
	var wp_data := {
		"id": "WP_" + str(e.get("id", "")),
		"name": "WAYPOINT: " + str(e.get("name", e.get("id", ""))),
		"pos": e.get("pos", Vector3.ZERO),
		"target_id": e.get("id", ""),
		"distance": e.get("distance", 0.0),
		"type": "TRANSMITTED_TARGET"
	}
	
	if SpaceWorldManager and SpaceWorldManager.has_method("set_active_waypoint"):
		SpaceWorldManager.set_active_waypoint(wp_data)
	
	var notif := get_node_or_null("/root/NotificationManager")
	if notif and notif.has_method("spawn_notification"):
		notif.spawn_notification("🛰️ Waypoint bersaglio trasmesso a Flight Control & Weapons: %s" % e.get("name", ""))

func _on_clear_waypoint_pressed() -> void:
	if not can_control_sensors:
		return
	
	if SpaceWorldManager and SpaceWorldManager.has_method("clear_active_waypoint"):
		SpaceWorldManager.clear_active_waypoint()
	
	var notif := get_node_or_null("/root/NotificationManager")
	if notif and notif.has_method("spawn_notification"):
		notif.spawn_notification("❌ Waypoint rimosso dalla mappa tattica.")

func _on_ship_damages_updated(_damages: Array) -> void:
	_update_power_and_damage_state(0.0)

func _on_waypoint_updated(_wp_data: Dictionary) -> void:
	_refresh_entities()
