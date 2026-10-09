extends RigidBody2D
# Claymore: se coloca en el suelo y explota al pisarla otro jugador (el dueño no la activa).
# Si nadie la pisa, desaparece a los 20 s. Todo lo decide el servidor.

var shooter_id: int = 0


func _ready() -> void:
	$Area2D.body_entered.connect(_on_target_entered)
	if multiplayer.is_server():
		get_tree().create_timer(20.0).timeout.connect(queue_free)


func _on_target_entered(body: Node) -> void:
	if not multiplayer.is_server() or body.name == str(shooter_id):
		return
	if body is CharacterBody2D:
		explode(body)


func explode(victim: Node) -> void:
	if victim.has_method("hit"):
		victim.hit(shooter_id)
	Fx.explosion_rpc.rpc(global_position, 40.0, 0)
	queue_free()
