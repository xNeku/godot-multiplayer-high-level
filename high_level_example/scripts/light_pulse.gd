extends PointLight2D
# Bombilla intermitente de sigilo: apagada casi siempre, se enciende "on_time"
# segundos cada "period" segundos (con un par de chispazos al encender).
# El momento depende del reloj desde que carga el mapa y de "phase", así todos los
# jugadores la ven a la vez (más o menos: lo que tarde en cargar cada uno).

@export var period: float = 40.0
@export var on_time: float = 2.0
# Desfase en segundos (para que no se enciendan todas a la vez)
@export var phase: float = 0.0

var _base_energy: float
var _t: float = 0.0
var _emp_until_msec: int = 0


func _ready() -> void:
	_base_energy = energy
	energy = 0.0
	add_to_group("emp_affected")


func _process(delta: float) -> void:
	_t += delta
	if Time.get_ticks_msec() < _emp_until_msec:
		energy = 0.0
		return
	var local: float = fposmod(_t + phase, period)
	if local > on_time:
		energy = 0.0
		return
	# Arranque con chispazos (primeros 0,25 s) y apagado suave
	var e: float = _base_energy
	if local < 0.25:
		e *= 1.0 if fmod(local, 0.08) < 0.04 else 0.15
	elif local > on_time - 0.3:
		e *= (on_time - local) / 0.3
	energy = e


func emp(duration: float) -> void:
	_emp_until_msec = Time.get_ticks_msec() + int(duration * 1000.0)
