extends Node

func _ready() -> void:
	print("--- INIZIO TEST SHIP BUILDER APP ---")
	_run_suite.call_deferred()

func _run_suite() -> void:
	await get_tree().process_frame

	# TEST 1: Istanziazione Applicazione
	print("\n--- TEST 1: Istanziazione Applicazione ---")
	var app_scene := load("res://Applications/ShipBuilder/ship_builder.tscn")
	assert(app_scene != null, "La scena ship_builder.tscn deve essere caricata correttamente")
	
	var app = app_scene.instantiate()
	add_child(app)
	assert(app != null, "L'app deve essere istanziata")
	await get_tree().process_frame
	print("? Applicazione istanziata con successo")

	# TEST 2: Verifica UI Iniziale
	print("\n--- TEST 2: Verifica UI Iniziale ---")
	assert(app.canvas != null, "Il canvas deve essere presente")
	assert(app.tool_selector != null, "Il tool selector deve essere presente")
	assert(app.room_list != null, "La lista stanze deve essere presente")
	assert(app.room_list.get_item_count() > 0, "La lista stanze deve essere popolata da RoomDatabase")
	print("? UI Iniziale verificata")

	# TEST 3: Creazione Elemento (Stanza)
	print("\n--- TEST 3: Creazione Elemento (Stanza) ---")
	var initial_rooms = app.current_blueprint.rooms.size()
	# Simulate finishing adding a room
	app.canvas.selected_room_template = "ponte_comando"
	app.canvas._finish_add_room(Vector2(100, 100), Vector2(200, 200))
	assert(app.current_blueprint.rooms.size() == initial_rooms + 1, "Una stanza deve essere stata aggiunta alla blueprint")
	print("? Creazione stanza riuscita")

	# TEST 4: Salvataggio e Caricamento
	print("\n--- TEST 4: Salvataggio e Caricamento ---")
	app.current_blueprint.ship_name = "Test Ship Alpha"
	app._on_save_pressed()
	
	app._new_blueprint()
	assert(app.current_blueprint.ship_name != "Test Ship Alpha", "La nuova blueprint deve avere il nome di default")
	
	app._on_load_pressed()
	assert(app.current_blueprint.ship_name == "Test Ship Alpha", "La blueprint caricata deve avere il nome salvato")
	print("? Salvataggio e Caricamento validati")

	# TEST 5: Registrazione Software Manager
	print("\n--- TEST 5: Registrazione Software Manager ---")
	var tsm = get_node_or_null("/root/TerminalSoftwareManager")
	assert(tsm != null, "TerminalSoftwareManager deve essere presente")
	var registered_app = tsm.get_registered_app("ship_builder")
	assert(registered_app != null, "ShipBuilder deve essere registrato in TerminalSoftwareManager")
	print("? Registrazione software verificata")

	print("\n--- TUTTI I TEST SHIP BUILDER COMPLETATI CON SUCCESSO! ---")
	get_tree().quit(0)
