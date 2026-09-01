class_name LifeSupportApp
extends Control

## Controller per l'applicazione di bordo "Life Support & Atmosphere Control" (Applications/LifeSupport).
## Gestisce il monitoraggio e controllo di O2, CO2, pressione barometrica, temperatura,
## incendi, fumo, paratie stagne e iniezione gas inerte antincendio per ciascun compartimento.

const APP_TITLE: String = "SUPPORTO VITALE & CONTROLLO ATMOSFERA"
const DEFAULT_WINDOW_SIZE: Vector2 = Vector2(700, 500)
const BASE_POWER_MW: float = 20.0

const CONFIG_PATH_PRIMARY: String = "Ship Drive/Programs/LifeSupport/life_support_config.dat"
const CONFIG_PATH_FALLBACK: String = "Terminal Drive/Programs/LifeSupport/life_support_config.dat"
const TUNING_PATH_PRIMARY: String = "Ship Drive/Programs/LifeSupport/atmo_tuning.dat"
const TUNING_PATH_FALLBACK: String = "Terminal Drive/Programs/LifeSupport/atmo_tuning.dat"

# --- RIFERIMENTI UI (Unique Names) ---
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
var rooms_state: Dictionary = {}
var room_card_widgets: Dictionary = {}
var selected_room_id: String = ""
var global_scrubber_setting: float = 1.0

func _ready() -> void:
	_configure_window()
	_init_rooms_state()
	_connect_system_signals()
	_connect_ui_signals()
	load_dat_configuration()
	_update_connection_state()
	_update_permissions()
	_refresh_all_ui()

func _exit_tree() -> void:
	_disconnect_system_signals()

func _process(delta: float) -> void:
	if not _is_ship_operational():
		return
	
	_simulate_atmosphere_step(delta)
	_update_telemetry_ui()

func _configure_window() -> void:
	custom_minimum_size = DEFAULT_WINDOW_SIZE
	var parent_win = get_parent()
	while parent_win:
		if "window_title" in parent_win:
			parent_win.window_title = APP_TITLE
			break
		parent_win = parent_win.get_parent()

func _is_ship_operational() -> bool:
	if SpaceWorldManager and SpaceWorldManager.has_method("is_ship_connected"):
		return SpaceWorldManager.is_ship_connected()
	var net_mgr = get_node_or_null("/root/NetworkManager")
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
	
	var net_mgr = get_node_or_null("/root/NetworkManager")
	if net_mgr and net_mgr.has_signal("player_role_changed"):
		if not net_mgr.player_role_changed.is_connected(_on_player_role_changed):
			net_mgr.player_role_changed.connect(_on_player_role_changed)
	
	var sdm = get_node_or_null("/root/ShipDriveManager")
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
	
	var net_mgr = get_node_or_null("/root/NetworkManager")
	if net_mgr and net_mgr.has_signal("player_role_changed"):
		if net_mgr.player_role_changed.is_connected(_on_player_role_changed):
			net_mgr.player_role_changed.disconnect(_on_player_role_changed)
	
	var sdm = get_node_or_null("/root/ShipDriveManager")
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
	if category == "life_support":
		if not is_powered:
			# Power lost! Start emergency oxygen consumption logic or similar
			if status_badge:
				status_badge.text = "● EMERGENZA ENERGETICA"
				status_badge.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2, 1.0))
		else:
			_update_connection_state()

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

func _update_permissions() -> void:
	var nm = get_node_or_null("/root/NetworkManager")
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
	# - Ingegnere, Capitano, Factotum, Solo Mode: Controllo Completo
	# - Pilota, Soldato, Hacker: Sola Visualizzazione
	var role_lower := my_role.to_lower().strip_edges()
	if not my_role.is_empty():
		can_control_life_support = role_lower in ["engineer", "ingegnere", "captain", "capitano", "factotum", "admin", "host"]
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

