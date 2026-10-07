extends Node2D
# Punto rojo que marca el último impacto. Se queda hasta el siguiente.

@export var radius: float = 2.5


func show_at(world_pos: Vector2) -> void:
	global_position = world_pos
	visible = true


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius + 1.0, Color(0, 0, 0, 0.6))
	draw_circle(Vector2.ZERO, radius, Color(1, 0.05, 0.05))
