extends Panel
class_name FakeWindow

## The base class for each window. Handles moving, resizing, minimizing, etc.

@onready var top_bar: Panel = $"Top Bar"

static var num_of_windows: int

var title_text: String

var is_dragging: bool
var start_drag_position: Vector2
var mouse_start_drag_position: Vector2

var is_being_deleted: bool
var is_minimized: bool
var is_selected: bool
var is_maximized: bool
var is_external: bool = false

var native_window: Window = null
var internal_parent: Node = null
var internal_position: Vector2
var internal_size: Vector2

var maximize_icon: CompressedTexture2D = preload("res://Art/Icons/expand.png")
var unmaximize_icon: CompressedTexture2D = preload("res://Art/Icons/shrink.png")
var old_unmaximized_position: Vector2
var old_unmaximized_size: Vector2

var start_bg_color_alpha: float

signal minimized(is_minimized: bool)
signal selected(is_selected: bool)
signal deleted()
@warning_ignore("unused_signal")
signal maximized(is_maximized: bool)
signal popout_toggled(is_external: bool)

func _ready() -> void:
	# Duplicate theme override so values can be set without affecting other windows
	self["theme_override_styles/panel"] = self["theme_override_styles/panel"].duplicate()
	top_bar["theme_override_styles/panel"] = top_bar["theme_override_styles/panel"].duplicate()
	start_bg_color_alpha = self["theme_override_styles/panel"]["bg_color"].a
	
	num_of_windows += 1
	select_window(false)
	
	$"Top Bar/Title Text".text = " ".join(title_text.split("\n"))
	
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	
	_update_popout_button_state()
	
	modulate.a = 0
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 1, 0.5)

func _process(_delta: float) -> void:
	if is_dragging and !is_external:
		global_position = start_drag_position + (get_global_mouse_position() - mouse_start_drag_position)
		clamp_window_inside_viewport()

func _input(event: InputEvent) -> void:
	if is_external or is_selected or is_minimized or not is_visible_in_tree():
		return
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT) and event.is_pressed():
		if get_global_rect().has_point(event.global_position):
			var is_covered: bool = false
			for window in get_tree().get_nodes_in_group("window"):
				if window == self:
					continue
				if not is_instance_valid(window) or window.is_queued_for_deletion():
					continue
				if window.is_external or window.is_minimized or not window.is_visible_in_tree():
					continue
				
				var is_above: bool = false
				if window.z_index > z_index:
					is_above = true
				elif window.z_index == z_index and window.get_parent() == get_parent() and window.get_index() > get_index():
					is_above = true
				
				if is_above and window.get_global_rect().has_point(event.global_position):
					is_covered = true
					break
			
			if not is_covered:
				select_window(true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event.button_index == 1 or event.button_index == 2) and event.is_pressed():
		select_window(true)

func _on_top_bar_gui_input(event: InputEvent) -> void:
	if is_external:
		return
	if event is InputEventMouseButton and event.button_index == 1:
		if event.is_pressed():
			is_dragging = true
			start_drag_position = global_position
			mouse_start_drag_position = get_global_mouse_position()
		else:
			is_dragging = false

func _on_popout_button_pressed() -> void:
	toggle_external_window()

func toggle_external_window() -> void:
	if is_external:
		dock_to_internal_window()
	else:
		detach_to_external_window()

func detach_to_external_window() -> void:
	if is_external:
		return
	
	if is_maximized:
		maximize_window()
	
	is_external = true
	internal_parent = get_parent()
	internal_position = position
	internal_size = size
	
	var clean_title: String = ($"Top Bar/Title Text" as RichTextLabel).text.replace("[center]", "").replace("[/center]", "").strip_edges()
	if clean_title.is_empty():
		clean_title = title_text.replace("\n", " ").strip_edges()
	
	native_window = Window.new()
	native_window.title = clean_title
	native_window.size = Vector2i(maxi(int(size.x), int(custom_minimum_size.x)), maxi(int(size.y), int(custom_minimum_size.y)))
	native_window.min_size = Vector2i(int(custom_minimum_size.x), int(custom_minimum_size.y))
	native_window.transient = false
	native_window.wrap_controls = false
	
	var main_window_pos: Vector2i = DisplayServer.window_get_position(DisplayServer.MAIN_WINDOW_ID)
	native_window.position = main_window_pos + Vector2i(int(global_position.x), int(global_position.y))
	
	native_window.close_requested.connect(_on_external_close_requested)
	native_window.focus_entered.connect(_on_external_focus_entered)
	native_window.focus_exited.connect(_on_external_focus_exited)
	native_window.size_changed.connect(_on_external_size_changed)
	
	get_tree().root.add_child(native_window)
	if internal_parent:
		internal_parent.remove_child(self)
	native_window.add_child(self)
	
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	
	if has_node("Resize Drag Spot"):
		$"Resize Drag Spot".visible = false
	if has_node("CornerHandle"):
		$"CornerHandle".visible = false
	
	_update_popout_button_state()
	
	native_window.popup()
	popout_toggled.emit(true)
	select_window(false)

