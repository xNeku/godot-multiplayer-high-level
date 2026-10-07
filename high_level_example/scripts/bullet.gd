extends Area2D
# Proyectil. SOLO el servidor lo mueve y detecta impactos (raycast, sin túnel).
# Los clientes lo ven por el MultiplayerSynchronizer (posición y rotación).

# Se rellenan desde el jugador al disparar
var speed: float = 2000.0
var direction: Vector2 = Vector2.RIGHT
var bounces: int = 0
var shooter_id: int = 0
var return_ammo_on_kill: bool = false

# Ajustables desde el inspector de cada escena de bala
@export var lifetime: float = 10.0
# Grados/segundo que gira el Sprite2D (Tomahawk). 0 = no gira.
@export var spin_speed: float = 0.0
# Protección para no matarse al disparar
@export var spawn_protection_time: float = 0.1

var _age: float = 0.0
var _sprite: Node2D


func _ready() -> void:
	_sprite = get_node_or_null("Sprite2D")
	set_physics_process(multiplayer.is_server())
	set_process(spin_speed != 0.0 and _sprite != null)


func _process(delta: float) -> void:
	# Solo estética, corre en todos los peers
	_sprite.rotation += deg_to_rad(spin_speed) * delta


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
		if collider.has_method("hit"):
			collider.hit(shooter_id, return_ammo_on_kill)
		queue_free()
	elif collider.is_in_group("blanco"):
		queue_free() # las dianas absorben la bala, no rebota
	elif bounces > 0:
		_bounce(result.normal)
	else:
		queue_free()


func _bounce(normal: Vector2) -> void:
	direction = direction.bounce(normal)
	rotation = direction.angle()
	bounces -= 1
	# Sacarla un poco de la pared para que no se quede pegada
	global_position += normal * 2.0
