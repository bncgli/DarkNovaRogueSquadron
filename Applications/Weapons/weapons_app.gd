class_name WeaponsApp
extends BaseApp

## Applicazione GodotOS per i Sistemi d'Arma Tattici, Torretta di Puntamento e Difesa di Prossimità.
## Conforme allo standard architetturale di bordo (APP_ARCHITECTURE_STANDARD.md).
## Task TASK-031: Weapons Turret Overhaul, Mouse Aiming & Ammo Types.

const APP_TITLE: String = "Tactical Weapons & Point Defense"
const DEFAULT_WINDOW_SIZE: Vector2 = Vector2(720, 520)

const CONFIG_PATH_PRIMARY: String = "Ship Drive/Programs/Weapons/weapons_config.dat"
const CONFIG_PATH_FALLBACK: String = "Terminal Drive/Programs/Weapons/weapons_config.dat"
const TUNING_PATH_PRIMARY: String = "Ship Drive/Programs/Weapons/ammo_tuning.dat"
const TUNING_PATH_FALLBACK: String = "Terminal Drive/Programs/Weapons/ammo_tuning.dat"

enum AmmoType {
	HEAVY_MG = 1,
	HEAVY_CANNON = 2,
	MISSILE = 3,
	PROBE = 4
}

# Compatibilita' retroattiva con i vecchi identificatori WeaponGroup
const WeaponGroup = {
	"LASER": AmmoType.HEAVY_CANNON,
	"TORPEDO": AmmoType.MISSILE,
	"PDG": AmmoType.HEAVY_MG,
	"HEAVY_MG": AmmoType.HEAVY_MG,
	"HEAVY_CANNON": AmmoType.HEAVY_CANNON,
	"MISSILE": AmmoType.MISSILE,
	"PROBE": AmmoType.PROBE
}

# --- RIFERIMENTI NODI UI ---
@onready var disconnected_overlay: Control = get_node_or_null("%DisconnectedOverlay")
@onready var status_badge: Label = get_node_or_null("%StatusBadge")
@onready var role_badge: Label = get_node_or_null("%RoleBadge")
@onready var power_badge: Label = get_node_or_null("%PowerBadge")
@onready var dat_status_badge: Label = get_node_or_null("%DatStatusBadge")
@onready var reload_dat_button: Button = get_node_or_null("%ReloadDatButton")

# Selettori Munizioni / Gruppi d'Arma [1-4]
@onready var btn_ammo_mg: Button = get_node_or_null("%BtnAmmoMG") if get_node_or_null("%BtnAmmoMG") else get_node_or_null("%BtnGroupPDG")
@onready var btn_ammo_cannon: Button = get_node_or_null("%BtnAmmoCannon") if get_node_or_null("%BtnAmmoCannon") else get_node_or_null("%BtnGroupLaser")
@onready var btn_ammo_missile: Button = get_node_or_null("%BtnAmmoMissile") if get_node_or_null("%BtnAmmoMissile") else get_node_or_null("%BtnGroupTorpedo")
@onready var btn_ammo_probe: Button = get_node_or_null("%BtnAmmoProbe")
@onready var btn_group_laser: Button = btn_ammo_cannon
@onready var btn_group_torpedo: Button = btn_ammo_missile
@onready var btn_group_pdg: Button = btn_ammo_mg
@onready var selected_group_label: Label = get_node_or_null("%SelectedGroupLabel")

# Indicatori di Stato e Indicatori Termici / Energetici
@onready var capacitor_progress: ProgressBar = get_node_or_null("%CapacitorProgress")
@onready var capacitor_value_label: Label = get_node_or_null("%CapacitorValueLabel")
@onready var heat_progress: ProgressBar = get_node_or_null("%HeatProgress")
@onready var heat_value_label: Label = get_node_or_null("%HeatValueLabel")
@onready var ammo_torpedo_label: Label = get_node_or_null("%AmmoTorpedoLabel")
@onready var ammo_missile_label: Label = get_node_or_null("%AmmoMissileLabel") if get_node_or_null("%AmmoMissileLabel") else get_node_or_null("%AmmoTorpedoLabel")
@onready var ammo_pdg_label: Label = get_node_or_null("%AmmoPDGLabel")
@onready var ammo_mg_label: Label = get_node_or_null("%AmmoMGLabel") if get_node_or_null("%AmmoMGLabel") else get_node_or_null("%AmmoPDGLabel")
@onready var ammo_probe_label: Label = get_node_or_null("%AmmoProbeLabel")
@onready var overheat_warning_label: Label = get_node_or_null("%OverheatWarningLabel")

# Radar Tattico & Puntamento
@onready var radar_canvas: WeaponsRadarCanvas = get_node_or_null("%RadarCanvas")
@onready var target_option_button: OptionButton = get_node_or_null("%TargetOptionButton")
@onready var lock_button: Button = get_node_or_null("%LockButton")
@onready var target_info_label: Label = get_node_or_null("%TargetInfoLabel")
@onready var lead_calc_label: Label = get_node_or_null("%LeadCalcLabel")
@onready var aim_yaw_slider: HSlider = get_node_or_null("%AimYawSlider")
@onready var aim_pitch_slider: HSlider = get_node_or_null("%AimPitchSlider")
@onready var aim_center_button: Button = get_node_or_null("%AimCenterButton")

# Feed Camera Torretta, Viewport 3D & HUD Traiettoria
@onready var sub_viewport_container: SubViewportContainer = get_node_or_null("%SubViewportContainer")
@onready var feed_viewport: SubViewport = get_node_or_null("%FeedViewport")
@onready var feed_camera_3d: Camera3D = get_node_or_null("%FeedCamera3D")
@onready var turret_feed_rect: TextureRect = get_node_or_null("%TurretFeedRect")
@onready var turret_feed_label: Label = get_node_or_null("%TurretFeedLabel")
@onready var feed_crosshair: Control = get_node_or_null("%FeedCrosshair")
@onready var trajectory_hud: WeaponsTrajectoryHUD = get_node_or_null("%TrajectoryHUD")