func dock_to_internal_window() -> void:
	if !is_external:
		return
	
	is_external = false
	var parent_to_attach: Node = internal_parent
	if parent_to_attach == null or !is_instance_valid(parent_to_attach) or parent_to_attach.is_queued_for_deletion():
		parent_to_attach = get_tree().current_scene
	
	var ext_win: Window = native_window
	native_window = null
	
	if get_parent() == ext_win:
		ext_win.remove_child(self)
	parent_to_attach.add_child(self)
	
	anchors_preset = Control.PRESET_CENTER
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	size = internal_size
	position = internal_position
	clamp_window_inside_viewport()
	
	if has_node("Resize Drag Spot"):
		$"Resize Drag Spot".visible = true
	if has_node("CornerHandle"):
		$"CornerHandle".visible = true
	
	_update_popout_button_state()
	
	if ext_win and is_instance_valid(ext_win) and !ext_win.is_queued_for_deletion():
		ext_win.queue_free()
	
	popout_toggled.emit(false)
	select_window(true)

func _on_external_close_requested() -> void:
	_on_close_button_pressed()

func _on_external_focus_entered() -> void:
	select_window(false)

func _on_external_focus_exited() -> void:
	deselect_window()

func _on_external_size_changed() -> void:
	if is_external and native_window:
		size = Vector2(native_window.size)
		if has_node("Resize Drag Spot"):
			$"Resize Drag Spot".window_resized.emit()

func _update_popout_button_state() -> void:
	var btn: Button = get_node_or_null("Top Bar/HBoxContainer/Popout Button")
	if btn:
		if is_external:
			btn.text = "↙"
			btn.tooltip_text = "Riporta all'interno di GodotOS"
		else:
			btn.text = "↗"
			btn.tooltip_text = "Apri come finestra esterna (OS)"

func _exit_tree() -> void:
	if is_being_deleted and is_external and native_window and is_instance_valid(native_window) and !native_window.is_queued_for_deletion():
		var win: Window = native_window
		native_window = null
		win.queue_free()

func _on_close_button_pressed() -> void:
	if is_being_deleted:
		return
	
	if GlobalValues.selected_window == self:
		GlobalValues.selected_window = null
	
	deleted.emit()
	num_of_windows -= 1
	is_being_deleted = true
	
	if is_external and native_window and is_instance_valid(native_window) and !native_window.is_queued_for_deletion():
		var win: Window = native_window
		native_window = null
		win.queue_free()
	else:
		var tween: Tween = create_tween()
		tween.set_trans(Tween.TRANS_CUBIC)
		await tween.tween_property(self, "modulate:a", 0, 0.25).finished
		queue_free()

func _on_minimize_button_pressed() -> void:
	hide_window()

func hide_window() -> void:
	if is_minimized:
		return
	
	deselect_window()
	is_minimized = true
	minimized.emit(is_minimized)
	
	if is_external and native_window and is_instance_valid(native_window):
		native_window.visible = false
		return
	
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y + 20, 0.25)
	await tween.tween_property(self, "modulate:a", 0, 0.25).finished
	if !is_selected:
		visible = false

func show_window() -> void:
	if !is_minimized:
		return
	
	select_window(false)
	
	is_minimized = false
	minimized.emit(is_minimized)
	
	if is_external and native_window and is_instance_valid(native_window):
		native_window.visible = true
		if native_window.mode == Window.MODE_MINIMIZED:
			native_window.mode = Window.MODE_WINDOWED
		native_window.grab_focus()
		return
	
	visible = true
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 20, 0.25)
	tween.tween_property(self, "modulate:a", 1, 0.25)

