@tool
class_name ShipBlueprint
extends Resource

## Struttura dati (Sublayer / Blueprint) per l'astronave in Dark Nova: Rogue Squadron.
## Contiene in modo unificato la geometria delle stanze, i condotti per i droni,
## la rete elettrica (dispositivi, snodi e cablaggi) e le zone di danno strutturale.

signal blueprint_changed()

# --- METADATI GENERALI ---
@export var ship_id: String = "dark_nova_corvette":
	set(val):
		ship_id = val
		emit_changed()

@export var ship_name: String = "Dark Nova Corvette":
	set(val):
		ship_name = val
		emit_changed()

@export var ship_class: String = "Corvetta d'Assalto & Ricognizione Leggera":
	set(val):
		ship_class = val
		emit_changed()

@export var ship_bounds: Rect2 = Rect2(60, 30, 480, 420):
	set(val):
		ship_bounds = val
		emit_changed()

@export var drone_spawn_pos: Vector2 = Vector2(300, 80):
	set(val):
		drone_spawn_pos = val
		emit_changed()

@export var drone_spawn_heading: float = -PI * 0.5:
	set(val):
		drone_spawn_heading = val
		emit_changed()

# --- SUBLAYER 1: STANZE E SETTORI (Rooms / Hull Layout) ---
# Ogni elemento: { "id": str, "name": str, "rect": Rect2, "color": Color, "border_color": Color, "category": str }
@export var rooms: Array[Dictionary] = []:
	set(val):
		rooms = val
		emit_changed()

# --- SUBLAYER 2: CONDOTTI DI MANUTENZIONE (Ducts System) ---
# Ogni elemento: { "id": str, "name": str, "from": Vector2, "to": Vector2, "width": float, "is_blocked": bool }
@export var ducts: Array[Dictionary] = []:
	set(val):
		ducts = val
		emit_changed()

# --- SUBLAYER 3: RETE ELETTRICA (Power Grid) ---
# Dispositivi: { "id": str, "name": str, "sector": str, "pos": Vector2, "is_generator": bool, "power_mw": float, "inputs_count": int, "desc": str }
@export var devices: Array[Dictionary] = []:
	set(val):
		devices = val
		emit_changed()

# Snodi: { "id": str, "name": str, "pos": Vector2, "input_source": str, "active_branch": int, "branches": Array[Dictionary] }
@export var junctions: Array[Dictionary] = []:
	set(val):
		junctions = val
		emit_changed()

# Cablaggi / Conduits espliciti o ausiliari: { "id": str, "from_pos": Vector2, "to_pos": Vector2, "from_junction": str, "target_id": str }
@export var conduits: Array[Dictionary] = []:
	set(val):
		conduits = val
		emit_changed()

# --- SUBLAYER 4: ZONE E PUNTI DI DANNO (Damage Zones) ---
# Ogni elemento: { "id": str, "type": str, "name": str, "pos": Vector2, "sector": str, "severity": float, "repair_cost": float, "desc": str, "system_impact": str }
@export var damages: Array[Dictionary] = []:
	set(val):
		damages = val
		emit_changed()

# --- SUBLAYER 5 / SEZIONE SHIP DRIVE: FILE SYSTEM & PASSWORD ---
# Ogni elemento in drive_files: { "path": str, "content": str, "is_protected": bool, "desc": str }
@export var drive_files: Array[Dictionary] = []:
	set(val):
		drive_files = val
		emit_changed()

# Mappa percorsi cartella -> password (es. "Ship Drive/Programs/FlightControls": "FLIGHT-7815")
@export var drive_passwords: Dictionary = {}:
	set(val):
		drive_passwords = val
		emit_changed()

# --- SUBLAYER 6 / SEZIONE APPLICAZIONI MAINFRAME INSTALLATE ---
# Ogni elemento in installed_apps: { "id": str, "title": str, "description": str, "scene_path": str, "icon_color": Color, "roles": Array[String] }
@export var installed_apps: Array[Dictionary] = []:
	set(val):
		installed_apps = val
		emit_changed()

func _init() -> void:
	if rooms.is_empty() and ducts.is_empty() and devices.is_empty():
		create_default_ship()

## Inizializza la blueprint con i dati standard della Dark Nova Corvette.
func create_default_ship() -> void:
	ship_id = "dark_nova_corvette"
	ship_name = "Dark Nova Corvette"
	ship_class = "Corvetta d'Assalto & Ricognizione Leggera"
	ship_bounds = Rect2(60, 30, 480, 420)
	drone_spawn_pos = Vector2(300, 80)
	drone_spawn_heading = -PI * 0.5
	
	_init_default_rooms()
	_init_default_ducts()
	_init_default_power_grid()
	_init_default_damages()
	_init_default_drive()
	_init_default_installed_apps()
	emit_changed()

func _init_default_rooms() -> void:
	rooms = [
		{
			"id": "bridge",
			"name": "Ponte di Comando",
			"rect": Rect2(230, 45, 140, 70),
			"color": Color(0.12, 0.28, 0.45, 0.55),
			"border_color": Color(0.35, 0.75, 1.0, 0.8),
			"category": "command"
		},
		{
			"id": "sensors",
			"name": "Sensori & Avionica",
			"rect": Rect2(110, 115, 100, 65),
			"color": Color(0.12, 0.35, 0.3, 0.5),
			"border_color": Color(0.2, 0.85, 0.65, 0.8),
			"category": "sensors"
		},
		{
			"id": "comms",
			"name": "Comunicazioni & EW",
			"rect": Rect2(390, 115, 100, 65),
			"color": Color(0.12, 0.35, 0.3, 0.5),
			"border_color": Color(0.2, 0.85, 0.65, 0.8),
			"category": "comms"
		},
		{
			"id": "armory",
			"name": "Armeria & Sicurezza",
			"rect": Rect2(245, 135, 110, 60),
			"color": Color(0.35, 0.15, 0.2, 0.5),
			"border_color": Color(0.9, 0.35, 0.4, 0.8),
			"category": "tactical"
		},
		{
			"id": "shields",
			"name": "Scudi Deflettori",
			"rect": Rect2(175, 145, 120, 60),
			"color": Color(0.2, 0.15, 0.4, 0.5),
			"border_color": Color(0.65, 0.45, 0.95, 0.8),
			"category": "defense"
		},
		{
			"id": "life_support",
			"name": "Supporto Vitale",
			"rect": Rect2(100, 205, 120, 60),
			"color": Color(0.15, 0.35, 0.2, 0.5),
			"border_color": Color(0.35, 0.85, 0.45, 0.8),
			"category": "life_support"
		},
		{
			"id": "cargo",
			"name": "Baia di Carico Principale",
			"rect": Rect2(380, 175, 120, 90),
			"color": Color(0.35, 0.28, 0.1, 0.5),
			"border_color": Color(0.85, 0.7, 0.3, 0.8),
			"category": "cargo"
		},
		{
			"id": "reactor",
			"name": "Nucleo Reattore & Fusione",
			"rect": Rect2(235, 225, 130, 60),
			"color": Color(0.4, 0.15, 0.1, 0.55),
			"border_color": Color(1.0, 0.4, 0.2, 0.85),
			"category": "engineering"
		},
		{
			"id": "rcs",
			"name": "Pod Manovra RCS",
			"rect": Rect2(240, 270, 120, 60),
			"color": Color(0.15, 0.25, 0.35, 0.5),
			"border_color": Color(0.4, 0.65, 0.85, 0.8),
			"category": "propulsion"
		},
		{
			"id": "engines",
			"name": "Sala Motori Principale",
			"rect": Rect2(230, 330, 140, 65),
			"color": Color(0.38, 0.22, 0.1, 0.55),
			"border_color": Color(0.95, 0.55, 0.2, 0.85),
			"category": "propulsion"
		}
	]

