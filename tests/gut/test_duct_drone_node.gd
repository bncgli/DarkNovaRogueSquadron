extends GutTest

## Test GUT per DuctDroneApp & Standard Architetturale (`Applications/DuctDrone/duct_drone_app.gd`).
## Le fasi sono eseguite in ordine di dichiarazione (comportamento di GUT) e condividono
## lo stato di `app`/`bp` per convalidare l'intera sequenza, come nel test manuale originale.
## `app` viene creato/liberato manualmente in before_all/after_all (non con add_child_autofree,
## che libererebbe il nodo già al termine del singolo test, rompendo la sequenza).

var sdm: Node
var fpm: Node
var app_res: PackedScene
var app: DuctDroneApp
var bp: ShipBlueprint

func before_all() -> void:
	sdm = get_node_or_null("/root/ShipDriveManager")
	fpm = get_node_or_null("/root/FolderPasswordManager")

	if NetworkManager:
		NetworkManager.disconnect_game()

	app_res = load("res://Applications/DuctDrone/duct_drone_app.tscn")
	app = app_res.instantiate() as DuctDroneApp
	add_child(app)
	await get_tree().process_frame

func after_all() -> void:
	if is_instance_valid(app):
		app.free()

func test_disconnected_overlay_blocks_app() -> void:
	assert_not_null(app_res, "Scena duct_drone_app.tscn valida")
	assert_false(app.is_operational(), "L'app non deve risultare operativa quando la nave è disconnessa")
	assert_true(app.disconnected_overlay != null and app.disconnected_overlay.visible, "L'overlay DisconnectedOverlay deve essere visibile da disconnesso")

func test_mission_start_enables_operational_app() -> void:
	if NetworkManager:
		NetworkManager.start_solo_game("Ingegnere")
		NetworkManager.start_mission()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(app.is_operational(), "L'app deve risultare operativa dopo l'avvio della missione")
	assert_true(app.disconnected_overlay != null and not app.disconnected_overlay.visible, "L'overlay DisconnectedOverlay deve scomparire dopo l'avvio della missione")

	# Verifica che tutti i pulsanti abbiano focus_mode disabilitato per evitare focus trapping
	var buttons: Array[Button] = [
		app.btn_forward, app.btn_backward, app.btn_rot_left, app.btn_rot_right,
		app.btn_stop, app.btn_reset, app.btn_speed_mode, app.btn_lights_toggle,
		app.btn_scan_pulse, app.btn_repair, app.reload_config_button
	]
	for b in buttons:
		if b:
			assert_eq(b.focus_mode, Control.FOCUS_NONE, "Il focus_mode del pulsante %s deve essere FOCUS_NONE" % b.name)

func test_ship_drive_protected_folder_and_dat_files() -> void:
	assert_true(DirAccess.dir_exists_absolute("user://files/Ship Drive/Programs/DuctDrone"), "Cartella Programs/DuctDrone deve esistere in Ship Drive")
	assert_true(FileAccess.file_exists("user://files/Ship Drive/Programs/DuctDrone/duct_drone_config.dat"), "duct_drone_config.dat deve esistere in Ship Drive/Programs/DuctDrone/")
	assert_true(FileAccess.file_exists("user://files/Ship Drive/Programs/DuctDrone/drone_tuning.dat"), "drone_tuning.dat deve esistere in Ship Drive/Programs/DuctDrone/")

	if fpm:
		assert_true(fpm.has_password("Ship Drive/Programs/DuctDrone"), "La cartella Ship Drive/Programs/DuctDrone deve essere protetta da password")
		assert_true(fpm.check_password("Ship Drive/Programs/DuctDrone", "DRONE-7815"), "La password predefinita della cartella deve essere DRONE-7815")

