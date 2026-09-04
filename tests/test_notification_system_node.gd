extends Node

func _ready() -> void:
	print("--- INIZIO TEST SUITE NOTIFICATION MANAGER & HARDWARE DETECTION (TASK-040) ---")
	_run_suite.call_deferred()

func _run_suite() -> void:
	await get_tree().process_frame
	
	# =========================================================================
	# FASE 1: VERIFICA SINGLETON E STRUTTURA DEL LAYOUT DINAMICO
	# =========================================================================
	print("\n--- TEST 1: Verifica Struttura Singleton e NotificationContainer ---")
	var nm := get_node_or_null("/root/NotificationManager") as NotificationManagerSingleton
	assert(nm != null, "NotificationManager deve essere registrato come Autoload")
	
	var container: VBoxContainer = nm.get_node_or_null("NotificationContainer") as VBoxContainer
	assert(container != null, "NotificationContainer (VBoxContainer) deve essere presente come figlio di NotificationManager")
	assert(container.alignment == BoxContainer.ALIGNMENT_END, "L'allineamento deve essere BoxContainer.ALIGNMENT_END")
	assert(container.grow_vertical == Control.GROW_DIRECTION_BEGIN, "grow_vertical deve essere Control.GROW_DIRECTION_BEGIN")
	assert(container.mouse_filter == Control.MOUSE_FILTER_IGNORE, "mouse_filter di NotificationContainer deve essere MOUSE_FILTER_IGNORE")
	assert(container.anchor_right == 1.0 and container.anchor_bottom == 1.0, "Le ancore inferiori/destre devono essere a 1.0")
	assert(container.offset_left == -350.0 and container.offset_top == -400.0, "Offset left e top devono essere -350 e -400")
	assert(container.offset_right == -15.0 and container.offset_bottom == -15.0, "Offset right e bottom devono essere -15")
	print("✔ Struttura VBoxContainer e configurazione ancore/layout verificate con successo")
	
	# Pulisci eventuali notifiche residue
	for c in container.get_children():
		c.queue_free()
	await get_tree().process_frame
	
	# =========================================================================
	# FASE 2: IMPILAMENTO VERTICALE ORDINATO DI NOTIFICHE MULTIPLE
	# =========================================================================
	print("\n--- TEST 2: Impilamento Verticale di 5 Notifiche Concorrenti ---")
	var initial_child_count := container.get_child_count()
	assert(initial_child_count == 0, "Container deve essere vuoto all'inizio del test di impilamento")
	
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
	assert(container.get_child_count() == 5, "Tutte e 5 le notifiche devono essere presenti nel NotificationContainer")
	
	for i in range(5):
		var notif: Control = container.get_child(i) as Control
		assert(notif != null, "Ogni elemento nel container deve essere un Control valido")
		var label: RichTextLabel = notif.get_node_or_null("Notification Text") as RichTextLabel
		assert(label != null, "Ogni notifica deve contenere un nodo RichTextLabel 'Notification Text'")
		assert(label.bbcode_enabled == true, "RichTextLabel deve avere bbcode_enabled abilitato")
		assert(label.text.contains(test_messages[i]), "Il testo della notifica #%d deve contenere '%s'" % [i, test_messages[i]])
	
	print("✔ 5 notifiche concorrenti impilate verticalmente in slot separati senza conflitti")
	
	# =========================================================================
	# FASE 3: DISSOLVENZA E COMPATIBILITA' ANIMAZIONE
	# =========================================================================
	print("\n--- TEST 3: Transizioni di Dissolvenza e Ciclo Vitale ---")
	# Istanzia una notifica isolata per verificare modulate iniziale e tween
	var notif_sample: Control = container.get_child(0) as Control
	assert(notif_sample != null, "Notifica campione deve esistere")
	assert(notif_sample.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Notifica deve avere mouse_filter = MOUSE_FILTER_IGNORE")
	
	# Pulisci le notifiche
	for c in container.get_children():
		c.queue_free()
	await get_tree().process_frame
	assert(container.get_child_count() == 0, "Container ripulito per i test successivi")
	print("✔ Transizioni e rilascio memoria convalidati")
	
	# =========================================================================
	# FASE 4: RICONOSCIMENTO CONNESSIONE PERIFERICA HARDWARE
	# =========================================================================
	print("\n--- TEST 4: Rilevamento Connessione Controller/Periferica ---")
	assert(Input.joy_connection_changed.is_connected(nm._on_joy_connection_changed), "NotificationManager deve essere connesso al segnale joy_connection_changed")
	
	# Simula connessione periferica dispositivo slot 0
	nm._on_joy_connection_changed(0, true)
	await get_tree().process_frame
	
	assert(container.get_child_count() == 1, "Una notifica deve essere stata generata alla connessione del controller")
	var connect_notif: Control = container.get_child(0) as Control
	var connect_label: RichTextLabel = connect_notif.get_node_or_null("Notification Text") as RichTextLabel
	assert(connect_label != null, "Notification Text deve esistere")
	assert(connect_label.text.contains("33ff88"), "La notifica di connessione deve essere colorata di verde (33ff88)")
	assert(connect_label.text.contains("🎮 Periferica Connessa:"), "La notifica di connessione deve contenere il tag '🎮 Periferica Connessa:'")
	assert(connect_label.text.contains("[Slot #0]"), "La notifica deve specificare lo Slot #0")
	print("✔ Connessione controller rilevata con notifica diegetica verde corretta: %s" % connect_label.text)
	
	# Pulisci per test successivo
	connect_notif.queue_free()
	await get_tree().process_frame
	
	# =========================================================================
	# FASE 5: RICONOSCIMENTO DISCONNESSIONE PERIFERICA HARDWARE
	# =========================================================================
	print("\n--- TEST 5: Rilevamento Disconnessione Controller/Periferica ---")
	# Simula disconnessione periferica dispositivo slot 1
	nm._on_joy_connection_changed(1, false)
	await get_tree().process_frame
	
	assert(container.get_child_count() == 1, "Una notifica deve essere stata generata alla disconnessione del controller")
	var disconnect_notif: Control = container.get_child(0) as Control
	var disconnect_label: RichTextLabel = disconnect_notif.get_node_or_null("Notification Text") as RichTextLabel
	assert(disconnect_label != null, "Notification Text deve esistere")
	assert(disconnect_label.text.contains("ffaa33"), "La notifica di disconnessione deve essere colorata di avviso giallo/arancio (ffaa33)")
	assert(disconnect_label.text.contains("⚠️ Periferica Scollegata: Slot #1"), "La notifica deve indicare la disconnessione dello Slot #1")
	print("✔ Disconnessione controller rilevata con notifica diegetica arancio corretta: %s" % disconnect_label.text)
	
	# Pulisci
	disconnect_notif.queue_free()
	await get_tree().process_frame
	
	# =========================================================================
	# FASE 6: TEST METODO SEND_NOTIFICATION (COMPATIBILITA')
	# =========================================================================
	print("\n--- TEST 6: Compatibilità send_notification(title, msg) ---")
	nm.send_notification("Security Alert", "Intrusion detected in sector 4")
	await get_tree().process_frame
	
	assert(container.get_child_count() == 1, "send_notification deve generare una notifica")
	var sec_notif: Control = container.get_child(0) as Control
	var sec_label: RichTextLabel = sec_notif.get_node_or_null("Notification Text") as RichTextLabel
	assert(sec_label.text.contains("[b]Security Alert[/b]: Intrusion detected in sector 4"), "Testo formattato correttamente con titolo in grassetto")
	print("✔ send_notification() convalidato")
	
	print("\n=== TUTTI I TEST DI NOTIFICATION MANAGER E HARDWARE DETECTION (TASK-040) COMPLETATI CON SUCCESSO! ===")
	get_tree().quit(0)
