extends PanelContainer

func _ready() -> void:
	play_animation()

func play_animation() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.25)
	
	await get_tree().create_timer(3.5).timeout
	if not is_inside_tree():
		return
	var fade := create_tween()
	await fade.tween_property(self, "modulate:a", 0.0, 0.5).finished
	queue_free()