# Pulsanti d'Azione
@onready var fire_button: Button = get_node_or_null("%FireButton")
@onready var auto_pdg_button: Button = get_node_or_null("%AutoPDGButton")
@onready var vent_heat_button: Button = get_node_or_null("%VentHeatButton")
@onready var reload_ammo_button: Button = get_node_or_null("%ReloadAmmoButton")
@onready var action_log_label: Label = get_node_or_null("%ActionLogLabel")

# --- PARAMETRI DI RUNTIME E STATO ---
var active_ammo_type: int = AmmoType.HEAVY_MG
var active_weapon_group: int:
	get:
		return active_ammo_type
	set(val):
		active_ammo_type = val

var is_mouse_captured: bool = false
var mouse_sensitivity: float = 0.15
var missile_lock_time_required: float = 2.0
var missile_current_aim_time: float = 0.0
var is_missile_locked: bool = false

var heavy_mg_ammo: int = 500
var heavy_cannon_ammo: int = 30
var missile_ammo: int = 12
var probe_ammo: int = 4
var laser_charge: float = 100.0 # 0..100%

# Alias retrocompatibili
var torpedo_ammo: int:
	get:
		return missile_ammo
	set(val):
		missile_ammo = val

var pdg_ammo: int:
	get:
		return heavy_mg_ammo
	set(val):
		heavy_mg_ammo = val

var barrel_heat: float = 0.0 # 0..100%
var is_overheated: bool = false
var auto_pdg_enabled: bool = true
var is_emergency_venting: bool = false
var vent_cooldown_timer: float = 0.0
var fire_cooldown_timer: float = 0.0
var pdg_auto_timer: float = 0.0
var is_target_locked: bool = false
var selected_target_id: String = ""
var manual_aim: Vector2 = Vector2.ZERO # x = yaw (-60..+60), y = pitch (-35..+45)

var can_control_weapons: bool = true

# Configurazione attiva estratta dai file .dat o valori standard
var active_config: Dictionary = {
	"max_range": 4500.0,
	"fire_rate": 1.8,
	"cooling_rate": 0.75,
	"auto_pdg_enabled": true,
	"laser_power_draw": 250.0,
	"heavy_mg_max_ammo": 500,
	"heavy_cannon_max_ammo": 30,
	"missile_max_ammo": 12,
	"probe_max_ammo": 4,
	"torpedo_max_ammo": 12,
	"pdg_ammo_max": 500,
	"pdg_fire_rate": 8.0,
	"emergency_vent_cooldown": 10.0,
	"heavy_mg_velocity": 450.0,
	"heavy_cannon_velocity": 750.0,
	"missile_velocity": 85.0,
	"probe_velocity": 35.0,
	"torpedo_velocity": 85.0,
	"auto_lead_tracking": true,
	"overclock_damage_mult": 1.0,
	"heat_multiplier": 1.0,
	"pdg_range": 1200.0,
	"laser_beam_intensity": 1.0,
	"is_dat_loaded": false
}

var detected_targets: Array[Dictionary] = []

func _ready() -> void:
	_configure_window(APP_TITLE, DEFAULT_WINDOW_SIZE)
	_setup_ui_signals()
	_setup_turret_camera()
	load_dat_configuration()
	_connect_system_signals()
	_update_connection_state()
	_update_permissions()
	_refresh_targets()
	_update_ammo_buttons()
	_update_ui_displays()
	_update_turret_camera_feed()

func _setup_parent_window(_title: String, _size: Vector2) -> void:
	parent_window = _find_parent_window()
	if parent_window:
		parent_window.size = DEFAULT_WINDOW_SIZE
		parent_window.custom_minimum_size = Vector2(620, 460)
		parent_window.title_text = APP_TITLE
		var title_label := parent_window.get_node_or_null("Top Bar/Title Text")
		if title_label:
			title_label.text = "[center]" + APP_TITLE
		
		if parent_window.has_signal("selected") and not parent_window.selected.is_connected(_on_parent_window_selected):
			parent_window.selected.connect(_on_parent_window_selected)
		if parent_window.has_signal("minimized") and not parent_window.minimized.is_connected(_on_parent_window_minimized):
			parent_window.minimized.connect(_on_parent_window_minimized)

func _on_parent_window_selected(is_sel: bool) -> void:
	if not is_sel and is_mouse_captured:
		_release_mouse()

func _on_parent_window_minimized(is_min: bool) -> void:
	if is_min and is_mouse_captured:
		_release_mouse()

func _find_parent_window() -> FakeWindow:
	var cur := get_parent()
	while cur != null:
		if cur is FakeWindow:
			return cur as FakeWindow
		cur = cur.get_parent()
	return null

func _setup_ui_signals() -> void:
	if btn_ammo_mg:
		btn_ammo_mg.pressed.connect(func(): _select_ammo_type(AmmoType.HEAVY_MG))
	if btn_ammo_cannon:
		btn_ammo_cannon.pressed.connect(func(): _select_ammo_type(AmmoType.HEAVY_CANNON))
	if btn_ammo_missile:
		btn_ammo_missile.pressed.connect(func(): _select_ammo_type(AmmoType.MISSILE))
	if btn_ammo_probe:
		btn_ammo_probe.pressed.connect(func(): _select_ammo_type(AmmoType.PROBE))
	
	if fire_button:
		fire_button.pressed.connect(_on_fire_button_pressed)
	if auto_pdg_button:
		auto_pdg_button.pressed.connect(_on_auto_pdg_button_pressed)
	if vent_heat_button:
		vent_heat_button.pressed.connect(_on_vent_heat_button_pressed)
	if reload_ammo_button:
		reload_ammo_button.pressed.connect(_on_reload_ammo_button_pressed)
	if reload_dat_button:
		reload_dat_button.pressed.connect(load_dat_configuration)
	
	if target_option_button:
		target_option_button.item_selected.connect(_on_target_option_selected)
	if lock_button:
		lock_button.pressed.connect(_on_lock_button_pressed)
	
	if aim_yaw_slider:
		aim_yaw_slider.value_changed.connect(_on_aim_slider_changed)
	if aim_pitch_slider:
		aim_pitch_slider.value_changed.connect(_on_aim_slider_changed)
	if aim_center_button:
		aim_center_button.pressed.connect(_on_aim_center_pressed)

