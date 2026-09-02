@tool
class_name ShipSublayerEditorPlugin
extends EditorPlugin

## Plugin per l'Editor di Godot che integra l'editor visivo di Ship Blueprint nel pannello inferiore.

var editor_view: ShipSublayerEditor = null
var bottom_panel_button: Button = null

func _enter_tree() -> void:
	var scene = load("res://addons/ship_sublayer_editor/ShipSublayerEditor.tscn")
	editor_view = scene.instantiate() as ShipSublayerEditor
	bottom_panel_button = add_control_to_bottom_panel(editor_view, "Ship Blueprint")

func _exit_tree() -> void:
	if editor_view:
		remove_control_from_bottom_panel(editor_view)
		editor_view.queue_free()
		editor_view = null

func _handles(object: Object) -> bool:
	return object is ShipBlueprint

func _edit(object: Object) -> void:
	if object is ShipBlueprint and editor_view:
		var bp: ShipBlueprint = object as ShipBlueprint
		editor_view.load_blueprint(bp, bp.resource_path)
		make_bottom_panel_item_visible(editor_view)
