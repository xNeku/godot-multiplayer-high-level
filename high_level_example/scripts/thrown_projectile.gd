extends Node2D
class_name ThrownProjectile
# Proyectil con trayectoria (gravedad). Solo el servidor lo mueve; el resto recibe
# posición y rotación. Paso a paso con rayos, igual que la previsualización del arco.
#   GRENADE: rebota amortiguada y explota al acabar la mecha.
#   TOMAHAWK: mata al tocar a alguien, rebota max_bounces veces y se queda en el suelo
#             como objeto recogible (si mata, cae donde murió el otro).
#   SEMTEX: se pega a la primera superficie o jugador y explota al acabar la mecha.
#   SMOKE: rebota como la granada y suelta humo al acabar la mecha.
#   TRANSLOCATOR: rebota y al acabar la mecha teletransporta a quien lo lanzó hasta donde está.
#   BETTY: cae al suelo y se arma. Si pisa alguien cerca (menos su dueño) salta a la altura
#          de la cabeza y explota.
#   PEM: rebota y al acabar la mecha apaga linternas, bombillas y puertas en un radio.
#   ROCKET: bala de bazooka con caída; explota al primer contacto.

enum Mode { GRENADE, TOMAHAWK, SEMTEX, SMOKE, TRANSLOCATOR, BETTY, PEM, ROCKET }
enum State { FLYING, RESTING, STUCK, GONE, POPPING }

const PLATFORM_LAYER: int = 4

@export var mode: Mode = Mode.GRENADE
# Qué objeto es (para poder recogerlo de nuevo: Tomahawk). Lo pone el jugador al lanzarlo
# (no se asigna en la escena: el .tres del objeto ya referencia esta escena).
var item_data: ItemData
# Holgura con la superficie al chocar (px)
@export var radius: float = 4.0
# Velocidad que conserva al rebotar (0 a 1)
@export var bounce_damping: float = 0.55
# Rebotes antes de quedarse en el suelo (Tomahawk: 2)
@export var max_bounces: int = 99
# Segundos hasta explotar (Granada: desde que se lanza. Semtex: desde que se pega). 0 = no explota
@export var fuse_time: float = 2.5
@export var explosion_radius: float = 70.0
# Rompe muros y suelos de los mapas JSON en este radio (× explosion_radius)
@export var break_terrain: bool = true
@export var terrain_radius_mult: float = 0.55
# Grados/segundo que gira mientras vuela
@export var spin_deg: float = 600.0
# ROCKET: el sprite mira hacia donde va
@export var face_velocity: bool = false
@export_group("Mina (Betty)")
@export var arm_time: float = 1.0
@export var trigger_radius: float = 26.0
@export var pop_height: float = 40.0
@export_group("Pem")
@export var emp_radius: float = 260.0
@export var emp_duration: float = 6.0
# Segundos que dura en el mapa si nadie la coge
@export var lifetime: float = 120.0

var velocity: Vector2 = Vector2.ZERO
var gravity: float = 1400.0
var shooter_id: int = 0

var _state: State = State.FLYING
var _bounces_left: int = 0
var _fuse_left: float = -1.0
var _age: float = 0.0
var _hit_someone: bool = false
var _pop_left: float = 0.0
var _betty_query: PhysicsShapeQueryParameters2D
var _stuck_to: Node2D
var _stuck_offset: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var fx: Node2D = $Explosion
@onready var fx_light: PointLight2D = $LuzExplosion
@onready var fx_sound: AudioStreamPlayer2D = $Sonido


func _ready() -> void:
	_bounces_left = max_bounces
	set_physics_process(multiplayer.is_server())


# Lo llama el servidor justo después de crearlo
func launch(vel: Vector2, shooter: int, grav: float) -> void:
	velocity = vel
	shooter_id = shooter
	gravity = grav
	if mode in [Mode.GRENADE, Mode.SMOKE, Mode.TRANSLOCATOR, Mode.PEM, Mode.ROCKET] and fuse_time > 0.0:
		_fuse_left = fuse_time


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	if _fuse_left > 0.0:
		_fuse_left -= delta
		if _fuse_left <= 0.0 and _state != State.GONE:
			_fuse_end()
			return

	match _state:
		State.FLYING:
			_fly(delta)
		State.RESTING:
			if mode == Mode.BETTY:
				_check_betty_trigger()
		State.POPPING:
			global_position.y -= (pop_height / 0.25) * delta
			_pop_left -= delta
			if _pop_left <= 0.0:
				_explode()
		State.STUCK:
			if _stuck_to and is_instance_valid(_stuck_to):
				global_position = _stuck_to.global_position + _stuck_offset


