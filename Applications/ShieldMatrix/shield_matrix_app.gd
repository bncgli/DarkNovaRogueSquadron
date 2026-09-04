class_name ShieldMatrixApp
extends BaseApp

## Applicazione GodotOS per la Matrice Scudi, Deflettori Scafo e Dispositivi di Difesa Direzionale.
## Conforme allo standard architetturale di bordo (APP_ARCHITECTURE_STANDARD.md) e TASK-032.
## Vista bipartita Split-View:
## - Sinistra: Visualizzatore olografico interattivo a 4 quadranti e bilanciamento energetico.
## - Destra: Gestione dinamica dei dispositivi Point-Defense (Gatling e Lanciatori Flack Angel-Hair).

const APP_TITLE: String = "Shield Matrix & Deflectors"
const DEFAULT_WINDOW_SIZE: Vector2 = Vector2(800, 520)

const CONFIG_PATH_PRIMARY: String = "Ship Drive/Programs/ShieldMatrix/shields_config.dat"
const CONFIG_PATH_FALLBACK: String = "Terminal Drive/Programs/ShieldMatrix/shields_config.dat"
const TUNING_PATH_PRIMARY: String = "Ship Drive/Programs/ShieldMatrix/deflector_tuning.dat"
const TUNING_PATH_FALLBACK: String = "Terminal Drive/Programs/ShieldMatrix/deflector_tuning.dat"

const DEFENSE_DEVICE_CARD_SCENE := preload("res://Applications/ShieldMatrix/defense_device_card.tscn")

enum DefenseSector {
	FORE = 0,
	PORT = 1,
	STARBOARD = 2,
	AFT = 3
}

# --- RIFERIMENTI NODI UI ---
@onready var disconnected_overlay: Control = get_node_or_null("%DisconnectedOverlay")
@onready var status_badge: Label = get_node_or_null("%StatusBadge")
@onready var role_badge: Label = get_node_or_null("%RoleBadge")
@onready var power_badge: Label = get_node_or_null("%PowerBadge")
@onready var dat_status_badge: Label = get_node_or_null("%DatStatusBadge")
@onready var reload_dat_button: Button = get_node_or_null("%ReloadDatButton")

# Visualizzatore Olografico
@onready var hologram_canvas: ShieldMatrixHologram = get_node_or_null("%HologramCanvas")

# Barre e Valori dei 4 Quadranti
@onready var fore_bar: ProgressBar = get_node_or_null("%ForeBar")
@onready var fore_value_label: Label = get_node_or_null("%ForeValueLabel")
@onready var aft_bar: ProgressBar = get_node_or_null("%AftBar")
@onready var aft_value_label: Label = get_node_or_null("%AftValueLabel")
@onready var port_bar: ProgressBar = get_node_or_null("%PortBar")
@onready var port_value_label: Label = get_node_or_null("%PortValueLabel")
@onready var starboard_bar: ProgressBar = get_node_or_null("%StarboardBar")
@onready var starboard_value_label: Label = get_node_or_null("%StarboardValueLabel")

# Integrità Totale
@onready var total_integrity_bar: ProgressBar = get_node_or_null("%TotalIntegrityBar")
@onready var total_integrity_label: Label = get_node_or_null("%TotalIntegrityLabel")

# Controlli di Bilanciamento (Sliders & Vector Pad)
@onready var balance_fore_slider: HSlider = get_node_or_null("%BalanceForeSlider")
@onready var balance_aft_slider: HSlider = get_node_or_null("%BalanceAftSlider")
@onready var balance_port_slider: HSlider = get_node_or_null("%BalancePortSlider")
@onready var balance_starboard_slider: HSlider = get_node_or_null("%BalanceStarboardSlider")
@onready var reset_balance_button: Button = get_node_or_null("%ResetBalanceButton")
@onready var vector_pad: Control = get_node_or_null("%VectorPad")
@onready var pad_handle: Control = get_node_or_null("%PadHandle")

# Ricarica Rapida e Armoniche
@onready var emergency_boost_button: Button = get_node_or_null("%EmergencyBoostButton")
@onready var phase_sync_switch: CheckButton = get_node_or_null("%PhaseSyncSwitch")
@onready var phase_status_label: Label = get_node_or_null("%PhaseStatusLabel")
@onready var action_log_label: Label = get_node_or_null("%ActionLogLabel")

# Pannello Dispositivi di Difesa (Sezione Destra)
@onready var defense_devices_panel: Control = get_node_or_null("%DefenseDevicesPanel")
@onready var devices_scroll_container: ScrollContainer = get_node_or_null("%DevicesScrollContainer")
@onready var devices_list_container: VBoxContainer = get_node_or_null("%DevicesListContainer")
@onready var devices_summary_label: Label = get_node_or_null("%DevicesSummaryLabel")
@onready var reload_all_defenses_button: Button = get_node_or_null("%ReloadAllDefensesButton")