func _connect_system_signals() -> void:
	if SpaceWorldManager:
		if SpaceWorldManager.has_signal("ship_connection_changed") and not SpaceWorldManager.ship_connection_changed.is_connected(_on_ship_connection_changed):
			SpaceWorldManager.ship_connection_changed.connect(_on_ship_connection_changed)
	
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
		if sdm.has_signal("drive_synced") and not sdm.drive_synced.is_connected(_on_drive_synced):
			sdm.drive_synced.connect(_on_drive_synced)

func _exit_tree() -> void:
	if is_mouse_captured:
		_release_mouse()
	
	if SpaceWorldManager and SpaceWorldManager.has_signal("ship_connection_changed") and SpaceWorldManager.ship_connection_changed.is_connected(_on_ship_connection_changed):
		SpaceWorldManager.ship_connection_changed.disconnect(_on_ship_connection_changed)
	
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
		if sdm.has_signal("drive_synced") and sdm.drive_synced.is_connected(_on_drive_synced):
			sdm.drive_synced.disconnect(_on_drive_synced)

func _get_net_mgr() -> Node:
	return get_node_or_null("/root/NetworkManager")

# --- GESTIONE INPUT, CATTURA MOUSE E SELEZIONE MUNIZIONI ---

func _input(event: InputEvent) -> void:
	if not is_inside_tree() or not is_visible_in_tree():
		return
	
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_toggle_mouse_capture()
		elif event.keycode == KEY_ESCAPE:
			if is_mouse_captured:
				_release_mouse()
		elif event.keycode == KEY_1:
			_select_ammo_type(AmmoType.HEAVY_MG)
		elif event.keycode == KEY_2:
			_select_ammo_type(AmmoType.HEAVY_CANNON)
		elif event.keycode == KEY_3:
			_select_ammo_type(AmmoType.MISSILE)
		elif event.keycode == KEY_4:
			_select_ammo_type(AmmoType.PROBE)
	
	if is_mouse_captured and event is InputEventMouseMotion:
		if can_control_weapons:
			manual_aim.x = clampf(manual_aim.x - event.relative.x * mouse_sensitivity, -60.0, 60.0)
			manual_aim.y = clampf(manual_aim.y - event.relative.y * mouse_sensitivity, -35.0, 45.0)
			if aim_yaw_slider:
				aim_yaw_slider.set_value_no_signal(manual_aim.x)
			if aim_pitch_slider:
				aim_pitch_slider.set_value_no_signal(manual_aim.y)
			_update_turret_camera_feed()
	
	if is_mouse_captured and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_fire_button_pressed()

func _toggle_mouse_capture() -> void:
	is_mouse_captured = not is_mouse_captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if is_mouse_captured else Input.MOUSE_MODE_VISIBLE
	if trajectory_hud:
		trajectory_hud.is_mouse_captured = is_mouse_captured
	_log_action("CONTROLLO TORRETTA MOUSE: %s" % ("CATTURATO (Premi Spazio/ESC per sbloccare)" if is_mouse_captured else "RILASCIATO"))

func _release_mouse() -> void:
	if is_mouse_captured:
		is_mouse_captured = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if trajectory_hud:
			trajectory_hud.is_mouse_captured = false
		_log_action("PUNTATORE MOUSE RILASCIATO.")

# --- GESTIONE FILE .DAT E CONFIGURAZIONE RUNTIME ---

func _on_drive_file_event(path: String) -> void:
	if "Programs/Weapons" in path and path.ends_with(".dat"):
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
			dat_status_badge.text = "DAT: ATTIVO (FIRMWARE V1.0.4)"
			dat_status_badge.modulate = Color(0.3, 1.0, 0.4)
		else:
			dat_status_badge.text = "DAT: STANDARD (FALLBACK)"
			dat_status_badge.modulate = Color(1.0, 0.8, 0.2)

func _apply_dict_to_config(data: Dictionary) -> void:
	for k in data:
		active_config[k] = data[k]

func _apply_configuration() -> void:
	if active_config.has("auto_pdg_enabled"):
		auto_pdg_enabled = bool(active_config["auto_pdg_enabled"])
	if active_config.has("torpedo_max_ammo"):
		missile_ammo = mini(missile_ammo, int(active_config["torpedo_max_ammo"]))
	if active_config.has("pdg_ammo_max"):
		heavy_mg_ammo = mini(heavy_mg_ammo, int(active_config["pdg_ammo_max"]))
	if active_config.has("heavy_cannon_max_ammo"):
		heavy_cannon_ammo = mini(heavy_cannon_ammo, int(active_config["heavy_cannon_max_ammo"]))
	if active_config.has("probe_max_ammo"):
		probe_ammo = mini(probe_ammo, int(active_config["probe_max_ammo"]))
	_update_ui_displays()

func _on_ship_connection_changed(_is_conn: bool) -> void:
	_update_connection_state()

func _on_mission_started(_role: String = "", _is_solo: bool = false) -> void:
	_update_connection_state()
	_update_permissions()
	_refresh_targets()

func _on_mission_ended() -> void:
	_update_connection_state()

func _on_player_role_changed(_peer_id: int, _role: String) -> void:
	_update_permissions()

func _is_ship_operational() -> bool:
	if SpaceWorldManager and SpaceWorldManager.has_method("is_ship_connected"):
		return SpaceWorldManager.is_ship_connected()
	var nm := _get_net_mgr()
	if nm and nm.has_method("is_ship_connected"):
		return nm.is_ship_connected()
	return false