# Rayo de a a b. Las plataformas de un solo sentido solo cuentan si caes sobre ellas.
func _cast(a: Vector2, b: Vector2) -> Dictionary:
	var space := get_world_2d().direct_space_state
	var excludes: Array[RID] = []
	if _age < 0.15:
		var shooter_node := get_parent().get_node_or_null(str(shooter_id)) as CollisionObject2D
		if shooter_node:
			excludes.append(shooter_node.get_rid())
	for _i in 4:
		var q := PhysicsRayQueryParameters2D.create(a, b)
		q.collision_mask = 1 + 2 + 8
		q.exclude = excludes
		var r := space.intersect_ray(q)
		if r.is_empty():
			return r
		var col := r.collider as CollisionObject2D
		if col and col.get_collision_layer_value(PLATFORM_LAYER) and (r.normal.y > -0.5 or velocity.y <= 0.0):
			excludes.append(col.get_rid())
			continue
		return r
	return {}


func _fly(delta: float) -> void:
	velocity.y += gravity * delta
	var from := global_position
	var to := from + velocity * delta
	var r := _cast(from, to)
	if r.is_empty():
		global_position = to
		if face_velocity:
			rotation = velocity.angle()
		elif spin_deg != 0.0:
			rotation += deg_to_rad(spin_deg) * signf(velocity.x if velocity.x != 0.0 else 1.0) * delta
		return

	global_position = r.position + r.normal * radius
	var collider: Node = r.collider
	if collider.has_method("on_impact"):
		collider.on_impact(r.position)

	if collider is CharacterBody2D:
		_hit_body(collider, r.normal)
	else:
		_hit_surface(r.normal)


func _hit_body(body: Node, normal: Vector2) -> void:
	match mode:
		Mode.TOMAHAWK:
			if _hit_someone:
				return
			if body.has_method("hit"):
				body.hit(shooter_id)
				_hit_someone = true
				# Se queda donde murió: pierde el impulso y cae al suelo
				velocity = Vector2.ZERO
		Mode.SEMTEX:
			_stick(body)
		Mode.ROCKET:
			_explode()
		_:
			velocity = velocity.bounce(normal) * bounce_damping


func _hit_surface(normal: Vector2) -> void:
	match mode:
		Mode.SEMTEX:
			_stick(null)
		Mode.ROCKET:
			_explode()
		Mode.BETTY:
			# Se queda en el suelo; contra paredes y techos rebota y acaba cayendo
			if normal.y < -0.7:
				_land()
			else:
				velocity = velocity.bounce(normal) * bounce_damping
		_:
			if _hit_someone:
				_land()
				return
			if _bounces_left > 0:
				_bounces_left -= 1
				velocity = velocity.bounce(normal) * bounce_damping
			else:
				_land()
				return
			# Grandes rebotes pequeños acaban parando en el suelo
			if normal.y < -0.7 and velocity.length() < 110.0:
				_land()


func _land() -> void:
	_state = State.RESTING
	velocity = Vector2.ZERO
	if mode == Mode.TOMAHAWK and item_data:
		add_to_group("pickups")


func _stick(body: Node2D) -> void:
	_state = State.STUCK
	velocity = Vector2.ZERO
	_stuck_to = body
	if body:
		_stuck_offset = global_position - body.global_position
	if fuse_time > 0.0:
		_fuse_left = fuse_time


func _check_betty_trigger() -> void:
	if _age < arm_time:
		return
	if _betty_query == null:
		var shape := CircleShape2D.new()
		shape.radius = trigger_radius
		_betty_query = PhysicsShapeQueryParameters2D.new()
		_betty_query.shape = shape
		_betty_query.collision_mask = 2
	_betty_query.transform = Transform2D(0.0, global_position)
	for r in get_world_2d().direct_space_state.intersect_shape(_betty_query, 8):
		var body: Node = r.collider
		if body.has_method("hit") and body.name != str(shooter_id):
			_state = State.POPPING
			_pop_left = 0.25
			return


