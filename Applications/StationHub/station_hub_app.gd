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
const DEFAULT_WINDOW_SIZE: Vector2 = Vector2(780, 590)
const MIN_WINDOW_SIZE: Vector2 = Vector2(780, 590)

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
@onready var scavenge_status_label: Label = get_node_or_null("%ScavengeStatusLabel")
@onready var btn_sell_all_scavenged: Button = get_node_or_null("%BtnSellAllScavenged")

# Tab 2: Bacheca Contratti UI
@onready var contracts_item_list: ItemList = get_node_or_null("%ContractsItemList")
@onready var contract_detail_label: RichTextLabel = get_node_or_null("%ContractDetailLabel")
@onready var btn_accept_contract: Button = get_node_or_null("%BtnAcceptContract")
@onready var btn_claim_all_contracts: Button = get_node_or_null("%BtnClaimAllContracts")
@onready var completed_contracts_summary_label: Label = get_node_or_null("%CompletedContractsSummaryLabel")

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
@onready var rent_status_label: Label = get_node_or_null("%RentStatusLabel")
@onready var btn_pay_rent_100: Button = get_node_or_null("%BtnPayRent100")
@onready var btn_pay_rent_all: Button = get_node_or_null("%BtnPayRentAll")
@onready var btn_save_ship_state: Button = get_node_or_null("%BtnSaveShipState")
@onready var save_status_label: Label = get_node_or_null("%SaveStatusLabel")

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
var mission_mgr: MissionManagerSingleton = null

func _ready() -> void:
	custom_minimum_size = Vector2(780, 560)
	call_deferred("_setup_parent_window")
	_init_managers()
	_init_runtime_files()
	_load_config()
	_connect_signals()
	_check_initial_state()

func _setup_parent_window() -> void:
	var curr: Node = get_parent()
	while curr:
		if curr is FakeWindow:
			curr.size = DEFAULT_WINDOW_SIZE
			curr.custom_minimum_size = MIN_WINDOW_SIZE
			break
		curr = curr.get_parent()

func _get_mission_manager() -> MissionManagerSingleton:
	if mission_mgr and is_instance_valid(mission_mgr):
		return mission_mgr
	if is_inside_tree() and get_tree().root.has_node("MissionManager"):
		return get_tree().root.get_node("MissionManager") as MissionManagerSingleton
	if MissionManagerSingleton.instance:
		return MissionManagerSingleton.instance
	return null

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
		
	# MissionManager
	mission_mgr = _get_mission_manager()

func _connect_signals() -> void:
	# MissionManager signals
	if mission_mgr and not mission_mgr.contracts_updated.is_connected(_refresh_contracts_view):
		mission_mgr.contracts_updated.connect(_refresh_contracts_view)
		
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
		if flux_mgr.has_signal("flux_balance_changed") and not flux_mgr.flux_balance_changed.is_connected(_on_flux_balance_changed):
			flux_mgr.flux_balance_changed.connect(_on_flux_balance_changed)
		
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
	if btn_sell_all_scavenged and not btn_sell_all_scavenged.pressed.is_connected(_on_btn_sell_all_scavenged_pressed):
		btn_sell_all_scavenged.pressed.connect(_on_btn_sell_all_scavenged_pressed)
		
	# Tab 2: Contratti
	if contracts_item_list and not contracts_item_list.item_selected.is_connected(_on_contract_item_selected):
		contracts_item_list.item_selected.connect(_on_contract_item_selected)
	if btn_accept_contract and not btn_accept_contract.pressed.is_connected(_on_accept_contract_pressed):
		btn_accept_contract.pressed.connect(_on_accept_contract_pressed)
	if btn_claim_all_contracts and not btn_claim_all_contracts.pressed.is_connected(_on_btn_claim_all_contracts_pressed):
		btn_claim_all_contracts.pressed.connect(_on_btn_claim_all_contracts_pressed)
		
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
	if btn_pay_rent_100 and not btn_pay_rent_100.pressed.is_connected(_on_pay_rent_100_pressed):
		btn_pay_rent_100.pressed.connect(_on_pay_rent_100_pressed)
	if btn_pay_rent_all and not btn_pay_rent_all.pressed.is_connected(_on_pay_rent_all_pressed):
		btn_pay_rent_all.pressed.connect(_on_pay_rent_all_pressed)
	if btn_save_ship_state and not btn_save_ship_state.pressed.is_connected(_on_btn_save_ship_state_pressed):
		btn_save_ship_state.pressed.connect(_on_btn_save_ship_state_pressed)
		
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

	# Auto-binding docking manager all'inizializzazione per abilitare subito i servizi portuali se attraccati
	if docking_manager == null:
		var dm: DockingManager = null
		if get_node_or_null("/root/StationManager") is DockingManager:
			dm = get_node_or_null("/root/StationManager")
		elif SpaceWorldManager and SpaceWorldManager.has_method("get_docking_manager"):
			dm = SpaceWorldManager.get_docking_manager()
		if dm:
			bind_docking_manager(dm)

