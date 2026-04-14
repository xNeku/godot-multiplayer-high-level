extends Label

func _ready():
	text = "Puntos: Espere..."
	# Conectamos con la señal del Autoload
	GameManager.score_updated.connect(update_score_text)

func update_score_text(id, points):
	# Esto es muy básico, luego lo haremos más bonito
	# Simplemente mostrará quién acaba de puntuar
	text = "Último punto: Jugador " + str(id) + " -> " + str(points) + " Ptos"
	
	# Si quieres una lista completa, tendrías que recorrer el diccionario:
	var final_text = ""
	for pid in GameManager.scores:
		final_text += "P" + str(pid) + ": " + str(GameManager.scores[pid]) + "\n"
		text = final_text
