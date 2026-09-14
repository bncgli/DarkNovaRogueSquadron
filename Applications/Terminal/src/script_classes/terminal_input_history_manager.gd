class_name TerminalInputHistoryManager
## Utility class to handle input history navigation and draft preservation.

## The navigation direction
enum DIR {
	UP,   ## Past / older commands
	DOWN  ## Present / newer commands and current draft
}

## The maximum number of inputs saved in history.
var max_history_size: int = 50

## Chronological list of user commands (oldest at index 0, newest at back).
var _history: Array[String] = []

## Navigation pointer in history. Equals _history.size() when pointing to current draft.
var _history_index: int = 0

## The draft text typed by the user before starting history navigation.
var _current_draft: String = ""

## Reference to the terminal LineEdit.
var cmd_line: LineEdit = null


func _init(command_line: LineEdit, max_size: int = 50) -> void:
	cmd_line = command_line
	max_history_size = max_size
	_history_index = 0
	_current_draft = ""


## Adds a submitted command to history.
## Ignores empty commands and consecutive duplicates.
func push_to_history(input: String) -> void:
	var trimmed: String = input.strip_edges()
	if trimmed.is_empty():
		return
	
	if not _history.is_empty() and _history.back() == trimmed:
		# Don't add duplicate of previous command, just reset index
		_history_index = _history.size()
		_current_draft = ""
		return
	
	_history.append(trimmed)
	if _history.size() > max_history_size:
		_history.pop_front()
	
	_history_index = _history.size()
	_current_draft = ""


## Updates index based on direction and returns the command or draft.
func get_next(dir: DIR) -> String:
	if _history.is_empty():
		return cmd_line.text if cmd_line != null else ""
	
	# If starting navigation from the bottom (draft position), save draft
	if _history_index == _history.size() and dir == DIR.UP:
		_current_draft = cmd_line.text if cmd_line != null else ""
	
	if dir == DIR.UP:
		if _history_index > 0:
			_history_index -= 1
		return _history[_history_index]
	
	elif dir == DIR.DOWN:
		if _history_index < _history.size() - 1:
			_history_index += 1
			return _history[_history_index]
		else:
			_history_index = _history.size()
			return _current_draft
	
	return ""


## Returns all history entries.
func get_history() -> Array[String]:
	return _history.duplicate()


## Clears all history entries and resets navigation.
func clear_history() -> void:
	_history.clear()
	_history_index = 0
	_current_draft = ""


## Returns the active draft.
func get_current_draft() -> String:
	return _current_draft
