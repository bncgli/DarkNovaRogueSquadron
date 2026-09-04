extends Control
class_name NotificationManagerSingleton

## Spawns notifications in the bottom right of the screen.
## Often used to show errors or file actions (copying, pasting).

static var instance: NotificationManagerSingleton

const notification_scene: PackedScene = preload("res://Scenes/Autoloads/Notification Manager/notification.tscn")

@onready var notification_container: VBoxContainer = %NotificationContainer

func _enter_tree() -> void:
	instance = self

func _ready() -> void:
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_joy_connection_changed)

func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	if connected:
		var joy_name := Input.get_joy_name(device_id)
		var msg := "[color=33ff88]🎮 Periferica Connessa: %s [Slot #%d][/color]" % [joy_name, device_id]
		spawn_notification(msg)
	else:
		var msg := "[color=ffaa33]⚠️ Periferica Scollegata: Slot #%d[/color]" % [device_id]
		spawn_notification(msg)

static func spawn_notification(text: String) -> void:
	if instance:
		instance._spawn_notification_internal(text)

func send_notification(title: String, msg: String) -> void:
	spawn_notification("[b]%s[/b]: %s" % [title, msg])

func _spawn_notification_internal(text: String) -> void:
	var container: Node = notification_container
	if not container:
		container = get_node_or_null("%NotificationContainer")
	if not container:
		container = get_node_or_null("NotificationContainer")
	if not container:
		container = self
	
	var new_notification: Control = notification_scene.instantiate()
	var label: RichTextLabel = new_notification.get_node_or_null("Notification Text") as RichTextLabel
	if label:
		label.text = "[center]%s" % text
	container.add_child(new_notification)
