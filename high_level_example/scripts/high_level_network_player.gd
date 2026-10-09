extends CharacterBody2D
# Jugador en red. Cada peer controla SOLO su jugador (la autoridad es el id que
# lleva el nombre del nodo). Los demás jugadores se ven por el
# MultiplayerSynchronizer (posición, animación y puntería) y no simulan nada.
# Todos empiezan con default_weapon (pistola infinita).

const PLATFORM_LAYER: int = 4 # capa "Plataformas" (project.godot)

@export_group("Movimiento")
@export var walk_speed: float = 120.0
@export var run_speed: float = 230.0
# Salto: ~52 px (2,4 personajes) en ~0,3 s hasta el pico. Referencia: Celeste
# escalado x2 (su personaje mide 11 px, el nuestro 22). Ver GAMEFEEL.md.
@export var jump_velocity: float = -380.0
@export var friction: float = 1400.0
@export var acceleration: float = 1400.0
@export var gravity: float = 1450.0
# En el pico del salto (|vel. vertical| < umbral) y con el salto mantenido la
# gravedad baja: da un instante de "flote" para apuntar y corregir.
@export var apex_threshold: float = 60.0
@export_range(0.1, 1.0) var apex_gravity_mult: float = 0.5
# Velocidad máxima de caída (y mayor si mantienes abajo)
@export var max_fall_speed: float = 380.0
@export var fast_fall_speed: float = 500.0
# En el aire se acelera y frena menos que en el suelo (conserva la inercia)
@export_range(0.1, 1.0) var air_control: float = 0.65
# Si vas más rápido que tu velocidad máxima (slide, backflip, soga, empujón) y sigues
# en esa dirección, frenas con esto en vez de en seco: conserva el impulso.
@export var over_speed_decel: float = 600.0
# Impulso horizontal extra al saltar en movimiento
@export var jump_h_boost: float = 40.0
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

@export_group("Sprint / Agacharse / Slide / Backflip")
# Sprint: doble toque rápido de dirección (teclado) o stick a fondo (mando)
@export var double_tap_time: float = 0.25
@export_range(0.5, 1.0) var pad_sprint_threshold: float = 0.9
# Agachado (Shift): más lento y sin ruido de pasos
@export var crouch_speed: float = 55.0
@export var crouch_height: float = 15.0
# Slide (Shift corriendo): impulso, frenado y velocidad a la que sales del slide
@export var slide_speed: float = 330.0
@export var slide_min_speed: float = 150.0
@export var slide_friction: float = 450.0
@export var slide_exit_speed: float = 60.0
@export var slide_height: float = 14.0
# Backflip (doble pulsación de salto en los primeros instantes del salto)
@export var backflip_window: float = 0.22
# Altura total del backflip desde donde despegas (px). El salto normal son ~52.
@export var backflip_height: float = 72.0
@export var backflip_speed: float = 140.0
@export var backflip_time: float = 0.5
@export_range(0.0, 1.0) var backflip_air_control: float = 0.25

@export_group("Soga")
# Mantén el botón de soga: sale hacia donde apuntas (igual que el arma: recto, y sube
# mientras mantienes salto) y se engancha a suelo, paredes, techos y plataformas.
# Suéltalo para soltarte: sales disparado con la velocidad del balanceo.
@export var rope_range: float = 170.0
# Arriba / abajo: acorta o alarga la soga
@export var rope_climb_speed: float = 70.0
@export var rope_min_length: float = 24.0
# Empuje lateral al balancearse en el aire y velocidad máxima del balanceo
@export var rope_swing_accel: float = 420.0
@export var rope_max_speed: float = 520.0
# Al soltarte, la velocidad se multiplica por esto (premia soltar en el buen momento)
@export var rope_release_boost: float = 1.1
# Espera tras fallar el enganche (no hay nada a tiro)
@export var rope_miss_cooldown: float = 0.3