## Connette un DockingManager per sincronizzazione automatica degli eventi
func bind_docking_manager(dm: DockingManager) -> void:
	if docking_manager and is_instance_valid(docking_manager):
		if docking_manager.docking_completed.is_connected(_on_docking_completed):
			docking_manager.docking_completed.disconnect(_on_docking_completed)
		if docking_manager.undocking_completed.is_connected(_on_undocking_completed):
			docking_manager.undocking_completed.disconnect(_on_undocking_completed)
	docking_manager = dm
	if not dm:
		_on_undocking_completed()
		return
	if not dm.docking_completed.is_connected(_on_docking_completed):
		dm.docking_completed.connect(_on_docking_completed)
	if not dm.undocking_completed.is_connected(_on_undocking_completed):
		dm.undocking_completed.connect(_on_undocking_completed)
	if dm.is_docked and dm.target_station:
		_on_docking_completed(dm.target_station.station_id, dm.assigned_bay_id, dm.target_station.get_telemetry_data())
	else:
		_on_undocking_completed()

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
			var cat: String = str(item.get("category", "Cargo"))
			var price: int = int(_get_effective_price(float(item.get("unit_base_value", 0.0)), true, cat))
			var rating_badge := ""
			var station = docking_manager.target_station if (docking_manager and docking_manager.target_station) else null
			if station and station.has_method("get_category_price_modifier"):
				var mod: float = station.get_category_price_modifier(cat)
				if mod > 0:
					rating_badge = " [+%d%%]" % int(round(mod * 100.0))
				elif mod < 0:
					rating_badge = " [%d%%]" % int(round(mod * 100.0))
			var line := "[%s] %s%s | Qnt: %d | %d FLUX" % [cat, str(item.get("name", "Merce")), rating_badge, int(item.get("quantity", 0)), price]
			station_market_list.add_item(line)
			
	# Popola stiva nave
	if ship_cargo_list and cargo_mgr:
		ship_cargo_list.clear()
		var ship_items: Array[CargoItemData] = cargo_mgr.get_cargo_list()
		for item: CargoItemData in ship_items:
			var val: int = int(_get_effective_price(item.unit_base_value, false, item.category))
			var is_scav: bool = bool(item.is_scavenged) or item.category in ["SCAVENGED", "WRECK_COMPONENT", "SALVAGE"]
			var scav_badge := " ⚡[BOTTI]" if is_scav else ""
			var line := "[%s]%s %s | Qnt: %d | Val: %d FLUX" % [item.category, scav_badge, item.name, item.quantity, val]
			ship_cargo_list.add_item(line)

	# Riepilogo e pulsante liquidazione rapida bottino scavenging
	if cargo_mgr:
		var scav_summary: Dictionary = cargo_mgr.calculate_scavenged_value()
		var scav_count: int = int(scav_summary.get("item_count", 0))
		var scav_flux: int = int(round(scav_summary.get("flux", scav_summary.get("credits", 0.0))))
		if scavenge_status_label:
			if scav_count > 0:
				scavenge_status_label.text = "⚡ Bottino Scavenging: %d oggetti (Stima Valore: +%d FLUX)" % [scav_count, scav_flux]
				scavenge_status_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.2, 1.0))
			else:
				scavenge_status_label.text = "Bottino Scavenging: Nessun relitto o container rilevato."
				scavenge_status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
		if btn_sell_all_scavenged:
			btn_sell_all_scavenged.disabled = not can_manage_services or not is_station_docked or scav_count == 0

func _get_effective_price(base_price: float, is_buying: bool, category: String = "") -> float:
	var cat := category
	if cat.is_empty():
		if is_buying and selected_station_cargo_idx >= 0 and selected_station_cargo_idx < station_market_goods.size():
			cat = str(station_market_goods[selected_station_cargo_idx].get("category", ""))
		elif not is_buying and cargo_mgr and selected_ship_cargo_idx >= 0:
			var ship_items := cargo_mgr.get_cargo_list()
			if selected_ship_cargo_idx < ship_items.size():
				cat = ship_items[selected_ship_cargo_idx].category

	var final_price := base_price
	var station = docking_manager.target_station if (docking_manager and docking_manager.target_station) else null
	if station and station.has_method("get_trade_price"):
		final_price = station.get_trade_price(cat, base_price, is_buying)
	elif station and station.has_method("get_category_price_modifier"):
		var mod: float = station.get_category_price_modifier(cat)
		var factor := maxf(0.2, 1.0 + mod)
		if is_buying:
			final_price = maxf(1.0, round(base_price * factor * 1.15))
		else:
			final_price = maxf(1.0, round(base_price * factor * 0.85))
			
	if flux_mgr:
		if flux_mgr.has_method("get_port_discount_multiplier"):
			var mult: float = flux_mgr.get_port_discount_multiplier()
			if is_buying:
				final_price = round(final_price * mult)
			else:
				var sell_mult := 1.20 if flux_mgr.get_rating_letter() == "S" else (1.10 if flux_mgr.get_rating_letter() == "A" else 1.0)
				final_price = round(final_price * sell_mult)
		elif flux_mgr.has_method("calculate_market_price"):
			final_price = flux_mgr.calculate_market_price(final_price, is_buying)
	return maxf(1.0, final_price)

