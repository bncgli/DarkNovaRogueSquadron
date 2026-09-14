class_name LifeSupportApp
extends BaseApp

## Controller per l'applicazione di bordo "Life Support & Atmosphere Control" (Applications/LifeSupport).
## Gestisce il monitoraggio e controllo di O2, CO2, pressione barometrica, temperatura,
## incendi, fumo, paratie stagne e iniezione gas inerte antincendio per ciascun compartimento.

signal atmosphere_anomaly_detected(room_id: String, anomaly_type: String)

const APP_TITLE: String = "SUPPORTO VITALE & CONTROLLO ATMOSFERA"
const DEFAULT_WINDOW_SIZE: Vector2 = Vector2(880, 610)
const MIN_WINDOW_SIZE: Vector2 = Vector2(850, 590)
const BLUEPRINT_SIZE: Vector2 = Vector2(600, 480)
const BASE_POWER_MW: float = 20.0

const CONFIG_PATH_PRIMARY: String = "Ship Drive/Programs/LifeSupport/life_support_config.dat"
const CONFIG_PATH_FALLBACK: String = "Terminal Drive/Programs/LifeSupport/life_support_config.dat"
const TUNING_PATH_PRIMARY: String = "Ship Drive/Programs/LifeSupport/atmo_tuning.dat"
const TUNING_PATH_FALLBACK: String = "Terminal Drive/Programs/LifeSupport/atmo_tuning.dat"

# --- RIFERIMENTI UI (Unique Names) ---
@onready var map_canvas: Control = get_node_or_null("%MapCanvas")
@onready var disconnected_overlay: Control = get_node_or_null("%DisconnectedOverlay")
@onready var status_badge: Label = get_node_or_null("%StatusBadge")
@onready var role_badge: Label = get_node_or_null("%RoleBadge")
@onready var dat_status_badge: Label = get_node_or_null("%DatBadge")
@onready var btn_reload_dat: Button = get_node_or_null("%BtnReloadDat")

@onready var room_cards_container: Container = get_node_or_null("%RoomCardsContainer")
@onready var selected_room_title: Label = get_node_or_null("%SelectedRoomTitle")
@onready var selected_room_status: Label = get_node_or_null("%SelectedRoomStatus")
@onready var selected_o2_label: Label = get_node_or_null("%SelectedO2Label")
@onready var selected_o2_bar: ProgressBar = get_node_or_null("%SelectedO2Bar")
@onready var selected_co2_label: Label = get_node_or_null("%SelectedCO2Label")
@onready var selected_pressure_label: Label = get_node_or_null("%SelectedPressureLabel")
@onready var selected_temp_label: Label = get_node_or_null("%SelectedTempLabel")

@onready var btn_toggle_seal: Button = get_node_or_null("%BtnToggleSeal")
@onready var btn_suppress_fire: Button = get_node_or_null("%BtnSuppressFire")
@onready var btn_toggle_vent: Button = get_node_or_null("%BtnToggleVent")
@onready var btn_normalize_atmo: Button = get_node_or_null("%BtnNormalizeAtmo")
@onready var btn_seal_all: Button = get_node_or_null("%BtnSealAll")
@onready var btn_suppress_all: Button = get_node_or_null("%BtnSuppressAll")
@onready var scrubber_slider: HSlider = get_node_or_null("%ScrubberSlider")
@onready var scrubber_value_label: Label = get_node_or_null("%ScrubberValueLabel")

@onready var status_label: Label = get_node_or_null("%StatusLabel")
@onready var total_o2_label: Label = get_node_or_null("%TotalO2Label")
@onready var avg_pressure_label: Label = get_node_or_null("%AvgPressureLabel")
@onready var active_alarms_label: Label = get_node_or_null("%ActiveAlarmsLabel")

# --- CONFIGURAZIONE RUNTIME (.DAT) ---
var active_config: Dictionary = {
	"app_name": "LifeSupportApp",
	"version": "1.0.0",
	"status": "OPERATIONAL",
	"o2_generation_rate": 1.2,
	"seal_door_speed": 0.5,
	"auto_fire_suppress": false,
	"decompression_rate": 1.8,
	"fire_suppression_co2_level": 0.45,
	"scrubber_efficiency": 0.98,
	"is_dat_loaded": false
}

# --- STATO INTERNO ---
var can_control_life_support: bool = false
var is_life_support_powered: bool = true
var rooms_state: Dictionary = {}
var room_card_widgets: Dictionary = {}
var selected_room_id: String = ""
var global_scrubber_setting: float = 1.0
var _room_anomalies: Dictionary = {}

var rooms: Array = [
	{"id": "bridge", "name": "Ponte di Comando", "category": "Command", "rect": Rect2(260, 40, 80, 50), "color": Color(0.15, 0.35, 0.55, 0.65), "border_color": Color(0.3, 0.7, 1.0, 0.9)},
	{"id": "sensors", "name": "Sensori & Scanner", "category": "Sensors", "rect": Rect2(160, 80, 75, 45), "color": Color(0.15, 0.4, 0.45, 0.65), "border_color": Color(0.2, 0.8, 0.8, 0.9)},
	{"id": "comms", "name": "Comunicazioni", "category": "Comms", "rect": Rect2(365, 80, 75, 45), "color": Color(0.2, 0.35, 0.5, 0.65), "border_color": Color(0.4, 0.6, 0.9, 0.9)},
	{"id": "life_support", "name": "Supporto Vitale", "category": "LifeSupport", "rect": Rect2(170, 155, 85, 55), "color": Color(0.15, 0.45, 0.3, 0.65), "border_color": Color(0.3, 0.9, 0.5, 0.9)},
	{"id": "shields", "name": "Generatore Scudi", "category": "Defense", "rect": Rect2(345, 155, 85, 55), "color": Color(0.25, 0.3, 0.55, 0.65), "border_color": Color(0.5, 0.6, 1.0, 0.9)},
	{"id": "corridor", "name": "Corridoio Centrale", "category": "Corridor", "rect": Rect2(275, 115, 50, 110), "color": Color(0.12, 0.2, 0.3, 0.65), "border_color": Color(0.3, 0.5, 0.7, 0.8)},
	{"id": "weapons", "name": "Controllo Armi", "category": "Tactical", "rect": Rect2(255, 245, 90, 50), "color": Color(0.45, 0.2, 0.2, 0.65), "border_color": Color(1.0, 0.4, 0.3, 0.9)},
	{"id": "engines", "name": "Sala Macchine & Motori", "category": "Engineering", "rect": Rect2(200, 315, 200, 75), "color": Color(0.4, 0.3, 0.15, 0.65), "border_color": Color(0.9, 0.6, 0.2, 0.9)}
]

var ducts: Array = [
	# Condotti principali asse Y
	{"from": Vector2(300, 90), "to": Vector2(300, 115), "width": 16.0, "name": "Condotto Dorsale Prua"},
	{"from": Vector2(300, 225), "to": Vector2(300, 245), "width": 16.0, "name": "Condotto Dorsale Centro"},
	{"from": Vector2(300, 295), "to": Vector2(300, 315), "width": 16.0, "name": "Condotto Dorsale Poppa"},
	
	# Condotti orizzontali asse X
	{"from": Vector2(235, 100), "to": Vector2(275, 140), "width": 14.0, "name": "Condotto Sensori"},
	{"from": Vector2(365, 100), "to": Vector2(325, 140), "width": 14.0, "name": "Condotto Comms"},
	{"from": Vector2(255, 180), "to": Vector2(275, 180), "width": 14.0, "name": "Condotto Life Support"},
	{"from": Vector2(325, 180), "to": Vector2(345, 180), "width": 14.0, "name": "Condotto Shields"},
	
	# Condotti di servizio ali esterne
	{"from": Vector2(170, 180), "to": Vector2(65, 250), "width": 12.0, "name": "Condotto Ala SX"},
	{"from": Vector2(430, 180), "to": Vector2(535, 250), "width": 12.0, "name": "Condotto Ala DX"},
	
	# Condotti laterali vano motori
	{"from": Vector2(160, 275), "to": Vector2(160, 350), "width": 14.0, "name": "Condotto Manutenzione SX"},
	{"from": Vector2(160, 350), "to": Vector2(185, 350), "width": 14.0, "name": "Accesso Motori SX"},
	{"from": Vector2(440, 275), "to": Vector2(440, 350), "width": 14.0, "name": "Condotto Manutenzione DX"},
	{"from": Vector2(440, 350), "to": Vector2(415, 350), "width": 14.0, "name": "Accesso Motori DX"},
	
	# Condotti di sfiato poppa
	{"from": Vector2(250, 400), "to": Vector2(250, 425), "width": 14.0, "name": "Sfiato Plasma 1"},
	{"from": Vector2(350, 400), "to": Vector2(350, 425), "width": 14.0, "name": "Sfiato Plasma 2"}
]

