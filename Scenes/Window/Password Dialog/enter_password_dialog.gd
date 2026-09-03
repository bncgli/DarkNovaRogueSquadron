extends FakeWindow

var folder_path: String
var folder_name: String
var on_success_callback: Callable
var on_cancel_callback: Callable
var _resolved: bool = false

@onready var password_edit: LineEdit = %PasswordEdit
@onready var error_label: Label = %ErrorLabel
@onready var ok_button: Button = %OkButton
@onready var ok_remove_button: Button = %OkRemoveButton
@onready var cancel_button: Button = %CancelButton
@onready var info_label: RichTextLabel = %InfoLabel

func setup(p_path: String, p_name: String, on_success: Callable, on_cancel: Callable = Callable()) -> void:
	folder_path = p_path
	folder_name = p_name
	on_success_callback = on_success
	on_cancel_callback = on_cancel
	title_text = "Cartella protetta"

func _ready() -> void:
	if title_text.is_empty():
		title_text = "Cartella protetta"
	super._ready()
	info_label.text = "[center]Questa cartella e' protetta da password.\nInserisci la password per [b]%s[/b]:[/center]" % folder_name
	error_label.text = ""
	password_edit.grab_focus()
	password_edit.text_submitted.connect(func(_t: String) -> void: _on_ok_pressed())
	ok_button.pressed.connect(_on_ok_pressed)
	ok_remove_button.pressed.connect(_on_ok_remove_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)

func _on_ok_pressed() -> void:
	var input_pass := password_edit.text
	var fpm := get_node_or_null("/root/FolderPasswordManager")
	var is_valid := true
	if fpm:
		is_valid = fpm.check_password(folder_path, input_pass)
	
	if is_valid:
		_resolved = true
		var cb := on_success_callback
		_on_close_button_pressed()
		if cb.is_valid():
			cb.call(false)
	else:
		error_label.text = "Password errata!"
		password_edit.grab_focus()
		password_edit.select_all()

func _on_ok_remove_pressed() -> void:
	var input_pass := password_edit.text
	var fpm := get_node_or_null("/root/FolderPasswordManager")
	var is_valid := true
	if fpm:
		is_valid = fpm.check_password(folder_path, input_pass)
	
	if is_valid:
		_resolved = true
		if fpm:
			fpm.remove_password(folder_path)
		NotificationManagerSingleton.spawn_notification("Password rimossa per [color=59ea90]%s[/color]." % folder_name)
		var cb := on_success_callback
		_on_close_button_pressed()
		if cb.is_valid():
			cb.call(true)
	else:
		error_label.text = "Password errata!"
		password_edit.grab_focus()
		password_edit.select_all()

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
