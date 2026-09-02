extends Node

func _ready() -> void:
	print("--- TEST: Taskbar Start Menu & ScrollBar ---")
	
	# 1. Carica scena taskbar.tscn
	var taskbar_scene: PackedScene = load("res://Scenes/Taskbar/taskbar.tscn")
	assert(taskbar_scene != null, "Scena taskbar.tscn caricata")
	
	var taskbar_inst: Control = taskbar_scene.instantiate() as Control
	add_child(taskbar_inst)
	
	# 2. Verifica ScrollContainer nel menu Start
	var scroll_container = taskbar_inst.get_node_or_null("StartMenuAnchor/Start Menu/ScrollContainer")
	assert(scroll_container != null, "ScrollContainer presente nel menu Start")
	assert(scroll_container is ScrollContainer, "Il nodo ScrollContainer è un tipo valido di ScrollContainer")
	
	# 3. Verifica VBoxContainer all'interno di ScrollContainer
	var vbox = scroll_container.get_node_or_null("VBoxContainer")
	assert(vbox != null, "VBoxContainer presente all'interno di ScrollContainer")
	assert(vbox is VBoxContainer, "VBoxContainer è un tipo valido")
	
	# 4. Verifica che Cube Scene Option NON sia presente
	var cube_option = vbox.get_node_or_null("Cube Scene Option")
	assert(cube_option == null, "Cube Scene Option NON deve essere presente nel menu Start")
	
	for child in vbox.get_children():
		assert(child.name != "Cube Scene Option", "Nessun figlio deve essere Cube Scene Option")
		if child.has_method("get"):
			var title = str(child.get("title_text"))
			assert(title != "Cube Scene", "Nessun elemento deve avere titolo 'Cube Scene'")
	
	# 5. Verifica che gli altri programmi siano presenti nel menu Start
	var expected_options := ["Lobby Option", "Godotris Option", "Super Bit Boy Option", "Snake Option", "Pong Option"]
	for opt_name in expected_options:
		var opt_node = vbox.get_node_or_null(opt_name)
		assert(opt_node != null, "Opzione %s deve essere presente nel menu Start" % opt_name)
	
	# 6. Verifica Start Button script bindings
	var start_button = taskbar_inst.get_node_or_null("Taskbar/Start Button")
	assert(start_button != null, "Start Button presente")
	assert(start_button.vbox_container == vbox, "start_button.vbox_container punta correttamente a VBoxContainer")
	assert(start_button.scroll_container == scroll_container, "start_button.scroll_container punta correttamente a ScrollContainer")
	
	# 7. Verifica apertura e ridimensionamento Start Menu
	start_button._update_start_menu_size()
	var start_menu: Panel = taskbar_inst.get_node("StartMenuAnchor/Start Menu")
	assert(start_menu.size.y > 0, "Altezza menu Start calcolata correttamente")
	
	print("--- TUTTI I TEST TASKBAR E START MENU SUPERATI CON SUCCESSO! ---")
	get_tree().quit(0)