func _update_connection_state() -> void:
	var is_op: bool = _is_ship_operational()
	if disconnected_overlay:
		disconnected_overlay.visible = not is_op
	
	set_process(is_op)
	set_physics_process(is_op)
	
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
	
	# RBAC: Soldato, Tattico / Armi, Capitano, Stagista, Solo Mode hanno pieno controllo
	can_control_weapons = (
		is_solo or
		my_role in ["Soldato", "Tattico / Armi", "Capitano", "Stagista", "Admin", "Host"] or
		my_role.is_empty() # Fallback se nessun ruolo impostato
	)
	
	if role_badge:
		var display_role := my_role if not my_role.is_empty() else ("SOLO MODE" if is_solo else "SPETTATORE")
		role_badge.text = "RUOLO: %s" % display_role
		if can_control_weapons:
			role_badge.modulate = Color(0.4, 0.85, 1.0)
		else:
			role_badge.text += " (SOLA LETTURA)"
			role_badge.modulate = Color(0.85, 0.85, 0.4)
	
	# Abilita o disabilita pulsanti di comando
	if fire_button:
		fire_button.disabled = not can_control_weapons
	if auto_pdg_button:
		auto_pdg_button.disabled = not can_control_weapons
	if vent_heat_button:
		vent_heat_button.disabled = not can_control_weapons
	if lock_button:
		lock_button.disabled = not can_control_weapons
	if reload_ammo_button:
		reload_ammo_button.disabled = not can_control_weapons
	if aim_yaw_slider:
		aim_yaw_slider.editable = can_control_weapons
	if aim_pitch_slider:
		aim_pitch_slider.editable = can_control_weapons
	if aim_center_button:
		aim_center_button.disabled = not can_control_weapons

# --- PROCESSO FISICO, RICARICA E TERMODINAMICA ---

func _process(delta: float) -> void:
	if not _is_ship_operational():
		return
	
	_update_timers(delta)
	_update_cooling_and_power(delta)
	_process_auto_pdg(delta)
	_process_missile_lock(delta)
	_refresh_targets()
	_update_turret_camera(delta)
	_update_ui_displays()

func _update_timers(delta: float) -> void:
	if fire_cooldown_timer > 0.0:
		fire_cooldown_timer -= delta
	
	if vent_cooldown_timer > 0.0:
		vent_cooldown_timer -= delta
		if vent_cooldown_timer <= 0.0:
			is_emergency_venting = false

func _update_cooling_and_power(delta: float) -> void:
	var armory_powered := true
	if SpaceWorldManager and SpaceWorldManager.has_method("is_armory_powered"):
		armory_powered = SpaceWorldManager.is_armory_powered()
	
	if power_badge:
		if armory_powered:
			power_badge.text = "PWR: 250 MW (OK)"
			power_badge.modulate = Color(0.3, 0.9, 0.5)
		else:
			power_badge.text = "⚠️ PWR: 0 MW (OFFLINE)"
			power_badge.modulate = Color(1.0, 0.25, 0.25)
	
	# Gestione blocco surriscaldamento
	if barrel_heat >= 100.0:
		is_overheated = true
	
	# Raffreddamento naturale canne
	var cooling_rate: float = float(active_config.get("cooling_rate", 0.75)) * 12.0
	if is_emergency_venting:
		cooling_rate *= 5.0
	
	if barrel_heat > 0.0:
		barrel_heat = maxf(0.0, barrel_heat - cooling_rate * delta)
	
	if is_overheated and barrel_heat < 25.0:
		is_overheated = false
	
	# Ricarica condensatori laser (dipendente dall'alimentazione Armeria Sublayer 3)
	if armory_powered:
		var recharge_speed: float = float(active_config.get("fire_rate", 1.8)) * 14.0
		laser_charge = minf(100.0, laser_charge + recharge_speed * delta)

func _process_auto_pdg(delta: float) -> void:
	if not auto_pdg_enabled or is_overheated:
		return
	
	pdg_auto_timer += delta
	var pdg_interval := 1.0 / maxf(float(active_config.get("pdg_fire_rate", 8.0)), 0.1)
	
	if pdg_auto_timer >= pdg_interval:
		pdg_auto_timer = 0.0
		# Controlla se c'e' un bersaglio pericolo a breve raggio (< 80m)
		for t in detected_targets:
			var dist: float = float(t.get("distance", 0.0))
			var threat: String = str(t.get("threat_level", "UNKNOWN"))
			if (threat in ["HAZARD", "HOSTILE"] or dist < 65.0) and heavy_mg_ammo > 0:
				heavy_mg_ammo -= 1
				var heat_mult: float = float(active_config.get("heat_multiplier", 1.0))
				barrel_heat = minf(100.0, barrel_heat + 1.2 * heat_mult)
				if SpaceWorldManager and SpaceWorldManager.has_method("request_fire_weapon"):
					SpaceWorldManager.request_fire_weapon("PDG_AUTO", str(t.get("id", "")), Vector3.ZERO)
				break

func _process_missile_lock(delta: float) -> void:
	if active_ammo_type == AmmoType.MISSILE:
		var has_alignment := false
		var best_target_id := ""
		var min_angle_diff := 999.0
		
		# Verifica allineamento reticolo manual_aim con i bersagli entro 5.0 gradi
		for t in detected_targets:
			var t_bearing: float = float(t.get("bearing_deg", 0.0))
			var t_elev: float = float(t.get("elevation_deg", 0.0))
			var delta_yaw := absf(t_bearing - manual_aim.x)
			var delta_pitch := absf(t_elev - manual_aim.y)
			var angle_diff := Vector2(delta_yaw, delta_pitch).length()
			if angle_diff <= 5.0:
				if angle_diff < min_angle_diff:
					min_angle_diff = angle_diff
					best_target_id = str(t.get("id", ""))
				has_alignment = true
		
		if has_alignment and not best_target_id.is_empty():
			if selected_target_id.is_empty() and not is_target_locked:
				selected_target_id = best_target_id
				_populate_target_dropdown()
		
		if has_alignment or (is_target_locked and not selected_target_id.is_empty()):
			missile_current_aim_time = minf(missile_lock_time_required, missile_current_aim_time + delta)
			if missile_current_aim_time >= missile_lock_time_required:
				is_missile_locked = true
		else:
			missile_current_aim_time = maxf(0.0, missile_current_aim_time - delta * 2.0)
			if not is_target_locked:
				is_missile_locked = false
	else:
		if not is_target_locked:
			missile_current_aim_time = 0.0
			is_missile_locked = false