func test_dat_configuration_dynamic_reload() -> void:
	var initial_cfg: Dictionary = app.load_dat_configuration()
	assert_true(initial_cfg.get("is_dat_loaded"), "Configurazione .dat deve risultare caricata")
	assert_eq(initial_cfg.get("linear_speed"), 175.0, "Velocità lineare iniziale deve essere 175.0")
	assert_eq(initial_cfg.get("rotate_speed"), 3.0, "Velocità rotazione iniziale deve essere 3.0")

	# Modifica dinamica del file duct_drone_config.dat (Tuning / Overclocking robottino)
	var new_dat_content := "[SYSTEM]\napp_name=DuctDrone\nversion=1.0.4\nstatus=OVERCLOCKED\n\n[DRONE_DYNAMICS]\nlinear_speed=260.0\nlinear_acceleration=900.0\nlinear_deceleration=950.0\nrotate_speed=4.5\n\n[BATTERY_MANAGEMENT]\nbattery_max=120.0\nbattery_drain_move=0.2\nbattery_drain_lights=0.4\nbattery_drain_radar=2.0\nbattery_drain_repair=3.0\n\n[MAINTENANCE]\nradar_scan_radius_max=220.0\nrepair_range=60.0\nrepair_speed_multiplier=2.0\n"
	var f_out := FileAccess.open("user://files/Ship Drive/Programs/DuctDrone/duct_drone_config.dat", FileAccess.WRITE)
	f_out.store_string(new_dat_content)
	f_out.close()

	# Notifica sincronizzazione/modifica
	if sdm:
		sdm.file_synced.emit("Ship Drive/Programs/DuctDrone/duct_drone_config.dat")
	else:
		app.load_dat_configuration()
	await get_tree().process_frame

	assert_eq(app.active_config["linear_speed"], 260.0, "linear_speed aggiornato in tempo reale a 260.0")
	assert_eq(app.active_config["rotate_speed"], 4.5, "rotate_speed aggiornato in tempo reale a 4.5")
	assert_eq(app.active_config["repair_range"], 60.0, "repair_range aggiornato in tempo reale a 60.0")
	assert_eq(app.active_config["repair_speed_multiplier"], 2.0, "repair_speed_multiplier aggiornato in tempo reale a 2.0")

func test_rbac_role_restrictions() -> void:
	# Ruolo Ingegnere
	NetworkManager.request_role("Ingegnere")
	await get_tree().process_frame
	assert_true(app.can_control, "L'Ingegnere deve poter controllare il Duct Drone")
	assert_false(app.btn_forward.disabled, "I pulsanti devono essere attivi per l'Ingegnere")
	assert_false(app.btn_lights_toggle.disabled, "Pulsante fari attivo per l'Ingegnere")

	# Ruolo Tattico in multiplayer (Solo telemetria/osservazione)
	NetworkManager.request_role("Tattico")
	NetworkManager.is_solo_mode = false # Simula multiplayer
	NetworkManager.player_role_changed.emit(1, "Tattico")
	await get_tree().process_frame
	assert_false(app.can_control, "Il Tattico in multiplayer non deve poter manovrare il Duct Drone")
	assert_true(app.btn_forward.disabled, "I pulsanti devono essere disabilitati per il Tattico")
	assert_true(app.btn_lights_toggle.disabled, "Pulsante fari disabilitato per il Tattico")

	# Ripristina ruolo Ingegnere per test fisici
	NetworkManager.is_solo_mode = true
	NetworkManager.request_role("Ingegnere")
	NetworkManager.player_role_changed.emit(1, "Ingegnere")
	await get_tree().process_frame