@export_group("Juice")
@export var shake_per_shot: float = 2.0
@export var shake_on_death: float = 14.0
@export var shake_decay: float = 40.0
# Giro máximo de la cámara (grados) con la sacudida más fuerte (18)
@export var shake_roll_deg: float = 1.2
# Rapidez del temblor (ruido suave en vez de saltos aleatorios)
@export var shake_frequency: float = 28.0
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
@export var sfx_slide: AudioStream = preload("res://high_level_example/assets/sounds/deslizar.wav")
@export var sfx_flip: AudioStream = preload("res://high_level_example/assets/sounds/voltereta.wav")

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
# Arma de juguete del lobby (empuja, no mata)
@export var lobby_weapon: WeaponData
# Empujón al disparar al 100% (cada arma usa su self_knockback_pct de esto)
@export var self_knockback_ref: float = 800.0
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
@onready var rope_line: Line2D = $Soga
# Copia de la soga en una capa sin oscuridad: tú siempre ves la tuya; los demás solo si la ilumina una luz
@onready var rope_line_own: Line2D = $CapaSogaPropia/SogaPropia
# Haz visible de la linterna y brillo del foco (capa sin oscuridad). Solo el tuyo.
@onready var beam: Sprite2D = $CapaBrillo/Haz
@onready var lens: Sprite2D = $CapaBrillo/Lente

const CORPSE_SCENE: PackedScene = preload("res://high_level_example/scenes/Cadaver.tscn")
const TRACER_SCENE: PackedScene = preload("res://high_level_example/scenes/Trazador.tscn")
const DROPPED_WEAPON_SCENE: PackedScene = preload("res://high_level_example/scenes/ArmaSuelta.tscn")


# Posición que se replica (global). El dueño la escribe cada frame de física;
# las copias remotas se deslizan hacia ella en _process.
var net_position: Vector2 = Vector2.ZERO


var _shake: float = 0.0
# Balas disparadas (para decidir cuáles son trazadoras)
var _shots_fired: int = 0
var _local_shots: int = 0
var _shake_t: float = 0.0
var _shake_noise := FastNoiseLite.new()
var _fx_last_pos: Vector2 = Vector2.ZERO
var _fx_vel: Vector2 = Vector2.ZERO
var _fx_airborne: bool = false
var _fx_peak_fall: float = 0.0
var _fx_step_acc: float = 0.0
var _coyote_left: float = 0.0
var _jump_buffer_left: float = 0.0
var _was_on_floor: bool = false
var _prev_fall_speed: float = 0.0

enum Stance { STAND, CROUCH, SLIDE }
# Postura (se replica; mueve la hitbox en todos los peers para que los disparos acierten)
var stance: int = Stance.STAND:
	set(v):
		if v == stance:
			return
		stance = v
		if is_node_ready():
			_apply_stance_shape()
			if v == Stance.SLIDE:
				_play_sfx(sfx_slide, step_range_run, -4.0)
var _col: CollisionShape2D
var _col_base_y: float = 0.0
var _col_base_h: float = 22.0
var _hand_base: Vector2 = Vector2.ZERO
var _visual_base_y: float = -3.0
var _kb_sprint_dir: int = 0
var _tap_dir: int = 0
var _tap_time: float = -10.0
var _since_jump: float = 99.0
# Punto donde está enganchada la soga (ZERO = sin soga). Se replica para dibujarla a todos.
var rope_anchor: Vector2 = Vector2.ZERO
var _rope_len: float = 0.0
var _rope_ready_at: int = 0
# Escondites
const HIDDEN_LAYER: int = 32 # capa 6 "Escondidos": las balas no la tocan, las explosiones sí
var escondido: bool = false
var _hide_spot: Node2D = null
var _near_spot: Node2D = null
var _rope_miss_end: Vector2 = Vector2.ZERO
var _rope_miss_until: int = 0
var _flip_t: float = -1.0 # <0 = sin backflip; si no, segundos transcurridos
var _flip_facing: int = 1
var _fx_flipping: bool = false
var _dir: int = 0
var _dead: bool = false
# Cosmético elegido en el lobby (índice de Settings.PLAYER_COLORS). Se replica.
var color_index: int = 0:
	set(v):
		color_index = v
		if is_node_ready():
			visual.set_tint(Settings.PLAYER_COLORS[clampi(v, 0, Settings.PLAYER_COLORS.size() - 1)])
