extends Control
class_name PowerGridApp

## Applicazione GodotOS per il monitoraggio e reindirizzamento della rete elettrica della nave.
## Illustra una mappa stilizzata 2D con dispositivi, snodi (biforcazioni), flussi energetici e cortocircuiti.
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
@onready var map_canvas: PowerGridMapCanvas = get_node_or_null("%MapCanvas")

# Inspector UI
@onready var inspector_title_label: Label = get_node_or_null("%InspectorTitleLabel")
@onready var inspector_desc_label: Label = get_node_or_null("%InspectorDescLabel")
@onready var inspector_inputs_label: Label = get_node_or_null("%InspectorInputsLabel")
@onready var inspector_regime_label: Label = get_node_or_null("%InspectorRegimeLabel")
@onready var inspector_regime_bar: ProgressBar = get_node_or_null("%InspectorRegimeBar")
@onready var btn_switch_selected_junction: Button = get_node_or_null("%BtnSwitchSelectedJunction")

# Mini-Terminal UI
@onready var terminal_output: RichTextLabel = get_node_or_null("%TerminalOutput")
@onready var terminal_input: LineEdit = get_node_or_null("%TerminalInput")
@onready var btn_autobalance: Button = get_node_or_null("%BtnAutobalance")
@onready var btn_diagnostics: Button = get_node_or_null("%BtnDiagnostics")
@onready var reload_config_button: Button = get_node_or_null("%ReloadConfigButton")

var parent_window: FakeWindow = null
var can_control: bool = true

# Parametri runtime caricati dai file .dat protetti
var active_config: Dictionary = {
	"reactor_output_mw": 1200.0,
	"aux_generator_mw": 450.0,
	"junction_switch_delay": 0.25,
	"overload_threshold_pct": 110.0,
	"reroute_efficiency_loss": 0.05,
	"breaker_trip_threshold": 1.4,
	"short_circuit_damping": 0.85,
	"auto_reroute_on_short": false,
	"power_efficiency_mult": 1.0,
	"backup_line_conductivity": 0.95,
	"switch_rate_hz": 10.0,
	"regime_boost": 1.0,
	"overclock_tolerance": 1.2,
	"is_dat_loaded": false
}

# Strutture dati Rete Elettrica
var devices: Dictionary = {}
var junctions: Dictionary = {}
var conduits: Array[Dictionary] = []
var selected_device_id: String = ""
var selected_junction_id: String = ""
var terminal_history: Array[String] = []
var terminal_history_index: int = -1
var total_grid_efficiency: float = 1.0
var total_power_draw_mw: float = 0.0
var total_power_gen_mw: float = 1650.0
var active_short_circuits: Array[Dictionary] = []
var anim_pulse_time: float = 0.0

func _ready() -> void:
	_configure_window()
	_init_grid_topology()
	_setup_ui_events()
	load_dat_configuration()
	_connect_system_signals()
	_update_connection_state()
	_update_permissions()
	update_power_simulation()
	_print_terminal_welcome()

func _process(delta: float) -> void:
	anim_pulse_time += delta
	if map_canvas and is_instance_valid(map_canvas):
		map_canvas.queue_redraw()

func _configure_window() -> void:
	custom_minimum_size = DEFAULT_WINDOW_SIZE
	call_deferred("_setup_parent_window")

func _setup_parent_window() -> void:
	parent_window = _find_parent_window()
	if parent_window:
		parent_window.size = DEFAULT_WINDOW_SIZE
		parent_window.custom_minimum_size = Vector2(600, 450)
		parent_window.title_text = APP_TITLE
		var title_label = parent_window.get_node_or_null("Top Bar/Title Text")
		if title_label:
			title_label.text = "[center]" + APP_TITLE

func _find_parent_window() -> FakeWindow:
	var p: Node = get_parent()
	while p != null:
		if p is FakeWindow:
			return p as FakeWindow
		p = p.get_parent()
	return null

func _setup_ui_events() -> void:
	if terminal_input:
		terminal_input.text_submitted.connect(_on_terminal_text_submitted)
	if btn_autobalance:
		btn_autobalance.pressed.connect(func(): execute_terminal_command("autobalance"))
	if btn_diagnostics:
		btn_diagnostics.pressed.connect(func(): execute_terminal_command("diag"))
	if reload_config_button:
		reload_config_button.pressed.connect(_on_reload_config_pressed)
	if btn_switch_selected_junction:
		btn_switch_selected_junction.pressed.connect(_on_switch_selected_junction_pressed)

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