func _on_station_market_selected(index: int) -> void:
	selected_station_cargo_idx = index
	if index >= 0 and index < station_market_goods.size():
		var item: Dictionary = station_market_goods[index]
		var cat: String = str(item.get("category", "Cargo"))
		var price: int = int(_get_effective_price(float(item.get("unit_base_value", 0.0)), true, cat))
		var rating_str := ""
		var station = docking_manager.target_station if (docking_manager and docking_manager.target_station) else null
		if station and station.has_method("get_market_rating_label"):
			rating_str = " | Rating Mercato: %s" % station.get_market_rating_label(cat)
		if station_market_desc_label:
			station_market_desc_label.text = "[b]%s[/b] (Categoria: %s)\nMassa: %.1f kg/u | Volume: %.1f m³/u | Prezzo FLUX: %d FLUX%s\nDisponibilità Porto: %d unità\n%s" % [
				str(item.get("name", "Merce")),
				cat,
				float(item.get("unit_mass_kg", 0.0)),
				float(item.get("unit_volume_m3", 0.0)),
				price,
				rating_str,
				int(item.get("quantity", 0)),
				str(item.get("description", ""))
			]
		if buy_quantity_spin_box:
			buy_quantity_spin_box.max_value = maxf(1.0, float(item.get("quantity", 0.0)))
		if btn_buy_cargo:
			btn_buy_cargo.disabled = not can_manage_services or not is_station_docked or not _can_afford(price)

func _can_afford(cost: int) -> bool:
	if flux_mgr:
		return flux_mgr.can_afford(cost, true)
	return _get_credits() >= cost

func _on_ship_cargo_selected(index: int) -> void:
	selected_ship_cargo_idx = index
	if not cargo_mgr:
		return
	var ship_items: Array[CargoItemData] = cargo_mgr.get_cargo_list()
	if index >= 0 and index < ship_items.size():
		var item: CargoItemData = ship_items[index]
		var payout: int = int(_get_effective_price(item.unit_base_value, false, item.category))
		var rating_str := ""
		var station = docking_manager.target_station if (docking_manager and docking_manager.target_station) else null
		if station and station.has_method("get_market_rating_label"):
			rating_str = " | Domanda Locale: %s" % station.get_market_rating_label(item.category)
		var is_scav: bool = bool(item.is_scavenged) or item.category in ["SCAVENGED", "WRECK_COMPONENT", "SALVAGE"]
		var scav_tag := "\n[color=yellow]⚡ BOTTINO DI SCAVENGING (Recuperato nello spazio / relitti)[/color]" if is_scav else ""
		if ship_cargo_desc_label:
			ship_cargo_desc_label.text = "[b]%s[/b] (Categoria: %s)%s\nMassa: %.1f kg/u | Volume: %.1f m³/u | Valore di Rivendita: %d FLUX%s\nIn Stiva: %d unità\n%s" % [
				item.name,
				item.category,
				scav_tag,
				item.unit_mass_kg,
				item.unit_volume_m3,
				payout,
				rating_str,
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
	var cat: String = str(item.get("category", ""))
	var unit_price: int = int(_get_effective_price(base_val, true, cat))
	var total_cost: int = unit_price * qty
	
	var can_buy := false
	var allow_debt := false
	if flux_mgr:
		if flux_mgr.get_liquid_flux() >= total_cost:
			can_buy = true
			allow_debt = false
		elif flux_mgr.can_afford(total_cost, true):
			can_buy = true
			allow_debt = true
	elif _get_credits() >= total_cost:
		can_buy = true
	
	if not can_buy:
		_notify("Mercato Portuale", "Fondi FLUX o linea di credito insufficienti per completare l'acquisto (%d FLUX richiesti)." % total_cost)
		return
		
	if not cargo_mgr:
		return
		
	var u_mass: float = float(item.get("unit_mass_kg", 1.0))
	var u_vol: float = float(item.get("unit_volume_m3", 0.1))
		
	if not cargo_mgr.can_fit(u_mass, u_vol, qty):
		_notify("Stiva Sovraccarica", "Spazio o massa insufficienti nella stiva della corvetta.")
		return
		
	var item_name: String = str(item.get("name", "Merce"))
	# Esecuzione transazione
	if flux_mgr:
		var st_name: String = str(current_station_data.get("name", "Station Port Authority"))
		var pay_res: Dictionary = flux_mgr.pay_with_flux(total_cost, allow_debt, st_name, "Acquisto porto %s x%d" % [item_name, qty])
		if not pay_res.get("success", false):
			_notify("Transazione Respinta", str(pay_res.get("reason", "Errore contabile transazione")))
			return
		if pay_res.get("debt_issued", 0) > 0:
			_notify("Credito Accordato", "Emessa nuova tranche di debito portuale (+%d FLUX passivi)." % int(pay_res.get("debt_issued", 0)))
	else:
		_spend_credits(total_cost)
	
	var item_id: String = str(item.get("id", ""))
	cargo_mgr.add_item_by_id(item_id, qty)
	item["quantity"] = int(item.get("quantity", 0)) - qty
	
	_notify("Transazione Eseguita", "Acquistato %dx %s per %d FLUX. Stiva aggiornata." % [qty, item_name, total_cost])
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
	var unit_payout: int = int(_get_effective_price(base_val, false, item.category))
	var total_payout: int = unit_payout * qty
	
	var item_id: String = item.id
	var item_name: String = item.name
	
	var removed: CargoItemData = cargo_mgr.remove_item(item_id, qty)
	if removed == null:
		return
		
	_add_credits(total_payout)
	
	if flux_mgr:
		if flux_mgr.has_method("add_transaction"):
			flux_mgr.add_transaction(float(total_payout), true, true, "Vendita merci porto %s x%d" % [item_name, qty])
		elif flux_mgr.has_method("record_transaction"):
			flux_mgr.record_transaction("Vendita merci porto %s x%d" % [item_name, qty], float(total_payout), true)
		_update_flux_display()
		
	_notify("Vendita Eseguita", "Venduto %dx %s per +%d FLUX. Stiva liberata." % [qty, item_name, total_payout])
	_refresh_cargo_market_view()

func _on_btn_sell_all_scavenged_pressed() -> void:
	if not can_manage_services or not is_station_docked or not cargo_mgr:
		return
	var res := cargo_mgr.liquidate_scavenged_items()
	var count: int = int(res.get("liquidated_count", 0))
	if count > 0:
		var flx: int = int(res.get("flux_earned", res.get("credits_earned", 0.0)))
		_update_credits_display()
		_persist_active_blueprint()
		_notify("Liquidazione Bottino", "Venduti in blocco %d oggetti di scavenging per +%d FLUX. Stiva liberata!" % [
			count, flx
		])
		_refresh_cargo_market_view()
		_update_flux_display()
	else:
		_notify("Nessun Bottino", "Nessun elemento di scavenging presente nella stiva da liquidare.")

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
	
	var mm := _get_mission_manager()
	var station = docking_manager.target_station if (docking_manager and docking_manager.target_station) else null
	
	if mm:
		var st_id := str(station.station_id) if (station and "station_id" in station) else "STATION_START"
		if mm.get_contracts_for_station(st_id).is_empty():
			mm.generate_station_contracts(station if station else self)
		active_contracts = mm.get_contracts_for_station(st_id)
	elif station and not station.active_contracts.is_empty():
		active_contracts = station.active_contracts.duplicate(true)
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
				"status": "AVAILABLE",
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
				"status": "AVAILABLE",
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
				"status": "AVAILABLE",
				"is_accepted": false,
				"is_completed": false
			}
		]
	for cnt in active_contracts:
		var st_status: String = str(cnt.get("status", "AVAILABLE"))
		var prefix := "• "
		if st_status == "COMPLETED":
			prefix = "★ [PRONTO] "
		elif st_status == "IN_PROGRESS" or cnt.get("is_accepted", false):
			prefix = "✓ [IN CORSO] "
		elif st_status == "CLAIMED":
			prefix = "✔ [RISCOSSO] "
		var r_liquid: int = int(cnt.get("reward_liquid_flux", cnt.get("reward_flux", cnt.get("reward_credits", 0))))
		contracts_item_list.add_item("%s%s - %d FLUX" % [prefix, cnt.get("title", ""), r_liquid])

	# Aggiorna summary label e pulsante claim collettivo
	var completed_unclaimed := 0
	if mm:
		completed_unclaimed = mm.get_unclaimed_completed_contracts().size()
	else:
		for c in active_contracts:
			if str(c.get("status")) == "COMPLETED":
				completed_unclaimed += 1
				
	if completed_contracts_summary_label:
		if completed_unclaimed > 0:
			completed_contracts_summary_label.text = "★ %d Contratti Completati in attesa di riscossione!" % completed_unclaimed
			completed_contracts_summary_label.add_theme_color_override("font_color", Color(0.2, 0.95, 0.4, 1.0))
		else:
			completed_contracts_summary_label.text = "Nessun contratto in attesa di liquidazione."
			completed_contracts_summary_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
			
	if btn_claim_all_contracts:
		btn_claim_all_contracts.disabled = not can_manage_services or not is_station_docked or completed_unclaimed == 0

