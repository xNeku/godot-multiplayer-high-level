extends RigidBody2D
# Arma soltada (o dejada al morir). El servidor la simula, el resto la recibe por red.
# No regenera nada: solo desaparece al cogerla o pasado lifetime.

@export var weapon_path: String = ""
@export var ammo: int = 0
@export var lifetime: float = 60.0

var weapon: WeaponData
var _available: bool = true


func _ready() -> void:
	if weapon_path != "":
		weapon = load(weapon_path)
		$Sprite2D.texture = weapon.texture
	# Los clientes solo siguen la posición que manda el servidor
	freeze = not multiplayer.is_server()
	if multiplayer.is_server():
		get_tree().create_timer(lifetime).timeout.connect(queue_free)


func is_available() -> bool:
	return _available and weapon != null


func get_weapon() -> WeaponData:
	return weapon


func take() -> void:
	if not multiplayer.is_server() or not _available:
		return
	_available = false
	queue_free()