func test_tank_controls_lights_sonar_and_repairs() -> void:
	var initial_pos: Vector2 = app.drone_pos
	var initial_heading: float = app.drone_heading

	# 1. Rotazione Tank
	app._ui_angular_input = 1.0
	app._process(0.1)
	SpaceWorldManager._physics_process(0.1)
	app._process(0.01)
	assert_gt(app.drone_heading, initial_heading, "Rotazione oraria avvenuta con successo")
	app._ui_angular_input = 0.0

	# 2. Movimento Lineare
	SpaceWorldManager.duct_drone_heading = -PI * 0.5
	app.drone_heading = -PI * 0.5
	app._ui_linear_input = 1.0
	for i in range(10):
		app._process(0.05)
		SpaceWorldManager._physics_process(0.05)
	app._process(0.01)
	assert_lt(app.drone_pos.y, initial_pos.y, "Avanzamento tank avvenuto con successo")
	app._ui_linear_input = 0.0

	# Stop rapido
	app._on_stop_pressed()
	SpaceWorldManager._physics_process(0.05)
	app._process(0.01)
	assert_eq(app.drone_current_speed, 0.0, "Pulsante Stop arresta immediatamente il robottino")

	# Fari e Sonar
	assert_false(app.lights_enabled, "Fari inizialmente OFF di default")
	assert_true(app.btn_lights_toggle.text.contains("OFF"), "Pulsante fari mostra OFF all'avvio")
	app._on_lights_toggle()
	assert_true(app.lights_enabled, "Fari impostati su ON")
	app._on_lights_toggle()
	assert_false(app.lights_enabled, "Fari ripristinati su OFF")

	app._on_scan_pulse_pressed()
	assert_true(app.scan_pulse_active, "Impulso Sonar attivato")
	SpaceWorldManager._physics_process(0.1)
	app._process(0.01)
	assert_gt(app.scan_pulse_radius, 5.0, "Raggio impulso Sonar in espansione")

	# Reset Base Dock
	app._on_reset_pressed()
	SpaceWorldManager._physics_process(0.01)
	app._process(0.01)
	assert_eq(app.drone_pos, app.initial_drone_pos, "Robottino riposizionato alla base dock")

	# Danni & Riparazioni
	SpaceWorldManager.clear_ship_damages()
	var breach_dmg: ShipDamageRuntimeState = SpaceWorldManager.spawn_ship_damage(SpaceWorldManager.DAMAGE_TYPE_BREACH, Vector2(300, 160), "Condotto Dorsale", 4.0)
	var short_dmg: ShipDamageRuntimeState = SpaceWorldManager.spawn_ship_damage(SpaceWorldManager.DAMAGE_TYPE_SHORT_CIRCUIT, Vector2(300, 240), "Condotto Reattore", 5.0)

	assert_false(breach_dmg.get("revealed"), "Breccia inizialmente invisibile")
	assert_false(short_dmg.get("revealed"), "Cortocircuito inizialmente invisibile")

	# Rivelazione Breccia con luce
	SpaceWorldManager.duct_drone_pos = Vector2(300, 155)
	SpaceWorldManager.duct_drone_lights = true
	SpaceWorldManager._physics_process(0.1)
	assert_true(breach_dmg.get("revealed"), "Breccia rivelata dai fari/luce")

	# Rivelazione Cortocircuito con radar
	SpaceWorldManager.duct_drone_pos = Vector2(300, 235)
	SpaceWorldManager.trigger_duct_drone_scan()
	SpaceWorldManager._physics_process(0.3)
	assert_true(short_dmg.get("revealed"), "Cortocircuito rilevato dal radar")

	# Riparazione della breccia
	SpaceWorldManager.duct_drone_pos = Vector2(300, 160)
	SpaceWorldManager._physics_process(0.01)
	app._process(0.01)
	assert_false(app.nearby_damage.is_empty(), "Danno adiacente rilevato")

	app._on_repair_button_pressed()
	assert_true(app.is_repairing or SpaceWorldManager.is_duct_drone_repairing, "Riparazione avviata")

	for step in range(30):
		SpaceWorldManager._physics_process(0.1)
		app._process(0.01)

	assert_true(breach_dmg.get("repaired"), "Breccia riparata con successo")
	SpaceWorldManager.duct_drone_lights = false
	app.lights_enabled = false

func test_terminal_cat_command_blocks_dat_read() -> void:
	var terminal_res := load("res://Applications/Terminal/src/terminal_scene.tscn") as PackedScene
	if terminal_res:
		var term := terminal_res.instantiate() as Terminal
		add_child(term)
		await get_tree().process_frame

		var cat_script: GDScript = load("res://Applications/Terminal/commands/cat_command.gd")
		var cat_cmd = cat_script.new()
		term.virtual_path_manager.set_path("Ship Drive/Programs/DuctDrone")
		var args: Array[String] = ["duct_drone_config.dat"]
		cat_cmd.execute(term, args)

		var found_msg := false
		for c in term.command_output_container.get_children():
			if "text" in c and (c.text.contains("non sono leggibili") or c.text.contains(".dat")):
				found_msg = true
				break
		assert_true(found_msg, "Il comando cat deve rifiutare la lettura diretta del file .dat")
		term.queue_free()

