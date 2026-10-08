extends Area2D
# Proyectil. SOLO el servidor lo mueve y detecta impactos (raycast, sin túnel).
# Los clientes lo ven por el MultiplayerSynchronizer (posición y rotación).

# Se rellenan desde el jugador al disparar
var speed: float = 2000.0
var direction: Vector2 = Vector2.RIGHT
var shooter_id: int = 0

# Ajustables desde el inspector de cada escena de bala
@export var lifetime: float = 10.0
# Protección para no matarse al disparar
@export var spawn_protection_time: float = 0.1
# Mayor que 0 = bala de juguete (lobby): empuja al jugador en vez de matarlo
@export var knockback: float = 0.0

var _age: float = 0.0


func _ready() -> void:
	set_physics_process(multiplayer.is_server())
	# El tirador (si no es el servidor) ya ve un trazador local al instante:
	# oculta la bala real para no verla duplicada y con retraso.
	if not multiplayer.is_server() and shooter_id == multiplayer.get_unique_id():
		visible = false


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	var space_state := get_world_2d().direct_space_state
	var current_pos := global_position
	var target_pos := current_pos + direction * speed * delta

	var query := PhysicsRayQueryParameters2D.create(current_pos, target_pos)
	query.collision_mask = 1 + 2 # Suelo + Jugadores

	# Durante la protección el rayo ignora al tirador
	var in_protection: bool = _age < spawn_protection_time
	if in_protection:
		var shooter_node := get_parent().get_node_or_null(str(shooter_id)) as CollisionObject2D
		if shooter_node:
			query.exclude = [shooter_node.get_rid()]

	var result := space_state.intersect_ray(query)
	if result.is_empty():
		global_position = target_pos
		return

	global_position = result.position
	var collider = result.collider

	# Dianas, interruptores... (solo se ejecuta en el servidor)
	if collider.has_method("on_impact"):
		collider.on_impact(result.position)

	if collider is CharacterBody2D:
		if knockback > 0.0:
			if collider.has_method("knockback_rpc"):
				var push := Vector2(direction.x * knockback, -90.0)
				collider.knockback_rpc.rpc(push)
		elif collider.has_method("hit"):
			collider.hit(shooter_id)
		queue_free()
	else:
		queue_free()