# --- STATO OPERATIVO E PARAMETRI RUNTIME ---
var shield_fore: float = 250.0
var shield_aft: float = 250.0
var shield_port: float = 250.0
var shield_starboard: float = 250.0

var ratio_fore: float = 0.25
var ratio_aft: float = 0.25
var ratio_port: float = 0.25
var ratio_starboard: float = 0.25

var is_phase_synced: bool = true
var is_is_shield_powered: bool = true
var boost_cooldown_timer: float = 0.0
var can_control_shields: bool = true
var is_dragging_pad: bool = false
var pad_vector: Vector2 = Vector2.ZERO

# Array dinamico dei dispositivi difensivi montati
var defense_devices: Array[Dictionary] = [
	{
		"id": "gatling_1",
		"name": "Gatling Difesa Auto-1",
		"type": "GATLING",
		"sector": DefenseSector.FORE,
		"ammo": 800,
		"max_ammo": 800,
		"status": "READY",
		"cooldown": 0.0,
		"cooldown_max": 0.5,
		"range": 150.0
	},
	{
		"id": "gatling_2",
		"name": "Gatling Difesa Auto-2",
		"type": "GATLING",
		"sector": DefenseSector.PORT,
		"ammo": 800,
		"max_ammo": 800,
		"status": "READY",
		"cooldown": 0.0,
		"cooldown_max": 0.5,
		"range": 150.0
	},
	{
		"id": "flack_1",
		"name": "Lanciatore Flack Angel-Hair",
		"type": "FLACK",
		"sector": DefenseSector.AFT,
		"ammo": 16,
		"max_ammo": 16,
		"status": "READY",
		"cooldown": 0.0,
		"cooldown_max": 3.0,
		"range": 200.0
	}
]

var _device_cards: Dictionary = {} # device_id -> DefenseDeviceCard

var active_config: Dictionary = {
	"max_capacity_per_quadrant": 250.0,
	"recharge_rate_per_sec": 15.0,
	"overload_limit": 1.3,
	"base_power_draw_mw": 90.0,
	"emergency_boost_power_mw": 120.0,
	"emergency_boost_amount": 75.0,
	"emergency_boost_cooldown": 8.0,
	"decay_rate_unpowered": 25.0,
	"harmonic_frequency": 440.0,
	"emergency_boost_multiplier": 2.5,
	"overclock_absorption": 1.0,
	"phase_sync_stability": 0.98,
	"dispersion_damping": 0.88,
	"is_dat_loaded": false
}

func _ready() -> void:
	_configure_window(APP_TITLE, DEFAULT_WINDOW_SIZE)
	_connect_system_signals()
	_setup_ui_signals()
	_rebuild_device_cards()
	_update_connection_state()
	load_dat_configuration()
	_update_permissions()
	_refresh_ui_display()

func _connect_system_signals() -> void:
	if SpaceWorldManager:
		if SpaceWorldManager.has_signal("ship_connection_changed"):
			SpaceWorldManager.ship_connection_changed.connect(_on_ship_connection_changed)
	
	if NetworkManager:
		if NetworkManager.has_signal("player_role_changed"):
			NetworkManager.player_role_changed.connect(_on_player_role_changed)
		if NetworkManager.has_signal("mission_started"):
			NetworkManager.mission_started.connect(_on_mission_started)
		if NetworkManager.has_signal("mission_ended"):
			NetworkManager.mission_ended.connect(_on_mission_ended)
	
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm:
		if sdm.has_signal("file_modified"):
			sdm.file_modified.connect(_on_drive_file_event)
		if sdm.has_signal("file_synced"):
			sdm.file_synced.connect(_on_drive_file_event)

func _setup_ui_signals() -> void:
	if reload_dat_button:
		reload_dat_button.pressed.connect(load_dat_configuration)
	if reset_balance_button:
		reset_balance_button.pressed.connect(_on_reset_balance_pressed)
	if emergency_boost_button:
		emergency_boost_button.pressed.connect(_on_emergency_boost_pressed)
	if phase_sync_switch:
		phase_sync_switch.toggled.connect(_on_phase_sync_toggled)
	
	if reload_all_defenses_button:
		reload_all_defenses_button.pressed.connect(reload_all_defense_devices)
	
	if hologram_canvas:
		if not hologram_canvas.sector_clicked.is_connected(_on_hologram_sector_clicked):
			hologram_canvas.sector_clicked.connect(_on_hologram_sector_clicked)
	
	if balance_fore_slider:
		balance_fore_slider.value_changed.connect(func(v): _on_slider_ratio_changed(GlobalValues.Quadrant.FORE, v))
	if balance_aft_slider:
		balance_aft_slider.value_changed.connect(func(v): _on_slider_ratio_changed(GlobalValues.Quadrant.AFT, v))
	if balance_port_slider:
		balance_port_slider.value_changed.connect(func(v): _on_slider_ratio_changed(GlobalValues.Quadrant.PORT, v))
	if balance_starboard_slider:
		balance_starboard_slider.value_changed.connect(func(v): _on_slider_ratio_changed(GlobalValues.Quadrant.STARBOARD, v))
	
	if vector_pad:
		vector_pad.gui_input.connect(_on_vector_pad_gui_input)

