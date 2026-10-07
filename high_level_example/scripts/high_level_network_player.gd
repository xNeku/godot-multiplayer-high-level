extends CharacterBody2D
# Jugador en red. Cada peer controla SOLO su jugador (la autoridad es el id que
# lleva el nombre del nodo). Los demás jugadores se ven por el
# MultiplayerSynchronizer (posición, animación y puntería) y no simulan nada.
# Las clases están aparcadas (carpeta Classes/): todos empiezan con default_weapon.

const LASER_RANGE: float = 2000.0
const PLATFORM_LAYER: int = 4 # capa "Plataformas" (project.godot)

@export_group("Movimiento")
@export var walk_speed: float = 220.0
@export var run_speed: float = 450.0
@export var jump_velocity: float = -750.0
@export var friction: float = 1500.0
@export var acceleration: float = 1800.0
@export var gravity: float = 2000.0
# Segundos que dura la caída a través de una plataforma
@export var drop_through_time: float = 0.25

@export_group("Puntería (sin ratón, estilo Duck Game)")
# Se dispara recto hacia donde se mira. El arma sube hacia arriba mientras
# se mantiene el botón de salto o si se está pegado a una pared mirándola.
# Si disparas mientras sube o baja, sale en el ángulo en que esté (diagonales).
@export var aim_up_at_wall: bool = true
@export_range(0.0, 90.0) var aim_up_max_deg: float = 90.0
# Velocidad a la que sube/baja el arma. Menos = diagonales más fáciles de clavar.
@export var aim_rotation_speed_deg: float = 360.0

@export_group("Arma")
# Arma con la que se empieza y con la que se reaparece.
@export var default_weapon: WeaponData
# Mientras no haya recogida de munición, el arma no se queda sin balas.
@export var debug_unlimited_ammo: bool = true

@export_group("Pruebas (habilidad y objeto lanzable)")
@export_enum("NONE", "DASH", "RICOCHET") var ability_type: String = "NONE"
@export var ability_cooldown: float = 3.0
@export var dash_speed: float = 900.0
# Arrastra aquí Claymore, SmokeBomb o Translocator para probarlos con la tecla G.
@export var throwable_scene: PackedScene
@export var throwable_cooldown: float = 5.0
@export var throw_force: float = 800.0

var current_weapon_data: WeaponData
var current_ammo: int = 0
var next_shot_bounces: bool = false
var is_aiming_laser: bool = false
var facing: int = 1 # 1 = derecha, -1 = izquierda
var aim_angle: float = 0.0 # radianes, ángulo global del disparo
var _aim_up: float = 0.0 # cuánto ha subido el arma (0 = recto)

# Cooldowns por marca de tiempo (más barato que crear un timer por disparo)
var _next_shot_msec: int = 0
var _next_ability_msec: int = 0
var _next_throw_msec: int = 0
var _drop_until_msec: int = 0

@onready var visual: Node2D = $Cuerpo
# Luz tenue solo para uno mismo: así te ves aunque estés a oscuras
@onready var aura: PointLight2D = $Aura
@onready var hand_pivot: Node2D = $HandPivot
@onready var muzzle: Marker2D = $HandPivot/Muzzle
@onready var flashlight: PointLight2D = $HandPivot/PointLight2D
@onready var camera: Camera2D = $Camera2D
@onready var weapon_sprite: Sprite2D = $HandPivot/Sprite2D
@onready var laser_sight: Line2D = $HandPivot/LaserSight


func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())


func _ready() -> void:
	var is_mine: bool = is_multiplayer_authority()
	camera.enabled = is_mine
	if flashlight:
		flashlight.enabled = is_mine
	aura.enabled = is_mine
	laser_sight.visible = false

	if is_mine:
		global_position = GameManager.get_spawn_position()
		camera.make_current()
	else:
		# Los jugadores de los demás no corren física ni input aquí.
		set_physics_process(false)

	if default_weapon:
		equip_weapon(default_weapon)