# --- TOPOLOGIA DELLA RETE ELETTRICA ---
func _init_grid_topology() -> void:
	devices.clear()
	junctions.clear()
	conduits.clear()
	
	# Dispositivi di bordo (Fonti di alimentazione e Utillizzatori con input 1, 2 o 3)
	devices["reactor_main"] = {
		"id": "reactor_main",
		"name": "Reattore Principale",
		"sector": "Nucleo Reattore & Fusione",
		"pos": Vector2(300, 255),
		"is_generator": true,
		"power_mw": 1200.0,
		"inputs_count": 0,
		"inputs_powered": 0,
		"regime": 1.0,
		"desc": "Generatore primario a fusione quantistica. Alimenta gli snodi dorsali e ventrali."
	}
	
	devices["aux_generator"] = {
		"id": "aux_generator",
		"name": "Generatore Ausiliario",
		"sector": "Baia di Carico Principale",
		"pos": Vector2(440, 240),
		"is_generator": true,
		"power_mw": 450.0,
		"inputs_count": 0,
		"inputs_powered": 0,
		"regime": 1.0,
		"desc": "Celle energetiche ausiliarie di riserva. Alimentano il settore tribordo e i canali di bypass."
	}
	
	devices["bridge_nav"] = {
		"id": "bridge_nav",
		"name": "Ponte di Comando",
		"sector": "Ponte di Comando",
		"pos": Vector2(300, 75),
		"is_generator": false,
		"power_mw": 150.0,
		"inputs_count": 2, # 2 input: se 2 -> 100%, se 1 -> 50%, se 0 -> 0%
		"inputs_powered": 0,
		"regime": 0.0,
		"desc": "Console di navigazione e comando centrale. Richiede 2 linee di alimentazione per piena operatività."
	}
	
	devices["sensors_radar"] = {
		"id": "sensors_radar",
		"name": "Sensori & Avionica",
		"sector": "Sensori & Avionica",
		"pos": Vector2(160, 145),
		"is_generator": false,
		"power_mw": 120.0,
		"inputs_count": 1, # 1 input: se 1 -> 100%, se 0 -> 0%
		"inputs_powered": 0,
		"regime": 0.0,
		"desc": "Array sensori a lungo raggio, scanner EM e telemetria spaziale."
	}
	
	devices["comms_ew"] = {
		"id": "comms_ew",
		"name": "Comunicazioni & EW",
		"sector": "Comunicazioni & EW",
		"pos": Vector2(440, 145),
		"is_generator": false,
		"power_mw": 120.0,
		"inputs_count": 1, # 1 input: se 1 -> 100%, se 0 -> 0%
		"inputs_powered": 0,
		"regime": 0.0,
		"desc": "Trasmettitore subspaziale e contromisure di guerra elettronica."
	}
	
	devices["armory_defense"] = {
		"id": "armory_defense",
		"name": "Armeria & Torrette",
		"sector": "Armeria & Sicurezza",
		"pos": Vector2(300, 165),
		"is_generator": false,
		"power_mw": 250.0,
		"inputs_count": 2, # 2 input: se 2 -> 100%, se 1 -> 50%, se 0 -> 0%
		"inputs_powered": 0,
		"regime": 0.0,
		"desc": "Sistemi di puntamento armi pesanti, torrette difensive di prossimità e blocco armeria."
	}
	
	devices["life_support"] = {
		"id": "life_support",
		"name": "Supporto Vitale",
		"sector": "Alloggi Equipaggio",
		"pos": Vector2(160, 235),
		"is_generator": false,
		"power_mw": 200.0,
		"inputs_count": 2, # 2 input: se 2 -> 100%, se 1 -> 50%, se 0 -> 0%
		"inputs_powered": 0,
		"regime": 0.0,
		"desc": "Filtrazione atmosfera, gravità artificiale e regolazione termica alloggi."
	}
	
	devices["cargo_drone_bay"] = {
		"id": "cargo_drone_bay",
		"name": "Baia Drone & CCTV",
		"sector": "Baia di Carico Principale",
		"pos": Vector2(440, 205),
		"is_generator": false,
		"power_mw": 90.0,
		"inputs_count": 1, # 1 input: se 1 -> 100%, se 0 -> 0%
		"inputs_powered": 0,
		"regime": 0.0,
		"desc": "Docking station del Duct Drone e matrice telecamere CCTV esterne."
	}
	
	devices["shields_deflector"] = {
		"id": "shields_deflector",
		"name": "Scudi Deflettori",
		"sector": "Scudi Deflettori",
		"pos": Vector2(235, 175),
		"is_generator": false,
		"power_mw": 400.0,
		"inputs_count": 3, # 3 input: se 3 -> 100%, se 2 -> 66%, se 1 -> 33%, se 0 -> 0%
		"inputs_powered": 0,
		"regime": 0.0,
		"desc": "Generatori di campo deflettore prua, poppa e matrice di sovralimentazione."
	}
	
	devices["engines_sublight"] = {
		"id": "engines_sublight",
		"name": "Motori Principali",
		"sector": "Sala Motori Principale",
		"pos": Vector2(300, 360),
		"is_generator": false,
		"power_mw": 600.0,
		"inputs_count": 3, # 3 input: se 3 -> 100%, se 2 -> 66%, se 1 -> 33%, se 0 -> 0%
		"inputs_powered": 0,
		"regime": 0.0,
		"desc": "Propulsione sub-luce (Propulsore SX, DX e canale termico di spinta centrale)."
	}
	
	devices["rcs_thrusters"] = {
		"id": "rcs_thrusters",
		"name": "Sistema RCS",
		"sector": "Pod RCS",
		"pos": Vector2(300, 300),
		"is_generator": false,
		"power_mw": 160.0,
		"inputs_count": 2, # 2 input: se 2 -> 100%, se 1 -> 50%, se 0 -> 0%
		"inputs_powered": 0,
		"regime": 0.0,
		"desc": "Ugelli di manovra laterali RCS Babordo (SX) e Tribordo (DX)."
	}
	
	# Snodi con Biforcazioni (2 o più uscite selezionabili, incluse connessioni morte/inutilizzate)
	junctions["J1"] = {
		"id": "J1",
		"name": "Snodo Reattore Dorsale",
		"pos": Vector2(300, 215),
		"input_source": "reactor_main",
		"active_branch": 0,
		"branches": [
			{"name": "Linea Dorsale Prua (J2)", "target_type": "junction", "target_id": "J2", "line_id": "L_J1_B0", "to_pos": Vector2(300, 125)},
			{"name": "Bypass Babordo (J3)", "target_type": "junction", "target_id": "J3", "line_id": "L_J1_B1", "to_pos": Vector2(160, 185)},
			{"name": "Terminazione Ausiliaria Morta", "target_type": "dead_end", "target_id": "DEAD_1", "line_id": "L_J1_B2", "to_pos": Vector2(360, 215)}
		]
	}
	
	junctions["J2"] = {
		"id": "J2",
		"name": "Snodo Prua & Avionica",
		"pos": Vector2(300, 125),
		"input_source": "J1_B0",
		"active_branch": 0,
		"branches": [
			{"name": "Ponte Nav (In1) & Armeria (In1)", "target_type": "device_multi", "target_ids": ["bridge_nav:0", "armory_defense:0"], "line_id": "L_J2_B0", "to_pos": Vector2(300, 75)},
			{"name": "Sensori & Avionica (In1)", "target_type": "device", "target_id": "sensors_radar:0", "line_id": "L_J2_B1", "to_pos": Vector2(160, 145)},
			{"name": "Comunicazioni & EW (In1)", "target_type": "device", "target_id": "comms_ew:0", "line_id": "L_J2_B2", "to_pos": Vector2(440, 145)}
		]
	}
	
	junctions["J3"] = {
		"id": "J3",
		"name": "Snodo Babordo & Difesa",
		"pos": Vector2(160, 185),
		"input_source": "J1_B1",
		"active_branch": 0,
		"branches": [
			{"name": "Supporto Vitale (In1)", "target_type": "device", "target_id": "life_support:0", "line_id": "L_J3_B0", "to_pos": Vector2(160, 235)},
			{"name": "Scudi Deflettori (In1 - Prua)", "target_type": "device", "target_id": "shields_deflector:0", "line_id": "L_J3_B1", "to_pos": Vector2(235, 175)},
			{"name": "Bypass Manutenzione SX (J8)", "target_type": "junction", "target_id": "J8", "line_id": "L_J3_B2", "to_pos": Vector2(160, 320)}
		]
	}
	
	junctions["J4"] = {
		"id": "J4",
		"name": "Snodo Reattore Ventrale",
		"pos": Vector2(300, 295),
		"input_source": "reactor_main",
		"active_branch": 0,
		"branches": [
			{"name": "Linea Poppa Motori (J5)", "target_type": "junction", "target_id": "J5", "line_id": "L_J4_B0", "to_pos": Vector2(300, 325)},
			{"name": "Scudi Sovralimentazione (In3)", "target_type": "device", "target_id": "shields_deflector:2", "line_id": "L_J4_B1", "to_pos": Vector2(235, 175)},
			{"name": "Scarico Termico Morto", "target_type": "dead_end", "target_id": "DEAD_2", "line_id": "L_J4_B2", "to_pos": Vector2(240, 295)}
		]
	}
	
	junctions["J5"] = {
		"id": "J5",
		"name": "Snodo Propulsione Poppa",
		"pos": Vector2(300, 325),
		"input_source": "J4_B0",
		"active_branch": 0,
		"branches": [
			{"name": "Motore SX (In1) & Termico (In3)", "target_type": "device_multi", "target_ids": ["engines_sublight:0", "engines_sublight:2"], "line_id": "L_J5_B0", "to_pos": Vector2(300, 360)},
			{"name": "Motore DX (In2)", "target_type": "device", "target_id": "engines_sublight:1", "line_id": "L_J5_B1", "to_pos": Vector2(330, 360)},
			{"name": "Scudi Deflettori Poppa (In2)", "target_type": "device", "target_id": "shields_deflector:1", "line_id": "L_J5_B2", "to_pos": Vector2(235, 175)}
		]
	}
	
	junctions["J6"] = {
		"id": "J6",
		"name": "Snodo Ausiliario Tribordo",
		"pos": Vector2(440, 185),
		"input_source": "J7_B0",
		"active_branch": 0,
		"branches": [
			{"name": "Baia Drone (In1) & Comms (In1)", "target_type": "device_multi", "target_ids": ["cargo_drone_bay:0", "comms_ew:0"], "line_id": "L_J6_B0", "to_pos": Vector2(440, 205)},
			{"name": "RCS Tribordo DX (In2)", "target_type": "device", "target_id": "rcs_thrusters:1", "line_id": "L_J6_B1", "to_pos": Vector2(300, 300)},
			{"name": "Armeria Secondaria (In2)", "target_type": "device", "target_id": "armory_defense:1", "line_id": "L_J6_B2", "to_pos": Vector2(300, 165)}
		]
	}
	
	junctions["J7"] = {
		"id": "J7",
		"name": "Snodo Generatore Riserva",
		"pos": Vector2(440, 260),
		"input_source": "aux_generator",
		"active_branch": 0,
		"branches": [
			{"name": "Canale Tribordo (J6)", "target_type": "junction", "target_id": "J6", "line_id": "L_J7_B0", "to_pos": Vector2(440, 185)},
			{"name": "Bypass Supporto Vitale (In2)", "target_type": "device", "target_id": "life_support:1", "line_id": "L_J7_B1", "to_pos": Vector2(160, 235)},
			{"name": "Backup Avionica Ponte (In2)", "target_type": "device", "target_id": "bridge_nav:1", "line_id": "L_J7_B2", "to_pos": Vector2(300, 75)}
		]
	}
	
	junctions["J8"] = {
		"id": "J8",
		"name": "Snodo Bypass Manutenzione SX",
		"pos": Vector2(160, 320),
		"input_source": "J3_B2",
		"active_branch": 0,
		"branches": [
			{"name": "Motore SX Ausiliario (In1)", "target_type": "device", "target_id": "engines_sublight:0", "line_id": "L_J8_B0", "to_pos": Vector2(270, 360)},
			{"name": "RCS Babordo SX (In1)", "target_type": "device", "target_id": "rcs_thrusters:0", "line_id": "L_J8_B1", "to_pos": Vector2(300, 300)},
			{"name": "Condotto Morto Manutenzione", "target_type": "dead_end", "target_id": "DEAD_3", "line_id": "L_J8_B2", "to_pos": Vector2(100, 340)}
		]
	}
	
	_rebuild_conduits_list()

