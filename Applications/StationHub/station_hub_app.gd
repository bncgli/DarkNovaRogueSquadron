class_name StationHubApp
extends Control

## StationHubApp (Applications/StationHub)
## Interfaccia diegetica a finestre di GodotOS per i servizi portuali e stazioni spaziali:
## 1. Logistica & Cargo Market (Compravendita bidirezionale merci e rating FLUX)
## 2. Bacheca Contratti & Ufficio Taglie (Sincronizzazione logbook)
## 3. Software & Firmware Repository (Download driver e programmi su Ship Drive)
## 4. Cantiere Navale & Riparazioni (Hull, brecce, condotti, ricarica batterie, naniti)
## 5. Taverna Spaziale & Intercettazione Frequenze (Rumors, coordinate relitti)

const APP_TITLE: String = "Station Services & Logistics Hub"
const DEFAULT_WINDOW_SIZE: Vector2 = Vector2(780, 560)

# Costanti di architettura e percorsi di storage diegetico
const CONFIG_PATH_PRIMARY: String = "Ship Drive/Programs/StationHub/station_hub_config.dat"
const CONFIG_PATH_FALLBACK: String = "Terminal Drive/Programs/StationHub/station_hub_config.dat"
const MARKET_PATH_PRIMARY: String = "Ship Drive/Programs/StationHub/market_manifest.dat"

# Riferimenti UI - Header & Overlays
@onready var disconnected_overlay: Control = get_node_or_null("%DisconnectedOverlay")
@onready var undocked_overlay: Control = get_node_or_null("%UndockedOverlay")
@onready var tab_container: TabContainer = get_node_or_null("%TabContainer")
@onready var station_title_label: Label = get_node_or_null("%StationTitleLabel")
@onready var station_sub_label: Label = get_node_or_null("%StationSubLabel")
@onready var flux_rating_label: Label = get_node_or_null("%FluxRatingLabel")
@onready var credits_label: Label = get_node_or_null("%CreditsLabel")
@onready var btn_undock: Button = get_node_or_null("%BtnUndock")

# Tab 1: Logistica & Cargo Market UI
@onready var mass_status_label: Label = get_node_or_null("%MassStatusLabel")
@onready var mass_progress_bar: ProgressBar = get_node_or_null("%MassProgressBar")
@onready var vol_status_label: Label = get_node_or_null("%VolStatusLabel")
@onready var vol_progress_bar: ProgressBar = get_node_or_null("%VolProgressBar")
@onready var station_market_list: ItemList = get_node_or_null("%StationMarketList")
@onready var station_market_desc_label: RichTextLabel = get_node_or_null("%StationMarketDescLabel")
@onready var buy_quantity_spin_box: SpinBox = get_node_or_null("%BuyQuantitySpinBox")
@onready var btn_buy_cargo: Button = get_node_or_null("%BtnBuyCargo")
@onready var ship_cargo_list: ItemList = get_node_or_null("%ShipCargoList")
@onready var ship_cargo_desc_label: RichTextLabel = get_node_or_null("%ShipCargoDescLabel")
@onready var sell_quantity_spin_box: SpinBox = get_node_or_null("%SellQuantitySpinBox")
@onready var btn_sell_cargo: Button = get_node_or_null("%BtnSellCargo")

# Tab 2: Bacheca Contratti UI
@onready var contracts_item_list: ItemList = get_node_or_null("%ContractsItemList")
@onready var contract_detail_label: RichTextLabel = get_node_or_null("%ContractDetailLabel")
@onready var btn_accept_contract: Button = get_node_or_null("%BtnAcceptContract")

# Tab 3: Software & Firmware Repository UI
@onready var market_item_list: ItemList = get_node_or_null("%MarketItemList")
@onready var market_desc_label: RichTextLabel = get_node_or_null("%MarketDescLabel")
@onready var btn_buy_market_item: Button = get_node_or_null("%BtnBuyMarketItem")

# Tab 4: Cantiere e Riparazioni UI
@onready var hull_bar: ProgressBar = get_node_or_null("%HullBar")
@onready var hull_status_lbl: Label = get_node_or_null("%HullStatusLbl")
@onready var breaches_status_lbl: Label = get_node_or_null("%BreachesStatusLbl")
@onready var btn_repair_hull: Button = get_node_or_null("%BtnRepairHull")
@onready var btn_service_ducts: Button = get_node_or_null("%BtnServiceDucts")
@onready var btn_recharge_battery: Button = get_node_or_null("%BtnRechargeBattery")
@onready var btn_buy_nanites: Button = get_node_or_null("%BtnBuyNanites")

# Tab 5: Taverna UI
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
var station_market_goods: Array[Dictionary] = []
var active_contracts: Array[Dictionary] = []
var active_software_items: Array[Dictionary] = [] # compatibilità con active_market_items
var active_market_items: Array[Dictionary]:
	get: return active_software_items
	set(val): active_software_items = val
var active_rumors: Array[Dictionary] = []

