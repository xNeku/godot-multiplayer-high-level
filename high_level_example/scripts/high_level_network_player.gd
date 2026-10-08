extends CharacterBody2D
# Jugador en red. Cada peer controla SOLO su jugador (la autoridad es el id que
# lleva el nombre del nodo). Los demás jugadores se ven por el
# MultiplayerSynchronizer (posición, animación y puntería) y no simulan nada.
# Todos empiezan con default_weapon (pistola infinita).

const PLATFORM_LAYER: int = 4 # capa "Plataformas" (project.godot)

@export_group("Movimiento")
@export var walk_speed: float = 120.0
@export var run_speed: float = 230.0
@export var jump_velocity: float = -440.0
@export var friction: float = 1400.0
@export var acceleration: float = 1400.0
@export var gravity: float = 2000.0
# Margen para saltar justo después de salir de un borde
@export var coyote_time: float = 0.1
# Si pulsas salto un poco antes de tocar suelo, salta al aterrizar
@export var jump_buffer_time: float = 0.12
# Al soltar el salto con el personaje subiendo, la velocidad vertical se multiplica
# por esto (menor = salto más corto al toque)
@export_range(0.0, 1.0) var jump_cut: float = 0.45
# Gravedad extra al caer (salto menos flotante)
@export var fall_gravity_mult: float = 1.3
# Segundos que dura la caída a través de una plataforma
@export var drop_through_time: float = 0.25

@export_group("Juice")
@export var shake_per_shot: float = 2.0
@export var shake_on_death: float = 14.0
@export var shake_decay: float = 40.0
# Pausa breve (hit-stop) al matar o morir
@export var hit_stop_time: float = 0.07
@export var corpse_force: float = 380.0
@export var sfx_step: AudioStream = preload("res://high_level_example/assets/sounds/paso.wav")
@export var sfx_jump: AudioStream = preload("res://high_level_example/assets/sounds/salto.wav")
@export var sfx_land: AudioStream = preload("res://high_level_example/assets/sounds/aterrizaje.wav")
@export var sfx_death: AudioStream = preload("res://high_level_example/assets/sounds/muerte.wav")
@export var sfx_pickup: AudioStream = preload("res://high_level_example/assets/sounds/recoger.wav")
# Distancia (px) entre pasos al andar y al correr, y alcance del sonido (el sigilo importa)
@export var step_distance: float = 34.0
@export var step_range_walk: float = 660.0
@export var step_range_run: float = 1200.0

@export_group("Red")
# Suavizado de los jugadores de los demás: más alto = más pegado a la posición
# recibida, más bajo = más suave pero con algo de retraso visual.
@export var remote_smoothing: float = 30.0
# Si la copia remota se desvía más que esto (teletransporte, respawn), salta directa.
@export var remote_snap_distance: float = 120.0

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

const CORPSE_SCENE: PackedScene = preload("res://high_level_example/scenes/Cadaver.tscn")
const TRACER_SCENE: PackedScene = preload("res://high_level_example/scenes/Trazador.tscn")
const DROPPED_WEAPON_SCENE: PackedScene = preload("res://high_level_example/scenes/ArmaSuelta.tscn")


# Posición que se replica (global). El dueño la escribe cada frame de física;
# las copias remotas se deslizan hacia ella en _process.
var net_position: Vector2 = Vector2.ZERO


var _shake: float = 0.0
var _fx_last_pos: Vector2 = Vector2.ZERO
var _fx_vel: Vector2 = Vector2.ZERO
var _fx_airborne: bool = false
var _fx_peak_fall: float = 0.0
var _fx_step_acc: float = 0.0
var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0
var _was_on_floor: bool = false
var _prev_fall_speed: float = 0.0


# Polvo al aterrizar (solo visual, local; los demás no lo ven por ahora)
func _land_fx(speed: float) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = clampi(int(speed / 60.0), 4, 14)
	p.lifetime = 0.35
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 80.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 90.0
	p.gravity = Vector2(0, 200)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = Color(0.75, 0.72, 0.65, 0.8)
	get_parent().add_child(p)
	p.global_position = global_position + Vector2(0, 14)
	get_tree().create_timer(0.8).timeout.connect(p.queue_free)


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
		net_position = global_position
		_apply_camera_limits()
		camera.make_current()
	else:
		# Los jugadores de los demás no corren física ni input aquí.
		set_physics_process(false)

	if default_weapon:
		equip_weapon(default_weapon, -1)


