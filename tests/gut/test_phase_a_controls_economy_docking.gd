extends GutTest

## Test GUT per la Fase A: Controlli, Economia Freemium-punk e Spawn Iniziale Attraccato.
## Valida:
## 1. Persistenza impostazioni input, assi joystick, calibrazione deadzone/sensibilità su file JSON.
## 2. Conio FLUX iniziale di 300, modificatore passivo vincolato di -700 "Ship Rent Service".
## 3. Visualizzazione nel FluxWallet e rimborso quote noleggio in StationHub.
## 4. Spawn iniziale della corvetta direttamente ancorata alla Baia 0 della stazione primaria,
##    blocco propulsori e successiva procedura di undock.

var world_mgr: Node = null
var local_world_mgr: bool = false
var sys_data: StarSystemData = null

func before_each() -> void:
	pass

func after_each() -> void:
	if is_instance_valid(world_mgr):
		if local_world_mgr:
			world_mgr.free()
			world_mgr = null
			local_world_mgr = false
		elif world_mgr.has_method("end_mission"):
			world_mgr.end_mission()

func test_input_settings_persistence_and_deadzones() -> void:
	var test_config_path := "user://test_phase_a_input_config.json"
	
	# Pulisce file precedente se esistente
	if FileAccess.file_exists(test_config_path):
		DirAccess.remove_absolute(test_config_path)
		
	var input_tab := InputSettingsTab.new()
	add_child(input_tab)
	
	# Modifica parametri di calibrazione
	input_tab.current_deadzone = 0.22
	input_tab.current_sensitivity = 1.8
	
	# Mappa un'azione di test
	var key_ev := InputEventKey.new()
	key_ev.physical_keycode = KEY_K
	InputMap.action_erase_events("ship_forward")
	InputMap.action_add_event("ship_forward", key_ev)
	
	# Salva su file
	var err := input_tab.save_config_to_file(test_config_path)
	assert_eq(err, OK, "Il salvataggio della configurazione input deve restituire OK")
	assert_true(FileAccess.file_exists(test_config_path), "Il file di configurazione input deve essere creato sul disco")
	
	# Ricarica e applica
	var loaded := InputSettingsTab.load_and_apply_config_static(test_config_path)
	assert_true(loaded, "Il caricamento della configurazione deve avere successo")
	
	# Verifica che la deadzone applicata all'InputMap corrisponda
	assert_almost_eq(InputMap.action_get_deadzone("ship_forward"), 0.22, 0.001, "La deadzone dell'azione ship_forward deve essere impostata a 0.22")
	assert_almost_eq(InputMap.action_get_deadzone("weapon_fire"), 0.22, 0.001, "La deadzone dell'azione weapon_fire deve essere impostata a 0.22")
	
	# Verifica evento caricato
	var events := InputMap.action_get_events("ship_forward")
	assert_gt(events.size(), 0, "L'azione deve contenere almeno un evento registrato")
	var first_ev := events[0] as InputEventKey
	assert_not_null(first_ev, "L'evento registrato deve essere un InputEventKey")
	assert_eq(first_ev.physical_keycode, KEY_K, "Il tasto mappato deve corrispondere a KEY_K")
	
	# Pulizia
	input_tab.queue_free()
	if FileAccess.file_exists(test_config_path):
		DirAccess.remove_absolute(test_config_path)
	InputMap.load_from_project_settings()

func test_flux_initial_minting_and_rent_debt_modifier() -> void:
	var bp := ShipBlueprint.get_default_blueprint()
	assert_not_null(bp, "Deve essere possibile istanziare il blueprint predefinito della nave")
	
	# Verifica conio iniziale di 300 FLUX
	assert_eq(bp.flux, 300, "Il conio iniziale della nave deve essere esattamente 300 FLUX")
	
	# Verifica presenza del modificatore passivo vincolato da 700 FLUX
	var rent_debt := bp.get_rent_debt()
	assert_eq(rent_debt, 700, "Il debito di noleggio scafo iniziale deve ammontare a 700 FLUX")
	
	var found_rent_mod: ShipFluxModifier = null
	for mod in bp.flux_modifiers:
		if mod is ShipFluxModifier and mod.owner == "Ship Rent Service":
			found_rent_mod = mod
			break
			
	assert_not_null(found_rent_mod, "Deve essere presente un modificatore con owner 'Ship Rent Service'")
	assert_eq(found_rent_mod.value, -700, "Il valore del modificatore passivo deve essere -700 FLUX")
	assert_eq(found_rent_mod.reason, "Canone noleggio scafo", "La causale deve indicare 'Canone noleggio scafo'")
	
	# Verifica saldo netto contabile
	var total_mods: int = 0
	for m in bp.flux_modifiers:
		if m:
			total_mods += int(m.value)
	var net_balance := bp.flux + total_mods
	assert_eq(net_balance, -400, "Il saldo netto contabile (300 FLUX - 700 Debito) deve essere pari a -400 FLUX")

