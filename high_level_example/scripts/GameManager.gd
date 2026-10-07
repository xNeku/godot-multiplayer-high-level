extends Node
# Autoload. Los puntos los calcula el servidor y se envían a todos los peers.

signal score_updated(id_jugador, puntos_nuevos)

var scores: Dictionary = {}

# Mapa elegido en el menú (ruta de la escena). Vacío = el que tenga la escena de juego.
var selected_map_path: String = ""


# Solo se llama en el servidor. Devuelve los puntos del jugador.
func add_point(player_id) -> int:
	var id := str(player_id)
	var points: int = scores.get(id, 0) + 1
	_sync_score.rpc(id, points)
	return points


@rpc("authority", "call_local", "reliable")
func _sync_score(id: String, points: int) -> void:
	scores[id] = points
	score_updated.emit(id, points)


# Se llama en todos los peers al empezar partida
func reset_scores() -> void:
	scores.clear()


# Punto de aparición aleatorio. Cada mapa tiene Marker2D en el grupo "spawn_points".
func get_spawn_position() -> Vector2:
	var points := get_tree().get_nodes_in_group("spawn_points")
	if points.is_empty():
		return Vector2(randf_range(100, 1100), randf_range(100, 500))
	return (points.pick_random() as Node2D).global_position
