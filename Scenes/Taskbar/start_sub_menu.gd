extends Panel

@onready var scroll_container: ScrollContainer = $ScrollContainer
@onready var vbox_container: VBoxContainer = $ScrollContainer/VBoxContainer

var parent_menu: Control
var parent_option: Control
var submenus: Array[Panel] = []

func _ready() -> void:
	pass

func populate(tree: Dictionary, p_parent_menu: Control, p_parent_option: Control) -> void:
	parent_menu = p_parent_menu
	parent_option = p_parent_option
	
	# Clear existing
	for child in vbox_container.get_children():
		child.queue_free()
	
	# Use the rendering logic from start_button if possible, or duplicate for now
	# Actually, I'll pass a reference to the start_button to use its methods
	var start_button = get_tree().get_first_node_in_group("start_button_controller")
	if start_button:
		start_button._render_menu_tree(vbox_container, tree, 0, 0, self)
	
	_update_size()

func _update_size() -> void:
	var visible_rows = 0
	for child in vbox_container.get_children():
		if child is Control and child.visible:
			visible_rows += 1
	
	var vp_height = get_viewport().get_visible_rect().size.y
	var max_allowed_height = maxf(vp_height - 60.0, 200.0)
	var desired_height = clampf(float(visible_rows) * 61.0 + 5.0, 40.0, max_allowed_height)
	size.y = desired_height
	
	# Position it to the right of parent_menu
	var parent_rect = parent_menu.get_global_rect()
	var option_rect = parent_option.get_global_rect()
	
	var vp_width = get_viewport().get_visible_rect().size.x
	var target_x = parent_rect.position.x + parent_rect.size.x + 2
	
	# If it goes off screen to the right, open to the left instead
	if target_x + size.x > vp_width - 5:
		target_x = parent_rect.position.x - size.x - 2
	
	global_position.x = target_x
	global_position.y = option_rect.position.y
	
	# Keep on screen vertically
	if global_position.y + size.y > vp_height - 45:
		global_position.y = vp_height - 45 - size.y

func close_submenus() -> void:
	for sub in submenus:
		if is_instance_valid(sub):
			sub.close()
	submenus.clear()

func close() -> void:
	close_submenus()
	queue_free()
