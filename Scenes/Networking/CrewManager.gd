extends Node
class_name CrewManager

## Gestore della ciurma e dei ruoli dei giocatori.
## Estratto da NetworkManager.

signal player_role_changed(player_id: int, old_role: String, new_role: String)

var players: Dictionary = {} # peer_id -> Dictionary

func set_player_role(peer_id: int, role: String) -> void:
	if peer_id in players:
		var old_role: Variant = players[peer_id].get("role")
		players[peer_id]["role"] = role
		player_role_changed.emit(peer_id, old_role, role)

func get_player_role(peer_id: int) -> String:
	return players.get(peer_id, {}).get("role", "")

func get_local_player_roles() -> Array[String]:
	return [get_player_role(multiplayer.get_unique_id())]

func add_player(peer_id: int, data: Dictionary) -> void:
	players[peer_id] = data

func remove_player(peer_id: int) -> void:
	players.erase(peer_id)
