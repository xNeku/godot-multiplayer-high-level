extends Sprite2D
# Halo que acompaña a una luz (bombillas). Vive en una capa sin oscuridad y copia
# el encendido y el parpadeo de la luz.

var light: PointLight2D
var base_alpha: float = 0.5
var _base_energy: float = 1.0


func _ready() -> void:
	if light:
		_base_energy = maxf(light.energy, 0.01)


func _process(_delta: float) -> void:
	if light == null or not is_instance_valid(light):
		queue_free()
		return
	visible = light.enabled and light.is_visible_in_tree()
	modulate.a = base_alpha * clampf(light.energy / _base_energy, 0.0, 1.5)
