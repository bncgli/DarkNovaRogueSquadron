class_name StationHubApp
extends Control

## StationHubApp (Applications/StationHub)
## Interfaccia diegetica a finestre di GodotOS per i servizi portuali e stazioni spaziali:
## 1. Cantiere Navale & Riparazioni (Hull, condotti, ricarica batterie, naniti)
## 2. Mercato Software & Repository Firmware (Software, driver RCS, script terminale)
## 3. Bacheca Contratti & Ufficio Taglie (Sincronizzazione logbook)
## 4. Taverna Spaziale & Intercettazione Frequenze (Rumors, coordinate relitti)

# Costanti di architettura e percorsi di storage diegetico
const CONFIG_PATH_PRIMARY: String = "Ship Drive/Programs/StationHub/station_hub_config.dat"
const CONFIG_PATH_FALLBACK: String = "Terminal Drive/Programs/StationHub/station_hub_config.dat"
const MARKET_PATH_PRIMARY: String = "Ship Drive/Programs/StationHub/market_manifest.dat"

# Riferimenti UI
@onready var disconnected_overlay: Control = get_node_or_null("%DisconnectedOverlay")
@onready var undocked_overlay: Control = get_node_or_null("%UndockedOverlay")
@onready var tab_container: TabContainer = get_node_or_null("%TabContainer")
@onready var station_title_label: Label = get_node_or_null("%StationTitleLabel")
@onready var station_sub_label: Label = get_node_or_null("%StationSubLabel")
@onready var credits_label: Label = get_node_or_null("%CreditsLabel")
@onready var btn_undock: Button = get_node_or_null("%BtnUndock")

# Cantiere UI
@onready var hull_bar: ProgressBar = get_node_or_null("%HullBar")
@onready var hull_status_lbl: Label = get_node_or_null("%HullStatusLbl")
@onready var btn_repair_hull: Button = get_node_or_null("%BtnRepairHull")
@onready var btn_service_ducts: Button = get_node_or_null("%BtnServiceDucts")
@onready var btn_recharge_battery: Button = get_node_or_null("%BtnRechargeBattery")
@onready var btn_buy_nanites: Button = get_node_or_null("%BtnBuyNanites")

# Mercato UI
@onready var market_item_list: ItemList = get_node_or_null("%MarketItemList")
@onready var market_desc_label: RichTextLabel = get_node_or_null("%MarketDescLabel")
@onready var btn_buy_market_item: Button = get_node_or_null("%BtnBuyMarketItem")

# Contratti UI
@onready var contracts_item_list: ItemList = get_node_or_null("%ContractsItemList")
@onready var contract_detail_label: RichTextLabel = get_node_or_null("%ContractDetailLabel")
@onready var btn_accept_contract: Button = get_node_or_null("%BtnAcceptContract")

# Taverna UI
@onready var tavern_rumors_list: ItemList = get_node_or_null("%TavernRumorsList")
@onready var rumor_detail_label: RichTextLabel = get_node_or_null("%RumorDetailLabel")
@onready var btn_record_coordinates: Button = get_node_or_null("%BtnRecordCoordinates")

# Stato applicativo
var is_ship_connected: bool = false
var is_station_docked: bool = false
var current_station_id: String = ""
var current_station_data: Dictionary = {}
var can_manage_services: bool = true # RBAC
var credits: int = 5000
var player_nanites: int = 15

# Cache dati attivi
var active_market_items: Array[Dictionary] = []
var active_contracts: Array[Dictionary] = []
var active_rumors: Array[Dictionary] = []
var selected_market_idx: int = -1
var selected_contract_idx: int = -1
var selected_rumor_idx: int = -1

# Riferimento al DockingManager se presente
var docking_manager: DockingManager = null

func _ready() -> void:
	_init_runtime_files()
	_load_config()
	_connect_signals()
	_check_initial_state()

