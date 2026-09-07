extends GutTest

## Migrato dal vecchio test manuale tests/test_notification_system_node.gd
## (TASK-040). Verifica il singleton NotificationManager, la struttura del
## layout del NotificationContainer, l'impilamento verticale di notifiche
## multiple, e il riconoscimento di connessione/disconnessione di
## periferiche hardware (joypad).

var nm: NotificationManagerSingleton
var container: VBoxContainer

func before_each() -> void:
	nm = get_node_or_null("/root/NotificationManager") as NotificationManagerSingleton
	container = nm.get_node_or_null("NotificationContainer") as VBoxContainer
	for c in container.get_children():
		c.queue_free()
	await get_tree().process_frame

func test_singleton_and_notification_container_structure() -> void:
	assert_not_null(nm, "NotificationManager deve essere registrato come Autoload")
	assert_not_null(container, "NotificationContainer (VBoxContainer) deve essere presente come figlio di NotificationManager")
	assert_eq(container.alignment, BoxContainer.ALIGNMENT_END, "L'allineamento deve essere BoxContainer.ALIGNMENT_END")
	assert_eq(container.grow_vertical, Control.GROW_DIRECTION_BEGIN, "grow_vertical deve essere Control.GROW_DIRECTION_BEGIN")
	assert_eq(container.mouse_filter, Control.MOUSE_FILTER_IGNORE, "mouse_filter di NotificationContainer deve essere MOUSE_FILTER_IGNORE")
	assert_eq(container.anchor_right, 1.0, "L'ancora destra deve essere a 1.0")
	assert_eq(container.anchor_bottom, 1.0, "L'ancora inferiore deve essere a 1.0")
	assert_eq(container.offset_left, -350.0, "offset_left deve essere -350")
	assert_eq(container.offset_top, -400.0, "offset_top deve essere -400")
	assert_eq(container.offset_right, -15.0, "offset_right deve essere -15")
	assert_eq(container.offset_bottom, -15.0, "offset_bottom deve essere -15")

func test_multiple_notifications_stack_vertically() -> void:
	assert_eq(container.get_child_count(), 0, "Il container deve essere vuoto all'inizio del test di impilamento")

	var test_messages := [
		"Notifica 1 - Alpha",
		"Notifica 2 - Bravo",
		"Notifica 3 - Charlie",
		"Notifica 4 - Delta",
		"Notifica 5 - Echo"
	]

	for msg in test_messages:
		NotificationManagerSingleton.spawn_notification(msg)

	await get_tree().process_frame
	assert_eq(container.get_child_count(), 5, "Tutte e 5 le notifiche devono essere presenti nel NotificationContainer")

	for i in range(5):
		var notif: Control = container.get_child(i) as Control
		assert_not_null(notif, "Ogni elemento nel container deve essere un Control valido")
		var label: RichTextLabel = notif.get_node_or_null("Notification Text") as RichTextLabel
		assert_not_null(label, "Ogni notifica deve contenere un nodo RichTextLabel 'Notification Text'")
		assert_true(label.bbcode_enabled, "RichTextLabel deve avere bbcode_enabled abilitato")
		assert_true(label.text.contains(test_messages[i]), "Il testo della notifica #%d deve contenere '%s'" % [i, test_messages[i]])

func test_notification_control_has_mouse_filter_ignore() -> void:
	NotificationManagerSingleton.spawn_notification("Notifica campione")
	await get_tree().process_frame

	var notif_sample: Control = container.get_child(0) as Control
	assert_not_null(notif_sample, "Notifica campione deve esistere")
	assert_eq(notif_sample.mouse_filter, Control.MOUSE_FILTER_IGNORE, "La notifica deve avere mouse_filter = MOUSE_FILTER_IGNORE")

func test_joystick_connection_produces_green_notification() -> void:
	assert_true(Input.joy_connection_changed.is_connected(nm._on_joy_connection_changed), "NotificationManager deve essere connesso al segnale joy_connection_changed")

	# Simula la connessione di una periferica nello slot 0
	nm._on_joy_connection_changed(0, true)
	await get_tree().process_frame

	assert_eq(container.get_child_count(), 1, "Una notifica deve essere stata generata alla connessione del controller")
	var connect_notif: Control = container.get_child(0) as Control
	var connect_label: RichTextLabel = connect_notif.get_node_or_null("Notification Text") as RichTextLabel
	assert_not_null(connect_label, "Notification Text deve esistere")
	assert_true(connect_label.text.contains("33ff88"), "La notifica di connessione deve essere colorata di verde (33ff88)")
	assert_true(connect_label.text.contains("🎮 Periferica Connessa:"), "La notifica di connessione deve contenere il tag '🎮 Periferica Connessa:'")
	assert_true(connect_label.text.contains("[Slot #0]"), "La notifica deve specificare lo Slot #0")

func test_joystick_disconnection_produces_orange_notification() -> void:
	# Simula la disconnessione di una periferica nello slot 1
	nm._on_joy_connection_changed(1, false)
	await get_tree().process_frame

	assert_eq(container.get_child_count(), 1, "Una notifica deve essere stata generata alla disconnessione del controller")
	var disconnect_notif: Control = container.get_child(0) as Control
	var disconnect_label: RichTextLabel = disconnect_notif.get_node_or_null("Notification Text") as RichTextLabel
	assert_not_null(disconnect_label, "Notification Text deve esistere")
	assert_true(disconnect_label.text.contains("ffaa33"), "La notifica di disconnessione deve essere colorata di avviso giallo/arancio (ffaa33)")
	assert_true(disconnect_label.text.contains("⚠️ Periferica Scollegata: Slot #1"), "La notifica deve indicare la disconnessione dello Slot #1")

func test_send_notification_formats_title_in_bold() -> void:
	nm.send_notification("Security Alert", "Intrusion detected in sector 4")
	await get_tree().process_frame

	assert_eq(container.get_child_count(), 1, "send_notification deve generare una notifica")
	var sec_notif: Control = container.get_child(0) as Control
	var sec_label: RichTextLabel = sec_notif.get_node_or_null("Notification Text") as RichTextLabel
	assert_true(sec_label.text.contains("[b]Security Alert[/b]: Intrusion detected in sector 4"), "Testo formattato correttamente con titolo in grassetto")