var selected_station_cargo_idx: int = -1
var selected_ship_cargo_idx: int = -1
var selected_contract_idx: int = -1
var selected_software_idx: int = -1
var selected_market_idx: int:
	get: return selected_software_idx
	set(val): selected_software_idx = val
var selected_rumor_idx: int = -1

# Riferimenti a Singleton e Manager di sistema
var docking_manager: DockingManager = null
var cargo_mgr: CargoManagerSingleton = null
var flux_mgr: FluxEconomyManagerSingleton = null

func _ready() -> void:
	custom_minimum_size = DEFAULT_WINDOW_SIZE
	_init_managers()
	_init_runtime_files()
	_load_config()
	_connect_signals()
	_check_initial_state()

func _init_managers() -> void:
	# CargoManager
	if get_node_or_null("/root/CargoManager") is CargoManagerSingleton:
		cargo_mgr = get_node_or_null("/root/CargoManager") as CargoManagerSingleton
	elif cargo_mgr == null:
		cargo_mgr = CargoManagerSingleton.new()
		cargo_mgr.name = "CargoManagerFallback"
		add_child(cargo_mgr)

	# FluxEconomyManager
	if get_node_or_null("/root/FluxEconomyManager") is FluxEconomyManagerSingleton:
		flux_mgr = get_node_or_null("/root/FluxEconomyManager") as FluxEconomyManagerSingleton
	elif flux_mgr == null:
		flux_mgr = FluxEconomyManagerSingleton.new()
		flux_mgr.name = "FluxEconomyManagerFallback"
		add_child(flux_mgr)

func _connect_signals() -> void:
	# SpaceWorldManager
	if SpaceWorldManager:
		if SpaceWorldManager.has_signal("ship_connection_changed") and not SpaceWorldManager.ship_connection_changed.is_connected(_on_ship_connection_changed):
			SpaceWorldManager.ship_connection_changed.connect(_on_ship_connection_changed)
		if SpaceWorldManager.has_signal("ship_damages_updated") and not SpaceWorldManager.ship_damages_updated.is_connected(_on_ship_damages_updated):
			SpaceWorldManager.ship_damages_updated.connect(_on_ship_damages_updated)
	
	# NetworkManager (RBAC)
	var net_mgr := get_node_or_null("/root/NetworkManager")
	if net_mgr:
		if net_mgr.has_signal("role_changed") and not net_mgr.role_changed.is_connected(_on_role_changed):
			net_mgr.role_changed.connect(_on_role_changed)
		if net_mgr.has_signal("session_mode_changed") and not net_mgr.session_mode_changed.is_connected(_on_session_mode_changed):
			net_mgr.session_mode_changed.connect(_on_session_mode_changed)
			
	# ShipDrive hot-reload
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm and sdm.has_signal("file_synced") and not sdm.file_synced.is_connected(_on_drive_file_synced):
		sdm.file_synced.connect(_on_drive_file_synced)
		
	# CargoManager signals
	if cargo_mgr:
		if not cargo_mgr.cargo_updated.is_connected(_on_cargo_state_updated):
			cargo_mgr.cargo_updated.connect(_on_cargo_state_updated)
			
	# FluxEconomyManager signals
	if flux_mgr:
		if not flux_mgr.flux_score_changed.is_connected(_on_flux_score_changed):
			flux_mgr.flux_score_changed.connect(_on_flux_score_changed)
		
	# Header Buttons
	if btn_undock and not btn_undock.pressed.is_connected(_on_btn_undock_pressed):
		btn_undock.pressed.connect(_on_btn_undock_pressed)
		
	# Tab 1: Cargo Market
	if station_market_list and not station_market_list.item_selected.is_connected(_on_station_market_selected):
		station_market_list.item_selected.connect(_on_station_market_selected)
	if btn_buy_cargo and not btn_buy_cargo.pressed.is_connected(_on_btn_buy_cargo_pressed):
		btn_buy_cargo.pressed.connect(_on_btn_buy_cargo_pressed)
	if ship_cargo_list and not ship_cargo_list.item_selected.is_connected(_on_ship_cargo_selected):
		ship_cargo_list.item_selected.connect(_on_ship_cargo_selected)
	if btn_sell_cargo and not btn_sell_cargo.pressed.is_connected(_on_btn_sell_cargo_pressed):
		btn_sell_cargo.pressed.connect(_on_btn_sell_cargo_pressed)
		
	# Tab 2: Contratti
	if contracts_item_list and not contracts_item_list.item_selected.is_connected(_on_contract_item_selected):
		contracts_item_list.item_selected.connect(_on_contract_item_selected)
	if btn_accept_contract and not btn_accept_contract.pressed.is_connected(_on_accept_contract_pressed):
		btn_accept_contract.pressed.connect(_on_accept_contract_pressed)
		
	# Tab 3: Software Market
	if market_item_list and not market_item_list.item_selected.is_connected(_on_software_item_selected):
		market_item_list.item_selected.connect(_on_software_item_selected)
	if btn_buy_market_item and not btn_buy_market_item.pressed.is_connected(_on_buy_software_item_pressed):
		btn_buy_market_item.pressed.connect(_on_buy_software_item_pressed)
		
	# Tab 4: Cantiere
	if btn_repair_hull and not btn_repair_hull.pressed.is_connected(_on_repair_hull_pressed):
		btn_repair_hull.pressed.connect(_on_repair_hull_pressed)
	if btn_service_ducts and not btn_service_ducts.pressed.is_connected(_on_service_ducts_pressed):
		btn_service_ducts.pressed.connect(_on_service_ducts_pressed)
	if btn_recharge_battery and not btn_recharge_battery.pressed.is_connected(_on_recharge_battery_pressed):
		btn_recharge_battery.pressed.connect(_on_recharge_battery_pressed)
	if btn_buy_nanites and not btn_buy_nanites.pressed.is_connected(_on_buy_nanites_pressed):
		btn_buy_nanites.pressed.connect(_on_buy_nanites_pressed)
		
	# Tab 5: Taverna
	if tavern_rumors_list and not tavern_rumors_list.item_selected.is_connected(_on_rumor_item_selected):
		tavern_rumors_list.item_selected.connect(_on_rumor_item_selected)
	if btn_record_coordinates and not btn_record_coordinates.pressed.is_connected(_on_record_coordinates_pressed):
		btn_record_coordinates.pressed.connect(_on_record_coordinates_pressed)

