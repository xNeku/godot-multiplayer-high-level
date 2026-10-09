extends Node
# Autoload. Opciones del jugador (volumen, ventana, color) guardadas en user://opciones.cfg.

const PATH: String = "user://opciones.cfg"

# Colores para tintar al personaje (pecho y manos). El primero es el original.
const PLAYER_COLORS: Array[Color] = [
	Color(1.0, 1.0, 1.0), Color(1.0, 0.55, 0.55), Color(1.0, 0.75, 0.45), Color(1.0, 0.95, 0.5),
	Color(0.6, 1.0, 0.6), Color(0.55, 0.95, 1.0), Color(0.6, 0.7, 1.0), Color(0.9, 0.65, 1.0),
]
const WINDOW_SIZES: Array[Vector2i] = [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]

var master_volume: float = 1.0
var fullscreen: bool = false
var window_size_index: int = 1
var color_index: int = 0


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		master_volume = clampf(float(cfg.get_value("opciones", "volumen", 1.0)), 0.0, 1.0)
		fullscreen = bool(cfg.get_value("opciones", "pantalla_completa", false))
		window_size_index = clampi(int(cfg.get_value("opciones", "ventana", 1)), 0, WINDOW_SIZES.size() - 1)
		color_index = clampi(int(cfg.get_value("jugador", "color", 0)), 0, PLAYER_COLORS.size() - 1)
	apply()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("opciones", "volumen", master_volume)
	cfg.set_value("opciones", "pantalla_completa", fullscreen)
	cfg.set_value("opciones", "ventana", window_size_index)
	cfg.set_value("jugador", "color", color_index)
	cfg.save(PATH)


func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(0, master_volume <= 0.001)
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var size: Vector2i = WINDOW_SIZES[window_size_index]
		DisplayServer.window_set_size(size)
		var screen: Vector2i = DisplayServer.screen_get_size()
		DisplayServer.window_set_position(Vector2i(Vector2(screen - size) * 0.5))
