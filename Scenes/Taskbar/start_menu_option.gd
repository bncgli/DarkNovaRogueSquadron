extends Panel

## A start menu option. Used to display and spawn applications and games.

## Path to the game scene (if it's a game)
@export var game_scene: String

## Path to the application scene (if it's an application)
@export var application_scene: String

## Title shown in start menu option (added at runtime).
@export var title_text: String

## Description shown in start menu option (added at runtime).
@export var description_text: String

## Developer shown in start menu option (added at runtime).
@export var developer_text: String

## Whether or not the scene should be instantiated inside a game window or outside one.
@export var spawn_inside_window: bool = true

## Whether to use a simple pause menu or not (spawned by pressing ESC or P)
@export var use_generic_pause_menu: bool

const DEFAULT_APP_ICON: Texture2D = preload("res://Art/Icons/Apps/standard_app.svg")
const FOLDER_ICON: Texture2D = preload("res://Art/Folder Icons/folder.png")

var is_folder: bool = false
var sub_tree: Dictionary = {}
signal folder_pressed(option: Control)

var is_mouse_over: bool

func _ready() -> void:
	$"Background Panel".visible = false
	if has_node("%Menu Title"):
		%"Menu Title".text = "[center]%s" % title_text
	if has_node("%Menu Description"):
		%"Menu Description".text = "[center]%s" % description_text
	if has_node("%Menu Developer"):
		%"Menu Developer".text = "[center][color=gray]%s[/color]" % developer_text
	
	tooltip_text = description_text if not is_folder else ""
	
	var tex_rect: TextureRect = get_node_or_null("HBoxContainer/MarginContainer/TextureRect")
	if tex_rect and tex_rect.texture == null:
		tex_rect.texture = DEFAULT_APP_ICON

func configure_option(p_title: String, p_description: String, p_app_scene: String, p_color: Color = Color.WHITE, p_texture: Texture2D = null, p_developer: String = "", p_is_folder: bool = false, p_sub_tree: Dictionary = {}, p_is_game: bool = false) -> void:
	title_text = p_title
	description_text = p_description
	developer_text = p_developer
	is_folder = p_is_folder
	sub_tree = p_sub_tree
	if p_is_game:
		game_scene = p_app_scene
		application_scene = ""
		use_generic_pause_menu = true
	else:
		application_scene = p_app_scene
		game_scene = ""
		use_generic_pause_menu = false
	
	tooltip_text = description_text if not is_folder else ""
	
	if has_node("%Menu Title"):
		%"Menu Title".text = "[center]%s" % title_text
	if has_node("%Menu Description"):
		%"Menu Description".text = "[center]%s" % (description_text if not is_folder else "")
	if has_node("%Menu Developer"):
		%"Menu Developer".text = "[center][color=gray]%s[/color]" % (developer_text if not is_folder else "")
	
	var tex_rect: TextureRect = get_node_or_null("HBoxContainer/MarginContainer/TextureRect")
	if tex_rect:
		if is_folder:
			tex_rect.texture = FOLDER_ICON
			tex_rect.modulate = Color(0.95, 0.75, 0.2)
		elif p_texture != null and p_texture is Texture2D:
			tex_rect.texture = p_texture
			tex_rect.modulate = p_color
		else:
			tex_rect.texture = DEFAULT_APP_ICON
			tex_rect.modulate = p_color

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == 1 and event.is_pressed():
		accept_event()
		if is_folder:
			folder_pressed.emit(self)
			return
			
		if spawn_inside_window:
			spawn_window()
		else:
			spawn_outside_window()
		
		var start_button := get_tree().get_first_node_in_group("start_button_controller")
		if start_button and start_button.has_method("hide_start_menu"):
			start_button.hide_start_menu()

func _on_mouse_entered() -> void:
	is_mouse_over = true
	$"Background Panel".visible = true
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property($"Background Panel", "modulate:a", 1, 0.2)

func _on_mouse_exited() -> void:
	is_mouse_over = false
	var tween: Tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.tween_property($"Background Panel", "modulate:a", 0, 0.2).finished
	if !is_mouse_over:
		$"Background Panel".visible = false

# TODO find a better way than copying this from desktop_folder.gd
func spawn_window() -> void:
	var window: FakeWindow
	
	if game_scene:
		window = load("res://Scenes/Window/Game Window/game_window.tscn").instantiate()
		window.get_node("%Game Window").add_child(load(game_scene).instantiate())
		
		if use_generic_pause_menu:
			window.get_node("%GamePauseManager").process_mode = Node.PROCESS_MODE_INHERIT
		
	elif application_scene:
		window = load("res://Scenes/Window/Application Window/application_window.tscn").instantiate()
		window.get_node("%ApplicationContents").add_child(load(application_scene).instantiate())
	
	window.title_text = title_text if not title_text.is_empty() else %"Menu Title".text.replace("[center]", "").replace("[/center]", "")
	get_tree().current_scene.add_child(window)
	
	var taskbar_button: Control = load("res://Scenes/Taskbar/taskbar_button.tscn").instantiate()
	taskbar_button.target_window = window
	var tex: Texture2D = $"HBoxContainer/MarginContainer/TextureRect".texture
	if tex == null:
		tex = DEFAULT_APP_ICON
	taskbar_button.get_node("TextureMargin/TextureRect").texture = tex
	taskbar_button.active_color = $"HBoxContainer/MarginContainer/TextureRect".modulate
	get_tree().get_first_node_in_group("taskbar_buttons").add_child(taskbar_button)

func spawn_outside_window() -> void:
	$/root/Control.add_child(load(game_scene).instantiate())
