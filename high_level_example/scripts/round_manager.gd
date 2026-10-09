extends Node
# Autoload. Sistema de rondas (lo decide el servidor, los demás reciben por RPC).
#
# Flujo: se aparece sin nada en la mano, se coge lo que hay por el mapa y se juega.
# Cuando solo queda un jugador vivo la ronda no acaba al instante: hay END_GRACE
# segundos de margen, y si el último muere en ese tiempo nadie se lleva el punto.
# El superviviente gana +1 punto y se pasa a otro mapa. Gana quien llegue antes
# a POINTS_TO_WIN.

signal banner(text: String, seconds: float)

const MapLoader := preload("res://high_level_example/scripts/map_loader.gd")
const GAME_SCENE: String = "res://high_level_example/scenes/high_level_example.tscn"
const LOBBY_SCENE: String = "res://high_level_example/scenes/Lobby.tscn"

const POINTS_TO_WIN: int = 5
# Margen entre que queda uno vivo y que acaba la ronda (segundos)
const END_GRACE: float = 3.0
# Pausa mostrando el resultado antes de la siguiente ronda
const RETRY_TIME: float = 2.0
const BETWEEN_TIME: float = 3.0
# Con este número de jugadores o más, el primero en morir pierde 1 punto
const PENALTY_MIN_PLAYERS: int = 4

enum State { LOBBY, IDLE, PLAYING, ENDING, BETWEEN, OVER }

var round_number: int = 0
var state: int = State.LOBBY

# Solo en el servidor
var _alive: Array[int] = []
var _peak: int = 0 # máximo de jugadores vivos a la vez en esta ronda
var _first_dead: int = -1
var _used_maps: Array[String] = []
var _current_map_path: String = ""
var _end_timer: SceneTreeTimer


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)


# Una vez empezada la partida no se admite a nadie más (hasta volver al lobby)
func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server() and not GameManager.in_lobby:
		multiplayer.multiplayer_peer.disconnect_peer(id)


# --- Partida ---

# El servidor (lobby) lanza la partida. Todos cargan el primer mapa.
func start_match(scene_path: String, map_json: String) -> void:
	if multiplayer.is_server():
		_start_match.rpc(scene_path, map_json)


@rpc("authority", "call_local", "reliable")
func _start_match(scene_path: String, map_json: String) -> void:
	GameManager.reset_scores()
	GameManager.in_lobby = false
	begin_match()
	GameManager.selected_map_json = map_json
	GameManager.selected_map_path = ""
	# Mapa de escena antiguo: solo los que ofrece el lobby
	var lobby := get_tree().current_scene
	if map_json == "" and "maps" in lobby:
		for scene in lobby.maps:
			if scene.resource_path == scene_path:
				GameManager.selected_map_path = scene_path
	get_tree().change_scene_to_file(GAME_SCENE)


@rpc("authority", "call_local", "reliable")
func _return_to_lobby() -> void:
	GameManager.in_lobby = true
	GameManager.selected_map_json = ""
	GameManager.selected_map_path = ""
	GameManager.reset_scores()
	state = State.LOBBY
	_reset_round_state()
	get_tree().change_scene_to_file(LOBBY_SCENE)


func enter_lobby() -> void:
	state = State.LOBBY
	GameManager.in_lobby = true
	_reset_round_state()


# Lo llama el menú en TODOS los peers al empezar la partida
func begin_match() -> void:
	round_number = 1
	state = State.IDLE
	_reset_round_state()


# El host elige el mapa de la primera ronda ("" = aleatorio entre los JSON).
# Devuelve el texto del JSON, o "" si no hay.
func pick_first_map(path: String) -> String:
	_used_maps.clear()
	if path == "":
		return _pick_random_map()
	_current_map_path = path
	_used_maps.append(path)
	return MapLoader.read_text(path)


func _reset_round_state() -> void:
	_alive.clear()
	_peak = 0
	_first_dead = -1
	if _end_timer:
		_end_timer = null


# --- Registro de jugadores (servidor) ---

func register_player(id: int) -> void:
	if not multiplayer.is_server() or state == State.OVER or state == State.LOBBY:
		return
	if not _alive.has(id):
		_alive.append(id)
	_peak = maxi(_peak, _alive.size())
	if state != State.PLAYING and state != State.ENDING:
		state = State.PLAYING