func _exit_tree() -> void:
	if SpaceWorldManager and SpaceWorldManager.has_signal("ship_connection_changed") and SpaceWorldManager.ship_connection_changed.is_connected(_on_ship_connection_changed):
		SpaceWorldManager.ship_connection_changed.disconnect(_on_ship_connection_changed)
	if NetworkManager:
		if NetworkManager.has_signal("player_role_changed") and NetworkManager.player_role_changed.is_connected(_on_player_role_changed):
			NetworkManager.player_role_changed.disconnect(_on_player_role_changed)
		if NetworkManager.has_signal("mission_started") and NetworkManager.mission_started.is_connected(_on_mission_started):
			NetworkManager.mission_started.disconnect(_on_mission_started)
		if NetworkManager.has_signal("mission_ended") and NetworkManager.mission_ended.is_connected(_on_mission_ended):
			NetworkManager.mission_ended.disconnect(_on_mission_ended)
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm:
		if sdm.has_signal("file_modified") and sdm.file_modified.is_connected(_on_drive_file_event):
			sdm.file_modified.disconnect(_on_drive_file_event)
		if sdm.has_signal("file_synced") and sdm.file_synced.is_connected(_on_drive_file_event):
			sdm.file_synced.disconnect(_on_drive_file_event)

func _process(delta: float) -> void:
	if not _is_ship_operational():
		return
	
	if boost_cooldown_timer > 0.0:
		boost_cooldown_timer = maxf(0.0, boost_cooldown_timer - delta)
		if emergency_boost_button and can_control_shields:
			if boost_cooldown_timer > 0.0:
				emergency_boost_button.disabled = true
				emergency_boost_button.text = "⏳ BOOST (%.1fs)" % boost_cooldown_timer
			else:
				emergency_boost_button.disabled = false
				emergency_boost_button.text = "⚡ RICARICA RAPIDA"
	
	_process_active_defenses(delta)
	_simulate_shield_recharge(delta)
	_refresh_ui_display()

# --- GESTIONE DINAMICA DISPOSITIVI DI DIFESA ---

func register_defense_device(device_data: Dictionary) -> void:
	var data := device_data.duplicate(true)
	if not data.has("id") or str(data["id"]).is_empty():
		data["id"] = "dev_%d" % (defense_devices.size() + 1)
	if not data.has("status"):
		data["status"] = "READY"
	if not data.has("cooldown"):
		data["cooldown"] = 0.0
	var dev_type: String = str(data.get("type", "GATLING")).to_upper()
	if not data.has("cooldown_max"):
		data["cooldown_max"] = 0.5 if dev_type == "GATLING" else 3.0
	if not data.has("max_ammo"):
		data["max_ammo"] = data.get("ammo", 800 if dev_type == "GATLING" else 16)
	if not data.has("sector"):
		data["sector"] = DefenseSector.FORE
	if not data.has("range"):
		data["range"] = 150.0 if dev_type == "GATLING" else 200.0
	
	var found := false
	for i in range(defense_devices.size()):
		if defense_devices[i].get("id") == data["id"]:
			defense_devices[i] = data
			found = true
			break
	if not found:
		defense_devices.append(data)
	
	_rebuild_device_cards()
	_refresh_ui_display()

func assign_device_sector(device_id: String, sector_enum: int) -> bool:
	for dev in defense_devices:
		if dev.get("id") == device_id:
			dev["sector"] = sector_enum
			_log_action("Dispositivo '%s' riassegnato al settore %s." % [dev.get("name", device_id), _get_sector_name(sector_enum)])
			_update_device_card_ui(device_id)
			_refresh_ui_display()
			return true
	return false

func _on_device_sector_changed(device_id: String, new_sector: int) -> void:
	if not can_control_shields or not _is_ship_operational():
		_update_device_card_ui(device_id)
		return
	assign_device_sector(device_id, new_sector)

func get_defense_devices() -> Array[Dictionary]:
	return defense_devices

func get_devices_in_sector(sector: int) -> Array[Dictionary]:
	var res: Array[Dictionary] = []
	for dev in defense_devices:
		if dev.get("sector") == sector:
			res.append(dev)
	return res

func reload_all_defense_devices() -> void:
	if not can_control_shields or not _is_ship_operational():
		return
	for dev in defense_devices:
		var max_a: int = int(dev.get("max_ammo", 800 if dev.get("type") == "GATLING" else 16))
		dev["ammo"] = max_a
		dev["cooldown"] = 0.0
		dev["status"] = "READY"
		_update_device_card_ui(dev.get("id"))
	_log_action("Munizioni di tutti i dispositivi difensivi ricaricate al 100%.")
	_refresh_ui_display()