func _init_rooms_state() -> void:
	rooms_state.clear()
	var rooms_list: Array[Dictionary] = []
	if SpaceWorldManager and SpaceWorldManager.has_method("get_duct_rooms"):
		rooms_list = SpaceWorldManager.get_duct_rooms()
	
	if rooms_list.is_empty():
		rooms_list = [
			{"id": "bridge", "name": "Ponte di Comando", "category": "Command"},
			{"id": "crew_quarters", "name": "Alloggi Equipaggio", "category": "Habitation"},
			{"id": "drone_bay", "name": "Baia Droni", "category": "Tech"},
			{"id": "tech_corridor", "name": "Corridoio Tecnico", "category": "Corridor"},
			{"id": "cargo_bay", "name": "Baia di Carico", "category": "Cargo"},
			{"id": "reactor_room", "name": "Sala Reattore", "category": "Engineering"},
			{"id": "engines", "name": "Sala Motori", "category": "Engineering"},
			{"id": "armory", "name": "Armeria & Scudi", "category": "Tactical"}
		]
	
	for r in rooms_list:
		var r_id: String = str(r.get("id", ""))
		rooms_state[r_id] = {
			"id": r_id,
			"name": str(r.get("name", r_id)),
			"category": str(r.get("category", "General")),
			"rect": r.get("rect", Rect2()),
			"o2_pct": 21.0,
			"co2_pct": 0.04,
			"pressure_kpa": 101.3,
			"temperature_c": 21.5,
			"is_sealed": false,
			"is_fire_active": false,
			"is_smoke_active": false,
			"is_suppression_active": false,
			"suppression_timer": 0.0,
			"is_venting": false,
			"has_breach": false
		}
	
	if not rooms_state.is_empty() and selected_room_id.is_empty():
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
	
	# Verifica danni breccia da SpaceWorldManager
	var active_damages: Array[Dictionary] = []
	if SpaceWorldManager and SpaceWorldManager.has_method("get_damage_zones"):
		active_damages = SpaceWorldManager.get_damage_zones()
	
	for r_id in rooms_state:
		var state: Dictionary = rooms_state[r_id]
		var r_rect: Rect2 = state.get("rect", Rect2())
		
		# Verifica se c'è un danno/breccia in questa stanza
		var breach_present := false
		for dmg in active_damages:
			var d_pos: Vector2 = dmg.get("pos", Vector2.ZERO)
			var d_type: String = str(dmg.get("type", ""))
			if (d_type.begins_with("dmg_breach") or d_type == "STRUCTURAL") and r_rect.has_point(d_pos):
				breach_present = true
				break
		state["has_breach"] = breach_present
		
		# Gestione timer iniezione soppressione gas inerte
		if state["is_suppression_active"]:
			state["suppression_timer"] -= delta
			state["is_fire_active"] = false
			state["is_smoke_active"] = false
			state["temperature_c"] = move_toward(state["temperature_c"], 18.0, delta * 15.0)
			state["o2_pct"] = move_toward(state["o2_pct"], 12.0, delta * 4.0)
			state["co2_pct"] = move_toward(state["co2_pct"], fire_supp_co2, delta * 0.1)
			if state["suppression_timer"] <= 0.0:
				state["is_suppression_active"] = false
		
		# Incendio attivo
		if state["is_fire_active"]:
			state["temperature_c"] = move_toward(state["temperature_c"], 380.0, delta * 25.0)
			state["o2_pct"] = move_toward(state["o2_pct"], 4.0, delta * 2.5)
			state["co2_pct"] = move_toward(state["co2_pct"], 3.5, delta * 0.4)
			state["is_smoke_active"] = true
			if auto_fire_suppress and not state["is_suppression_active"]:
				trigger_fire_suppression(r_id)
		
		# Decompressione da breccia o venting manuale
		if state["has_breach"] or state["is_venting"]:
			var rate_mult: float = decomp_rate * (3.0 if state["has_breach"] else 1.5)
			state["pressure_kpa"] = move_toward(state["pressure_kpa"], 0.0, delta * 12.0 * rate_mult)
			state["o2_pct"] = move_toward(state["o2_pct"], 0.0, delta * 3.0 * rate_mult)
			state["temperature_c"] = move_toward(state["temperature_c"], -40.0, delta * 5.0)
			# Senza ossigeno l'incendio soffoca
			if state["o2_pct"] < 6.0:
				state["is_fire_active"] = false
		else:
			# Pressurizzazione e rigenerazione normale
			if not state["is_suppression_active"]:
				state["pressure_kpa"] = move_toward(state["pressure_kpa"], 101.3, delta * 4.0)
				state["o2_pct"] = move_toward(state["o2_pct"], 21.0, delta * o2_gen_rate * 0.5)
				state["temperature_c"] = move_toward(state["temperature_c"], 21.5, delta * 2.0)
				
				# Scrubber CO2
				var scrub_rate := delta * 0.08 * scrubber_eff * global_scrubber_setting
				state["co2_pct"] = move_toward(state["co2_pct"], 0.04, scrub_rate)
				if state["co2_pct"] <= 0.1 and not state["is_fire_active"]:
					state["is_smoke_active"] = false