# Se fue (desconexión) o se borró el nodo
func player_left(id: int) -> void:
	if not multiplayer.is_server():
		return
	_remove_alive(id, false)


# El servidor llama esto cuando un jugador muere
func player_died(id: int) -> void:
	if not multiplayer.is_server():
		return
	_remove_alive(id, true)


func _remove_alive(id: int, died: bool) -> void:
	if not _alive.has(id):
		return
	_alive.erase(id)
	if died and _first_dead == -1:
		_first_dead = id
	_check_round_end()


func _check_round_end() -> void:
	if state != State.PLAYING and state != State.ENDING:
		return
	# Con un solo jugador (pruebas): si mueres, se repite la ronda en el mismo mapa
	if _peak < 2:
		if _alive.is_empty() and state == State.PLAYING:
			state = State.BETWEEN
			_banner.rpc("Has muerto. Otra vez...", RETRY_TIME)
			await get_tree().create_timer(RETRY_TIME).timeout
			if state == State.BETWEEN:
				_start_round.rpc("")
		return
	if _alive.size() <= 1 and state == State.PLAYING:
		state = State.ENDING
		if _alive.size() == 1:
			_banner.rpc("¡Último en pie!", END_GRACE)
		_end_timer = get_tree().create_timer(END_GRACE)
		_end_timer.timeout.connect(_resolve_round.bind(_end_timer))
	elif _alive.size() == 0 and state == State.ENDING:
		# El último murió dentro del margen: no hay ganador
		_banner.rpc("Empate, nadie suma", END_GRACE)


func _resolve_round(timer: SceneTreeTimer) -> void:
	if timer != _end_timer or state != State.ENDING:
		return
	state = State.BETWEEN
	var winner: int = _alive[0] if _alive.size() == 1 else -1
	var text := "Empate, nadie suma"
	if winner != -1:
		var pts: int = GameManager.add_point(winner)
		text = "Gana el jugador %d  (+1)" % winner
		if _peak >= PENALTY_MIN_PLAYERS and _first_dead != -1 and _first_dead != winner:
			GameManager.remove_point(_first_dead)
		if pts >= POINTS_TO_WIN:
			state = State.OVER
			_game_over.rpc(winner)
			return
	_banner.rpc(text, BETWEEN_TIME)
	await get_tree().create_timer(BETWEEN_TIME).timeout
	if state == State.BETWEEN:
		_next_round()


func _next_round() -> void:
	var text := _pick_random_map()
	_start_round.rpc(text)


# Mapa JSON al azar que no se haya usado (cuando se agotan, se vuelve a empezar).
func _pick_random_map() -> String:
	var all: Array = MapLoader.list_maps()
	if all.is_empty():
		return ""
	var free: Array = all.filter(func(x): return not _used_maps.has(x["path"]))
	if free.is_empty():
		_used_maps.clear()
		if _current_map_path != "":
			_used_maps.append(_current_map_path)
		free = all.filter(func(x): return not _used_maps.has(x["path"]))
		if free.is_empty():
			free = all # solo hay un mapa
	var m: Dictionary = free.pick_random()
	_current_map_path = m["path"]
	_used_maps.append(m["path"])
	return MapLoader.read_text(m["path"])


# --- RPC (el servidor manda, todos reciben) ---

@rpc("authority", "call_local", "reliable")
func _start_round(map_json: String) -> void:
	round_number += 1
	_reset_round_state()
	state = State.IDLE
	if map_json != "":
		GameManager.selected_map_json = map_json
		GameManager.selected_map_path = ""
	get_tree().change_scene_to_file(GAME_SCENE)


@rpc("authority", "call_local", "reliable")
func _banner(text: String, seconds: float) -> void:
	banner.emit(text, seconds)


@rpc("authority", "call_local", "reliable")
func _game_over(winner_id: int) -> void:
	state = State.OVER
	var level := get_tree().current_scene
	if level.has_method("end_game_sequence"):
		level.end_game_sequence(winner_id)
	if multiplayer.is_server():
		await get_tree().create_timer(6.0).timeout
		_return_to_lobby.rpc()