var hovered_room_id: String = ""
var _cached_active_damages: Array = []

func _ready() -> void:
	_configure_window(APP_TITLE, DEFAULT_WINDOW_SIZE, MIN_WINDOW_SIZE)
	_init_rooms_state()
	_connect_system_signals()
	_connect_ui_signals()
	load_dat_configuration()
	_update_connection_state()
	_update_permissions()
	_refresh_all_ui()
	if SpaceWorldManager and SpaceWorldManager.has_method("register_life_support_app"):
		SpaceWorldManager.register_life_support_app(self)

func _exit_tree() -> void:
	if SpaceWorldManager and SpaceWorldManager.has_method("unregister_life_support_app"):
		SpaceWorldManager.unregister_life_support_app(self)
	_disconnect_system_signals()

func _process(delta: float) -> void:
	if not _is_ship_operational():
		return
	
	_simulate_atmosphere_step(delta)
	_update_telemetry_ui()
	if map_canvas:
		map_canvas.queue_redraw()

func _is_ship_operational() -> bool:
	if SpaceWorldManager and SpaceWorldManager.has_method("is_ship_connected"):
		return SpaceWorldManager.is_ship_connected()
	var net_mgr := get_node_or_null("/root/NetworkManager")
	if net_mgr and "is_mission_active" in net_mgr:
		return bool(net_mgr.is_mission_active)
	return true

# --- SEGNALI DI SISTEMA E RBAC ---

func _connect_system_signals() -> void:
	if SpaceWorldManager and SpaceWorldManager.has_signal("ship_connection_changed"):
		if not SpaceWorldManager.ship_connection_changed.is_connected(_on_ship_connection_changed):
			SpaceWorldManager.ship_connection_changed.connect(_on_ship_connection_changed)
	
	if SpaceWorldManager and SpaceWorldManager.has_signal("ship_system_power_changed"):
		if not SpaceWorldManager.ship_system_power_changed.is_connected(_on_system_power_changed):
			SpaceWorldManager.ship_system_power_changed.connect(_on_system_power_changed)
	
	var net_mgr := get_node_or_null("/root/NetworkManager")
	if net_mgr:
		if net_mgr.has_signal("player_role_changed") and not net_mgr.player_role_changed.is_connected(_on_player_role_changed):
			net_mgr.player_role_changed.connect(_on_player_role_changed)
		if net_mgr.has_signal("mission_started") and not net_mgr.mission_started.is_connected(_on_mission_started):
			net_mgr.mission_started.connect(_on_mission_started)
		if net_mgr.has_signal("connection_state_changed") and not net_mgr.connection_state_changed.is_connected(_on_net_connection_state_changed):
			net_mgr.connection_state_changed.connect(_on_net_connection_state_changed)
	
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm:
		if sdm.has_signal("file_modified") and not sdm.file_modified.is_connected(_on_drive_file_modified):
			sdm.file_modified.connect(_on_drive_file_modified)
		if sdm.has_signal("file_synced") and not sdm.file_synced.is_connected(_on_drive_file_synced):
			sdm.file_synced.connect(_on_drive_file_synced)

func _disconnect_system_signals() -> void:
	if SpaceWorldManager and SpaceWorldManager.has_signal("ship_connection_changed"):
		if SpaceWorldManager.ship_connection_changed.is_connected(_on_ship_connection_changed):
			SpaceWorldManager.ship_connection_changed.disconnect(_on_ship_connection_changed)
	
	if SpaceWorldManager and SpaceWorldManager.has_signal("ship_system_power_changed"):
		if SpaceWorldManager.ship_system_power_changed.is_connected(_on_system_power_changed):
			SpaceWorldManager.ship_system_power_changed.disconnect(_on_system_power_changed)
	
	var net_mgr := get_node_or_null("/root/NetworkManager")
	if net_mgr:
		if net_mgr.has_signal("player_role_changed") and net_mgr.player_role_changed.is_connected(_on_player_role_changed):
			net_mgr.player_role_changed.disconnect(_on_player_role_changed)
		if net_mgr.has_signal("mission_started") and net_mgr.mission_started.is_connected(_on_mission_started):
			net_mgr.mission_started.disconnect(_on_mission_started)
		if net_mgr.has_signal("connection_state_changed") and net_mgr.connection_state_changed.is_connected(_on_net_connection_state_changed):
			net_mgr.connection_state_changed.disconnect(_on_net_connection_state_changed)
	
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm:
		if sdm.has_signal("file_modified") and sdm.file_modified.is_connected(_on_drive_file_modified):
			sdm.file_modified.disconnect(_on_drive_file_modified)
		if sdm.has_signal("file_synced") and sdm.file_synced.is_connected(_on_drive_file_synced):
			sdm.file_synced.disconnect(_on_drive_file_synced)

func _connect_ui_signals() -> void:
	if btn_reload_dat:
		btn_reload_dat.pressed.connect(_on_reload_dat_pressed)
	if btn_toggle_seal:
		btn_toggle_seal.pressed.connect(_on_toggle_seal_pressed)
	if btn_suppress_fire:
		btn_suppress_fire.pressed.connect(_on_suppress_fire_pressed)
	if btn_toggle_vent:
		btn_toggle_vent.pressed.connect(_on_toggle_vent_pressed)
	if btn_normalize_atmo:
		btn_normalize_atmo.pressed.connect(_on_normalize_atmo_pressed)
	if btn_seal_all:
		btn_seal_all.pressed.connect(_on_seal_all_pressed)
	if btn_suppress_all:
		btn_suppress_all.pressed.connect(_on_suppress_all_pressed)
	if scrubber_slider:
		scrubber_slider.value_changed.connect(_on_scrubber_slider_changed)

func _on_system_power_changed(category: String, is_powered: bool) -> void:
	if category == "life_support" or category == "all":
		is_life_support_powered = is_powered
		if not is_powered:
			# Power lost! Start emergency oxygen consumption logic or similar
			if status_badge:
				status_badge.text = "● EMERGENZA ENERGETICA"
				status_badge.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2, 1.0))
		else:
			_update_connection_state()

func is_power_supplied_to_room(room_id: String) -> bool:
	if not _is_ship_operational():
		return false
	if not is_life_support_powered:
		return false
	if SpaceWorldManager and SpaceWorldManager.has_method("get_ship_blueprint"):
		var bp := SpaceWorldManager.get_ship_blueprint()
		if bp:
			for r in bp.rooms:
				if r.id == room_id:
					return bool(r.is_on)
	return true

func _on_ship_connection_changed(is_connected: bool) -> void:
	_update_connection_state()
	if is_connected:
		load_dat_configuration()
		_refresh_all_ui()

func _update_connection_state() -> void:
	var connected := _is_ship_operational()
	if disconnected_overlay:
		disconnected_overlay.visible = not connected
	
	if status_badge:
		if connected:
			status_badge.text = "● SISTEMA ATTIVO"
			status_badge.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4, 1.0))
		else:
			status_badge.text = "● OFFLINE"
			status_badge.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25, 1.0))

