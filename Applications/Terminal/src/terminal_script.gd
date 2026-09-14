extends Control
class_name Terminal


const COMMAND_OUTPUT_LABEL_SCENE: PackedScene = preload("uid://buktfxd073666")

@onready var command_line: LineEdit = %command_line
@onready var command_output_container: VBoxContainer = %command_output_container
@onready var scroll_container: ScrollContainer = %scroll_container
@onready var path_indicator_label: Label = %path_indicator_label
@onready var tui_overlay_host: Control = get_node_or_null("%tui_overlay_host")

@onready var command_manager := TerminalCommandManager.new()
@onready var input_parser := TerminalInputParser.new()
@onready var input_history_manager := TerminalInputHistoryManager.new(command_line)
@onready var virtual_path_manager := VirtualPathManager.new()

static var _instance_counter: int = 0
var instance_id: int = 0

var parent_window: FakeWindow
var active_interactive_command: TerminalCommand = null

func _ready() -> void:
	_instance_counter += 1
	instance_id = _instance_counter

	# updates the label that indicates the current path when virtual path changes
	virtual_path_manager.on_virtual_path_changes.connect(
		func(_new_virt_path: String) -> void:
			path_indicator_label.text = virtual_path_manager.get_current_folder() + " > "
			update_window_title()
	)

	# Set initial virtual_path
	# Check for focused folder icon first
	if ContextMenu.target is FakeFolder:
		virtual_path_manager.set_path(ContextMenu.target.folder_path)
	# Check for a focused folder window to be the starting path
	elif ContextMenu.target is FileManagerWindow:
		var path: String = ContextMenu.target.file_path

		if virtual_path_manager.path_is_valid_folder(path):
			virtual_path_manager.set_path(path)

	# command_line focus follows window focus
	parent_window = find_parent_window()
	if parent_window != null:
		update_window_title()
		parent_window.selected.connect(
			func(is_selected: bool) -> void:
				if is_selected:
					command_line.call_deferred("grab_focus")
				else:
					command_line.call_deferred("release_focus")
		)


## Updates the title of the hosting FakeWindow to reflect instance ID and active path.
func update_window_title() -> void:
	if parent_window == null:
		parent_window = find_parent_window()
	if parent_window != null:
		var path_str: String = virtual_path_manager.get_current_folder()
		if path_str.is_empty():
			path_str = "~"
		parent_window.title_text = "Terminale Shell UNIX #%d - %s" % [instance_id, path_str]


func _input(event: InputEvent) -> void:
	# command_line focus whenever the user clicks the window
	if event is InputEventMouseButton and event.is_pressed():
		command_line.grab_focus()
		parent_window.select_window(true)


# Create and append a new TerminalCommandOutputLabel to the container
func push_line_to_output(text: String) -> void:
	var new_label: TerminalCommandOutputLabel = COMMAND_OUTPUT_LABEL_SCENE.instantiate()
	command_output_container.add_child(new_label)
	new_label.text = text

	update_scroll()


# Create and append a new TerminalCommandOutputLabel for every element in lines to the container
func push_lines_to_output(lines: Array[String]) -> void:
	for line: String in lines:
		var new_label: TerminalCommandOutputLabel = COMMAND_OUTPUT_LABEL_SCENE.instantiate()
		command_output_container.add_child(new_label)
		new_label.text = line

	update_scroll()


# Appends an interactive Control widget (such as a TerminalUIWidget) to the output stream
func push_widget_to_output(widget: Control) -> void:
	command_output_container.add_child(widget)
	update_scroll()


# Programmatically executes a command as if submitted through the command line
func execute_command(command_line_text: String) -> void:
	_on_command_line_text_submitted(command_line_text)


# Displays a full-view interactive TUI overlay
func open_tui_overlay(overlay_node: Control) -> void:
	if tui_overlay_host == null:
		return
	for child in tui_overlay_host.get_children():
		child.queue_free()
	tui_overlay_host.add_child(overlay_node)
	tui_overlay_host.visible = true


# Closes the active TUI overlay and returns focus to the command line
func close_tui_overlay() -> void:
	if tui_overlay_host == null:
		return
	tui_overlay_host.visible = false
	for child in tui_overlay_host.get_children():
		child.queue_free()
	command_line.call_deferred("grab_focus")


