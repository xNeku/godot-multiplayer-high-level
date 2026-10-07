extends Node2D
# Parte visual del jugador (cuerpo en piezas). Se anima solo por código a partir
# de cómo se mueve el nodo padre, así funciona igual para el jugador local y para
# los remotos (que solo reciben la posición). No toca la lógica de juego.

@export_group("Tamaño")
@export var base_scale: float = 0.6

@export_group("Andar")
# Píxeles recorridos por paso (menos = pasos más rápidos)
@export var step_length: float = 26.0
@export var foot_swing: float = 6.0
@export var foot_lift: float = 4.0
@export var hand_swing: float = 5.0
@export var walk_bob: float = 1.5

@export_group("Aire")
@export var air_foot_lift: float = 4.0
@export var air_hand_lift: float = 5.0
@export var air_stretch: float = 0.12

@export_group("Reposo")
@export var breath_speed: float = 2.2
@export var breath_amount: float = 0.025

@onready var foot_l: Sprite2D = $Pies/PieIzq
@onready var foot_r: Sprite2D = $Pies/PieDer
@onready var torso: Sprite2D = $Torso
@onready var head: Sprite2D = $Cabeza
@onready var free_hand: Sprite2D = $ManoLibre

var _rest := {}
var _last_pos: Vector2
var _vel := Vector2.ZERO
var _phase := 0.0
var _walk := 0.0
var _air := 0.0
var _time := 0.0


func _ready() -> void:
	for s in [foot_l, foot_r, torso, head, free_hand]:
		_rest[s] = s.position
	scale = Vector2(base_scale, base_scale)
	_last_pos = (get_parent() as Node2D).global_position


# 1 = mira a la derecha, -1 = izquierda
func set_facing(facing: int) -> void:
	scale = Vector2(base_scale * facing, base_scale)


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_time += delta
	var pos: Vector2 = (get_parent() as Node2D).global_position
	_vel = _vel.lerp((pos - _last_pos) / delta, 0.35)
	_last_pos = pos

	var speed: float = absf(_vel.x)
	var airborne: bool = absf(_vel.y) > 45.0
	var moving: bool = speed > 12.0 and not airborne

	if moving:
		_phase += speed * delta / step_length * TAU
	_walk = move_toward(_walk, 1.0 if moving else 0.0, delta * 9.0)
	_air = move_toward(_air, 1.0 if airborne else 0.0, delta * 12.0)

	var s: float = sin(_phase)
	var c: float = cos(_phase)

	# Pies: uno adelanta y se levanta mientras el otro empuja
	foot_l.position = _rest[foot_l] + Vector2(s * foot_swing * _walk, -maxf(0.0, c) * foot_lift * _walk)
	foot_r.position = _rest[foot_r] + Vector2(-s * foot_swing * _walk, -maxf(0.0, -c) * foot_lift * _walk)
	# En el aire los pies se recogen
	foot_l.position += Vector2(-1.5, -air_foot_lift) * _air
	foot_r.position += Vector2(1.5, -air_foot_lift * 0.6) * _air

	# Mano libre: contrabalancea al pie contrario
	free_hand.position = _rest[free_hand] + Vector2(0.0, 0.0)
	free_hand.position.x += -s * hand_swing * _walk
	free_hand.position.y += -air_hand_lift * _air + absf(s) * 1.0 * _walk

	# Cuerpo: rebote al andar, respiración en reposo, estiramiento en el aire
	var bob: float = -absf(s) * walk_bob * _walk
	var breath: float = sin(_time * breath_speed) * breath_amount * (1.0 - _walk)
	var stretch: float = clampf(-_vel.y / 900.0, -1.0, 1.0) * air_stretch * _air
	torso.position = _rest[torso] + Vector2(0.0, bob)
	torso.scale = Vector2(1.0 - stretch * 0.5, 1.0 + breath + stretch)
	# La cabeza llega un poco tarde, da sensación de peso
	var head_bob: float = -absf(sin(_phase - 0.5)) * walk_bob * _walk
	head.position = _rest[head] + Vector2(0.0, head_bob + sin(_time * breath_speed - 0.4) * 0.6 * (1.0 - _walk))
	head.scale = Vector2(1.0 - stretch * 0.4, 1.0 + stretch * 0.8)