func _rebuild_device_cards() -> void:
	if not devices_list_container:
		return
	
	for child in devices_list_container.get_children():
		devices_list_container.remove_child(child)
		child.queue_free()
	_device_cards.clear()
	
	for dev in defense_devices:
		var card: DefenseDeviceCard = DEFENSE_DEVICE_CARD_SCENE.instantiate() as DefenseDeviceCard
		devices_list_container.add_child(card)
		card.setup(dev, can_control_shields)
		card.sector_changed.connect(_on_device_sector_changed)
		_device_cards[dev.get("id")] = card
	
	_update_devices_summary()

func _update_device_card_ui(device_id: String) -> void:
	if _device_cards.has(device_id) and is_instance_valid(_device_cards[device_id]):
		for dev in defense_devices:
			if dev.get("id") == device_id:
				_device_cards[device_id].update_state(dev, can_control_shields)
				break
	_update_devices_summary()

func _update_devices_summary() -> void:
	if devices_summary_label:
		var active_count := 0
		for dev in defense_devices:
			if dev.get("ammo", 0) > 0:
				active_count += 1
		devices_summary_label.text = "Copertura attiva: %d/%d apparati" % [active_count, defense_devices.size()]

func _on_hologram_sector_clicked(sector: int) -> void:
	if not can_control_shields or not _is_ship_operational():
		return
	# Seleziona il primo dispositivo disponibile e lo sposta ciclicamente al settore cliccato
	if not defense_devices.is_empty():
		var target_dev: Dictionary = defense_devices[0]
		assign_device_sector(target_dev.get("id"), sector)

# --- LOGICA DI INTERCETTAZIONE AUTOMATICA PUNTO-DIFESA ---

func _process_active_defenses(delta: float) -> void:
	if not _is_ship_operational() or not is_is_shield_powered:
		return
	
	# Aggiorna cooldown dei dispositivi
	for dev in defense_devices:
		if dev.get("cooldown", 0.0) > 0.0:
			dev["cooldown"] = maxf(0.0, dev["cooldown"] - delta)
			if dev["cooldown"] == 0.0 and dev.get("ammo", 0) > 0:
				dev["status"] = "READY"
			_update_device_card_ui(dev.get("id"))
	
	if not SpaceWorldManager:
		return
	
	var incoming: Array[Dictionary] = []
	if SpaceWorldManager.has_method("get_incoming_projectiles"):
		incoming = SpaceWorldManager.get_incoming_projectiles()
	
	if incoming.is_empty():
		return
	
	var ship := SpaceWorldManager.get_spaceship() if SpaceWorldManager.has_method("get_spaceship") else null
	var ship_pos := ship.global_position if ship and is_instance_valid(ship) and ship.is_inside_tree() else Vector3.ZERO
	var ship_basis := ship.global_transform.basis if ship and is_instance_valid(ship) and ship.is_inside_tree() else Basis.IDENTITY
	
	# Scorre le minacce in arrivo
	for proj in incoming.duplicate():
		if proj.get("is_destroyed", false):
			continue
		
		var proj_pos: Vector3 = proj.get("position", Vector3.ZERO)
		var diff := proj_pos - ship_pos
		var dist := diff.length()
		
		# Calcolo settore di provenienza dell'attacco relativo alla nave
		var local_diff := ship_basis.inverse() * diff
		var bearing_deg := rad_to_deg(atan2(local_diff.x, -local_diff.z))
		var incoming_sector := _get_sector_from_bearing(bearing_deg)
		
		# Verifica se c'è un dispositivo difensivo assegnato al settore di provenienza
		for dev in defense_devices:
			if dev.get("sector") != incoming_sector:
				continue # Vincolo direzionale monosettore!
			
			if dev.get("ammo", 0) <= 0 or dev.get("cooldown", 0.0) > 0.0:
				continue
			
			var dev_type: String = str(dev.get("type", "")).to_upper()
			var dev_range: float = float(dev.get("range", 150.0))
			
			if dist > dev_range:
				continue
			
			var proj_type: String = str(proj.get("type", "")).to_upper()
			var is_homing: bool = proj.get("is_homing", false) or proj_type.contains("HOMING") or proj_type == "TORPEDO"
			
			# GATLING: intercetta e distrugge minacce cinetiche, missili, asteroidi, mine
			if dev_type == "GATLING":
				if proj_type in ["MISSILE", "HOMING_MISSILE", "KINETIC", "ASTEROID", "ROCKET", "MINE", "TORPEDO", "PLASMA"]:
					dev["ammo"] = max(0, dev.get("ammo", 1) - 1)
					dev["cooldown"] = float(dev.get("cooldown_max", 0.5))
					dev["status"] = "COOLDOWN" if dev["ammo"] > 0 else "EMPTY"
					
					SpaceWorldManager.intercept_projectile(proj.get("id"), dev.get("id"), incoming_sector)
					_log_action("🎯 %s ha neutralizzato %s nel settore %s!" % [
						dev.get("name", "Gatling"), proj.get("id"), _get_sector_name(incoming_sector)
					])
					_update_device_card_ui(dev.get("id"))
					break
			
			# FLACK: cortina Angel Hair che acceca e devia i missili a guida autonoma/ricerca
			elif dev_type == "FLACK":
				if is_homing and not proj.get("is_deflected", false):
					dev["ammo"] = max(0, dev.get("ammo", 1) - 1)
					dev["cooldown"] = float(dev.get("cooldown_max", 3.0))
					dev["status"] = "COOLDOWN" if dev["ammo"] > 0 else "EMPTY"
					
					SpaceWorldManager.deflect_projectile(proj.get("id"), dev.get("id"), incoming_sector)
					_log_action("💨 %s ha steso una nube Angel-Hair nel settore %s: bersaglio %s deviato!" % [
						dev.get("name", "Flack"), _get_sector_name(incoming_sector), proj.get("id")
					])
					_update_device_card_ui(dev.get("id"))
					break

