class_name SpaceStationEntity
extends Node3D

## Rappresenta un'entità spaziale 3D di Stazione Orbitale / Porto Spaziale per Dark Nova.
## Gestisce coordinate telemetriche, coni di docking, identificazione IFF e servizi offerti.

signal docking_bay_occupied(bay_index: int, ship_id: String)
signal docking_bay_freed(bay_index: int)
signal station_scanned(station_data: Dictionary)

@export var station_id: String = "station_alpha_outpost"
@export var station_name: String = "Stazione Orbitale 'Aegis Outpost'"
@export var station_type: String = "Military / Trade Hub"
@export var faction_iff: String = "SOL-NAV-DEFENSE"
@export var comms_frequency: float = 142.85 # MHz diegetica per autorizzazione
@export var security_clearance_required: int = 1

# Telemetria & Parametri Cono di Cattura Magnetica
@export var capture_radius: float = 45.0 # Raggio massimo di ingaggio guida
@export var magnetic_lock_distance: float = 6.0 # Distanza di aggancio finale
@export var alignment_tolerance_angle_deg: float = 30.0 # Angolo max di tolleranza di approccio
@export var max_approach_speed: float = 15.0 # Tolleranza max velocità nave per non abortire

# Array di Docking Bays disponibili (offset locali relativi alla stazione e direzione normale)
@export var docking_bays: Array[Dictionary] = [
	{
		"id": 0,
		"name": "Bay 01 - Baia Principale Prua",
		"local_pos": Vector3(0, 0, 15.0),
		"approach_vector": Vector3(0, 0, 1.0), # Vettore uscente dal porto
		"is_occupied": false,
		"assigned_ship_id": ""
	},
	{
		"id": 1,
		"name": "Bay 02 - Baia Merci Babor",
		"local_pos": Vector3(-20.0, 0, 0),
		"approach_vector": Vector3(-1.0, 0, 0),
		"is_occupied": false,
		"assigned_ship_id": ""
	},
	{
		"id": 2,
		"name": "Bay 03 - Baia Tecnica Tribor",
		"local_pos": Vector3(20.0, 0, 0),
		"approach_vector": Vector3(1.0, 0, 0),
		"is_occupied": false,
		"assigned_ship_id": ""
	}
]

# Servizi offerti dal porto
@export var services_available: Dictionary = {
	"shipyard": true,        # Riparazione scafo, manutenzione condotti, ricarica batterie, naniti
	"software_market": true, # Compravendita programmi diegetici, script terminale, driver
	"contracts_board": true, # Bacheca contratti e ufficio taglie sinc con logbook
	"tavern": true           # Taverna Spaziale per rumors e coordinate
}

# Inventario / Dati specifici del mercato e contratti offerti da questa stazione
@export var market_catalog: Array[Dictionary] = []
@export var active_contracts: Array[Dictionary] = []
@export var tavern_rumors: Array[Dictionary] = []
@export var warehouse_cargo: Array[Dictionary] = []

func _ready() -> void:
	_init_station_defaults()

