extends StaticBody2D
# Muñeco de pruebas fijo: enseña dónde le llega el último impacto.

@onready var marker: Node2D = $Marca


func _ready() -> void:
	marker.visible = false
	marker.top_level = true


# Lo llama la bala (solo en el servidor)
func on_impact(world_pos: Vector2) -> void:
	if multiplayer.is_server():
		_show_mark.rpc(world_pos)


@rpc("authority", "call_local", "reliable")
func _show_mark(world_pos: Vector2) -> void:
	marker.show_at(world_pos)
