extends Node2D

@onready var darkness = $CanvasModulate
@onready var game_over_ui = $GameOverUi # Referencia a nuestra nueva UI
@onready var map_container: Node2D = $MapContainer

# Mapa que se carga si se lanza esta escena sin pasar por el menú.
# Si el menú ha elegido uno (GameManager.selected_map_path), manda ese.
@export var default_map: PackedScene

func _ready() -> void:
	var map_scene: PackedScene = default_map
	if GameManager.selected_map_path != "":
		map_scene = load(GameManager.selected_map_path)
	if map_scene:
		map_container.add_child(map_scene.instantiate())

	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	if darkness: darkness.visible = true

# Esta función la llamará el jugador al ganar
func end_game_sequence(winner_id: int):
	# 1. Hágase la luz (Apagamos la oscuridad)
	if darkness: darkness.visible = false
	
	# 2. Mostrar la UI de victoria
	if game_over_ui:
		game_over_ui.display_results(winner_id)
