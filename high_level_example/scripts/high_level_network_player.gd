extends CharacterBody2D
# Jugador en red. Cada peer controla SOLO su jugador (la autoridad es el id que
# lleva el nombre del nodo). Los demás jugadores se ven por el
# MultiplayerSynchronizer (posición, animación y puntería) y no simulan nada.
# Todos empiezan con default_weapon (pistola infinita).

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

@export_group("Objeto (lanzamiento)")
# Del arco de previsualización solo se enseña este tramo del vuelo (segundos)
@export var arc_preview_time: float = 0.45

var current_weapon_data: WeaponData
var current_item: ItemData
var _charging: bool = false
var _charge_time: float = 0.0
var _emp_until_msec: int = 0
# Balas que quedan. -1 = infinitas (arma inicial). Sin recarga: a 0 el arma queda vacía.
var current_ammo: int = 0
var facing: int = 1 # 1 = derecha, -1 = izquierda
var aim_angle: float = 0.0 # radianes, ángulo global del disparo
var _aim_up: float = 0.0 # cuánto ha subido el arma (0 = recto)
var _recoil: float = 0.0 # retroceso acumulado (radianes hacia arriba)
var _recoil_recover_at_msec: int = 0

# Cooldowns por marca de tiempo (más barato que crear un timer por disparo)
var _next_shot_msec: int = 0
var _drop_until_msec: int = 0

@onready var visual: Node2D = $Cuerpo
# Luz tenue solo para uno mismo: así te ves aunque estés a oscuras
@onready var aura: PointLight2D = $Aura
@onready var hand_pivot: Node2D = $HandPivot
@onready var muzzle: Marker2D = $HandPivot/Muzzle
@onready var flashlight: PointLight2D = $HandPivot/PointLight2D
@onready var camera: Camera2D = $Camera2D
@onready var weapon_sprite: Sprite2D = $HandPivot/Sprite2D
@onready var muzzle_flash: PointLight2D = $HandPivot/Muzzle/Fogonazo
@onready var shot_audio: AudioStreamPlayer2D = $HandPivot/Muzzle/SonidoDisparo
@onready var throw_arc: Line2D = $ArcoLanzamiento

const DROPPED_WEAPON_SCENE: PackedScene = preload("res://high_level_example/scenes/ArmaSuelta.tscn")


func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())


func _ready() -> void:
	add_to_group("emp_affected")
	var is_mine: bool = is_multiplayer_authority()
	camera.enabled = is_mine
	if flashlight:
		flashlight.enabled = is_mine
	aura.enabled = is_mine
	throw_arc.clear_points()

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

	update_aiming(delta)

	if current_weapon_data:
		var auto: bool = current_weapon_data.fire_mode == WeaponData.FireMode.AUTO
		var trigger: bool = Input.is_action_pressed("shoot") if auto else Input.is_action_just_pressed("shoot")
		if trigger:
			shoot()
	if Input.is_action_just_pressed("interact"):
		request_interact.rpc_id(1)
	_update_weapon_arc()
	_update_throw(delta)


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
	# Margen tras coger/cambiar de arma (evita disparar sin querer al pulsar E)
	_next_shot_msec = Time.get_ticks_msec() + 200
	weapon_sprite.texture = new_weapon.texture
	weapon_sprite.scale = Vector2.ONE * 1.2 * new_weapon.sprite_scale


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

	# El ángulo va en global (aim_angle). hand_pivot.rotation es local y este nodo
	# tiene escala no uniforme, así que con él las balas se desviaban.
	request_shoot.rpc_id(1,
		muzzle.global_position,
		aim_angle,
		current_weapon_data.bullet_speed,
		current_weapon_data.spread,
		current_weapon_data.bullet_count
	)

	# El disparo sale con el ángulo actual; el retroceso afecta al siguiente
	if current_weapon_data.recoil_per_shot_deg > 0.0:
		_recoil = minf(_recoil + deg_to_rad(current_weapon_data.recoil_per_shot_deg), deg_to_rad(current_weapon_data.recoil_max_deg))
		_recoil_recover_at_msec = now + int(current_weapon_data.recoil_pause * 1000.0)


@rpc("any_peer", "call_local", "reliable")
func request_shoot(pos: Vector2, rot: float, speed: float, spread: float, count: int) -> void:
	if not multiplayer.is_server():
		return
	if current_weapon_data == null or current_weapon_data.bullet_scene == null:
		return

	# El tirador es el dueño de este nodo (su nombre es su id de red)
	var shooter: int = name.to_int()

	# La copia del servidor también cuenta la munición (el dueño ya descontó la suya)
	if not is_multiplayer_authority() and current_ammo > 0:
		current_ammo -= 1
	_shot_fx.rpc(not current_weapon_data.silenced)

	for _i in count:
		var bullet = current_weapon_data.bullet_scene.instantiate()
		get_parent().add_child(bullet, true)
		bullet.global_position = pos

		var final_angle: float = rot + deg_to_rad(randf_range(-spread, spread))
		bullet.rotation = final_angle

		if bullet.has_method("launch"):
			bullet.launch(Vector2.RIGHT.rotated(final_angle) * speed, shooter, current_weapon_data.projectile_gravity)
		if "speed" in bullet: bullet.speed = speed
		if "direction" in bullet: bullet.direction = Vector2.RIGHT.rotated(final_angle)
		if "shooter_id" in bullet: bullet.shooter_id = shooter


