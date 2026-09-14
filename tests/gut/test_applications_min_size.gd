extends GutTest

func test_all_registered_apps_have_fitting_min_window_size():
	var all_apps: Array[AppResource] = SoftwareManager.get_all_installed_apps()
	assert_gt(all_apps.size(), 0, "Dovrebbero esserci applicazioni installate/registrate.")
	
	for app in all_apps:
		var app_id: String = app.app_id
		assert_gt(app.min_window_size.x, 0.0, "App %s deve avere min_window_size.x > 0" % app_id)
		assert_gt(app.min_window_size.y, 0.0, "App %s deve avere min_window_size.y > 0" % app_id)
		assert_gte(app.default_window_size.x, app.min_window_size.x, "App %s default_window_size.x deve essere >= min_window_size.x" % app_id)
		assert_gte(app.default_window_size.y, app.min_window_size.y, "App %s default_window_size.y deve essere >= min_window_size.y" % app_id)
		
		# Verifica che min_window_size sia coerente con l'effettiva UI dell'applicazione
		var scn := app.get_effective_scene()
		if scn:
			var inst = scn.instantiate()
			if inst is Control:
				var c := inst as Control
				# Se il nodo radice della scena ha una custom_minimum_size, la finestra deve includerla (+30px di top bar)
				if c.custom_minimum_size != Vector2.ZERO:
					assert_gte(app.min_window_size.x, c.custom_minimum_size.x, "App %s min_window_size.x (%s) deve contenere la custom_minimum_size.x (%s)" % [app_id, app.min_window_size.x, c.custom_minimum_size.x])
					assert_gte(app.min_window_size.y, c.custom_minimum_size.y + 30.0, "App %s min_window_size.y (%s) deve contenere la custom_minimum_size.y + 30px (%s)" % [app_id, app.min_window_size.y, c.custom_minimum_size.y + 30.0])
			inst.free()

func test_launch_app_sets_window_sizes():
	var win: FakeWindow = ShipSoftwareManager.launch_app("cams")
	if win:
		assert_not_null(win)
		assert_gte(win.custom_minimum_size.x, 520.0, "La finestra di Cams deve avere min size X >= 520")
		assert_gte(win.custom_minimum_size.y, 530.0, "La finestra di Cams deve avere min size Y >= 530")
		assert_gte(win.size.x, win.custom_minimum_size.x, "La dimensione iniziale X deve essere >= custom_minimum_size.x")
		assert_gte(win.size.y, win.custom_minimum_size.y, "La dimensione iniziale Y deve essere >= custom_minimum_size.y")
		win.queue_free()
