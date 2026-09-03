extends SceneTree

func _init() -> void:
	print("--- INIZIO TEST SISTEMA TELECAMERE (CAMS) ---")
	
	# 1. Test Caricamento SpaceScene e Spaceship
	var space_scene_res: PackedScene = load("res://Outside/space_scene.tscn")
	assert(space_scene_res != null, "SpaceScene tscn deve essere caricabile")
	var space_scene: SpaceScene = space_scene_res.instantiate() as SpaceScene
	assert(space_scene != null, "SpaceScene deve essere istanziabile")
	root.add_child(space_scene)
	
	var ship: Spaceship = space_scene.get_spaceship()
	assert(ship != null, "Spaceship deve essere presente in SpaceScene")
	
	var cam_ids := ["front", "rear", "left", "right", "top", "bottom"]
	for cid in cam_ids:
		var mount := ship.get_camera_mount(cid)
		assert(mount != null, "Mount telecamera '%s' deve esistere" % cid)
		var trans := ship.get_camera_global_transform(cid)
		print("✔ Telecamera '%s' verificata - Transform: %s" % [cid, trans])
	
	# 2. Test SpaceWorldManager
	print("✔ Test SpaceWorldManager...")
	var manager: SpaceWorldManagerSingleton = SpaceWorldManagerSingleton.new()
	manager.name = "SpaceWorldManager"
	root.add_child(manager)
	
	assert(manager.get_world_3d() != null, "World3D di SpaceWorldManager non deve essere nullo")
	assert(manager.get_cameras_info().size() == 6, "Devono esserci 6 telecamere registrate")
	
	# 3. Test Apertura Finestra Feed Telecamera
	print("✔ Test apertura e chiusura feed finestra...")
	for cid in cam_ids:
		assert(not manager.is_camera_window_open(cid), "La telecamera non deve essere aperta inizialmente")
		var win: FakeWindow = manager.open_camera_window(cid)
		assert(win != null, "La finestra feed deve essere creata con successo")
		assert(manager.is_camera_window_open(cid), "is_camera_window_open deve restituire true")
		
		# Test chiusura
		manager.close_camera_window(cid)
		assert(not manager.is_camera_window_open(cid), "is_camera_window_open deve restituire false dopo la chiusura")
	
	# 4. Test CamsApp mini panel
	print("✔ Test CamsApp mini panel...")
	var cams_app_res: PackedScene = load("res://Applications/Cams/cams_app.tscn")
	assert(cams_app_res != null, "CamsApp tscn deve essere caricabile")
	var cams_app: Control = cams_app_res.instantiate()
	root.add_child(cams_app)
	
	# Simula toggle dei pulsanti
	for cid in cam_ids:
		var btn: Button = cams_app.cam_buttons.get(cid)
		assert(btn != null, "Bottone per telecamera '%s' deve essere mappato nell'app" % cid)
		assert(btn.toggle_mode == true, "Bottone deve essere in toggle_mode")
		
		# Toggle ON
		btn.button_pressed = true
		assert(manager.is_camera_window_open(cid), "Attivando il toggle, la finestra deve aprirsi")
		
		# Toggle OFF
		btn.button_pressed = false
		assert(not manager.is_camera_window_open(cid), "Disattivando il toggle, la finestra deve chiudersi")
	
	# Test Open All / Close All
	print("✔ Test Open All / Close All...")
	cams_app._on_open_all_pressed()
	for cid in cam_ids:
		assert(manager.is_camera_window_open(cid), "Tutte le telecamere devono essere aperte dopo Open All")
	
	cams_app._on_close_all_pressed()
	for cid in cam_ids:
		assert(not manager.is_camera_window_open(cid), "Tutte le telecamere devono essere chiuse dopo Close All")
	
	print("=== TUTTI I TEST COMPLETATI CON SUCCESSO! ===")
	quit(0)
