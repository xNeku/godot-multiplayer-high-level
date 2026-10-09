extends AnimatedSprite2D
# Animaciones del mapache (sprites provisionales, de frente). Decide qué animación
# toca a partir de lo que ya se sincroniza del jugador (posición, postura y giro del
# cuerpo), así que funciona igual para el jugador local y para los remotos.
# El cuerpo por piezas (nodo Cuerpo) sigue existiendo para la lógica (giro del
# backflip, sincronización, escondites, muerte); aquí solo se ocultan sus dibujos.

# Desactívalo para volver al muñeco por piezas
@export var usar_mapache: bool = true:
	set(v):
		usar_mapache = v
		if is_node_ready():
			_apply_toggle()

@export_group("Umbrales")
# Velocidad horizontal (px/s) a partir de la que anda y corre (sprint)
@export var walk_threshold: float = 12.0
@export var run_threshold: float = 175.0
# Velocidad vertical para considerar que está en el aire
@export var air_threshold: float = 45.0
# Frame 0 del salto al aterrizar (agachado del impacto)
@export var land_time: float = 0.09

# Velocidad de caída (px/s) a partir de la que el aterrizaje es "fuerte" (animación land)
@export var hard_land_speed: float = 330.0

@export_group("Brazo")
# Hombro respecto al centro del jugador mirando a la derecha (en el frame 19x27 es el
# píxel (14,18)). Mirando a la izquierda se espeja.
@export var shoulder: Vector2 = Vector2(5, 2)
@export var shoulder_left: Vector2 = Vector2(-4, 2)

@export_group("Tiempos (segundos por frame)")
@export var crouch_frame_time: float = 0.12
@export var crouch_breath_time: float = 0.35
@export var slide_frame_time: float = 0.11

enum Mode { LOOP, JUMP, LAND, HARD_LAND, CROUCH_IN, CROUCH_HOLD, CROUCH_OUT, SLIDE, FLIP, HANG }

var _player: Node2D
var _body: Node2D
var _hand: Node2D
var _last_pos: Vector2
var _vel := Vector2.ZERO
var _mode: int = Mode.LOOP
var _t: float = 0.0
var _was_air: bool = false
var _prev_stance: int = 0
var _peak_fall: float = 0.0
var _shot_t: float = -1.0
@onready var tint: AnimatedSprite2D = $Tinte
var _arm: Sprite2D
var _old_hand: CanvasItem


func _ready() -> void:
	_player = get_parent()
	_body = _player.get_node("Cuerpo")
	_hand = _player.get_node("HandPivot")
	_arm = _hand.get_node_or_null("Brazo")
	_old_hand = _hand.get_node_or_null("ManoArma")
	_last_pos = _player.global_position
	_apply_toggle()


func _apply_toggle() -> void:
	visible = usar_mapache
	for piece in _body.get_children():
		(piece as CanvasItem).visible = not usar_mapache
	if _arm:
		_arm.visible = usar_mapache
	if _old_hand:
		_old_hand.visible = not usar_mapache


# Lo llama el jugador al disparar (en todos los peers): retroceso del cuerpo y del brazo
func on_shot() -> void:
	_shot_t = 0.0