func test_station_hub_debt_repayment() -> void:
	var bp := ShipBlueprint.new()
	bp.flux = 300
	bp.setup_default_freemium_debt()
	
	assert_eq(bp.get_rent_debt(), 700)
	assert_eq(bp.flux, 300)
	
	# 1. Pagamento parziale di 100 FLUX
	var paid := bp.repay_rent_debt(100)
	assert_eq(paid, 100, "Deve essere pagata una quota di 100 FLUX")
	assert_eq(bp.flux, 200, "Il saldo liquido deve scendere a 200 FLUX")
	assert_eq(bp.get_rent_debt(), 600, "Il debito di noleggio residuo deve scendere a 600 FLUX")
	
	# 2. Tentativo di estinguere debito residuo (600 FLUX) con soli 200 FLUX disponibili
	var paid_all_attempt := bp.repay_rent_debt(600)
	assert_eq(paid_all_attempt, 200, "Il pagamento deve essere limitato al saldo liquido disponibile (200 FLUX)")
	assert_eq(bp.flux, 0, "Il saldo liquido deve essere azzerato")
	assert_eq(bp.get_rent_debt(), 400, "Il debito residuo deve essere di 400 FLUX")
	
	# 3. Accredito nuovi proventi (es. da taglia o trading) ed estinzione finale
	bp.flux = 500
	var final_paid := bp.repay_rent_debt(400)
	assert_eq(final_paid, 400, "Deve essere saldato l'intero debito residuo di 400 FLUX")
	assert_eq(bp.get_rent_debt(), 0, "Il debito di noleggio deve risultare completamente estinto")
	assert_eq(bp.flux, 100, "Il saldo liquido residuo deve essere di 100 FLUX")
	
	# Verifica rimozione del modificatore
	var has_rent_mod := false
	for m in bp.flux_modifiers:
		if m is ShipFluxModifier and m.owner == "Ship Rent Service":
			has_rent_mod = true
			break
	assert_false(has_rent_mod, "A debito estinto, il modificatore Ship Rent Service deve essere eliminato")

func test_initial_station_docked_spawn_and_undocking() -> void:
	sys_data = StarSystemData.new("SYS-PHASE-A", "Helios Gateway")
	sys_data.create_default_system()
	
	world_mgr = get_node_or_null("/root/SpaceWorldManager")
	if world_mgr == null:
		var wm_script: GDScript = load("res://Outside/space_world_manager.gd")
		world_mgr = wm_script.new()
		add_child(world_mgr)
		local_world_mgr = true
		
	world_mgr.set_initial_spawn_docked(true)
	world_mgr.set_star_system_data(sys_data)
	world_mgr.start_mission(null, true)
	
	# 1. Verifica stato docked attivo
	assert_true(world_mgr.is_ship_docked(), "La nave deve iniziare la missione nello stato DOCKED")
	
	var dm: DockingManager = world_mgr.get_docking_manager()
	assert_not_null(dm, "SpaceWorldManager deve esporre un DockingManager valido")
	assert_eq(dm.current_state, DockingManager.DockingState.DOCKED, "Lo stato del DockingManager deve essere DOCKED")
	assert_true(dm.is_docked, "dm.is_docked deve essere true")
	
	# 2. Verifica posizionamento nave e blocco propulsori
	var ship: Spaceship = world_mgr.get_spaceship()
	assert_not_null(ship, "Spaceship deve essere istanziata nello space world")
	assert_true(ship.is_movement_locked(), "I propulsori della nave devono essere bloccati durante l'ancoraggio iniziale")
	assert_eq(ship.linear_velocity, Vector3.ZERO, "La velocità lineare della nave ancorata deve essere zero")
	
	var station: SpaceStationEntity = world_mgr.get_primary_station_entity() as SpaceStationEntity
	assert_not_null(station, "La stazione primaria deve essere istanziata")
	var bay_0_trans: Transform3D = station.get_bay_global_transform(0)
	assert_almost_eq(ship.global_position.distance_to(bay_0_trans.origin), 0.0, 0.5, "La posizione della nave deve coincidere con la Baia 0")
	
	# 3. Verifica auto-binding di StationHubApp
	var hub_scene: PackedScene = load("res://Applications/StationHub/station_hub_app.tscn")
	assert_not_null(hub_scene, "La scena di StationHubApp deve essere caricabile")
	var hub_app: Node = hub_scene.instantiate()
	add_child(hub_app)
	
	# All'avvio con nave docked, l'overlay undocked deve essere invisibile e i servizi attivi
	assert_true(hub_app.is_station_docked, "StationHubApp deve rilevare immediatamente che la nave è ancorata alla stazione")
	var overlay: Control = hub_app.get_node_or_null("%UndockedOverlay")
	if overlay:
		assert_false(overlay.visible, "L'overlay di disconnessione deve essere nascosto quando attraccati")
		
	# 4. Esecuzione procedura diegetica di Undocking
	world_mgr.request_undock()
	
	assert_false(world_mgr.is_ship_docked(), "Dopo request_undock(), la nave deve passare a UNDOCKED")
	assert_false(dm.is_docked, "dm.is_docked deve essere false")
	assert_false(ship.is_movement_locked(), "I propulsori della nave devono essere sbloccati per la navigazione libera")
	assert_false(hub_app.is_station_docked, "StationHubApp deve rilevare il disattracco della nave")
	if overlay:
		assert_true(overlay.visible, "L'overlay di disconnessione deve tornare visibile dopo il decollo")
		
	hub_app.queue_free()
