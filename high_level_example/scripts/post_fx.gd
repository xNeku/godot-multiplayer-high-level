extends CanvasLayer
# Autoload. Filtro de tele antigua por encima de todo (juego y HUD).
# Cada cierto tiempo lanza una franja de interferencia de arriba abajo.

# Segundos entre interferencias (aleatorio entre min y max) y lo que tarda en bajar
@export var sweep_every_min: float = 12.0
@export var sweep_every_max: float = 30.0
@export var sweep_duration: float = 1.4

@onready var screen: ColorRect = $Pantalla
var _mat: ShaderMaterial
var _wait: float = 0.0
var _pos: float = -1.0


func _ready() -> void:
	_mat = screen.material as ShaderMaterial
	set_enabled(Settings.tv_filter)
	_wait = randf_range(sweep_every_min * 0.5, sweep_every_max * 0.5)


func set_enabled(on: bool) -> void:
	screen.visible = on
	set_process(on)


func _process(delta: float) -> void:
	if _pos >= 0.0:
		_pos += delta / sweep_duration
		if _pos > 1.1:
			_pos = -1.0
			_wait = randf_range(sweep_every_min, sweep_every_max)
		_mat.set_shader_parameter("sweep_pos", _pos)
		return
	_wait -= delta
	if _wait <= 0.0:
		_pos = 0.0
