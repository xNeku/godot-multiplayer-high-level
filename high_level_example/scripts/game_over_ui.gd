extends CanvasLayer

@onready var panel = $Panel
@onready var winner_label = $Panel/WinnerLabel
@onready var score_label = $Panel/ScoreLabel

func _ready():
	# Nos aseguramos de que empiece oculto
	panel.visible = false

func display_results(winner_id: int):
	# 1. Mostrar el panel
	panel.visible = true
	
	# 2. Poner quién ganó
	winner_label.text = "¡VICTORIA DEL JUGADOR " + str(winner_id) + "!"
	
	# 3. Listar los puntos de todos
	var texto = "--- PUNTUACIONES ---\n"
	for pid in GameManager.scores:
		texto += "Jugador " + str(pid) + ": " + str(GameManager.scores[pid]) + " Ptos\n"
	
	score_label.text = texto
