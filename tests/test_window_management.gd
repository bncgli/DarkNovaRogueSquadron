extends Node

## Test Runner Headless per Gestione Finestre GodotOS (TASK-022)
## Verifica Z-Order, Opacità Finestre in Background e Selezione su Tutta la Superficie

func _ready() -> void:
	print("\n=======================================================")
	print(">>> AVVIO SUITE DI TEST HEADLESS: GODOTOS WINDOW MANAGEMENT (TASK-022)")
	print("=======================================================\n")
	_run_all_tests()

func _run_all_tests() -> void:
	await get_tree().process_frame
	
	# =========================================================================
	# TEST 1: FIX Z-ORDER TOP BAR NELLA SCENA BASE
	# =========================================================================
	print("--- TEST 1: Verifica Z-Index Top Bar in Window.tscn ---")
	var window_scene: PackedScene = load("res://Scenes/Window/Window.tscn")
	assert(window_scene != null, "Window.tscn deve essere caricabile")
	
	var test_win: FakeWindow = window_scene.instantiate() as FakeWindow
	assert(test_win != null, "Window deve essere istanziabile come FakeWindow")
	var top_bar: Panel = test_win.get_node("Top Bar") as Panel
	assert(top_bar != null, "Il nodo 'Top Bar' deve esistere")
	assert(top_bar.z_index == 0, "Top Bar deve avere z_index = 0 (era 2), trovato: %d" % top_bar.z_index)
	print("✔ Z-Index Top Bar verificato con successo (z_index = %d)" % top_bar.z_index)
	test_win.free()
	
	# =========================================================================
	# TEST 2: VERIFICA OPACITÀ FINESTRA IN BACKGROUND (100% / 1.0)
	# =========================================================================
	print("\n--- TEST 2: Opacità Finestre in Background (deselect_window) ---")
	var win1: FakeWindow = window_scene.instantiate() as FakeWindow
	win1.title_text = "Test Window 1"
	add_child(win1)
	await get_tree().process_frame
	
	# Simula completamento del tween di ready
	win1.modulate.a = 1.0
	assert(win1.is_selected == true, "La finestra appena istanziata deve essere selezionata")
	assert(win1.modulate.a == 1.0, "Opacità finestra attiva deve essere 1.0")
	
	# Deseleziona la finestra
	win1.deselect_window()
	assert(win1.is_selected == false, "Finestra deve risultare non selezionata")
	assert(win1.modulate.a == 1.0, "Opacità finestra non deve scendere a 0.75 quando deselezionata (trovato: %f)" % win1.modulate.a)
	
	# Ri-seleziona la finestra
	win1.select_window(true)
	assert(win1.is_selected == true, "Finestra deve risultare selezionata")
	assert(win1.modulate.a == 1.0, "Opacità finestra selezionata deve rimanere 1.0")
	print("✔ Opacità finestre in background (1.0 costante) convalidata con successo")
	
	# =========================================================================
	# TEST 3: SELEZIONE FINESTRA SU INTERA SUPERFICIE & GESTIONE OVERLAP
	# =========================================================================
	print("\n--- TEST 3: Intercettazione Click & Selezione Finestra su Intera Superficie ---")
	var win2: FakeWindow = window_scene.instantiate() as FakeWindow
	win2.title_text = "Test Window 2"
	add_child(win2)
	await get_tree().process_frame
	
	# Configura posizioni e dimensioni esplicite per il test
	# win1 posizionata a (100, 100), dimensione (300, 200) -> Rect: (100..400, 100..300)
	# win2 posizionata a (250, 150), dimensione (300, 200) -> Rect: (250..550, 150..350)
	win1.position = Vector2(100, 100)
	win1.size = Vector2(300, 200)
	win2.position = Vector2(250, 150)
	win2.size = Vector2(300, 200)
	
	# win2 è l'ultima selezionata, win1 è in background
	win2.select_window(false)
	assert(win2.is_selected == true, "win2 deve essere selezionata")
	assert(win1.is_selected == false, "win1 deve essere deselezionata")
	assert(win2.get_index() > win1.get_index(), "win2 deve avere indice gerarchico superiore a win1")
	
	# Test 3a: Click nell'area di sovrapposizione (es. 300, 200) dove win2 è sopra win1
	# win1 non deve rubare il focus a win2
	var click_overlap := InputEventMouseButton.new()
	click_overlap.button_index = MOUSE_BUTTON_LEFT
	click_overlap.pressed = true
	click_overlap.global_position = Vector2(300, 200)
	win1._input(click_overlap)
	assert(win1.is_selected == false, "win1 non deve selezionarsi cliccando sopra win2 che la copre")
	assert(win2.is_selected == true, "win2 deve rimanere selezionata")
	
	# Test 3b: Click nell'area libera di win1 (es. 150, 120 - contenuti interni di win1 non coperti da win2)
	# win1 deve selezionarsi e passare in primo piano
	var click_win1 := InputEventMouseButton.new()
	click_win1.button_index = MOUSE_BUTTON_LEFT
	click_win1.pressed = true
	click_win1.global_position = Vector2(150, 120)
	win1._input(click_win1)
	assert(win1.is_selected == true, "win1 deve selezionarsi quando viene cliccata nella sua superficie interna")
	assert(win2.is_selected == false, "win2 deve essere deselezionata dopo che win1 prende il focus")
	assert(win1.get_index() > win2.get_index(), "win1 deve essere spostata sopra win2 nell'albero dei nodi")
	
	# Test 3c: Click destro (button 2) per selezionare finestra
	win2.select_window(false)
	assert(win2.is_selected == true, "win2 selezionata")
	assert(win1.is_selected == false, "win1 deselezionata")
	
	var rclick_win1 := InputEventMouseButton.new()
	rclick_win1.button_index = MOUSE_BUTTON_RIGHT
	rclick_win1.pressed = true
	rclick_win1.global_position = Vector2(150, 120)
	win1._input(rclick_win1)
	assert(win1.is_selected == true, "win1 deve selezionarsi anche tramite click destro")
	
	# Test 3d: Finestra minimizzata o nascosta non deve intercettare i click
	win1.deselect_window()
	win1.is_minimized = true
	win1._input(click_win1)
	assert(win1.is_selected == false, "Finestra minimizzata non deve selezionarsi al click")
	win1.is_minimized = false
	
	win1.visible = false
	win1._input(click_win1)
	assert(win1.is_selected == false, "Finestra nascosta (visible = false) non deve selezionarsi al click")
	win1.visible = true
	
	print("✔ Selezione finestre su intera superficie e ordinamento z-order validati con successo")
	
	# Pulizia
	win1.queue_free()
	win2.queue_free()
	
	print("\n=======================================================")
	print("=== TUTTI I TEST GODOTOS WINDOW MANAGEMENT COMPLETATI CON SUCCESSO! ===")
	print("=======================================================\n")
	get_tree().quit(0)