func _get_sector_from_bearing(bearing_deg: float) -> int:
	# -45°..+45° Fore, 45°..135° Starboard, 135°..-135° Aft, -135°..-45° Port
	if bearing_deg >= -45.0 and bearing_deg <= 45.0:
		return DefenseSector.FORE
	elif bearing_deg > 45.0 and bearing_deg <= 135.0:
		return DefenseSector.STARBOARD
	elif bearing_deg < -45.0 and bearing_deg >= -135.0:
		return DefenseSector.PORT
	else:
		return DefenseSector.AFT

func _get_sector_name(sector: int) -> String:
	match sector:
		DefenseSector.FORE: return "Prua (FORE)"
		DefenseSector.PORT: return "Babordo (PORT)"
		DefenseSector.STARBOARD: return "Tribordo (STARBOARD)"
		DefenseSector.AFT: return "Poppa (AFT)"
		_: return "Sconosciuto"

# --- RIGENERAZIONE ED ENERGETICA SCUDI ---

func _simulate_shield_recharge(delta: float) -> void:
	var base_max: float = float(active_config.get("max_capacity_per_quadrant", 250.0))
	var recharge_rate: float = float(active_config.get("recharge_rate_per_sec", 15.0))
	var decay_rate: float = float(active_config.get("decay_rate_unpowered", 25.0))
	var sync_mult: float = 1.15 if is_phase_synced else 0.85
	
	var port_damage_penalty: float = 0.0
	if SpaceWorldManager and SpaceWorldManager.has_method("get_damage_zones"):
		var damages: Array = SpaceWorldManager.get_damage_zones()
		for d in damages:
			var impact: Variant = d.system_impact if d is ShipDamageData else d.get("system_impact", "")
			if str(impact) == "shields_degraded":
				var sev: Variant = d.severity if d is ShipDamageData else d.get("severity", 0.0)
				port_damage_penalty = float(sev) * 10.0
	
	var max_f := base_max * (ratio_fore / 0.25)
	var max_a := base_max * (ratio_aft / 0.25)
	var max_p := maxf(20.0, (base_max - port_damage_penalty) * (ratio_port / 0.25))
	var max_s := base_max * (ratio_starboard / 0.25)
	
	if is_is_shield_powered:
		shield_fore = move_toward(shield_fore, max_f, recharge_rate * (ratio_fore / 0.25) * sync_mult * delta)
		shield_aft = move_toward(shield_aft, max_a, recharge_rate * (ratio_aft / 0.25) * sync_mult * delta)
		shield_port = move_toward(shield_port, max_p, recharge_rate * (ratio_port / 0.25) * sync_mult * delta)
		shield_starboard = move_toward(shield_starboard, max_s, recharge_rate * (ratio_starboard / 0.25) * sync_mult * delta)
	else:
		shield_fore = move_toward(shield_fore, 0.0, decay_rate * delta)
		shield_aft = move_toward(shield_aft, 0.0, decay_rate * delta)
		shield_port = move_toward(shield_port, 0.0, decay_rate * delta)
		shield_starboard = move_toward(shield_starboard, 0.0, decay_rate * delta)