func _physics_process(delta: float) -> void:
	# Solo llega aquí el jugador local (en _ready se apaga para los demás).
	if not is_on_floor():
		velocity.y += gravity * delta

	# Plataformas atravesables: se recuperan al acabar el tiempo de caída
	if _drop_until_msec > 0 and Time.get_ticks_msec() >= _drop_until_msec:
		set_collision_mask_value(PLATFORM_LAYER, true)
		_drop_until_msec = 0

	if Input.is_action_just_pressed("ui_up") and is_on_floor():
		# Abajo + salto sobre una plataforma = bajar a través de ella
		if Input.is_action_pressed("ui_down") and _is_on_platform():
			set_collision_mask_value(PLATFORM_LAYER, false)
			_drop_until_msec = Time.get_ticks_msec() + int(drop_through_time * 1000.0)
		else:
			velocity.y = jump_velocity

	var speed: float = run_speed if Input.is_action_pressed("ui_run") else walk_speed
	var direction: float = Input.get_axis("ui_left", "ui_right")
	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	move_and_slide()

	if is_aiming_laser:
		update_laser_trajectory()

	update_aiming(delta)

	if Input.is_action_pressed("shoot"):
		shoot()
	if Input.is_action_just_pressed("ability"):
		use_ability()
	if Input.is_action_just_pressed("throw"):
		throw_object()


# ¿Estoy de pie sobre una plataforma atravesable?
func _is_on_platform() -> bool:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i).get_collider()
		if c is CollisionObject2D and c.get_collision_layer_value(PLATFORM_LAYER):
			return true
	return false


func update_aiming(delta: float) -> void:
	var direction: float = Input.get_axis("ui_left", "ui_right")
	if direction != 0.0:
		facing = 1 if direction > 0.0 else -1

	# ¿Hay que apuntar arriba? Botón de salto mantenido, o pegado a una pared mirándola
	var want_up: bool = Input.is_action_pressed("ui_up") and not Input.is_action_pressed("ui_down")
	if aim_up_at_wall and is_on_wall() and get_wall_normal().x * facing < 0.0:
		want_up = true

	var target: float = deg_to_rad(aim_up_max_deg) if want_up else 0.0
	_aim_up = move_toward(_aim_up, target, deg_to_rad(aim_rotation_speed_deg) * delta)

	aim_angle = Vector2(facing * cos(_aim_up), -sin(_aim_up)).angle()

	hand_pivot.global_rotation = aim_angle
	visual.set_facing(facing)
	hand_pivot.scale.y = -1 if facing < 0 else 1


func equip_weapon(new_weapon: WeaponData) -> void:
	current_weapon_data = new_weapon
	current_ammo = new_weapon.max_ammo
	if new_weapon.texture:
		weapon_sprite.texture = new_weapon.texture


# --- HABILIDAD DE PRUEBA ---

func use_ability() -> void:
	if ability_type == "NONE":
		return
	var now: int = Time.get_ticks_msec()
	if now < _next_ability_msec:
		return
	_next_ability_msec = now + int(ability_cooldown * 1000.0)

	match ability_type:
		"DASH":
			velocity = Vector2.RIGHT.rotated(aim_angle) * dash_speed
		"RICOCHET":
			# El siguiente disparo rebota una vez más y se enseña el láser
			next_shot_bounces = true
			is_aiming_laser = true
			laser_sight.visible = true


# --- DISPARO ---

func shoot() -> void:
	if current_weapon_data == null:
		return
	var now: int = Time.get_ticks_msec()
	if now < _next_shot_msec:
		return
	if current_ammo <= 0 and not debug_unlimited_ammo:
		return

	_next_shot_msec = now + int(current_weapon_data.fire_rate * 1000.0)
	if not debug_unlimited_ammo:
		current_ammo -= 1

	var total_bounces: int = current_weapon_data.bounces
	if next_shot_bounces:
		total_bounces += 1
		next_shot_bounces = false
		is_aiming_laser = false
		laser_sight.visible = false
		laser_sight.clear_points()

	# El ángulo va en global (aim_angle). hand_pivot.rotation es local y este nodo
	# tiene escala no uniforme, así que con él las balas se desviaban.
	request_shoot.rpc_id(1,
		muzzle.global_position,
		aim_angle,
		current_weapon_data.bullet_speed,
		current_weapon_data.spread,
		current_weapon_data.bullet_count,
		current_weapon_data.return_ammo_on_kill,
		total_bounces
	)


func update_laser_trajectory() -> void:
	laser_sight.clear_points()

	var start: Vector2 = muzzle.global_position
	var direction: Vector2 = Vector2.RIGHT.rotated(aim_angle)
	laser_sight.add_point(laser_sight.to_local(start))

	var space := get_world_2d().direct_space_state

	# Rayo 1: del arma a la primera pared (capa 1 = suelo)
	var query := PhysicsRayQueryParameters2D.create(start, start + direction * LASER_RANGE, 1)
	var result := space.intersect_ray(query)
	if result.is_empty():
		laser_sight.add_point(laser_sight.to_local(start + direction * LASER_RANGE))
		return

	var hit_pos: Vector2 = result.position
	var normal: Vector2 = result.normal
	laser_sight.add_point(laser_sight.to_local(hit_pos))

	# Rayo 2: el rebote, saliendo un pelín separado de la pared
	var bounce_dir: Vector2 = direction.bounce(normal)
	var bounce_start: Vector2 = hit_pos + normal
	var query2 := PhysicsRayQueryParameters2D.create(bounce_start, bounce_start + bounce_dir * LASER_RANGE, 1)
	var result2 := space.intersect_ray(query2)
	if result2.is_empty():
		laser_sight.add_point(laser_sight.to_local(bounce_start + bounce_dir * LASER_RANGE))
	else:
		laser_sight.add_point(laser_sight.to_local(result2.position))


