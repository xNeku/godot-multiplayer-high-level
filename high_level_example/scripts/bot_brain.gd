extends Node
# Cerebro de un bot. Vive SOLO en el servidor, como hijo del jugador-bot, y cada
# frame de física decide qué "teclas" pulsa (me.input, virtual). El jugador hace el
# resto igual que con una persona: física, disparos, red...
#
# Prioridades: 1) sin arma -> ir a por la más cercana; 2) enemigo a la vista ->
# encararlo, apuntar y disparar; 3) si no, patrullar o ir a donde lo vio por última vez.

@export_group("Dificultad")
# Segundos viendo a alguien antes de empezar a disparar
@export var reaction_time: float = 0.45
# Cuánto puede fallar el ángulo al disparar (grados)
@export var aim_tolerance_deg: float = 9.0
# Distancia a la que ve (de frente) y a la que nota a alguien aunque esté de espaldas
@export var vision_range: float = 300.0
@export var near_sense: float = 90.0
# Medio ángulo del cono de visión (grados)
@export var vision_half_angle_deg: float = 75.0

const REPATH_TIME: float = 0.6
const STUCK_TIME: float = 1.2

var me: CharacterBody2D
var _nav: BotNav
var _path: Array = []
var _goal_key: int = -1
var _repath_t: float = 0.0
var _stuck_t: float = 0.0
var _last_pos: Vector2
var _seen_t: float = 0.0
var _enemy: Node2D = null
var _last_seen: Vector2 = Vector2.ZERO
var _interact_cd: float = 0.0
var _jump_hold: float = 0.0
var _throw_hold: float = 0.0
var _patrol_key: int = -1
# Saltos que no le han salido: BotNav.edge_id -> instante hasta el que se evitan
var _bad_edges: Dictionary = {}
var _from_key: int = -1
# Armas a las que no sabe llegar: nodo -> instante hasta el que se ignoran
var _bad_pickups: Dictionary = {}
var _pickup: Node2D = null
# Progreso hacia el waypoint actual (si no se acerca en un rato, ese tramo no sale)
var _wp_key: int = -1
var _wp_best: float = INF
var _wp_t: float = 0.0
# Sin camino: deambula en una dirección un rato (saltando si choca) hasta salir del hoyo
var _wander_dir: int = 1
var _wander_t: float = 0.0
var _map: Node = null


func _ready() -> void:
	me = get_parent()
	# Antes que el jugador, para que lea las teclas de este frame
	process_physics_priority = -10
	_last_pos = me.global_position


func _physics_process(delta: float) -> void:
	var inp: PlayerInput = me.input
	inp.release_all()
	if me._dead or not multiplayer.is_server():
		set_physics_process(false)
		return
	if not is_instance_valid(_map):
		_map = get_tree().get_first_node_in_group("map_settings")
	_nav = BotNav.for_map(_map)
	_interact_cd = maxf(0.0, _interact_cd - delta)

	_enemy = _find_enemy()
	if _enemy:
		_seen_t += delta
		_last_seen = _enemy.global_position
	else:
		_seen_t = 0.0

	var has_gun: bool = me.current_weapon_data != null and me.current_ammo != 0
	var goal := Vector2.ZERO
	var fighting := false

	if _enemy and has_gun:
		fighting = true
		_fight(inp, delta)
	elif not has_gun:
		var p := _nearest_pickup()
		_pickup = p
		if p:
			goal = p.global_position
			if me.global_position.distance_to(p.global_position) < me.interact_range * 0.8 and _interact_cd <= 0.0:
				inp.set_action(&"interact", true)
				_interact_cd = 0.5
	if not fighting and goal == Vector2.ZERO:
		if _last_seen != Vector2.ZERO:
			goal = _last_seen
			if me.global_position.distance_to(_last_seen) < 24.0:
				_last_seen = Vector2.ZERO
		else:
			goal = _patrol_goal()

	# Lanzar el objeto que lleve si hay alguien cerca a la vista
	if me.current_item and _enemy and me.global_position.distance_to(_enemy.global_position) < 230.0:
		_throw_hold = 0.3
	if _throw_hold > 0.0:
		_throw_hold -= delta
		inp.set_action(&"throw", _throw_hold > 0.0)

	if not fighting and goal != Vector2.ZERO:
		_move_to(goal, inp, delta)