var _jump_start_y: float = 0.0


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


func _exit_tree() -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and not _dead:
		RoundManager.player_left(name.to_int())


func _ready() -> void:
	add_to_group("emp_affected")
	var is_mine: bool = is_multiplayer_authority()
	camera.enabled = is_mine
	if flashlight:
		flashlight.enabled = is_mine
	aura.enabled = is_mine
	throw_arc.clear_points()

	# La hitbox cambia con la postura: cada instancia necesita su propia copia
	_col = $CollisionShape2D
	_col.shape = _col.shape.duplicate()
	_col_base_y = _col.position.y
	_col_base_h = (_col.shape as CapsuleShape2D).height
	_hand_base = hand_pivot.position
	_visual_base_y = visual.position.y
	_apply_stance_shape()

	if is_mine:
		global_position = GameManager.get_spawn_position()
		net_position = global_position
		_apply_camera_limits()
		camera.make_current()
	else:
		# Los jugadores de los demás no corren física ni input aquí.
		set_physics_process(false)

	if is_mine:
		color_index = Settings.color_index
	visual.set_tint(Settings.PLAYER_COLORS[clampi(color_index, 0, Settings.PLAYER_COLORS.size() - 1)])
	var start_weapon: WeaponData = lobby_weapon if GameManager.in_lobby else default_weapon
	if start_weapon:
		equip_weapon(start_weapon, -1)
	if multiplayer.is_server() and not GameManager.in_lobby:
		RoundManager.register_player(name.to_int())


func _apply_stance_shape() -> void:
	var h: float = _col_base_h
	if stance == Stance.CROUCH:
		h = crouch_height
	elif stance == Stance.SLIDE:
		h = slide_height
	(_col.shape as CapsuleShape2D).height = h
	# Los pies se quedan en el suelo: la cápsula se encoge hacia abajo
	_col.position.y = _col_base_y + (_col_base_h - h) * 0.5


# ¿Hay hueco para ponerse de pie?
func _can_stand() -> bool:
	return not test_move(global_transform, Vector2(0.0, -(_col_base_h - (_col.shape as CapsuleShape2D).height) - 1.0))


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
			_shake_t += delta * shake_frequency
			var n := Vector2(_shake_noise.get_noise_2d(_shake_t, 0.0), _shake_noise.get_noise_2d(0.0, _shake_t))
			camera.offset = n * 2.0 * _shake
			camera.rotation = deg_to_rad(shake_roll_deg) * _shake_noise.get_noise_2d(_shake_t, 50.0) * 2.0 * (_shake / 18.0)
		elif camera.offset != Vector2.ZERO or camera.rotation != 0.0:
			camera.offset = Vector2.ZERO
			camera.rotation = 0.0
	elif net_position != Vector2.ZERO:
		# Copias remotas: sin física, solo se acercan a la posición recibida.
		if global_position.distance_to(net_position) > remote_snap_distance:
			global_position = net_position
		else:
			global_position = global_position.lerp(net_position, 1.0 - exp(-remote_smoothing * delta))
	_movement_sfx(delta)
	_update_beam()
	var missing: bool = rope_anchor == Vector2.ZERO and Time.get_ticks_msec() < _rope_miss_until
	var shown: bool = rope_anchor != Vector2.ZERO or missing
	var pts := PackedVector2Array([global_position, _rope_miss_end if missing else rope_anchor])
	rope_line.visible = shown
	rope_line_own.visible = shown and is_multiplayer_authority()
	if shown:
		rope_line.points = pts
		rope_line_own.points = pts