func _check_initial_state() -> void:
	if SpaceWorldManager and "is_ship_connected_state" in SpaceWorldManager:
		_on_ship_connection_changed(SpaceWorldManager.is_ship_connected_state)
	else:
		_on_ship_connection_changed(true)
		
	_evaluate_rbac()
	_update_credits_display()
	_update_flux_display()

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
		station_title_label.text = "⚓ %s" % str(station_data.get("name", "Stazione Ignota"))
	if station_sub_label:
		station_sub_label.text = "Settore Operativo | Connesso a Bay 0%d | Fazione: %s" % [bay_id + 1, str(station_data.get("iff", "Neutrale"))]
		
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

## Popola le sezioni diegetiche con i dati della stazione
func _populate_hub_data(st_data: Dictionary) -> void:
	# 1. Logistica & Cargo Market
	_refresh_cargo_market_view()
	
	# 2. Bacheca Contratti
	_refresh_contracts_view()
	
	# 3. Mercato Software / Repository
	_refresh_software_view()
	
	# 4. Cantiere
	_refresh_shipyard_view()
	
	# 5. Taverna Spaziale
	_refresh_tavern_view()

# =============================================================================
# TAB 1: LOGISTICA & CARGO MARKET (COMPRAVENDITA MERCI & RATING FLUX)
# =============================================================================

func _refresh_cargo_market_view() -> void:
	# Stiva nave (Massa e Volume)
	if cargo_mgr:
		var total_m := cargo_mgr.get_total_mass()
		var max_m := cargo_mgr.max_mass_kg
		var total_v := cargo_mgr.get_total_volume()
		var max_v := cargo_mgr.max_volume_m3
		
		if mass_status_label:
			mass_status_label.text = "Massa Stiva: %.1f / %.1f kg (%.0f%%)" % [total_m, max_m, (total_m / maxf(max_m, 1.0)) * 100.0]
		if mass_progress_bar:
			mass_progress_bar.value = (total_m / maxf(max_m, 1.0)) * 100.0
			
		if vol_status_label:
			vol_status_label.text = "Volume Stiva: %.1f / %.1f m³ (%.0f%%)" % [total_v, max_v, (total_v / maxf(max_v, 1.0)) * 100.0]
		if vol_progress_bar:
			vol_progress_bar.value = (total_v / maxf(max_v, 1.0)) * 100.0

	# Popola catalogo merci stazione
	if station_market_list:
		station_market_list.clear()
		station_market_goods.clear()
		if docking_manager and docking_manager.target_station and not docking_manager.target_station.warehouse_cargo.is_empty():
			station_market_goods = docking_manager.target_station.warehouse_cargo.duplicate(true)
		else:
			station_market_goods = [
				{"id": "minerals_titanium", "name": "Titanio Grezzo", "category": "MINERAL", "unit_mass_kg": 25.0, "unit_volume_m3": 0.8, "unit_base_value": 120.0, "quantity": 50, "description": "Minerali di titanio grezzo estratti da asteroidi."},
				{"id": "alloys_durasteel", "name": "Leghe Raffinate Durasteel", "category": "ALLOY", "unit_mass_kg": 40.0, "unit_volume_m3": 0.5, "unit_base_value": 350.0, "quantity": 25, "description": "Lingotti compositi per corazzature e cantieri navali."},
				{"id": "ammo_railgun", "name": "Munizioni Sabot Railgun", "category": "AMMO", "unit_mass_kg": 15.0, "unit_volume_m3": 0.2, "unit_base_value": 220.0, "quantity": 40, "description": "Proiettili cinetici al tungsteno-uranio per torrette pesanti."},
				{"id": "energy_cell", "name": "Celle Energetiche al Plasma", "category": "ENERGY_CELL", "unit_mass_kg": 10.0, "unit_volume_m3": 0.3, "unit_base_value": 180.0, "quantity": 30, "description": "Condensatori al plasma ad alta densità per ricarica sublayer e scudi."}
			]
		for item: Dictionary in station_market_goods:
			var price: int = int(_get_effective_price(float(item.get("unit_base_value", 0.0)), true))
			var line := "[%s] %s | Qnt: %d | %d CR" % [str(item.get("category", "Cargo")), str(item.get("name", "Merce")), int(item.get("quantity", 0)), price]
			station_market_list.add_item(line)
			
	# Popola stiva nave
	if ship_cargo_list and cargo_mgr:
		ship_cargo_list.clear()
		var ship_items: Array[CargoItemData] = cargo_mgr.get_cargo_list()
		for item: CargoItemData in ship_items:
			var val: int = int(_get_effective_price(item.unit_base_value, false))
			var line := "[%s] %s | Qnt: %d | Val: %d CR" % [item.category, item.name, item.quantity, val]
			ship_cargo_list.add_item(line)