func test_blueprint_alignment_radar_key_and_emergency_recovery() -> void:
	# 1. Verifica rimozione pulsante %BtnReset
	assert_null(app.get_node_or_null("%BtnReset"), "Il pulsante %BtnReset deve essere rimosso dal layout visivo")

	# 2. Verifica inizializzazione posizione e heading da ShipBlueprint
	bp = SpaceWorldManager.get_ship_blueprint()
	assert_not_null(bp, "ShipBlueprint attiva disponibile")
	assert_eq(app.initial_drone_pos, bp.get_drone_spawn_pos(), "initial_drone_pos allineata a bp.drone_spawn_pos")
	assert_eq(app.drone_heading, bp.drone_spawn_heading, "drone_heading allineato a bp.drone_spawn_heading")

	# 3. Verifica rimappatura tasto 'R' a scan sonar/radar
	app.scan_pulse_active = false
	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.keycode = KEY_R
	key_event.physical_keycode = KEY_R
	app._input(key_event)
	assert_true(app.scan_pulse_active, "La pressione del tasto 'R' deve attivare l'impulso radar/sonar")

	# 4. Verifica vincolo di ricarica stanza (recharge_room_id)
	var recharge_room: ShipRoomData = bp.get_room_by_id(bp.recharge_room_id)
	assert_not_null(recharge_room, "Stanza di ricarica definita nella blueprint")

	# Fuori dalla stanza di ricarica -> NESSUNA ricarica
	app.drone_pos = Vector2(160, 80) # Nel condotto sensori (fuori dalla stanza di ricarica)
	app.drone_battery = 50.0
	app._process(1.0)
	assert_lte(app.drone_battery, 50.0, "Fuori dalla stanza di ricarica non deve esserci ricarica passiva")

	# Dentro la stanza di ricarica -> Ricarica attiva
	app.drone_pos = recharge_room.rect.position + Vector2(10, 10) # Dentro la stanza di ricarica
	var bat_before: float = app.drone_battery
	app._process(1.0)
	assert_gt(app.drone_battery, bat_before, "All'interno della stanza di ricarica la batteria deve ricaricarsi")

	# 5. Verifica Timer Recupero Emergenza (60s) a batteria 0% fuori dalla stanza
	app.drone_pos = Vector2(160, 80) # Fuori dalla stanza di ricarica
	app.drone_battery = 0.0
	app.is_in_emergency_recovery = false
	app.emergency_recovery_time_left = 0.0

	# Frame 1: Attivazione emergenza
	app._process(0.1)
	assert_true(app.is_in_emergency_recovery, "Stato di recupero di emergenza attivato a batteria 0%")
	assert_true(app.emergency_recovery_time_left <= 60.0 and app.emergency_recovery_time_left >= 59.0, "Timer emergenza avviato a 60s")
	assert_true(app.status_summary_label.text.contains("RECUPERO EMERGENZA IN:"), "Countdown visibile nell'HUD")

	# Blocco controlli di movimento
	app._ui_linear_input = 1.0
	app._ui_angular_input = 1.0
	var pos_frozen: Vector2 = app.drone_pos
	var heading_frozen: float = app.drone_heading
	app._process(0.5)
	assert_eq(app.drone_pos, pos_frozen, "Movimento lineare bloccato durante il recupero")
	assert_eq(app.drone_heading, heading_frozen, "Rotazione angolare bloccata durante il recupero")

	# Avanzamento timer fino a scadenza (60 secondi)
	app._process(60.0)
	assert_false(app.is_in_emergency_recovery, "Stato di recupero di emergenza terminato allo scadere dei 60s")
	assert_eq(app.drone_pos, bp.get_drone_spawn_pos(), "Drone riposizionato alla posizione di spawn")
	assert_eq(app.drone_battery, 25.0, "Batteria ripristinata al 25% dopo il recupero di emergenza")
	app._ui_linear_input = 0.0
	app._ui_angular_input = 0.0
	SpaceWorldManager.stop_duct_drone()
	app._on_stop_pressed()