func _rebuild_conduits_list() -> void:
	conduits.clear()
	
	# Linee dirette dai generatori agli snodi primari
	conduits.append({
		"id": "L_REC_J1",
		"name": "Dorsale Reattore",
		"from": devices["reactor_main"]["pos"],
		"to": junctions["J1"]["pos"],
		"is_powered": true,
		"is_shorted": false,
		"is_active_branch": true,
		"source": "reactor_main",
		"target": "J1"
	})
	
	conduits.append({
		"id": "L_REC_J4",
		"name": "Ventrale Reattore",
		"from": devices["reactor_main"]["pos"],
		"to": junctions["J4"]["pos"],
		"is_powered": true,
		"is_shorted": false,
		"is_active_branch": true,
		"source": "reactor_main",
		"target": "J4"
	})
	
	conduits.append({
		"id": "L_AUX_J7",
		"name": "Linea Ausiliaria Riserva",
		"from": devices["aux_generator"]["pos"],
		"to": junctions["J7"]["pos"],
		"is_powered": true,
		"is_shorted": false,
		"is_active_branch": true,
		"source": "aux_generator",
		"target": "J7"
	})
	
	# Linee delle biforcazioni per ciascuno snodo
	for j_id in junctions:
		var j: Dictionary = junctions[j_id]
		var active_idx: int = int(j.get("active_branch", 0))
		var branches: Array = j.get("branches", [])
		for b_idx in range(branches.size()):
			var br: Dictionary = branches[b_idx]
			conduits.append({
				"id": br["line_id"],
				"name": br["name"],
				"from": j["pos"],
				"to": br["to_pos"],
				"is_powered": false,
				"is_shorted": false,
				"is_active_branch": (b_idx == active_idx),
				"is_dead_end": (br["target_type"] == "dead_end"),
				"source": j_id,
				"branch_index": b_idx,
				"target_type": br["target_type"],
				"target_id": br.get("target_id", ""),
				"target_ids": br.get("target_ids", [])
			})