func _update_beam() -> void:
	var on: bool = flashlight != null and flashlight.enabled and visible and hand_pivot.visible
	beam.visible = on
	lens.visible = on
	if on:
		var t: Transform2D = flashlight.global_transform
		beam.global_position = t.origin
		beam.global_rotation = t.get_rotation()
		lens.global_position = t.origin
		# El foco parpadea un pelín, como una linterna barata
		lens.modulate.a = 0.5 + randf() * 0.08


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
	var flipping: bool = absf(visual.rotation) > 0.05
	if flipping and not _fx_flipping:
		_play_sfx(sfx_flip, step_range_walk, -4.0)
	_fx_flipping = flipping
	if not airborne and stance == Stance.STAND:
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
	if _update_hiding():
		return
	if GameManager.input_blocked:
		_idle_physics(delta)
		return
	var on_floor: bool = is_on_floor()
	if on_floor:
		_coyote_left = coyote_time
	else:
		_coyote_left = maxf(0.0, _coyote_left - delta)
		var g: float = gravity * (fall_gravity_mult if velocity.y > 0.0 else 1.0)
		if absf(velocity.y) < apex_threshold and Input.is_action_pressed("ui_up"):
			g *= apex_gravity_mult
		velocity.y += g * delta
		var cap: float = fast_fall_speed if Input.is_action_pressed("ui_down") else max_fall_speed
		velocity.y = minf(velocity.y, cap)
	_was_on_floor = on_floor

	# Plataformas atravesables: se recuperan al acabar el tiempo de caída
	if _drop_until_msec > 0 and Time.get_ticks_msec() >= _drop_until_msec:
		set_collision_mask_value(PLATFORM_LAYER, true)
		_drop_until_msec = 0

	var dir: int = _read_dir()
	_dir = dir
	_update_sprint(dir)
	_since_jump += delta
	var crouch_held: bool = Input.is_action_pressed("crouch")
	_update_stance(on_floor, dir, crouch_held, Input.is_action_just_pressed("crouch"))

	var roped: bool = _update_rope(delta)
	var jump_pressed: bool = Input.is_action_just_pressed("ui_up") and not roped
	if jump_pressed:
		_jump_buffer_left = jump_buffer_time
	else:
		_jump_buffer_left = maxf(0.0, _jump_buffer_left - delta)

	# Segunda pulsación de salto nada más empezar el salto = backflip
	if jump_pressed and _flip_t < 0.0 and not on_floor and _since_jump <= backflip_window \
			and stance == Stance.STAND:
		_flip_t = 0.0
		_flip_facing = facing
		# Velocidad justa para que el pico del salto sea backflip_height desde el despegue
		var left: float = maxf(backflip_height - (_jump_start_y - global_position.y), 12.0)
		velocity.y = -sqrt(2.0 * gravity * left)
		velocity.x = -facing * backflip_speed
		_jump_buffer_left = 0.0
		_since_jump = 99.0
	elif _jump_buffer_left > 0.0 and on_floor and Input.is_action_pressed("ui_down") and _is_on_platform():
		# Abajo + salto sobre una plataforma = bajar a través de ella
		set_collision_mask_value(PLATFORM_LAYER, false)
		_drop_until_msec = Time.get_ticks_msec() + int(drop_through_time * 1000.0)
		_jump_buffer_left = 0.0
	elif _jump_buffer_left > 0.0 and _coyote_left > 0.0:
		velocity.y = jump_velocity
		if dir != 0 and stance != Stance.SLIDE:
			velocity.x += dir * jump_h_boost
		_jump_buffer_left = 0.0
		_coyote_left = 0.0
		_since_jump = 0.0
		_jump_start_y = global_position.y
		if stance == Stance.SLIDE:
			stance = Stance.CROUCH # saltar desde el slide: mantiene el impulso
	# Soltar el salto en la subida lo acorta (no en el backflip)
	if Input.is_action_just_released("ui_up") and velocity.y < 0.0 and _flip_t < 0.0 and not roped:
		velocity.y *= jump_cut

	if roped and not on_floor:
		# Balanceo: empuje en la dirección del arco (tangente a la soga). La gravedad
		# hace el péndulo; empujar a favor del movimiento acumula velocidad.
		if dir != 0:
			var n: Vector2 = (global_position - rope_anchor).normalized()
			var tangent := Vector2(-n.y, n.x)
			if tangent.x * dir < 0.0:
				tangent = -tangent
			velocity += tangent * rope_swing_accel * delta
		velocity = velocity.limit_length(rope_max_speed)
	elif stance == Stance.SLIDE:
		if on_floor:
			velocity.x = move_toward(velocity.x, 0.0, slide_friction * delta)
	elif _flip_t >= 0.0:
		if dir != 0:
			velocity.x = move_toward(velocity.x, dir * walk_speed, acceleration * backflip_air_control * delta)
	else:
		var speed: float = walk_speed
		if stance == Stance.CROUCH:
			speed = crouch_speed
		elif _is_sprinting(dir):
			speed = run_speed
		var ctrl: float = 1.0 if on_floor else air_control
		if absf(velocity.x) > speed and ((dir == 0 and not on_floor) or signf(velocity.x) == dir):
			# Por encima de tu velocidad normal (slide, soga, empujón...) frenas suave
			velocity.x = move_toward(velocity.x, dir * speed, over_speed_decel * ctrl * delta)
		elif dir != 0:
			velocity.x = move_toward(velocity.x, dir * speed, acceleration * ctrl * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * ctrl * delta)

	_prev_fall_speed = velocity.y
	move_and_slide()
	if roped:
		_apply_rope_constraint()
	net_position = global_position

	_update_flip(delta)
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