# --- METODI PUBBLICI / CONTROLLO ATMOSFERA ---

func set_bulkhead_sealed(room_id: String, sealed: bool) -> void:
	if not rooms_state.has(room_id):
		return
	rooms_state[room_id]["is_sealed"] = sealed
	if room_card_widgets.has(room_id):
		room_card_widgets[room_id].update_telemetry(rooms_state[room_id])
	_update_selected_room_ui()

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
	state["is_venting"] = false
	state["is_fire_active"] = false
	state["is_smoke_active"] = false
	state["o2_pct"] = 21.0
	state["co2_pct"] = 0.04
	state["pressure_kpa"] = 101.3
	state["temperature_c"] = 21.5
	_update_selected_room_ui()

func seal_all_bulkheads() -> void:
	for r_id in rooms_state:
		rooms_state[r_id]["is_sealed"] = true
	_refresh_all_ui()

func suppress_all_fires() -> void:
	for r_id in rooms_state:
		trigger_fire_suppression(r_id)
	_refresh_all_ui()

# --- CALLBACK UI ---

func _on_room_card_selected(room_id: String) -> void:
	selected_room_id = room_id
	_update_selected_room_visuals()
	_update_selected_room_ui()

func _on_room_card_seal_toggled(room_id: String, is_sealed: bool) -> void:
	set_bulkhead_sealed(room_id, is_sealed)

func _on_room_card_fire_suppressed(room_id: String) -> void:
	trigger_fire_suppression(room_id)

func _on_toggle_seal_pressed() -> void:
	if not can_control_life_support or not rooms_state.has(selected_room_id):
		return
	var current_sealed: bool = bool(rooms_state[selected_room_id].get("is_sealed", false))
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
	if selected_pressure_label: selected_pressure_label.text = "Pressione: %.1f kPa (%.2f atm)" % [pres, pres / 101.3]
	if selected_temp_label: selected_temp_label.text = "Temperatura: %.1f°C" % tmp
	
	if selected_room_status:
		if has_br or pres < 40.0:
			selected_room_status.text = "⚡ ALLARME DECOMPRESSIONE / BRECCIA SCAFO"
			selected_room_status.add_theme_color_override("font_color", Color(0.95, 0.2, 0.2, 1.0))
		elif is_fire:
			selected_room_status.text = "🔥 ALLARME INCENDIO ATTIVO"
			selected_room_status.add_theme_color_override("font_color", Color(0.95, 0.3, 0.1, 1.0))
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
		else:
			selected_room_status.text = "● PARAMETRI AMBIENTALI OTTIMALI"
			selected_room_status.add_theme_color_override("font_color", Color(0.2, 0.85, 0.4, 1.0))
	
	if btn_toggle_seal:
		btn_toggle_seal.text = "🔓 Apri Paratia" if is_sealed else "🚪 Sigilla Paratia"
	if btn_toggle_vent:
		btn_toggle_vent.text = "⏹ Ferma Evacuazione" if is_vent else "💨 Evacua Atmosfera"

func _update_telemetry_ui() -> void:
	var total_o2 := 0.0
	var total_press := 0.0
	var alarms_count := 0
	var count := rooms_state.size()
	
	for r_id in rooms_state:
		var st: Dictionary = rooms_state[r_id]
		var o2: float = float(st.get("o2_pct", 21.0))
		var pr: float = float(st.get("pressure_kpa", 101.3))
		total_o2 += o2
		total_press += pr
		
		if bool(st.get("is_fire_active")) or bool(st.get("has_breach")) or o2 < 18.0 or pr < 80.0:
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
		if eq_pos == -1:
			continue
		
		var key := line.substr(0, eq_pos).strip_edges()
		var val_str := line.substr(eq_pos + 1).strip_edges()
		
		if val_str.to_lower() == "true":
			result[key] = true
		elif val_str.to_lower() == "false":
			result[key] = false
		elif val_str.is_valid_int():
			result[key] = val_str.to_int()
		elif val_str.is_valid_float():
			result[key] = val_str.to_float()
		else:
			result[key] = val_str
	
	file.close()
	return result

func _on_drive_file_modified(rel_path: String) -> void:
	if "LifeSupport" in rel_path and rel_path.ends_with(".dat"):
		load_dat_configuration()

func _on_drive_file_synced(rel_path: String, _content: String = "") -> void:
	if "LifeSupport" in rel_path and rel_path.ends_with(".dat"):
		load_dat_configuration()
