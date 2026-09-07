extends GutTest

## Migrato dal vecchio test manuale tests/test_start_menu_icons.gd
## Verifica dimensioni, contenuti visibili, tooltip, proprietà icona su
## AppResource, comportamento di fallback dell'icona, e che tutte le
## applicazioni di sistema GodotOS abbiano un'icona valida.

func test_option_dimensions_reduced_by_20_percent() -> void:
	var option_scene: PackedScene = load("res://Scenes/Taskbar/start_menu_option.tscn")
	assert_not_null(option_scene, "La scena start_menu_option.tscn deve esistere")
	var option: Control = option_scene.instantiate()
	add_child_autofree(option)

	assert_eq(option.custom_minimum_size.y, 48.0, "L'altezza dell'opzione del menu Start dovrebbe essere 48 (60 * 0.8)")
	var margin_container: Control = option.get_node_or_null("HBoxContainer/MarginContainer")
	assert_not_null(margin_container, "MarginContainer deve esistere")
	assert_eq(margin_container.custom_minimum_size.x, 40.0, "La larghezza di MarginContainer dovrebbe essere 40 (50 * 0.8)")

func test_only_title_is_visible() -> void:
	var option_scene: PackedScene = load("res://Scenes/Taskbar/start_menu_option.tscn")
	var option: Control = option_scene.instantiate()
	add_child_autofree(option)

	var title_node: Node = option.get_node_or_null("%Menu Title")
	assert_not_null(title_node, "Menu Title deve esistere")
	var desc_node: Node = option.get_node_or_null("%Menu Description")
	assert_null(desc_node, "Menu Description non deve esistere in start_menu_option.tscn")
	var dev_node: Node = option.get_node_or_null("%Menu Developer")
	assert_null(dev_node, "Menu Developer non deve esistere in start_menu_option.tscn")

func test_tooltip_shows_description() -> void:
	var option_scene: PackedScene = load("res://Scenes/Taskbar/start_menu_option.tscn")
	var option: Control = option_scene.instantiate()
	add_child_autofree(option)

	var test_desc := "Questa è una descrizione dettagliata del software."
	option.configure_option("Software Test", test_desc, "res://test.tscn", Color.WHITE, null, "Dev")
	assert_eq(option.tooltip_text, test_desc, "Il tooltip_text dell'opzione deve corrispondere alla descrizione")

func test_app_resource_has_icon_property() -> void:
	var app_res := AppResource.new()
	assert_true("icon" in app_res, "AppResource deve avere la proprietà 'icon'")
	assert_null(app_res.icon, "L'icona di default dovrebbe essere null")

	var dummy_tex: Texture2D = load("res://Art/Icons/Apps/flight_control.svg")
	app_res.icon = dummy_tex
	assert_eq(app_res.icon, dummy_tex, "L'assegnazione della proprietà icon deve funzionare")

	var d := app_res.to_dict()
	assert_true(d.has("icon"), "to_dict() deve includere 'icon'")
	assert_eq(d["icon"], dummy_tex, "L'icona in to_dict() deve corrispondere a quella assegnata")

func test_icon_fallback_behavior() -> void:
	var option_scene: PackedScene = load("res://Scenes/Taskbar/start_menu_option.tscn")
	var option: Control = option_scene.instantiate()
	add_child_autofree(option)

	var tex_rect: TextureRect = option.get_node("HBoxContainer/MarginContainer/TextureRect")

	# Fallback quando icon è null
	option.configure_option("No Icon App", "Desc", "res://test.tscn", Color.WHITE, null)
	assert_not_null(tex_rect.texture, "TextureRect deve avere l'icona di default quando viene passato null")
	assert_true(tex_rect.texture.resource_path.contains("standard_app.svg"), "L'icona di default deve essere standard_app.svg")

	# Icona personalizzata
	var custom_tex: Texture2D = load("res://Art/Icons/Apps/cams.svg")
	option.configure_option("Cams App", "Desc", "res://test.tscn", Color.WHITE, custom_tex)
	assert_eq(tex_rect.texture, custom_tex, "TextureRect deve usare l'icona personalizzata quando fornita")

func test_all_24_system_apps_have_valid_icons() -> void:
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
		"res://Applications/ShipBuilder/ship_builder.tres",
		"res://Applications/Games/Godotris/godotris_app.tres",
		"res://Applications/Games/Pong/pong_app.tres",
		"res://Applications/Games/Snake/snake_app.tres",
		"res://Applications/Games/Super Bit Boy/super_bit_boy_app.tres",
		"res://Applications/Lobby/lobby_app.tres"
	]

	assert_eq(app_tres_files.size(), 23, "Devono esserci esattamente 23 risorse applicazione")

	for path in app_tres_files:
		assert_true(ResourceLoader.exists(path), "Il file risorsa deve esistere: %s" % path)
		var res: AppResource = load(path) as AppResource
		assert_not_null(res, "La risorsa deve caricarsi come AppResource: %s" % path)
		assert_not_null(res.icon, "AppResource %s deve avere un'icona non nulla" % path)
		assert_true(res.icon is Texture2D, "L'icona di AppResource %s deve essere un Texture2D" % path)