# Los mapas pueden limitar la cámara para que no se vea el vacío exterior
func _apply_camera_limits() -> void:
	var m := get_tree().get_first_node_in_group("map_settings")
	if m == null or not ("camera_limits" in m):
		return
	var r: Rect2 = m.camera_limits
	if r.size == Vector2.ZERO:
		return
	camera.limit_left = int(r.position.x)
	camera.limit_top = int(r.position.y)
	camera.limit_right = int(r.end.x)
	camera.limit_bottom = int(r.end.y)


func _process(delta: float) -> void:
	if is_multiplayer_authority():
		if _shake > 0.0:
			_shake = maxf(0.0, _shake - shake_decay * delta)
			camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
		elif camera.offset != Vector2.ZERO:
			camera.offset = Vector2.ZERO
	elif net_position != Vector2.ZERO:
		# Copias remotas: sin física, solo se acercan a la posición recibida.
		if global_position.distance_to(net_position) > remote_snap_distance:
			global_position = net_position
		else:
			global_position = global_position.lerp(net_position, 1.0 - exp(-remote_smoothing * delta))
	_movement_sfx(delta)


# Pasos, salto y aterrizaje deducidos del movimiento, así suenan igual para todos
# (en un juego de sigilo los demás tienen que oír cómo te mueves).
func _movement_sfx(delta: float) -> void:
	if delta <= 0.0:
		return
	var pos: Vector2 = global_position
	if _fx_last_pos == Vector2.ZERO:
		_fx_last_pos = pos
	_fx_vel = _fx_vel.lerp((pos - _fx_last_pos) / delta, 0.5)
	var dx: float = pos.x - _fx_last_pos.x
	_fx_last_pos = pos
	if absf(dx) > 100.0:
		return # teletransporte / reaparición
	var airborne: bool = absf(_fx_vel.y) > 60.0
	if airborne and not _fx_airborne and _fx_vel.y < -200.0:
		_play_sfx(sfx_jump, step_range_walk, -6.0)
	if airborne:
		_fx_peak_fall = maxf(_fx_peak_fall, _fx_vel.y)
	elif _fx_airborne:
		if _fx_peak_fall > 250.0:
			_play_sfx(sfx_land, step_range_run, -2.0)
			_land_fx(_fx_peak_fall)
		_fx_peak_fall = 0.0
	_fx_airborne = airborne
	if not airborne:
		_fx_step_acc += absf(dx)
		if _fx_step_acc >= step_distance:
			_fx_step_acc = 0.0
			var running: bool = absf(_fx_vel.x) > (walk_speed + run_speed) * 0.5
			_play_sfx(sfx_step, step_range_run if running else step_range_walk, -4.0 if running else -10.0)


