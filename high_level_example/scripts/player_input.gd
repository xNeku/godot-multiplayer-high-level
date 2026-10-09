extends RefCounted
class_name PlayerInput
# Entrada del jugador. Los humanos leen el teclado/mando (Input); los bots ponen
# las acciones a mano (virtual = true) y el jugador las lee igual, sin distinguir.

var virtual: bool = false
var _cur: Dictionary = {}
var _prev: Dictionary = {}


func pressed(action: StringName) -> bool:
	return _cur.get(action, false) if virtual else Input.is_action_pressed(action)


func just(action: StringName) -> bool:
	if virtual:
		return _cur.get(action, false) and not _prev.get(action, false)
	return Input.is_action_just_pressed(action)


func released(action: StringName) -> bool:
	if virtual:
		return _prev.get(action, false) and not _cur.get(action, false)
	return Input.is_action_just_released(action)


func axis(neg: StringName, pos: StringName) -> float:
	if virtual:
		return (1.0 if _cur.get(pos, false) else 0.0) - (1.0 if _cur.get(neg, false) else 0.0)
	return Input.get_axis(neg, pos)


# --- Solo bots ---

func set_action(action: StringName, on: bool) -> void:
	_cur[action] = on


func release_all() -> void:
	_cur = {}


# El jugador lo llama al final de cada frame de física (para "recién pulsado")
func end_frame() -> void:
	if virtual:
		_prev = _cur
		_cur = {}
