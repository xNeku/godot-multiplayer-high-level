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

@export_group("Tiempos (segundos por frame)")
@export var crouch_frame_time: float = 0.12
@export var crouch_breath_time: float = 0.35
@export var slide_frame_time: float = 0.11

enum Mode { LOOP, JUMP, LAND, CROUCH_IN, CROUCH_HOLD, CROUCH_OUT, SLIDE, FLIP }

var _player: Node2D
var _body: Node2D
var _hand: Node2D
var _last_pos: Vector2
var _vel := Vector2.ZERO
var _mode: int = Mode.LOOP
var _t: float = 0.0
var _was_air: bool = false
var _prev_stance: int = 0


func _ready() -> void:
	_player = get_parent()
	_body = _player.get_node("Cuerpo")
	_hand = _player.get_node("HandPivot")
	_last_pos = _player.global_position
	_apply_toggle()


func _apply_toggle() -> void:
	visible = usar_mapache
	for piece in _body.get_children():
		(piece as CanvasItem).visible = not usar_mapache


func _process(delta: float) -> void:
	if not usar_mapache or delta <= 0.0:
		return
	# Mismo estado de visibilidad que el cuerpo (muerto, escondido, transparente)
	visible = _body.visible
	modulate.a = _body.modulate.a
	var idx: int = clampi(int(_player.get("color_index")), 0, Settings.PLAYER_COLORS.size() - 1)
	self_modulate = Settings.PLAYER_COLORS[idx]

	var pos: Vector2 = _player.global_position
	_vel = _vel.lerp((pos - _last_pos) / delta, 0.35)
	_last_pos = pos
	var facing: int = -1 if _body.scale.x < 0.0 else 1
	var airborne: bool = absf(_vel.y) > air_threshold
	var stance: int = int(_player.get("stance"))
	var flipping: bool = absf(_body.rotation) > 0.05
	_t += delta

	# Backflip: pose de bola (frame 0) girada para que los pies apunten al arma
	if flipping:
		_set_mode(Mode.FLIP)
		_show("backflip", 0)
		flip_h = false
		rotation = _hand.global_rotation - PI * 0.5
		_was_air = true
		return
	rotation = 0.0
	flip_h = facing < 0

	if stance == 2: # SLIDE
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
		_set_mode(Mode.LAND)
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
		if animation != anim or not is_playing():
			play(anim)
	_was_air = airborne
	_prev_stance = stance


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
