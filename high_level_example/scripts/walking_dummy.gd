extends CharacterBody2D
# Muñeco que patrulla de izquierda a derecha (para probar minas y claymores).
# Si le dan muere, sale volando y reaparece a los respawn_time segundos.
# Solo el servidor lo simula; el resto recibe posición/rotación.

@export var patrol_distance: float = 90.0
@export var speed: float = 35.0
@export var respawn_time: float = 3.0
@export var gravity: float = 900.0
@export var launch_speed: Vector2 = Vector2(260, -420)
@export var spin_speed: float = 14.0

var _origin: Vector2
var _dir: float = 1.0
var _dead: bool = false
var _fly_velocity: Vector2 = Vector2.ZERO
var _spin: float = 0.0

@onready var visual: Node2D = $Visual
@onready var shape: CollisionShape2D = $CollisionShape2D
@onready var marker: Node2D = $Marca


func _ready() -> void:
	_origin = position
	marker.visible = false
	marker.top_level = true
	set_physics_process(multiplayer.is_server())


func _physics_process(delta: float) -> void:
	if _dead:
		_fly_velocity.y += gravity * delta
		position += _fly_velocity * delta
		rotation += _spin * delta
		return

	velocity.x = _dir * speed
	velocity.y += gravity * delta
	move_and_slide()
	if position.x > _origin.x + patrol_distance:
		_dir = -1.0
	elif position.x < _origin.x - patrol_distance:
		_dir = 1.0
	visual.scale.x = _dir


# Mismo contrato que el jugador: lo llaman balas y claymores (solo servidor)
func hit(shooter_id: int = 0, _return_ammo: bool = false) -> void:
	if not multiplayer.is_server() or _dead:
		return
	_dead = true
	shape.set_deferred("disabled", true)
	var side: float = [-1.0, 1.0].pick_random()
	var shooter := get_tree().root.find_child(str(shooter_id), true, false) as Node2D
	if shooter:
		side = signf(global_position.x - shooter.global_position.x)
		if side == 0.0:
			side = 1.0
	_fly_velocity = Vector2(launch_speed.x * side, launch_speed.y)
	_spin = spin_speed * side
	await get_tree().create_timer(respawn_time).timeout
	_respawn()


func _respawn() -> void:
	position = _origin
	rotation = 0.0
	velocity = Vector2.ZERO
	_dir = 1.0
	shape.set_deferred("disabled", false)
	_dead = false


# Las balas también marcan impacto en él (si sigue vivo, hit() lo mata antes)
func on_impact(world_pos: Vector2) -> void:
	if multiplayer.is_server():
		_show_mark.rpc(world_pos)


@rpc("authority", "call_local", "reliable")
func _show_mark(world_pos: Vector2) -> void:
	marker.show_at(world_pos)