func _on_contract_item_selected(index: int) -> void:
	selected_contract_idx = index
	if index >= 0 and index < active_contracts.size():
		var cnt: Dictionary = active_contracts[index]
		var c_status: String = str(cnt.get("status", "AVAILABLE"))
		var status_str := "[color=#ffcc00]DISPONIBILE PER L'ACCETTAZIONE[/color]"
		var btn_text := "Accetta Incarico"
		var btn_disabled := not can_manage_services or not is_station_docked
		
		match c_status:
			"AVAILABLE":
				status_str = "[color=#ffcc00]DISPONIBILE PER L'ACCETTAZIONE[/color]"
				btn_text = "Accetta Incarico"
				btn_disabled = not can_manage_services or not is_station_docked
			"IN_PROGRESS":
				status_str = "[color=#00e5ff]IN CORSO (OBIETTIVO ATTIVO)[/color]"
				btn_text = "In Corso (Obiettivo Pendente)"
				btn_disabled = true
			"COMPLETED":
				status_str = "[color=#00ff88]COMPLETATO (PRONTO AL RITIRO)[/color]"
				btn_text = "Riscuoti Taglia / Ricompensa"
				btn_disabled = not can_manage_services or not is_station_docked
			"CLAIMED":
				status_str = "[color=#888888]CONTRATTO RISCOSSO ED ARCHIVIATO[/color]"
				btn_text = "Contratto Riscosso"
				btn_disabled = true
				
		if contract_detail_label:
			var target_coords = cnt.get("target_coords_3d", Vector3.ZERO)
			var elevation_info := ""
			if target_coords is Vector3 and target_coords != Vector3.ZERO:
				elevation_info = " | Quota 3D: %.0f m" % target_coords.y
			var r_amt: int = int(cnt.get("reward_liquid_flux", cnt.get("reward_flux", cnt.get("reward_credits", 0))))
			var r_relief: int = int(cnt.get("reward_debt_relief", 0))
			var relief_txt := (" | Sgravio Debito: -%d FLUX" % r_relief) if r_relief > 0 else ""
			contract_detail_label.text = "[b]%s[/b]\nEmittente: %s | Settore: %s%s\nRicompensa: %d FLUX%s\nStato: %s\n\n%s" % [
				cnt.get("title", ""),
				cnt.get("issuer", "Port Authority"),
				cnt.get("target_sector", "Settore Primario"),
				elevation_info,
				r_amt,
				relief_txt,
				status_str,
				cnt.get("description", "")
			]
		if btn_accept_contract:
			btn_accept_contract.text = btn_text
			btn_accept_contract.disabled = btn_disabled