func _get_effective_price(base_price: float, is_buying: bool) -> float:
	if flux_mgr:
		if flux_mgr.has_method("calculate_market_price"):
			return flux_mgr.calculate_market_price(base_price, is_buying)
		elif flux_mgr.has_method("get_market_price"):
			return flux_mgr.get_market_price(base_price, is_buying)
	return base_price

func _on_station_market_selected(index: int) -> void:
	selected_station_cargo_idx = index
	if index >= 0 and index < station_market_goods.size():
		var item: Dictionary = station_market_goods[index]
		var price: int = int(_get_effective_price(float(item.get("unit_base_value", 0.0)), true))
		if station_market_desc_label:
			station_market_desc_label.text = "[b]%s[/b] (Categoria: %s)\nMassa: %.1f kg/u | Volume: %.1f m³/u | Prezzo FLUX: %d CR\nDisponibilità Porto: %d unità\n%s" % [
				str(item.get("name", "Merce")),
				str(item.get("category", "Cargo")),
				float(item.get("unit_mass_kg", 0.0)),
				float(item.get("unit_volume_m3", 0.0)),
				price,
				int(item.get("quantity", 0)),
				str(item.get("description", ""))
			]
		if buy_quantity_spin_box:
			buy_quantity_spin_box.max_value = maxf(1.0, float(item.get("quantity", 0.0)))
		if btn_buy_cargo:
			btn_buy_cargo.disabled = not can_manage_services or not is_station_docked or credits < price

func _on_ship_cargo_selected(index: int) -> void:
	selected_ship_cargo_idx = index
	if not cargo_mgr:
		return
	var ship_items: Array[CargoItemData] = cargo_mgr.get_cargo_list()
	if index >= 0 and index < ship_items.size():
		var item: CargoItemData = ship_items[index]
		var payout: int = int(_get_effective_price(item.unit_base_value, false))
		if ship_cargo_desc_label:
			ship_cargo_desc_label.text = "[b]%s[/b] (Categoria: %s)\nMassa: %.1f kg/u | Volume: %.1f m³/u | Valore di Rivendita: %d CR\nIn Stiva: %d unità\n%s" % [
				item.name,
				item.category,
				item.unit_mass_kg,
				item.unit_volume_m3,
				payout,
				item.quantity,
				item.description
			]
		if sell_quantity_spin_box:
			sell_quantity_spin_box.max_value = maxf(1.0, float(item.quantity))
		if btn_sell_cargo:
			btn_sell_cargo.disabled = not can_manage_services or not is_station_docked

func _on_btn_buy_cargo_pressed() -> void:
	if not can_manage_services or not is_station_docked:
		return
	if selected_station_cargo_idx < 0 or selected_station_cargo_idx >= station_market_goods.size():
		return
	var item: Dictionary = station_market_goods[selected_station_cargo_idx]
	var qty: int = int(buy_quantity_spin_box.value) if buy_quantity_spin_box else 1
	var item_qty: int = int(item.get("quantity", 1))
	qty = mini(qty, item_qty)
	if qty <= 0:
		return
		
	var base_val: float = float(item.get("unit_base_value", 100.0))
	var unit_price: int = int(_get_effective_price(base_val, true))
	var total_cost: int = unit_price * qty
	
	if credits < total_cost:
		_notify("Mercato Portuale", "Crediti insufficienti per completare l'acquisto (%d CR richiesti)." % total_cost)
		return
		
	if not cargo_mgr:
		return
		
	var u_mass: float = float(item.get("unit_mass_kg", 1.0))
	var u_vol: float = float(item.get("unit_volume_m3", 0.1))
		
	if not cargo_mgr.can_fit(u_mass, u_vol, qty):
		_notify("Stiva Sovraccarica", "Spazio o massa insufficienti nella stiva della corvetta.")
		return
		
	# Esecuzione transazione
	credits -= total_cost
	_update_credits_display()
	
	var item_id: String = str(item.get("id", ""))
	cargo_mgr.add_item_by_id(item_id, qty)
	item["quantity"] = int(item.get("quantity", 0)) - qty
	
	var item_name: String = str(item.get("name", "Merce"))
	if flux_mgr:
		if flux_mgr.has_method("add_transaction"):
			flux_mgr.add_transaction(float(total_cost), false, true, "Acquisto porto %s x%d" % [item_name, qty])
		elif flux_mgr.has_method("record_transaction"):
			flux_mgr.record_transaction("Acquisto porto %s x%d" % [item_name, qty], float(total_cost), true)
		_update_flux_display()
		
	_notify("Transazione Eseguita", "Acquistato %dx %s per %d CR. Stiva aggiornata." % [qty, item_name, total_cost])
	_refresh_cargo_market_view()