func _play_sfx(stream: AudioStream, hearing: float, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var a := AudioStreamPlayer2D.new()
	a.stream = stream
	a.max_distance = hearing
	a.attenuation = 1.6
	a.volume_db = volume_db
	a.pitch_scale = randf_range(0.92, 1.08)
	add_child(a)
	a.finished.connect(a.queue_free)
	a.play()


func shake(amount: float) -> void:
	if is_multiplayer_authority():
		_shake = maxf(_shake, amount)


func _physics_process(delta: float) -> void:
	# Solo llega aquí el jugador local (en _ready se apaga para los demás).
	var on_floor: bool = is_on_floor()
	if on_floor:
		_coyote_left = coyote_time
	else:
		_coyote_left = maxf(0.0, _coyote_left - delta)
		velocity.y += gravity * (fall_gravity_mult if velocity.y > 0.0 else 1.0) * delta
	_was_on_floor = on_floor

	# Plataformas atravesables: se recuperan al acabar el tiempo de caída
	if _drop_until_msec > 0 and Time.get_ticks_msec() >= _drop_until_msec:
		set_collision_mask_value(PLATFORM_LAYER, true)
		_drop_until_msec = 0

	if Input.is_action_just_pressed("ui_up"):
		_jump_buffer_left = jump_buffer_time
	else:
		_jump_buffer_left = maxf(0.0, _jump_buffer_left - delta)

	if _jump_buffer_left > 0.0 and on_floor and Input.is_action_pressed("ui_down") and _is_on_platform():
		# Abajo + salto sobre una plataforma = bajar a través de ella
		set_collision_mask_value(PLATFORM_LAYER, false)
		_drop_until_msec = Time.get_ticks_msec() + int(drop_through_time * 1000.0)
		_jump_buffer_left = 0.0
	elif _jump_buffer_left > 0.0 and _coyote_left > 0.0:
		velocity.y = jump_velocity
		_jump_buffer_left = 0.0
		_coyote_left = 0.0
	# Soltar el salto en la subida lo acorta
	if Input.is_action_just_released("ui_up") and velocity.y < 0.0:
		velocity.y *= jump_cut

	var speed: float = run_speed if Input.is_action_pressed("ui_run") else walk_speed
	var direction: float = Input.get_axis("ui_left", "ui_right")
	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	_prev_fall_speed = velocity.y
	move_and_slide()
	net_position = global_position

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

	# Efectos inmediatos en el tirador (sin esperar al servidor)
	shake(shake_per_shot * (1.0 + current_weapon_data.recoil_per_shot_deg * 0.15))
	_play_shot_fx(not current_weapon_data.silenced)
	if not multiplayer.is_server() and current_weapon_data.projectile_gravity <= 0.0:
		_spawn_local_tracers()

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
		# Antes de añadirla: así viaja en el spawn y el cliente tirador la oculta
		if "shooter_id" in bullet: bullet.shooter_id = shooter
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
	# El tirador ya lo reprodujo al disparar
	if is_multiplayer_authority():
		return
	_play_shot_fx(with_flash)


func _play_shot_fx(with_flash: bool) -> void:
	var wd := current_weapon_data
	if wd and wd.shot_sound:
		shot_audio.stream = wd.shot_sound
		shot_audio.max_distance = wd.hearing_range
		shot_audio.play()
	if with_flash:
		muzzle_flash.enabled = true
		await get_tree().create_timer(0.06).timeout
		muzzle_flash.enabled = false


# Balas "de mentira" solo visuales para el tirador cliente; la real llega con retraso
# y la tiene oculta (bullet.gd).
func _spawn_local_tracers() -> void:
	var wd := current_weapon_data
	for _i in wd.bullet_count:
		var t = TRACER_SCENE.instantiate()
		get_tree().current_scene.add_child(t)
		var ang: float = aim_angle + deg_to_rad(randf_range(-wd.spread, wd.spread))
		t.global_position = muzzle.global_position
		t.direction = Vector2.RIGHT.rotated(ang)
		t.speed = wd.bullet_speed
		t.shooter_node = self
		t.rotation = ang


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
		_play_sfx(sfx_pickup, 300.0, -4.0)


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
	death_fx_rpc.rpc(shooter_id)

	if current_points >= 10:
		game_over_rpc.rpc(shooter_id)
	else:
		respawn_rpc.rpc()


# Efectos de muerte en todos los peers: cadáver que sale despedido, sangre/chispas,
# sonido, sacudida, hit-stop y entrada en el feed de muertes.
@rpc("any_peer", "call_local", "reliable")
func death_fx_rpc(shooter_id: int) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return
	var dir := Vector2.UP
	var shooter := get_parent().get_node_or_null(str(shooter_id)) as Node2D
	if shooter and shooter != self:
		dir = (global_position - shooter.global_position).normalized()
		dir.y = minf(dir.y, -0.3)
		dir = dir.normalized()
	var corpse := CORPSE_SCENE.instantiate()
	get_tree().current_scene.add_child(corpse)
	corpse.global_position = global_position
	corpse.setup(visual, dir * corpse_force)
	_burst_fx(dir)
	_play_sfx(sfx_death, step_range_run + 200.0, 0.0)

	var mine: int = multiplayer.get_unique_id()
	if name.to_int() == mine:
		shake(shake_on_death)
	if name.to_int() == mine or shooter_id == mine:
		_hit_stop()
	var feed := get_tree().current_scene.get_node_or_null("KillFeed")
	if feed:
		feed.add_entry(shooter_id, name.to_int())


func _burst_fx(dir: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 18
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.direction = dir
	p.spread = 50.0
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 260.0
	p.gravity = Vector2(0, 700)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.5
	p.color = Color(0.85, 0.12, 0.1)
	get_tree().current_scene.add_child(p)
	p.global_position = global_position
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


func _hit_stop() -> void:
	Engine.time_scale = 0.05
	# El temporizador ignora la escala de tiempo (4º parámetro)
	await get_tree().create_timer(hit_stop_time, true, false, true).timeout
	Engine.time_scale = 1.0


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
	if path != "":
		_play_sfx(sfx_pickup, 300.0, -4.0)
