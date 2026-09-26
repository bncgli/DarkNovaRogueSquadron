class_name ConfirmDialog
extends FakeWindow

var message: String = ""
var confirm_text: String = "Conferma"
var cancel_text: String = "Annulla"
var on_confirm_callback: Callable
var on_cancel_callback: Callable
var _resolved: bool = false

@onready var message_label: RichTextLabel = %MessageLabel
@onready var confirm_button: Button = %ConfirmButton
@onready var cancel_button: Button = %CancelButton

func setup(p_title: String, p_message: String, on_confirm: Callable, on_cancel: Callable = Callable(), p_confirm_text: String = "Conferma", p_cancel_text: String = "Annulla") -> void:
	title_text = p_title
	message = p_message
	on_confirm_callback = on_confirm
	on_cancel_callback = on_cancel
	confirm_text = p_confirm_text
	cancel_text = p_cancel_text

func _ready() -> void:
	if title_text.is_empty():
		title_text = "Conferma operazione"
	super._ready()
	if message_label:
		message_label.text = "[center]%s[/center]" % message
	if confirm_button:
		confirm_button.text = confirm_text
		confirm_button.pressed.connect(_on_confirm_pressed)
	if cancel_button:
		cancel_button.text = cancel_text
		cancel_button.pressed.connect(_on_cancel_pressed)

func _on_confirm_pressed() -> void:
	_resolved = true
	var cb := on_confirm_callback
	_on_close_button_pressed()
	if cb.is_valid():
		cb.call()

func _on_cancel_pressed() -> void:
	_resolved = true
	var cb := on_cancel_callback
	_on_close_button_pressed()
	if cb.is_valid():
		cb.call()

func _on_close_button_pressed() -> void:
	if not _resolved and on_cancel_callback.is_valid():
		_resolved = true
		on_cancel_callback.call()
	super._on_close_button_pressed()

static func show_dialog(tree: SceneTree, title: String, msg: String, on_confirm: Callable, on_cancel: Callable = Callable(), confirm_label: String = "Conferma", cancel_label: String = "Annulla") -> ConfirmDialog:
	if tree == null:
		if on_confirm.is_valid():
			on_confirm.call()
		return null
	var scene: PackedScene = load("res://Scenes/Window/Confirm Dialog/confirm_dialog.tscn")
	var dlg: ConfirmDialog = scene.instantiate() as ConfirmDialog
	dlg.setup(title, msg, on_confirm, on_cancel, confirm_label, cancel_label)
	var root := tree.current_scene if tree.current_scene else tree.root
	root.add_child(dlg)
	return dlg