func _init_default_ducts() -> void:
	ducts = [
		{"id": "duct_spine_1", "from": Vector2(300, 115), "to": Vector2(300, 135), "width": 16.0, "name": "Condotto Dorsale Alpha", "is_blocked": false},
		{"id": "duct_spine_2", "from": Vector2(300, 195), "to": Vector2(300, 215), "width": 16.0, "name": "Condotto Reattore-Armeria", "is_blocked": false},
		{"id": "duct_spine_3", "from": Vector2(300, 285), "to": Vector2(300, 290), "width": 16.0, "name": "Condotto Reattore-RCS", "is_blocked": false},
		{"id": "duct_spine_4", "from": Vector2(300, 310), "to": Vector2(300, 330), "width": 16.0, "name": "Condotto RCS-Motori", "is_blocked": false},
		{"id": "duct_port_fwd", "from": Vector2(240, 80), "to": Vector2(210, 130), "width": 14.0, "name": "Condotto Prua Babordo", "is_blocked": false},
		{"id": "duct_stbd_fwd", "from": Vector2(360, 80), "to": Vector2(390, 130), "width": 14.0, "name": "Condotto Prua Tribordo", "is_blocked": false},
		{"id": "duct_port_mid", "from": Vector2(160, 180), "to": Vector2(160, 205), "width": 14.0, "name": "Condotto Laterale Sensori", "is_blocked": false},
		{"id": "duct_stbd_mid", "from": Vector2(440, 180), "to": Vector2(440, 190), "width": 14.0, "name": "Condotto Laterale Comms", "is_blocked": false},
		{"id": "duct_port_eng", "from": Vector2(220, 235), "to": Vector2(240, 255), "width": 14.0, "name": "Condotto Vita-Reattore", "is_blocked": false},
		{"id": "duct_stbd_eng", "from": Vector2(380, 235), "to": Vector2(360, 255), "width": 14.0, "name": "Condotto Carico-Reattore", "is_blocked": false},
		{"id": "duct_armory_bypass", "from": Vector2(245, 165), "to": Vector2(220, 175), "width": 14.0, "name": "Bypass Armeria-Scudi", "is_blocked": false},
		{"id": "duct_shields_core", "from": Vector2(235, 205), "to": Vector2(240, 235), "width": 14.0, "name": "Condotto Alimentazione Scudi", "is_blocked": false},
		{"id": "duct_port_aft", "from": Vector2(160, 265), "to": Vector2(235, 345), "width": 14.0, "name": "Condotto Servizio Poppa SX", "is_blocked": false},
		{"id": "duct_stbd_aft", "from": Vector2(440, 265), "to": Vector2(365, 345), "width": 14.0, "name": "Condotto Servizio Poppa DX", "is_blocked": false}
	]

