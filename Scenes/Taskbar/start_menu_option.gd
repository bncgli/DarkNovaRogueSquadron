extends Panel

## A start menu option. Currently only used to spawn game windows and nothing else.

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
## (You probably want this on, but it's great if you want to make your own custom window or behavior)
@export var spawn_inside_window: bool = true

## Whether to use a simple pause menu or not (spawned by pressing ESC or P)
@export var use_generic_pause_menu: bool

var is_mouse_over: bool

func _ready() -> void:
	$"Background Panel".visible = false
	if has_node("%Menu Title"):
		%"Menu Title".text = "[center]%s" % title_text
	if has_node("%Menu Description"):
		%"Menu Description".text = "[center]%s" % description_text
	if has_node("%Menu Developer"):
		%"Menu Developer".text = "[center][color=gray]%s[/color]" % developer_text

func configure_option(p_title: String, p_description: String, p_app_scene: String, p_color: Color = Color.WHITE, p_texture: Texture2D = null, p_developer: String = "") -> void:
	title_text = p_title
	description_text = p_description
	developer_text = p_developer
	application_scene = p_app_scene
	game_scene = ""
	use_generic_pause_menu = false
	if has_node("%Menu Title"):
		%"Menu Title".text = "[center]%s" % title_text
	if has_node("%Menu Description"):
		%"Menu Description".text = "[center]%s" % description_text
	if has_node("%Menu Developer"):
		%"Menu Developer".text = "[center][color=gray]%s[/color]" % developer_text
	var tex_rect: TextureRect = get_node_or_null("HBoxContainer/MarginContainer/TextureRect")
	if tex_rect:
		tex_rect.modulate = p_color
		if p_texture:
			tex_rect.texture = p_texture

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == 1 and event.is_pressed():
		if spawn_inside_window:
			spawn_window()
		else:
			spawn_outside_window()

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
	taskbar_button.get_node("TextureMargin/TextureRect").texture = $"HBoxContainer/MarginContainer/TextureRect".texture
	taskbar_button.active_color = $"HBoxContainer/MarginContainer/TextureRect".modulate
	get_tree().get_first_node_in_group("taskbar_buttons").add_child(taskbar_button)

func spawn_outside_window() -> void:
	$/root/Control.add_child(load(game_scene).instantiate())