# Sonido (con alcance según el arma) y, si no lleva silenciador, fogonazo de luz.
# Cada peer usa el arma que tiene equipada este jugador.
@rpc("any_peer", "call_local", "unreliable")
func _shot_fx(with_flash: bool) -> void:
	var wd := current_weapon_data
	if wd and wd.shot_sound:
		shot_audio.stream = wd.shot_sound
		shot_audio.max_distance = wd.hearing_range
		shot_audio.play()
	if with_flash:
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

	if best and best.pickup_kind() == "item":
		var picked: ItemData = best.get_item()
		best.take()
		_drop_current_item(Vector2(randf_range(-40.0, 40.0), -120.0))
		equip_item_rpc.rpc(picked.resource_path)
	elif best:
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


# Solo servidor: deja en el suelo el objeto que lleva
func _drop_current_item(toss: Vector2) -> void:
	if current_item == null:
		return
	var drop := DROPPED_WEAPON_SCENE.instantiate()
	drop.item_path = current_item.resource_path
	get_parent().add_child(drop, true)
	drop.global_position = global_position + Vector2(0, -6)
	drop.linear_velocity = toss


# --- DAÑO Y VICTORIA ---

func hit(shooter_id: int) -> void:
	if not multiplayer.is_server():
		return

	# Matarte a ti mismo (granada propia...) no da punto a nadie
	var current_points: int = GameManager.scores.get(str(shooter_id), 0)
	if shooter_id != name.to_int():
		current_points = GameManager.add_point(shooter_id)
	_drop_current_weapon(Vector2(randf_range(-80.0, 80.0), -200.0))
	_drop_current_item(Vector2(randf_range(-80.0, 80.0), -200.0))

	if current_points >= 10:
		game_over_rpc.rpc(shooter_id)
	else:
		respawn_rpc.rpc()


@rpc("any_peer", "call_local", "reliable")
func respawn_rpc() -> void:
	# Al reaparecer se vuelve al arma por defecto con la munición llena
	if default_weapon:
		equip_weapon(default_weapon, -1)
	current_item = null

	if is_multiplayer_authority():
		_aim_up = 0.0
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


# --- OBJETO: LANZAR CON CARGA Y ARCO ---

# Mantén el botón para cargar (el arco se alarga) y suéltalo para lanzar
func _update_throw(delta: float) -> void:
	if current_item == null:
		if _charging:
			_cancel_charge()
		return
	if current_item.place_only:
		if Input.is_action_just_pressed("throw"):
			request_throw.rpc_id(1, current_item.resource_path, global_position, Vector2.ZERO)
		return
	if Input.is_action_just_pressed("throw"):
		_charging = true
		_charge_time = 0.0
	if not _charging:
		return
	_charge_time += delta
	_update_arc()
	if Input.is_action_just_released("throw") or not Input.is_action_pressed("throw"):
		_do_throw()


# Armas con proyectil de caída (Bazooka): arco corto siempre visible al apuntar
func _update_weapon_arc() -> void:
	if _charging:
		return
	var wd := current_weapon_data
	if wd == null or wd.projectile_gravity <= 0.0 or current_ammo == 0:
		if throw_arc.get_point_count() > 0:
			throw_arc.clear_points()
		return
	_draw_arc(muzzle.global_position, Vector2.RIGHT.rotated(aim_angle) * wd.bullet_speed, wd.projectile_gravity)


func _cancel_charge() -> void:
	_charging = false
	throw_arc.clear_points()


func _throw_direction() -> Vector2:
	var a: float = clampf(_aim_up + deg_to_rad(current_item.lob_deg), 0.0, deg_to_rad(95.0))
	return Vector2(facing * cos(a), -sin(a))


func _throw_velocity() -> Vector2:
	var t: float = clampf(_charge_time / maxf(current_item.charge_time, 0.01), 0.0, 1.0)
	return _throw_direction() * lerpf(current_item.min_speed, current_item.max_speed, t)


func _throw_origin() -> Vector2:
	return global_position + Vector2(facing * 8.0, -6.0)


# Primeros arc_preview_time segundos del vuelo (se corta al chocar con el suelo)
func _update_arc() -> void:
	_draw_arc(_throw_origin(), _throw_velocity(), current_item.gravity)