func _init_default_power_grid() -> void:
	devices = [
		{
			"id": "reactor_main",
			"name": "Reattore Principale",
			"sector": "Nucleo Reattore & Fusione",
			"pos": Vector2(300, 255),
			"is_generator": true,
			"power_mw": 1200.0,
			"inputs_count": 0,
			"desc": "Generatore primario a fusione quantistica. Alimenta gli snodi dorsali e ventrali."
		},
		{
			"id": "aux_generator",
			"name": "Generatore Ausiliario",
			"sector": "Baia di Carico Principale",
			"pos": Vector2(440, 240),
			"is_generator": true,
			"power_mw": 450.0,
			"inputs_count": 0,
			"desc": "Celle energetiche ausiliarie di riserva. Alimentano il settore tribordo e i canali di bypass."
		},
		{
			"id": "bridge_nav",
			"name": "Ponte di Comando",
			"sector": "Ponte di Comando",
			"pos": Vector2(300, 75),
			"is_generator": false,
			"power_mw": 150.0,
			"inputs_count": 2,
			"desc": "Console di navigazione e comando centrale. Richiede 2 linee di alimentazione per piena operatività."
		},
		{
			"id": "sensors_radar",
			"name": "Sensori & Avionica",
			"sector": "Sensori & Avionica",
			"pos": Vector2(160, 145),
			"is_generator": false,
			"power_mw": 120.0,
			"inputs_count": 1,
			"desc": "Array sensori a lungo raggio, scanner EM e telemetria spaziale."
		},
		{
			"id": "comms_ew",
			"name": "Comunicazioni & EW",
			"sector": "Comunicazioni & EW",
			"pos": Vector2(440, 145),
			"is_generator": false,
			"power_mw": 120.0,
			"inputs_count": 1,
			"desc": "Trasmettitore subspaziale e contromisure di guerra elettronica."
		},
		{
			"id": "armory_defense",
			"name": "Armeria & Torrette",
			"sector": "Armeria & Sicurezza",
			"pos": Vector2(300, 165),
			"is_generator": false,
			"power_mw": 250.0,
			"inputs_count": 2,
			"desc": "Sistemi di puntamento armi pesanti, torrette difensive di prossimità e blocco armeria."
		},
		{
			"id": "life_support",
			"name": "Supporto Vitale",
			"sector": "Supporto Vitale",
			"pos": Vector2(160, 235),
			"is_generator": false,
			"power_mw": 200.0,
			"inputs_count": 2,
			"desc": "Filtrazione atmosfera, gravità artificiale e regolazione termica alloggi."
		},
		{
			"id": "cargo_drone_bay",
			"name": "Baia Drone & CCTV",
			"sector": "Baia di Carico Principale",
			"pos": Vector2(440, 205),
			"is_generator": false,
			"power_mw": 90.0,
			"inputs_count": 1,
			"desc": "Docking station del Duct Drone e matrice telecamere CCTV esterne."
		},
		{
			"id": "shields_deflector",
			"name": "Scudi Deflettori",
			"sector": "Scudi Deflettori",
			"pos": Vector2(235, 175),
			"is_generator": false,
			"power_mw": 400.0,
			"inputs_count": 3,
			"desc": "Generatori di campo deflettore prua, poppa e matrice di sovralimentazione."
		},
		{
			"id": "engines_sublight",
			"name": "Motori Principali",
			"sector": "Sala Motori Principale",
			"pos": Vector2(300, 360),
			"is_generator": false,
			"power_mw": 600.0,
			"inputs_count": 3,
			"desc": "Propulsione sub-luce (Propulsore SX, DX e canale termico di spinta centrale)."
		},
		{
			"id": "rcs_thrusters",
			"name": "Sistema RCS",
			"sector": "Pod Manovra RCS",
			"pos": Vector2(300, 300),
			"is_generator": false,
			"power_mw": 160.0,
			"inputs_count": 2,
			"desc": "Ugelli di manovra laterali RCS Babordo (SX) e Tribordo (DX)."
		}
	]

	junctions = [
		{
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
		},
		{
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
		},
		{
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
		},
		{
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
		},
		{
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
		},
		{
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
		},
		{
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
		},
		{
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
	]

func _init_default_damages() -> void:
	damages = [
		{
			"id": "dmg_1",
			"type": "breach",
			"name": "Falla Strutturale Prua",
			"pos": Vector2(260, 65),
			"sector": "Ponte di Comando",
			"severity": 4.5,
			"repair_cost": 10.0,
			"desc": "Micrometeorite ha perforato la blindatura anteriore della cabina di pilotaggio.",
			"system_impact": "nav_instability"
		},
		{
			"id": "dmg_2",
			"type": "short_circuit",
			"name": "Cortocircuito Scanner EM",
			"pos": Vector2(140, 135),
			"sector": "Sensori & Avionica",
			"severity": 6.0,
			"repair_cost": 12.0,
			"desc": "Sovratensione nei banchi di condensatori dei sensori a lungo raggio.",
			"system_impact": "radar_ghosts"
		},
		{
			"id": "dmg_3",
			"type": "short_circuit",
			"name": "Guasto Emettitore Scudo Babordo",
			"pos": Vector2(210, 160),
			"sector": "Scudi Deflettori",
			"severity": 7.5,
			"repair_cost": 15.0,
			"desc": "Arco voltaico negli anelli di collimazione deflettore sinistro.",
			"system_impact": "shields_degraded"
		},
		{
			"id": "dmg_4",
			"type": "breach",
			"name": "Infiltrazione Refrigerante Nucleo",
			"pos": Vector2(275, 245),
			"sector": "Nucleo Reattore & Fusione",
			"severity": 8.0,
			"repair_cost": 18.0,
			"desc": "Perdita di fluido criogenico ad alta pressione dal circuito di confinamento.",
			"system_impact": "overheating"
		},
		{
			"id": "dmg_5",
			"type": "short_circuit",
			"name": "Malfunzionamento Compressore Atmosfera",
			"pos": Vector2(130, 225),
			"sector": "Supporto Vitale",
			"severity": 5.0,
			"repair_cost": 8.0,
			"desc": "Blocco meccanico con surriscaldamento delle valvole di ricircolo O2.",
			"system_impact": "o2_leak"
		},
		{
			"id": "dmg_6",
			"type": "breach",
			"name": "Fessurazione Camera di Spinta",
			"pos": Vector2(320, 350),
			"sector": "Sala Motori Principale",
			"severity": 6.5,
			"repair_cost": 14.0,
			"desc": "Stress termico elevato ha causato microfratture nell'ugello di scarico destro.",
			"system_impact": "engine_thrust_loss"
		},
		{
			"id": "dmg_7",
			"type": "short_circuit",
			"name": "Attuatore Ugello RCS Babordo Bloccato",
			"pos": Vector2(260, 290),
			"sector": "Pod Manovra RCS",
			"severity": 4.0,
			"repair_cost": 7.0,
			"desc": "Relè di potenza bruciato sull'elettrovalvola dei propulsori di rotazione SX.",
			"system_impact": "turn_speed_reduced"
		},
		{
			"id": "dmg_8",
			"type": "breach",
			"name": "Compromissione Portellone Cargo Esterno",
			"pos": Vector2(460, 215),
			"sector": "Baia di Carico Principale",
			"severity": 5.5,
			"repair_cost": 11.0,
			"desc": "Guarnizione magnetica della rampa di carico danneggiata da detriti.",
			"system_impact": "cargo_depressurization"
		}
	]

func _init_default_drive() -> void:
	drive_files = [
		{
			"path": "Ship Drive/Ship Systems.txt",
			"content": "=== DARK NOVA - SISTEMI NAVE ===\nReattore Principale: ONLINE (100% Efficienza)\nPropulsione Sub-Luce: ATTIVA\nScudi Deflettori: OPERATIVI\nArray Sensori & Cams: 6 Canali Attivi (Prua, Poppa, Babordo, Tribordo, Dorsale, Ventrale)\nSottosistemi di Guida: Calibrati\n",
			"is_protected": false,
			"desc": "Riepilogo stato dei sistemi e della telemetria di bordo."
		},
		{
			"path": "Ship Drive/Flight Log.txt",
			"content": "=== REGISTRO DI BORDO ===\n[STARDATE 7815.4] Connessione al sistema centrale stabilita.\nTutti i sistemi della Dark Nova sono pronti alla navigazione spaziale.\nEquipaggio autorizzato ad accedere all'unita' condivisa Ship Drive.\n",
			"is_protected": false,
			"desc": "Registro eventi e cronologia di navigazione."
		},
		{
			"path": "Ship Drive/Crew Directives.txt",
			"content": "=== DIRETTIVE EQUIPAGGIO ===\n1. Mantenere monitorati i feed video delle telecamere esterne durante la navigazione.\n2. Coordinare le manovre di volo e la spinta propulsori con la plancia.\n3. Condividere report di missione e file di rotta all'interno dello Ship Drive.\n",
			"is_protected": false,
			"desc": "Protocolli operativi per l'equipaggio in missione."
		},
		{
			"path": "Ship Drive/Programs/FlightControls/flight_config.dat",
			"content": "# DARK NOVA FLIGHT CONTROLS RUNTIME CONFIGURATION\n# WARNING: SYSTEM CONFIGURATION FILE - ACTIVE FLIGHT TUNING\n[SYSTEM]\napp_name=FlightControls\nversion=1.0.4\nstatus=OPERATIONAL\nrcs_subsystem=ACTIVE\n\n[FLIGHT_DYNAMICS]\nmax_linear_speed=20.0\nlinear_acceleration=35.0\nlinear_deceleration=20.0\nmax_angular_speed=2.5\nangular_acceleration=8.0\nangular_deceleration=6.0\n\n[SPEED_MODES]\nturbo_multiplier=2.0\nprecision_multiplier=0.4\n",
			"is_protected": true,
			"desc": "Parametri di dinamica e limiti di manovra del sistema di volo."
		},
		{
			"path": "Ship Drive/Programs/FlightControls/thrusters_tuning.dat",
			"content": "# RCS & MAIN THRUSTERS TUNING MATRIX\n[THRUSTERS]\nrcs_power_rate=1.0\npitch_thrust_mult=1.0\nyaw_thrust_mult=1.0\nroll_thrust_mult=1.0\nvertical_thrust_mult=1.0\noverclock_limit=1.5\n",
			"is_protected": true,
			"desc": "Matrice di calibrazione dei propulsori RCS e di spinta principale."
		},
		{
			"path": "Ship Drive/Programs/Cams/cams_config.dat",
			"content": "# DARK NOVA CAMS ARRAY RUNTIME CONFIGURATION\n# WARNING: SENSORS & OPTICS CONFIGURATION FILE\n[SYSTEM]\napp_name=Cams\nversion=1.0.4\nstatus=OPERATIONAL\nsensor_array=CCTV_6CH\n\n[OPTICS]\ndefault_fov=75.0\nmin_fov=30.0\nmax_fov=100.0\nzoom_step=10.0\nnight_vision_intensity=0.18\ntactical_hud_contrast=0.18\nthermal_intensity=0.22\n",
			"is_protected": true,
			"desc": "Configurazione lenti e calibrazione array ottico a 6 canali."
		},
		{
			"path": "Ship Drive/Programs/Cams/optics_tuning.dat",
			"content": "# OPTICS & SENSOR CALIBRATION MATRIX\n[SENSORS]\nsignal_boost=1.0\nnoise_reduction=1.0\nrefresh_rate_hz=60.0\ncrosshair_style=STANDARD\noverclock_gain=1.0\n",
			"is_protected": true,
			"desc": "Taratura guadagno di segnale e filtri visivi CCTV."
		},
		{
			"path": "Ship Drive/Programs/DuctDrone/duct_drone_config.dat",
			"content": "# DARK NOVA DUCT DRONE RUNTIME CONFIGURATION\n# WARNING: SYSTEM CONFIGURATION FILE - MAINTENANCE & REPAIR ROBOT\n[SYSTEM]\napp_name=DuctDrone\nversion=1.0.4\nstatus=OPERATIONAL\nmaintenance_subsystem=ACTIVE\n\n[DRONE_DYNAMICS]\nlinear_speed=175.0\nlinear_acceleration=650.0\nlinear_deceleration=750.0\nrotate_speed=3.0\n\n[BATTERY_MANAGEMENT]\nbattery_max=100.0\nbattery_drain_move=0.35\nbattery_drain_lights=0.75\nbattery_drain_radar=3.5\nbattery_drain_repair=6.0\n\n[MAINTENANCE]\nradar_scan_radius_max=160.0\nrepair_range=42.0\nrepair_speed_multiplier=1.0\n",
			"is_protected": true,
			"desc": "Configurazione dinamica e gestione energetica del drone di manutenzione."
		},
		{
			"path": "Ship Drive/Programs/DuctDrone/drone_tuning.dat",
			"content": "# DUCT DRONE CALIBRATION & EFFICIENCY MATRIX\n[TUNING]\nturbo_multiplier=2.0\nprecision_multiplier=0.5\nrepair_efficiency=1.0\nradar_intensity=1.0\noverclock_speed_gain=1.0\n",
			"is_protected": true,
			"desc": "Coefficienti di efficienza riparazione e radar del drone."
		},
		{
			"path": "Ship Drive/Programs/PowerGrid/power_grid_config.dat",
			"content": "# DARK NOVA POWER GRID RUNTIME CONFIGURATION\n# WARNING: ELECTRICAL GRID AND POWER DISTRIBUTION MATRIX\n[SYSTEM]\napp_name=PowerGrid\nversion=1.0.4\nstatus=OPERATIONAL\nmode=AUTOMATIC_BALANCING\n\n[GRID_SETTINGS]\nreactor_output_mw=1200.0\naux_generator_mw=450.0\njunction_switch_delay=0.25\noverload_threshold_pct=110.0\nreroute_efficiency_loss=0.05\n\n[CIRCUIT_PROTECTION]\nbreaker_trip_threshold=1.4\nshort_circuit_damping=0.85\nauto_reroute_on_short=false\n",
			"is_protected": true,
			"desc": "Configurazione reattore, soglie di sovraccarico e disgiuntori della rete."
		},
		{
			"path": "Ship Drive/Programs/PowerGrid/grid_tuning.dat",
			"content": "# POWER GRID CALIBRATION & TUNING MATRIX\n[TUNING]\npower_efficiency_mult=1.0\nbackup_line_conductivity=0.95\nswitch_rate_hz=10.0\nregime_boost=1.0\noverclock_tolerance=1.2\n",
			"is_protected": true,
			"desc": "Matrice di conduttività e frequenza di commutazione snodi."
		},
		{
			"path": "Ship Drive/Programs/Weapons/weapons_config.dat",
			"content": "# DARK NOVA TACTICAL WEAPONS RUNTIME CONFIGURATION\n# WARNING: TACTICAL WEAPONS & DEFENSE SYSTEMS FIRMWARE\n[SYSTEM]\napp_name=Weapons\nversion=1.0.4\nstatus=OPERATIONAL\nweapons_subsystem=ACTIVE\n\n[WEAPONS]\nmax_range=4500.0\nfire_rate=1.8\ncooling_rate=0.75\nauto_pdg_enabled=true\nlaser_power_draw=250.0\ntorpedo_max_ammo=12\npdg_ammo_max=500\npdg_fire_rate=8.0\nemergency_vent_cooldown=10.0\n",
			"is_protected": true,
			"desc": "Parametri operativi armi pesanti, torrette laser e cadenza PDG."
		},
		{
			"path": "Ship Drive/Programs/Weapons/ammo_tuning.dat",
			"content": "# WEAPONS BALLISTICS & TARGETING CALIBRATION MATRIX\n[BALLISTICS]\ntorpedo_velocity=85.0\nauto_lead_tracking=true\noverclock_damage_mult=1.0\nheat_multiplier=1.0\npdg_range=1200.0\nlaser_beam_intensity=1.0\n",
			"is_protected": true,
			"desc": "Balistica siluri, tracking anticipo di tiro e guadagno danno."
		},
		{
			"path": "Ship Drive/Programs/ShieldMatrix/shields_config.dat",
			"content": "# DARK NOVA SHIELD MATRIX RUNTIME CONFIGURATION\n# WARNING: SHIELD DEFLECTOR AND HULL PROTECTION MATRIX\n[SYSTEM]\napp_name=ShieldMatrix\nversion=1.0.4\nstatus=OPERATIONAL\nshield_subsystem=ACTIVE\n\n[SHIELD_SETTINGS]\nmax_capacity_per_quadrant=250.0\nrecharge_rate_per_sec=15.0\noverload_limit=1.3\nbase_power_draw_mw=90.0\nemergency_boost_power_mw=120.0\nemergency_boost_amount=75.0\nemergency_boost_cooldown=8.0\ndecay_rate_unpowered=25.0\n",
			"is_protected": true,
			"desc": "Capacità per quadrante, rigenerazione e assorbimento energetico matrice scudi."
		},
		{
			"path": "Ship Drive/Programs/ShieldMatrix/deflector_tuning.dat",
			"content": "# DEFLECTOR HARMONICS & FIELD TUNING MATRIX\n[HARMONICS]\nharmonic_frequency=440.0\nemergency_boost_multiplier=2.5\noverclock_absorption=1.0\nphase_sync_stability=0.98\ndispersion_damping=0.88\n",
			"is_protected": true,
			"desc": "Frequenza armonica deflettori e moltiplicatori boost scudi."
		},
		{
			"path": "Ship Drive/Programs/Comms/comms_config.dat",
			"content": "# DARK NOVA COMMUNICATIONS & EW RUNTIME CONFIGURATION\n# WARNING: SUBSPACE RELAY AND CRYPTOGRAPHY MATRIX\n[SYSTEM]\napp_name=Comms\nversion=1.0.4\nstatus=OPERATIONAL\ncomms_subsystem=ACTIVE\n\n[COMMS_SETTINGS]\nbandwidth_hz=1420.0\ndecryption_speed_multiplier=1.0\nsubspace_relay_active=true\nauto_tune_sos=true\nsignal_amplification=1.2\n",
			"is_protected": true,
			"desc": "Configurazione larghezza di banda e ricezione subspaziale."
		},
		{
			"path": "Ship Drive/Programs/Comms/crypto_tuning.dat",
			"content": "# EW COUNTERMEASURES & CRYPTO TUNING MATRIX\n[ELECTRONIC_WARFARE]\njamming_power_mw=120.0\nsignal_noise_ratio=0.85\nspoofing_signature=CORVETTE_CIVILIAN\njamming_radius=15000.0\noverclock_ew_boost=1.0\ncrypto_crack_speed=1.0\n",
			"is_protected": true,
			"desc": "Taratura potenza Jamming, contromisure EW e violazione cifrari."
		},
		{
			"path": "Ship Drive/Programs/Diagnostics/diagnostics_config.dat",
			"content": "# DARK NOVA SYSTEM DIAGNOSTICS RUNTIME CONFIGURATION\n# WARNING: SYSTEM INTEGRITY & THREAT SCANNER CONFIGURATION\n[SYSTEM]\napp_name=Diagnostics\nversion=1.0.4\nstatus=OPERATIONAL\ndiagnostics_subsystem=ACTIVE\n\n[SCANNER_SETTINGS]\nscan_depth=DEEP\nauto_quarantine_malware=true\nalert_sound=true\nscan_speed_multiplier=1.0\ntamper_detection_level=HIGH\nlog_telemetry_integrity=true\n",
			"is_protected": true,
			"desc": "Configurazione scanner di integrità, rilevamento malware e parametri di allarme."
		},
		{
			"path": "Ship Drive/Programs/Diagnostics/security_tuning.dat",
			"content": "# ICE DEFENSE & CYBER SECURITY TUNING MATRIX\n[ICE_DEFENSE]\nice_firewall_strength=100.0\nfactory_reset_delay_sec=3.0\ntamper_detection_level=HIGH\nice_recharge_rate=5.0\nmalware_purge_efficiency=1.0\noverclock_bypass_security=false\n",
			"is_protected": true,
			"desc": "Barriere ICE difensive, tasso di ricarica e ritardo ripristino di fabbrica."
		},
		{
			"path": "Ship Drive/Programs/Sensors/sensors_config.dat",
			"content": "# DARK NOVA SENSORS ARRAY & TACTICAL MAP CONFIGURATION\n# WARNING: SYSTEM CONFIGURATION FILE - RUNTIME RADAR FIRMWARE\n[SYSTEM]\napp_name=SensorsApp\nversion=1.0.0\nstatus=OPERATIONAL\n\n[SWEEP]\nsweep_frequency_hz=12.0\nactive_ping_radius=50000.0\nnoise_filter=0.92\n",
			"is_protected": true,
			"desc": "Configurazione frequenza sweep, raggio ping attivo e filtri rumore sensori."
		},
		{
			"path": "Ship Drive/Programs/Sensors/radar_tuning.dat",
			"content": "# RADAR TUNING & SPECTROMETRY CALIBRATION MATRIX\n[TUNING]\nspectrum_sensitivity=1.0\niff_auto_tag=true\nstealth_detection_threshold=0.35\n",
			"is_protected": true,
			"desc": "Sensibilità spettrometrica, marcatura automatica IFF e soglia stealth."
		},
		{
			"path": "Ship Drive/Programs/LifeSupport/life_support_config.dat",
			"content": "# DARK NOVA LIFE SUPPORT & ATMOSPHERE CONTROL CONFIGURATION\n# WARNING: SYSTEM CONFIGURATION FILE - RUNTIME ATMOSPHERE FIRMWARE\n[SYSTEM]\napp_name=LifeSupportApp\nversion=1.0.0\nstatus=OPERATIONAL\n\n[OXYGEN]\no2_generation_rate=1.2\nseal_door_speed=0.5\nauto_fire_suppress=false\n",
			"is_protected": true,
			"desc": "Configurazione generazione O2, velocità sigillatura paratie e automazione antincendio."
		},
		{
			"path": "Ship Drive/Programs/LifeSupport/atmo_tuning.dat",
			"content": "# ATMOSPHERE TUNING & DECOMPRESSION PARAMETERS MATRIX\n[PARAMETERS]\ndecompression_rate=1.8\nfire_suppression_co2_level=0.45\nscrubber_efficiency=0.98\n",
			"is_protected": true,
			"desc": "Parametri di decompressione rapida, livelli gas inerte e efficienza scrubber CO2."
		},
		{
			"path": "Ship Drive/Programs/Logbook/logbook_config.dat",
			"content": "[SYSTEM]\napp_name=LogbookApp\nversion=1.0.0\nstatus=OPERATIONAL\n\n[LOGGING]\nauto_log_events=true\nmax_history_entries=200\nlog_telemetry_errors=true\n",
			"is_protected": true,
			"desc": "Configurazione sistema di logging eventi e telemetria scatola nera."
		},
		{
			"path": "Ship Drive/Programs/Logbook/journal_tuning.dat",
			"content": "[SYNC]\nsync_to_ship_drive=true\ntimestamp_format=STAR_DATE\ncloud_backup=false\n",
			"is_protected": true,
			"desc": "Parametri di sincronizzazione diario e formattazione timestamp."
		},
		{
			"path": "Ship Drive/systems/ship_blueprint.dat",
			"content": "# DARK NOVA SHIP BLUEPRINT & HULL SPECIFICATIONS\n# WARNING: SHIP MAINFRAME BLUEPRINT MATRIX - LOW-LEVEL FIRMWARE\n[BLUEPRINT_METADATA]\nship_id=dark_nova_corvette\nship_name=Dark Nova Corvette\nship_class=Corvetta d'Assalto & Ricognizione Leggera\nbounds_x=60.0\nbounds_y=30.0\nbounds_width=480.0\nbounds_height=420.0\ndrone_spawn_x=300.0\ndrone_spawn_y=80.0\ndrone_spawn_heading=-1.5707963\n\n[BLUEPRINT_SUBLAYERS]\nrooms_count=10\nducts_count=14\ndevices_count=11\njunctions_count=8\ndamages_count=8\ndrive_files_count=27\ninstalled_apps_count=11\n",
			"is_protected": true,
			"desc": "Specifiche generali del blueprint e metadati dimensionali scafo."
		},
		{
			"path": "Ship Drive/systems/hull_specs.dat",
			"content": "# SHIP HULL SECTORS & SUBLAYER TOPOLOGY MATRIX\n[HULL_SECTORS]\nsector_bridge=Ponte di Comando\nsector_crew=Alloggi Equipaggio\nsector_drone_bay=Baia di Lancio Droni\nsector_tech_corridor=Corridoio Tecnico Principale\nsector_cargo=Baia di Carico Principale\nsector_reactor=Sala Reattore Principale\nsector_engines=Sala Motori & Propulsione\nsector_armory=Sala Armeria & Scudi\n\n[POWER_GRID_SPECS]\nreactor_output_mw=1200.0\naux_generator_mw=450.0\ntotal_junctions=8\ntotal_devices=11\ngrid_balancing=AUTOMATIC\n\n[DAMAGE_TOLERANCE]\ncritical_integrity_threshold=25.0\nmax_structural_integrity=100.0\ntotal_damage_sectors=8\n",
			"is_protected": true,
			"desc": "Topologia dei settori dello scafo, specifiche di alimentazione e tolleranze danni."
		}
	]
	
	drive_passwords = {
		"Ship Drive/Programs/FlightControls": "FLIGHT-7815",
		"Ship Drive/Programs/Cams": "CAMS-7815",
		"Ship Drive/Programs/DuctDrone": "DRONE-7815",
		"Ship Drive/Programs/PowerGrid": "GRID-7815",
		"Ship Drive/Programs/Weapons": "WEAP-7815",
		"Ship Drive/Programs/ShieldMatrix": "SHLD-7815",
		"Ship Drive/Programs/Comms": "COMM-7815",
		"Ship Drive/Programs/Diagnostics": "DIAG-7815",
		"Ship Drive/Programs/Sensors": "SENS-7815",
		"Ship Drive/Programs/LifeSupport": "LIFE-7815",
		"Ship Drive/Programs/Logbook": "LOGS-7815",
		"Ship Drive/systems": "ROOT-7815"
	}

func _init_default_installed_apps() -> void:
	installed_apps = [
		{
			"id": "flight_control",
			"title": "Flight Control",
			"description": "Controlli di manovra e navigazione nave",
			"scene_path": "res://Applications/FlightControl/flight_control_app.tscn",
			"icon_color": Color(1.0, 0.6, 0.2, 1.0),
			"roles": ["Capitano", "Pilota", "Factotum"]
		},
		{
			"id": "duct_drone",
			"title": "Duct Drone",
			"description": "Robottino manutenzione e schema condotti 2D",
			"scene_path": "res://Applications/DuctDrone/duct_drone_app.tscn",
			"icon_color": Color(1.0, 0.85, 0.2, 1.0),
			"roles": ["Capitano", "Ingegnere", "Hacker", "Factotum"]
		},
		{
			"id": "power_grid",
			"title": "Power Grid",
			"description": "Mappa elettrica 2D, snodi e flussi energetici nave",
			"scene_path": "res://Applications/PowerGrid/power_grid_app.tscn",
			"icon_color": Color(0.95, 0.85, 0.2, 1.0),
			"roles": ["Capitano", "Ingegnere", "Factotum"]
		},
		{
			"id": "cams",
			"title": "Cams",
			"description": "Telecamere esterne dell'astronave",
			"scene_path": "res://Applications/Cams/cams_app.tscn",
			"icon_color": Color(0.3, 0.9, 0.6, 1.0),
			"roles": ["Capitano", "Pilota", "Tattico / Armi", "Sensori / Radar", "Soldato", "Factotum"]
		},
		{
			"id": "weapons",
			"title": "Tactical Weapons",
			"description": "Sistemi d'arma, torrette laser binate, lanciasiluri e PDG",
			"scene_path": "res://Applications/Weapons/weapons_app.tscn",
			"icon_color": Color(0.95, 0.25, 0.25, 1.0),
			"roles": ["Capitano", "Soldato", "Tattico / Armi", "Factotum"]
		},
		{
			"id": "shield_matrix",
			"title": "Shield Matrix",
			"description": "Matrice deflettori a 4 quadranti e scudi energetici",
			"scene_path": "res://Applications/ShieldMatrix/shield_matrix_app.tscn",
			"icon_color": Color(0.2, 0.6, 1.0, 1.0),
			"roles": ["Capitano", "Ingegnere", "Factotum"]
		},
		{
			"id": "comms",
			"title": "Comms & Electronic War",
			"description": "Comunicazioni subspaziali, guerra elettronica EW e decodifica cifrari",
			"scene_path": "res://Applications/Comms/comms_app.tscn",
			"icon_color": Color(0.4, 0.8, 1.0, 1.0),
			"roles": ["Capitano", "Hacker", "Factotum"]
		},
		{
			"id": "diagnostics",
			"title": "System Diagnostics",
			"description": "Centro sicurezza cyber, scansione minacce drive e barriere ICE",
			"scene_path": "res://Applications/Diagnostics/diagnostics_app.tscn",
			"icon_color": Color(0.2, 0.9, 0.7, 1.0),
			"roles": ["Capitano", "Hacker", "Ingegnere", "Factotum"]
		},
		{
			"id": "sensors",
			"title": "Array Sensori & Mappa Tattica",
			"description": "Mappa telemetrica spaziale a lungo raggio e spettrometria",
			"scene_path": "res://Applications/Sensors/sensors_app.tscn",
			"icon_color": Color(0.2, 0.8, 0.4, 1.0),
			"roles": ["Soldier", "Hacker", "Captain", "Factotum", "Soldato", "Capitano", "Sensori / Radar"]
		},
		{
			"id": "life_support",
			"title": "Supporto Vitale & Atmosfera",
			"description": "Monitoraggio e controllo parametri vitali, O2, paratie e antincendio",
			"scene_path": "res://Applications/LifeSupport/life_support_app.tscn",
			"icon_color": Color(0.2, 0.7, 0.9, 1.0),
			"roles": ["Ingegnere", "Capitano", "Factotum", "Engineer", "Captain"]
		},
		{
			"id": "logbook",
			"title": "Registro di Bordo & Obiettivi",
			"description": "Diario di volo, contratti sandbox, scatola nera ed eventi",
			"scene_path": "res://Applications/Logbook/logbook_app.tscn",
			"icon_color": Color(0.8, 0.7, 0.2, 1.0),
			"roles": ["Captain", "Factotum", "Pilot", "Soldier", "Engineer", "Hacker", "Capitano", "Pilota", "Soldato", "Ingegnere"]
		}
	]

# --- METODI DI QUERY E RICERCA ---

func get_room_by_id(room_id: String) -> Dictionary:
	for r in rooms:
		if r.get("id", "") == room_id:
			return r
	return {}

func get_room_at(pos: Vector2) -> Dictionary:
	for r in rooms:
		var rect: Rect2 = r.get("rect", Rect2())
		if rect.has_point(pos):
			return r
	return {}

func get_duct_by_id(duct_id: String) -> Dictionary:
	for d in ducts:
		if d.get("id", "") == duct_id:
			return d
	return {}

func get_device_by_id(dev_id: String) -> Dictionary:
	for dev in devices:
		if dev.get("id", "") == dev_id:
			return dev
	return {}

func get_junction_by_id(junc_id: String) -> Dictionary:
	for j in junctions:
		if j.get("id", "") == junc_id:
			return j
	return {}

func get_damage_by_id(dmg_id: String) -> Dictionary:
	for d in damages:
		if d.get("id", "") == dmg_id:
			return d
	return {}

func get_drive_file_by_path(path: String) -> Dictionary:
	for f in drive_files:
		if f.get("path", "") == path:
			return f
	return {}

func set_drive_file(path: String, content: String, is_protected: bool = false, desc: String = "") -> void:
	for i in range(drive_files.size()):
		if drive_files[i].get("path", "") == path:
			drive_files[i]["content"] = content
			drive_files[i]["is_protected"] = is_protected
			if desc != "":
				drive_files[i]["desc"] = desc
			emit_changed()
			return
	drive_files.append({
		"path": path,
		"content": content,
		"is_protected": is_protected,
		"desc": desc
	})
	emit_changed()

func remove_drive_file(path: String) -> bool:
	for i in range(drive_files.size()):
		if drive_files[i].get("path", "") == path:
			drive_files.remove_at(i)
			emit_changed()
			return true
	return false

func get_drive_password(path: String) -> String:
	return drive_passwords.get(path, "")

func set_drive_password(path: String, password: String) -> void:
	drive_passwords[path] = password
	emit_changed()

func remove_drive_password(path: String) -> bool:
	if drive_passwords.has(path):
		drive_passwords.erase(path)
		emit_changed()
		return true
	return false

func get_installed_app_by_id(app_id: String) -> Dictionary:
	for app in installed_apps:
		if app.get("id", "") == app_id:
			return app
	return {}

func set_installed_app(app_id: String, app_data: Dictionary) -> void:
	for i in range(installed_apps.size()):
		if installed_apps[i].get("id", "") == app_id:
			installed_apps[i] = app_data.duplicate(true)
			installed_apps[i]["id"] = app_id
			emit_changed()
			return
	var new_app := app_data.duplicate(true)
	new_app["id"] = app_id
	installed_apps.append(new_app)
	emit_changed()

func remove_installed_app(app_id: String) -> bool:
	for i in range(installed_apps.size()):
		if installed_apps[i].get("id", "") == app_id:
			installed_apps.remove_at(i)
			emit_changed()
			return true
	return false

func get_apps_for_role(role_name: String, _is_solo: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var clean_role := role_name.strip_edges()
	var is_super := clean_role.is_empty() or clean_role == "Capitano" or clean_role == "Factotum" or clean_role == "HOST"
	
	for app in installed_apps:
		if is_super:
			result.append(app.duplicate(true))
			continue
		
		var allowed: Array = app.get("roles", [])
		if allowed.is_empty():
			result.append(app.duplicate(true))
			continue
			
		var role_matched := false
		for r in allowed:
			var r_str: String = str(r).strip_edges()
			if r_str == "*" or r_str.to_lower() == "all":
				role_matched = true
				break
			if r_str.to_lower() == clean_role.to_lower():
				role_matched = true
				break
			if clean_role != "" and (r_str.to_lower() in clean_role.to_lower() or clean_role.to_lower() in r_str.to_lower()):
				role_matched = true
				break
		
		if role_matched:
			result.append(app.duplicate(true))
	
	if result.is_empty() and (clean_role == "Non Assegnato" or clean_role == ""):
		for app in installed_apps:
			result.append(app.duplicate(true))
	
	return result

## Installa una ShipAppResource nel blueprint registrando app, file di drive e password
func install_app_resource(res: ShipAppResource) -> void:
	if not res:
		return
	set_installed_app(res.app_id, res.to_dict())
	var df_list := res.get_formatted_drive_files("Ship Drive")
	for df in df_list:
		set_drive_file(df["path"], df["content"], df["is_protected"], df["desc"])
	if not res.drive_folder.is_empty() and not res.default_password.is_empty():
		var folder_rel: String = res.drive_folder.trim_prefix("/").trim_suffix("/")
		var full_folder := "Ship Drive/%s" % folder_rel if not folder_rel.begins_with("Ship Drive/") else folder_rel
		set_drive_password(full_folder, res.default_password)

## Restituisce le ShipAppResource installate (usando ShipSoftwareManager o ricostruendole dai dati)
func get_installed_app_resources() -> Array[ShipAppResource]:
	var result: Array[ShipAppResource] = []
	for app_dict in installed_apps:
		var app_id: String = str(app_dict.get("id", ""))
		var ssm = Engine.get_singleton("ShipSoftwareManager") if Engine.has_singleton("ShipSoftwareManager") else null
		var res: ShipAppResource = null
		if ssm and ssm.has_method("get_registered_app"):
			res = ssm.get_registered_app(app_id)
		if not res:
			var res_path := "res://Applications/%s/%s_app.tres" % [app_id.to_pascal_case(), app_id]
			if ResourceLoader.exists(res_path):
				res = load(res_path) as ShipAppResource
		if not res:
			res = ShipAppResource.new()
			res.app_id = app_id
			res.title = str(app_dict.get("title", app_id))
			res.description = str(app_dict.get("description", ""))
			res.scene_path = str(app_dict.get("scene_path", ""))
			res.icon_color = app_dict.get("icon_color", Color(0, 0.79, 0.95, 1.0))
			var raw_roles = app_dict.get("roles", [])
			if raw_roles is Array:
				for r in raw_roles:
					res.roles.append(str(r))
		result.append(res)
	return result

## Restituisce le ShipAppResource autorizzate per il ruolo specificato
func get_app_resources_for_role(role_name: String, is_solo: bool = false) -> Array[ShipAppResource]:
	var all_res := get_installed_app_resources()
	var filtered: Array[ShipAppResource] = []
	for r in all_res:
		if r.is_role_allowed(role_name, is_solo):
			filtered.append(r)
	return filtered

## Converte l'intera Blueprint in un dizionario serializzabile (es. per JSON o salvataggi di rete)
func to_dict() -> Dictionary:
	var rooms_copy: Array = []
	for r: Dictionary in rooms:
		var rc: Dictionary = r.duplicate(true)
		if rc.has("rect") and rc["rect"] is Rect2:
			var rect: Rect2 = rc["rect"]
			rc["rect"] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
		if rc.has("color") and rc["color"] is Color:
			var col: Color = rc["color"]
			rc["color"] = [col.r, col.g, col.b, col.a]
		if rc.has("border_color") and rc["border_color"] is Color:
			var col: Color = rc["border_color"]
			rc["border_color"] = [col.r, col.g, col.b, col.a]
		rooms_copy.append(rc)
	
	var ducts_copy: Array = []
	for d: Dictionary in ducts:
		var dc: Dictionary = d.duplicate(true)
		if dc.has("from") and dc["from"] is Vector2:
			dc["from"] = [dc["from"].x, dc["from"].y]
		if dc.has("to") and dc["to"] is Vector2:
			dc["to"] = [dc["to"].x, dc["to"].y]
		ducts_copy.append(dc)
		
	var devices_copy: Array = []
	for dev: Dictionary in devices:
		var dev_c: Dictionary = dev.duplicate(true)
		if dev_c.has("pos") and dev_c["pos"] is Vector2:
			dev_c["pos"] = [dev_c["pos"].x, dev_c["pos"].y]
		devices_copy.append(dev_c)
		
	var junctions_copy: Array = []
	for j: Dictionary in junctions:
		var jc: Dictionary = j.duplicate(true)
		if jc.has("pos") and jc["pos"] is Vector2:
			jc["pos"] = [jc["pos"].x, jc["pos"].y]
		if jc.has("branches") and jc["branches"] is Array:
			var branches_copy: Array = []
			for b in (jc["branches"] as Array):
				if b is Dictionary:
					var bc: Dictionary = (b as Dictionary).duplicate(true)
					if bc.has("to_pos") and bc["to_pos"] is Vector2:
						bc["to_pos"] = [bc["to_pos"].x, bc["to_pos"].y]
					branches_copy.append(bc)
			jc["branches"] = branches_copy
		junctions_copy.append(jc)

	var damages_copy: Array = []
	for dmg: Dictionary in damages:
		var dmg_c: Dictionary = dmg.duplicate(true)
		if dmg_c.has("pos") and dmg_c["pos"] is Vector2:
			dmg_c["pos"] = [dmg_c["pos"].x, dmg_c["pos"].y]
		damages_copy.append(dmg_c)
		
	var drive_files_copy: Array = []
	for df: Dictionary in drive_files:
		drive_files_copy.append(df.duplicate(true))
		
	var installed_apps_copy: Array = []
	for app: Dictionary in installed_apps:
		var ac: Dictionary = app.duplicate(true)
		if ac.has("icon_color") and ac["icon_color"] is Color:
			var col: Color = ac["icon_color"]
			ac["icon_color"] = [col.r, col.g, col.b, col.a]
		installed_apps_copy.append(ac)
		
	return {
		"ship_id": ship_id,
		"ship_name": ship_name,
		"ship_class": ship_class,
		"ship_bounds": [ship_bounds.position.x, ship_bounds.position.y, ship_bounds.size.x, ship_bounds.size.y],
		"drone_spawn_pos": [drone_spawn_pos.x, drone_spawn_pos.y],
		"drone_spawn_heading": drone_spawn_heading,
		"rooms": rooms_copy,
		"ducts": ducts_copy,
		"devices": devices_copy,
		"junctions": junctions_copy,
		"damages": damages_copy,
		"drive_files": drive_files_copy,
		"drive_passwords": drive_passwords.duplicate(true),
		"installed_apps": installed_apps_copy
	}

## Ricostruisce la blueprint a partire da un dizionario deserializzato
func from_dict(data: Dictionary) -> void:
	if data.has("ship_id"):
		ship_id = str(data["ship_id"])
	if data.has("ship_name"):
		ship_name = str(data["ship_name"])
	if data.has("ship_class"):
		ship_class = str(data["ship_class"])
	if data.has("ship_bounds") and data["ship_bounds"] is Array and data["ship_bounds"].size() == 4:
		var b: Array = data["ship_bounds"]
		ship_bounds = Rect2(float(b[0]), float(b[1]), float(b[2]), float(b[3]))
	if data.has("drone_spawn_pos") and data["drone_spawn_pos"] is Array and data["drone_spawn_pos"].size() == 2:
		var p: Array = data["drone_spawn_pos"]
		drone_spawn_pos = Vector2(float(p[0]), float(p[1]))
	if data.has("drone_spawn_heading"):
		drone_spawn_heading = float(data["drone_spawn_heading"])
		
	if data.has("rooms") and data["rooms"] is Array:
		var new_rooms: Array[Dictionary] = []
		for r in data["rooms"]:
			if r is Dictionary:
				var rd := (r as Dictionary).duplicate(true)
				if rd.has("rect") and rd["rect"] is Array and rd["rect"].size() == 4:
					var arr: Array = rd["rect"]
					rd["rect"] = Rect2(float(arr[0]), float(arr[1]), float(arr[2]), float(arr[3]))
				if rd.has("color") and rd["color"] is Array and rd["color"].size() >= 3:
					var arr: Array = rd["color"]
					var a := float(arr[3]) if arr.size() > 3 else 1.0
					rd["color"] = Color(float(arr[0]), float(arr[1]), float(arr[2]), a)
				if rd.has("border_color") and rd["border_color"] is Array and rd["border_color"].size() >= 3:
					var arr: Array = rd["border_color"]
					var a := float(arr[3]) if arr.size() > 3 else 1.0
					rd["border_color"] = Color(float(arr[0]), float(arr[1]), float(arr[2]), a)
				new_rooms.append(rd)
		rooms = new_rooms
		
	if data.has("ducts") and data["ducts"] is Array:
		var new_ducts: Array[Dictionary] = []
		for d in data["ducts"]:
			if d is Dictionary:
				var dd := (d as Dictionary).duplicate(true)
				if dd.has("from") and dd["from"] is Array and dd["from"].size() == 2:
					var arr: Array = dd["from"]
					dd["from"] = Vector2(float(arr[0]), float(arr[1]))
				if dd.has("to") and dd["to"] is Array and dd["to"].size() == 2:
					var arr: Array = dd["to"]
					dd["to"] = Vector2(float(arr[0]), float(arr[1]))
				new_ducts.append(dd)
		ducts = new_ducts

	if data.has("devices") and data["devices"] is Array:
		var new_devs: Array[Dictionary] = []
		for dev in data["devices"]:
			if dev is Dictionary:
				var dev_d := (dev as Dictionary).duplicate(true)
				if dev_d.has("pos") and dev_d["pos"] is Array and dev_d["pos"].size() == 2:
					var arr: Array = dev_d["pos"]
					dev_d["pos"] = Vector2(float(arr[0]), float(arr[1]))
				new_devs.append(dev_d)
		devices = new_devs

	if data.has("junctions") and data["junctions"] is Array:
		var new_juncs: Array[Dictionary] = []
		for j in data["junctions"]:
			if j is Dictionary:
				var jd := (j as Dictionary).duplicate(true)
				if jd.has("pos") and jd["pos"] is Array and jd["pos"].size() == 2:
					var arr: Array = jd["pos"]
					jd["pos"] = Vector2(float(arr[0]), float(arr[1]))
				if jd.has("branches") and jd["branches"] is Array:
					var new_branches: Array[Dictionary] = []
					for b in jd["branches"]:
						if b is Dictionary:
							var bd := (b as Dictionary).duplicate(true)
							if bd.has("to_pos") and bd["to_pos"] is Array and bd["to_pos"].size() == 2:
								var arr: Array = bd["to_pos"]
								bd["to_pos"] = Vector2(float(arr[0]), float(arr[1]))
							new_branches.append(bd)
					jd["branches"] = new_branches
				new_juncs.append(jd)
		junctions = new_juncs

	if data.has("damages") and data["damages"] is Array:
		var new_damages: Array[Dictionary] = []
		for dmg in data["damages"]:
			if dmg is Dictionary:
				var dmg_d := (dmg as Dictionary).duplicate(true)
				if dmg_d.has("pos") and dmg_d["pos"] is Array and dmg_d["pos"].size() == 2:
					var arr: Array = dmg_d["pos"]
					dmg_d["pos"] = Vector2(float(arr[0]), float(arr[1]))
				new_damages.append(dmg_d)
		damages = new_damages

	if data.has("drive_files") and data["drive_files"] is Array:
		var new_df: Array[Dictionary] = []
		for item in data["drive_files"]:
			if item is Dictionary:
				new_df.append((item as Dictionary).duplicate(true))
		drive_files = new_df

	if data.has("drive_passwords") and data["drive_passwords"] is Dictionary:
		drive_passwords = (data["drive_passwords"] as Dictionary).duplicate(true)

	if data.has("installed_apps") and data["installed_apps"] is Array:
		var new_apps: Array[Dictionary] = []
		for app in data["installed_apps"]:
			if app is Dictionary:
				var ad := (app as Dictionary).duplicate(true)
				if ad.has("icon_color") and ad["icon_color"] is Array and ad["icon_color"].size() >= 3:
					var arr: Array = ad["icon_color"]
					var a := float(arr[3]) if arr.size() > 3 else 1.0
					ad["icon_color"] = Color(float(arr[0]), float(arr[1]), float(arr[2]), a)
				elif ad.has("icon_color") and ad["icon_color"] is String:
					ad["icon_color"] = Color.from_string(ad["icon_color"], Color.WHITE)
				new_apps.append(ad)
		installed_apps = new_apps

	emit_changed()

## Esporta la Blueprint in formato JSON su disco
func export_to_json(file_path: String) -> Error:
	var dict := to_dict()
	var json_text := JSON.stringify(dict, "\t")
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(json_text)
	file.close()
	return OK

## Importa la Blueprint da formato JSON
func import_from_json(file_path: String) -> Error:
	if not FileAccess.file_exists(file_path):
		return ERR_FILE_NOT_FOUND
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var json_text := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_err := json.parse(json_text)
	if parse_err != OK:
		return parse_err
	if json.data is Dictionary:
		from_dict(json.data as Dictionary)
		return OK
	return ERR_INVALID_DATA

## Clona l'istanza corrente
func clone() -> ShipBlueprint:
	var copy := ShipBlueprint.new()
	copy.from_dict(to_dict())
	return copy

static func get_default_blueprint() -> ShipBlueprint:
	const PATH := "res://Outside/ShipSublayer/default_ship_blueprint.tres"
	if ResourceLoader.exists(PATH):
		var res = ResourceLoader.load(PATH)
		if res is ShipBlueprint:
			return res as ShipBlueprint
	var bp := ShipBlueprint.new()
	bp.create_default_ship()
	return bp