func _refresh_ui_display() -> void:
	var base_max: float = active_config.get("max_capacity_per_quadrant", 250.0)
	var max_f := maxf(1.0, base_max * (ratio_fore / 0.25))
	var max_a := maxf(1.0, base_max * (ratio_aft / 0.25))
	var max_p := maxf(1.0, base_max * (ratio_port / 0.25))
	var max_s := maxf(1.0, base_max * (ratio_starboard / 0.25))
	
	if fore_bar:
		fore_bar.max_value = max_f
		fore_bar.value = shield_fore
	if fore_value_label:
		fore_value_label.text = "%d / %d MW (%.0f%%)" % [int(shield_fore), int(max_f), (ratio_fore * 100.0)]
	
	if aft_bar:
		aft_bar.max_value = max_a
		aft_bar.value = shield_aft
	if aft_value_label:
		aft_value_label.text = "%d / %d MW (%.0f%%)" % [int(shield_aft), int(max_a), (ratio_aft * 100.0)]
		
	if port_bar:
		port_bar.max_value = max_p
		port_bar.value = shield_port
	if port_value_label:
		port_value_label.text = "%d / %d MW (%.0f%%)" % [int(shield_port), int(max_p), (ratio_port * 100.0)]
		
	if starboard_bar:
		starboard_bar.max_value = max_s
		starboard_bar.value = shield_starboard
	if starboard_value_label:
		starboard_value_label.text = "%d / %d MW (%.0f%%)" % [int(shield_starboard), int(max_s), (ratio_starboard * 100.0)]
	
	# Integrità Totale
	var total_hp := shield_fore + shield_aft + shield_port + shield_starboard
	var total_max := max_f + max_a + max_p + max_s
	if total_integrity_bar:
		total_integrity_bar.max_value = total_max
		total_integrity_bar.value = total_hp
	if total_integrity_label:
		var pct := (total_hp / total_max) * 100.0 if total_max > 0.0 else 0.0
		total_integrity_label.text = "INTEGRITÀ GLOBALE: %d / %d MW (%.1f%%)" % [int(total_hp), int(total_max), pct]
	
	# Sliders
	if balance_fore_slider and not balance_fore_slider.has_focus():
		balance_fore_slider.set_value_no_signal(ratio_fore * 100.0)
	if balance_aft_slider and not balance_aft_slider.has_focus():
		balance_aft_slider.set_value_no_signal(ratio_aft * 100.0)
	if balance_port_slider and not balance_port_slider.has_focus():
		balance_port_slider.set_value_no_signal(ratio_port * 100.0)
	if balance_starboard_slider and not balance_starboard_slider.has_focus():
		balance_starboard_slider.set_value_no_signal(ratio_starboard * 100.0)
	
	# Ologramma
	if hologram_canvas:
		var f_hp_pct := shield_fore / max_f
		var a_hp_pct := shield_aft / max_a
		var p_hp_pct := shield_port / max_p
		var s_hp_pct := shield_starboard / max_s
		hologram_canvas.set_defense_devices(defense_devices)
		hologram_canvas.update_matrix_state(
			ratio_fore, ratio_aft, ratio_port, ratio_starboard,
			f_hp_pct, a_hp_pct, p_hp_pct, s_hp_pct,
			is_phase_synced, _is_ship_operational()
		)
	
	# Power badge
	if power_badge:
		var p_mw: float = active_config.get("base_power_draw_mw", 90.0)
		if boost_cooldown_timer > 0.0:
			p_mw += active_config.get("emergency_boost_power_mw", 120.0)
		power_badge.text = "POTENZA: %.0f MW" % p_mw

# --- GESTIONE VECTOR PAD & SLIDER RATIO ---

func _on_vector_pad_gui_input(event: InputEvent) -> void:
	if not can_control_shields or not _is_ship_operational():
		return
	
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			is_dragging_pad = mb.pressed
			if is_dragging_pad:
				_update_vector_from_mouse(mb.position)
	elif event is InputEventMouseMotion and is_dragging_pad:
		var mm := event as InputEventMouseMotion
		_update_vector_from_mouse(mm.position)

func _update_vector_from_mouse(pos: Vector2) -> void:
	if not vector_pad:
		return
	var half_size := vector_pad.size * 0.5
	var rel := (pos - half_size) / half_size
	rel.x = clampf(rel.x, -1.0, 1.0)
	rel.y = clampf(rel.y, -1.0, 1.0)
	pad_vector = rel
	
	if pad_handle:
		pad_handle.position = half_size + rel * (half_size.x * 0.75) - pad_handle.size * 0.5
	
	_apply_vector_bias(rel)

func _apply_vector_bias(vec: Vector2) -> void:
	var f_weight := maxf(0.05, 0.25 - vec.y * 0.35)
	var a_weight := maxf(0.05, 0.25 + vec.y * 0.35)
	var p_weight := maxf(0.05, 0.25 - vec.x * 0.35)
	var s_weight := maxf(0.05, 0.25 + vec.x * 0.35)
	
	var total := f_weight + a_weight + p_weight + s_weight
	ratio_fore = f_weight / total
	ratio_aft = a_weight / total
	ratio_port = p_weight / total
	ratio_starboard = s_weight / total
	
	_log_action("Bilanciamento orientato: Prua %.0f%% | Poppa %.0f%% | Babordo %.0f%% | Tribordo %.0f%%" % [
		ratio_fore * 100.0, ratio_aft * 100.0, ratio_port * 100.0, ratio_starboard * 100.0
	])
	_refresh_ui_display()

func _on_slider_ratio_changed(quadrant: int, val: float) -> void:
	if not can_control_shields or not _is_ship_operational():
		return
	
	var new_ratio := clampf(val / 100.0, 0.05, 0.70)
	match quadrant:
		GlobalValues.Quadrant.FORE:
			ratio_fore = new_ratio
		GlobalValues.Quadrant.AFT:
			ratio_aft = new_ratio
		GlobalValues.Quadrant.PORT:
			ratio_port = new_ratio
		GlobalValues.Quadrant.STARBOARD:
			ratio_starboard = new_ratio
	
	_normalize_ratios(quadrant)
	_refresh_ui_display()

