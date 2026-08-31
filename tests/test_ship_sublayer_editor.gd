@tool
extends Node

## Test Suite per Ship Sublayer Blueprint Editor e Canvas

func _ready() -> void:
	print("--- INIZIO TEST SHIP SUBLAYER EDITOR ---")
	_test_editor_ui_layout()
	_test_layer_toggles()
	_test_undo_redo_system()
	_test_all_layers_support()
	_test_modify_devices_junctions_damages()
	_test_room_resize()
	print("✔ TUTTI I TEST SHIP SUBLAYER EDITOR COMPLETATI CON SUCCESSO!")

func _test_editor_ui_layout() -> void:
	print("Test 1: Verifica layout UI e toolbar multi-riga (anti-overflow)...")
	var editor := ShipSublayerEditor.new()
	editor._ready()
	
	# Verifica bottoni essenziali
	assert(editor.btn_undo != null, "Pulsante Undo deve essere istanziato")
	assert(editor.btn_redo != null, "Pulsante Redo deve essere istanziato")
	assert(editor.btn_undo.disabled == true, "Undo deve iniziare disabilitato")
	assert(editor.btn_redo.disabled == true, "Redo deve iniziare disabilitato")
	
	# Verifica bottoni strumenti
	assert(editor.btn_select != null, "Pulsante Seleziona/Sposta deve esistere")
	assert(editor.btn_add_room != null, "Pulsante Stanza deve esistere")
	assert(editor.btn_add_duct != null, "Pulsante Condotto deve esistere")
	assert(editor.btn_add_device != null, "Pulsante Dispositivo deve esistere")
	assert(editor.btn_add_junction != null, "Pulsante Snodo deve esistere")
	assert(editor.btn_add_conduit != null, "Pulsante Cablaggio deve esistere")
	assert(editor.btn_add_damage != null, "Pulsante Danno deve esistere")
	assert(editor.btn_delete != null, "Pulsante Elimina deve esistere")
	
	# Verifica outliner / pannello tutti i layer (a sinistra) e inspector (a destra)
	assert(editor.outliner_tree != null, "Outliner con tutti i layer deve esistere nel pannello sinistro")
	assert(editor.prop_editor_vbox != null, "Inspector proprietà deve esistere nel pannello destro")
	
	# Verifica tutti i checkbox dei layer (Errore 1 & Errore 3)
	assert(editor.chk_layer_rooms != null, "Checkbox Stanze deve esistere")
	assert(editor.chk_layer_ducts != null, "Checkbox Condotti deve esistere")
	assert(editor.chk_layer_devices != null, "Checkbox Dispositivi deve esistere")
	assert(editor.chk_layer_junctions != null, "Checkbox Snodi deve esistere")
	assert(editor.chk_layer_conduits != null, "Checkbox Cablaggi deve esistere")
	assert(editor.chk_layer_damages != null, "Checkbox Danni deve esistere")
	assert(editor.chk_layer_spawn != null, "Checkbox Spawn Drone deve esistere")
	assert(editor.chk_layer_bounds != null, "Checkbox Scafo/Limiti deve esistere")
	assert(editor.chk_layer_grid != null, "Checkbox Griglia deve esistere")
	assert(editor.chk_layer_labels != null, "Checkbox Testo deve esistere")
	
	editor.queue_free()
	print("  -> OK!")

func _test_layer_toggles() -> void:
	print("Test 2: Verifica toggles visibilità di tutti i layer sul canvas...")
	var editor := ShipSublayerEditor.new()
	editor._ready()
	var canvas: ShipBlueprintCanvas = editor.canvas
	assert(canvas != null, "Canvas deve essere presente")
	
	editor.chk_layer_rooms.button_pressed = false
	assert(canvas.show_rooms == false, "Canvas show_rooms deve essere false")
	
	editor.chk_layer_ducts.button_pressed = false
	assert(canvas.show_ducts == false, "Canvas show_ducts deve essere false")
	
	editor.chk_layer_devices.button_pressed = false
	assert(canvas.show_devices == false, "Canvas show_devices deve essere false")
	
	editor.chk_layer_junctions.button_pressed = false
	assert(canvas.show_junctions == false, "Canvas show_junctions deve essere false")
	
	editor.chk_layer_conduits.button_pressed = false
	assert(canvas.show_conduits == false, "Canvas show_conduits deve essere false")
	
	editor.chk_layer_damages.button_pressed = false
	assert(canvas.show_damages == false, "Canvas show_damages deve essere false")
	
	editor.chk_layer_spawn.button_pressed = false
	assert(canvas.show_spawn == false, "Canvas show_spawn deve essere false")
	
	editor.chk_layer_bounds.button_pressed = false
	assert(canvas.show_bounds == false, "Canvas show_bounds deve essere false")
	
	editor.chk_layer_grid.button_pressed = false
	assert(canvas.show_grid == false, "Canvas show_grid deve essere false")
	
	editor.chk_layer_labels.button_pressed = false
	assert(canvas.show_labels == false, "Canvas show_labels deve essere false")
	
	editor.queue_free()
	print("  -> OK!")

