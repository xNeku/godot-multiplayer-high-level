extends StaticBody2D
# Interruptor de la luz del mapa: al dispararle alterna la oscuridad global.

@export var lights_on: bool = true
@export var on_color: Color = Color(0.2, 1, 0.3)
@export var off_color: Color = Color(1, 0.15, 0.15)

@onready var lamp: ColorRect = $Lampara


func _ready() -> void:
	_update_lamp()


func on_impact(_world_pos: Vector2) -> void:
	if multiplayer.is_server():
		_set_lights.rpc(not lights_on)


@rpc("authority", "call_local", "reliable")
func _set_lights(value: bool) -> void:
	lights_on = value
	_update_lamp()
	var darkness := get_tree().get_first_node_in_group("darkness") as CanvasItem
	if darkness:
		darkness.visible = not lights_on


func _update_lamp() -> void:
	lamp.color = on_color if lights_on else off_color