func _normalize_ratios(fixed_quadrant: int) -> void:
	var fixed_val: float
	match fixed_quadrant:
		GlobalValues.Quadrant.FORE: fixed_val = ratio_fore
		GlobalValues.Quadrant.AFT: fixed_val = ratio_aft
		GlobalValues.Quadrant.PORT: fixed_val = ratio_port
		GlobalValues.Quadrant.STARBOARD: fixed_val = ratio_starboard
	
	var rem := maxf(0.05, 1.0 - fixed_val)
	var other_sum: float = 0.0
	if fixed_quadrant != GlobalValues.Quadrant.FORE: other_sum += ratio_fore
	if fixed_quadrant != GlobalValues.Quadrant.AFT: other_sum += ratio_aft
	if fixed_quadrant != GlobalValues.Quadrant.PORT: other_sum += ratio_port
	if fixed_quadrant != GlobalValues.Quadrant.STARBOARD: other_sum += ratio_starboard
	
	if other_sum <= 0.001:
		other_sum = 0.001
	
	if fixed_quadrant != GlobalValues.Quadrant.FORE: ratio_fore = (ratio_fore / other_sum) * rem
	if fixed_quadrant != GlobalValues.Quadrant.AFT: ratio_aft = (ratio_aft / other_sum) * rem
	if fixed_quadrant != GlobalValues.Quadrant.PORT: ratio_port = (ratio_port / other_sum) * rem
	if fixed_quadrant != GlobalValues.Quadrant.STARBOARD: ratio_starboard = (ratio_starboard / other_sum) * rem

func _on_reset_balance_pressed() -> void:
	if not can_control_shields or not _is_ship_operational():
		return
	ratio_fore = 0.25
	ratio_aft = 0.25
	ratio_port = 0.25
	ratio_starboard = 0.25
	pad_vector = Vector2.ZERO
	if vector_pad and pad_handle:
		pad_handle.position = vector_pad.size * 0.5 - pad_handle.size * 0.5
	_log_action("Bilanciamento scudi ripristinato a valori simmetrici (25% per quadrante).")
	_refresh_ui_display()

# --- RICARICA RAPIDA D'EMERGENZA & ARMONICHE ---

func _on_emergency_boost_pressed() -> void:
	if not can_control_shields or not _is_ship_operational() or boost_cooldown_timer > 0.0:
		return
	
	var boost_amt: float = active_config.get("emergency_boost_amount", 75.0)
	var boost_mult: float = active_config.get("emergency_boost_multiplier", 2.5)
	var effective_boost := boost_amt * (boost_mult / 2.0)
	
	var base_max: float = active_config.get("max_capacity_per_quadrant", 250.0)
	var max_f := base_max * (ratio_fore / 0.25)
	var max_a := base_max * (ratio_aft / 0.25)
	var max_p := base_max * (ratio_port / 0.25)
	var max_s := base_max * (ratio_starboard / 0.25)
	
	shield_fore = minf(max_f, shield_fore + effective_boost * (ratio_fore / 0.25))
	shield_aft = minf(max_a, shield_aft + effective_boost * (ratio_aft / 0.25))
	shield_port = minf(max_p, shield_port + effective_boost * (ratio_port / 0.25))
	shield_starboard = minf(max_s, shield_starboard + effective_boost * (ratio_starboard / 0.25))
	
	boost_cooldown_timer = active_config.get("emergency_boost_cooldown", 8.0)
	if emergency_boost_button:
		emergency_boost_button.disabled = true
		emergency_boost_button.text = "⏳ BOOST (%.1fs)" % boost_cooldown_timer
	_log_action("⚡ Ricarica Rapida d'Emergenza erogata (+%.0f MW per quadrante). Picco 120 MW assorbito." % effective_boost)
	_refresh_ui_display()

func _on_phase_sync_toggled(toggled_on: bool) -> void:
	if not can_control_shields or not _is_ship_operational():
		return
	is_phase_synced = toggled_on
	var freq: float = active_config.get("harmonic_frequency", 440.0)
	if is_phase_synced:
		if phase_status_label:
			phase_status_label.text = "ARMONICHE: SINCRONIZZATE (%.1f Hz)" % freq
		_log_action("Armoniche di deflessione sincronizzate a %.1f Hz." % freq)
	else:
		if phase_status_label:
			phase_status_label.text = "ARMONICHE: ASINCRONE / DISATTIVE"
		_log_action("Armoniche di deflessione disattivate (efficienza ridotta).")
	_refresh_ui_display()

func _log_action(msg: String) -> void:
	if action_log_label:
		action_log_label.text = "[LOG] %s" % msg

# --- CONFIGURAZIONE .DAT & HOT-RELOADING ---