func _on_player_role_changed(_peer_id: int, _new_role: String) -> void:
	_update_permissions()

func _on_mission_started() -> void:
	_update_connection_state()
	_update_permissions()
	_refresh_all_ui()

func _on_net_connection_state_changed(_is_connected: bool, _is_host: bool) -> void:
	_update_connection_state()
	_update_permissions()
	_refresh_all_ui()

func _update_permissions() -> void:
	var nm := get_node_or_null("/root/NetworkManager")
	var my_role := ""
	var is_solo := true
	
	if nm:
		if nm.has_method("get_local_player_role"):
			my_role = str(nm.get_local_player_role())
		elif "my_role" in nm:
			my_role = str(nm.my_role)
		if "is_solo_mode" in nm:
			is_solo = bool(nm.is_solo_mode)
		elif "is_multiplayer_active" in nm:
			is_solo = not bool(nm.is_multiplayer_active)
	
	# Matrice RBAC:
	# - Ingegnere, Capitano, Stagista, Solo Mode: Controllo Completo
	# - Pilota, Soldato, Hacker: Sola Visualizzazione
	var role_lower := my_role.to_lower().strip_edges()
	if not my_role.is_empty():
		can_control_life_support = role_lower in ["engineer", "ingegnere", "captain", "capitano", "stagista", "admin", "host"]
	else:
		can_control_life_support = is_solo
	
	if role_badge:
		var display_role := my_role if not my_role.is_empty() else ("SOLO MODE" if is_solo else "SPETTATORE")
		role_badge.text = "Ruolo: %s (%s)" % [display_role, "CONTROLLO TOTALE" if can_control_life_support else "SOLA LETTURA"]
		role_badge.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5, 1.0) if can_control_life_support else Color(0.9, 0.7, 0.2, 1.0))
	
	_update_controls_interactivity()

func _update_controls_interactivity() -> void:
	if btn_toggle_seal: btn_toggle_seal.disabled = not can_control_life_support
	if btn_suppress_fire: btn_suppress_fire.disabled = not can_control_life_support
	if btn_toggle_vent: btn_toggle_vent.disabled = not can_control_life_support
	if btn_normalize_atmo: btn_normalize_atmo.disabled = not can_control_life_support
	if btn_seal_all: btn_seal_all.disabled = not can_control_life_support
	if btn_suppress_all: btn_suppress_all.disabled = not can_control_life_support
	if scrubber_slider: scrubber_slider.editable = can_control_life_support
	
	for card in room_card_widgets.values():
		if card and card.has_method("set_controls_enabled"):
			card.set_controls_enabled(can_control_life_support)

# --- INIZIALIZZAZIONE E GESTIONE STANZE ---

func _infer_room_category(r_id: String) -> String:
	var cat := "Compartment"
	match r_id:
		"bridge": cat = "Command"
		"sensors": cat = "Sensors"
		"comms": cat = "Comms"
		"life_support": cat = "LifeSupport"
		"shields": cat = "Defense"
		"weapons": cat = "Tactical"
		"engines", "reactor_room": cat = "Engineering"
		"corridor", "tech_corridor": cat = "Corridor"
		"crew_quarters": cat = "Habitation"
		"drone_bay": cat = "Tech"
		"cargo_bay": cat = "Cargo"
	return cat

func _init_rooms_state() -> void:
	rooms_state.clear()
	var loaded_rooms: Array = []
	if SpaceWorldManager and SpaceWorldManager.has_method("get_duct_rooms"):
		var mgr_rooms: Array = SpaceWorldManager.get_duct_rooms()
		for r in mgr_rooms:
			if r is DuctRoomData:
				loaded_rooms.append({
					"id": r.id,
					"name": r.name,
					"rect": r.rect,
					"color": r.color,
					"border_color": r.border_color,
					"category": _infer_room_category(r.id)
				})
			elif r is Dictionary:
				loaded_rooms.append(r)
	
	if loaded_rooms.size() > 0:
		rooms = loaded_rooms
	
	if SpaceWorldManager and SpaceWorldManager.has_method("get_duct_corridors"):
		var mgr_ducts: Array = SpaceWorldManager.get_duct_corridors()
		if mgr_ducts.size() > 0:
			ducts.clear()
			for d in mgr_ducts:
				if d is ShipDuctData:
					ducts.append({
						"from": d.from,
						"to": d.to,
						"width": d.width,
						"name": d.name
					})
				elif d is Dictionary:
					ducts.append(d)

	for r in rooms:
		var r_id: String = str(r.get("id", ""))
		if r_id.is_empty(): continue
		rooms_state[r_id] = {
			"id": r_id,
			"name": str(r.get("name", "Stanza Ignota")),
			"category": str(r.get("category", _infer_room_category(r_id))),
			"rect": r.get("rect", Rect2()),
			"color": r.get("color", Color(0.15, 0.35, 0.55, 0.65)),
			"border_color": r.get("border_color", Color(0.3, 0.7, 1.0, 0.9)),
			"pressure_kpa": 101.3,
			"temperature_c": 21.5,
			"o2_pct": 21.0,
			"co2_pct": 0.04,
			"has_breach": false,
			"has_short_circuit": false,
			"heater_online": true,
			"is_fire_active": false,
			"is_smoke_active": false,
			"is_suppression_active": false,
			"suppression_timer": 0.0,
			"is_venting": false,
			"is_sealed": false
		}
	
	if SpaceWorldManager and "sealed_rooms" in SpaceWorldManager:
		for s_id in SpaceWorldManager.sealed_rooms:
			if rooms_state.has(s_id):
				rooms_state[s_id]["is_sealed"] = bool(SpaceWorldManager.sealed_rooms[s_id])

	if not rooms_state.is_empty() and (selected_room_id.is_empty() or not rooms_state.has(selected_room_id)):
		selected_room_id = str(rooms_state.keys()[0])
	
	_build_room_cards_ui()

func _build_room_cards_ui() -> void:
	if not room_cards_container:
		return
	
	for child in room_cards_container.get_children():
		child.queue_free()
	room_card_widgets.clear()
	
	var card_scene: PackedScene = load("res://Applications/LifeSupport/Components/room_atmo_card.tscn")
	if not card_scene:
		return
	
	for r_id in rooms_state:
		var card: RoomAtmoCard = card_scene.instantiate() as RoomAtmoCard
		card.setup(rooms_state[r_id])
		card.selected.connect(_on_room_card_selected)
		card.seal_toggled.connect(_on_room_card_seal_toggled)
		card.fire_suppressed.connect(_on_room_card_fire_suppressed)
		card.set_controls_enabled(can_control_life_support)
		room_cards_container.add_child(card)
		room_card_widgets[r_id] = card
	
	_update_selected_room_visuals()

# --- SIMULAZIONE DINAMICA ATMOSFERICA ---