func test_fire_damage_type() -> void:
	# 1. Verifica costanti danno FIRE
	assert_eq(ShipBlueprint.DAMAGE_TYPE_FIRE, "fire", "ShipBlueprint.DAMAGE_TYPE_FIRE definita")
	assert_eq(ShipDamageData.DAMAGE_TYPE_FIRE, "fire", "ShipDamageData.DAMAGE_TYPE_FIRE definita")
	assert_eq(SpaceWorldManager.DAMAGE_TYPE_FIRE, "fire", "SpaceWorldManager.DAMAGE_TYPE_FIRE definita")

	# 2. Spawn danno da incendio
	SpaceWorldManager.clear_ship_damages()
	var fire_dmg: ShipDamageRuntimeState = SpaceWorldManager.spawn_ship_damage(SpaceWorldManager.DAMAGE_TYPE_FIRE, Vector2(300, 240), "Nucleo Reattore", 4.0)
	assert_not_null(fire_dmg, "Danno incendio spawnato con successo")
	assert_eq(fire_dmg.type, "fire", "Tipo danno corrisponde a 'fire'")
	assert_false(fire_dmg.revealed, "Incendio inizialmente non rivelato")

	# 3. Rivelazione per vicinanza termica (<= 45px)
	SpaceWorldManager.duct_drone_pos = Vector2(300, 230)
	SpaceWorldManager._physics_process(0.1)
	assert_true(fire_dmg.revealed, "Incendio rivelato dai sensori termici di prossimità")
	assert_eq(fire_dmg.revealed_by, "thermal", "Rivelato via thermal")

	# 4. Verifica UI danno incendio
	app.drone_pos = Vector2(300, 230)
	app._process(0.01)
	assert_false(app.nearby_damage.is_empty(), "Danno incendio adiacente rilevato dall'app")
	assert_true(app.nearby_damage_label.text.contains("Incendio"), "Label telemetria indica Incendio Attivo")
	assert_true(app.btn_repair.text.contains("ESTINGUI") or app.btn_repair.text.contains("FUOCO"), "Pulsante riparazione mostra opzione estinzione fuoco")

	# 5. Estinzione e completamento riparazione
	app._on_repair_button_pressed()
	assert_true(app.is_repairing or SpaceWorldManager.is_duct_drone_repairing, "Estinzione incendio avviata")

	for step in range(35):
		SpaceWorldManager._physics_process(0.1)
		app._process(0.01)

	assert_true(fire_dmg.repaired, "Incendio estinto e riparato con successo")
	assert_true(app.nearby_damage.is_empty(), "Nessun danno adiacente attivo dopo estinzione")