# --- ESCONDITES ---

# Aviso del escondite cercano y tecla de esconderse/salir. Devuelve true si estás
# escondido (entonces no te mueves ni haces nada más).
func _update_hiding() -> bool:
	var near: Node2D = null
	if not escondido and is_on_floor() and stance != Stance.SLIDE:
		for spot in get_tree().get_nodes_in_group("hide_spots"):
			if spot.covers(global_position):
				near = spot
				break
	if near != _near_spot:
		if _near_spot and is_instance_valid(_near_spot):
			_near_spot.show_prompt(false)
		_near_spot = near
	if _near_spot:
		_near_spot.show_prompt(true, "%s · Esconderse" % Settings.key_for("hide"))
	if Input.is_action_just_pressed("hide") and not GameManager.input_blocked:
		if escondido:
			request_unhide.rpc_id(1)
		elif _near_spot:
			request_hide.rpc_id(1, _near_spot.get_path())
	if escondido:
		velocity = Vector2.ZERO
		net_position = global_position
	return escondido


@rpc("any_peer", "call_local", "reliable")
func request_hide(spot_path: NodePath) -> void:
	if not multiplayer.is_server() or _dead or escondido:
		return
	if _sender() != name.to_int():
		return
	var spot := get_node_or_null(spot_path)
	if spot == null or not spot.has_method("covers") or not spot.covers(global_position) or not spot.is_free():
		return
	spot.occupant = name.to_int()
	_set_hidden.rpc(true, spot_path)


@rpc("any_peer", "call_local", "reliable")
func request_unhide() -> void:
	if not multiplayer.is_server() or not escondido:
		return
	if _sender() != name.to_int():
		return
	if _hide_spot and is_instance_valid(_hide_spot):
		_hide_spot.occupant = 0
	_set_hidden.rpc(false, _hide_spot.get_path() if _hide_spot else NodePath())


# Quién llamó al RPC (en las llamadas locales Godot puede devolver 0)
func _sender() -> int:
	var id: int = multiplayer.get_remote_sender_id()
	return multiplayer.get_unique_id() if id == 0 else id


# Lo manda el servidor a todos
@rpc("any_peer", "call_local", "reliable")
func _set_hidden(on: bool, spot_path: NodePath) -> void:
	if _sender() != 1 or _dead:
		return
	escondido = on
	var spot := get_node_or_null(spot_path) if not spot_path.is_empty() else null
	if spot and spot.has_method("rustle"):
		spot.rustle()
	_play_sfx(sfx_pickup, step_range_walk * 0.5, -12.0)
	if on:
		_hide_spot = spot
		collision_layer = HIDDEN_LAYER
		if is_multiplayer_authority():
			rope_anchor = Vector2.ZERO
			_cancel_charge()
			velocity = Vector2.ZERO
			if spot:
				global_position = spot.global_position + Vector2(0.0, -11.0)
				net_position = global_position
	else:
		_hide_spot = null
		collision_layer = 2
	_apply_hidden_visual()