## Actually "focuses" the window and brings it to the front
func select_window(_play_fade_animation: bool = false) -> void:
	if is_selected:
		return
	
	is_selected = true
	selected.emit(true)
	GlobalValues.selected_window = self
	
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property($"Top Bar/Title Text", "modulate", Color("3cffff"), 0.25)
	tween.tween_property(self["theme_override_styles/panel"], "shadow_size", 20, 0.25)
	
	# Move in front of all other windows (+2 to ignore wallpaper and bg color)
	if !is_external and get_parent():
		get_parent().move_child(self, min(num_of_windows + 2, get_parent().get_child_count() - 1))
	
	deselect_other_windows()

func deselect_window() -> void:
	if !is_selected:
		return
	
	is_selected = false
	selected.emit(false)
	
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property($"Top Bar/Title Text", "modulate", Color.WHITE, 0.25)
	tween.tween_property(self["theme_override_styles/panel"], "shadow_size", 0, 0.25)

func deselect_other_windows() -> void:
	for window in get_tree().get_nodes_in_group("window"):
		if window == self:
			continue
		window.deselect_window()

func clamp_window_inside_viewport() -> void:
	if is_external:
		return
	var game_window_size: Vector2 = get_viewport_rect().size
	if (size.y > game_window_size.y - 40):
		size.y = game_window_size.y - 40
	if (size.x > game_window_size.x):
		size.x = game_window_size.x
	
	global_position.y = clamp(global_position.y, 0, game_window_size.y - size.y - 40)
	global_position.x = clamp(global_position.x, 0, game_window_size.x - size.x)

func _on_viewport_size_changed() -> void:
	if is_external:
		return
	if is_maximized:
		var new_size: Vector2 = get_viewport_rect().size
		new_size.y -= 40 #Because taskbar
		global_position = Vector2.ZERO
		size = new_size
	
	clamp_window_inside_viewport()

func _on_maximize_button_pressed() -> void:
	maximize_window()

func maximize_window() -> void:
	if is_external and native_window and is_instance_valid(native_window):
		if native_window.mode == Window.MODE_MAXIMIZED:
			native_window.mode = Window.MODE_WINDOWED
			is_maximized = false
			$"Top Bar/HBoxContainer/Maximize Button".icon = maximize_icon
		else:
			native_window.mode = Window.MODE_MAXIMIZED
			is_maximized = true
			$"Top Bar/HBoxContainer/Maximize Button".icon = unmaximize_icon
		return

	if is_maximized:
		is_maximized = !is_maximized
		$"Top Bar/HBoxContainer/Maximize Button".icon = maximize_icon
		
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "global_position", old_unmaximized_position, 0.25)
		tween.tween_property(self["theme_override_styles/panel"], "bg_color:a", start_bg_color_alpha, 0.25)
		await tween.tween_property(self, "size", old_unmaximized_size, 0.25).finished
		
		self["theme_override_styles/panel"].set_corner_radius_all(5)
		top_bar["theme_override_styles/panel"]["corner_radius_top_left"] = 5
		top_bar["theme_override_styles/panel"]["corner_radius_top_right"] = 5
		
		if has_node("Resize Drag Spot"):
			$"Resize Drag Spot".window_resized.emit()
	else:
		is_maximized = !is_maximized
		$"Top Bar/HBoxContainer/Maximize Button".icon = unmaximize_icon
		
		old_unmaximized_position = global_position
		old_unmaximized_size = size
		
		var new_size: Vector2 = get_viewport_rect().size
		new_size.y -= 40 #Because taskbar
		
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "global_position", Vector2.ZERO, 0.25)
		tween.tween_property(self["theme_override_styles/panel"], "bg_color:a", 1, 0.25)
		await tween.tween_property(self, "size", new_size, 0.25).finished
		
		self["theme_override_styles/panel"].set_corner_radius_all(0)
		top_bar["theme_override_styles/panel"]["corner_radius_top_left"] = 0
		top_bar["theme_override_styles/panel"]["corner_radius_top_right"] = 0
		
		if has_node("Resize Drag Spot"):
			$"Resize Drag Spot".window_resized.emit()