func _on_drive_file_event(rel_path: String) -> void:
	if "Programs/ShieldMatrix" in rel_path and rel_path.ends_with(".dat"):
		load_dat_configuration()

func load_dat_configuration() -> void:
	var cfg_primary := _parse_dat_file(CONFIG_PATH_PRIMARY)
	var cfg_fallback := _parse_dat_file(CONFIG_PATH_FALLBACK)
	var tune_primary := _parse_dat_file(TUNING_PATH_PRIMARY)
	var tune_fallback := _parse_dat_file(TUNING_PATH_FALLBACK)
	
	var merged_cfg := cfg_fallback.duplicate()
	for k in cfg_primary.keys():
		merged_cfg[k] = cfg_primary[k]
	
	var merged_tune := tune_fallback.duplicate()
	for k in tune_primary.keys():
		merged_tune[k] = tune_primary[k]
	
	if not merged_cfg.is_empty() or not merged_tune.is_empty():
		active_config["is_dat_loaded"] = true
	
	for k in merged_cfg.keys():
		active_config[k] = merged_cfg[k]
	for k in merged_tune.keys():
		active_config[k] = merged_tune[k]
	
	_apply_configuration()

func _apply_configuration() -> void:
	var max_cap: float = active_config.get("max_capacity_per_quadrant", 250.0)
	var freq: float = active_config.get("harmonic_frequency", 440.0)
	
	if dat_status_badge:
		if active_config.get("is_dat_loaded", false):
			dat_status_badge.text = "DAT: ATTIVO (Cap: %.0f | Freq: %.0fHz)" % [max_cap, freq]
		else:
			dat_status_badge.text = "DAT: DEFAULT"
	
	if phase_status_label:
		if is_phase_synced:
			phase_status_label.text = "ARMONICHE: SINCRONIZZATE (%.1f Hz)" % freq
		else:
			phase_status_label.text = "ARMONICHE: ASINCRONE / DISATTIVE"
	
	_refresh_ui_display()

func _is_ship_operational() -> bool:
	if SpaceWorldManager and SpaceWorldManager.has_method("is_ship_connected"):
		return SpaceWorldManager.is_ship_connected()
	if NetworkManager and NetworkManager.has_method("is_ship_connected"):
		return NetworkManager.is_ship_connected()
	return false

func _on_ship_connection_changed(_is_connected: bool) -> void:
	_update_connection_state()

func _on_mission_started(_role: String = "", _is_solo: bool = false) -> void:
	_update_connection_state()

func _on_mission_ended() -> void:
	_update_connection_state()

func _update_connection_state() -> void:
	var operational := _is_ship_operational()
	if disconnected_overlay:
		disconnected_overlay.visible = not operational
	
	if status_badge:
		if operational:
			status_badge.text = "● MATRICE SCUDI ONLINE"
			status_badge.modulate = Color(0.3, 1.0, 0.4)
		else:
			status_badge.text = "○ SISTEMI OFFLINE"
			status_badge.modulate = Color(1.0, 0.3, 0.3)
	
	set_process(operational)
	set_process_input(operational)
	if operational:
		_refresh_ui_display()

func _on_player_role_changed(_peer_id: int, _new_role: String) -> void:
	_update_permissions()

func _update_permissions() -> void:
	var my_role := ""
	var is_solo := false
	if NetworkManager:
		my_role = NetworkManager.get_local_player_role()
		is_solo = NetworkManager.is_solo_mode
	
	can_control_shields = (
		is_solo or
		my_role == "Ingegnere" or
		my_role == "Capitano" or
		my_role == "Stagista" or
		my_role == ""
	)
	
	if role_badge:
		var display_role := my_role if not my_role.is_empty() else ("Solo" if is_solo else "N/A")
		if can_control_shields:
			role_badge.text = "RUOLO: %s (CONTROLLO COMPLETO)" % display_role
			role_badge.modulate = Color(0.4, 0.9, 1.0)
		else:
			role_badge.text = "RUOLO: %s (SOLA TELEMETRIA)" % display_role
			role_badge.modulate = Color(1.0, 0.75, 0.3)
	
	# Abilita o disabilita controlli
	if emergency_boost_button:
		emergency_boost_button.disabled = not can_control_shields or boost_cooldown_timer > 0.0
	if reset_balance_button:
		reset_balance_button.disabled = not can_control_shields
	if phase_sync_switch:
		phase_sync_switch.disabled = not can_control_shields
	if balance_fore_slider:
		balance_fore_slider.editable = can_control_shields
	if balance_aft_slider:
		balance_aft_slider.editable = can_control_shields
	if balance_port_slider:
		balance_port_slider.editable = can_control_shields
	if balance_starboard_slider:
		balance_starboard_slider.editable = can_control_shields
	if reload_all_defenses_button:
		reload_all_defenses_button.disabled = not can_control_shields
	
	for dev_id in _device_cards:
		if is_instance_valid(_device_cards[dev_id]):
			_device_cards[dev_id].set_permissions(can_control_shields)