func _on_accept_contract_pressed() -> void:
	if not can_manage_services or not is_station_docked or selected_contract_idx < 0 or selected_contract_idx >= active_contracts.size():
		return
	var cnt: Dictionary = active_contracts[selected_contract_idx]
	var cid: String = str(cnt.get("id"))
	var c_status: String = str(cnt.get("status", "AVAILABLE"))
	var mm := _get_mission_manager()
	
	if c_status == "COMPLETED":
		# Riscossione ricompensa
		if mm:
			var res := mm.claim_contract_reward(cid)
			if res.get("success", false):
				var r_flx := int(res.get("liquid_flux", res.get("credits", res.get("flux", 0))))
				var r_rel := int(res.get("debt_relief_applied", 0))
				var rel_txt := (" (Sgravio Debito: -%d FLUX)" % r_rel) if r_rel > 0 else ""
				_notify("Ufficio Fixer", "Taglia riscossa: +%d FLUX%s!" % [r_flx, rel_txt])
		else:
			cnt["status"] = "CLAIMED"
			var r_flx: int = int(cnt.get("reward_liquid_flux", cnt.get("reward_credits", 0)))
			_add_credits(r_flx)
			_notify("Ufficio Fixer", "Ricompensa riscossa: +%d FLUX!" % r_flx)
		_update_credits_display()
		_update_flux_display()
		_refresh_contracts_view()
		_on_contract_item_selected(selected_contract_idx)
		return
		
	if c_status == "AVAILABLE":
		if mm:
			mm.accept_contract(cid)
		else:
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
		_refresh_contracts_view()
		_on_contract_item_selected(selected_contract_idx)

func _on_btn_claim_all_contracts_pressed() -> void:
	if not can_manage_services or not is_station_docked:
		return
	var mm := _get_mission_manager()
	if mm:
		var res: Dictionary = mm.claim_all_completed_contracts()
		var count: int = int(res.get("claimed_count", 0))
		if count > 0:
			var f_earned: int = int(res.get("total_liquid_flux", res.get("total_credits", res.get("total_flux", 0))))
			var f_relief: int = int(res.get("total_debt_relief", 0))
			_notify("Bacheca Fixer", "Riscossi con successo %d contratti completati! Accredito: +%d FLUX%s." % [
				count, f_earned, (" (Sgravio Debiti: -%d FLUX)" % f_relief) if f_relief > 0 else ""
			])
			_update_credits_display()
			_update_flux_display()
			_persist_active_blueprint()
			_refresh_contracts_view()
		else:
			_notify("Nessun Contratto", "Nessun contratto completato in attesa di liquidazione.")
	else:
		var claimed_count := 0
		var total_flux := 0
		for c in active_contracts:
			if str(c.get("status")) == "COMPLETED":
				c["status"] = "CLAIMED"
				claimed_count += 1
				total_flux += int(c.get("reward_liquid_flux", c.get("reward_credits", 0)))
		if claimed_count > 0:
			_add_credits(total_flux)
			_notify("Bacheca Fixer", "Riscossi %d contratti per +%d FLUX!" % [claimed_count, total_flux])
			_update_credits_display()
			_refresh_contracts_view()
		else:
			_notify("Nessun Contratto", "Nessun contratto completato da riscuotere.")

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
		market_item_list.add_item("[%s] %s (%d FLUX)" % [item.get("category", "Software"), item.get("name", ""), item.get("price", 0)])

func _on_software_item_selected(index: int) -> void:
	selected_software_idx = index
	if index >= 0 and index < active_software_items.size():
		var item: Variant = active_software_items[index]
		if market_desc_label:
			market_desc_label.text = "[b]%s[/b] (Categoria: %s)\nProduttore: %s\nPrezzo: %d FLUX\nDestinazione: Ship Drive/Programs/%s/%s\n\n%s" % [
				item.get("name", ""),
				item.get("category", ""),
				item.get("developer", "Unknown"),
				item.get("price", 0),
				item.get("app_target_folder", "General"),
				item.get("filename", "patch.dat"),
				item.get("description", "")
			]
		if btn_buy_market_item:
			btn_buy_market_item.disabled = not can_manage_services or not is_station_docked or not _can_afford(item.get("price", 0))

