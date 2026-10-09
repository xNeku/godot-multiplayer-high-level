extends Node2D
# Trazador cosmético: lo crea SOLO el tirador (si no es el servidor) para ver su
# bala al instante, sin esperar la ida y vuelta de red. No hace daño; la bala real
# (del servidor) está oculta en ese cliente.

var speed: float = 2000.0
var direction: Vector2 = Vector2.RIGHT
var shooter_node: CollisionObject2D
var tracer: bool = false
@export var max_life: float = 2.0

var _age: float = 0.0


func _ready() -> void:
	var line := $Linea as Line2D
	if tracer:
		line.default_color = Color(1.0, 0.75, 0.35)
		line.width = 1.2
		$Luz.enabled = true


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= max_life:
		queue_free()
		return
	var target: Vector2 = global_position + direction * speed * delta
	var q := PhysicsRayQueryParameters2D.create(global_position, target)
	q.collision_mask = 1 + 2
	if _age < 0.1 and shooter_node:
		q.exclude = [shooter_node.get_rid()]
	var r := get_world_2d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		global_position = target
	else:
		global_position = r.position
		queue_free()