func _test_undo_redo_system() -> void:
	print("Test 3: Verifica sistema Undo (Ctrl+Z) e Redo (Ctrl+Y)...")
	var editor := ShipSublayerEditor.new()
	editor._ready()
	var bp: ShipBlueprint = editor.current_blueprint
	var initial_rooms_count := bp.rooms.size()
	
	# Azione: Aggiungi stanza
	editor.canvas._finish_add_room(Vector2(100, 100), Vector2(200, 200))
	assert(bp.rooms.size() == initial_rooms_count + 1, "La stanza deve essere aggiunta")
	assert(editor.btn_undo.disabled == false, "Undo deve essere abilitato dopo l'azione")
	
	# Undo
	editor.undo()
	assert(bp.rooms.size() == initial_rooms_count, "Undo deve ripristinare il conteggio stanze")
	assert(editor.btn_redo.disabled == false, "Redo deve essere abilitato dopo l'undo")
	
	# Redo
	editor.redo()
	assert(bp.rooms.size() == initial_rooms_count + 1, "Redo deve riapplicare la stanza")
	
	# Altro Undo
	editor.undo()
	assert(bp.rooms.size() == initial_rooms_count, "Undo deve ripristinare di nuovo")
	
	editor.queue_free()
	print("  -> OK!")

func _test_all_layers_support() -> void:
	print("Test 4: Verifica supporto completo per tutti i sublayer...")
	var bp := ShipBlueprint.new()
	bp.create_default_ship()
	
	# Layer 1: Stanze
	assert(bp.rooms.size() > 0, "Stanze devono essere presenti")
	# Layer 2: Condotti
	assert(bp.ducts.size() > 0, "Condotti devono essere presenti")
	# Layer 3: Rete (Dispositivi, Snodi, Cablaggi)
	assert(bp.devices.size() > 0, "Dispositivi devono essere presenti")
	assert(bp.junctions.size() > 0, "Snodi devono essere presenti")
	# Aggiunta cablaggio ausiliario
	bp.conduits.append({
		"id": "CND_TEST",
		"from_pos": Vector2(100, 100),
		"to_pos": Vector2(200, 200),
		"from_junction": "J1",
		"target_id": "reactor_main"
	})
	assert(bp.get_conduit_by_id("CND_TEST").is_empty() == false, "Cablaggio deve essere recuperabile")
	
	# Layer 4: Danni
	assert(bp.damages.size() > 0, "Danni devono essere presenti")
	# Layer 5: Ship Drive (Files & Passwords)
	assert(bp.drive_files.size() > 0, "Drive files devono essere presenti")
	assert(bp.drive_passwords.size() > 0, "Drive passwords devono essere presenti")
	# Layer 6: Installed Apps
	assert(bp.installed_apps.size() > 0, "Installed apps devono essere presenti")
	# Layer 7: Spawn Drone
	assert(bp.drone_spawn_pos != Vector2.ZERO, "Spawn drone deve essere impostato")
	# Layer 8: Bounds Scafo
	assert(bp.ship_bounds.size != Vector2.ZERO, "Bounds scafo devono essere impostati")
	
	# Test serializzazione e deserializzazione con tutti i layer (inclusi conduits)
	var dict := bp.to_dict()
	assert(dict.has("conduits"), "to_dict deve includere conduits")
	var bp2 := ShipBlueprint.new()
	bp2.from_dict(dict)
	assert(bp2.conduits.size() == bp.conduits.size(), "from_dict deve ripristinare i conduits")
	assert(bp2.get_conduit_by_id("CND_TEST")["id"] == "CND_TEST", "Cablaggio deserializzato correttamente")
	
	print("  -> OK!")