# --- TARGETING, RADAR E CALCOLO LEAD INDICATOR ---

func _refresh_targets() -> void:
	if SpaceWorldManager and SpaceWorldManager.has_method("get_weapon_targets"):
		detected_targets = SpaceWorldManager.get_weapon_targets()
	
	if radar_canvas:
		radar_canvas.targets = detected_targets
		radar_canvas.locked_target_id = selected_target_id
		radar_canvas.has_lock = is_target_locked
		radar_canvas.aim_angles = manual_aim
		
		# Calcola Lead Indicator per il bersaglio bloccato
		if is_target_locked and not selected_target_id.is_empty():
			var target_data := _get_target_data(selected_target_id)
			if not target_data.is_empty():
				var t_dist: float = float(target_data.get("distance", 0.0))
				var proj_vel := _get_active_projectile_velocity()
				var flight_time := t_dist / maxf(proj_vel, 1.0)
				var t_vel: Vector3 = target_data.get("velocity", Vector3.ZERO)
				var lead_world_delta := t_vel * flight_time
				# Proietta in 2D sul radar
				radar_canvas.lead_offset = Vector2(lead_world_delta.x, -lead_world_delta.z) * 1.5
		else:
			radar_canvas.lead_offset = Vector2.ZERO
	
	_populate_target_dropdown()

func _populate_target_dropdown() -> void:
	if not target_option_button:
		return
	
	var cur_selected := target_option_button.selected
	var prev_id := selected_target_id
	
	target_option_button.clear()
	target_option_button.add_item("-- NESSUN BERSAGLIO --", 0)
	
	var new_idx := 0
	for i in range(detected_targets.size()):
		var t: Dictionary = detected_targets[i]
		var item_text := "%s (%.0fm) - %s" % [str(t.get("name", "IGNOTO")), float(t.get("distance", 0.0)), str(t.get("threat_level", "UNKNOWN"))]
		target_option_button.add_item(item_text, i + 1)
		if str(t.get("id", "")) == prev_id:
			new_idx = i + 1
	
	if new_idx > 0:
		target_option_button.selected = new_idx
	elif cur_selected >= 0 and cur_selected < target_option_button.item_count:
		target_option_button.selected = cur_selected

func _get_target_data(target_id: String) -> Dictionary:
	for t in detected_targets:
		if str(t.get("id", "")) == target_id:
			return t
	return {}

func _on_target_option_selected(index: int) -> void:
	if index <= 0 or index > detected_targets.size():
		selected_target_id = ""
		is_target_locked = false
		is_missile_locked = false
		missile_current_aim_time = 0.0
	else:
		selected_target_id = detected_targets[index - 1].get("id")
	_update_target_info()

func _on_lock_button_pressed() -> void:
	if selected_target_id.is_empty() and not detected_targets.is_empty():
		selected_target_id = detected_targets[0].get("id")
		if target_option_button:
			target_option_button.selected = 1
	
	if not selected_target_id.is_empty():
		is_target_locked = not is_target_locked
		if is_target_locked:
			is_missile_locked = true
			missile_current_aim_time = missile_lock_time_required
		else:
			is_missile_locked = false
			missile_current_aim_time = 0.0
		_log_action("TARGET LOCK: %s [%s]" % [selected_target_id, "AGGANCIO CONFERMATO" if is_target_locked else "SBLOCCATO"])
	
	_update_target_info()

func _update_target_info() -> void:
	if radar_canvas:
		radar_canvas.locked_target_id = selected_target_id
		radar_canvas.has_lock = is_target_locked
		if is_target_locked and not selected_target_id.is_empty():
			var target_data := _get_target_data(selected_target_id)
			if not target_data.is_empty():
				var t_dist: float = float(target_data.get("distance", 0.0))
				var proj_vel := _get_active_projectile_velocity()
				var flight_time := t_dist / maxf(proj_vel, 1.0)
				var t_vel: Vector3 = target_data.get("velocity", Vector3.ZERO)
				var lead_world_delta := t_vel * flight_time
				radar_canvas.lead_offset = Vector2(lead_world_delta.x, -lead_world_delta.z) * 1.5
		else:
			radar_canvas.lead_offset = Vector2.ZERO
	
	if lock_button:
		lock_button.text = "🎯 SBLOCCA LOCK" if is_target_locked else "🎯 AGGANCIA LOCK"
		lock_button.modulate = Color(1.0, 0.4, 0.4) if is_target_locked else Color(0.3, 0.9, 1.0)
	
	if target_info_label:
		if not selected_target_id.is_empty():
			var t := _get_target_data(selected_target_id)
			target_info_label.text = "BERSAGLIO: %s | DIST: %.1fm | AZIMUTH: %.1f° | STATO: %s" % [
				str(t.get("name", "IGNOTO")),
				float(t.get("distance", 0.0)),
				float(t.get("bearing_deg", 0.0)),
				"🔒 AGGANCIATO" if (is_target_locked or is_missile_locked) else "TRACCIATO"
			]
		else:
			target_info_label.text = "BERSAGLIO: NESSUNO SELEZIONATO"
	
	if lead_calc_label:
		if is_target_locked or is_missile_locked or not selected_target_id.is_empty():
			var t := _get_target_data(selected_target_id)
			var proj_vel := _get_active_projectile_velocity()
			var dist: float = float(t.get("distance", 0.0))
			var t_hit := dist / maxf(proj_vel, 1.0)
			lead_calc_label.text = "ANTICIPO TIRO (LEAD): +%.2fs | VEL_PROIETTILE: %.0f m/s | RETICOLO PRONTO" % [t_hit, proj_vel]
		else:
			lead_calc_label.text = "ANTICIPO TIRO (LEAD): STANDBY (AGGANCIARE BERSAGLIO)"
	
	_update_turret_camera_feed()

