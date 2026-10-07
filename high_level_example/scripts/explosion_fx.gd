extends Node2D
# Círculo que se expande y se desvanece (solo estético).

var _radius: float = 0.0
var _max_radius: float = 70.0
var _alpha: float = 0.0


func play(max_radius: float) -> void:
	_max_radius = max_radius
	visible = true
	var tw := create_tween().set_parallel(true)
	tw.tween_method(func(v: float): _radius = v; queue_redraw(), 4.0, max_radius, 0.25)
	tw.tween_method(func(v: float): _alpha = v; queue_redraw(), 0.9, 0.0, 0.45)


func _draw() -> void:
	draw_circle(Vector2.ZERO, _radius, Color(1.0, 0.55, 0.1, _alpha * 0.55))
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 32, Color(1.0, 0.9, 0.5, _alpha), 2.0)