func _on_btn_sell_cargo_pressed() -> void:
	if not can_manage_services or not is_station_docked or not cargo_mgr:
		return
	var ship_items: Array[CargoItemData] = cargo_mgr.get_cargo_list()
	if selected_ship_cargo_idx < 0 or selected_ship_cargo_idx >= ship_items.size():
		return
	var item: CargoItemData = ship_items[selected_ship_cargo_idx]
	var qty: int = int(sell_quantity_spin_box.value) if sell_quantity_spin_box else 1
	var item_qty: int = item.quantity
	qty = mini(qty, item_qty)
	if qty <= 0:
		return
		
	var base_val: float = item.unit_base_value
	var unit_payout: int = int(_get_effective_price(base_val, false))
	var total_payout: int = unit_payout * qty
	
	var item_id: String = item.id
	var item_name: String = item.name
	
	var removed: CargoItemData = cargo_mgr.remove_item(item_id, qty)
	if removed == null:
		return
		
	credits += total_payout
	_update_credits_display()
	
	if flux_mgr:
		if flux_mgr.has_method("add_transaction"):
			flux_mgr.add_transaction(float(total_payout), true, true, "Vendita merci porto %s x%d" % [item_name, qty])
		elif flux_mgr.has_method("record_transaction"):
			flux_mgr.record_transaction("Vendita merci porto %s x%d" % [item_name, qty], float(total_payout), true)
		_update_flux_display()
		
	_notify("Vendita Eseguita", "Venduto %dx %s per +%d CR. Stiva liberata." % [qty, item_name, total_payout])
	_refresh_cargo_market_view()

func _on_cargo_state_updated(_items: Array, _total_m: float, _total_v: float) -> void:
	_refresh_cargo_market_view()

func _on_flux_score_changed(_score: float, _rating: String, _delta: float, _reason: String) -> void:
	_update_flux_display()

# =============================================================================
# TAB 2: BACHECA CONTRATTI & LOGBOOK SYNC
# =============================================================================

func _refresh_contracts_view() -> void:
	if not contracts_item_list:
		return
	contracts_item_list.clear()
	active_contracts.clear()
	
	if docking_manager and docking_manager.target_station and not docking_manager.target_station.active_contracts.is_empty():
		active_contracts = docking_manager.target_station.active_contracts.duplicate(true)
	else:
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
	for cnt in active_contracts:
		var prefix := "✓ " if cnt.get("is_accepted", false) else "• "
		contracts_item_list.add_item("%s%s - %d CR (%d FLUX)" % [prefix, cnt.get("title", ""), cnt.get("reward_credits", 0), cnt.get("reward_flux", cnt.get("reward_credits", 0))])

func _on_contract_item_selected(index: int) -> void:
	selected_contract_idx = index
	if index >= 0 and index < active_contracts.size():
		var cnt: Variant = active_contracts[index]
		if contract_detail_label:
			var status_str := "[color=#00ff88]ACCETTATO (ATTIVO)[/color]" if cnt.get("is_accepted", false) else "[color=#ffcc00]DISPONIBILE PER L'ACCETTAZIONE[/color]"
			contract_detail_label.text = "[b]%s[/b]\nEmittente: %s | Settore: %s\nRicompensa: %d CR | Bonus FLUX: +%d\nStato: %s\n\n%s" % [
				cnt.get("title", ""),
				cnt.get("issuer", "Port Authority"),
				cnt.get("target_sector", "Theta-9"),
				cnt.get("reward_credits", 0),
				cnt.get("reward_flux", cnt.get("reward_credits", 0)),
				status_str,
				cnt.get("description", "")
			]
		if btn_accept_contract:
			btn_accept_contract.disabled = not can_manage_services or not is_station_docked or cnt.get("is_accepted", false)