func _init_station_defaults() -> void:
	if market_catalog.is_empty():
		market_catalog = [
			{
				"id": "patch_ecm_v2",
				"name": "Algoritmo Decrittazione Nova-Pulse v2.4",
				"category": "Software",
				"price": 450,
				"app_target_folder": "Comms",
				"filename": "crypto_tuning.dat",
				"content": "# EW & CRYPTO TUNING OVERCLOCK MATRIX\n[ELECTRONIC_WARFARE]\njamming_power_mw=150.0\nsignal_noise_ratio=0.92\nspoofing_signature=MILITARY_ESCORT\njamming_radius=18000.0\noverclock_ew_boost=1.25\ncrypto_crack_speed=1.5\n",
				"description": "Ottimizzazione cifrari subspaziali per Comms & EW. Velocità decodifica +50%."
			},
			{
				"id": "driver_overclock_rcs",
				"name": "Driver Propulsori RCS Overclock 'Viper-9'",
				"category": "Firmware",
				"price": 600,
				"app_target_folder": "FlightControls",
				"filename": "thrusters_tuning.dat",
				"content": "# RCS & MAIN THRUSTERS TUNING MATRIX\n[THRUSTERS]\nrcs_power_rate=1.35\npitch_thrust_mult=1.3\nyaw_thrust_mult=1.3\nroll_thrust_mult=1.3\nvertical_thrust_mult=1.3\noverclock_limit=1.8\n",
				"description": "Firmware a bassa latenza per propulsori di manovra Flight Control."
			},
			{
				"id": "script_auto_ping",
				"name": "Script Terminale 'DeepScan.sh'",
				"category": "Script",
				"price": 250,
				"app_target_folder": "Sensors",
				"filename": "deepscan.sh",
				"content": "#!/bin/bash\n# DeepScan automated sweep\necho 'Scanning active sector for gravitational anomalies...'\n",
				"description": "Script bash diegetico per scansione periodica automatica del quadrante sensori."
			},
			{
				"id": "sw_firewall_adv",
				"name": "Firewall Subspaziale 'Aegis-IV'",
				"category": "Software",
				"price": 400,
				"app_target_folder": "Diagnostics",
				"filename": "security_tuning.dat",
				"content": "# ICE DEFENSE & SECURITY TUNING\n[ICE_DEFENSE]\nice_firewall_strength=150.0\ntamper_detection_level=MAXIMUM\nice_recharge_rate=8.0\nmalware_purge_efficiency=1.5\n",
				"description": "Schermatura contro tentativi di hackwarfare e malware."
			}
		]
	
	if active_contracts.is_empty():
		active_contracts = [
			{
				"id": "contract_patrol_01",
				"title": "Pattugliamento Settore Asteroidi 'Theta-9'",
				"issuer": "Autorità Portuale di Settore",
				"reward_credits": 1200,
				"reward_flux": 1800,
				"description": "Scansione e verifica di 3 anomalie gravitazionali nel campo asteroidale.",
				"target_sector": "Theta-9",
				"is_accepted": false,
				"is_completed": false
			},
			{
				"id": "contract_bounty_pirate",
				"title": "Taglia: Corsaro 'Red Vulture'",
				"issuer": "Consorzio di Sicurezza Spaziale",
				"reward_credits": 2500,
				"reward_flux": 3200,
				"description": "Neutralizzare o scansionare la fregata pirata nell'avamposto periferico.",
				"target_sector": "Zeta-3",
				"is_accepted": false,
				"is_completed": false
			},
			{
				"id": "contract_cargo_nanites",
				"title": "Consegna Merci: 100x Naniti Medici",
				"issuer": "Laboratorio Bio-Sintetico",
				"reward_credits": 800,
				"reward_flux": 1000,
				"description": "Trasporto e consegna componenti critici per i filtri di Life Support.",
				"target_sector": "Centauri-Prime",
				"is_accepted": false,
				"is_completed": false
			}
		]
		
	if tavern_rumors.is_empty():
		tavern_rumors = [
			{
				"id": "rumor_derelict_freighter",
				"source": "Vecchio Minatore di Silicio",
				"text": "Ho intercettato un transponder SOS debole vicino al cluster Sigma-4. Sembra una nave cargo abbandonata piena di leghe di titanio.",
				"coordinates": Vector3(1450.0, 220.0, -890.0),
				"discovered_poi": "Relitto Fregata Cargo Titan-14"
			},
			{
				"id": "rumor_pirate_frequency",
				"source": "Contrabbandiere incappucciato",
				"text": "Se sintonizzate le comunicazioni su 184.50 MHz vicino alla fascia di asteroidi, potreste intercettare i codici cifrati del sindacato pirata.",
				"coordinates": Vector3(-500.0, 10.0, 1200.0),
				"discovered_poi": "Avamposto Clandestino Pirata"
			}
		]
	
	if warehouse_cargo.is_empty():
		warehouse_cargo = [
			{
				"id": "minerals_titanium",
				"name": "Titanio Grezzo",
				"category": "MINERAL",
				"unit_mass_kg": 25.0,
				"unit_volume_m3": 0.8,
				"unit_base_value": 120.0,
				"quantity": 50,
				"description": "Minerali di titanio grezzo estratti da asteroidi."
			},
			{
				"id": "alloys_durasteel",
				"name": "Leghe Raffinate Durasteel",
				"category": "ALLOY",
				"unit_mass_kg": 40.0,
				"unit_volume_m3": 0.5,
				"unit_base_value": 350.0,
				"quantity": 25,
				"description": "Lingotti compositi per corazzature e cantieri navali."
			},
			{
				"id": "ammo_railgun",
				"name": "Munizioni Sabot Railgun",
				"category": "AMMO",
				"unit_mass_kg": 15.0,
				"unit_volume_m3": 0.2,
				"unit_base_value": 220.0,
				"quantity": 40,
				"description": "Proiettili cinetici al tungsteno-uranio per torrette pesanti."
			},
			{
				"id": "energy_cell",
				"name": "Celle Energetiche al Plasma",
				"category": "ENERGY_CELL",
				"unit_mass_kg": 10.0,
				"unit_volume_m3": 0.3,
				"unit_base_value": 180.0,
				"quantity": 30,
				"description": "Condensatori al plasma ad alta densità per ricarica sublayer e scudi."
			}
		]

## Ritorna le info telematiche complete della stazione
func get_telemetry_data() -> Dictionary:
	return {
		"id": station_id,
		"name": station_name,
		"type": station_type,
		"iff": faction_iff,
		"comms_frequency": comms_frequency,
		"global_position": global_position,
		"capture_radius": capture_radius,
		"magnetic_lock_distance": magnetic_lock_distance,
		"alignment_tolerance_angle_deg": alignment_tolerance_angle_deg,
		"max_approach_speed": max_approach_speed,
		"docking_bays": docking_bays,
		"services_available": services_available
	}

## Trova uno slot di docking libero
func get_available_docking_bay() -> int:
	for bay in docking_bays:
		if not bay.get("is_occupied", false):
			return int(bay.get("id"))
	return -1

## Assegna uno slot di docking a una nave
func assign_docking_bay(bay_id: int, ship_id: String) -> bool:
	for i in range(docking_bays.size()):
		if docking_bays[i].get("id") == bay_id:
			if docking_bays[i].get("is_occupied"):
				return false
			docking_bays[i]["is_occupied"] = true
			docking_bays[i]["assigned_ship_id"] = ship_id
			docking_bay_occupied.emit(bay_id, ship_id)
			return true
	return false

## Rilascia uno slot di docking occupato
func release_docking_bay(bay_id: int) -> void:
	for i in range(docking_bays.size()):
		if docking_bays[i].get("id") == bay_id:
			docking_bays[i]["is_occupied"] = false
			docking_bays[i]["assigned_ship_id"] = ""
			docking_bay_freed.emit(bay_id)
			break

## Calcola la posizione globale e il vettore di approccio di un dato bay
func get_bay_global_transform(bay_id: int) -> Transform3D:
	for bay in docking_bays:
		if bay.get("id") == bay_id:
			var local_pos: Vector3 = bay.get("local_pos", Vector3.ZERO)
			var target_pos := global_transform * local_pos
			return Transform3D(global_transform.basis, target_pos)
	return global_transform