func _connect_signals() -> void:
	# SpaceWorldManager
	if SpaceWorldManager:
		if SpaceWorldManager.has_signal("ship_connection_changed"):
			SpaceWorldManager.ship_connection_changed.connect(_on_ship_connection_changed)
	
	# NetworkManager (RBAC)
	var net_mgr = get_node_or_null("/root/NetworkManager")
	if net_mgr:
		if net_mgr.has_signal("role_changed"):
			net_mgr.role_changed.connect(_on_role_changed)
		if net_mgr.has_signal("session_mode_changed"):
			net_mgr.session_mode_changed.connect(_on_session_mode_changed)
			
	# ShipDrive hot-reload
	var sdm = get_node_or_null("/root/ShipDriveManager")
	if sdm and sdm.has_signal("file_synced"):
		sdm.file_synced.connect(_on_drive_file_synced)
		
	# UI Button signals
	if btn_undock:
		btn_undock.pressed.connect(_on_btn_undock_pressed)
	if btn_repair_hull:
		btn_repair_hull.pressed.connect(_on_repair_hull_pressed)
	if btn_service_ducts:
		btn_service_ducts.pressed.connect(_on_service_ducts_pressed)
	if btn_recharge_battery:
		btn_recharge_battery.pressed.connect(_on_recharge_battery_pressed)
	if btn_buy_nanites:
		btn_buy_nanites.pressed.connect(_on_buy_nanites_pressed)
	if market_item_list:
		market_item_list.item_selected.connect(_on_market_item_selected)
	if btn_buy_market_item:
		btn_buy_market_item.pressed.connect(_on_buy_market_item_pressed)
	if contracts_item_list:
		contracts_item_list.item_selected.connect(_on_contract_item_selected)
	if btn_accept_contract:
		btn_accept_contract.pressed.connect(_on_accept_contract_pressed)
	if tavern_rumors_list:
		tavern_rumors_list.item_selected.connect(_on_rumor_item_selected)
	if btn_record_coordinates:
		btn_record_coordinates.pressed.connect(_on_record_coordinates_pressed)

func _check_initial_state() -> void:
	if SpaceWorldManager and "is_ship_connected_state" in SpaceWorldManager:
		_on_ship_connection_changed(SpaceWorldManager.is_ship_connected_state)
	else:
		_on_ship_connection_changed(true)
		
	_evaluate_rbac()
	_update_credits_display()

## Connette un DockingManager per sincronizzazione automatica degli eventi
func bind_docking_manager(dm: DockingManager) -> void:
	docking_manager = dm
	if not dm:
		return
	if not dm.docking_completed.is_connected(_on_docking_completed):
		dm.docking_completed.connect(_on_docking_completed)
	if not dm.undocking_completed.is_connected(_on_undocking_completed):
		dm.undocking_completed.connect(_on_undocking_completed)
	if dm.is_docked and dm.target_station:
		_on_docking_completed(dm.target_station.station_id, dm.assigned_bay_id, dm.target_station.get_telemetry_data())

func _on_docking_completed(station_id: String, bay_id: int, station_data: Dictionary) -> void:
	is_station_docked = true
	current_station_id = station_id
	current_station_data = station_data
	
	if undocked_overlay:
		undocked_overlay.visible = false
		
	if station_title_label:
		station_title_label.text = "⚓ %s" % station_data.get("name", "Stazione Spaziale")
	if station_sub_label:
		station_sub_label.text = "Settore Operativo | Connesso a Bay 0%d | Fazione: %s" % [bay_id + 1, station_data.get("iff", "NEUTRAL")]
		
	_populate_hub_data(station_data)

func _on_undocking_completed() -> void:
	is_station_docked = false
	current_station_id = ""
	current_station_data.clear()
	
	if undocked_overlay:
		undocked_overlay.visible = true
	if station_title_label:
		station_title_label.text = "DISCONNESSO DA STAZIONE"
	if station_sub_label:
		station_sub_label.text = "Nessun aggancio magnetico attivo."