func is_tui_overlay_active() -> bool:
	return tui_overlay_host != null and tui_overlay_host.visible


# Make the container scroll all the way down
# to keep the command input visible
func update_scroll() -> void:
	# Wait a process_frame to update the container correctly
	# if not, the scroll is going to jump to a position before
	# the new label added has changed the container size
	for x in range(3):
		#ALERT "hacky" way, awaiting just one frame can
		# make the problem cited above hapens anyway
		await get_tree().process_frame
	scroll_container.set_deferred("scroll_vertical", scroll_container.get_v_scroll_bar().max_value)


# Just queue_free all the labels
func clear_output() -> void:
	for child: TerminalCommandOutputLabel in command_output_container.get_children():
		child.queue_free()


# Get the FakeWindow that's the terminal is inside
func find_parent_window() -> FakeWindow:
	const MAX_ITERATIONS: int = 1000
	var node: Node = null

	for x: int in range(MAX_ITERATIONS):
		if node == null:
			node = get_parent()
		else:
			node = node.get_parent()

		if node == null:
			break

		if node is FakeWindow and node.is_ancestor_of(self):
			return node

	return null


# Called when the user presses enter with the command line in focus
func _on_command_line_text_submitted(new_text: String) -> void:
	command_line.clear()
	push_line_to_output(virtual_path_manager.get_current_folder() + " > " + new_text)

	# Return early if user input is a empty string
	if new_text.replace(" ", "") == "":
		return

	input_history_manager.push_to_history(new_text)

	if active_interactive_command != null:
		active_interactive_command.handle_interactive_input(self, new_text)
		return

	var parser_outputs: Array[TerminalParserOutput] = input_parser.parse(new_text)
	for output: TerminalParserOutput in parser_outputs:
		var result: Dictionary = command_manager.find_command(output.command_call_name)
		var cmd: TerminalCommand = result.get("command")
		var regex_match: RegExMatch = result.get("regex_match")

		# If not found by call_name, try matching against the raw command string
		if cmd == null and not output.raw_command.is_empty():
			result = command_manager.find_command(output.raw_command)
			cmd = result.get("command")
			regex_match = result.get("regex_match")

		if cmd != null:
			if regex_match != null:
				cmd.execute_regex(self, regex_match, output.raw_args)
			else:
				cmd.execute(self, output.command_args)
		else:
			push_line_to_output("%s not found" % [output.command_call_name])


func _on_command_line_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_TAB:
			_handle_tab_autocomplete()
			command_line.accept_event()
			return

		elif event.keycode == KEY_UP or event.is_action("ui_up") or event.is_action("ui_text_caret_up"):
			command_line.text = input_history_manager.get_next(TerminalInputHistoryManager.DIR.UP)
			command_line.set_deferred("caret_column", command_line.text.length())
			command_line.accept_event()
			return

		elif event.keycode == KEY_DOWN or event.is_action("ui_down") or event.is_action("ui_text_caret_down"):
			command_line.text = input_history_manager.get_next(TerminalInputHistoryManager.DIR.DOWN)
			command_line.set_deferred("caret_column", command_line.text.length())
			command_line.accept_event()
			return


## Handles TAB autocompletion for commands and files/folders.
func _handle_tab_autocomplete() -> void:
	var command_names: Array[String] = command_manager.get_command_call_names()
	var result: Dictionary = TerminalAutoComplete.autocomplete(
		command_line.text,
		command_line.caret_column,
		command_names,
		virtual_path_manager
	)

	if result.get("completed", false):
		command_line.text = result.get("new_text", command_line.text)
		var new_pos: int = result.get("new_caret_position", command_line.text.length())
		command_line.caret_column = new_pos
		command_line.set_deferred("caret_column", new_pos)

	if result.get("is_ambiguous", false):
		var candidates: Array = result.get("candidates", [])
		if not candidates.is_empty():
			var candidates_str: String = ""
			for c in candidates:
				candidates_str += str(c) + "    "
			push_line_to_output(candidates_str.strip_edges())