func _test_modify_devices_junctions_damages() -> void:
	print("Test 5: Verifica modifica, interazione e cancellazione di dispositivi, snodi e danni...")
	var editor := ShipSublayerEditor.new()
	editor._ready()
	var bp: ShipBlueprint = editor.current_blueprint
	var canvas: ShipBlueprintCanvas = editor.canvas
	
	# 1. Modifica Dispositivo
	canvas._finish_add_device(Vector2(150, 150))
	var dev_id := canvas.selected_id
	var dev := bp.get_device_by_id(dev_id)
	assert(dev.is_empty() == false, "Dispositivo appena creato deve esistere")
	
	# Simula modifica proprietà da inspector
	dev["name"] = "Reattore Ausiliario Modificato"
	dev["power_mw"] = 250.0
	dev["is_generator"] = true
	dev["pos"] = Vector2(180, 180)
	bp.emit_changed()
	assert(bp.get_device_by_id(dev_id)["power_mw"] == 250.0, "Potenza modificata con successo")
	assert(bp.get_device_by_id(dev_id)["is_generator"] == true, "Tipo generatore modificato")
	
	# 2. Modifica Snodo e rami
	canvas._finish_add_junction(Vector2(220, 220))
	var junc_id := canvas.selected_id
	var junc := bp.get_junction_by_id(junc_id)
	assert(junc.is_empty() == false, "Snodo appena creato deve esistere")
	
	var branches: Array = junc.get("branches", [])
	var initial_b_count := branches.size()
	branches.append({
		"name": "Ramo Secondario",
		"target_type": "device",
		"target_id": dev_id,
		"line_id": "L_TEST_B1",
		"to_pos": Vector2(180, 180)
	})
	bp.emit_changed()
	assert(bp.get_junction_by_id(junc_id)["branches"].size() == initial_b_count + 1, "Nuovo ramo aggiunto allo snodo")
	
	# 3. Modifica Danno
	canvas._finish_add_damage(Vector2(300, 300))
	var dmg_id := canvas.selected_id
	var dmg := bp.get_damage_by_id(dmg_id)
	assert(dmg.is_empty() == false, "Danno appena creato deve esistere")
	dmg["type"] = "fire"
	dmg["severity"] = 8.5
	dmg["system_impact"] = "life_support_compromised"
	bp.emit_changed()
	assert(bp.get_damage_by_id(dmg_id)["type"] == "fire", "Tipo danno aggiornato a fire")
	assert(bp.get_damage_by_id(dmg_id)["severity"] == 8.5, "Gravità danno aggiornata")
	
	# 4. Modifica Cablaggio (Conduit)
	canvas._finish_add_conduit(Vector2(100, 100), Vector2(250, 250))
	var cnd_id := canvas.selected_id
	var cnd := bp.get_conduit_by_id(cnd_id)
	assert(cnd.is_empty() == false, "Cablaggio appena creato deve esistere")
	cnd["target_id"] = dev_id
	bp.emit_changed()
	assert(bp.get_conduit_by_id(cnd_id)["target_id"] == dev_id, "Target cablaggio aggiornato")
	
	# 5. Eliminazione elementi
	canvas.delete_element("device", dev_id)
	assert(bp.get_device_by_id(dev_id).is_empty() == true, "Dispositivo deve essere eliminato")
	
	canvas.delete_element("junction", junc_id)
	assert(bp.get_junction_by_id(junc_id).is_empty() == true, "Snodo deve essere eliminato")
	
	canvas.delete_element("damage", dmg_id)
	assert(bp.get_damage_by_id(dmg_id).is_empty() == true, "Danno deve essere eliminato")
	
	canvas.delete_element("conduit", cnd_id)
	assert(bp.get_conduit_by_id(cnd_id).is_empty() == true, "Cablaggio deve essere eliminato")
	
	editor.queue_free()
	print("  -> OK!")