## Popola le 4 sezioni diegetiche con i dati della stazione
func _populate_hub_data(st_data: Dictionary) -> void:
	# 1. Cantiere
	_refresh_shipyard_view()
	
	# 2. Mercato Software
	if market_item_list:
		market_item_list.clear()
		active_market_items.clear()
		if docking_manager and docking_manager.target_station:
			active_market_items = docking_manager.target_station.market_catalog.duplicate(true)
		else:
			active_market_items = [
				{"id": "sw_firewall_adv", "name": "Firewall Subspaziale 'Aegis-IV'", "category": "Software", "price": 400, "description": "Schermatura contro tentativi di hackwarfare."},
				{"id": "fw_reactor_tune", "name": "Firmware Reattore Sovra-Induttivo", "category": "Firmware", "price": 550, "description": "Tuning potenza per PowerGrid."},
				{"id": "mat_nanites", "name": "Cassa Naniti Riparazione (x20)", "category": "Materiale", "price": 180, "description": "Naniti per saldatura scafo."}
			]
		for item in active_market_items:
			market_item_list.add_item("[%s] %s (%d cr)" % [item.get("category", ""), item.get("name", ""), item.get("price", 0)])
			
	# 3. Bacheca Contratti
	if contracts_item_list:
		contracts_item_list.clear()
		active_contracts.clear()
		if docking_manager and docking_manager.target_station:
			active_contracts = docking_manager.target_station.active_contracts.duplicate(true)
		else:
			active_contracts = [
				{"id": "cnt_patrol", "title": "Pattuglia di Sicurezza Settore", "reward_credits": 900, "description": "Ronda perimetrale attorno all'avamposto.", "is_accepted": false},
				{"id": "cnt_repair", "title": "Riparazione Satellite Spia", "reward_credits": 1400, "description": "Intervento EVA con saldatore drone.", "is_accepted": false}
			]
		for cnt in active_contracts:
			var prefix := "✓ " if cnt.get("is_accepted", false) else "• "
			contracts_item_list.add_item("%s%s - %d CR" % [prefix, cnt.get("title", ""), cnt.get("reward_credits", 0)])
			
	# 4. Taverna Spaziale
	if tavern_rumors_list:
		tavern_rumors_list.clear()
		active_rumors.clear()
		if docking_manager and docking_manager.target_station:
			active_rumors = docking_manager.target_station.tavern_rumors.duplicate(true)
		else:
			active_rumors = [
				{"id": "rum_1", "source": "Mercante Errante", "text": "Coordinate di un cargo abbandonato registrate a bordo.", "coordinates": Vector3(120, -50, 400), "discovered_poi": "Relitto Alpha"}
			]
		for rum in active_rumors:
			tavern_rumors_list.add_item("Diceria: %s" % rum.get("source", "Sconosciuto"))

func _refresh_shipyard_view() -> void:
	if hull_bar:
		hull_bar.value = 100.0
	if hull_status_lbl:
		hull_status_lbl.text = "Integrità Scafo: 100%% | Naniti Disponibili: %d" % player_nanites

func _update_credits_display() -> void:
	if credits_label:
		credits_label.text = "Crediti: %d CR" % credits

# Handlers Cantiere
func _on_repair_hull_pressed() -> void:
	if not can_manage_services or not is_station_docked: return
	var cost := 150
	if credits >= cost:
		credits -= cost
		_update_credits_display()
		_notify("Cantiere Navale", "Riparazioni scafo completate con successo (-%d CR)." % cost)
	else:
		_notify("Cantiere Navale", "Crediti insufficienti per riparare lo scafo.")

func _on_service_ducts_pressed() -> void:
	if not can_manage_services or not is_station_docked: return
	var cost := 100
	if credits >= cost:
		credits -= cost
		_update_credits_display()
		_notify("Cantiere Navale", "Manutenzione condotti e rimozione anomalie completata (-%d CR)." % cost)

func _on_recharge_battery_pressed() -> void:
	if not can_manage_services or not is_station_docked: return
	var cost := 50
	if credits >= cost:
		credits -= cost
		_update_credits_display()
		_notify("Cantiere Navale", "Accumulatori e batterie della nave ricaricati al 100% (-%d CR)." % cost)