# --- SIMULAZIONE FLUSSI ENERGETICI & REGIME ---
func update_power_simulation() -> void:
	# 1. Rileva e associa i cortocircuiti attivi di Duct Drone
	_update_active_short_circuits()
	
	# 2. Reset stato linee e input dispositivi
	for c in conduits:
		c["is_powered"] = false
		c["is_shorted"] = false
		
		# Controlla se la linea interseca un cortocircuito
		for sc in active_short_circuits:
			var sc_pos: Vector2 = sc.get("pos", Vector2.ZERO)
			var dist := _distance_to_segment(sc_pos, c["from"], c["to"])
			if dist <= 38.0:
				c["is_shorted"] = true
				break
	
	for dev_id in devices:
		var dev: Dictionary = devices[dev_id]
		dev["inputs_powered"] = 0
		if not dev["is_generator"]:
			dev["regime"] = 0.0
	
	# 3. Propagazione energia dai generatori attraverso linee attive non interrotte
	var powered_sources: Array[String] = ["reactor_main", "aux_generator"]
	
	# Imposta alimentazione linee primarie
	for c in conduits:
		if c["source"] in powered_sources:
			if not c["is_shorted"]:
				c["is_powered"] = true
	
	# Risolvi la cascata degli snodi in ordine topologico
	var junction_eval_order: Array[String] = ["J1", "J4", "J7", "J2", "J3", "J5", "J6", "J8"]
	
	for j_id in junction_eval_order:
		if not junctions.has(j_id):
			continue
		var j: Dictionary = junctions[j_id]
		var is_j_powered: bool = false
		
		# Determina se lo snodo riceve corrente a monte
		if j["input_source"] == "reactor_main" or j["input_source"] == "aux_generator":
			for c in conduits:
				if c["target"] == j_id and c["is_powered"] and not c["is_shorted"]:
					is_j_powered = true
					break
		else:
			# Riceve corrente da una linea di un altro snodo
			var upstream_line_id: String = "L_" + str(j["input_source"])
			for c in conduits:
				if c["id"] == upstream_line_id and c["is_powered"] and not c["is_shorted"]:
					is_j_powered = true
					break
		
		var active_idx: int = int(j.get("active_branch", 0))
		var branches: Array = j.get("branches", [])
		
		for b_idx in range(branches.size()):
			var br: Dictionary = branches[b_idx]
			var line_id: String = br["line_id"]
			var line_dict: Dictionary = {}
			for c in conduits:
				if c["id"] == line_id:
					line_dict = c
					break
			
			if line_dict.is_empty():
				continue
			
			var is_active_branch: bool = (b_idx == active_idx)
			line_dict["is_active_branch"] = is_active_branch
			
			if is_j_powered and is_active_branch and not line_dict["is_shorted"]:
				line_dict["is_powered"] = true
				
				# Applica potenza ai target
				if br["target_type"] == "device":
					_apply_power_to_device_port(br["target_id"])
				elif br["target_type"] == "device_multi":
					for target_str in br.get("target_ids", []):
						_apply_power_to_device_port(target_str)
	
	# 4. Calcolo Regimi Dispositivi secondo la formula di specifica:
	# - 1 input: 1 powered -> 100% (1.0), 0 -> 0%
	# - 2 input: 2 powered -> 100% (1.0), 1 -> 50% (0.5), 0 -> 0%
	# - 3 input: 3 powered -> 100% (1.0), 2 -> 66% (0.66), 1 -> 33% (0.33), 0 -> 0%
	var total_regimes: float = 0.0
	var consumer_count: int = 0
	
	for dev_id in devices:
		var dev: Dictionary = devices[dev_id]
		if dev["is_generator"]:
			dev["regime"] = 1.0
			continue
		
		consumer_count += 1
		var total_in: int = int(dev.get("inputs_count", 1))
		var pow_in: int = int(dev.get("inputs_powered", 0))
		
		if total_in == 1:
			dev["regime"] = 1.0 if pow_in >= 1 else 0.0
		elif total_in == 2:
			if pow_in >= 2:
				dev["regime"] = 1.0
			elif pow_in == 1:
				dev["regime"] = 0.5
			else:
				dev["regime"] = 0.0
		elif total_in == 3:
			if pow_in >= 3:
				dev["regime"] = 1.0
			elif pow_in == 2:
				dev["regime"] = 0.66
			elif pow_in == 1:
				dev["regime"] = 0.33
			else:
				dev["regime"] = 0.0
		
		# Applicazione tuning boost se presente
		var boost: float = float(active_config.get("regime_boost", 1.0))
		if dev["regime"] > 0.0:
			dev["regime"] = clampf(dev["regime"] * boost, 0.0, 1.0)
		
		total_regimes += dev["regime"]
	
	if consumer_count > 0:
		total_grid_efficiency = total_regimes / float(consumer_count)
	else:
		total_grid_efficiency = 1.0
	
	_update_ui_telemetry()
	if map_canvas and is_instance_valid(map_canvas):
		map_canvas.queue_redraw()

func _apply_power_to_device_port(target_str: String) -> void:
	var parts := target_str.split(":")
	var dev_id := parts[0]
	if devices.has(dev_id):
		devices[dev_id]["inputs_powered"] += 1

func _update_active_short_circuits() -> void:
	active_short_circuits.clear()
	if SpaceWorldManager and SpaceWorldManager.has_method("get_ship_damages"):
		var all_damages: Array = SpaceWorldManager.get_ship_damages()
		for dmg in all_damages:
			if dmg.get("type", "") == "short_circuit" and not dmg.get("repaired", false):
				active_short_circuits.append(dmg)

func _update_ui_telemetry() -> void:
	if total_power_label:
		var eff_mw := (1200.0 + 450.0) * total_grid_efficiency
		total_power_label.text = "%d / %d MW" % [int(eff_mw), int(1200.0 + 450.0)]
	
	if efficiency_label:
		var eff_pct := int(total_grid_efficiency * 100.0)
		efficiency_label.text = "%d%%" % eff_pct
		if eff_pct >= 90:
			efficiency_label.modulate = Color(0.2, 1.0, 0.5)
		elif eff_pct >= 50:
			efficiency_label.modulate = Color(1.0, 0.85, 0.2)
		else:
			efficiency_label.modulate = Color(1.0, 0.3, 0.2)
	
	if damage_count_label:
		var count := active_short_circuits.size()
		damage_count_label.text = "%d CORTI" % count
		damage_count_label.modulate = Color(1.0, 0.3, 0.2) if count > 0 else Color(0.4, 1.0, 0.6)
	
	_update_inspector_ui()

func _update_inspector_ui() -> void:
	if selected_junction_id != "" and junctions.has(selected_junction_id):
		var j: Dictionary = junctions[selected_junction_id]
		var active_idx: int = int(j.get("active_branch", 0))
		var branches: Array = j.get("branches", [])
		var curr_br: Dictionary = branches[active_idx] if active_idx < branches.size() else {}
		
		if inspector_title_label:
			inspector_title_label.text = "%s [%s]" % [j["name"], j["id"]]
		if inspector_desc_label:
			inspector_desc_label.text = "Snodo di biforcazione. Uscita attiva: %d/%d (%s)" % [active_idx + 1, branches.size(), curr_br.get("name", "N/D")]
		if inspector_inputs_label:
			inspector_inputs_label.text = "Alimentazione: %s" % j["input_source"]
		if inspector_regime_label:
			inspector_regime_label.text = "STATO: OPERATIVO"
		if inspector_regime_bar:
			inspector_regime_bar.value = 100.0
		if btn_switch_selected_junction:
			btn_switch_selected_junction.visible = true
			btn_switch_selected_junction.text = "⚡ Commuta Snodo (-> Ramo %d)" % (((active_idx + 1) % branches.size()) + 1)
			btn_switch_selected_junction.disabled = not can_control
	
	elif selected_device_id != "" and devices.has(selected_device_id):
		var dev: Dictionary = devices[selected_device_id]
		var total_in: int = int(dev.get("inputs_count", 1))
		var pow_in: int = int(dev.get("inputs_powered", 0))
		var regime_pct: int = int(dev.get("regime", 0.0) * 100.0)
		
		if inspector_title_label:
			inspector_title_label.text = "%s" % dev["name"]
		if inspector_desc_label:
			inspector_desc_label.text = dev.get("desc", "")
		if inspector_inputs_label:
			inspector_inputs_label.text = "Input Connessi: %d / %d" % [pow_in, total_in]
		if inspector_regime_label:
			var reg_str := "%d%%" % regime_pct
			if regime_pct == 100:
				reg_str += " [OTTIMALE]"
			elif regime_pct > 0:
				reg_str += " [REGIME RIDOTTO]"
			else:
				reg_str += " [OFFLINE / INTERROTTO]"
			inspector_regime_label.text = reg_str
		if inspector_regime_bar:
			inspector_regime_bar.value = regime_pct
		if btn_switch_selected_junction:
			btn_switch_selected_junction.visible = false
	else:
		if inspector_title_label:
			inspector_title_label.text = "Seleziona Snodo / Dispositivo"
		if inspector_desc_label:
			inspector_desc_label.text = "Clicca su uno snodo [J1-J8] per commutare la biforcazione, oppure su un dispositivo per ispezionarne gli ingressi."
		if inspector_inputs_label:
			inspector_inputs_label.text = "Input: --"
		if inspector_regime_label:
			inspector_regime_label.text = "Regime: --"
		if inspector_regime_bar:
			inspector_regime_bar.value = int(total_grid_efficiency * 100.0)
		if btn_switch_selected_junction:
			btn_switch_selected_junction.visible = false

