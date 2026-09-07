@tool
class_name StarSystemEditorPlugin
extends EditorPlugin

## Plugin per l'Editor di Godot che integra l'editor visivo di Star System nel pannello inferiore.

var editor_view: StarSystemEditor = null
var bottom_panel_button: Button = null

func _enter_tree() -> void:
	var scene := load("res://addons/star_system_editor/star_system_editor.tscn")
	editor_view = scene.instantiate() as StarSystemEditor
	editor_view.undo_redo = get_undo_redo()
	bottom_panel_button = add_control_to_bottom_panel(editor_view, "Star System")

func _exit_tree() -> void:
	if editor_view:
		remove_control_from_bottom_panel(editor_view)
		editor_view.queue_free()
		editor_view = null

func _handles(object: Object) -> bool:
	return object is StarSystemData

func _edit(object: Object) -> void:
	if object is StarSystemData and editor_view:
		var sys: StarSystemData = object as StarSystemData
		editor_view.load_star_system(sys, sys.resource_path)
		make_bottom_panel_item_visible(editor_view)
