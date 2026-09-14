extends Node
class_name CameraFeedManager

## Gestore delle telecamere e delle relative finestre di feed.
## Estratto da SpaceWorldManager.

signal window_opened(cam_id: String, window: FakeWindow)
signal window_closed(cam_id: String)
signal status_changed(cam_id: String, is_open: bool)
signal headlight_toggled(cam_id: String, enabled: bool)
signal hyperdrive_transition_changed(is_active: bool)

var active_camera_windows: Dictionary = {} # cam_id -> FakeWindow
var active_headlights: Dictionary = {} # cam_id -> bool
var is_hyperdrive_transition_active: bool = false
var current_hyperdrive_progress: Dictionary = {"loaded": 1, "total": 1}

func open_camera_window(cam_id: String, window_scene_path: String, parent_node: Node) -> FakeWindow:
	if active_camera_windows.has(cam_id):
		return active_camera_windows[cam_id]
	
	var scene := load(window_scene_path)
	if not scene: return null
	
	var win := scene.instantiate() as FakeWindow
	parent_node.add_child(win)
	
	active_camera_windows[cam_id] = win
	window_opened.emit(cam_id, win)
	status_changed.emit(cam_id, true)
	
	if is_hyperdrive_transition_active and win.has_method("set_hyperdrive_transition"):
		win.set_hyperdrive_transition(true, current_hyperdrive_progress)
	
	win.tree_exited.connect(func(): 
		active_camera_windows.erase(cam_id)
		window_closed.emit(cam_id)
		status_changed.emit(cam_id, false)
	)
	
	return win

func set_hyperdrive_transition(active: bool, progress: Dictionary = {}) -> void:
	is_hyperdrive_transition_active = active
	if not progress.is_empty():
		current_hyperdrive_progress = progress
	hyperdrive_transition_changed.emit(active)
	for cam_id in active_camera_windows:
		var win: FakeWindow = active_camera_windows[cam_id]
		if win and is_instance_valid(win) and win.has_method("set_hyperdrive_transition"):
			win.set_hyperdrive_transition(active, current_hyperdrive_progress)

func update_hyperdrive_progress(loaded: int, total: int) -> void:
	current_hyperdrive_progress = {"loaded": loaded, "total": total}
	for cam_id in active_camera_windows:
		var win: FakeWindow = active_camera_windows[cam_id]
		if win and is_instance_valid(win) and win.has_method("update_hyperdrive_progress"):
			win.update_hyperdrive_progress(loaded, total)

func is_camera_open(cam_id: String) -> bool:
	return active_camera_windows.has(cam_id)

func set_headlight(cam_id: String, enabled: bool) -> void:
	active_headlights[cam_id] = enabled
	headlight_toggled.emit(cam_id, enabled)

func is_headlight_on(cam_id: String) -> bool:
	return active_headlights.get(cam_id, false)

func toggle_headlight(cam_id: String) -> bool:
	var new_state := not is_headlight_on(cam_id)
	set_headlight(cam_id, new_state)
	return new_state