# --- AZIONI E COMANDI SNODI ---
func switch_junction(junction_id: String, branch_index: int = -1) -> bool:
	if not can_control:
		_print_terminal("[color=#ff5555]ACCESSO NEGATO: Solo Ingegnere o Capitano possono commutare gli snodi.[/color]")
		return false
	
	if not junctions.has(junction_id):
		_print_terminal("[color=#ff5555]ERRORE: Snodo %s non trovato.[/color]" % junction_id)
		return false
	
	var j: Dictionary = junctions[junction_id]
	var branches: Array = j.get("branches", [])
	if branches.size() == 0:
		return false
	
	var current_idx: int = int(j.get("active_branch", 0))
	var new_idx: int = 0
	if branch_index >= 0 and branch_index < branches.size():
		new_idx = branch_index
	else:
		new_idx = (current_idx + 1) % branches.size()
	
	j["active_branch"] = new_idx
	_rebuild_conduits_list()
	update_power_simulation()
	
	var br_name: String = branches[new_idx].get("name", "N/D")
	_print_terminal("[color=#00e5ff]SNODO %s COMMUTATO -> Ramo %d: %s[/color]" % [junction_id, new_idx + 1, br_name])
	
	# Sincronizzazione multiplayer
	var nm := _get_net_mgr()
	if nm and nm.get("is_connected_to_network"):
		if nm.get("is_host"):
			_rpc_sync_junction_switch.rpc(junction_id, new_idx)
		else:
			_rpc_client_switch_junction.rpc_id(1, junction_id, new_idx)
	
	return true

func autobalance_grid() -> void:
	if not can_control:
		_print_terminal("[color=#ff5555]ACCESSO NEGATO: Solo Ingegnere o Capitano possono eseguire l'autobilanciamento.[/color]")
		return
	
	_print_terminal("[color=#ffaa00]Calcolo matrice di instradamento ottimale in corso...[/color]")
	
	# Risolvi le combinazioni di biforcazioni per massimizzare il regime complessivo
	var j_keys := junctions.keys()
	var best_score: float = -1.0
	var best_settings: Dictionary = {}
	
	# Salva configurazione attuale
	var orig_settings: Dictionary = {}
	for jk in j_keys:
		orig_settings[jk] = junctions[jk]["active_branch"]
	
	# Strategia euristica intelligente basata sui danni
	for jk in j_keys:
		var j: Dictionary = junctions[jk]
		var branches: Array = j.get("branches", [])
		for b_idx in range(branches.size()):
			j["active_branch"] = b_idx
			_rebuild_conduits_list()
			update_power_simulation()
			
			if total_grid_efficiency > best_score:
				best_score = total_grid_efficiency
				for k in j_keys:
					best_settings[k] = junctions[k]["active_branch"]
	
	# Applica la configurazione migliore trovata
	for jk in best_settings:
		junctions[jk]["active_branch"] = best_settings[jk]
	
	_rebuild_conduits_list()
	update_power_simulation()
	
	_print_terminal("[color=#00ff88]✔ Autobilanciamento completato! Efficienza stimata: %d%%[/color]" % int(total_grid_efficiency * 100.0))

# --- GESTIONE MINI-TERMINALE ---
func _print_terminal_welcome() -> void:
	_print_terminal("[color=#00e5ff]=== DARK NOVA POWER GRID OS v1.0.4 ===[/color]")
	_print_terminal("[color=#88bbdd]Console di controllo instradamento flussi energetici.[/color]")
	_print_terminal("[color=#88bbdd]Digita [color=#ffffaa]help[/color] per la guida comandi, o usa [color=#ffffaa]switch <snodo> <ramo>[/color].[/color]\n")

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
	
	var verb := parts[0].to_lower()
	
	match verb:
		"help", "?":
			_print_terminal("[color=#ffffaa]--- COMANDI DISPONIBILI ---[/color]")
			_print_terminal("[color=#00e5ff]switch <snodo> [ramo][/color] : Commuta lo snodo specificato (es. 'switch J1 2' o 'switch J3')")
			_print_terminal("[color=#00e5ff]status / stat[/color]        : Mostra il report completo della rete elettrica e dei dispositivi")
			_print_terminal("[color=#00e5ff]devices / dev[/color]        : Elenco dettagliato dei dispositivi, ingressi e regimi attivi")
			_print_terminal("[color=#00e5ff]junctions / junc[/color]     : Elenco degli snodi di biforcazione e rami attivi")
			_print_terminal("[color=#00e5ff]reroute <dispositivo>[/color] : Trova un instradamento alternativo per il dispositivo specificato")
			_print_terminal("[color=#00e5ff]autobalance / auto[/color]   : Calcola automaticamente il miglior instradamento contro i guasti")
			_print_terminal("[color=#00e5ff]diag / scan[/color]          : Scansiona la rete per rilevare linee interrotte o in cortocircuito")
			_print_terminal("[color=#00e5ff]config[/color]               : Mostra i parametri di calibrazione attivi (.dat)")
			_print_terminal("[color=#00e5ff]reload[/color]               : Ricarica i file di configurazione .dat")
			_print_terminal("[color=#00e5ff]clear / cls[/color]          : Pulisce la schermata del terminale")
		
		"status", "stat":
			_print_terminal("[color=#ffffaa]=== STATO RETE ELETTRICA ===[/color]")
			_print_terminal("Potenza Generata: %d MW | Efficienza Globale: %d%%" % [int(total_power_gen_mw), int(total_grid_efficiency * 100.0)])
			_print_terminal("Cortocircuiti attivi rilevati: %d" % active_short_circuits.size())
			for dev_id in devices:
				var d: Dictionary = devices[dev_id]
				if not d["is_generator"]:
					var reg := int(d.get("regime", 0.0) * 100.0)
					var col := "#00ff88" if reg == 100 else ("#ffbb00" if reg > 0 else "#ff4444")
					_print_terminal("  • %s: [color=%s]%d%%[/color] (In: %d/%d)" % [d["name"], col, reg, d["inputs_powered"], d["inputs_count"]])
		
		"devices", "dev":
			_print_terminal("[color=#ffffaa]=== DISPOSITIVI DI BORDO ===[/color]")
			for dev_id in devices:
				var d: Dictionary = devices[dev_id]
				if d["is_generator"]:
					_print_terminal("  [GEN] %s (%s) - OUTPUT: %d MW" % [d["name"], d["id"], int(d.get("power_mw", 0.0))])
				else:
					var reg := int(d.get("regime", 0.0) * 100.0)
					_print_terminal("  [%s] %s - Regime: %d%% | Ingressi Alimentati: %d/%d" % [d["id"], d["name"], reg, d["inputs_powered"], d["inputs_count"]])
		
		"junctions", "junc":
			_print_terminal("[color=#ffffaa]=== SNODI E BIFORCAZIONI ===[/color]")
			for j_id in junctions:
				var j: Dictionary = junctions[j_id]
				var cur := int(j.get("active_branch", 0))
				var branches: Array = j.get("branches", [])
				_print_terminal("  • [%s] %s (Attivo: Ramo %d/%d)" % [j_id, j["name"], cur + 1, branches.size()])
				for b_idx in range(branches.size()):
					var mark := "-> [ATTIVO]" if b_idx == cur else "   [OFF]"
					_print_terminal("      %s Ramo %d: %s" % [mark, b_idx + 1, branches[b_idx]["name"]])
		
		"switch", "set":
			if parts.size() < 2:
				_print_terminal("[color=#ff5555]Uso: switch <ID_SNODO> [NUM_RAMO] (es. 'switch J1 2')[/color]")
				return
			var target_jid := parts[1].to_upper()
			var target_bidx := -1
			if parts.size() >= 3 and parts[2].is_valid_int():
				target_bidx = parts[2].to_int() - 1 # 1-based index per l'utente
			switch_junction(target_jid, target_bidx)
		
		"reroute":
			if parts.size() < 2:
				_print_terminal("[color=#ff5555]Uso: reroute <ID_DISPOSITIVO> (es. 'reroute life_support')[/color]")
				return
			var target_dev := parts[1].to_lower()
			_reroute_device(target_dev)
		
		"autobalance", "auto", "balance":
			autobalance_grid()
		
		"diag", "scan", "diagnostics":
			_run_diagnostics()
		
		"config":
			_print_terminal("[color=#ffffaa]=== CONFIGURAZIONE RUNTIME .DAT ===[/color]")
			for k in active_config:
				_print_terminal("  %s = %s" % [k, str(active_config[k])])
		
		"reload":
			load_dat_configuration()
			_print_terminal("[color=#00ff88]✔ Configurazione .dat ricaricata.[/color]")
		
		"clear", "cls":
			if terminal_output:
				terminal_output.clear()
		
		_:
			_print_terminal("[color=#ff5555]Comando non riconosciuto: '%s'. Digita 'help' per la lista dei comandi.[/color]" % verb)