func _setup_turret_camera() -> void:
	if not is_inside_tree():
		return
	if feed_viewport and SpaceWorldManager:
		feed_viewport.world_3d = SpaceWorldManager.get_world_3d()
		feed_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		feed_viewport.handle_input_locally = false
		feed_viewport.own_world_3d = false
	if feed_camera_3d:
		feed_camera_3d.current = true
		feed_camera_3d.fov = 65.0

func _on_aim_slider_changed(_val: float) -> void:
	if aim_yaw_slider and aim_pitch_slider:
		manual_aim = Vector2(aim_yaw_slider.value, aim_pitch_slider.value)
	_update_turret_camera_feed()

func _on_aim_center_pressed() -> void:
	if aim_yaw_slider:
		aim_yaw_slider.value = 0.0
	if aim_pitch_slider:
		aim_pitch_slider.value = 0.0
	manual_aim = Vector2.ZERO
	_update_turret_camera_feed()

func _update_turret_camera(delta: float = 0.0) -> void:
	# Se target locked e auto lead tracking abilitato, allinea la mira al bersaglio
	if is_target_locked and not selected_target_id.is_empty() and bool(active_config.get("auto_lead_tracking", true)):
		var t := _get_target_data(selected_target_id)
		if not t.is_empty():
			var target_bearing: float = float(t.get("bearing_deg", 0.0))
			var target_elev: float = float(t.get("elevation_deg", 0.0))
			if delta > 0.0:
				manual_aim.x = clampf(lerpf(manual_aim.x, target_bearing, 8.0 * delta), -60.0, 60.0)
				manual_aim.y = clampf(lerpf(manual_aim.y, target_elev, 8.0 * delta), -35.0, 45.0)
			else:
				manual_aim.x = clampf(target_bearing, -60.0, 60.0)
				manual_aim.y = clampf(target_elev, -35.0, 45.0)
			
			if aim_yaw_slider:
				aim_yaw_slider.set_value_no_signal(manual_aim.x)
			if aim_pitch_slider:
				aim_pitch_slider.set_value_no_signal(manual_aim.y)
	
	_update_turret_camera_feed()

func _update_turret_camera_feed() -> void:
	if turret_feed_label:
		turret_feed_label.text = "CAMERA OTTICA PUNTAMENTO [YAW: %+.1f° | PITCH: %+.1f°]" % [manual_aim.x, manual_aim.y]
	
	# Aggiorna orientamento 3D della telecamera nel mondo di gioco
	if feed_camera_3d and is_instance_valid(feed_camera_3d):
		if feed_viewport and feed_viewport.world_3d == null and SpaceWorldManager:
			feed_viewport.world_3d = SpaceWorldManager.get_world_3d()
		
		var ship_trans := Transform3D.IDENTITY
		if SpaceWorldManager:
			var ship := SpaceWorldManager.get_spaceship()
			if ship and is_instance_valid(ship) and ship.is_inside_tree():
				ship_trans = SpaceWorldManager.get_camera_transform("front")
			else:
				ship_trans = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.25, -2.1))
		
		var yaw_rad: float = deg_to_rad(-manual_aim.x)
		var pitch_rad: float = deg_to_rad(-manual_aim.y)
		var rot_basis := Basis.from_euler(Vector3(pitch_rad, yaw_rad, 0.0), EulerOrder.EULER_ORDER_YXZ)
		feed_camera_3d.global_transform = Transform3D(ship_trans.basis * rot_basis, ship_trans.origin)
	
	# Centratura reticolo HUD standard
	if feed_crosshair:
		var parent_ctrl: Control = feed_crosshair.get_parent() as Control
		var center := parent_ctrl.size * 0.5 if parent_ctrl else Vector2(160, 55)
		var offset := Vector2(manual_aim.x * 1.5, -manual_aim.y * 1.5)
		feed_crosshair.position = center + offset - feed_crosshair.size * 0.5
	
	# Aggiornamento HUD Traiettoria Diegetico e Lead Indicator
	if trajectory_hud:
		trajectory_hud.is_mouse_captured = is_mouse_captured
		trajectory_hud.aim_yaw = manual_aim.x
		trajectory_hud.aim_pitch = manual_aim.y
		trajectory_hud.active_ammo_type = active_ammo_type
		trajectory_hud.active_ammo_name = _get_ammo_type_name(active_ammo_type)
		trajectory_hud.is_missile_locked = is_missile_locked
		trajectory_hud.missile_lock_progress = clampf(missile_current_aim_time / maxf(missile_lock_time_required, 0.01), 0.0, 1.0)
		
		var hud_center := trajectory_hud.size * 0.5
		var reticle_offset := Vector2(manual_aim.x * 1.5, -manual_aim.y * 1.5)
		trajectory_hud.crosshair_pos = hud_center + reticle_offset
		
		if not selected_target_id.is_empty():
			var t := _get_target_data(selected_target_id)
			if not t.is_empty():
				var t_dist: float = float(t.get("distance", 0.0))
				var proj_vel := _get_active_projectile_velocity()
				var flight_time := t_dist / maxf(proj_vel, 1.0)
				var t_vel: Vector3 = t.get("velocity", Vector3.ZERO)
				var lead_world_delta := t_vel * flight_time
				
				trajectory_hud.target_name = str(t.get("name", "BERSAGLIO"))
				trajectory_hud.target_dist = t_dist
				trajectory_hud.has_target_screen = true
				
				var target_yaw: float = float(t.get("bearing_deg", 0.0))
				var target_pitch: float = float(t.get("elevation_deg", 0.0))
				var t_screen_offset := Vector2((target_yaw - manual_aim.x) * 3.5, -(target_pitch - manual_aim.y) * 3.5)
				trajectory_hud.target_screen_pos = hud_center + reticle_offset + t_screen_offset
				
				var lead_yaw: float = target_yaw + rad_to_deg(atan2(lead_world_delta.x, maxf(t_dist, 1.0)))
				var lead_pitch: float = target_pitch + rad_to_deg(atan2(lead_world_delta.y, maxf(t_dist, 1.0)))
				var lead_screen_offset := Vector2((lead_yaw - manual_aim.x) * 3.5, -(lead_pitch - manual_aim.y) * 3.5)
				trajectory_hud.lead_pos = hud_center + reticle_offset + lead_screen_offset
				trajectory_hud.has_lead = true
			else:
				trajectory_hud.has_lead = false
				trajectory_hud.has_target_screen = false
		else:
			trajectory_hud.has_lead = false
			trajectory_hud.has_target_screen = false

