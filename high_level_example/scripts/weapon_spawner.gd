extends Node2D
# Punto del mapa donde aparece un arma (flota como un puntito).
# Al cogerla, vuelve a aparecer en este mismo sitio tras respawn_time segundos.
# Para cambiar el arma: arrastra otro .tres al campo "Weapon" en el inspector.

@export var weapon: WeaponData
@export var respawn_time: float = 5.0
@export var show_label: bool = true
@export var float_height: float = 2.5

var _available: bool = true
var _phase: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Etiqueta

# Los jugadores leen esto igual que de un arma suelta
var ammo: int:
	get: return weapon.max_ammo if weapon else 0


func _ready() -> void:
	_phase = randf() * TAU
	if weapon:
		sprite.texture = weapon.texture
		label.text = weapon.role_name
	label.visible = show_label


func _process(_delta: float) -> void:
	sprite.position.y = -11.0 + sin(Time.get_ticks_msec() / 1000.0 * 2.5 + _phase) * float_height


func _draw() -> void:
	var c := Color(1, 1, 1, 0.85) if _available else Color(1, 1, 1, 0.2)
	draw_circle(Vector2(0, 2), 2.5, c)
	draw_arc(Vector2(0, 2), 5.0, 0.0, TAU, 20, Color(c, c.a * 0.5), 1.0)


func is_available() -> bool:
	return _available and weapon != null


func get_weapon() -> WeaponData:
	return weapon


# Solo el servidor (lo llama el jugador que interactúa)
func take() -> void:
	if not multiplayer.is_server() or not _available:
		return
	_set_available.rpc(false)
	await get_tree().create_timer(respawn_time).timeout
	_set_available.rpc(true)


@rpc("authority", "call_local", "reliable")
func _set_available(value: bool) -> void:
	_available = value
	sprite.visible = value
	queue_redraw()