func _on_accept_contract_pressed() -> void:
	if not can_manage_services or not is_station_docked or selected_contract_idx < 0 or selected_contract_idx >= active_contracts.size():
		return
	var cnt: Variant = active_contracts[selected_contract_idx]
	cnt["is_accepted"] = true
	cnt["status"] = "IN_PROGRESS"
	
	# Sincronizzazione con LogbookApp
	var logbook_found := false
	if is_inside_tree():
		for logbook in get_tree().get_nodes_in_group("logbook_app"):
			if is_instance_valid(logbook) and logbook.has_method("add_contract"):
				logbook.add_contract(cnt)
				logbook_found = true
				break
				
	if not logbook_found and is_inside_tree():
		var root := get_tree().root
		var lb := root.find_child("LogbookApp", true, false)
		if lb is LogbookApp:
			lb.add_contract(cnt)
			logbook_found = true
			
	# Sincronizzazione SpaceWorldManager
	if SpaceWorldManager:
		if SpaceWorldManager.has_method("add_active_contract"):
			SpaceWorldManager.add_active_contract(cnt)
		elif "active_contracts" in SpaceWorldManager and SpaceWorldManager.active_contracts is Array:
			SpaceWorldManager.active_contracts.append(cnt)
			
	_notify("Bacheca Contratti", "Contratto stipulato e iniettato nel Logbook: %s" % cnt.get("title", ""))
	_on_contract_item_selected(selected_contract_idx)
	if contracts_item_list:
		contracts_item_list.set_item_text(selected_contract_idx, "✓ %s - %d CR" % [cnt.get("title", ""), cnt.get("reward_credits", 0)])

# =============================================================================
# TAB 3: SOFTWARE & FIRMWARE REPOSITORY (STORAGE SHIP DRIVE/PROGRAMS/)
# =============================================================================

func _refresh_software_view() -> void:
	if not market_item_list:
		return
	market_item_list.clear()
	active_software_items.clear()
	
	if docking_manager and docking_manager.target_station and not docking_manager.target_station.market_catalog.is_empty():
		active_software_items = docking_manager.target_station.market_catalog.duplicate(true)
	else:
		active_software_items = [
			{
				"id": "patch_ecm_v2",
				"name": "Algoritmo Decrittazione Nova-Pulse v2.4",
				"category": "Software",
				"price": 450,
				"app_target_folder": "Comms",
				"filename": "crypto_tuning.dat",
				"content": "# EW & CRYPTO TUNING OVERCLOCK MATRIX\n[ELECTRONIC_WARFARE]\njamming_power_mw=150.0\nsignal_noise_ratio=0.92\nspoofing_signature=MILITARY_ESCORT\njamming_radius=18000.0\noverclock_ew_boost=1.25\ncrypto_crack_speed=1.5\n",
				"description": "Ottimizzazione cifrari subspaziali per Comms & EW. Velocità decodifica +50%.",
				"developer": "NovaPulse Electronics"
			},
			{
				"id": "driver_overclock_rcs",
				"name": "Driver Propulsori RCS Overclock 'Viper-9'",
				"category": "Firmware",
				"price": 600,
				"app_target_folder": "FlightControls",
				"filename": "thrusters_tuning.dat",
				"content": "# RCS & MAIN THRUSTERS TUNING MATRIX\n[THRUSTERS]\nrcs_power_rate=1.35\npitch_thrust_mult=1.3\nyaw_thrust_mult=1.3\nroll_thrust_mult=1.3\nvertical_thrust_mult=1.3\noverclock_limit=1.8\n",
				"description": "Firmware a bassa latenza per propulsori di manovra Flight Control.",
				"developer": "Zenith Aerospace"
			},
			{
				"id": "script_auto_ping",
				"name": "Script Terminale 'DeepScan.sh'",
				"category": "Script",
				"price": 250,
				"app_target_folder": "Sensors",
				"filename": "deepscan.sh",
				"content": "#!/bin/bash\n# DeepScan automated sweep\necho 'Scanning active sector for gravitational anomalies...'\n",
				"description": "Script diegetico per scansione periodica automatica del quadrante sensori.",
				"developer": "Nebula Logic"
			},
			{
				"id": "sw_firewall_adv",
				"name": "Firewall Subspaziale 'Aegis-IV'",
				"category": "Software",
				"price": 400,
				"app_target_folder": "Diagnostics",
				"filename": "security_tuning.dat",
				"content": "# ICE DEFENSE & SECURITY TUNING\n[ICE_DEFENSE]\nice_firewall_strength=150.0\ntamper_detection_level=MAXIMUM\nice_recharge_rate=8.0\nmalware_purge_efficiency=1.5\n",
				"description": "Schermatura contro tentativi di hackwarfare e malware.",
				"developer": "OmniCorp Software"
			}
		]
	for item in active_software_items:
		market_item_list.add_item("[%s] %s (%d CR)" % [item.get("category", "Software"), item.get("name", ""), item.get("price", 0)])

func _on_software_item_selected(index: int) -> void:
	selected_software_idx = index
	if index >= 0 and index < active_software_items.size():
		var item: Variant = active_software_items[index]
		if market_desc_label:
			market_desc_label.text = "[b]%s[/b] (Categoria: %s)\nProduttore: %s\nPrezzo di Scaricamento: %d CR\nDestinazione: Ship Drive/Programs/%s/%s\n\n%s" % [
				item.get("name", ""),
				item.get("category", ""),
				item.get("developer", "Unknown"),
				item.get("price", 0),
				item.get("app_target_folder", "General"),
				item.get("filename", "patch.dat"),
				item.get("description", "")
			]
		if btn_buy_market_item:
			btn_buy_market_item.disabled = not can_manage_services or not is_station_docked or credits < item.get("price", 0)

