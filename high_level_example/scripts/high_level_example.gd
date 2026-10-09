extends Node2D

@onready var darkness = $CanvasModulate
@onready var game_over_ui = $GameOverUi # Referencia a nuestra nueva UI
@onready var map_container: Node2D = $MapContainer

# Mapa que se carga si se lanza esta escena sin pasar por el menú.
# Si el menú ha elegido uno (GameManager.selected_map_path), manda ese.
@export var default_map: PackedScene

const MapLoader := preload("res://high_level_example/scripts/map_loader.gd")

func _ready() -> void:
	var map_scene: PackedScene = default_map
	if GameManager.selected_map_path != "":
		map_scene = load(GameManager.selected_map_path)
	var with_darkness := true
	var show_city := true
	var map: Node2D = null
	if GameManager.selected_map_json != "":
		map = MapLoader.build(GameManager.selected_map_json)
		if map == null:
			push_warning("El mapa JSON recibido no es válido; uso el mapa por defecto")
	if map == null and map_scene:
		map = map_scene.instantiate()
	if map:
		map_container.add_child(map)
		# Ajustes opcionales del mapa (script map_settings.gd)
		if "with_darkness" in map:
			with_darkness = map.with_darkness
			show_city = map.show_city_background

	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	if darkness: darkness.visible = with_darkness
	$Origbig.visible = show_city

# La llama RoundManager._game_over en todos los peers al acabar la partida
func end_game_sequence(winner_id: int):
	# 1. Hágase la luz (Apagamos la oscuridad)
	if darkness: darkness.visible = false

	# 2. Mostrar la UI de victoria
	if game_over_ui:
		game_over_ui.display_results(winner_id)
