extends Node

## Test Headless per l'Addon StarSystemEditor e StarSystemData

func _ready() -> void:
	print("--- AVVIO TEST: STAR SYSTEM EDITOR ADDON ---")
	
	test_star_system_data_serialization()
	test_star_system_editor_ui_instantiation()
	test_star_system_canvas_interactions()
	test_json_export_and_import()
	test_plugin_lifecycle_and_manager_integration()
	
	print("TUTTI I TEST PER STAR SYSTEM EDITOR COMPLETATI CON SUCCESSO! [OK]")
	get_tree().quit(0)

func test_star_system_data_serialization() -> void:
	print("1. Test StarSystemData: creazione, aggiunta entità e serializzazione dict...")
	var sys := StarSystemData.new("SYS-TEST-01", "Test Galaxy System")
	sys.description = "Sistema per test automatico."
	sys.primary_star_name = "Alpha Test"
	sys.primary_star_coords = Vector3i.ZERO
	sys.primary_star_energy = 1.5
	
	sys.add_or_update_body({
		"id": "BODY_TEST_01",
		"name": "Planet Test",
		"type": "PLANET",
		"coords": Vector3i(2, 5, 0),
		"radius_km": 6000.0,
		"mass_tons": 5.0e21,
		"occluding": true
	})
	
	assert(sys.celestial_bodies.size() == 1, "Dovrebbe esserci 1 corpo celeste.")
	var b := sys.get_body("BODY_TEST_01")
	assert(b.get("name") == "Planet Test")
	
	var d := sys.to_dict()
	assert(d.get("system_id") == "SYS-TEST-01")
	
	var sys2 := StarSystemData.new()
	sys2.from_dict(d)
	assert(sys2.system_name == "Test Galaxy System", "Il system_name deserializzato deve corrispondere.")
	assert(sys2.celestial_bodies.size() == 1, "I corpi deserializzati devono essere 1.")
	
	# Rimozione corpo
	var removed := sys2.remove_body("BODY_TEST_01")
	assert(removed == true, "La rimozione del corpo per ID deve riuscire.")
	assert(sys2.celestial_bodies.is_empty(), "La lista dei corpi deve essere vuota.")
	print("   [OK] StarSystemData serializzazione e manipolazione superata.")

func test_star_system_editor_ui_instantiation() -> void:
	print("2. Test StarSystemEditor UI: creazione controlli e outliner...")
	var editor := StarSystemEditor.new()
	add_child(editor)
	
	assert(editor.canvas != null, "Il canvas deve essere istanziato.")
	assert(editor.outliner_tree != null, "L'outliner ad albero deve essere istanziato.")
	assert(editor.prop_editor_vbox != null, "Il property inspector deve essere istanziato.")
	assert(editor.current_system != null, "Un sistema di default deve essere stato caricato.")
	
	# Aggiunta di un nuovo pianeta tramite editor
	var initial_count := editor.current_system.celestial_bodies.size()
	editor._add_celestial_body("PLANET")
	assert(editor.current_system.celestial_bodies.size() == initial_count + 1, "Il numero di corpi deve aumentare.")
	
	# Rimozione entità
	var last_id: String = editor.current_system.celestial_bodies.back()["id"]
	editor._delete_body(last_id)
	assert(editor.current_system.celestial_bodies.size() == initial_count, "Il numero di corpi deve tornare a initial_count.")
	
	editor.queue_free()
	print("   [OK] StarSystemEditor UI e comandi superati.")

func test_star_system_canvas_interactions() -> void:
	print("3. Test StarSystemCanvas: trasformazioni coordinate e hit test...")
	var canvas := StarSystemCanvas.new()
	add_child(canvas)
	canvas.size = Vector2(800, 600)
	canvas.reset_view()
	
	var sys := StarSystemData.new("SYS-CANVAS-01", "Canvas Test")
	sys.add_or_update_body({
		"id": "BODY_CENTER",
		"name": "Center Planet",
		"type": "PLANET",
		"coords": Vector3i(0, 0, 0),
		"radius_km": 5000.0
	})
	canvas.system_data = sys
	
	var screen_center := canvas.world_to_screen(Vector2.ZERO)
	var back_to_grid := canvas.screen_to_grid_coords(screen_center)
	assert(back_to_grid == Vector3i(0, 0, 0), "La conversione coordinate world-screen-world deve essere accurata.")
	
	var hit := canvas._find_body_at_pos(screen_center)
	assert(hit.get("id") == "BODY_CENTER")
	
	canvas.queue_free()
	print("   [OK] StarSystemCanvas conversioni e hit test superati.")

func test_json_export_and_import() -> void:
	print("4. Test Esportazione / Importazione JSON...")
	var editor := StarSystemEditor.new()
	add_child(editor)
	
	var test_json_path := "user://test_star_system_temp.json"
	editor._export_system_to_json(test_json_path)
	
	assert(FileAccess.file_exists(test_json_path), "Il file JSON esportato deve esistere.")
	
	editor._import_system_from_json(test_json_path)
	assert(editor.current_system != null, "Il sistema deve essere stato importato correttamente.")
	
	# Cleanup
	DirAccess.remove_absolute(test_json_path)
	editor.queue_free()
	print("   [OK] Esportazione e importazione JSON superata.")

func test_plugin_lifecycle_and_manager_integration() -> void:
	print("5. Test Plugin Lifecycle e StarSystemGridManager integration...")
	var sys := StarSystemData.new("SYS-INTEGRATION", "Integration System")
	sys.add_or_update_body({
		"id": "PLANET_INTEG_1",
		"name": "Integ Planet",
		"type": "PLANET",
		"coords": Vector3i(10, 10, 0),
		"radius_km": 7000.0,
		"occluding": true
	})
	
	StarSystemGridManager.load_star_system(sys)
	assert(StarSystemGridManager.system_celestial_bodies.size() == 1, "StarSystemGridManager deve aver caricato il sistema.")
	
	var exported := StarSystemGridManager.export_to_star_system_data()
	assert(exported.celestial_bodies.size() == 1, "L'esportazione dal manager a StarSystemData deve conservare le entità.")
	print("   [OK] StarSystemGridManager integrazione superata.")