func _on_buy_software_item_pressed() -> void:
	if not can_manage_services or not is_station_docked or selected_software_idx < 0 or selected_software_idx >= active_software_items.size():
		return
	var item: Variant = active_software_items[selected_software_idx]
	var price: int = item.get("price", 0)
	if credits < price:
		_notify("Software Repository", "Crediti insufficienti per acquistare il modulo software.")
		return
		
	credits -= price
	_update_credits_display()
	
	# Scrittura fisica del file su Ship Drive/Programs/
	var folder_name: String = item.get("app_target_folder", "StationHub")
	var file_name: String = item.get("filename", "%s.dat" % item.get("id", "patch"))
	var content: String = item.get("content", "# Installed program %s\nstatus=ONLINE\n" % item.get("id", ""))
	
	var rel_path := "Ship Drive/Programs/%s/%s" % [folder_name, file_name]
	var abs_path := "user://files/" + rel_path
	var base_dir := abs_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(base_dir):
		DirAccess.make_dir_recursive_absolute(base_dir)
		
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f:
		f.store_string(content)
		f.close()
		
	var sdm := get_node_or_null("/root/ShipDriveManager")
	if sdm and sdm.has_method("sync_file"):
		sdm.sync_file(rel_path, content)
	elif sdm and sdm.has_method("create_file"):
		sdm.create_file(rel_path, content)
		
	_notify("Download Software", "Installato con successo: %s in %s (-%d CR)." % [item.get("name", ""), rel_path, price])
	_on_software_item_selected(selected_software_idx)

# =============================================================================
# TAB 4: CANTIERE NAVALE E RIPARAZIONI (HULL, BRECCE, RECHARGE)
# =============================================================================

func _refresh_shipyard_view() -> void:
	var hull_val := 100.0
	var breach_count := 0
	
	if SpaceWorldManager and SpaceWorldManager.has_method("get_active_ship_damages"):
		var dmgs: Array = SpaceWorldManager.get_active_ship_damages()
		breach_count = dmgs.size()
		if breach_count > 0:
			hull_val = maxf(20.0, 100.0 - (breach_count * 15.0))
			
	if hull_bar:
		hull_bar.value = hull_val
	if hull_status_lbl:
		hull_status_lbl.text = "Integrità Scafo: %.0f%% | Naniti Disponibili: %d" % [hull_val, player_nanites]
	if breaches_status_lbl:
		if breach_count > 0:
			breaches_status_lbl.text = "⚠️ ALLARME: %d Brecce / Malfunzionamenti scafo attivi!" % breach_count
			breaches_status_lbl.modulate = Color(1.0, 0.4, 0.4)
		else:
			breaches_status_lbl.text = "✔ Stato Brecce Scafo: Nessuna anomalia strutturale rilevata."
			breaches_status_lbl.modulate = Color(0.2, 0.9, 0.4)

func _on_repair_hull_pressed() -> void:
	if not can_manage_services or not is_station_docked: return
	var cost := 150
	if credits >= cost:
		credits -= cost
		_update_credits_display()
		
		# Azzeramento danni e brecce su SpaceWorldManager
		if SpaceWorldManager and SpaceWorldManager.has_method("clear_ship_damages"):
			SpaceWorldManager.clear_ship_damages()
			
		# Azzeramento allarmi e riparazione scafo su SystemicDamageHandler
		if is_inside_tree():
			for dmg_handler in get_tree().get_nodes_in_group("systemic_damage_handler"):
				if is_instance_valid(dmg_handler) and dmg_handler.has_method("repair_hull"):
					dmg_handler.repair_hull(100.0)
					if "has_critical_breach" in dmg_handler:
						dmg_handler.has_critical_breach = false
					if dmg_handler.has_method("reset"):
						dmg_handler.reset()
						
		_refresh_shipyard_view()
		_notify("Cantiere Navale", "Riparazioni scafo e sigillatura brecce completate con successo (-%d CR)." % cost)
	else:
		_notify("Cantiere Navale", "Crediti insufficienti per riparare lo scafo.")

func _on_service_ducts_pressed() -> void:
	if not can_manage_services or not is_station_docked: return
	var cost := 100
	if credits >= cost:
		credits -= cost
		_update_credits_display()
		if SpaceWorldManager and SpaceWorldManager.has_method("clear_ship_damages"):
			SpaceWorldManager.clear_ship_damages()
		_refresh_shipyard_view()
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

func _on_ship_damages_updated(_damages: Array) -> void:
	_refresh_shipyard_view()

# =============================================================================
# TAB 5: TAVERNA SPAZIALE (RUMORS & COORDINATE)
# =============================================================================