# --- PERCEPCIÓN ---

func _find_enemy() -> Node2D:
	var best: Node2D = null
	var best_d: float = INF
	var space := me.get_world_2d().direct_space_state
	for p in get_tree().get_nodes_in_group("players"):
		if p == me or p._dead or p.escondido:
			continue
		var to: Vector2 = p.global_position - me.global_position
		var d: float = to.length()
		if d > vision_range or d >= best_d:
			continue
		# De espaldas solo nota a quien tiene muy cerca
		var ahead: float = Vector2(me.facing, 0.0).angle_to(to)
		if d > near_sense and absf(ahead) > deg_to_rad(vision_half_angle_deg):
			continue
		var q := PhysicsRayQueryParameters2D.create(me.global_position, p.global_position, 1)
		if not space.intersect_ray(q).is_empty():
			continue
		best = p
		best_d = d
	return best


func _nearest_pickup() -> Node2D:
	var best: Node2D = null
	var best_d: float = INF
	for p in get_tree().get_nodes_in_group("pickups"):
		if not p.is_available() or p.pickup_kind() != "weapon":
			continue
		if int(_bad_pickups.get(p.get_instance_id(), 0)) > Time.get_ticks_msec():
			continue
		var d: float = me.global_position.distance_to(p.global_position)
		if d < best_d:
			best = p
			best_d = d
	return best


# --- COMBATE ---

func _fight(inp: PlayerInput, delta: float) -> void:
	var to: Vector2 = _enemy.global_position - me.global_position
	var want_facing: int = 1 if to.x >= 0.0 else -1
	# Encararse (un toque de dirección gira al personaje)
	if me.facing != want_facing:
		inp.set_action(&"ui_right" if want_facing > 0 else &"ui_left", true)
		return
	# Ángulo deseado: el arma solo apunta de recto a vertical hacia arriba
	var muzzle: Vector2 = me.muzzle.global_position
	var desired: Vector2 = _enemy.global_position - muzzle
	var up_angle: float = clampf(atan2(-desired.y, absf(desired.x)), 0.0, PI * 0.5)
	var current_up: float = atan2(-sin(me.aim_angle), absf(cos(me.aim_angle)))
	# Subir el arma = mantener salto (como una persona); se suelta al pasarse
	if up_angle > deg_to_rad(12.0) and current_up < up_angle - deg_to_rad(4.0):
		inp.set_action(&"ui_up", true)
	# Mantener distancia: ni pegado ni demasiado lejos
	var d: float = to.length()
	if d > vision_range * 0.75:
		inp.set_action(&"ui_right" if want_facing > 0 else &"ui_left", true)
	if _seen_t >= reaction_time and absf(current_up - up_angle) <= deg_to_rad(aim_tolerance_deg):
		inp.set_action(&"shoot", true)


# --- MOVIMIENTO ---

func _patrol_goal() -> Vector2:
	if _nav == null:
		return me.global_position + Vector2(randf_range(-200.0, 200.0), 0.0) if randf() < 0.01 else Vector2.ZERO
	if _patrol_key < 0 or me.global_position.distance_to(_nav.key_pos(_patrol_key)) < 16.0:
		_patrol_key = _nav.random_key()
	return _nav.key_pos(_patrol_key) if _patrol_key >= 0 else Vector2.ZERO


