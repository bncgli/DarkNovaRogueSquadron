extends Node

func _ready() -> void:
	print("--- AVVIO TEST HEADLESS RBAC START MENU FILTER ---")
	_run.call_deferred()

func _run() -> void:
	await get_tree().process_frame
	var success := TestRBACStartMenuFilter.run_all_tests(self)
	await get_tree().process_frame
	if success:
		print("\n=======================================================")
		print(" TUTTI I TEST RBAC START MENU SUPERATI CON SUCCESSO! [OK]")
		print("=======================================================")
		get_tree().quit(0)
	else:
		print("\n❌ ALCUNI TEST RBAC START MENU SONO FALLITI!")
		get_tree().quit(1)