func _on_buy_nanites_pressed() -> void:
	if not can_manage_services or not is_station_docked: return
	var cost := 200
	if credits >= cost:
		credits -= cost
		player_nanites += 25
		_update_credits_display()
		_refresh_shipyard_view()
		_notify("Cantiere Navale", "Acquistato kit 25x Naniti di Riparazione (-%d CR)." % cost)

# Handlers Mercato
func _on_market_item_selected(index: int) -> void:
	selected_market_idx = index
	if index >= 0 and index < active_market_items.size():
		var item = active_market_items[index]
		if market_desc_label:
			market_desc_label.text = "[b]%s[/b]\nCategoria: %s\nPrezzo: %d CR\n\n%s" % [
				item.get("name", ""),
				item.get("category", ""),
				item.get("price", 0),
				item.get("description", "")
			]
		if btn_buy_market_item:
			btn_buy_market_item.disabled = not can_manage_services or credits < item.get("price", 0)

func _on_buy_market_item_pressed() -> void:
	if not can_manage_services or selected_market_idx < 0 or selected_market_idx >= active_market_items.size():
		return
	var item = active_market_items[selected_market_idx]
	var price: int = item.get("price", 0)
	if credits >= price:
		credits -= price
		_update_credits_display()
		_notify("Mercato Firmware", "Acquistato: %s per %d CR." % [item.get("name", ""), price])
		if btn_buy_market_item:
			btn_buy_market_item.disabled = credits < price

# Handlers Contratti
func _on_contract_item_selected(index: int) -> void:
	selected_contract_idx = index
	if index >= 0 and index < active_contracts.size():
		var cnt = active_contracts[index]
		if contract_detail_label:
			var status_str := "[color=#00ff88]ACCETTATO[/color]" if cnt.get("is_accepted", false) else "[color=#ffcc00]DISPONIBILE[/color]"
			contract_detail_label.text = "[b]%s[/b]\nEmittente: %s\nRicompensa: %d CR\nStato: %s\n\n%s" % [
				cnt.get("title", ""),
				cnt.get("issuer", "Port Authority"),
				cnt.get("reward_credits", 0),
				status_str,
				cnt.get("description", "")
			]
		if btn_accept_contract:
			btn_accept_contract.disabled = not can_manage_services or cnt.get("is_accepted", false)

func _on_accept_contract_pressed() -> void:
	if not can_manage_services or selected_contract_idx < 0 or selected_contract_idx >= active_contracts.size():
		return
	var cnt = active_contracts[selected_contract_idx]
	cnt["is_accepted"] = true
	_notify("Bacheca Contratti", "Contratto registrato nel Logbook di bordo: %s" % cnt.get("title", ""))
	_on_contract_item_selected(selected_contract_idx)
	if contracts_item_list:
		contracts_item_list.set_item_text(selected_contract_idx, "✓ %s - %d CR" % [cnt.get("title", ""), cnt.get("reward_credits", 0)])

# Handlers Taverna
func _on_rumor_item_selected(index: int) -> void:
	selected_rumor_idx = index
	if index >= 0 and index < active_rumors.size():
		var rum = active_rumors[index]
		if rumor_detail_label:
			rumor_detail_label.text = "[b]Fonte: %s[/b]\nCoordinate: %s\n\n\"%s\"" % [
				rum.get("source", ""),
				str(rum.get("coordinates", Vector3.ZERO)),
				rum.get("text", "")
			]
		if btn_record_coordinates:
			btn_record_coordinates.disabled = not can_manage_services

func _on_record_coordinates_pressed() -> void:
	if selected_rumor_idx < 0 or selected_rumor_idx >= active_rumors.size():
		return
	var rum = active_rumors[selected_rumor_idx]
	_notify("Taverna Spaziale", "Coordinate di '%s' inviate ai Sensori e Logbook." % rum.get("discovered_poi", "POI"))