func _simulate_atmosphere_step(delta: float) -> void:
	var o2_gen_rate: float = float(active_config.get("o2_generation_rate", 1.2))
	var decomp_rate: float = float(active_config.get("decompression_rate", 1.8))
	var auto_fire_suppress: bool = bool(active_config.get("auto_fire_suppress", false))
	var scrubber_eff: float = float(active_config.get("scrubber_efficiency", 0.98))
	var fire_supp_co2: float = float(active_config.get("fire_suppression_co2_level", 0.45))
	
	# Verifica danni da SpaceWorldManager
	var active_damages: Array = []
	if SpaceWorldManager:
		if SpaceWorldManager.has_method("get_active_ship_damages"):
			var rt_damages := SpaceWorldManager.get_active_ship_damages()
			for d in rt_damages:
				active_damages.append({
					"pos": d.pos,
					"type": d.type,
					"id": d.id,
					"sector": d.sector
				})
		if active_damages.is_empty() and SpaceWorldManager.has_method("get_damage_zones"):
			var mgr_damages := SpaceWorldManager.get_damage_zones()
			for d in mgr_damages:
				if d is ShipDamageData:
					if not d.repaired:
						active_damages.append({
							"pos": d.pos,
							"type": d.type,
							"id": d.id,
							"sector": d.sector
						})
				elif d is Dictionary:
					if not d.get("repaired", false):
						active_damages.append(d)
	
	_cached_active_damages = active_damages
	
	var has_swm_damages := (SpaceWorldManager != null and (
		(SpaceWorldManager.has_method("get_ship_damages") and SpaceWorldManager.get_ship_damages().size() > 0) or
		(SpaceWorldManager.has_method("get_damage_zones") and SpaceWorldManager.get_damage_zones().size() > 0)
	))

	for r_id in rooms_state:
		var state: Dictionary = rooms_state[r_id]
		var r_rect: Rect2 = state.get("rect", Rect2())
		
		# Calcolo stato brecce, corti e incendi
		var breach_present := false
		var short_present := false
		var fire_present := false
		for dmg in active_damages:
			var d_pos: Vector2 = dmg.get("pos", Vector2.ZERO)
			var d_type: String = str(dmg.get("type", ""))
			var d_sector: String = str(dmg.get("sector", ""))
			var in_room: bool = (r_rect.has_point(d_pos) and r_rect.size != Vector2.ZERO) or (not d_sector.is_empty() and (d_sector == state.get("name", "") or d_sector == r_id))
			if in_room:
				if d_type.begins_with("dmg_breach") or d_type == "STRUCTURAL" or d_type == "breach" or (SpaceWorldManager and d_type == SpaceWorldManager.DAMAGE_TYPE_BREACH):
					breach_present = true
				if d_type.begins_with("dmg_short") or d_type == "ELECTRICAL" or d_type == "short_circuit" or (SpaceWorldManager and d_type == SpaceWorldManager.DAMAGE_TYPE_SHORT_CIRCUIT):
					short_present = true
				if d_type.begins_with("dmg_fire") or d_type == "FIRE" or d_type == "fire" or (SpaceWorldManager and d_type == SpaceWorldManager.DAMAGE_TYPE_FIRE):
					fire_present = true
		
		if breach_present:
			state["has_breach"] = true
		if short_present:
			state["has_short_circuit"] = true
		if fire_present:
			state["is_fire_active"] = true
		
		# Calcolo stato caldaia: heater_online
		state["heater_online"] = not state["has_short_circuit"] and is_power_supplied_to_room(r_id)
		
		# Gestione timer iniezione soppressione gas inerte
		if state["is_suppression_active"]:
			state["suppression_timer"] -= delta
			state["is_fire_active"] = false
			state["is_smoke_active"] = false
			state["co2_pct"] = move_toward(state["co2_pct"], fire_supp_co2, delta * 0.1)
			if state["suppression_timer"] <= 0.0:
				state["is_suppression_active"] = false
		
		# Incendio attivo
		if state["is_fire_active"]:
			state["is_smoke_active"] = true
			if auto_fire_suppress and not state["is_suppression_active"]:
				trigger_fire_suppression(r_id)
		
		# Dinamica Decompressione (Breccia o Venting) vs Pressurizzazione
		if state["has_breach"] or state["is_venting"]:
			var rate_mult: float = decomp_rate * (1.5 if state["has_breach"] else 1.0)
			state["pressure_kpa"] = move_toward(state["pressure_kpa"], 0.0, delta * 25.0 * rate_mult)
			state["o2_pct"] = move_toward(state["o2_pct"], 0.0, delta * 15.0 * rate_mult)
			# Nel vuoto o senza ossigeno l'incendio soffoca
			if state["o2_pct"] < 6.0 or state["pressure_kpa"] < 10.0:
				state["is_fire_active"] = false
		else:
			# Pressurizzazione e rigenerazione normale
			if not state["is_suppression_active"]:
				state["pressure_kpa"] = move_toward(state["pressure_kpa"], 101.3, delta * 4.0)
				if not state["is_fire_active"]:
					state["o2_pct"] = move_toward(state["o2_pct"], 21.0, delta * o2_gen_rate * 0.5)
				
				# Scrubber CO2
				var scrub_rate := delta * 0.08 * scrubber_eff * global_scrubber_setting
				state["co2_pct"] = move_toward(state["co2_pct"], 0.04, scrub_rate)
				if state["co2_pct"] <= 0.1 and not state["is_fire_active"]:
					state["is_smoke_active"] = false
		
		# Se c'è incendio e c'è ancora pressione/combustibile
		if state["is_fire_active"]:
			state["o2_pct"] = move_toward(state["o2_pct"], 0.0, delta * 4.0)
			state["co2_pct"] = move_toward(state["co2_pct"], 3.5, delta * 0.4)
		
		# DINAMICA DELLA TEMPERATURA:
		# 1. Nel vuoto (pressione <= 1.0 kPa), la temperatura decade rapidamente e incondizionatamente verso 0.0 °C
		if state["pressure_kpa"] <= 1.0:
			state["temperature_c"] = move_toward(state["temperature_c"], 0.0, delta * 30.0)
		# 2. Incendio attivo porta la temperatura a picchi critici (420.0 °C)
		elif state["is_fire_active"]:
			state["temperature_c"] = move_toward(state["temperature_c"], 420.0, delta * 35.0)
		# 3. Soppressione gas inerte raffredda a 18.0 °C
		elif state["is_suppression_active"]:
			state["temperature_c"] = move_toward(state["temperature_c"], 18.0, delta * 15.0)
		# 4. Riscaldamento normale con caldaia online verso 21.5 °C
		elif state["heater_online"]:
			state["temperature_c"] = move_toward(state["temperature_c"], 21.5, delta * 1.5)
		# 5. Caldaia spenta / corto circuito -> raffreddamento progressivo verso 0.0 °C
		else:
			state["temperature_c"] = move_toward(state["temperature_c"], 0.0, delta * 0.8)
		
		_check_and_emit_room_anomalies(r_id, state)

func _check_and_emit_room_anomalies(r_id: String, state: Dictionary) -> void:
	if not _room_anomalies.has(r_id):
		_room_anomalies[r_id] = {}
	var prev_anomalies: Dictionary = _room_anomalies[r_id]
	var current_anomalies: Dictionary = {}
	
	if bool(state.get("is_fire_active", false)):
		current_anomalies["FIRE"] = true
	if bool(state.get("has_breach", false)):
		current_anomalies["BREACH"] = true
	if bool(state.get("has_short_circuit", false)):
		current_anomalies["SHORT_CIRCUIT"] = true
	if float(state.get("pressure_kpa", 101.3)) < 50.0:
		current_anomalies["DECOMPRESSION"] = true
	if float(state.get("o2_pct", 21.0)) < 18.0:
		current_anomalies["HYPOXIA"] = true
	if float(state.get("temperature_c", 21.5)) < 10.0:
		current_anomalies["FREEZING"] = true
	elif float(state.get("temperature_c", 21.5)) > 40.0:
		current_anomalies["OVERHEAT"] = true
	
	for anomaly in current_anomalies:
		if not prev_anomalies.has(anomaly):
			atmosphere_anomaly_detected.emit(r_id, anomaly)
	
	_room_anomalies[r_id] = current_anomalies

# --- METODI PUBBLICI / CONTROLLO ATMOSFERA ---

func get_room_atmo_state(room_id: String) -> Dictionary:
	if rooms_state.has(room_id):
		return rooms_state[room_id].duplicate()
	return {}

func get_all_rooms_atmo_state() -> Dictionary:
	return rooms_state.duplicate(true)

func set_room_breach(room_id: String, has_breach: bool) -> void:
	if not rooms_state.has(room_id):
		return
	rooms_state[room_id]["has_breach"] = has_breach
	if room_card_widgets.has(room_id):
		room_card_widgets[room_id].update_telemetry(rooms_state[room_id])
	_update_selected_room_ui()

