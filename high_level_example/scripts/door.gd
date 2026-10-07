extends StaticBody2D
# Puerta automática: se abre sola cuando un jugador se acerca y se cierra
# cuando no queda nadie cerca. No hay que pulsar nada. Se comporta igual en
# todos los peers porque todos tienen a todos los jugadores en su escena.

@export var open_time: float = 0.18
@export var close_delay: float = 0.5

@onready var leaf: Node2D = $Hoja
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var occluder: LightOccluder2D = $LightOccluder2D
@onready var zone: Area2D = $Zona

var _inside: int = 0
var _open: bool = false
var _tween: Tween


func _ready() -> void:
	zone.body_entered.connect(_on_body_entered)
	zone.body_exited.connect(_on_body_exited)


func _on_body_entered(_body: Node2D) -> void:
	_inside += 1
	_set_open(true)


func _on_body_exited(_body: Node2D) -> void:
	_inside = maxi(_inside - 1, 0)
	if _inside == 0:
		await get_tree().create_timer(close_delay).timeout
		if _inside == 0:
			_set_open(false)


func _set_open(value: bool) -> void:
	if value == _open:
		return
	_open = value
	collision.set_deferred("disabled", value)
	occluder.visible = not value
	if _tween:
		_tween.kill()
	_tween = create_tween()
	# La hoja sube y se encoge hacia arriba al abrir
	_tween.tween_property(leaf, "scale:y", 0.0 if value else 1.0, open_time)
