class_name SensorsApp
extends BaseApp

## Applicazione della Nave: Long-Range Sensor Array & Tactical Map (Applications/Sensors)
## Fornisce radar a raggio diegetico (1 km standard, 2 km ping attivo), sweep passivo,
## occlusione Line of Sight (LoS) da ostacoli, integrazione feed radar Probe e trasmissione waypoint.

const APP_TITLE: String = "ARRAY SENSORI & RADAR"
const DEFAULT_WINDOW_SIZE: Vector2 = Vector2(750, 580)
const MIN_WINDOW_SIZE: Vector2 = Vector2(750, 580)
const RADAR_STANDARD_RANGE: float = 1000.0 # 1 km
const MAX_STANDARD_RANGE: float = 1000.0
const ACTIVE_PING_RANGE: float = 2000.0 # 2 km
const PING_MAX_RANGE: float = 2000.0
const BASE_POWER_MW: float = 40.0
const ACTIVE_PING_POWER_MW: float = 120.0

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
@onready var range_indicator_label: Label = get_node_or_null("%RangeIndicatorLabel")
@onready var btn_zoom_in: Button = get_node_or_null("%BtnZoomIn")
@onready var btn_zoom_out: Button = get_node_or_null("%BtnZoomOut")
@onready var btn_sweep_toggle: Button = get_node_or_null("%BtnSweepToggle")
@onready var btn_active_ping: Button = get_node_or_null("%BtnActivePing")

@onready var target_details_label: RichTextLabel = get_node_or_null("%TargetDetailsLabel")
@onready var probe_status_label: RichTextLabel = get_node_or_null("%ProbeStatusLabel")
@onready var btn_lock_target: Button = get_node_or_null("%BtnLockTarget")
@onready var btn_transmit_waypoint: Button = get_node_or_null("%BtnTransmitWaypoint")
@onready var btn_clear_waypoint: Button = get_node_or_null("%BtnClearWaypoint")

@onready var status_label: Label = get_node_or_null("%StatusLabel")
@onready var power_label: Label = get_node_or_null("%PowerLabel")
@onready var sweep_label: Label = get_node_or_null("%SweepLabel")
@onready var ping_label: Label = get_node_or_null("%PingLabel")
@onready var radar_damage_badge: Label = get_node_or_null("%RadarDamageBadge")

# Nodi opzionali per retrocompatibilità
@onready var target_option: OptionButton = get_node_or_null("%TargetOption")
@onready var spectrometry_label: RichTextLabel = get_node_or_null("%SpectrometryLabel")
@onready var option_range: OptionButton = get_node_or_null("%OptionRange")
@onready var option_filter: OptionButton = get_node_or_null("%OptionFilter")

