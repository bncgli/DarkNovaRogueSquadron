extends GutTest

## Test di prova (smoke test) per verificare che l'installazione di GUT funzioni
## correttamente in questo progetto, prima di iniziare la migrazione dei test
## esistenti dal vecchio pattern basato su assert() nudo.

func test_gut_is_working() -> void:
	assert_true(true, "GUT deve poter eseguire un assert_true elementare")

func test_basic_math() -> void:
	assert_eq(2 + 2, 4, "2 + 2 deve fare 4")

func test_failure_detection_is_reliable() -> void:
	# Verifica che GUT segnali correttamente successi/fallimenti in modo affidabile.
	# NOTA: questa asserzione è stata volutamente forzata a fallire durante la
	# verifica manuale (assert_eq(1, 2, ...)) e GUT ha correttamente riportato
	# "1 failing tests" con exit code 1, a differenza di assert() nudo che in
	# passato falliva silenziosamente in headless senza debugger collegato.
	assert_eq(1, 1, "Confermato: GUT rileva e riporta i fallimenti in modo affidabile")

func test_can_access_project_autoload() -> void:
	# Verifica che un autoload reale del progetto sia raggiungibile dal contesto
	# di test, per confermare che GUT ha accesso al SceneTree del progetto.
	var flux_manager: Node = get_node_or_null("/root/FluxEconomyManager")
	assert_not_null(flux_manager, "L'autoload FluxEconomyManager deve essere raggiungibile durante i test GUT")
