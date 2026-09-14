extends GutTest

func test_star_system_editor_instantiation_and_rendering():
	var scn = load("res://addons/star_system_editor/star_system_editor.tscn")
	assert_not_null(scn, "La scena star_system_editor.tscn deve caricarsi con successo")
	
	var editor: StarSystemEditor = scn.instantiate()
	assert_not_null(editor, "L'editor deve potersi istanziare")
	add_child_autofree(editor)
	
	await wait_frames(2)
	
	# Verifica che current_system e canvas siano attivi e inizializzati
	assert_not_null(editor.current_system, "current_system deve essere popolato")
	assert_gt(editor.current_system.celestial_bodies.size(), 0, "Dovrebbero esserci corpi celesti predefiniti")
	
	var canvas: StarSystemCanvas = editor.get_node("%Canvas")
	assert_not_null(canvas, "Canvas deve esistere")
	assert_not_null(canvas.system_data, "Canvas deve avere system_data assegnato")
	
	# Verifica reset_view e ridimensionamento
	canvas.size = Vector2(1000, 700)
	canvas.reset_view()
	assert_eq(canvas.pan_offset, Vector2(500, 350), "Pan offset deve essere centrato dopo reset_view")
	
	canvas.notification(CanvasItem.NOTIFICATION_DRAW)
	await wait_frames(1)

func test_star_system_editor_body_operations():
	var scn = load("res://addons/star_system_editor/star_system_editor.tscn")
	var editor: StarSystemEditor = scn.instantiate()
	add_child_autofree(editor)
	await wait_frames(2)
	
	var initial_count = editor.current_system.celestial_bodies.size()
	
	# Aggiunta di vari tipi di corpi celesti
	editor._add_celestial_body("PLANET")
	assert_eq(editor.current_system.celestial_bodies.size(), initial_count + 1, "Dovrebbe essere stato aggiunto un pianeta")
	
	var new_body: CelestialBodyData = editor.current_system.celestial_bodies[-1]
	assert_eq(new_body.type, "PLANET")
	
	# Spostamento tramite coordinate
	var old_coords = new_body.coords
	var target_coords = old_coords + Vector3i(2, 3, 0)
	editor._on_canvas_entity_moved(new_body.id, old_coords, target_coords)
	assert_eq(new_body.coords, target_coords, "Le coordinate dovrebbero essere aggiornate")
	
	# Test Undo dello spostamento
	editor.undo_redo.undo()
	assert_eq(new_body.coords, old_coords, "Le coordinate dovrebbero essere tornate indietro dopo undo")
	
	# Test Redo dello spostamento
	editor.undo_redo.redo()
	assert_eq(new_body.coords, target_coords, "Le coordinate dovrebbero essere ripristinate dopo redo")
	
	# Eliminazione corpo celeste
	editor._delete_body(new_body.id)
	assert_eq(editor.current_system.celestial_bodies.size(), initial_count, "Il corpo aggiunto dovrebbe essere stato rimosso")
	
	# Undo dell'eliminazione
	editor.undo_redo.undo()
	assert_eq(editor.current_system.celestial_bodies.size(), initial_count + 1, "Il corpo dovrebbe essere ripristinato dopo undo di eliminazione")

func test_star_system_editor_plugin_and_load():
	var scn = load("res://addons/star_system_editor/star_system_editor.tscn")
	var editor: StarSystemEditor = scn.instantiate()
	add_child_autofree(editor)
	await wait_frames(2)
	
	var default_sys = StarSystemData.new()
	default_sys.create_default_system()
	default_sys.system_id = "TEST-SYS"
	default_sys.system_name = "Test System"
	editor.load_star_system(default_sys, "res://test_path.tres")
	
	assert_eq(editor.current_system.system_id, "TEST-SYS")
	assert_eq(editor.canvas.system_data, default_sys)
	assert_gt(editor.current_system.celestial_bodies.size(), 0)

func test_star_system_editor_generate_random_system():
	var scn = load("res://addons/star_system_editor/star_system_editor.tscn")
	var editor: StarSystemEditor = scn.instantiate()
	add_child_autofree(editor)
	await wait_frames(2)
	
	# Verifica presenza e abilitazione del pulsante BtnRandom
	var btn_random = editor.get_node("%BtnRandom")
	assert_not_null(btn_random, "Il pulsante BtnRandom deve esistere nella scena")
	assert_eq(editor.btn_random, btn_random, "Il riferimento @onready btn_random deve puntare a %BtnRandom")
	assert_false(btn_random.disabled, "Il pulsante BtnRandom deve essere abilitato")
	
	# Test di annullamento (Cancel su ConfirmDialog)
	var initial_sys = editor.current_system
	editor._on_btn_random_pressed()
	assert_eq(editor._pending_file_action, "random", "_pending_file_action deve essere 'random'")
	assert_true(editor.confirm_dialog.dialog_text.contains("casuale"), "Il confirm_dialog deve contenere testo di avviso")
	# Annullamento senza confirm
	editor._pending_file_action = ""
	assert_eq(editor.current_system, initial_sys, "current_system non deve cambiare se l'azione viene annullata")
	
	# Generazione casuale con conferma
	editor._on_btn_random_pressed()
	editor._on_confirm_dialog_confirmed()
	await wait_frames(2)
	
	# Verifiche su current_system
	var sys: StarSystemData = editor.current_system
	assert_not_null(sys, "current_system deve essere valorizzato dopo la generazione casuale")
	assert_ne(sys, initial_sys, "current_system deve essere una nuova istanza")
	assert_true(sys.system_id.begins_with("SYS-RAND-"), "L'ID del sistema deve avere prefisso SYS-RAND-")
	assert_not_null(sys.find_primary_station(), "Il sistema generato deve contenere una stazione spaziale primaria")
	
	var has_star := false
	var has_planet := false
	for body in sys.celestial_bodies:
		if body.type == "STAR":
			has_star = true
		elif body.type == "PLANET":
			has_planet = true
	
	assert_true(has_star, "Il sistema deve contenere una stella primaria")
	assert_true(has_planet, "Il sistema deve contenere almeno un pianeta")
	assert_gt(sys.celestial_bodies.size(), 3, "Il sistema deve avere molteplici corpi celesti")
	
	# Verifiche Canvas, Outliner e StatusBar/Label
	assert_eq(editor.canvas.system_data, sys, "canvas.system_data deve puntare al nuovo sistema")
	assert_true(editor.lbl_current_file.text.contains("non salvato"), "lbl_current_file deve indicare che il sistema non è salvato")
	assert_true(editor.lbl_current_file.text.contains(sys.system_name), "lbl_current_file deve contenere il nome del nuovo sistema")
	assert_not_null(editor.outliner_tree.get_root(), "L'outliner deve avere un nodo radice popolato")
	assert_gt(editor.outliner_tree.get_root().get_child_count(), 0, "L'albero outliner deve contenere nodi popolati")