func _apply_hidden_visual() -> void:
	if _dead:
		return
	if is_multiplayer_authority():
		# Tú te ves en transparente; la linterna se apaga (te delataría)
		visual.modulate.a = 0.35 if escondido else 1.0
		hand_pivot.visible = not escondido
		if flashlight and Time.get_ticks_msec() >= _emp_until_msec:
			flashlight.enabled = not escondido
	else:
		visual.visible = not escondido
		hand_pivot.visible = not escondido
	$Polvo.emitting = not escondido


# Menú abierto en el lobby: el personaje se queda quieto (sin leer controles)
func _idle_physics(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * fall_gravity_mult * delta, max_fall_speed)
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	move_and_slide()
	net_position = global_position


# Gestiona enganche, escalada y desenganche. Devuelve true si hay soga puesta.
func _update_rope(delta: float) -> bool:
	if rope_anchor == Vector2.ZERO:
		if Input.is_action_just_pressed("rope") and Time.get_ticks_msec() >= _rope_ready_at \
				and stance != Stance.SLIDE and _flip_t < 0.0:
			_try_attach()
		return rope_anchor != Vector2.ZERO
	if not Input.is_action_pressed("rope") or _rope_blocked():
		rope_anchor = Vector2.ZERO
		if not is_on_floor():
			velocity *= rope_release_boost
		return false
	var old_len: float = _rope_len
	if Input.is_action_pressed("ui_up"):
		_rope_len = maxf(rope_min_length, _rope_len - rope_climb_speed * delta)
	elif Input.is_action_pressed("ui_down"):
		_rope_len = minf(rope_range, _rope_len + rope_climb_speed * delta)
	# Conservación del momento angular: al acortar la soga balanceándote, vas más rápido
	# (y al alargarla, más lento). Es lo que hace un columpio cuando "bombeas".
	if _rope_len != old_len and not is_on_floor():
		var n: Vector2 = (global_position - rope_anchor).normalized()
		var radial: Vector2 = n * velocity.dot(n)
		velocity = radial + (velocity - radial) * (old_len / _rope_len)
	return true


func _try_attach() -> void:
	var dir := Vector2.RIGHT.rotated(aim_angle)
	# Capa 1 (suelo/paredes) + capa 4 (plataformas atravesables)
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + dir * rope_range, 1 | 8)
	query.hit_from_inside = false
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		_rope_ready_at = Time.get_ticks_msec() + int(rope_miss_cooldown * 1000.0)
		# Aviso visual de que la soga ha salido pero no ha enganchado nada
		_rope_miss_end = global_position + dir * rope_range
		_rope_miss_until = Time.get_ticks_msec() + 150
		return
	rope_anchor = result.position
	_rope_len = maxf(global_position.distance_to(rope_anchor), rope_min_length)


# Algo se ha puesto en medio de la soga (esquina): se suelta
func _rope_blocked() -> bool:
	var to_anchor: Vector2 = rope_anchor - global_position
	if to_anchor.length() < 4.0:
		return false
	var end: Vector2 = rope_anchor - to_anchor.normalized() * 3.0
	var query := PhysicsRayQueryParameters2D.create(global_position, end, 1)
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


# La soga no se estira: si te pasas de largo, te devuelve al círculo y quita la
# velocidad que te alejaba (así sale el péndulo).
func _apply_rope_constraint() -> void:
	var off: Vector2 = global_position - rope_anchor
	var dist: float = off.length()
	if dist <= _rope_len or dist < 0.01:
		return
	var n: Vector2 = off / dist
	move_and_collide(-n * (dist - _rope_len))
	var away: float = velocity.dot(n)
	if away > 0.0:
		velocity -= n * away


func _read_dir() -> int:
	return int(signf(Input.get_axis("ui_left", "ui_right")))