func _get_active_projectile_velocity() -> float:
	match active_ammo_type:
		AmmoType.HEAVY_MG:
			return float(active_config.get("heavy_mg_velocity", 450.0))
		AmmoType.HEAVY_CANNON:
			return float(active_config.get("heavy_cannon_velocity", 750.0))
		AmmoType.MISSILE:
			return float(active_config.get("missile_velocity", active_config.get("torpedo_velocity", 85.0)))
		AmmoType.PROBE:
			return float(active_config.get("probe_velocity", 35.0))
		_:
			return 500.0

# --- AZIONI DI FUOCO E GESTIONE SELETTORE MUNIZIONI ---

func _select_ammo_type(type: int) -> void:
	active_ammo_type = type
	_update_ammo_buttons()
	_update_target_info()
	_update_turret_camera_feed()
	_log_action("SISTEMA SELEZIONATO: [%d] %s" % [active_ammo_type, _get_ammo_type_name(active_ammo_type)])

func _select_weapon_group(group: int) -> void:
	if group == 0:
		_select_ammo_type(AmmoType.HEAVY_CANNON)
	else:
		_select_ammo_type(group)

func _get_ammo_type_name(type: int) -> String:
	match type:
		AmmoType.HEAVY_MG:
			return "MITRAGLIATRICE PESANTE"
		AmmoType.HEAVY_CANNON:
			return "CANNONE PESANTE A IMPULSI"
		AmmoType.MISSILE:
			return "MISSILI A RICERCA TERMICA"
		AmmoType.PROBE:
			return "SONDA TELEMETRICA SPAZIALE"
		_:
			return "SISTEMA D'ARMA"

func _get_weapon_group_name(group: int) -> String:
	return _get_ammo_type_name(group)

func _update_ammo_buttons() -> void:
	if btn_ammo_mg:
		btn_ammo_mg.button_pressed = (active_ammo_type == AmmoType.HEAVY_MG)
	if btn_ammo_cannon:
		btn_ammo_cannon.button_pressed = (active_ammo_type == AmmoType.HEAVY_CANNON)
	if btn_ammo_missile:
		btn_ammo_missile.button_pressed = (active_ammo_type == AmmoType.MISSILE)
	if btn_ammo_probe:
		btn_ammo_probe.button_pressed = (active_ammo_type == AmmoType.PROBE)
	
	if selected_group_label:
		selected_group_label.text = "SISTEMA ATTIVO: [%d] %s" % [active_ammo_type, _get_ammo_type_name(active_ammo_type)]

func _update_weapon_group_buttons() -> void:
	_update_ammo_buttons()

func _on_fire_button_pressed() -> void:
	if not _is_ship_operational() or not can_control_weapons:
		return
	
	if is_overheated:
		_log_action("⚠️ FUOCO BLOCCATO: SOVRATEMPERATURA CRITICA CANNE")
		return
	
	if fire_cooldown_timer > 0.0:
		return
	
	var heat_mult: float = float(active_config.get("heat_multiplier", 1.0))
	var fire_rate: float = float(active_config.get("fire_rate", 1.8))
	
	match active_ammo_type:
		AmmoType.HEAVY_MG:
			if heavy_mg_ammo <= 0:
				_log_action("⚠️ MUNIZIONI MITRAGLIATRICE PESANTE ESAURITE!")
				return
			heavy_mg_ammo -= 1
			barrel_heat = minf(100.0, barrel_heat + 0.8 * heat_mult)
			fire_cooldown_timer = 0.08
			_execute_fire_event("HEAVY_MG")
			_log_action("💥 MITRAGLIATRICE PESANTE: COLPO ESPLOSO (MUNIZIONI: %d | CALORE: %.0f%%)" % [heavy_mg_ammo, barrel_heat])
			
		AmmoType.HEAVY_CANNON:
			if laser_charge < 20.0 and heavy_cannon_ammo <= 0:
				_log_action("⚠️ CANNONE PESANTE: CARICA CONDENSATORI INSUFFICIENTE (< 20%)")
				return
			laser_charge = maxf(0.0, laser_charge - 20.0)
			heavy_cannon_ammo = maxi(0, heavy_cannon_ammo - 1)
			barrel_heat = minf(100.0, barrel_heat + 18.0 * heat_mult)
			fire_cooldown_timer = 1.4
			_execute_fire_event("HEAVY_CANNON")
			_log_action("⚡ CANNONE PESANTE: COLPO CRITICO SPARATO (COLPI: %d | CONDENSATORE: %.0f%%)" % [heavy_cannon_ammo, laser_charge])
			
		AmmoType.MISSILE:
			if not is_missile_locked:
				_log_action("⚠️ LANCIO NEGATO: LOCK IN CORSO (ALLINEARE MIRINO O RADAR LOCK)...")
				return
			if missile_ammo <= 0:
				_log_action("⚠️ MISSILI / SILURI ESAURITI! RICARICARE ALL'ARMERIA")
				return
			missile_ammo -= 1
			barrel_heat = minf(100.0, barrel_heat + 22.0 * heat_mult)
			fire_cooldown_timer = 2.5
			_execute_fire_event("HOMING_MISSILE")
			_log_action("🚀 MISSILE A RICERCA LANCIATO SU [%s] (RIMANENTI: %d)" % [selected_target_id if not selected_target_id.is_empty() else "TARGET", missile_ammo])
			
		AmmoType.PROBE:
			if probe_ammo <= 0:
				_log_action("⚠️ SONDE TELEMETRICHE ESAURITE NELLA STIVA!")
				return
			probe_ammo -= 1
			barrel_heat = minf(100.0, barrel_heat + 2.0 * heat_mult)
			fire_cooldown_timer = 1.0
			_execute_fire_event("PROBE")
			_log_action("📡 SONDA TELEMETRICA LANCIATA NELLO SPAZIO (DISPONIBILI: %d)" % probe_ammo)
	
	_update_ui_displays()