func _refresh_tavern_view() -> void:
	if not tavern_rumors_list:
		return
	tavern_rumors_list.clear()
	active_rumors.clear()
	if docking_manager and docking_manager.target_station and not docking_manager.target_station.tavern_rumors.is_empty():
		active_rumors = docking_manager.target_station.tavern_rumors.duplicate(true)
	else:
		active_rumors = [
			{"id": "rum_1", "source": "Mercante Errante", "text": "Coordinate di un cargo abbandonato registrate a bordo.", "coordinates": Vector3(120, -50, 400), "discovered_poi": "Relitto Alpha"},
			{"id": "rum_2", "source": "Minatore Veterano", "text": "Presenza di giacimento minerario ad alta densità nel settore Theta-9.", "coordinates": Vector3(-800, 100, 600), "discovered_poi": "Cluster Titanio"}
		]
	for rum in active_rumors:
		tavern_rumors_list.add_item("Diceria: %s" % rum.get("source", "Sconosciuto"))

func _on_rumor_item_selected(index: int) -> void:
	selected_rumor_idx = index
	if index >= 0 and index < active_rumors.size():
		var rum: Variant = active_rumors[index]
		if rumor_detail_label:
			rumor_detail_label.text = "[b]Fonte: %s[/b]\nCoordinate: %s\n\n\"%s\"" % [
				rum.get("source", ""),
				str(rum.get("coordinates", Vector3.ZERO)),
				rum.get("text", "")
			]
		if btn_record_coordinates:
			btn_record_coordinates.disabled = not can_manage_services or not is_station_docked

func _on_record_coordinates_pressed() -> void:
	if selected_rumor_idx < 0 or selected_rumor_idx >= active_rumors.size():
		return
	var rum: Variant = active_rumors[selected_rumor_idx]
	_notify("Taverna Spaziale", "Coordinate di '%s' inviate ai Sensori e Logbook." % rum.get("discovered_poi", "POI"))

# =============================================================================
# HELPER & INTEGRATION
# =============================================================================

func _on_btn_undock_pressed() -> void:
	if not can_manage_services or not is_station_docked:
		return
	if docking_manager:
		docking_manager.request_undock()
	else:
		_on_undocking_completed()

func _update_credits_display() -> void:
	if credits_label:
		credits_label.text = "Crediti: %d CR" % credits

func _update_flux_display() -> void:
	if flux_rating_label:
		if flux_mgr:
			flux_rating_label.text = "FLUX: %.0f (%s)" % [flux_mgr.flux_score, flux_mgr.get_rating_letter()]
		else:
			flux_rating_label.text = "FLUX: 720 (B)"

func _on_ship_connection_changed(connected: bool) -> void:
	is_ship_connected = connected
	if disconnected_overlay:
		disconnected_overlay.visible = not connected

func _on_role_changed(_role: String) -> void:
	_evaluate_rbac()

func _on_session_mode_changed(_mode: int) -> void:
	_evaluate_rbac()

func _evaluate_rbac() -> void:
	var net_mgr := get_node_or_null("/root/NetworkManager")
	var role: String = "Capitano"
	if net_mgr and "player_role" in net_mgr:
		role = net_mgr.player_role
	
	# Ruoli autorizzati ai servizi di stazione: Capitano, Ingegnere, Hacker, Pilota, Stagista
	can_manage_services = (role == "Capitano" or role == "Ingegnere" or role == "Hacker" or role == "Pilota" or role == "Stagista" or role == "Captain" or role == "Engineer" or role == "Pilot")
	
	if btn_repair_hull: btn_repair_hull.disabled = not can_manage_services
	if btn_service_ducts: btn_service_ducts.disabled = not can_manage_services
	if btn_recharge_battery: btn_recharge_battery.disabled = not can_manage_services
	if btn_buy_nanites: btn_buy_nanites.disabled = not can_manage_services
	if btn_undock: btn_undock.disabled = not can_manage_services
	if btn_buy_cargo: btn_buy_cargo.disabled = not can_manage_services
	if btn_sell_cargo: btn_sell_cargo.disabled = not can_manage_services
	if btn_accept_contract: btn_accept_contract.disabled = not can_manage_services
	if btn_buy_market_item: btn_buy_market_item.disabled = not can_manage_services

func _init_runtime_files() -> void:
	var sdm := get_node_or_null("/root/ShipDriveManager")
	var fpm := get_node_or_null("/root/FolderPasswordManager")
	
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
			var k: Variant = parts[0].strip_edges()
			var v: Variant = parts[1].strip_edges()
			if k == "default_credits" and v.is_valid_int():
				credits = v.to_int()
				_update_credits_display()

func _on_drive_file_synced(rel_path: String) -> void:
	if "StationHub" in rel_path and rel_path.ends_with(".dat"):
		_load_config()

func _notify(title: String, msg: String) -> void:
	var nm := get_node_or_null("/root/NotificationManager")
	if nm and nm.has_method("send_notification"):
		nm.send_notification(title, msg)
	elif nm and nm.has_method("spawn_notification"):
		nm.spawn_notification("[%s] %s" % [title, msg])