func _test_room_resize() -> void:
	print("Test 6: Verifica funzionalità di resize delle stanze (interattivo e inspector)...")
	var editor := ShipSublayerEditor.new()
	editor._ready()
	var bp: ShipBlueprint = editor.current_blueprint
	var canvas: ShipBlueprintCanvas = editor.canvas
	
	# Crea una nuova stanza per il test
	canvas._finish_add_room(Vector2(200, 200), Vector2(300, 300))
	var room_id := canvas.selected_id
	var room := bp.get_room_by_id(room_id)
	assert(room.is_empty() == false, "La stanza deve esistere")
	var initial_rect: Rect2 = room.get("rect", Rect2())
	assert(initial_rect.size == Vector2(100, 100), "Dimensione iniziale della stanza corretta")
	
	# 1. Modifica diretta del rettangolo (es. Inspector)
	var new_rect := Rect2(Vector2(200, 200), Vector2(150, 120))
	room["rect"] = new_rect
	bp.emit_changed()
	assert(bp.get_room_by_id(room_id)["rect"] == new_rect, "Il resize da Inspector aggiorna il blueprint")
	
	# 2. Verifica rilevamento maniglie (handle) sui 4 vertici
	# 0: Top-Left, 1: Top-Right, 2: Bottom-Right, 3: Bottom-Left
	var tl_pos := new_rect.position
	var tr_pos := Vector2(new_rect.end.x, new_rect.position.y)
	var br_pos := new_rect.end
	var bl_pos := Vector2(new_rect.position.x, new_rect.end.y)
	
	assert(canvas._get_resize_handle_at(tl_pos, new_rect) == 0, "Maniglia Top-Left rilevata (0)")
	assert(canvas._get_resize_handle_at(tr_pos, new_rect) == 1, "Maniglia Top-Right rilevata (1)")
	assert(canvas._get_resize_handle_at(br_pos, new_rect) == 2, "Maniglia Bottom-Right rilevata (2)")
	assert(canvas._get_resize_handle_at(bl_pos, new_rect) == 3, "Maniglia Bottom-Left rilevata (3)")
	assert(canvas._get_resize_handle_at(Vector2(50, 50), new_rect) == -1, "Nessuna maniglia trovata fuori stanza (-1)")
	
	# 3. Test drag e resize interattivo tramite simulazione mouse su maniglia Bottom-Right (2)
	canvas.selected_type = "room"
	canvas.selected_id = room_id
	canvas._handle_left_click_pressed(br_pos, br_pos)
	assert(canvas.is_resizing_room == true, "Stato is_resizing_room attivo")
	assert(canvas.resize_handle_index == 2, "Maniglia 2 (Bottom-Right) agganciata")
	
	# Trascina il mouse di +50 in X e +30 in Y
	var mouse_drag_pos := br_pos + Vector2(50, 30)
	canvas._handle_element_drag(mouse_drag_pos)
	assert(bp.get_room_by_id(room_id)["rect"].size == Vector2(200, 150), "Stanza ridimensionata durante il drag a (200, 150)")
	
	# Rilascio del click mouse (applica la modifica e committa l'azione di Undo)
	canvas._handle_left_click_released(mouse_drag_pos, mouse_drag_pos)
	assert(canvas.is_resizing_room == false, "Stato is_resizing_room disattivato al rilascio")
	assert(bp.get_room_by_id(room_id)["rect"].size == Vector2(200, 150), "Dimensione confermata a (200, 150)")
	
	# 4. Verifica Undo / Redo sul resize
	assert(editor.btn_undo.disabled == false, "Undo abilitato dopo il resize")
	editor.undo()
	assert(bp.get_room_by_id(room_id)["rect"].size == Vector2(150, 120), "Undo ripristina dimensione precedente (150, 120)")
	editor.redo()
	assert(bp.get_room_by_id(room_id)["rect"].size == Vector2(200, 150), "Redo ripristina dimensione modificata (200, 150)")
	
	# 5. Verifica limite dimensione minima (20x20)
	canvas._handle_left_click_pressed(br_pos + Vector2(50, 30), br_pos + Vector2(50, 30))
	var extreme_shrink_pos := new_rect.position - Vector2(100, 100)
	canvas._handle_element_drag(extreme_shrink_pos)
	var final_rect: Rect2 = bp.get_room_by_id(room_id)["rect"]
	assert(final_rect.size.x >= 20.0 and final_rect.size.y >= 20.0, "Dimensione minima stanza 20x20 rispettata")
	canvas._handle_left_click_released(extreme_shrink_pos, extreme_shrink_pos)
	
	editor.queue_free()
	print("  -> OK!")