func set_room_short_circuit(room_id: String, has_short: bool) -> void:
	if not rooms_state.has(room_id):
		return
	rooms_state[room_id]["has_short_circuit"] = has_short
	rooms_state[room_id]["heater_online"] = not has_short and is_power_supplied_to_room(room_id)
	if room_card_widgets.has(room_id):
		room_card_widgets[room_id].update_telemetry(rooms_state[room_id])
	_update_selected_room_ui()

func set_room_fire(room_id: String, is_fire: bool) -> void:
	if not rooms_state.has(room_id):
		return
	rooms_state[room_id]["is_fire_active"] = is_fire
	if is_fire:
		rooms_state[room_id]["is_smoke_active"] = true
	if room_card_widgets.has(room_id):
		room_card_widgets[room_id].update_telemetry(rooms_state[room_id])
	_update_selected_room_ui()

func set_bulkhead_sealed(room_id: String, sealed: bool) -> void:
	if not rooms_state.has(room_id):
		return
	rooms_state[room_id]["is_sealed"] = sealed
	if SpaceWorldManager:
		SpaceWorldManager.sealed_rooms[room_id] = sealed
	if room_card_widgets.has(room_id):
		room_card_widgets[room_id].update_telemetry(rooms_state[room_id])
	_update_selected_room_ui()

func get_sealed_rooms() -> Array:
	var list: Array = []
	for r_id in rooms_state:
		if rooms_state[r_id].get("is_sealed", false):
			list.append(rooms_state[r_id])
	return list

func is_room_sealed(room_id: String) -> bool:
	if rooms_state.has(room_id):
		return bool(rooms_state[room_id].get("is_sealed", false))
	return false

func trigger_fire_suppression(room_id: String) -> void:
	if not rooms_state.has(room_id):
		return
	var state: Dictionary = rooms_state[room_id]
	state["is_suppression_active"] = true
	state["suppression_timer"] = 5.0
	state["is_fire_active"] = false
	if room_card_widgets.has(room_id):
		room_card_widgets[room_id].update_telemetry(state)
	_update_selected_room_ui()

func set_room_venting(room_id: String, venting: bool) -> void:
	if not rooms_state.has(room_id):
		return
	rooms_state[room_id]["is_venting"] = venting
	_update_selected_room_ui()

func normalize_room_atmosphere(room_id: String) -> void:
	if not rooms_state.has(room_id):
		return
	var state: Dictionary = rooms_state[room_id]
	state["is_suppression_active"] = false
	state["suppression_timer"] = 0.0
	state["is_venting"] = false
	state["is_fire_active"] = false
	state["is_smoke_active"] = false
	state["has_breach"] = false
	state["has_short_circuit"] = false
	state["heater_online"] = is_power_supplied_to_room(room_id)
	state["o2_pct"] = 21.0
	state["co2_pct"] = 0.04
	state["pressure_kpa"] = 101.3
	state["temperature_c"] = 21.5
	if room_card_widgets.has(room_id):
		room_card_widgets[room_id].update_telemetry(state)
	_update_selected_room_ui()

func seal_all_bulkheads() -> void:
	for r_id in rooms_state:
		rooms_state[r_id]["is_sealed"] = true
		if SpaceWorldManager:
			SpaceWorldManager.sealed_rooms[r_id] = true
	_refresh_all_ui()

func suppress_all_fires() -> void:
	for r_id in rooms_state:
		trigger_fire_suppression(r_id)
	_refresh_all_ui()

# --- CALLBACK UI ---

func _on_room_card_selected(room_id: String) -> void:
	select_room(room_id)

func select_room(room_id: String) -> void:
	if not rooms_state.has(room_id):
		return
	selected_room_id = room_id
	_update_selected_room_visuals()
	_update_selected_room_ui()
	if map_canvas:
		map_canvas.queue_redraw()

func _on_room_card_seal_toggled(room_id: String, is_sealed: bool) -> void:
	set_bulkhead_sealed(room_id, is_sealed)

func _on_room_card_fire_suppressed(room_id: String) -> void:
	trigger_fire_suppression(room_id)

func _on_toggle_seal_pressed() -> void:
	if not can_control_life_support or not rooms_state.has(selected_room_id):
		return
	var current_sealed: bool = bool(rooms_state[selected_room_id].get("is_sealed"))
	set_bulkhead_sealed(selected_room_id, not current_sealed)

func _on_suppress_fire_pressed() -> void:
	if not can_control_life_support or not rooms_state.has(selected_room_id):
		return
	trigger_fire_suppression(selected_room_id)

func _on_toggle_vent_pressed() -> void:
	if not can_control_life_support or not rooms_state.has(selected_room_id):
		return
	var current_vent: bool = bool(rooms_state[selected_room_id].get("is_venting", false))
	set_room_venting(selected_room_id, not current_vent)

func _on_normalize_atmo_pressed() -> void:
	if not can_control_life_support or not rooms_state.has(selected_room_id):
		return
	normalize_room_atmosphere(selected_room_id)

func _on_seal_all_pressed() -> void:
	if not can_control_life_support:
		return
	seal_all_bulkheads()

func _on_suppress_all_pressed() -> void:
	if not can_control_life_support:
		return
	suppress_all_fires()

func _on_scrubber_slider_changed(value: float) -> void:
	global_scrubber_setting = value / 100.0
	if scrubber_value_label:
		scrubber_value_label.text = "Regolazione Scrubber: %.0f%%" % value

func _on_reload_dat_pressed() -> void:
	load_dat_configuration()
	_refresh_all_ui()

# --- REFRESH UI & TELEMETRIA ---

func _update_selected_room_visuals() -> void:
	for r_id in room_card_widgets:
		var card: RoomAtmoCard = room_card_widgets[r_id]
		if card:
			card.set_selected_visual(r_id == selected_room_id)
	if map_canvas:
		map_canvas.queue_redraw()