func _process(delta: float) -> void:
	if not usar_mapache or delta <= 0.0:
		return
	# Mismo estado de visibilidad que el cuerpo (muerto, escondido, transparente)
	visible = _body.visible
	modulate.a = _body.modulate.a
	# Solo el pecho (capa de tinte) lleva el color del jugador
	var idx: int = clampi(int(_player.get("color_index")), 0, Settings.PLAYER_COLORS.size() - 1)
	tint.self_modulate = Settings.PLAYER_COLORS[idx]

	var pos: Vector2 = _player.global_position
	_vel = _vel.lerp((pos - _last_pos) / delta, 0.35)
	_last_pos = pos
	var facing: int = -1 if _body.scale.x < 0.0 else 1
	var airborne: bool = absf(_vel.y) > air_threshold
	var stance: int = int(_player.get("stance"))
	var flipping: bool = absf(_body.rotation) > 0.05
	var roped: bool = _player.get("rope_anchor") != Vector2.ZERO
	_t += delta
	if airborne:
		_peak_fall = maxf(_peak_fall, _vel.y)
	# El brazo sale del hombro (el jugador local lo usa para colocar el arma)
	if _player.is_multiplayer_authority():
		_player.set("_hand_base", shoulder if facing > 0 else shoulder_left)
	if _arm:
		_arm.frame = 1 if _shot_t >= 0.0 and _shot_t < 0.07 else 0

	# Backflip: pose de bola (frame 0) girada para que los pies apunten al arma
	if flipping:
		_set_mode(Mode.FLIP)
		_show("backflip", 0)
		flip_h = false
		rotation = _hand.global_rotation - PI * 0.5
		_was_air = true
		_sync_tint()
		return
	rotation = 0.0
	flip_h = facing < 0

	# Colgado: el jugador local sabe si toca suelo; los remotos lo deducen del movimiento
	var hanging: bool = roped and (not _player.is_on_floor() if _player.is_multiplayer_authority() else (airborne or _vel.length() > 40.0))
	if hanging:
		_set_mode(Mode.HANG)
		if animation != &"hang" or not is_playing():
			play(&"hang")
	elif stance == 2: # SLIDE
		if _mode != Mode.SLIDE:
			_set_mode(Mode.SLIDE)
		var f: int = int(_t / slide_frame_time)
		_show("slide", f if f < 2 else 2 + (f % 2))
	elif stance == 1: # CROUCH
		if _mode != Mode.CROUCH_IN and _mode != Mode.CROUCH_HOLD:
			_set_mode(Mode.CROUCH_IN)
		if _mode == Mode.CROUCH_IN:
			var f: int = int(_t / crouch_frame_time)
			if f >= 2:
				_set_mode(Mode.CROUCH_HOLD)
			_show("crouch", mini(f, 2))
		else:
			_show("crouch", 2 + int(_t / crouch_breath_time) % 2)
	elif airborne:
		_set_mode(Mode.JUMP)
		var fr: int = 2
		if _vel.y < -120.0:
			fr = 1
		elif _vel.y > 120.0:
			fr = 3
		_show("jump", fr)
	elif _prev_stance == 1 and _mode != Mode.CROUCH_OUT:
		_set_mode(Mode.CROUCH_OUT)
		_show("crouch", 2)
	elif _mode == Mode.CROUCH_OUT:
		var f: int = 2 - int(_t / crouch_frame_time)
		if f < 0:
			_set_mode(Mode.LOOP)
		else:
			_show("crouch", f)
	elif _was_air:
		_set_mode(Mode.HARD_LAND if _peak_fall > hard_land_speed else Mode.LAND)
		_peak_fall = 0.0
	if _mode == Mode.HARD_LAND:
		var f: int = int(_t / 0.11)
		if f > 1:
			_set_mode(Mode.LOOP)
		else:
			_show("land", f)
	if _mode == Mode.LAND:
		if _t >= land_time:
			_set_mode(Mode.LOOP)
		else:
			_show("jump", 0)
	if _mode == Mode.LOOP:
		var speed: float = absf(_vel.x)
		var anim: StringName = &"idle"
		if speed > run_threshold:
			anim = &"run"
		elif speed > walk_threshold:
			anim = &"walk"
		# Retroceso del disparo encima de idle/andar/correr (2 frames de 70 ms)
		if _shot_t >= 0.0 and _shot_t < 0.14:
			_show("shoot", int(_shot_t / 0.07))
		elif animation != anim or not is_playing():
			play(anim)
	if _shot_t >= 0.0:
		_shot_t += delta
		if _shot_t > 0.3:
			_shot_t = -1.0
	_was_air = airborne
	_prev_stance = stance
	_sync_tint()


# La capa de tinte copia animación, frame, giro y volteo del mapache
func _sync_tint() -> void:
	if tint.animation != animation:
		tint.animation = animation
	tint.frame = frame
	tint.flip_h = flip_h

func _set_mode(m: int) -> void:
	if _mode != m:
		_mode = m
		_t = 0.0


# Frame fijo de una animación (sin reproducirla)
func _show(anim: StringName, f: int) -> void:
	if animation != anim:
		animation = anim
	if is_playing():
		stop()
	frame = clampi(f, 0, sprite_frames.get_frame_count(anim) - 1)
