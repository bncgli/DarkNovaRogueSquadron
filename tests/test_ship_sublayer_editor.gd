@tool
extends Node

## Test Suite per Ship Sublayer Blueprint Editor e Canvas

func _ready() -> void:
	print("--- INIZIO TEST SHIP SUBLAYER EDITOR ---")
	_test_editor_ui_layout()
	_test_layer_toggles()
	_test_undo_redo_system()
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
	assert(editor.btn_add_damage != null, "Pulsante Danno deve esistere")
	assert(editor.btn_delete != null, "Pulsante Elimina deve esistere")
	
	# Verifica outliner / pannello tutti i layer (a sinistra) e inspector (a destra)
	assert(editor.outliner_tree != null, "Outliner con tutti i layer deve esistere nel pannello sinistro")
	assert(editor.prop_editor_vbox != null, "Inspector proprietà deve esistere nel pannello destro")
	
	# Verifica tutti i checkbox dei layer (Errore 1 & Errore 3)
	assert(editor.chk_layer_rooms != null, "Checkbox Stanze deve esistere")
	assert(editor.chk_layer_ducts != null, "Checkbox Condotti deve esistere")
	assert(editor.chk_layer_devices != null, "Checkbox Dispositivi deve esistere")
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
