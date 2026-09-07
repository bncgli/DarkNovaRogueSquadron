extends GutTest

## Migrato dal vecchio test manuale tests/test_start_menu_scrollbar.gd
## Verifica la struttura ScrollContainer/VBoxContainer del menu Start, che
## la vecchia "Cube Scene Option" non sia più presente, il popolamento
## dinamico delle app (Lobby e giochi), i binding dello script Start
## Button, e il ridimensionamento del menu Start.

func test_taskbar_start_menu_scroll_structure_and_population() -> void:
	# 1. Carica scena taskbar.tscn
	var taskbar_scene: PackedScene = load("res://Scenes/Taskbar/taskbar.tscn")
	assert_not_null(taskbar_scene, "Scena taskbar.tscn caricata")

	var taskbar_inst: Control = taskbar_scene.instantiate() as Control
	add_child_autofree(taskbar_inst)

	# 2. Verifica ScrollContainer nel menu Start
	var scroll_container := taskbar_inst.get_node_or_null("StartMenuAnchor/Start Menu/ScrollContainer")
	assert_not_null(scroll_container, "ScrollContainer presente nel menu Start")
	assert_true(scroll_container is ScrollContainer, "Il nodo ScrollContainer è un tipo valido di ScrollContainer")

	# 3. Verifica VBoxContainer all'interno di ScrollContainer
	var vbox := scroll_container.get_node_or_null("VBoxContainer")
	assert_not_null(vbox, "VBoxContainer presente all'interno di ScrollContainer")
	assert_true(vbox is VBoxContainer, "VBoxContainer è un tipo valido")

	# 4. Verifica che Cube Scene Option NON sia presente
	var cube_option := vbox.get_node_or_null("Cube Scene Option")
	assert_null(cube_option, "Cube Scene Option NON deve essere presente nel menu Start")

	for child in vbox.get_children():
		assert_ne(child.name, "Cube Scene Option", "Nessun figlio deve essere Cube Scene Option")
		if child.has_method("get"):
			var title := str(child.get("title_text"))
			assert_ne(title, "Cube Scene", "Nessun elemento deve avere titolo 'Cube Scene'")

	# 5. Popola le app dinamicamente e verifica la presenza delle applicazioni di default
	var start_button := taskbar_inst.get_node_or_null("Taskbar/Start Button")
	assert_not_null(start_button, "Start Button presente")
	start_button._refresh_ship_apps()

	var found_lobby := false
	var found_game := false
	for child in vbox.get_children():
		if child.has_method("get"):
			var title: String = str(child.get("title_text"))
			if title.contains("Lobby"):
				found_lobby = true
			if title.contains("Godotris") or title.contains("Pong") or title.contains("Snake") or title.contains("Super Bit Boy") or title.contains("Giochi"):
				found_game = true
	assert_true(found_lobby, "Lobby deve essere presente nel menu Start")
	assert_true(found_game, "I giochi devono essere presenti nel menu Start")

	# 6. Verifica Start Button script bindings
	assert_eq(start_button.vbox_container, vbox, "start_button.vbox_container punta correttamente a VBoxContainer")
	assert_eq(start_button.scroll_container, scroll_container, "start_button.scroll_container punta correttamente a ScrollContainer")

	# 7. Verifica apertura e ridimensionamento Start Menu
	start_button._update_start_menu_size()
	var start_menu: Panel = taskbar_inst.get_node("StartMenuAnchor/Start Menu")
	assert_gt(start_menu.size.y, 0.0, "Altezza menu Start calcolata correttamente")
