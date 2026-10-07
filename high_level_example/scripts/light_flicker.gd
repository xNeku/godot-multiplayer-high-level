extends PointLight2D
# Bombilla que de vez en cuando parpadea y se apaga un rato.
# Todo ajustable desde el inspector. Es solo local de cada jugador: si más
# adelante la luz influye en el sigilo, habrá que sincronizarla desde el servidor.

@export_group("Tiempos (segundos)")
@export var on_time_min: float = 4.0
@export var on_time_max: float = 12.0
@export var off_time_min: float = 0.6
@export var off_time_max: float = 2.5
@export_group("Parpadeo")
# Probabilidad de que antes de apagarse parpadee unas veces
@export_range(0.0, 1.0) var flicker_chance: float = 0.7
@export var flicker_count_max: int = 4
@export var flicker_speed: float = 0.07
# Energía con la luz encendida (se copia de la energía de la escena)
var _base_energy: float


func _ready() -> void:
	_base_energy = energy
	# Cada bombilla empieza en un punto distinto para que no vayan a la vez
	await get_tree().create_timer(randf_range(0.0, on_time_max)).timeout
	_cycle()


func _cycle() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(on_time_min, on_time_max)).timeout
		if not is_inside_tree():
			return
		if randf() < flicker_chance:
			for _i in randi_range(1, flicker_count_max):
				energy = _base_energy * 0.15
				await get_tree().create_timer(flicker_speed * randf_range(0.5, 1.5)).timeout
				energy = _base_energy
				await get_tree().create_timer(flicker_speed * randf_range(0.5, 1.5)).timeout
		energy = 0.0
		await get_tree().create_timer(randf_range(off_time_min, off_time_max)).timeout
		energy = _base_energy
