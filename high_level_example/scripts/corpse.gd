extends RigidBody2D
# Cadáver cosmético: copia visual del jugador que sale despedido y se desvanece.
# Local a cada peer (no se replica).

@export var life_time: float = 4.0


func setup(source_visual: Node2D, impulse: Vector2) -> void:
	var body: Node2D = source_visual.duplicate()
	body.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(body)
	body.position = Vector2.ZERO
	linear_velocity = impulse
	angular_velocity = clampf(impulse.x * 0.02, -12.0, 12.0)
	var tw := create_tween()
	tw.tween_interval(life_time * 0.6)
	tw.tween_property(self, "modulate:a", 0.0, life_time * 0.4)
	tw.tween_callback(queue_free)