func _update_selected_room_ui() -> void:
	if not rooms_state.has(selected_room_id):
		return
	var st: Dictionary = rooms_state[selected_room_id]
	
	if selected_room_title:
		selected_room_title.text = "%s [%s]" % [st.get("name", selected_room_id), st.get("category", "Stanza")]
	
	var o2: float = float(st.get("o2_pct", 21.0))
	var co2: float = float(st.get("co2_pct", 0.04))
	var pres: float = float(st.get("pressure_kpa", 101.3))
	var tmp: float = float(st.get("temperature_c", 21.5))
	var is_sealed: bool = bool(st.get("is_sealed", false))
	var is_vent: bool = bool(st.get("is_venting", false))
	var is_fire: bool = bool(st.get("is_fire_active", false))
	var is_smoke: bool = bool(st.get("is_smoke_active", false))
	var is_supp: bool = bool(st.get("is_suppression_active", false))
	var has_br: bool = bool(st.get("has_breach", false))
	var has_short: bool = bool(st.get("has_short_circuit", false))
	var heater_on: bool = bool(st.get("heater_online", true))
	
	if selected_o2_label: selected_o2_label.text = "Livello O2: %.1f%%" % o2
	if selected_o2_bar:
		selected_o2_bar.value = o2
		if o2 < 16.0 or o2 > 26.0:
			selected_o2_bar.modulate = Color(0.95, 0.25, 0.25, 1.0)
		elif o2 < 19.0:
			selected_o2_bar.modulate = Color(0.95, 0.75, 0.2, 1.0)
		else:
			selected_o2_bar.modulate = Color(0.2, 0.85, 0.95, 1.0)
	
	if selected_co2_label: selected_co2_label.text = "CO2: %.2f%%" % co2
	if selected_pressure_label:
		selected_pressure_label.text = "Pressione: %.1f kPa (%.2f atm)" % [pres, pres / 101.3]
		if pres < 50.0:
			selected_pressure_label.add_theme_color_override("font_color", Color(0.95, 0.2, 0.2, 1.0))
		elif pres < 90.0:
			selected_pressure_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2, 1.0))
		else:
			selected_pressure_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.9, 1.0))
	
	if selected_temp_label:
		selected_temp_label.text = "Temperatura: %.1f°C (%s)" % [tmp, "Caldaia ON" if heater_on else ("CORTO" if has_short else "Caldaia OFF")]
		if tmp < 10.0:
			selected_temp_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0, 1.0))
		elif tmp > 40.0:
			selected_temp_label.add_theme_color_override("font_color", Color(0.95, 0.2, 0.2, 1.0))
		elif tmp >= 18.0 and tmp <= 24.0:
			selected_temp_label.add_theme_color_override("font_color", Color(0.2, 0.85, 0.4, 1.0))
		else:
			selected_temp_label.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2, 1.0))
	
	if selected_room_status:
		if is_fire:
			selected_room_status.text = "🔥 ALLARME INCENDIO ATTIVO"
			selected_room_status.add_theme_color_override("font_color", Color(0.95, 0.3, 0.1, 1.0))
		elif has_br:
			selected_room_status.text = "🚨 ALLARME BRECCIA SCAFO ATTIVA"
			selected_room_status.add_theme_color_override("font_color", Color(0.95, 0.2, 0.2, 1.0))
		elif pres < 50.0:
			selected_room_status.text = "⚡ ALLARME DECOMPRESSIONE (VUOTO)"
			selected_room_status.add_theme_color_override("font_color", Color(0.95, 0.2, 0.2, 1.0))
		elif has_short:
			selected_room_status.text = "⚡ CORTO CIRCUITO CALDAIA / CAVI"
			selected_room_status.add_theme_color_override("font_color", Color(0.95, 0.6, 0.2, 1.0))
		elif is_supp:
			selected_room_status.text = "💨 INIEZIONE AZOTO / SOPPRESSIONE IN CORSO"
			selected_room_status.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0, 1.0))
		elif is_smoke:
			selected_room_status.text = "🌫️ FUMO RILEVATO NEI CONDOTTI"
			selected_room_status.add_theme_color_override("font_color", Color(0.95, 0.7, 0.2, 1.0))
		elif is_sealed:
			selected_room_status.text = "🚪 PARATIA STAGNA SIGILLATA"
			selected_room_status.add_theme_color_override("font_color", Color(0.85, 0.6, 0.9, 1.0))
		elif o2 < 18.0:
			selected_room_status.text = "⚠️ ALLARME IPOSSIA (O2 < 18%)"
			selected_room_status.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2, 1.0))
		elif tmp < 10.0:
			selected_room_status.text = "❄️ ALLARME IPOTERMIA (T < 10°C)"
			selected_room_status.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0, 1.0))
		elif tmp > 40.0:
			selected_room_status.text = "🔥 ALLARME SOVRATEMPERATURA (T > 40°C)"
			selected_room_status.add_theme_color_override("font_color", Color(0.95, 0.3, 0.1, 1.0))
		else:
			selected_room_status.text = "● PARAMETRI AMBIENTALI OTTIMALI"
			selected_room_status.add_theme_color_override("font_color", Color(0.2, 0.85, 0.4, 1.0))
	
	if btn_toggle_seal:
		btn_toggle_seal.text = "🔓 Apri Paratia" if is_sealed else "🚪 Sigilla Paratia"
	if btn_toggle_vent:
		btn_toggle_vent.text = "⏹ Ferma Evacuazione" if is_vent else "💨 Evacua Atmosfera"
	
	if map_canvas:
		map_canvas.queue_redraw()

func _update_telemetry_ui() -> void:
	var total_o2 := 0.0
	var total_press := 0.0
	var alarms_count := 0
	var count := rooms_state.size()
	
	for r_id in rooms_state:
		var st: Dictionary = rooms_state[r_id]
		var o2: float = float(st.get("o2_pct", 21.0))
		var pr: float = float(st.get("pressure_kpa", 101.3))
		var tmp: float = float(st.get("temperature_c", 21.5))
		total_o2 += o2
		total_press += pr
		
		if bool(st.get("is_fire_active")) or bool(st.get("has_breach")) or bool(st.get("has_short_circuit")) or o2 < 18.0 or pr < 80.0 or tmp < 10.0 or tmp > 40.0:
			alarms_count += 1
		
		if room_card_widgets.has(r_id):
			room_card_widgets[r_id].update_telemetry(st)
	
	var avg_o2 := total_o2 / maxf(float(count), 1.0)
	var avg_p := total_press / maxf(float(count), 1.0)
	
	if total_o2_label:
		total_o2_label.text = "O2 Medio: %.1f%%" % avg_o2
		if avg_o2 < 18.0:
			total_o2_label.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25, 1.0))
		else:
			total_o2_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.9, 1.0))
	
	if avg_pressure_label:
		avg_pressure_label.text = "Pressione Media: %.1f kPa" % avg_p
		if avg_p < 80.0:
			avg_pressure_label.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25, 1.0))
		else:
			avg_pressure_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.9, 1.0))
	
	if active_alarms_label:
		if alarms_count > 0:
			active_alarms_label.text = "⚠️ ALLARMI: %d" % alarms_count
			active_alarms_label.add_theme_color_override("font_color", Color(0.95, 0.25, 0.25, 1.0))
		else:
			active_alarms_label.text = "● NESSUN ALLARME"
			active_alarms_label.add_theme_color_override("font_color", Color(0.2, 0.85, 0.4, 1.0))
	
	if status_label:
		status_label.text = "Supporto Vitale: %s | Assorbimento: %.0f MW" % [
			"OPERATIVO" if alarms_count == 0 else "ATTENZIONE",
			BASE_POWER_MW
		]
	
	_update_selected_room_ui()

func _refresh_all_ui() -> void:
	_update_permissions()
	_update_selected_room_visuals()
	_update_telemetry_ui()

# --- PARSING E HOT-RELOADING .DAT ---

func load_dat_configuration() -> void:
	var parsed_config := _parse_dat_file(CONFIG_PATH_PRIMARY)
	if parsed_config.is_empty():
		parsed_config = _parse_dat_file(CONFIG_PATH_FALLBACK)
	
	var parsed_tuning := _parse_dat_file(TUNING_PATH_PRIMARY)
	if parsed_tuning.is_empty():
		parsed_tuning = _parse_dat_file(TUNING_PATH_FALLBACK)
	
	if not parsed_config.is_empty() or not parsed_tuning.is_empty():
		for k in parsed_config:
			active_config[k] = parsed_config[k]
		for k in parsed_tuning:
			active_config[k] = parsed_tuning[k]
		active_config["is_dat_loaded"] = true
	else:
		active_config["is_dat_loaded"] = false
	
	_apply_configuration()

func _apply_configuration() -> void:
	if dat_status_badge:
		if active_config.get("is_dat_loaded", false):
			dat_status_badge.text = "DAT: SINCRO (100%)"
			dat_status_badge.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4, 1.0))
		else:
			dat_status_badge.text = "DAT: DEFAULT"
			dat_status_badge.add_theme_color_override("font_color", Color(0.95, 0.75, 0.2, 1.0))

func _on_drive_file_modified(rel_path: String) -> void:
	if "LifeSupport" in rel_path and rel_path.ends_with(".dat"):
		load_dat_configuration()

func _on_drive_file_synced(rel_path: String, _content: String = "") -> void:
	if "LifeSupport" in rel_path and rel_path.ends_with(".dat"):
		load_dat_configuration()

# --- RENDERING BLUEPRINT & CONTROLLO MAPPA ---

