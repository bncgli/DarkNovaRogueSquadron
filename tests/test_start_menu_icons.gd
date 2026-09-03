extends Node

func _ready() -> void:
	print("--- AVVIO TEST START MENU ICONS & UI ---")
	
	_test_1_option_dimensions()
	_test_2_only_title_visible()
	_test_3_tooltip_description()
	_test_4_app_resource_icon_property()
	_test_5_icon_fallback_behavior()
	_test_6_all_24_apps_have_valid_icons()
	
	print("\n=======================================================")
	print(" TUTTI I TEST START MENU ICONS SUPERATI CON SUCCESSO! [OK]")
	print("=======================================================")
	get_tree().quit(0)

func _test_1_option_dimensions() -> void:
	print("\n--- Test 1: Dimensioni 20% più piccole ---")
	var option_scene := load("res://Scenes/Taskbar/start_menu_option.tscn")
	assert(option_scene != null, "Scene start_menu_option.tscn must exist")
	var option: Control = option_scene.instantiate()
	add_child(option)
	
	assert(option.custom_minimum_size.y == 48, "Start menu option height should be 48 (60 * 0.8)")
	var margin_container: Control = option.get_node_or_null("HBoxContainer/MarginContainer")
	assert(margin_container != null, "MarginContainer must exist")
	assert(margin_container.custom_minimum_size.x == 40, "MarginContainer width should be 40 (50 * 0.8)")
	
	option.queue_free()
	print("✔ Test 1 superato: Dimensioni ridotte del 20% (altezza riga 48px, larghezza icona 40px).")

func _test_2_only_title_visible() -> void:
	print("\n--- Test 2: Solo il nome del programma visibile ---")
	var option_scene := load("res://Scenes/Taskbar/start_menu_option.tscn")
	var option: Control = option_scene.instantiate()
	add_child(option)
	
	var title_node: Node = option.get_node_or_null("%Menu Title")
	assert(title_node != null, "Menu Title must exist")
	var desc_node: Node = option.get_node_or_null("%Menu Description")
	assert(desc_node == null, "Menu Description must not exist in start_menu_option.tscn")
	var dev_node: Node = option.get_node_or_null("%Menu Developer")
	assert(dev_node == null, "Menu Developer must not exist in start_menu_option.tscn")
	
	option.queue_free()
	print("✔ Test 2 superato: Nel menu si vede solo il titolo del programma.")

func _test_3_tooltip_description() -> void:
	print("\n--- Test 3: Tooltip con descrizione al passaggio del mouse ---")
	var option_scene := load("res://Scenes/Taskbar/start_menu_option.tscn")
	var option: Control = option_scene.instantiate()
	add_child(option)
	
	var test_desc := "Questa è una descrizione dettagliata del software."
	option.configure_option("Software Test", test_desc, "res://test.tscn", Color.WHITE, null, "Dev")
	assert(option.tooltip_text == test_desc, "Option tooltip_text must match description")
	
	option.queue_free()
	print("✔ Test 3 superato: Il tooltip mostra correttamente la descrizione dell'app.")

func _test_4_app_resource_icon_property() -> void:
	print("\n--- Test 4: Variabile icon in AppResource ---")
	var app_res := AppResource.new()
	assert("icon" in app_res, "AppResource must have 'icon' property")
	assert(app_res.icon == null, "Default icon should be null")
	
	var dummy_tex: Texture2D = load("res://Art/Icons/Apps/flight_control.svg")
	app_res.icon = dummy_tex
	assert(app_res.icon == dummy_tex, "Icon property assignment must work")
	
	var d := app_res.to_dict()
	assert(d.has("icon"), "to_dict() must include 'icon'")
	assert(d["icon"] == dummy_tex, "to_dict() icon must match assigned icon")
	
	print("✔ Test 4 superato: AppResource contiene la variabile 'icon' correttamente serializzata.")

func _test_5_icon_fallback_behavior() -> void:
	print("\n--- Test 5: Fallback su icona standard in caso di assenza o errore ---")
	var option_scene := load("res://Scenes/Taskbar/start_menu_option.tscn")
	var option: Control = option_scene.instantiate()
	add_child(option)
	
	var tex_rect: TextureRect = option.get_node("HBoxContainer/MarginContainer/TextureRect")
	
	# Fallback quando icon è null
	option.configure_option("No Icon App", "Desc", "res://test.tscn", Color.WHITE, null)
	assert(tex_rect.texture != null, "TextureRect should have fallback default icon when null is passed")
	assert(tex_rect.texture.resource_path.contains("standard_app.svg"), "Default icon should be standard_app.svg")
	
	# Icona personalizzata
	var custom_tex: Texture2D = load("res://Art/Icons/Apps/cams.svg")
	option.configure_option("Cams App", "Desc", "res://test.tscn", Color.WHITE, custom_tex)
	assert(tex_rect.texture == custom_tex, "TextureRect should use custom icon when provided")
	
	option.queue_free()
	print("✔ Test 5 superato: Comportamento di default con fallback su icona standard verificato.")

func _test_6_all_24_apps_have_valid_icons() -> void:
	print("\n--- Test 6: Verifica icone per tutte le 24 applicazioni di sistema GodotOS ---")
	
	var app_tres_files := [
		"res://Applications/FlightControl/flight_control_app.tres",
		"res://Applications/Cams/cams_app.tres",
		"res://Applications/DuctDrone/duct_drone_app.tres",
		"res://Applications/PowerGrid/power_grid_app.tres",
		"res://Applications/Weapons/weapons_app.tres",
		"res://Applications/ShieldMatrix/shield_matrix_app.tres",
		"res://Applications/Diagnostics/diagnostics_app.tres",
		"res://Applications/Sensors/sensors_app.tres",
		"res://Applications/LifeSupport/life_support_app.tres",
		"res://Applications/Logbook/logbook_app.tres",
		"res://Applications/ServiceDrone/service_drone_app.tres",
		"res://Applications/StationHub/station_hub_app.tres",
		"res://Applications/CargoBay/cargo_bay_app.tres",
		"res://Applications/FluxWallet/flux_wallet.tres",
		"res://Applications/Comms/comms_app.tres",
		"res://Applications/SystemMap/system_map_app.tres",
		"res://Applications/Terminal/terminal_app.tres",
		"res://Applications/PodInfo/pod_info_app.tres",
		"res://Applications/ShipBuilder/ship_builder.tres",
		"res://Applications/Games/Godotris/godotris_app.tres",
		"res://Applications/Games/Pong/pong_app.tres",
		"res://Applications/Games/Snake/snake_app.tres",
		"res://Applications/Games/Super Bit Boy/super_bit_boy_app.tres",
		"res://Applications/Lobby/lobby_app.tres"
	]
	
	assert(app_tres_files.size() == 24, "Must have exactly 24 application resources")
	
	for path in app_tres_files:
		assert(ResourceLoader.exists(path), "Resource file must exist: %s" % path)
		var res: AppResource = load(path) as AppResource
		assert(res != null, "Resource must load as AppResource: %s" % path)
		assert(res.icon != null, "AppResource %s must have a non-null icon" % path)
		assert(res.icon is Texture2D, "AppResource %s icon must be a Texture2D" % path)
		print("  ✔ App '%s' -> Icon: %s" % [res.title if not res.title.is_empty() else res.app_id, res.icon.resource_path])
	
	print("✔ Test 6 superato: Tutte le 24 applicazioni hanno un'icona valida e funzionante.")
