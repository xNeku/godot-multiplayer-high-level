extends Node2D
# Casquillo expulsado al disparar. Física mínima: cae, rebota una o dos veces y
# se queda un rato en el suelo. Solo visual (no se sincroniza).

var velocity: Vector2 = Vector2.ZERO
var color: Color = Color(0.85, 0.65, 0.3)
var _spin: float = 0.0
var _life: float = 3.0
var _bounces: int = 0


func _ready() -> void:
	_spin = randf_range(-25.0, 25.0)
	z_index = 2


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	velocity.y += 700.0 * delta
	rotation += _spin * delta
	var target := global_position + velocity * delta
	var q := PhysicsRayQueryParameters2D.create(global_position, target, 1 | 8)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		global_position = target
		return
	global_position = hit.position + hit.normal * 0.5
	velocity = velocity.bounce(hit.normal) * 0.35
	_spin *= 0.5
	_bounces += 1
	if _bounces >= 3 or velocity.length() < 25.0:
		# En el suelo: deja de simular y se desvanece al final de su vida
		velocity = Vector2.ZERO
		rotation = 0.0
		set_physics_process(false)
		var tw := create_tween()
		tw.tween_interval(maxf(_life - 0.6, 0.0))
		tw.tween_property(self, "modulate:a", 0.0, minf(_life, 0.6))
		tw.tween_callback(queue_free)


func _draw() -> void:
	draw_rect(Rect2(-1.5, -0.5, 3.0, 1.2), color)