func draw_blueprint(canvas: Control) -> void:
	if canvas == null:
		return
	var canvas_size: Vector2 = canvas.size
	var scale_factor: float = minf(canvas_size.x / BLUEPRINT_SIZE.x, canvas_size.y / BLUEPRINT_SIZE.y)
	if scale_factor <= 0.001:
		scale_factor = 1.0
	var offset: Vector2 = (canvas_size - BLUEPRINT_SIZE * scale_factor) * 0.5
	var trans := Transform2D().translated(offset).scaled(Vector2(scale_factor, scale_factor))
	
	_draw_blueprint_grid(canvas, trans)
	_draw_ship_hull(canvas, trans)
	_draw_ducts(canvas, trans)
	_draw_rooms(canvas, trans)
	_draw_damages(canvas, trans)

func _draw_blueprint_grid(canvas: Control, trans: Transform2D) -> void:
	var grid_color := Color(0.08, 0.16, 0.25, 0.4)
	var step := 30.0
	
	for x in range(0, int(BLUEPRINT_SIZE.x), int(step)):
		var p1 := trans * Vector2(x, 0)
		var p2 := trans * Vector2(x, BLUEPRINT_SIZE.y)
		canvas.draw_line(p1, p2, grid_color, 1.0)
	
	for y in range(0, int(BLUEPRINT_SIZE.y), int(step)):
		var p1 := trans * Vector2(0, y)
		var p2 := trans * Vector2(BLUEPRINT_SIZE.x, y)
		canvas.draw_line(p1, p2, grid_color, 1.0)

func _draw_ship_hull(canvas: Control, trans: Transform2D) -> void:
	var hull_points: PackedVector2Array = [
		Vector2(300, 20),   # Prua / Muso Cockpit
		Vector2(340, 45),
		Vector2(400, 70),   # Ala Comms
		Vector2(500, 110),
		Vector2(510, 170),
		Vector2(490, 200),
		Vector2(580, 225),  # Ala Esterna RCS DX
		Vector2(580, 300),
		Vector2(510, 305),
		Vector2(430, 310),  # Inizio Motori DX
		Vector2(420, 410),  # Propulsore DX
		Vector2(350, 425),  # Ugello Centrale DX
		Vector2(300, 430),  # Poppa Centro
		Vector2(250, 425),  # Ugello Centrale SX
		Vector2(180, 410),  # Propulsore SX
		Vector2(170, 310),  # Inizio Motori SX
		Vector2(90, 305),
		Vector2(20, 300),   # Ala Esterna RCS SX
		Vector2(20, 225),
		Vector2(110, 200),
		Vector2(90, 170),
		Vector2(100, 110),
		Vector2(200, 70),   # Ala Sensori
		Vector2(260, 45)
	]
	
	var transformed_hull: PackedVector2Array = []
	for pt in hull_points:
		transformed_hull.push_back(trans * pt)
	
	canvas.draw_colored_polygon(transformed_hull, Color(0.04, 0.08, 0.14, 0.85))
	
	for i in range(transformed_hull.size()):
		var p1: Variant = transformed_hull[i]
		var p2: Variant = transformed_hull[(i + 1) % transformed_hull.size()]
		canvas.draw_line(p1, p2, Color(0.25, 0.55, 0.85, 0.8), 2.0)

func _draw_ducts(canvas: Control, trans: Transform2D) -> void:
	for duct in ducts:
		var from_pos: Vector2 = duct["from"]
		var to_pos: Vector2 = duct["to"]
		var p1: Vector2 = trans * from_pos
		var p2: Vector2 = trans * to_pos
		var w: float = float(duct.get("width", 14.0)) * trans.get_scale().x
		
		canvas.draw_line(p1, p2, Color(0.08, 0.22, 0.28, 0.95), w)
		canvas.draw_line(p1, p2, Color(0.2, 0.8, 0.9, 0.75), w, false)
		canvas.draw_line(p1, p2, Color(0.4, 1.0, 0.9, 0.4), 1.5)
		
		canvas.draw_circle(p1, w * 0.45, Color(0.25, 0.85, 1.0, 0.9))
		canvas.draw_circle(p2, w * 0.45, Color(0.25, 0.85, 1.0, 0.9))

func _draw_rooms(canvas: Control, trans: Transform2D) -> void:
	var font: Font = ThemeDB.fallback_font
	var time_now := Time.get_ticks_msec() * 0.003
	var s: float = trans.get_scale().x
	
	for room in rooms:
		var r_id: String = str(room.get("id", ""))
		var r: Rect2 = room.get("rect", Rect2())
		if r.size == Vector2.ZERO:
			continue
		var p1 := trans * r.position
		var p2 := trans * (r.position + r.size)
		var tr_rect := Rect2(p1, p2 - p1)
		
		var st: Dictionary = rooms_state.get(r_id, {})
		var is_selected: bool = (r_id == selected_room_id)
		var is_hovered: bool = (r_id == hovered_room_id)
		var is_sealed: bool = bool(st.get("is_sealed", false))
		var is_fire: bool = bool(st.get("is_fire_active", false))
		var is_vent: bool = bool(st.get("is_venting", false))
		var is_supp: bool = bool(st.get("is_suppression_active", false))
		var has_br: bool = bool(st.get("has_breach", false))
		var has_short: bool = bool(st.get("has_short_circuit", false))
		var o2: float = float(st.get("o2_pct", 21.0))
		var pres: float = float(st.get("pressure_kpa", 101.3))
		
		# Sfondo stanza dinamico in base allo stato
		var fill_color: Color = room.get("color", Color(0.15, 0.35, 0.55, 0.65))
		if is_fire:
			fill_color = Color(0.75, 0.2, 0.1, 0.6 + 0.2 * sin(time_now * 6.0))
		elif has_br or pres < 50.0:
			fill_color = Color(0.6, 0.1, 0.35, 0.55 + 0.2 * sin(time_now * 4.0))
		elif is_vent:
			fill_color = Color(0.1, 0.45, 0.65, 0.5 + 0.15 * sin(time_now * 5.0))
		elif is_supp:
			fill_color = Color(0.2, 0.5, 0.7, 0.5)
		elif is_sealed:
			fill_color = Color(0.4, 0.12, 0.15, 0.65)
		
		if is_hovered:
			fill_color = fill_color.lightened(0.18)
		if is_selected:
			fill_color = fill_color.lightened(0.1)
		
		canvas.draw_rect(tr_rect, fill_color, true)
		
		# Bordo stanza
		if is_sealed:
			_draw_sealed_bulkhead_border(canvas, tr_rect, s)
		elif is_fire:
			var border_pulse := 0.7 + 0.3 * sin(time_now * 6.0)
			canvas.draw_rect(tr_rect, Color(1.0, 0.35, 0.1, border_pulse), false, 2.0 * s)
		elif has_br:
			var border_pulse := 0.7 + 0.3 * sin(time_now * 5.0)
			canvas.draw_rect(tr_rect, Color(1.0, 0.2, 0.2, border_pulse), false, 2.0 * s)
		else:
			var bcol: Color = room.get("border_color", Color(0.3, 0.7, 1.0, 0.8))
			canvas.draw_rect(tr_rect, bcol, false, 1.5 * s)
		
		# Evidenziazione Stanza Selezionata
		if is_selected:
			var sel_color := Color(0.2, 0.9, 1.0, 0.95)
			var corner_len := minf(tr_rect.size.x, tr_rect.size.y) * 0.25
			canvas.draw_rect(tr_rect.grow(2.0 * s), sel_color, false, 2.0 * s)
			var tl := tr_rect.position - Vector2(2, 2) * s
			var tr := Vector2(tr_rect.position.x + tr_rect.size.x, tr_rect.position.y) + Vector2(2, -2) * s
			var bl := Vector2(tr_rect.position.x, tr_rect.position.y + tr_rect.size.y) + Vector2(-2, 2) * s
			var br := tr_rect.position + tr_rect.size + Vector2(2, 2) * s
			canvas.draw_line(tl, tl + Vector2(corner_len, 0), Color.WHITE, 2.5 * s)
			canvas.draw_line(tl, tl + Vector2(0, corner_len), Color.WHITE, 2.5 * s)
			canvas.draw_line(tr, tr - Vector2(corner_len, 0), Color.WHITE, 2.5 * s)
			canvas.draw_line(tr, tr + Vector2(0, corner_len), Color.WHITE, 2.5 * s)
			canvas.draw_line(bl, bl + Vector2(corner_len, 0), Color.WHITE, 2.5 * s)
			canvas.draw_line(bl, bl - Vector2(0, corner_len), Color.WHITE, 2.5 * s)
			canvas.draw_line(br, br - Vector2(corner_len, 0), Color.WHITE, 2.5 * s)
			canvas.draw_line(br, br - Vector2(0, corner_len), Color.WHITE, 2.5 * s)
		elif is_hovered:
			canvas.draw_rect(tr_rect, Color(0.7, 0.9, 1.0, 0.4), false, 1.5 * s)
		
		# Testo nome e parametri stanza
		var room_name: String = str(st.get("name", room.get("name", r_id)))
		var title_col: Color = Color(1.0, 0.9, 0.3, 1.0) if is_selected else Color(0.9, 0.95, 1.0, 0.95)
		var text_pos := p1 + Vector2(4 * s, 12 * s)
		canvas.draw_string(font, text_pos, room_name, HORIZONTAL_ALIGNMENT_LEFT, int(tr_rect.size.x - 8 * s), int(maxf(8.0, 10.0 * s)), title_col)
		
		if tr_rect.size.y >= 30 * s:
			var status_str := "O2:%.0f%% P:%.0f" % [o2, pres]
			var stat_col := Color(0.4, 0.9, 0.6, 0.9)
			if is_fire:
				status_str = "🔥 INCENDIO"
				stat_col = Color(1.0, 0.35, 0.1, 1.0)
			elif has_br:
				status_str = "🚨 BRECCIA"
				stat_col = Color(1.0, 0.25, 0.25, 1.0)
			elif pres < 50.0:
				status_str = "⚡ VUOTO"
				stat_col = Color(1.0, 0.3, 0.3, 1.0)
			elif has_short:
				status_str = "⚡ CORTO"
				stat_col = Color(1.0, 0.8, 0.2, 1.0)
			elif is_vent:
				status_str = "💨 SFIATO"
				stat_col = Color(0.3, 0.8, 1.0, 1.0)
			elif is_sealed:
				status_str = "🚪 SIGILLATA"
				stat_col = Color(1.0, 0.5, 0.5, 1.0)
			
			canvas.draw_string(font, p1 + Vector2(4 * s, 24 * s), status_str, HORIZONTAL_ALIGNMENT_LEFT, int(tr_rect.size.x - 8 * s), int(maxf(7.0, 9.0 * s)), stat_col)

