extends Control
class_name NotificationManagerSingleton

## Spawns notifications in the bottom right of the screen.
## Often used to show errors or file actions (copying, pasting).

static var instance: NotificationManagerSingleton

const notification_scene: PackedScene = preload("res://Scenes/Autoloads/Notification Manager/notification.tscn")

func _enter_tree() -> void:
	instance = self

static func spawn_notification(text: String) -> void:
	if instance:
		instance._spawn_notification_internal(text)

func _spawn_notification_internal(text: String) -> void:
	var new_notification: Control = notification_scene.instantiate()
	new_notification.get_node("Notification Text").text = "[center]%s" % text
	add_child(new_notification)
