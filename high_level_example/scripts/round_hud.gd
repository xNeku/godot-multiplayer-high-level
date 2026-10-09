extends Label
# Mensajes grandes de la ronda en el centro de la pantalla ("Ronda 3", "Gana el jugador 1 (+1)"...).

var _tween: Tween


func _ready() -> void:
	text = ""
	RoundManager.banner.connect(show_banner)
	show_banner("RONDA %d  -  PRIMERO A %d" % [RoundManager.round_number, RoundManager.POINTS_TO_WIN], 2.5)


func show_banner(msg: String, seconds: float) -> void:
	text = msg
	modulate.a = 1.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(maxf(seconds - 0.5, 0.2))
	_tween.tween_property(self, "modulate:a", 0.0, 0.5)