func _reroute_device(dev_id: String) -> void:
	if not devices.has(dev_id):
		_print_terminal("[color=#ff5555]Dispositivo '%s' non trovato. Usa 'devices' per l'elenco.[/color]" % dev_id)
		return
	
	var dev: Dictionary = devices[dev_id]
	if dev.get("regime", 0.0) >= 1.0:
		_print_terminal("[color=#00ff88]Il dispositivo %s è già al 100%% del regime operativo.[/color]" % dev["name"])
		return
	
	_print_terminal("[color=#ffaa00]Tentativo di riallocazione flussi per %s...[/color]" % dev["name"])
	autobalance_grid()

func _run_diagnostics() -> void:
	_print_terminal("[color=#ffffaa]=== DIAGNOSTICA LINEE ELETTRICHE ===[/color]")
	var broken_lines := 0
	for c in conduits:
		if c["is_shorted"]:
			broken_lines += 1
			_print_terminal("  [color=#ff4444]⚡ CORTO-CIRCUITO: Linea '%s' interrotta da guasto Duct Drone![/color]" % c["name"])
	
	if broken_lines == 0:
		_print_terminal("[color=#00ff88]✔ Nessuna interruzione fisica rilevata su tutti i condotti primari e secondari.[/color]")
	else:
		_print_terminal("[color=#ffaa00]Suggerimento: Commuta gli snodi o invia il Duct Drone per riparare i cortocircuiti.[/color]")

func _on_switch_selected_junction_pressed() -> void:
	if selected_junction_id != "":
		switch_junction(selected_junction_id)

func _on_reload_config_pressed() -> void:
	load_dat_configuration()

# --- GESTIONE CLICK E INTERAZIONE SULLA MAPPA ---
func on_canvas_junction_clicked(junc_id: String) -> void:
	selected_junction_id = junc_id
	selected_device_id = ""
	switch_junction(junc_id)
	_update_inspector_ui()

func on_canvas_device_clicked(dev_id: String) -> void:
	selected_device_id = dev_id
	selected_junction_id = ""
	_update_inspector_ui()

func get_junction_at_pos(pos: Vector2, canvas: Control) -> String:
	var trans := _get_canvas_transform(canvas)
	var s: float = trans.get_scale().x
	for j_id in junctions:
		var j_pos: Vector2 = trans * junctions[j_id]["pos"]
		if pos.distance_to(j_pos) <= 16.0 * s:
			return j_id
	return ""

func get_device_at_pos(pos: Vector2, canvas: Control) -> String:
	var trans := _get_canvas_transform(canvas)
	var s: float = trans.get_scale().x
	for dev_id in devices:
		var d_pos: Vector2 = trans * devices[dev_id]["pos"]
		var r := Rect2(d_pos - Vector2(35, 20) * s, Vector2(70, 40) * s)
		if r.has_point(pos):
			return dev_id
	return ""

func _get_canvas_transform(canvas: Control) -> Transform2D:
	var canvas_size: Vector2 = canvas.size
	var scale_factor: float = minf(canvas_size.x / BLUEPRINT_SIZE.x, canvas_size.y / BLUEPRINT_SIZE.y)
	if scale_factor <= 0.001:
		scale_factor = 1.0
	var offset: Vector2 = (canvas_size - BLUEPRINT_SIZE * scale_factor) * 0.5
	return Transform2D().translated(offset).scaled(Vector2(scale_factor, scale_factor))

# --- RENDERING MAPPA 2D BLUEPRINT ---
func draw_power_grid(canvas: Control) -> void:
	if not canvas or not is_instance_valid(canvas):
		return
	
	var trans := _get_canvas_transform(canvas)
	var s: float = trans.get_scale().x
	var font: Font = ThemeDB.fallback_font
	
	# 1. Griglia di sfondo e Sagoma Scafo
	_draw_blueprint_grid(canvas, trans)
	_draw_ship_hull(canvas, trans)
	
	# 2. Disegno Conduits (Linee Elettriche)
	_draw_conduits(canvas, trans, s)
	
	# 3. Disegno Snodi (Junctions con Biforcazioni)
	_draw_junctions(canvas, trans, s, font)
	
	# 4. Disegno Dispositivi
	_draw_devices(canvas, trans, s, font)
	
	# 5. Disegno Segnalatori Cortocircuito Duct Drone
	_draw_short_circuits(canvas, trans, s, font)

