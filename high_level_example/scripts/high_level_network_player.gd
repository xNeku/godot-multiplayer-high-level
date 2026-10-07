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
# Para pruebas: ninguna arma gasta munición. (El arma inicial ya es infinita.)
@export var debug_unlimited_ammo: bool = false
# A qué distancia se puede coger un arma con el botón de interactuar
@export var interact_range: float = 36.0

@export_group("Pruebas (habilidad y objeto lanzable)")
@export_enum("NONE", "DASH", "RICOCHET") var ability_type: String = "NONE"
@export var ability_cooldown: float = 3.0
@export var dash_speed: float = 900.0
# Arrastra aquí Claymore, SmokeBomb o Translocator para probarlos con la tecla G.
@export var throwable_scene: PackedScene
@export var throwable_cooldown: float = 5.0
@export var throw_force: float = 800.0

var current_weapon_data: WeaponData
# Balas que quedan. -1 = infinitas (arma inicial). Sin recarga: a 0 el arma queda vacía.
var current_ammo: int = 0
var next_shot_bounces: bool = false
var is_aiming_laser: bool = false
var facing: int = 1 # 1 = derecha, -1 = izquierda
var aim_angle: float = 0.0 # radianes, ángulo global del disparo
var _aim_up: float = 0.0 # cuánto ha subido el arma (0 = recto)
var _recoil: float = 0.0 # retroceso acumulado (radianes hacia arriba)
var _recoil_recover_at_msec: int = 0

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
@onready var muzzle_flash: PointLight2D = $HandPivot/Muzzle/Fogonazo

const DROPPED_WEAPON_SCENE: PackedScene = preload("res://high_level_example/scenes/ArmaSuelta.tscn")


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
		equip_weapon(default_weapon, -1)


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

	if current_weapon_data:
		var auto: bool = current_weapon_data.fire_mode == WeaponData.FireMode.AUTO
		var trigger: bool = Input.is_action_pressed("shoot") if auto else Input.is_action_just_pressed("shoot")
		if trigger:
			shoot()
	if Input.is_action_just_pressed("interact"):
		request_interact.rpc_id(1)
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

	# El retroceso baja solo cuando pasa la pausa sin disparar
	if _recoil > 0.0:
		if current_weapon_data == null:
			_recoil = 0.0
		elif Time.get_ticks_msec() >= _recoil_recover_at_msec:
			_recoil = move_toward(_recoil, 0.0, deg_to_rad(current_weapon_data.recoil_recovery_deg_per_sec) * delta)

	var up_total: float = clampf(_aim_up + _recoil, 0.0, deg_to_rad(90.0))
	aim_angle = Vector2(facing * cos(up_total), -sin(up_total)).angle()

	hand_pivot.global_rotation = aim_angle
	visual.set_facing(facing)
	hand_pivot.scale.y = -1 if facing < 0 else 1


# ammo: -2 = cargador lleno, -1 = infinita, otro valor = esa cantidad
func equip_weapon(new_weapon: WeaponData, ammo: int = -2) -> void:
	_recoil = 0.0
	current_weapon_data = new_weapon
	if new_weapon == null:
		current_ammo = 0
		weapon_sprite.texture = null
		return
	current_ammo = new_weapon.max_ammo if ammo == -2 else ammo
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
	if current_ammo == 0 and not debug_unlimited_ammo:
		return

	_next_shot_msec = now + int(current_weapon_data.fire_rate * 1000.0)
	if current_ammo > 0 and not debug_unlimited_ammo:
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

	# El disparo sale con el ángulo actual; el retroceso afecta al siguiente
	if current_weapon_data.recoil_per_shot_deg > 0.0:
		_recoil = minf(_recoil + deg_to_rad(current_weapon_data.recoil_per_shot_deg), deg_to_rad(current_weapon_data.recoil_max_deg))
		_recoil_recover_at_msec = now + int(current_weapon_data.recoil_pause * 1000.0)


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

	# La copia del servidor también cuenta la munición (el dueño ya descontó la suya)
	if not is_multiplayer_authority() and current_ammo > 0:
		current_ammo -= 1
	if not current_weapon_data.silenced:
		_fire_flash.rpc()

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


@rpc("any_peer", "call_local", "unreliable")
func _fire_flash() -> void:
	muzzle_flash.enabled = true
	await get_tree().create_timer(0.06).timeout
	muzzle_flash.enabled = false


# --- RECOGER Y SOLTAR ARMAS ---

# Lo pide el dueño con el botón de interactuar; decide el servidor.
# Si hay un arma cerca la coge (y suelta la que llevaba); si no, suelta la que lleva.
@rpc("any_peer", "call_local", "reliable")
func request_interact() -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender != 0 and sender != name.to_int():
		return

	var best: Node2D = null
	var best_dist: float = interact_range
	for pickup in get_tree().get_nodes_in_group("pickups"):
		if not pickup.is_available():
			continue
		var d: float = global_position.distance_to(pickup.global_position)
		if d < best_dist:
			best = pickup
			best_dist = d

	if best:
		var data: WeaponData = best.get_weapon()
		var ammo: int = best.ammo
		best.take()
		_drop_current_weapon(Vector2(randf_range(-40.0, 40.0), -120.0))
		equip_rpc.rpc(data.resource_path, ammo)
	elif current_weapon_data:
		_drop_current_weapon(Vector2(facing * 140.0, -140.0))
		equip_rpc.rpc("", 0)


# path vacío = quedarse sin arma
@rpc("any_peer", "call_local", "reliable")
func equip_rpc(path: String, ammo: int) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return
	if path == "":
		equip_weapon(null)
	else:
		equip_weapon(load(path), ammo)


# Solo servidor: deja en el suelo el arma que lleva (el arma inicial, infinita, se descarta)
func _drop_current_weapon(toss: Vector2) -> void:
	if current_weapon_data == null or current_ammo == -1:
		return
	var drop := DROPPED_WEAPON_SCENE.instantiate()
	drop.weapon_path = current_weapon_data.resource_path
	drop.ammo = current_ammo
	get_parent().add_child(drop, true)
	drop.global_position = global_position + Vector2(0, -6)
	drop.linear_velocity = toss


# --- DAÑO Y VICTORIA ---

func hit(shooter_id: int, ammo_back: bool = false, _damage_amount: int = 1) -> void:
	if not multiplayer.is_server():
		return

	var current_points: int = GameManager.add_point(shooter_id)
	_drop_current_weapon(Vector2(randf_range(-80.0, 80.0), -200.0))

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
		equip_weapon(default_weapon, -1)
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