func _on_btn_undock_pressed() -> void:
	if not can_manage_services or not is_station_docked:
		return
	if docking_manager:
		docking_manager.request_undock()
	else:
		_on_undocking_completed()

func _on_ship_connection_changed(connected: bool) -> void:
	is_ship_connected = connected
	if disconnected_overlay:
		disconnected_overlay.visible = not connected

func _on_role_changed(_role: String) -> void:
	_evaluate_rbac()

func _on_session_mode_changed(_mode: int) -> void:
	_evaluate_rbac()

func _evaluate_rbac() -> void:
	var net_mgr = get_node_or_null("/root/NetworkManager")
	var role: String = "Capitano"
	if net_mgr and "player_role" in net_mgr:
		role = net_mgr.player_role
	
	# Ruoli autorizzati ai servizi di stazione: Capitano, Ingegnere, Hacker, Pilota, Factotum
	can_manage_services = (role == "Capitano" or role == "Ingegnere" or role == "Hacker" or role == "Pilota" or role == "Factotum")
	
	if btn_repair_hull: btn_repair_hull.disabled = not can_manage_services
	if btn_service_ducts: btn_service_ducts.disabled = not can_manage_services
	if btn_recharge_battery: btn_recharge_battery.disabled = not can_manage_services
	if btn_buy_nanites: btn_buy_nanites.disabled = not can_manage_services
	if btn_undock: btn_undock.disabled = not can_manage_services

func _init_runtime_files() -> void:
	var sdm = get_node_or_null("/root/ShipDriveManager")
	var fpm = get_node_or_null("/root/FolderPasswordManager")
	
	if fpm and fpm.has_method("set_password"):
		fpm.set_password("Ship Drive/Programs/StationHub", "STTN-7815")
		
	var default_config := """# CONFIGURAZIONE STATION HUB & DOCKING SUITE
[SYSTEM]
app_name=StationHubApp
version=1.0.0
status=OPERATIONAL

[SERVICES]
auto_handshake=true
default_credits=5000
allow_firmware_trade=true
logbook_sync=true
"""
	var abs_dir := "user://files/Ship Drive/Programs/StationHub"
	if not DirAccess.dir_exists_absolute(abs_dir):
		DirAccess.make_dir_recursive_absolute(abs_dir)
		
	var cfg_abs := "user://files/" + CONFIG_PATH_PRIMARY
	if not FileAccess.file_exists(cfg_abs):
		var f := FileAccess.open(cfg_abs, FileAccess.WRITE)
		if f:
			f.store_string(default_config)
			f.close()
			
	if sdm and sdm.has_method("sync_file"):
		sdm.sync_file(CONFIG_PATH_PRIMARY, default_config)

func _load_config() -> void:
	var cfg_abs := "user://files/" + CONFIG_PATH_PRIMARY
	if not FileAccess.file_exists(cfg_abs):
		cfg_abs = "user://files/" + CONFIG_PATH_FALLBACK
	if FileAccess.file_exists(cfg_abs):
		var f := FileAccess.open(cfg_abs, FileAccess.READ)
		if f:
			var txt := f.get_as_text()
			f.close()
			_parse_config_text(txt)

func _parse_config_text(txt: String) -> void:
	var lines := txt.split("\n")
	for line in lines:
		var l := line.strip_edges()
		if l.begins_with("#") or l.begins_with(";") or l.is_empty():
			continue
		var parts := l.split("=", false, 2)
		if parts.size() == 2:
			var k := parts[0].strip_edges()
			var v := parts[1].strip_edges()
			if k == "default_credits" and v.is_valid_int():
				credits = v.to_int()
				_update_credits_display()

func _on_drive_file_synced(rel_path: String) -> void:
	if "StationHub" in rel_path and rel_path.ends_with(".dat"):
		_load_config()

func _notify(title: String, msg: String) -> void:
	var nm = get_node_or_null("/root/NotificationManager")
	if nm and nm.has_method("send_notification"):
		nm.send_notification(title, msg)