func _fuse_end() -> void:
	match mode:
		Mode.PEM:
			_state = State.GONE
			_emp_fx.rpc(global_position)
			await get_tree().create_timer(1.0).timeout
			queue_free()
		Mode.SMOKE:
			_state = State.GONE
			_smoke_fx.rpc()
			await get_tree().create_timer(6.0).timeout
			queue_free()
		Mode.TRANSLOCATOR:
			_state = State.GONE
			var player := get_parent().get_node_or_null(str(shooter_id))
			if player:
				player.teleport_to.rpc(global_position)
			_teleport_fx.rpc()
			await get_tree().create_timer(0.5).timeout
			queue_free()
		_:
			_explode()


func _explode() -> void:
	_state = State.GONE
	var space := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = explosion_radius
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.transform = Transform2D(0.0, global_position)
	q.collision_mask = 2 | 32 # jugadores y escondidos (a esos sí les llega la explosión)
	for r in space.intersect_shape(q, 32):
		var body: Node2D = r.collider
		if not body.has_method("hit"):
			continue
		# No atraviesa paredes: rayo hasta la víctima solo contra el suelo
		var los := PhysicsRayQueryParameters2D.create(global_position, body.global_position, 1)
		if not space.intersect_ray(los).is_empty():
			continue
		body.hit(shooter_id)
	_explode_fx.rpc(global_position)
	await get_tree().create_timer(1.3).timeout
	queue_free()


@rpc("authority", "call_local", "reliable")
func _explode_fx(pos: Vector2) -> void:
	_state = State.GONE
	global_position = pos
	# Rompe el terreno (mapas JSON). Misma posición en todos los peers = mismo agujero.
	if break_terrain:
		var map := get_tree().get_first_node_in_group("map_settings") as Node2D
		var loader: GDScript = load("res://high_level_example/scripts/map_loader.gd")
		var broken: PackedVector2Array = loader.carve(map, pos, explosion_radius * terrain_radius_mult)
		if not broken.is_empty():
			Fx.debris(broken)
	sprite.visible = false
	var rocket_light := get_node_or_null("Luz") as Node2D
	if rocket_light:
		rocket_light.visible = false
	fx.play(explosion_radius)
	var tw := create_tween()
	fx_light.energy = 3.0
	fx_light.enabled = true
	tw.tween_property(fx_light, "energy", 0.0, 0.35)
	tw.tween_callback(func(): fx_light.enabled = false)
	fx_sound.play()


# Apaga luces y puertas cercanas en TODOS los peers (cada uno aplica lo suyo en local)
@rpc("authority", "call_local", "reliable")
func _emp_fx(center: Vector2) -> void:
	_state = State.GONE
	sprite.visible = false
	fx.play(emp_radius, Color(0.3, 0.7, 1.0), 6.0, 1.5)
	for n in get_tree().get_nodes_in_group("emp_affected"):
		if n.has_method("emp") and n.global_position.distance_to(center) <= emp_radius:
			n.emp(emp_duration)
	fx_light.color = Color(0.4, 0.75, 1.0)
	fx_light.enabled = true
	fx_light.energy = 2.5
	var tw := create_tween()
	tw.tween_property(fx_light, "energy", 0.0, 0.5)
	tw.tween_callback(func(): fx_light.enabled = false)
	fx_sound.play()


@rpc("authority", "call_local", "reliable")
func _smoke_fx() -> void:
	_state = State.GONE
	sprite.visible = false
	var smoke := get_node_or_null("Humo") as CPUParticles2D
	if smoke:
		smoke.emitting = true


@rpc("authority", "call_local", "reliable")
func _teleport_fx() -> void:
	_state = State.GONE
	sprite.visible = false
	fx_light.color = Color(0.9, 0.2, 0.7)
	fx_light.enabled = true
	fx_light.energy = 2.5
	var tw := create_tween()
	tw.tween_property(fx_light, "energy", 0.0, 0.4)
	tw.tween_callback(func(): fx_light.enabled = false)


# --- Interfaz de objeto recogible (solo el Tomahawk en reposo) ---

func is_available() -> bool:
	return _state == State.RESTING and mode == Mode.TOMAHAWK and item_data != null


func pickup_kind() -> String:
	return "item"


func get_item() -> ItemData:
	return item_data


func take() -> void:
	if multiplayer.is_server() and is_available():
		_state = State.GONE
		queue_free()
