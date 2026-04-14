extends Node2D

@onready var darkness = $CanvasModulate
@onready var game_over_ui = $GameOverUi # Referencia a nuestra nueva UI

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	if darkness: darkness.visible = true

# Esta función la llamará el jugador al ganar
func end_game_sequence(winner_id: int):
	# 1. Hágase la luz (Apagamos la oscuridad)
	if darkness: darkness.visible = false
	
	# 2. Mostrar la UI de victoria
	if game_over_ui:
		game_over_ui.display_results(winner_id)