func _on_buy_software_item_pressed() -> void:
	if not can_manage_services or not is_station_docked or selected_software_idx < 0 or selected_software_idx >= active_software_items.size():
		return
	var item: Variant = active_software_items[selected_software_idx]
	var price: int = int(item.get("price", 0))
	
	var paid := false
	if flux_mgr:
		var st_name: String = str(current_station_data.get("name", "Station Software Repository"))
		var pay_res: Dictionary = flux_mgr.pay_with_flux(price, true, st_name, "Download software: " + str(item.get("name", "")))
		paid = pay_res.get("success", false)
	elif _get_credits() >= price:
		_spend_credits(price)
		paid = true

	if not paid:
		_notify("Software Repository", "Fondi FLUX o linea di credito insufficienti per acquistare il modulo software.")
		return
		
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
		
	_notify("Download Software", "Installato con successo: %s in %s (-%d FLUX)." % [item.get("name", ""), rel_path, price])
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

	# Aggiornamento stato debito noleggio scafo (Freemium debt)
	var bp := _get_blueprint()
	if bp:
		var rent_debt := bp.get_rent_debt()
		var cur_flux := bp.flux
		if rent_status_label:
			if rent_debt > 0:
				rent_status_label.text = "Debito Noleggio Residuo: %d FLUX (Modificatore passivo vincolato) | FLUX Disponibili: %d" % [rent_debt, cur_flux]
				rent_status_label.modulate = Color(1.0, 0.4, 0.4)
			else:
				rent_status_label.text = "✔ Canone Noleggio Scafo Estinto: Nessun debito pendente."
				rent_status_label.modulate = Color(0.2, 0.9, 0.4)
		if btn_pay_rent_100:
			btn_pay_rent_100.disabled = not can_manage_services or not is_station_docked or rent_debt <= 0 or cur_flux < 100
		if btn_pay_rent_all:
			btn_pay_rent_all.disabled = not can_manage_services or not is_station_docked or rent_debt <= 0 or cur_flux <= 0

func _on_repair_hull_pressed() -> void:
	if not can_manage_services or not is_station_docked: return
	var cost := 150
	var paid := false
	if flux_mgr:
		var st_name := str(current_station_data.get("name", "Aegis Shipyard Repairs"))
		var pay_res: Dictionary = flux_mgr.pay_with_flux(cost, true, st_name, "Riparazioni scafo e brecce")
		paid = pay_res.get("success", false)
	elif _get_credits() >= cost:
		_spend_credits(cost)
		paid = true

	if paid:
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
		_update_credits_display()
		_notify("Cantiere Navale", "Riparazioni scafo e sigillatura brecce completate con successo (-%d FLUX)." % cost)
	else:
		_notify("Cantiere Navale", "Fondi FLUX e linea di credito insufficienti per riparare lo scafo.")

func _on_service_ducts_pressed() -> void:
	if not can_manage_services or not is_station_docked: return
	var cost := 100
	var paid := false
	if flux_mgr:
		var st_name := str(current_station_data.get("name", "Aegis Shipyard Repairs"))
		var pay_res: Dictionary = flux_mgr.pay_with_flux(cost, true, st_name, "Manutenzione condotti")
		paid = pay_res.get("success", false)
	elif _get_credits() >= cost:
		_spend_credits(cost)
		paid = true

	if paid:
		if SpaceWorldManager and SpaceWorldManager.has_method("clear_ship_damages"):
			SpaceWorldManager.clear_ship_damages()
		_refresh_shipyard_view()
		_update_credits_display()
		_notify("Cantiere Navale", "Manutenzione condotti e rimozione anomalie completata (-%d FLUX)." % cost)
	else:
		_notify("Cantiere Navale", "Fondi FLUX e linea di credito insufficienti per manutenzione condotti.")

func _on_recharge_battery_pressed() -> void:
	if not can_manage_services or not is_station_docked: return
	var cost := 50
	var paid := false
	if flux_mgr:
		var st_name := str(current_station_data.get("name", "Aegis Shipyard Repairs"))
		var pay_res: Dictionary = flux_mgr.pay_with_flux(cost, true, st_name, "Ricarica accumulatori")
		paid = pay_res.get("success", false)
	elif _get_credits() >= cost:
		_spend_credits(cost)
		paid = true

	if paid:
		_update_credits_display()
		_notify("Cantiere Navale", "Accumulatori e batterie della nave ricaricati al 100% (-%d FLUX)." % cost)
	else:
		_notify("Cantiere Navale", "Fondi FLUX insufficienti per la ricarica batterie.")

func _on_buy_nanites_pressed() -> void:
	if not can_manage_services or not is_station_docked: return
	var cost := 200
	var paid := false
	if flux_mgr:
		var st_name := str(current_station_data.get("name", "Aegis Shipyard Repairs"))
		var pay_res: Dictionary = flux_mgr.pay_with_flux(cost, true, st_name, "Kit Naniti")
		paid = pay_res.get("success", false)
	elif _get_credits() >= cost:
		_spend_credits(cost)
		paid = true

	if paid:
		player_nanites += 25
		_refresh_shipyard_view()
		_update_credits_display()
		_notify("Cantiere Navale", "Acquistato kit 25x Naniti di Riparazione (-%d FLUX)." % cost)
	else:
		_notify("Cantiere Navale", "Fondi FLUX insufficienti per acquistare naniti.")