func _execute_fire_event(weapon_name: String) -> void:
	var aim_dir := Vector3(sin(deg_to_rad(manual_aim.x)), sin(deg_to_rad(manual_aim.y)), -cos(deg_to_rad(manual_aim.x)))
	if SpaceWorldManager and SpaceWorldManager.has_method("request_fire_weapon"):
		SpaceWorldManager.request_fire_weapon(weapon_name, selected_target_id if (is_target_locked or is_missile_locked) else "", aim_dir)

func _on_auto_pdg_button_pressed() -> void:
	auto_pdg_enabled = not auto_pdg_enabled
	_update_ui_displays()
	_log_action("PDG AUTOMATICO: %s" % ("ATTIVATO" if auto_pdg_enabled else "DISATTIVATO"))

func _on_vent_heat_button_pressed() -> void:
	if is_emergency_venting or vent_cooldown_timer > 0.0:
		_log_action("⚠️ SCARICO TERMICO IN CORSO O IN RICARICA (%.1fs)" % vent_cooldown_timer)
		return
	
	is_emergency_venting = true
	barrel_heat = 0.0
	is_overheated = false
	vent_cooldown_timer = float(active_config.get("emergency_vent_cooldown", 10.0))
	_update_ui_displays()
	_log_action("❄️ SCARICO TERMICO D'EMERGENZA COMPLETATO (VENT 0% HEAT)")

func _on_reload_ammo_button_pressed() -> void:
	heavy_mg_ammo = int(active_config.get("heavy_mg_max_ammo", active_config.get("pdg_ammo_max", 500)))
	heavy_cannon_ammo = int(active_config.get("heavy_cannon_max_ammo", 30))
	missile_ammo = int(active_config.get("missile_max_ammo", active_config.get("torpedo_max_ammo", 12)))
	probe_ammo = int(active_config.get("probe_max_ammo", 4))
	laser_charge = 100.0
	_update_ui_displays()
	_log_action("🔄 RISERVE D'ARMAMENTO, CONDENSATORI E SONDE RICARICATI AL 100%")

func _update_ui_displays() -> void:
	# Condensatori
	if capacitor_progress:
		capacitor_progress.value = laser_charge
	if capacitor_value_label:
		capacitor_value_label.text = "%.0f%%" % laser_charge
	
	# Calore
	if heat_progress:
		heat_progress.value = barrel_heat
		if barrel_heat > 80.0:
			heat_progress.modulate = Color(1.0, 0.2, 0.2)
		elif barrel_heat > 50.0:
			heat_progress.modulate = Color(1.0, 0.7, 0.2)
		else:
			heat_progress.modulate = Color(0.2, 0.9, 0.6)
	
	if heat_value_label:
		heat_value_label.text = "%.0f%%" % barrel_heat
	
	if overheat_warning_label:
		overheat_warning_label.visible = is_overheated
	
	# Munizioni
	if ammo_torpedo_label:
		var max_t := int(active_config.get("missile_max_ammo", active_config.get("torpedo_max_ammo", 12)))
		ammo_torpedo_label.text = "%d / %d" % [missile_ammo, max_t]
		ammo_torpedo_label.modulate = Color(1.0, 0.4, 0.4) if missile_ammo == 0 else Color(1.0, 0.9, 0.5)
	
	if ammo_pdg_label:
		var max_p := int(active_config.get("heavy_mg_max_ammo", active_config.get("pdg_ammo_max", 500)))
		ammo_pdg_label.text = "%d / %d" % [heavy_mg_ammo, max_p]
		ammo_pdg_label.modulate = Color(1.0, 0.4, 0.4) if heavy_mg_ammo == 0 else Color(0.5, 0.9, 1.0)
	
	if ammo_probe_label:
		var max_pr := int(active_config.get("probe_max_ammo", 4))
		ammo_probe_label.text = "%d / %d" % [probe_ammo, max_pr]
		ammo_probe_label.modulate = Color(1.0, 0.4, 0.4) if probe_ammo == 0 else Color(0.6, 1.0, 0.7)
	
	# Auto PDG button
	if auto_pdg_button:
		auto_pdg_button.text = "PDG AUTO: ATTIVO" if auto_pdg_enabled else "PDG AUTO: DISATTIVATO"
		auto_pdg_button.modulate = Color(0.3, 1.0, 0.5) if auto_pdg_enabled else Color(0.7, 0.7, 0.7)
	
	# Emergency Vent Button
	if vent_heat_button:
		if vent_cooldown_timer > 0.0:
			vent_heat_button.text = "SCARICO TERMICO (%.0fs)" % vent_cooldown_timer
		else:
			vent_heat_button.text = "❄️ SCARICO TERMICO D'EMERGENZA"

func _log_action(msg: String) -> void:
	if action_log_label:
		action_log_label.text = "> " + msg
