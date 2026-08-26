extends FakeWindow

var folder_path: String
var folder_name: String

@onready var password_edit: LineEdit = %PasswordEdit
@onready var error_label: Label = %ErrorLabel
@onready var ok_button: Button = %OkButton
@onready var cancel_button: Button = %CancelButton
@onready var info_label: RichTextLabel = %InfoLabel

func setup(p_path: String, p_name: String) -> void:
	folder_path = p_path
	folder_name = p_name
	title_text = "Aggiungi password"

func _ready() -> void:
	if title_text.is_empty():
		title_text = "Aggiungi password"
	super._ready()
	info_label.text = "[center]Imposta una password per la cartella:\n[b]%s[/b][/center]" % folder_name
	error_label.text = ""
	password_edit.grab_focus()
	password_edit.text_submitted.connect(func(_t: String) -> void: _on_ok_pressed())
	ok_button.pressed.connect(_on_ok_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)

func _on_ok_pressed() -> void:
	var new_pass := password_edit.text.strip_edges()
	if new_pass.is_empty():
		error_label.text = "La password non puo' essere vuota!"
		return
	
	var fpm := get_node_or_null("/root/FolderPasswordManager")
	if fpm:
		if fpm.has_password(folder_path):
			error_label.text = "La cartella ha gia' una password!"
			return
		fpm.set_password(folder_path, new_pass)
	NotificationManager.spawn_notification("Password impostata per [color=59ea90]%s[/color]!" % folder_name)
	_on_close_button_pressed()

func _on_cancel_pressed() -> void:
	_on_close_button_pressed()
