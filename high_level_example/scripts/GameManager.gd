extends Node

var scores = {}
signal score_updated(id_jugador, puntos_nuevos)

# --- NUEVA SEÑAL DE FIN DE JUEGO ---
signal game_over(winner_id)

func add_point(player_id) -> int: # Ahora devuelve un int (puntos)
	var id = str(player_id)
	if not scores.has(id):
		scores[id] = 0
	
	scores[id] += 1
	score_updated.emit(id, scores[id])
	
	return scores[id] # Devolvemos el valor para comprobarlo


# --- NUEVO: CLASE SELECCIONADA ---
# Guardaremos la RUTA del archivo .tres (es lo más fácil para sincronizar)
# Pon aquí la ruta de tu clase por defecto (ej: Asalto)
var selected_class_path: String = "res://high_level_example/Classes/ClasePipero.tres" 

# ... (resto de funciones add_point, etc) ...