# --- CONFIGURAZIONE RUNTIME (.DAT) ---
var active_config: Dictionary = {
	"app_name": "SensorsApp",
	"version": "1.0.0",
	"status": "OPERATIONAL",
	"sweep_frequency_hz": 12.0,
	"active_ping_radius": 2000.0,
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
	_configure_window(APP_TITLE, DEFAULT_WINDOW_SIZE, MIN_WINDOW_SIZE)
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

func _init_ui_elements() -> void:
	if option_display_mode:
		option_display_mode.clear()
		option_display_mode.add_item("Vista Orbitale 3D", 0)
		option_display_mode.add_item("Vista Zenitale (Top-Down)", 1)
		option_display_mode.add_item("Vista Frontale (Elevazione)", 2)
		option_display_mode.selected = 0
	
	if option_range:
		option_range.clear()
		option_range.add_item("Raggio: 200m (Zoom 5x)", 0)
		option_range.add_item("Raggio: 500m (Zoom 2x)", 1)
		option_range.add_item("Raggio: 1000m (1 km)", 2)
		option_range.add_item("Raggio: 2000m (2 km)", 3)
		option_range.selected = 2
	
	if radar_display:
		radar_display.max_range = RADAR_STANDARD_RANGE
		radar_display.ping_max_radius = ACTIVE_PING_RANGE
	
	_update_range_indicator()

func _update_range_indicator() -> void:
	if not range_indicator_label:
		return
	var cur_r: float = radar_display.max_range if radar_display else RADAR_STANDARD_RANGE
	var zoom_txt := ""
	if cur_r < 1000.0:
		zoom_txt = " (ZOOM %.0fx)" % (1000.0 / cur_r)
	elif cur_r > 1000.0:
		zoom_txt = " (PANORAMICO)"
	range_indicator_label.text = "📡 SCANNER: %.0fm%s | PING: 2000m" % [cur_r, zoom_txt]

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
		if not radar_display.range_changed.is_connected(_on_radar_range_changed):
			radar_display.range_changed.connect(_on_radar_range_changed)
	
	if option_display_mode and not option_display_mode.item_selected.is_connected(_on_display_mode_selected):
		option_display_mode.item_selected.connect(_on_display_mode_selected)
	if option_range and not option_range.item_selected.is_connected(_on_range_selected):
		option_range.item_selected.connect(_on_range_selected)
	if btn_zoom_in and not btn_zoom_in.pressed.is_connected(_on_zoom_in_pressed):
		btn_zoom_in.pressed.connect(_on_zoom_in_pressed)
	if btn_zoom_out and not btn_zoom_out.pressed.is_connected(_on_zoom_out_pressed):
		btn_zoom_out.pressed.connect(_on_zoom_out_pressed)
	
	if btn_sweep_toggle and not btn_sweep_toggle.pressed.is_connected(_on_sweep_toggle_pressed):
		btn_sweep_toggle.pressed.connect(_on_sweep_toggle_pressed)
	if btn_active_ping and not btn_active_ping.pressed.is_connected(_on_active_ping_pressed):
		btn_active_ping.pressed.connect(_on_active_ping_pressed)
	
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

func _on_mission_started(_role: String = "", _is_solo: bool = false) -> void:
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
	# - Soldato, Hacker, Captain, Stagista, Solo Mode: Controllo Completo
	# - Pilota, Ingegnere: Sola Visualizzazione
	var role_lower := my_role.to_lower()
	if not my_role.is_empty():
		can_control_sensors = role_lower in ["soldier", "soldato", "hacker", "captain", "capitano", "stagista", "sensori / radar", "admin", "host"]
	else:
		can_control_sensors = is_solo
	
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

func _on_drive_file_event(path: String, _content: String = "") -> void:
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
			ping_label.text = "PING: IMPULSO ATTIVO (2 km)..."
			ping_label.modulate = Color(0.2, 0.9, 1.0)
		elif ping_cooldown > 0.0:
			ping_label.text = "PING: RICARICA (%.1fs)" % ping_cooldown
			ping_label.modulate = Color(1.0, 0.8, 0.2)
		else:
			ping_label.text = "PING: PRONTO (2 km)"
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
	current_power_mw = ACTIVE_PING_POWER_MW if is_pinging else (BASE_POWER_MW if is_passive_sweep_active else 10.0)
	
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

# --- LINE OF SIGHT (LoS) & PROBE INTEGRATION ---

func _refresh_entities() -> void:
	var raw_entities: Array[Dictionary] = []
	if SpaceWorldManager and SpaceWorldManager.has_method("get_sensor_entities"):
		raw_entities = SpaceWorldManager.get_sensor_entities()
	
	# Recupera stato eventuale sonda attiva (Probe)
	var active_probe: Dictionary = {}
	if SpaceWorldManager and SpaceWorldManager.has_method("get_active_probe"):
		active_probe = SpaceWorldManager.get_active_probe()
	
	if radar_display:
		radar_display.probe_data = active_probe
	
	# Filtra ostacoli fisici solidi (Asteroidi, Relitti, Stazioni)
	var obstacles: Array[Dictionary] = []
	for e in raw_entities:
		var t: String = str(e.get("type", ""))
		var r_m: float = float(e.get("radius_m", 0.0))
		if r_m > 0.0 or t in ["ASTEROID", "MINERAL_ASTEROID", "STATION", "WRECK"]:
			obstacles.append(e)
	
	# Calcola occlusione Line of Sight e copertura Probe
	detected_entities.clear()
	for e in raw_entities:
		var e_copy := e.duplicate(true)
		var rel_pos: Vector3 = e_copy.get("local_rel_pos", e_copy.get("rel_pos", e_copy.get("pos", Vector3.ZERO)))
		var e_dist: float = rel_pos.length()
		var e_type: String = str(e_copy.get("type", ""))
		var e_id: String = str(e_copy.get("id", ""))
		var e_rad: float = float(e_copy.get("radius_m", 0.0))
		
		var is_occluded_from_ship := false
		
		# I waypoint e la propria sonda non sono mai occlusi
		if e_type != "WAYPOINT" and e_type != "PROBE" and e_dist > 5.0:
			var ray_dir := rel_pos / e_dist
			for obs in obstacles:
				if str(obs.get("id", "")) == e_id:
					continue
				
				var obs_rel: Vector3 = obs.get("local_rel_pos", obs.get("rel_pos", obs.get("pos", Vector3.ZERO)))
				var obs_rad: float = float(obs.get("radius_m", 4.0))
				if obs_rad <= 0.0:
					obs_rad = 4.0
				
				# Proiezione del vettore ostacolo sul raggio nave->contatto
				var t_proj := obs_rel.dot(ray_dir)
				# L'ostacolo deve trovarsi tra la nave e il contatto
				if t_proj > (obs_rad * 0.5) and t_proj < (e_dist - 2.0):
					var perp_dist_sq := obs_rel.length_squared() - (t_proj * t_proj)
					if perp_dist_sq >= 0.0 and perp_dist_sq < (obs_rad * obs_rad):
						is_occluded_from_ship = true
						break
		
		# Verifica se il contatto si trova nel raggio di scansione della sonda telemetrica
		var is_revealed_by_probe := false
		if not active_probe.is_empty():
			var p_pos: Vector3 = active_probe.get("pos", Vector3.ZERO)
			var e_world_pos: Vector3 = e_copy.get("pos", rel_pos)
			var dist_to_probe := (e_world_pos - p_pos).length()
			var probe_scan_r: float = float(active_probe.get("scan_radius", 1000.0))
			if dist_to_probe <= probe_scan_r:
				is_revealed_by_probe = true
		
		# Se è nel raggio della sonda, il contatto viene rivelato anche se in ombra
		var is_occluded := is_occluded_from_ship and not is_revealed_by_probe
		e_copy["is_occluded"] = is_occluded
		e_copy["is_revealed_by_probe"] = is_revealed_by_probe
		
		detected_entities.append(e_copy)
	
	if radar_display:
		radar_display.entities = detected_entities
		radar_display.selected_entity_id = selected_entity_id
		radar_display.locked_entity_id = locked_entity_id

	if target_option:
		var prev_sel := target_option.selected
		target_option.clear()
		target_option.add_item("-- NESSUN CONTATTO --", 0)
		var sel_idx := 0
		for i in range(detected_entities.size()):
			var ent := detected_entities[i]
			target_option.add_item("ECO #%s (%s)" % [ent.get("id"), ent.get("name")], i + 1)
			if str(ent.get("id")) == selected_entity_id:
				sel_idx = i + 1
		if sel_idx > 0:
			target_option.selected = sel_idx
		elif prev_sel >= 0 and prev_sel < target_option.item_count:
			target_option.selected = prev_sel

func _update_telemetry_ui() -> void:
	var cur_entity := _get_entity_data(selected_entity_id)
	
	if target_details_label:
		if cur_entity.is_empty():
			target_details_label.text = "[color=#7799aa]Nessun contatto selezionato sul display radar.[/color]\n[color=#557788]Fai clic su un eco radar per analizzare la telemetria.[/color]"
		else:
			var e_id: String = str(cur_entity.get("id", ""))
			var dist_m: float = float(cur_entity.get("distance", 0.0))
			var bearing: float = float(cur_entity.get("bearing_deg", 0.0))
			var elev: float = float(cur_entity.get("elevation_deg", 0.0))
			var vel: Vector3 = cur_entity.get("velocity", Vector3.ZERO)
			var mass: float = float(cur_entity.get("mass_tons", 0.0))
			var sig: float = float(cur_entity.get("signal_signature", 0.0))
			var e_type: String = str(cur_entity.get("type", "UNKNOWN"))
			var is_rev_probe: bool = bool(cur_entity.get("is_revealed_by_probe", false))
			
			var lock_txt := " [color=#ff3333]● LOCKED[/color]" if (e_id == locked_entity_id and is_target_locked) else ""
			var probe_txt := "\n[color=#33ccff]● Rivelato da Feed Sonda Telemetrica[/color]" if is_rev_probe else ""
			
			var dist_str := "%.0f m" % dist_m if dist_m < 1000.0 else "%.2f km" % (dist_m / 1000.0)
			
			var title_str := "ECO #%s" % e_id
			if e_type == "WAYPOINT": title_str = "WAYPOINT TATTICO"
			elif e_type == "PROBE": title_str = "SONDA TELEMETRICA"
			
			var comp: Dictionary = cur_entity.get("composition", {})
			var comp_str := ""
			if not comp.is_empty():
				var comp_lines: Array[String] = []
				for elem in comp.keys():
					comp_lines.append("%s: %.0f%%" % [elem, float(comp[elem])])
				comp_str = "\n[b]Spettrometria:[/b] " + ", ".join(comp_lines)
			
			var integ_val: float = float(cur_entity.get("integrity", 100.0))
			var rad_val: float = float(cur_entity.get("radiation_level", 0.0))
			var deep_scan_str := "\n[b]Integrità:[/b] %.0f%% | [b]Radiazione:[/b] %.2f Sv/h" % [integ_val, rad_val]
			
			target_details_label.text = (
				"[b]Identificativo Eco:[/b] %s%s\n" % [title_str, lock_txt] +
				"[b]Distanza Scanner:[/b] %s | [b]Azimut:[/b] %.1f° | [b]Elevazione:[/b] %.1f°\n" % [dist_str, bearing, elev] +
				"[b]Velocità Relativa:[/b] %.1f m/s\n" % vel.length() +
				"[b]Massa Stimata:[/b] %.0f tonnellate | [b]Segnatura EM:[/b] %.0f%%%s%s%s" % [mass, sig * 100.0, probe_txt, comp_str, deep_scan_str]
			)
	
	if spectrometry_label:
		if cur_entity.is_empty():
			spectrometry_label.text = "[color=#7799aa]Nessun dato spettrale.[/color]"
		else:
			var sp_comp: Dictionary = cur_entity.get("composition", {})
			if sp_comp.is_empty():
				spectrometry_label.text = "[color=#7799aa]Nessuna firma spettrale rilevata.[/color]"
			else:
				var sp_lines: Array[String] = []
				for elem in sp_comp.keys():
					sp_lines.append("[b]%s:[/b] %.1f%%" % [elem, float(sp_comp[elem])])
				spectrometry_label.text = "\n".join(sp_lines)
	
	if probe_status_label:
		var active_probe: Dictionary = {}
		if SpaceWorldManager and SpaceWorldManager.has_method("get_active_probe"):
			active_probe = SpaceWorldManager.get_active_probe()
		
		if active_probe.is_empty():
			probe_status_label.text = "[b]Feed Sonda Telemetrica:[/b] [color=#8899aa]OFFLINE[/color]\n[color=#557788]Nessuna sonda attiva nello spazio.\nLancia una sonda da Weapons per estendere la copertura radar.[/color]"
		else:
			var prb_id: String = str(active_probe.get("id", "PROBE"))
			var prb_pos: Vector3 = active_probe.get("pos", Vector3.ZERO)
			var prb_scan_r: float = float(active_probe.get("scan_radius", 1000.0))
			probe_status_label.text = (
				"[b]Feed Sonda Telemetrica:[/b] [color=#33ff88]● ATTIVO & CONNESSO[/color]\n" +
				"[b]Unità Sonda:[/b] %s | [b]Portata Radar Secondario:[/b] %.0f m\n" % [prb_id, prb_scan_r] +
				"[b]Coordinate Rel:[color=#33ccff] (%.0f, %.0f, %.0f)[/color][/b]" % [prb_pos.x, prb_pos.y, prb_pos.z]
			)

func _get_entity_data(e_id: String) -> Dictionary:
	if e_id.is_empty():
		return {}
	for e in detected_entities:
		if str(e.get("id", "")) == e_id:
			return e
	return {}

# --- GESTIONE CONTROLLI RADAR & TATTICA ---

func _on_display_mode_selected(index: int) -> void:
	if radar_display:
		radar_display.current_mode = index as RadarDisplay.DisplayMode

func _on_range_selected(index: int) -> void:
	var r: float = 1000.0
	match index:
		0: r = 200.0
		1: r = 500.0
		2: r = 1000.0
		3: r = 2000.0
	if radar_display:
		radar_display.set_range(r)

func _on_zoom_in_pressed() -> void:
	if radar_display:
		radar_display.zoom_in_range()

func _on_zoom_out_pressed() -> void:
	if radar_display:
		radar_display.zoom_out_range()

func _on_radar_range_changed(new_range: float) -> void:
	_update_range_indicator()
	if option_range:
		if is_equal_approx(new_range, 200.0):
			option_range.selected = 0
		elif is_equal_approx(new_range, 500.0):
			option_range.selected = 1
		elif is_equal_approx(new_range, 1000.0):
			option_range.selected = 2
		elif is_equal_approx(new_range, 2000.0):
			option_range.selected = 3

func _on_sweep_toggle_pressed() -> void:
	if not can_control_sensors:
		return
	is_passive_sweep_active = not is_passive_sweep_active
	if radar_display:
		radar_display.is_sweep_active = is_passive_sweep_active
	if btn_sweep_toggle:
		btn_sweep_toggle.text = "📡 Sweep: ATTIVO" if is_passive_sweep_active else "📡 Sweep: IN PAUSA"

func _on_active_ping_pressed() -> void:
	if not can_control_sensors or ping_cooldown > 0.0:
		return
	
	# Verifica potenza energetica disponibile (PowerGrid / Sublayer 3)
	var has_power := false
	if SpaceWorldManager and SpaceWorldManager.has_method("can_consume_power"):
		has_power = SpaceWorldManager.can_consume_power(ACTIVE_PING_POWER_MW)
	else:
		has_power = is_radar_powered
	
	if not has_power or not is_radar_powered:
		var notif := get_node_or_null("/root/NotificationManager")
		if notif and notif.has_method("spawn_notification"):
			notif.spawn_notification("⚠️ ENERGIA INSUFFICIENTE PER IMPULSO PING (RICHIESTI 120 MW)")
		return
	
	if SpaceWorldManager and SpaceWorldManager.has_method("consume_power"):
		SpaceWorldManager.consume_power(ACTIVE_PING_POWER_MW)
	
	var r: float = float(active_config.get("active_ping_radius", ACTIVE_PING_RANGE))
	is_pinging = true
	ping_timer = 0.0
	ping_cooldown = 4.0
	
	if radar_display:
		radar_display.trigger_ping(r)
	
	if SpaceWorldManager and SpaceWorldManager.has_method("trigger_active_ping"):
		SpaceWorldManager.trigger_active_ping(r)
	
	var notif := get_node_or_null("/root/NotificationManager")
	if notif and notif.has_method("spawn_notification"):
		notif.spawn_notification("📡 Ping Radar Attivo emesso (Raggio: %.0f m)" % r)
	
	_update_permissions()

func _on_radar_entity_selected(entity_data: Dictionary) -> void:
	selected_entity_id = str(entity_data.get("id", ""))
	_update_permissions()
	_update_telemetry_ui()

func _on_radar_waypoint_placed(world_pos: Vector3) -> void:
	if not can_control_sensors:
		return
	
	# world_pos dal radar è in coordinate locali sfera (relative alla nave).
	# Convertiamo in coordinate globali mondo per il manager spaziale.
	var global_pos := world_pos
	if SpaceWorldManager and SpaceWorldManager.has_method("get_spaceship"):
		var ship := SpaceWorldManager.get_spaceship()
		if ship and is_instance_valid(ship) and ship.is_inside_tree():
			global_pos = ship.global_transform * world_pos
	
	var wp_data := {
		"id": "TACTICAL_WP",
		"name": "WAYPOINT TATTICO SENSORI",
		"pos": global_pos,
		"type": "WAYPOINT"
	}
	
	if SpaceWorldManager and SpaceWorldManager.has_method("set_active_waypoint"):
		SpaceWorldManager.set_active_waypoint(wp_data)
	
	var notif := get_node_or_null("/root/NotificationManager")
	if notif and notif.has_method("spawn_notification"):
		notif.spawn_notification("🛰️ Waypoint fissato a coordinate (%.0f, %.0f)" % [global_pos.x, global_pos.z])

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
			notif.spawn_notification("🎯 Bersaglio agganciato: ECO #%s" % e.get("id"))
	
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
		"id": "WP_" + str(e.get("id")),
		"name": "WAYPOINT ECO #" + str(e.get("id")),
		"pos": e.get("pos"),
		"target_id": e.get("id"),
		"distance": e.get("distance"),
		"type": "TRANSMITTED_TARGET"
	}
	
	if SpaceWorldManager and SpaceWorldManager.has_method("set_active_waypoint"):
		SpaceWorldManager.set_active_waypoint(wp_data)
	
	var notif := get_node_or_null("/root/NotificationManager")
	if notif and notif.has_method("spawn_notification"):
		notif.spawn_notification("🛰️ Waypoint bersaglio trasmesso a Flight Control & Weapons: ECO #%s" % e.get("id"))

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
