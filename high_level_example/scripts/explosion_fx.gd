extends Node2D
# Círculo que se expande y se desvanece (solo estético).

var _radius: float = 0.0
var _max_radius: float = 70.0
var _alpha: float = 0.0
var _color: Color = Color(1.0, 0.55, 0.1)


# Sacudida: shake_near pegado a la explosión, baja con la distancia hasta shake_far,
# que la sienten todos los jugadores del mapa estén donde estén.
func play(max_radius: float, color: Color = Color(1.0, 0.55, 0.1), shake_near: float = 18.0, shake_far: float = 4.0) -> void:
	_max_radius = max_radius
	_color = color
	visible = true
	# Cada peer sacude solo su cámara (la del jugador que controla)
	for n in get_tree().get_nodes_in_group("emp_affected"):
		if n.has_method("shake") and n.is_multiplayer_authority():
			var d: float = global_position.distance_to(n.global_position)
			var k: float = clampf(1.0 - d / (_max_radius * 6.0), 0.0, 1.0)
			n.shake(lerpf(shake_far, shake_near, k * k))
	var tw := create_tween().set_parallel(true)
	tw.tween_method(func(v: float): _radius = v; queue_redraw(), 4.0, max_radius, 0.25)
	tw.tween_method(func(v: float): _alpha = v; queue_redraw(), 0.9, 0.0, 0.45)


func _draw() -> void:
	draw_circle(Vector2.ZERO, _radius, Color(_color, _alpha * 0.45))
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 32, Color(_color.lightened(0.5), _alpha), 2.0)