func _draw_blueprint_grid(canvas: Control, trans: Transform2D) -> void:
	var grid_color := Color(0.06, 0.14, 0.22, 0.4)
	var step := 30.0
	for x in range(0, int(BLUEPRINT_SIZE.x), int(step)):
		canvas.draw_line(trans * Vector2(x, 0), trans * Vector2(x, BLUEPRINT_SIZE.y), grid_color, 1.0)
	for y in range(0, int(BLUEPRINT_SIZE.y), int(step)):
		canvas.draw_line(trans * Vector2(0, y), trans * Vector2(BLUEPRINT_SIZE.x, y), grid_color, 1.0)

func _draw_ship_hull(canvas: Control, trans: Transform2D) -> void:
	var hull_points: PackedVector2Array = [
		Vector2(300, 20), Vector2(340, 45), Vector2(400, 70), Vector2(500, 110),
		Vector2(510, 170), Vector2(490, 200), Vector2(580, 225), Vector2(580, 300),
		Vector2(510, 305), Vector2(430, 310), Vector2(420, 410), Vector2(350, 425),
		Vector2(300, 430), Vector2(250, 425), Vector2(180, 410), Vector2(170, 310),
		Vector2(90, 305), Vector2(20, 300), Vector2(20, 225), Vector2(110, 200),
		Vector2(90, 170), Vector2(100, 110), Vector2(200, 70), Vector2(260, 45)
	]
	var transformed_hull: PackedVector2Array = []
	for pt in hull_points:
		transformed_hull.push_back(trans * pt)
	canvas.draw_colored_polygon(transformed_hull, Color(0.03, 0.07, 0.12, 0.9))
	for i in range(transformed_hull.size()):
		var p1 := transformed_hull[i]
		var p2 := transformed_hull[(i + 1) % transformed_hull.size()]
		canvas.draw_line(p1, p2, Color(0.18, 0.45, 0.75, 0.7), 2.0)

func _draw_conduits(canvas: Control, trans: Transform2D, s: float) -> void:
	for c in conduits:
		var p1: Vector2 = trans * c["from"]
		var p2: Vector2 = trans * c["to"]
		var is_pow: bool = c.get("is_powered", false)
		var is_short: bool = c.get("is_shorted", false)
		var is_act: bool = c.get("is_active_branch", true)
		var is_dead: bool = c.get("is_dead_end", false)
		
		var line_color := Color(0.15, 0.22, 0.32, 0.5) # Inattiva
		var width := 2.5 * s
		
		if is_short:
			# Cortocircuito / Danneggiata (Rosso lampeggiante)
			var flash := 0.6 + 0.4 * sin(anim_pulse_time * 8.0)
			line_color = Color(1.0, 0.2, 0.2, flash)
			width = 3.5 * s
		elif is_pow:
			# Attiva ed alimentata (Ciano / Giallo neon brillante)
			line_color = Color(0.0, 0.9, 1.0, 0.95)
			width = 3.5 * s
		elif is_act:
			# Connessione attiva ma senza alimentazione
			line_color = Color(0.3, 0.5, 0.7, 0.65)
		elif is_dead:
			# Linea morta / non utilizzata
			line_color = Color(0.4, 0.3, 0.2, 0.4)
		
		canvas.draw_line(p1, p2, line_color, width)
		
		# Animazione flusso di particelle / impulsi sulle linee alimentate
		if is_pow and not is_short:
			var t := fmod(anim_pulse_time * 1.5, 1.0)
			var pulse_p := p1.lerp(p2, t)
			canvas.draw_circle(pulse_p, 3.5 * s, Color(1.0, 1.0, 0.7, 0.95))

func _draw_junctions(canvas: Control, trans: Transform2D, s: float, font: Font) -> void:
	for j_id in junctions:
		var j: Dictionary = junctions[j_id]
		var p: Vector2 = trans * j["pos"]
		var active_idx: int = int(j.get("active_branch", 0))
		var is_selected: bool = (j_id == selected_junction_id)
		
		# Base Snodo
		var node_col := Color(0.1, 0.8, 1.0)
		if is_selected:
			node_col = Color(1.0, 0.9, 0.2)
			canvas.draw_arc(p, 14.0 * s, 0, TAU, 24, Color(1.0, 0.9, 0.2, 0.8), 2.0 * s, true)
		
		canvas.draw_circle(p, 8.0 * s, Color(0.05, 0.15, 0.25, 0.95))
		canvas.draw_arc(p, 8.0 * s, 0, TAU, 20, node_col, 2.0 * s, true)
		canvas.draw_circle(p, 4.0 * s, node_col)
		
		# Etichetta Snodo
		var lbl_text := "%s (%d)" % [j_id, active_idx + 1]
		canvas.draw_string(font, p + Vector2(-12 * s, -11 * s), lbl_text, HORIZONTAL_ALIGNMENT_CENTER, -1, int(9 * s), node_col)

func _draw_devices(canvas: Control, trans: Transform2D, s: float, font: Font) -> void:
	for dev_id in devices:
		var dev: Dictionary = devices[dev_id]
		var p: Vector2 = trans * dev["pos"]
		var is_gen: bool = dev.get("is_generator", false)
		var is_selected: bool = (dev_id == selected_device_id)
		var regime: float = float(dev.get("regime", 0.0))
		var total_in: int = int(dev.get("inputs_count", 1))
		var pow_in: int = int(dev.get("inputs_powered", 0))
		
		var w := 68.0 * s
		var h := 34.0 * s
		var rect := Rect2(p - Vector2(w * 0.5, h * 0.5), Vector2(w, h))
		
		# Colore di stato del dispositivo
		var status_col := Color(0.2, 0.9, 0.5) if regime >= 0.99 else (Color(1.0, 0.8, 0.2) if regime > 0.0 else Color(0.9, 0.25, 0.25))
		if is_gen:
			status_col = Color(0.8, 0.4, 1.0)
		
		# Sfondo box
		canvas.draw_rect(rect, Color(0.06, 0.12, 0.18, 0.92))
		var border_col := Color(1.0, 0.9, 0.2, 0.9) if is_selected else status_col
		canvas.draw_rect(rect, border_col, false, 1.5 * s)
		
		# Nome dispositivo
		var name_str: String = dev["name"]
		if name_str.length() > 14:
			name_str = name_str.substr(0, 12) + ".."
		canvas.draw_string(font, rect.position + Vector2(4 * s, 11 * s), name_str, HORIZONTAL_ALIGNMENT_LEFT, -1, int(8 * s), Color(0.9, 0.95, 1.0))
		
		# Visualizzazione Porte Input e Regime
		if not is_gen:
			var in_str := ""
			for i in range(total_in):
				in_str += "●" if i < pow_in else "○"
			canvas.draw_string(font, rect.position + Vector2(4 * s, 22 * s), in_str, HORIZONTAL_ALIGNMENT_LEFT, -1, int(8 * s), status_col)
			
			var reg_str := "%d%%" % int(regime * 100.0)
			canvas.draw_string(font, rect.position + Vector2(w - 28 * s, 22 * s), reg_str, HORIZONTAL_ALIGNMENT_RIGHT, -1, int(8 * s), status_col)
		else:
			canvas.draw_string(font, rect.position + Vector2(4 * s, 22 * s), "GEN 100%", HORIZONTAL_ALIGNMENT_LEFT, -1, int(8 * s), status_col)