func _on_ship_damages_updated(_damages: Array) -> void:
	_refresh_shipyard_view()

var ship_blueprint_ref: ShipBlueprint = null

func set_ship_blueprint(bp: ShipBlueprint) -> void:
	ship_blueprint_ref = bp
	if flux_mgr and flux_mgr.has_method("set_active_blueprint"):
		flux_mgr.set_active_blueprint(bp)

func _get_blueprint() -> ShipBlueprint:
	if ship_blueprint_ref and is_instance_valid(ship_blueprint_ref):
		return ship_blueprint_ref
	if SpaceWorldManager and SpaceWorldManager.has_method("get_ship_blueprint"):
		var b = SpaceWorldManager.get_ship_blueprint()
		if b:
			return b
	return null

## Salva lo stato attivo della blueprint su disco utente (user://)
func _persist_active_blueprint() -> bool:
	var bp := _get_blueprint()
	if not bp:
		if save_status_label:
			save_status_label.text = "Nessun blueprint agganciato."
			save_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
		return false
	var err := bp.save_blueprint_state()
	if save_status_label:
		if err == OK:
			save_status_label.text = "✔ Salvataggio attivo: user://blueprints/active_corvette_session.tres"
			save_status_label.add_theme_color_override("font_color", Color(0.2, 0.95, 0.4, 1.0))
		else:
			save_status_label.text = "❌ Errore salvataggio disco (Codice %d)" % err
			save_status_label.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3, 1.0))
	return err == OK

func _on_btn_save_ship_state_pressed() -> void:
	if not can_manage_services:
		return
	var success := _persist_active_blueprint()
	if success:
		_notify("Persistenza Nave", "Stato nave e blueprint salvati con successo su disco per la sessione successiva.")
	else:
		_notify("Persistenza Nave", "Impossibile salvare il blueprint su disco (nessuna nave attiva o errore di I/O).")

func _on_pay_rent_100_pressed() -> void:
	if not can_manage_services or not is_station_docked:
		return
	var paid := 0
	if flux_mgr:
		paid = flux_mgr.repay_debt("Ship Rent Service", 100)
	else:
		var bp := _get_blueprint()
		if bp:
			paid = bp.repay_rent_debt(100)
	if paid > 0:
		_persist_active_blueprint()
		_refresh_shipyard_view()
		_update_credits_display()
		var rem := flux_mgr.get_total_debt() if flux_mgr else 0
		_notify("Ship Rent Service", "Versata quota canone noleggio: -%d FLUX. Debito residuo: %d FLUX." % [paid, rem])
	else:
		_notify("Ship Rent Service", "FLUX liquidi insufficienti per versare la quota di 100 FLUX.")

func _on_pay_rent_all_pressed() -> void:
	if not can_manage_services or not is_station_docked:
		return
	var paid := 0
	var rem_debt := 0
	if flux_mgr:
		rem_debt = flux_mgr.get_total_debt()
		paid = flux_mgr.repay_debt("Ship Rent Service", rem_debt)
	else:
		var bp := _get_blueprint()
		if bp:
			rem_debt = bp.get_rent_debt()
			paid = bp.repay_rent_debt(rem_debt)
	if paid > 0:
		_persist_active_blueprint()
		_refresh_shipyard_view()
		_update_credits_display()
		var final_rem := flux_mgr.get_total_debt() if flux_mgr else 0
		if final_rem == 0:
			_notify("Ship Rent Service", "Canone noleggio estinto interamente (-%d FLUX)! Titolo di proprietà sbloccato." % paid)
		else:
			_notify("Ship Rent Service", "Pagamento parziale effettuato: -%d FLUX. Debito residuo: %d FLUX." % [paid, final_rem])
	else:
		_notify("Ship Rent Service", "Nessun saldo liquido FLUX disponibile per estinguere il noleggio.")

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
			{
				"id": "rum_derelict_apex",
				"source": "Pilota da Trasporto Veterano",
				"text": "Ho avvistato i rottami di una fregata da trasporto classe Apex a quota non convenzionale, coordinate (1450, 350, -890). Il faro d'emergenza è ancora debolmente attivo.",
				"coordinates": Vector3(1450.0, 350.0, -890.0),
				"discovered_poi": "Relitto Fregata Cargo Apex"
			},
			{
				"id": "rum_asteroid_core",
				"source": "Minatore di Silicio Indipendente",
				"text": "C'è un asteroide metallico massiccio ad alto contenuto di titanio e cobalto fluttuante a dislivello Y = -420 m nel settore periferico.",
				"coordinates": Vector3(-850.0, -420.0, 1150.0),
				"discovered_poi": "Giacimento Titanio Alpha"
			},
			{
				"id": "rum_pirate_cache",
				"source": "Informatore dei Bassifondi",
				"text": "Un nascondiglio di contrabbandieri con container non reclamati è stato rilevato dietro l'ombra gravitazionale a quota Y = 680 m.",
				"coordinates": Vector3(600.0, 680.0, 950.0),
				"discovered_poi": "Nascondiglio Pirata 'Dead Man'"
			}
		]
	for rum in active_rumors:
		tavern_rumors_list.add_item("Diceria: %s" % rum.get("source", "Sconosciuto"))