func _move_to(goal: Vector2, inp: PlayerInput, delta: float) -> void:
	var pos: Vector2 = me.global_position
	# Atasco: si no avanza, salta y recalcula
	if pos.distance_to(_last_pos) < 2.0:
		_stuck_t += delta
	else:
		_stuck_t = 0.0
		_last_pos = pos
	if _stuck_t > STUCK_TIME:
		_stuck_t = 0.0
		# Ese tramo no sale: se evita un rato y se busca otro camino
		if _nav and not _path.is_empty() and _from_key >= 0:
			_bad_edges[_nav.edge_id(_from_key, _path[0][0])] = Time.get_ticks_msec() + 12000
		_path.clear()
		_jump_hold = 0.25
		_patrol_key = -1

	if _nav == null:
		_simple_move(goal, inp, delta)
		return

	_repath_t -= delta
	var gk: int = _nav.nearest_key(goal)
	if _repath_t <= 0.0 or gk != _goal_key or _path.is_empty():
		_repath_t = REPATH_TIME
		_goal_key = gk
		_from_key = _nav.nearest_key(pos)
		_path = _nav.path(_from_key, gk, _bad_edges)
		if _path.is_empty() and _from_key != gk:
			_patrol_key = -1 # destino al que no se llega: otro
			if _pickup and is_instance_valid(_pickup) and goal == _pickup.global_position:
				_bad_pickups[_pickup.get_instance_id()] = Time.get_ticks_msec() + 15000
	if _path.is_empty():
		_wander(inp, delta)
		return

	# Waypoint alcanzado
	var wp: Vector2 = _nav.key_pos(_path[0][0])
	if absf(wp.x - pos.x) < 4.0 and absf(wp.y - pos.y) < 8.0:
		_from_key = _path[0][0]
		_path.pop_front()
		if _path.is_empty():
			return
		wp = _nav.key_pos(_path[0][0])
	var edge: int = _path[0][1]
	var dx: float = wp.x - pos.x
	if _path[0][0] != _wp_key:
		_wp_key = _path[0][0]
		_wp_best = INF
		_wp_t = 0.0
	var dist: float = pos.distance_to(wp)
	if dist < _wp_best - 2.0:
		_wp_best = dist
		_wp_t = 0.0
	else:
		_wp_t += delta
		if _wp_t > 2.0:
			_wp_t = 0.0
			if _from_key >= 0:
				_bad_edges[_nav.edge_id(_from_key, _wp_key)] = Time.get_ticks_msec() + 15000
			_path.clear()
			_patrol_key = -1
			return
	if absf(dx) > 3.0:
		inp.set_action(&"ui_right" if dx > 0.0 else &"ui_left", true)
	match edge:
		BotNav.Edge.JUMP:
			# Si el salto es largo, primero se acerca; salta cerca del borde o si choca
			# Salto casi vertical (trampillas): hay que estar centrado debajo o se da con la cabeza
			var close: bool = absf(dx) <= 3.0 if absf(dx) <= _nav.bp * 1.5 else absf(dx) <= _nav.bp * 2.5
			if wp.y < pos.y - 4.0 and me.is_on_floor() and (close or me.is_on_wall()):
				_jump_hold = 0.35
			if absf(dx) > _nav.bp * 1.5:
				inp.set_action(&"sprint", true)
		BotNav.Edge.DROP:
			if me.is_on_floor():
				inp.set_action(&"ui_down", true)
				_jump_hold = 0.05
	if _jump_hold > 0.0:
		_jump_hold -= delta
		inp.set_action(&"ui_up", true)


func _wander(inp: PlayerInput, delta: float) -> void:
	_wander_t -= delta
	if _wander_t <= 0.0 or (me.is_on_wall() and me.is_on_floor() and randf() < 0.3):
		_wander_t = randf_range(1.5, 3.0)
		_wander_dir = -_wander_dir if randf() < 0.6 else _wander_dir
	inp.set_action(&"ui_right" if _wander_dir > 0 else &"ui_left", true)
	if me.is_on_floor() and me.is_on_wall():
		_jump_hold = 0.35
	if _jump_hold > 0.0:
		_jump_hold -= delta
		inp.set_action(&"ui_up", true)


# Sin mapa de rejilla (mapas de escena): ir en línea recta y saltar si choca
func _simple_move(goal: Vector2, inp: PlayerInput, delta: float) -> void:
	var dx: float = goal.x - me.global_position.x
	if absf(dx) > 6.0:
		inp.set_action(&"ui_right" if dx > 0.0 else &"ui_left", true)
	if me.is_on_floor() and (me.is_on_wall() or goal.y < me.global_position.y - 30.0):
		_jump_hold = 0.3
	if _jump_hold > 0.0:
		_jump_hold -= delta
		inp.set_action(&"ui_up", true)
