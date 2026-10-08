extends Label
# Mensajes grandes de la ronda en el centro de la pantalla ("Ronda 3", "Gana el jugador 1 (+1)"...).

var _tween: Tween


func _ready() -> void:
	text = ""
	add_theme_font_size_override("font_size", 22)
	add_theme_constant_override("outline_size", 5)
	add_theme_color_override("font_outline_color", Color.BLACK)
	RoundManager.banner.connect(show_banner)
	show_banner("Ronda %d  ·  primero a %d" % [RoundManager.round_number, RoundManager.POINTS_TO_WIN], 2.5)


func show_banner(msg: String, seconds: float) -> void:
	text = msg
	modulate.a = 1.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(maxf(seconds - 0.5, 0.2))
	_tween.tween_property(self, "modulate:a", 0.0, 0.5)