func _on_rumor_item_selected(index: int) -> void:
	selected_rumor_idx = index
	if index >= 0 and index < active_rumors.size():
		var rum: Dictionary = active_rumors[index]
		var coords: Vector3 = rum.get("coordinates", Vector3.ZERO)
		if rumor_detail_label:
			rumor_detail_label.text = "[b]Fonte: %s[/b]\nPOI: [color=#00e5ff]%s[/color]\nCoordinate 3D: [b](%.0f, %.0f, %.0f)[/b] | Quota Y: [color=#ffcc00]%.0f m[/color]\n\n\"%s\"" % [
				rum.get("source", "Anonimo"),
				rum.get("discovered_poi", "Punto di Interesse"),
				coords.x, coords.y, coords.z,
				coords.y,
				rum.get("text", "")
			]
		if btn_record_coordinates:
			btn_record_coordinates.disabled = not can_manage_services or not is_station_docked

func _on_record_coordinates_pressed() -> void:
	if selected_rumor_idx < 0 or selected_rumor_idx >= active_rumors.size():
		return
	var rum: Dictionary = active_rumors[selected_rumor_idx]
	var poi_name: String = str(rum.get("discovered_poi", "POI"))
	var coords: Vector3 = rum.get("coordinates", Vector3.ZERO)
	
	if SpaceWorldManager:
		if SpaceWorldManager.has_method("register_discovered_poi"):
			SpaceWorldManager.register_discovered_poi({
				"id": str(rum.get("id", "RUMOR_POI")),
				"name": poi_name,
				"coordinates": coords,
				"discovered_poi": poi_name,
				"pos": coords
			})
		elif SpaceWorldManager.has_method("set_active_waypoint"):
			SpaceWorldManager.set_active_waypoint({
				"id": str(rum.get("id", "RUMOR_POI")),
				"name": poi_name,
				"pos": coords
			})
			
	_notify("Taverna Spaziale", "Waypoint 3D '%s' (Quota Y = %.0f m) registrato su Mappa, Sensori e Navigazione!" % [poi_name, coords.y])

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

## Legge i crediti direttamente dalla fonte di verità economica (FluxEconomyManager)
func _get_credits() -> int:
	if flux_mgr:
		return flux_mgr.get_liquid_flux()
	return 0

## Sottrae crediti tramite FluxEconomyManager, propagandone il segnale
func _spend_credits(amount: int) -> void:
	if flux_mgr:
		flux_mgr.spend_liquid_flux(amount)
	_update_credits_display()

## Aggiunge crediti tramite FluxEconomyManager, propagandone il segnale
func _add_credits(amount: int) -> void:
	if flux_mgr:
		flux_mgr.add_liquid_flux(amount)
	_update_credits_display()

func _update_credits_display() -> void:
	if credits_label:
		if flux_mgr:
			var net: int = flux_mgr.get_net_flux()
			var liq: int = flux_mgr.get_liquid_flux()
			var deb: int = flux_mgr.get_total_debt()
			credits_label.text = "FLUX Netto: %d [Liq: %d | Deb: -%d]" % [net, liq, deb]
		else:
			credits_label.text = "FLUX: %d" % _get_credits()

func _on_flux_balance_changed(_net: int, _liq: int, _deb: int) -> void:
	_update_credits_display()
	_update_flux_display()
	_refresh_shipyard_view()

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
	if btn_pay_rent_100: btn_pay_rent_100.disabled = not can_manage_services or not is_station_docked
	if btn_pay_rent_all: btn_pay_rent_all.disabled = not can_manage_services or not is_station_docked
	if btn_undock: btn_undock.disabled = not can_manage_services
	if btn_buy_cargo: btn_buy_cargo.disabled = not can_manage_services
	if btn_sell_cargo: btn_sell_cargo.disabled = not can_manage_services
	if btn_sell_all_scavenged: btn_sell_all_scavenged.disabled = not can_manage_services or not is_station_docked
	if btn_accept_contract: btn_accept_contract.disabled = not can_manage_services
	if btn_claim_all_contracts: btn_claim_all_contracts.disabled = not can_manage_services or not is_station_docked
	if btn_save_ship_state: btn_save_ship_state.disabled = not can_manage_services
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
	# Il file di configurazione non contiene più campi rilevanti per questa app
	# (i crediti sono gestiti unicamente da FluxEconomyManager), ma il parsing
	# resta disponibile per future direttive di configurazione dello StationHub.
	var lines := txt.split("\n")
	for line in lines:
		var l := line.strip_edges()
		if l.begins_with("#") or l.begins_with(";") or l.is_empty():
			continue
		var parts := l.split("=", false, 2)
		if parts.size() != 2:
			continue

func _on_drive_file_synced(rel_path: String) -> void:
	if "StationHub" in rel_path and rel_path.ends_with(".dat"):
		_load_config()

func _notify(title: String, msg: String) -> void:
	var nm := get_node_or_null("/root/NotificationManager")
	if nm and nm.has_method("send_notification"):
		nm.send_notification(title, msg)
	elif nm and nm.has_method("spawn_notification"):
		nm.spawn_notification("[%s] %s" % [title, msg])