func _draw_arc(pos: Vector2, vel: Vector2, g: float) -> void:
	throw_arc.clear_points()
	var space := get_world_2d().direct_space_state
	var dt: float = 1.0 / 60.0
	throw_arc.add_point(pos)
	for i in int(arc_preview_time / dt):
		vel.y += g * dt
		var next: Vector2 = pos + vel * dt
		var q := PhysicsRayQueryParameters2D.create(pos, next, 1)
		var r := space.intersect_ray(q)
		if not r.is_empty():
			throw_arc.add_point(r.position)
			break
		pos = next
		if i % 2 == 1:
			throw_arc.add_point(pos)


func _do_throw() -> void:
	var item := current_item
	var vel: Vector2 = _throw_velocity()
	var origin: Vector2 = _throw_origin()
	_cancel_charge()
	request_throw.rpc_id(1, item.resource_path, origin, vel)


@rpc("any_peer", "call_local", "reliable")
func request_throw(item_path: String, origin: Vector2, vel: Vector2) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if sender != 0 and sender != name.to_int():
		return
	# Tiene que ser el objeto que lleva (la copia del servidor lo sabe)
	if current_item == null or current_item.resource_path != item_path or current_item.scene == null:
		return
	var item := current_item
	if item.place_only:
		_place_item(item)
		return
	if vel.length() > item.max_speed * 1.05:
		vel = vel.normalized() * item.max_speed

	# Si hay una pared entre el jugador y la mano, sale desde el jugador
	var space := get_world_2d().direct_space_state
	var los := PhysicsRayQueryParameters2D.create(global_position, origin, 1)
	var block := space.intersect_ray(los)
	if not block.is_empty():
		origin = block.position + block.normal * 2.0

	var projectile = item.scene.instantiate()
	get_parent().add_child(projectile, true)
	projectile.global_position = origin
	if "shooter_id" in projectile:
		projectile.shooter_id = name.to_int()
	if "item_data" in projectile:
		projectile.item_data = item
	if projectile.has_method("launch"):
		projectile.launch(vel, name.to_int(), item.gravity)
	elif projectile is RigidBody2D:
		projectile.linear_velocity = vel
		projectile.angular_velocity = randf_range(-10, 10)

	equip_item_rpc.rpc("")


# Solo servidor: coloca el objeto en el suelo delante del jugador (Claymore)
func _place_item(item: ItemData) -> void:
	if item.place_in_door:
		_place_in_door(item)
		return
	var space := get_world_2d().direct_space_state
	var from: Vector2 = global_position + Vector2(facing * 16.0, -6.0)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 40), 1 + 8)
	var r := space.intersect_ray(q)
	var pos: Vector2 = (r.position + Vector2(0, -8)) if not r.is_empty() else global_position
	var placed = item.scene.instantiate()
	get_parent().add_child(placed, true)
	placed.global_position = pos
	if "shooter_id" in placed:
		placed.shooter_id = name.to_int()
	equip_item_rpc.rpc("")


# Hilo decapitador: solo si hay una puerta al lado que aún no tenga uno
func _place_in_door(item: ItemData) -> void:
	var best: Node2D = null
	var best_dist: float = 48.0
	for door in get_tree().get_nodes_in_group("puertas"):
		var d: float = global_position.distance_to(door.global_position)
		if d < best_dist and not _door_has_wire(door):
			best = door
			best_dist = d
	if best == null:
		return
	var wire = item.scene.instantiate()
	get_parent().add_child(wire, true)
	wire.global_position = best.global_position
	if "shooter_id" in wire:
		wire.shooter_id = name.to_int()
	equip_item_rpc.rpc("")


func _door_has_wire(door: Node2D) -> bool:
	for w in get_tree().get_nodes_in_group("hilos"):
		if w.global_position.distance_to(door.global_position) < 4.0:
			return true
	return false


# Pem: sin luz propia durante unos segundos (la linterna solo la tiene el dueño)
func emp(duration: float) -> void:
	_emp_until_msec = Time.get_ticks_msec() + int(duration * 1000.0)
	if not is_multiplayer_authority():
		return
	flashlight.enabled = false
	aura.enabled = false
	await get_tree().create_timer(duration + 0.05).timeout
	if Time.get_ticks_msec() >= _emp_until_msec:
		flashlight.enabled = true
		aura.enabled = true


# El servidor mueve a este jugador (Translocator). Lo aplica el dueño, que es quien manda su posición.
@rpc("any_peer", "call_local", "reliable")
func teleport_to(pos: Vector2) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return
	if is_multiplayer_authority():
		global_position = pos
		velocity = Vector2.ZERO


@rpc("any_peer", "call_local", "reliable")
func equip_item_rpc(path: String) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return
	current_item = null if path == "" else load(path)
