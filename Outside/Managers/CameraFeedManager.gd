extends Node
class_name CameraFeedManager

## Gestore delle telecamere e delle relative finestre di feed.
## Estratto da SpaceWorldManager.

signal window_opened(cam_id: String, window: FakeWindow)
signal window_closed(cam_id: String)
signal status_changed(cam_id: String, is_open: bool)
signal headlight_toggled(cam_id: String, enabled: bool)

var active_camera_windows: Dictionary = {} # cam_id -> FakeWindow
var active_headlights: Dictionary = {} # cam_id -> bool

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
	
	win.tree_exited.connect(func(): 
		active_camera_windows.erase(cam_id)
		window_closed.emit(cam_id)
		status_changed.emit(cam_id, false)
	)
	
	return win

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