# Sprint: doble toque de dirección (se mantiene mientras no sueltes) o stick a fondo
func _update_sprint(dir: int) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	for d in [-1, 1]:
		if Input.is_action_just_pressed("ui_left" if d < 0 else "ui_right"):
			if _tap_dir == d and now - _tap_time <= double_tap_time:
				_kb_sprint_dir = d
			_tap_dir = d
			_tap_time = now
	if dir == 0 or dir != _kb_sprint_dir:
		_kb_sprint_dir = 0


func _is_sprinting(dir: int) -> bool:
	if dir == 0 or stance != Stance.STAND:
		return false
	if _kb_sprint_dir == dir:
		return true
	for id in Input.get_connected_joypads():
		var x: float = Input.get_joy_axis(id, JOY_AXIS_LEFT_X)
		if absf(x) >= pad_sprint_threshold and int(signf(x)) == dir:
			return true
	return false


func _update_stance(on_floor: bool, dir: int, crouch_held: bool, crouch_pressed: bool) -> void:
	if _flip_t >= 0.0 or not on_floor:
		return
	match stance:
		Stance.STAND:
			if crouch_held:
				if crouch_pressed and absf(velocity.x) >= slide_min_speed:
					_start_slide()
				else:
					stance = Stance.CROUCH
		Stance.CROUCH:
			# (si el botón llega un frame después de empezar a agacharse, también vale)
			if crouch_pressed and absf(velocity.x) >= slide_min_speed:
				_start_slide()
			elif not crouch_held and _can_stand():
				stance = Stance.STAND
		Stance.SLIDE:
			# Te quedas tumbado hasta que te vuelvas a mover (o frenes y pulses dirección)
			var s: float = absf(velocity.x)
			var sd: int = int(signf(velocity.x))
			if dir != 0 and (s < slide_exit_speed or (sd != 0 and dir != sd)):
				stance = Stance.CROUCH
				if not crouch_held and _can_stand():
					stance = Stance.STAND


func _start_slide() -> void:
	velocity.x = signf(velocity.x) * maxf(absf(velocity.x), slide_speed)
	_kb_sprint_dir = 0
	stance = Stance.SLIDE


func _update_flip(delta: float) -> void:
	if _flip_t < 0.0:
		return
	_flip_t += delta
	if _flip_t >= backflip_time or (is_on_floor() and _flip_t > 0.12):
		_flip_t = -1.0
		visual.rotation = 0.0
	else:
		visual.rotation = -_flip_facing * TAU * (_flip_t / backflip_time)


# ¿Estoy de pie sobre una plataforma atravesable?
func _is_on_platform() -> bool:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i).get_collider()
		if c is CollisionObject2D and c.get_collision_layer_value(PLATFORM_LAYER):
			return true
	return false