@rpc("any_peer", "call_local", "reliable")
func request_shoot(pos: Vector2, rot: float, speed: float, spread: float, count: int, return_ammo: bool, bounces_amount: int) -> void:
	if not multiplayer.is_server():
		return
	if current_weapon_data == null or current_weapon_data.bullet_scene == null:
		return

	# El tirador es el dueño de este nodo (su nombre es su id de red)
	var shooter: int = name.to_int()

	for _i in count:
		var bullet = current_weapon_data.bullet_scene.instantiate()
		get_parent().add_child(bullet, true)
		bullet.global_position = pos

		var final_angle: float = rot + deg_to_rad(randf_range(-spread, spread))
		bullet.rotation = final_angle

		if "speed" in bullet: bullet.speed = speed
		if "direction" in bullet: bullet.direction = Vector2.RIGHT.rotated(final_angle)
		if "shooter_id" in bullet: bullet.shooter_id = shooter
		if "return_ammo_on_kill" in bullet: bullet.return_ammo_on_kill = return_ammo
		if "bounces" in bullet: bullet.bounces = bounces_amount


# --- DAÑO Y VICTORIA ---

func hit(shooter_id: int, ammo_back: bool = false, _damage_amount: int = 1) -> void:
	if not multiplayer.is_server():
		return

	var current_points: int = GameManager.add_point(shooter_id)

	# Armas que devuelven munición al matar (Tomahawk)
	if ammo_back:
		var shooter_node = get_parent().get_node_or_null(str(shooter_id))
		if shooter_node:
			shooter_node.regain_ammo.rpc_id(shooter_id)

	if current_points >= 10:
		game_over_rpc.rpc(shooter_id)
	else:
		respawn_rpc.rpc()


@rpc("any_peer", "call_local", "reliable")
func respawn_rpc() -> void:
	# Al reaparecer se vuelve al arma por defecto con la munición llena
	if default_weapon:
		equip_weapon(default_weapon)
	next_shot_bounces = false

	if is_multiplayer_authority():
		is_aiming_laser = false
		_aim_up = 0.0
		laser_sight.visible = false
		global_position = GameManager.get_spawn_position()
		velocity = Vector2.ZERO


@rpc("any_peer", "call_local", "reliable")
func game_over_rpc(winner_id: int) -> void:
	var level := get_tree().current_scene
	if level.has_method("end_game_sequence"):
		level.end_game_sequence(winner_id)

	if multiplayer.is_server():
		get_tree().create_timer(5.0).timeout.connect(func():
			multiplayer.multiplayer_peer.close()
		)


@rpc("any_peer", "call_local", "reliable")
func regain_ammo() -> void:
	current_ammo += 1


# --- OBJETOS LANZABLES (de prueba, ver exports) ---

func throw_object() -> void:
	if throwable_scene == null:
		return
	var now: int = Time.get_ticks_msec()
	if now < _next_throw_msec:
		return
	_next_throw_msec = now + int(throwable_cooldown * 1000.0)

	var throw_dir: Vector2 = Vector2.RIGHT.rotated(aim_angle)
	throw_dir.y -= 0.2 # arco ligero

	# Se manda la RUTA de la escena; el servidor la instancia
	request_throw.rpc_id(1, throwable_scene.resource_path, hand_pivot.global_position, throw_dir, throw_force)


@rpc("any_peer", "call_local", "reliable")
func request_throw(scene_path: String, pos: Vector2, dir: Vector2, force: float) -> void:
	if not multiplayer.is_server():
		return

	var scene: PackedScene = load(scene_path)
	if scene == null:
		return

	var projectile = scene.instantiate()
	get_parent().add_child(projectile, true)
	projectile.global_position = pos

	if projectile is RigidBody2D:
		projectile.linear_velocity = dir * force
		projectile.angular_velocity = randf_range(-10, 10)

	if "shooter_id" in projectile:
		projectile.shooter_id = name.to_int()
