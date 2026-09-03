extends Node

## Test Suite Headless: Flusso Integrato Servizi Stazione Spaziale
## Verifica:
## 1. Procedura di docking/undocking ed emissione stato is_docked via Comms & StationManager.
## 2. Compravendita merci tra mercato stazione e stiva nave con saldo FLUX e pesi/volumi.
## 3. Accettazione contratti dalla bacheca hub e sincronizzazione con Logbook.
## 4. Acquisto moduli software/firmware con scrittura su Ship Drive/Programs/.
## 5. Riparazione scafo e condotti nel cantiere con azzeramento brecce/danni e allarmi.

func _ready() -> void:
	print("\n=======================================================")
	print(">>> AVVIO SUITE DI TEST: STATION SERVICES HUB INTEGRATION")
	print("=======================================================\n")
	_run_all_tests()

func _run_all_tests() -> void:
	await get_tree().process_frame
	
	# 1. Setup Entità Stazione e Managers
	var station_scene: PackedScene = load("res://Outside/Stations/space_station_entity.tscn")
	assert(station_scene != null, "La scena space_station_entity.tscn deve caricarsi correttamente")
	var station: SpaceStationEntity = station_scene.instantiate() as SpaceStationEntity
	add_child(station)
	
	var station_mgr := StationManager.new()
	add_child(station_mgr)
	station_mgr.register_station(station)
	
	var comms_scene: PackedScene = load("res://Applications/Comms/comms_app.tscn")
	var comms: CommsApp = null
	if comms_scene != null:
		comms = comms_scene.instantiate() as CommsApp
		add_child(comms)
		comms.bind_docking_manager(station_mgr)
	
	var hub_scene: PackedScene = load("res://Applications/StationHub/station_hub_app.tscn")
	assert(hub_scene != null, "La scena station_hub_app.tscn deve caricarsi correttamente")
	var hub: StationHubApp = hub_scene.instantiate() as StationHubApp
	add_child(hub)
	hub.bind_docking_manager(station_mgr)
	
	var logbook_scene: PackedScene = load("res://Applications/Logbook/logbook_app.tscn")
	var logbook: LogbookApp = null
	if logbook_scene != null:
		logbook = logbook_scene.instantiate() as LogbookApp
		add_child(logbook)
	
	var cargo_mgr: CargoManagerSingleton = hub.cargo_mgr
	var flux_mgr: FluxEconomyManagerSingleton = hub.flux_mgr
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	# =========================================================================
	# TEST 1: DOCKING / UNDOCKING VIA COMMS & STATION MANAGER
	# =========================================================================
	print("--- TEST 1: Procedura Docking / Undocking ed Emissione is_docked ---")
	assert(station_mgr.is_docked == false, "Stato iniziale deve essere non ancorato")
	assert(hub.is_station_docked == false, "StationHub deve essere inizialmente disconnesso")
	
	if comms:
		comms.can_control_comms = true
		comms.current_frequency = station.comms_frequency
		var comms_req := comms.request_station_docking(station, station_mgr)
		assert(comms_req == true, "Richiesta di attracco da Comms deve avere successo")
		assert(station_mgr.current_state == DockingManager.DockingState.APPROACH_GUIDANCE, "Lo stato docking deve essere in guida approccio")
	
	# Completamento dell'attracco
	station_mgr.force_complete_docking(station, 0)
	assert(station_mgr.is_docked == true, "StationManager deve registrare is_docked = true")
	if comms:
		assert(comms.is_docked == true, "CommsApp deve aggiornare lo stato is_docked = true")
	assert(hub.is_station_docked == true, "StationHubApp deve riconoscere l'attracco completato")
	assert(hub.current_station_id == station.station_id, "L'ID stazione deve essere associato a StationHub")
	assert(hub.undocked_overlay.visible == false, "L'overlay di non ancoraggio deve essere nascosto")
	print("✔ Procedura di docking e transizione is_docked convalidate con successo")
	
	# =========================================================================
	# TEST 2: COMPRAVENDITA MERCI, TRASFERIMENTO STIVA E SALDO FLUX
	# =========================================================================
	print("\n--- TEST 2: Compravendita Merci, Stiva Corvetta e Rating FLUX ---")
	assert(cargo_mgr != null, "CargoManagerSingleton deve essere disponibile")
	assert(flux_mgr != null, "FluxEconomyManagerSingleton deve essere disponibile")
	
	var initial_credits: int = hub.credits
	var initial_mass: float = cargo_mgr.get_total_mass()
	var initial_vol: float = cargo_mgr.get_total_volume()
	var initial_flux_score: float = flux_mgr.flux_score
	
	# Acquisto merci dal mercato locale della stazione
	assert(hub.station_market_goods.size() > 0, "Il catalogo merci del mercato stazione deve essere popolato")
	hub._on_station_market_selected(0) # Seleziona titanio grezzo
	if hub.buy_quantity_spin_box:
		hub.buy_quantity_spin_box.value = 2.0
	
	var buy_item := hub.station_market_goods[0]
	var buy_price := int(hub._get_effective_price(buy_item.get("unit_base_value"), true)) * 2
	
	hub._on_btn_buy_cargo_pressed()
	
	assert(hub.credits == initial_credits - buy_price, "I crediti devono essere decurtati del prezzo d'acquisto")
	assert(cargo_mgr.get_total_mass() > initial_mass, "La massa della stiva deve essere aumentata")
	assert(cargo_mgr.get_total_volume() > initial_vol, "Il volume della stiva deve essere aumentato")
	assert(cargo_mgr.get_item_quantity(buy_item.get("id")) >= 2, "La merce acquistata deve risultare nella stiva nave")
	assert(flux_mgr.flux_score >= initial_flux_score, "Il rating FLUX deve essere incrementato o premiato per la transazione")
	print("✔ Acquisto merci: scalati crediti, caricata stiva (+massa/+vol) e registrata transazione FLUX")
	
	# Vendita merci dalla stiva della corvetta al porto
	var mass_before_sell := cargo_mgr.get_total_mass()
	var credits_before_sell := hub.credits
	var ship_items := cargo_mgr.get_cargo_list()
	assert(ship_items.size() > 0, "La stiva deve contenere elementi vendibili")
	
	hub._on_ship_cargo_selected(0)
	if hub.sell_quantity_spin_box:
		hub.sell_quantity_spin_box.value = 1.0
	
	var sell_item: Variant = ship_items[0]
	var sell_payout := int(hub._get_effective_price(sell_item.get("unit_base_value"), false))
	
	hub._on_btn_sell_cargo_pressed()
	
	assert(hub.credits == credits_before_sell + sell_payout, "I crediti devono aumentare dopo la vendita")
	assert(cargo_mgr.get_total_mass() < mass_before_sell, "La massa della stiva deve diminuire dopo lo scarico")
	print("✔ Vendita merci: accreditati fondi, liberata capacità stiva e sincronizzato FLUX rating")
	
	# =========================================================================
	# TEST 3: ACCETTAZIONE CONTRATTO E SINCRONIZZAZIONE CON LOGBOOK
	# =========================================================================
	print("\n--- TEST 3: Accettazione Contratti e Sincronizzazione Logbook ---")
	assert(hub.active_contracts.size() > 0, "La bacheca contratti deve contenere missioni")
	
	hub._on_contract_item_selected(0)
	var selected_cnt := hub.active_contracts[0]
	var target_cnt_id: String = selected_cnt.get("id")
	
	hub._on_accept_contract_pressed()
	assert(hub.active_contracts[0]["is_accepted"] == true, "Il contratto deve risultare accettato su StationHub")
	
	if logbook:
		var found_in_logbook := false
		for c in logbook.active_contracts:
			if c.get("id") == target_cnt_id or c.get("title") == selected_cnt.get("title"):
				found_in_logbook = true
				assert(c.get("status") == "IN_PROGRESS")
				break
		assert(found_in_logbook == true, "Il contratto accettato deve essere sincronizzato e visibile su Logbook")
	print("✔ Bacheca contratti: contratto stipulato, stato aggiornato e iniettato con successo in Logbook")
	
	# =========================================================================
	# TEST 4: ACQUISTO SOFTWARE E SCRITTURA SU SHIP DRIVE/PROGRAMS/
	# =========================================================================
	print("\n--- TEST 4: Acquisto Software Repository & Scrittura Ship Drive ---")
	assert(hub.active_software_items.size() > 0, "Il catalogo software repository deve contenere moduli")
	
	hub._on_software_item_selected(0)
	var sw_item := hub.active_software_items[0]
	var sw_price: int = sw_item.get("price")
	var credits_before_sw := hub.credits
	
	hub._on_buy_software_item_pressed()
	assert(hub.credits == credits_before_sw - sw_price, "I crediti devono essere decurtati per l'acquisto software")
	
	var folder: String = sw_item.get("app_target_folder")
	var fname: String = sw_item.get("filename")
	var expected_path := "user://files/Ship Drive/Programs/%s/%s" % [folder, fname]
	
	assert(FileAccess.file_exists(expected_path), "Il modulo software acquistato deve essere scritto su: " + expected_path)
	var f := FileAccess.open(expected_path, FileAccess.READ)
	assert(f != null, "Il file software su Ship Drive deve essere leggibile")
	var file_content := f.get_as_text()
	f.close()
	assert(not file_content.is_empty(), "Il file software non deve essere vuoto")
	print("✔ Repository Software: acquisto completato e file scritto con successo su Ship Drive/Programs/%s/%s" % [folder, fname])
	
	# =========================================================================
	# TEST 5: RIPARAZIONE SCAFO, AZZERAMENTO BRECCE E DANNI SISTEMICI
	# =========================================================================
	print("\n--- TEST 5: Cantiere Riparazioni, Azzeramento Brecce & Allarmi ---")
	
	# Inietta danni/brecce nello scafo
	var dmg_handler := SystemicDamageHandler.new()
	dmg_handler.add_to_group("systemic_damage_handler")
	add_child(dmg_handler)
	dmg_handler.reset()
	
	# Infligge un impatto critico per generare breccia e abbassare lo scafo
	dmg_handler.process_hit(Vector3(0, 0, -5), 180.0, "plasma")
	assert(dmg_handler.hull_integrity < 100.0, "Integrità scafo deve essere ridotta dopo l'impatto")
	
	if SpaceWorldManager:
		SpaceWorldManager.spawn_ship_damage("breach", Vector2(100, 50), "engines", 45.0)
		assert(SpaceWorldManager.get_active_ship_damages().size() > 0, "Brecce attive devono risultare su SpaceWorldManager")
	
	hub._refresh_shipyard_view()
	
	# Esecuzione riparazione cantiere
	var credits_before_repair := hub.credits
	hub._on_repair_hull_pressed()
	
	assert(hub.credits == credits_before_repair - 150, "Costo riparazione scafo (150 CR) deve essere scalato")
	assert(hub.hull_bar.value == 100.0, "La barra di integrità scafo deve essere tornata al 100%")
	
	if SpaceWorldManager:
		assert(SpaceWorldManager.get_active_ship_damages().is_empty(), "Tutte le brecce scafo su SpaceWorldManager devono essere state azzerate")
		
	assert(dmg_handler.hull_integrity == 100.0, "Integrità scafo su SystemicDamageHandler deve essere ripristinata al 100%")
	assert(dmg_handler.current_alarm_level == GlobalValues.AlarmLevel.NORMAL, "Livello allarme deve tornare a NORMAL dopo le riparazioni")
	print("✔ Cantiere Navale: brecce sigillate, scafo ripristinato al 100% e allarmi azzerati")
	
	# =========================================================================
	# TEST 6: UNDOCKING FINALE
	# =========================================================================
	print("\n--- TEST 6: Undocking e Ripristino Libero Assetto ---")
	hub._on_btn_undock_pressed()
	assert(station_mgr.is_docked == false, "StationManager deve risultare undocked")
	assert(hub.is_station_docked == false, "StationHubApp deve risultare disconnesso dalla stazione")
	assert(hub.undocked_overlay.visible == true, "Overlay undocked deve tornare visibile")
	print("✔ Sgancio completato con successo")
	
	print("\n=======================================================")
	print("✅ TUTTI I TEST STATION SERVICES HUB INTEGRATION SUPERATI!")
	print("=======================================================\n")
	get_tree().quit(0)