func _draw_sealed_bulkhead_border(canvas: Control, rect: Rect2, scale_factor: float) -> void:
	var time_now := Time.get_ticks_msec() * 0.003
	var pulse := 0.75 + 0.25 * sin(time_now * 4.0)
	var red_color := Color(1.0, 0.15, 0.15, 0.95 * pulse)
	var yellow_color := Color(1.0, 0.85, 0.2, 0.9)
	var border_w := maxf(2.0, 3.0 * scale_factor)
	
	# Bordo rosso esterno continuo
	canvas.draw_rect(rect, red_color, false, border_w)
	
	# Tratteggio di sicurezza sui 4 lati
	var dash_len := 8.0 * scale_factor
	var p_tl := rect.position
	var p_tr := rect.position + Vector2(rect.size.x, 0)
	var p_br := rect.position + rect.size
	var p_bl := rect.position + Vector2(0, rect.size.y)
	
	canvas.draw_dashed_line(p_tl, p_tr, yellow_color, border_w * 0.5, dash_len)
	canvas.draw_dashed_line(p_tr, p_br, yellow_color, border_w * 0.5, dash_len)
	canvas.draw_dashed_line(p_br, p_bl, yellow_color, border_w * 0.5, dash_len)
	canvas.draw_dashed_line(p_bl, p_tl, yellow_color, border_w * 0.5, dash_len)

func _draw_damages(canvas: Control, trans: Transform2D) -> void:
	var font: Font = ThemeDB.fallback_font
	var time_now := Time.get_ticks_msec() * 0.003
	var s: float = trans.get_scale().x
	
	for dmg in _cached_active_damages:
		var d_pos := _parse_pos(dmg.get("pos", Vector2.ZERO))
		if d_pos == Vector2.ZERO:
			continue
		var canvas_pos: Vector2 = trans * d_pos
		var d_type: String = str(dmg.get("type", ""))
		var d_color := Color(1.0, 0.3, 0.2, 0.9)
		var d_symbol := "💥"
		if d_type.begins_with("dmg_fire") or d_type == "FIRE":
			d_color = Color(1.0, 0.45, 0.1, 0.9)
			d_symbol = "🔥"
		elif d_type.begins_with("dmg_short") or d_type == "ELECTRICAL":
			d_color = Color(1.0, 0.85, 0.2, 0.9)
			d_symbol = "⚡"
		elif d_type.begins_with("dmg_breach") or d_type == "STRUCTURAL":
			d_color = Color(0.9, 0.2, 0.4, 0.9)
			d_symbol = "🚨"
		
		var pulse := 0.6 + 0.4 * sin(time_now * 5.0)
		canvas.draw_circle(canvas_pos, 7.0 * s, Color(d_color.r, d_color.g, d_color.b, 0.3 * pulse))
		canvas.draw_circle(canvas_pos, 4.0 * s, d_color)
		canvas.draw_string(font, canvas_pos + Vector2(-6 * s, -6 * s), d_symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, int(11 * s), Color.WHITE)

func _parse_pos(val: Variant) -> Vector2:
	if val is Vector2:
		return val
	elif val is Dictionary:
		return Vector2(float(val.get("x", 0.0)), float(val.get("y", 0.0)))
	elif val is Array and val.size() >= 2:
		return Vector2(float(val[0]), float(val[1]))
	return Vector2.ZERO

# --- INPUT E INTERAZIONE BLUEPRINT ---

func handle_blueprint_gui_input(canvas: Control, event: InputEvent) -> void:
	var canvas_size: Vector2 = canvas.size
	var scale_factor: float = minf(canvas_size.x / BLUEPRINT_SIZE.x, canvas_size.y / BLUEPRINT_SIZE.y)
	if scale_factor <= 0.001:
		scale_factor = 1.0
	var offset: Vector2 = (canvas_size - BLUEPRINT_SIZE * scale_factor) * 0.5
	var trans := Transform2D().translated(offset).scaled(Vector2(scale_factor, scale_factor))
	var inv_trans := trans.affine_inverse()
	
	if event is InputEventMouseMotion:
		var bp_pos: Vector2 = inv_trans * event.position
		var found_room_id := ""
		for room in rooms:
			var r: Rect2 = room.get("rect", Rect2())
			if r.has_point(bp_pos):
				found_room_id = str(room.get("id", ""))
				break
		
		if found_room_id != hovered_room_id:
			hovered_room_id = found_room_id
			if hovered_room_id.is_empty():
				canvas.mouse_default_cursor_shape = Control.CURSOR_ARROW
			else:
				canvas.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			canvas.queue_redraw()
	
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var bp_pos: Vector2 = inv_trans * event.position
			for room in rooms:
				var r: Rect2 = room.get("rect", Rect2())
				if r.has_point(bp_pos):
					var r_id: String = str(room.get("id", ""))
					select_room(r_id)
					break

func _on_blueprint_gui_input(canvas: Control, event: InputEvent) -> void:
	handle_blueprint_gui_input(canvas, event)

func handle_blueprint_mouse_exited() -> void:
	if not hovered_room_id.is_empty():
		hovered_room_id = ""
		if map_canvas:
			map_canvas.mouse_default_cursor_shape = Control.CURSOR_ARROW
			map_canvas.queue_redraw()

func _on_blueprint_mouse_exited() -> void:
	handle_blueprint_mouse_exited()