func update_aiming(delta: float) -> void:
	if _flip_t < 0.0 and _dir != 0:
		facing = _dir

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

	# En el backflip el arma va pegada al cuerpo y gira con él
	if _flip_t >= 0.0:
		aim_angle = Vector2(_flip_facing, 0.0).rotated(visual.rotation).angle()
	hand_pivot.global_rotation = aim_angle
	# Agachado / deslizando el arma baja con el cuerpo
	var center := Vector2(0.0, _visual_base_y)
	var low: Vector2 = _hand_base + Vector2(0.0, _col.position.y - _col_base_y)
	hand_pivot.position = center + (low - center).rotated(visual.rotation)
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
	request_shoot.rpc_id(1, muzzle.global_position, aim_angle)

	# Retroceso que empuja al tirador (escopeta, francos, bazooka)
	if current_weapon_data.self_knockback_pct > 0.0:
		var push: Vector2 = -Vector2.RIGHT.rotated(aim_angle) * self_knockback_ref * current_weapon_data.self_knockback_pct / 100.0
		velocity += push
		if push.y < 0.0:
			_coyote_left = 0.0 # que no cuente como salto pegado al suelo

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
func request_shoot(pos: Vector2, rot: float) -> void:
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

	var wd := current_weapon_data
	for _i in wd.bullet_count:
		var bullet = wd.bullet_scene.instantiate()
		# Antes de añadirla: así viaja en el spawn y el cliente tirador la oculta
		if "shooter_id" in bullet: bullet.shooter_id = shooter
		_shots_fired += 1
		if "tracer" in bullet:
			bullet.tracer = wd.tracer_every > 0 and _shots_fired % wd.tracer_every == 0
			bullet.impact_size = wd.impact_size
			bullet.impact_trail = wd.impact_trail
		get_parent().add_child(bullet, true)
		bullet.global_position = pos

		var final_angle: float = rot + deg_to_rad(randf_range(-wd.spread, wd.spread))
		bullet.rotation = final_angle

		if bullet.has_method("launch"):
			bullet.launch(Vector2.RIGHT.rotated(final_angle) * wd.bullet_speed, shooter, wd.projectile_gravity)
		if "speed" in bullet: bullet.speed = wd.bullet_speed
		if "direction" in bullet: bullet.direction = Vector2.RIGHT.rotated(final_angle)


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
	if wd == null:
		return
	var mapache := get_node_or_null("Mapache")
	if mapache and mapache.has_method("on_shot"):
		mapache.on_shot()
	var flash_size: float = 0.0 if wd.silenced else wd.muzzle_flash
	Fx.muzzle(muzzle.global_position, aim_angle, flash_size)
	if wd.eject_casing:
		Fx.casing(hand_pivot.global_position + Vector2(facing * 6.0, -3.0), facing, wd.casing_color)
	if with_flash and flash_size > 0.0:
		muzzle_flash.energy = 1.2 + flash_size * 0.6
		muzzle_flash.texture_scale = 0.6 + flash_size * 0.25
		muzzle_flash.enabled = true
		await get_tree().create_timer(0.05).timeout
		muzzle_flash.enabled = false


# Balas "de mentira" solo visuales para el tirador cliente; la real llega con retraso
# y la tiene oculta (bullet.gd).
func _spawn_local_tracers() -> void:
	var wd := current_weapon_data
	for _i in wd.bullet_count:
		var t = TRACER_SCENE.instantiate()
		_local_shots += 1
		t.tracer = wd.tracer_every > 0 and _local_shots % wd.tracer_every == 0
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

# Empujón de las balas de juguete del lobby. Lo manda el servidor; lo aplica el dueño.
@rpc("any_peer", "call_local", "reliable")
func knockback_rpc(impulse: Vector2) -> void:
	var sender: int = multiplayer.get_remote_sender_id()
	if sender != 0 and sender != 1:
		return
	if is_multiplayer_authority():
		velocity += impulse
		_coyote_left = 0.0


func hit(shooter_id: int) -> void:
	if not multiplayer.is_server() or _dead:
		return
	# Muerte de un golpe. No hay reaparición: se vuelve en la siguiente ronda.
	# (Los puntos los reparte RoundManager al acabar la ronda, no las kills.)
	_dead = true
	if _hide_spot and is_instance_valid(_hide_spot):
		_hide_spot.occupant = 0
	_drop_current_weapon(Vector2(randf_range(-80.0, 80.0), -200.0))
	_drop_current_item(Vector2(randf_range(-80.0, 80.0), -200.0))
	death_fx_rpc.rpc(shooter_id)
	RoundManager.player_died(name.to_int())


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
	corpse.setup(visual, dir * corpse_force, get_node_or_null("Mapache"))
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
	_set_dead_local()


# Muerto hasta la siguiente ronda: sin cuerpo, sin luz, sin colisión, sin control
func _set_dead_local() -> void:
	_dead = true
	escondido = false
	if _near_spot and is_instance_valid(_near_spot):
		_near_spot.show_prompt(false)
	visual.visible = false
	hand_pivot.visible = false
	aura.enabled = false
	if flashlight:
		flashlight.enabled = false
	collision_layer = 0
	rope_anchor = Vector2.ZERO
	rope_line.visible = false
	rope_line_own.visible = false
	_col.set_deferred("disabled", true)
	velocity = Vector2.ZERO
	if is_multiplayer_authority():
		set_physics_process(false)
		throw_arc.clear_points()


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
	if Time.get_ticks_msec() >= _emp_until_msec and not escondido and not _dead:
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