func test_sealed_room_collision_barriers() -> void:
	# Sigilla la stanza del Ponte di Comando ('bridge')
	SpaceWorldManager.set_room_sealed("bridge", true)
	assert_true(SpaceWorldManager.is_room_sealed("bridge"), "Stanza bridge risulta sigillata in SpaceWorldManager")
	assert_true(app.is_room_sealed("bridge"), "Stanza bridge risulta sigillata in DuctDroneApp")

	# Caso 1: Drone ESTERNO tenta di entrare nella stanza sigillata -> BLOCCATO
	# Posiziona il drone nel condotto esterno verso il bridge a Vector2(300, 125) (Bridge rect: 230, 45, 140, 70 -> Y da 45 a 115)
	SpaceWorldManager.duct_drone_pos = Vector2(300, 125)
	app.drone_pos = Vector2(300, 125)
	var target_inside_bridge := Vector2(300, 90)
	assert_false(app._can_move_to(target_inside_bridge), "Il drone all'esterno non può entrare nella stanza sigillata")

	# Test fisico con input verso Nord (verso il bridge)
	SpaceWorldManager.duct_drone_heading = -PI * 0.5
	app.drone_heading = -PI * 0.5
	app._ui_linear_input = 1.0
	for step in range(10):
		app._process(0.05)
		SpaceWorldManager._physics_process(0.05)
	app._process(0.01)
	assert_gte(app.drone_pos.y, 115.0, "Il drone rimane all'esterno del perimetro sigillato (pos: %v)" % app.drone_pos)
	app._ui_linear_input = 0.0

	# Caso 2: Drone INTERNO tenta di uscire dalla stanza sigillata -> CONFINATO ALL'INTERNO
	# Posiziona il drone all'interno del bridge a Vector2(300, 60)
	SpaceWorldManager.duct_drone_pos = Vector2(300, 60)
	app.drone_pos = Vector2(300, 60)
	var target_outside_bridge := Vector2(300, 125)
	assert_false(app._can_move_to(target_outside_bridge), "Il drone all'interno non può uscire dalla stanza sigillata")

	# Test fisico con input verso Sud (verso l'uscita condotto)
	SpaceWorldManager.duct_drone_heading = PI * 0.5
	app.drone_heading = PI * 0.5
	app._ui_linear_input = 1.0
	for step in range(10):
		app._process(0.05)
		SpaceWorldManager._physics_process(0.05)
	app._process(0.01)
	assert_true(app.drone_pos.y <= 115.0 and app.drone_pos.y >= 45.0, "Il drone rimane confinato all'interno del ponte sigillato (pos: %v)" % app.drone_pos)
	app._ui_linear_input = 0.0

	# Caso 3: Movimento consentito all'interno della stanza sigillata
	var pos_before_move: Vector2 = app.drone_pos
	SpaceWorldManager.duct_drone_heading = 0.0 # Est (verso destra dentro il ponte)
	app.drone_heading = 0.0
	app._ui_linear_input = 1.0
	for step in range(5):
		app._process(0.05)
		SpaceWorldManager._physics_process(0.05)
	app._process(0.01)
	assert_gt(app.drone_pos.x, pos_before_move.x, "Movimento libero all'interno della stanza sigillata")
	app._ui_linear_input = 0.0

	# Caso 4: Dissigillatura stanza -> passaggio riaperto
	SpaceWorldManager.set_room_sealed("bridge", false)
	assert_false(app.is_room_sealed("bridge"), "Stanza ponte dissigillata con successo")
	assert_true(app._can_move_to(Vector2(300, 125)), "Transito verso l'esterno consentito dopo dissigillatura")

func test_default_light_off_and_strict_blueprint_spawn() -> void:
	SpaceWorldManager.reset_duct_drone()
	var fresh_app: DuctDroneApp = app_res.instantiate() as DuctDroneApp
	add_child(fresh_app)
	await get_tree().process_frame

	# Verifica luce spenta di default all'avvio
	assert_false(fresh_app.lights_enabled, "lights_enabled è false di default all'avvio")
	assert_true(fresh_app.btn_lights_toggle.text.contains("OFF"), "Pulsante fari indica 'LUCI: OFF' all'avvio")

	# Verifica coordinate spawn e heading lette da ShipBlueprint
	assert_eq(fresh_app.initial_drone_pos, bp.get_drone_spawn_pos(), "initial_drone_pos corrisponde esattamente a bp.get_drone_spawn_pos() (%v)" % bp.get_drone_spawn_pos())
	assert_eq(fresh_app.drone_pos, bp.get_drone_spawn_pos(), "drone_pos corrisponde esattamente a bp.get_drone_spawn_pos() (%v)" % bp.get_drone_spawn_pos())
	assert_eq(fresh_app.drone_heading, bp.drone_spawn_heading, "drone_heading corrisponde esattamente a bp.drone_spawn_heading (%f)" % bp.drone_spawn_heading)
	assert_true(fresh_app.drone_pos != Vector2(300, 80) or bp.get_drone_spawn_pos() == Vector2(300, 80), "Nessun fallback hardcoded spurio a Vector2(300, 80)")

	fresh_app.queue_free()