func _draw_short_circuits(canvas: Control, trans: Transform2D, s: float, font: Font) -> void:
	for sc in active_short_circuits:
		var sc_pos: Vector2 = sc.get("pos", Vector2.ZERO)
		var p: Vector2 = trans * sc_pos
		var flash := 0.6 + 0.4 * sin(anim_pulse_time * 10.0)
		
		# Alone di pericolo
		canvas.draw_circle(p, 10.0 * s, Color(1.0, 0.2, 0.1, 0.25 * flash))
		canvas.draw_arc(p, 9.0 * s, 0, TAU, 18, Color(1.0, 0.3, 0.1, flash), 1.5 * s, true)
		
		# Saetta
		var bolt1 := p + Vector2(-3, -7) * s
		var bolt2 := p + Vector2(4, -1) * s
		var bolt3 := p + Vector2(-2, 1) * s
		var bolt4 := p + Vector2(3, 7) * s
		canvas.draw_line(bolt1, bolt2, Color(1.0, 1.0, 0.4, 0.95), 2.0 * s)
		canvas.draw_line(bolt2, bolt3, Color(0.3, 0.95, 1.0, 0.95), 2.0 * s)
		canvas.draw_line(bolt3, bolt4, Color(1.0, 1.0, 0.6, 0.95), 2.0 * s)
		canvas.draw_string(font, p + Vector2(-16 * s, -11 * s), "⚡ CORTO", HORIZONTAL_ALIGNMENT_LEFT, -1, int(8 * s), Color(1.0, 0.4, 0.2, 0.95))

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
			f.store_string("# DARK NOVA POWER GRID RUNTIME CONFIGURATION\n[SYSTEM]\napp_name=PowerGrid\nversion=1.0.4\nstatus=OPERATIONAL\nmode=AUTOMATIC_BALANCING\n\n[GRID_SETTINGS]\nreactor_output_mw=1200.0\naux_generator_mw=450.0\njunction_switch_delay=0.25\noverload_threshold_pct=110.0\nreroute_efficiency_loss=0.05\n\n[CIRCUIT_PROTECTION]\nbreaker_trip_threshold=1.4\nshort_circuit_damping=0.85\nauto_reroute_on_short=false\n")
			f.close()
	
	var tune_abs := "%s/grid_tuning.dat" % abs_dir
	if not FileAccess.file_exists(tune_abs):
		var ft := FileAccess.open(tune_abs, FileAccess.WRITE)
		if ft:
			ft.store_string("# POWER GRID CALIBRATION & TUNING MATRIX\n[TUNING]\npower_efficiency_mult=1.0\nbackup_line_conductivity=0.95\nswitch_rate_hz=10.0\nregime_boost=1.0\noverclock_tolerance=1.2\n")
			ft.close()
	
	var fpm := get_node_or_null("/root/FolderPasswordManager")
	if fpm and not fpm.has_password("Ship Drive/Programs/PowerGrid"):
		fpm.set_password("Ship Drive/Programs/PowerGrid", "GRID-7815")

func is_operational() -> bool:
	if SpaceWorldManager and SpaceWorldManager.has_method("is_ship_connected"):
		return SpaceWorldManager.is_ship_connected()
	elif NetworkManager and NetworkManager.has_method("is_ship_connected"):
		return NetworkManager.is_ship_connected()
	return false

func _apply_configuration() -> void:
	total_power_gen_mw = float(active_config.get("reactor_output_mw", 1200.0)) + float(active_config.get("aux_generator_mw", 450.0))
	if devices.has("reactor_main"):
		devices["reactor_main"]["power_mw"] = float(active_config.get("reactor_output_mw", 1200.0))
	if devices.has("aux_generator"):
		devices["aux_generator"]["power_mw"] = float(active_config.get("aux_generator_mw", 450.0))
	
	if dat_status_badge:
		if active_config.get("is_dat_loaded", false):
			dat_status_badge.text = "DAT: ATTIVO (SINCRONIZZATO)"
			dat_status_badge.modulate = Color(0.2, 1.0, 0.5)
		else:
			dat_status_badge.text = "DAT: DEFAULT"
			dat_status_badge.modulate = Color(0.7, 0.8, 0.9)
	
	update_power_simulation()

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
			if val_str.to_lower() == "true":
				result[key] = true
			elif val_str.to_lower() == "false":
				result[key] = false
			elif val_str.is_valid_float():
				result[key] = val_str.to_float()
			elif val_str.is_valid_int():
				result[key] = val_str.to_int()
			else:
				result[key] = val_str
	file.close()
	return result

# --- GESTIONE MISSIONE / STATO RETE / PERMESSI ---
func _on_ship_connection_changed(is_connected: bool) -> void:
	_update_connection_state()

func _on_ship_damages_updated(_damages: Array) -> void:
	update_power_simulation()

func _on_mission_started() -> void:
	_update_connection_state()

func _on_mission_ended() -> void:
	_update_connection_state()

func _update_connection_state() -> void:
	var is_operational: bool = false
	if SpaceWorldManager and SpaceWorldManager.has_method("is_ship_connected"):
		is_operational = SpaceWorldManager.is_ship_connected()
	elif NetworkManager and NetworkManager.has_method("is_ship_connected"):
		is_operational = NetworkManager.is_ship_connected()
	
	if disconnected_overlay:
		disconnected_overlay.visible = not is_operational
	
	if status_badge:
		status_badge.text = "ONLINE" if is_operational else "OFFLINE"
		status_badge.modulate = Color(0.2, 1.0, 0.5) if is_operational else Color(1.0, 0.3, 0.2)
	
	set_process(is_operational)
	set_process_input(is_operational)

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
	
	can_control = (my_role == "Ingegnere" or my_role == "Capitano" or is_solo)
	
	if role_badge:
		var role_txt := my_role if my_role != "" else ("SOLO" if is_solo else "SPETTATORE")
		role_badge.text = "RUOLO: %s" % role_txt
		role_badge.modulate = Color(0.2, 1.0, 0.5) if can_control else Color(1.0, 0.8, 0.2)
	
	if btn_switch_selected_junction:
		btn_switch_selected_junction.disabled = not can_control
	if btn_autobalance:
		btn_autobalance.disabled = not can_control

func _get_net_mgr() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/NetworkManager")
	return null

func _distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var ab_len_sq := ab.length_squared()
	if ab_len_sq < 0.001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / ab_len_sq, 0.0, 1.0)
	var proj := a + t * ab
	return p.distance_to(proj)

# --- MULTIPLAYER RPC SYNCHRONIZATION ---
@rpc("authority", "call_remote", "reliable")
func _rpc_sync_junction_switch(junction_id: String, branch_index: int) -> void:
	if junctions.has(junction_id):
		junctions[junction_id]["active_branch"] = branch_index
		_rebuild_conduits_list()
		update_power_simulation()

@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_switch_junction(junction_id: String, branch_index: int) -> void:
	var nm := _get_net_mgr()
	if nm and nm.get("is_host"):
		switch_junction(junction_id, branch_index)
