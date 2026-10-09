extends Node
# Autoload. Los puntos los calcula el servidor y se envían a todos los peers.

signal score_updated(id_jugador, puntos_nuevos)

var scores: Dictionary = {}

# Mapa elegido en el menú (ruta de la escena). Vacío = el que tenga la escena de juego.
var selected_map_path: String = ""
# Mapa JSON elegido (el texto entero: así viaja por red a los clientes). Tiene prioridad.
var selected_map_json: String = ""
# true mientras se está en el lobby (jugadores con pistola de juguete, sin rondas)
# Menú abierto (lobby con mando): el jugador local no lee los controles
var input_blocked: bool = false
var in_lobby: bool = false


# --- JUGADORES: COLORES ÚNICOS Y BOTS ---
# El servidor decide; todos tienen copia (se manda entera con _sync_roster).

# Los bots usan ids 100-199 (los de los jugadores de red son números enormes al azar)
const BOT_ID_MIN: int = 100
const BOT_ID_MAX: int = 199
const MAX_PLAYERS: int = 8

# id -> índice de color (Settings.PLAYER_COLORS). Nunca hay dos iguales.
var colors: Dictionary = {}
# ids de los bots de la partida
var bots: Array = []


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(func(): colors.clear(); bots.clear())


static func is_bot_id(id: int) -> bool:
	return id >= BOT_ID_MIN and id <= BOT_ID_MAX


# Nombre para mostrar en esta máquina ("Tú" si es el jugador local)
func display_name(id: int) -> String:
	if id == multiplayer.get_unique_id():
		return "Tú"
	return public_name(id)


# Nombre igual para todos (textos que manda el servidor)
func public_name(id: int) -> String:
	if is_bot_id(id):
		return "Bot %d" % (id - BOT_ID_MIN + 1)
	return "Jugador %d" % (id % 1000)


func color_of(id: int) -> int:
	return int(colors.get(id, 0))


# Cada jugador pide su color al entrar al lobby y al pulsar un color
@rpc("any_peer", "call_local", "reliable")
func request_color(preferred: int) -> void:
	if not multiplayer.is_server():
		return
	var id: int = multiplayer.get_remote_sender_id()
	if id == 0:
		id = 1
	_assign_color(id, preferred)
	_sync_roster.rpc(colors, bots)


func _assign_color(id: int, preferred: int) -> void:
	var n: int = Settings.PLAYER_COLORS.size()
	for k in n:
		var c: int = (preferred + k) % n
		if not _color_taken(c, id):
			colors[id] = c
			return


func _color_taken(c: int, except_id: int) -> bool:
	for other in colors:
		if other != except_id and int(colors[other]) == c:
			return true
	return false


# Solo servidor. Devuelve el id del bot nuevo (o -1 si no cabe).
func add_bot() -> int:
	if not multiplayer.is_server() or colors.size() >= MAX_PLAYERS:
		return -1
	for id in range(BOT_ID_MIN, BOT_ID_MAX + 1):
		if not bots.has(id):
			bots.append(id)
			_assign_color(id, randi() % Settings.PLAYER_COLORS.size())
			_sync_roster.rpc(colors, bots)
			return id
	return -1


# Solo servidor. Quita el último bot y devuelve su id (o -1).
func remove_bot() -> int:
	if not multiplayer.is_server() or bots.is_empty():
		return -1
	var id: int = bots.pop_back()
	colors.erase(id)
	_sync_roster.rpc(colors, bots)
	return id


func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server() and colors.has(id):
		colors.erase(id)
		_sync_roster.rpc(colors, bots)


@rpc("authority", "call_local", "reliable")
func _sync_roster(c: Dictionary, b: Array) -> void:
	colors = c
	bots = b


# Solo se llama en el servidor. Devuelve los puntos del jugador.
func add_point(player_id) -> int:
	var id := str(player_id)
	var points: int = scores.get(id, 0) + 1
	_sync_score.rpc(id, points)
	return points


@rpc("authority", "call_local", "reliable")
func _sync_score(id: String, points: int) -> void:
	scores[id] = points
	score_updated.emit(id, points)


# Solo el servidor. Resta un punto (nunca baja de 0).
func remove_point(player_id) -> int:
	var id := str(player_id)
	var points: int = maxi(scores.get(id, 0) - 1, 0)
	_sync_score.rpc(id, points)
	return points


# Se llama en todos los peers al empezar partida
func reset_scores() -> void:
	scores.clear()


# Punto de aparición aleatorio. Cada mapa tiene Marker2D en el grupo "spawn_points".
# Punto de aparición sin repetir: todos los peers calculan lo mismo (misma lista de
# jugadores y misma ronda), así nadie aparece encima de otro. Cambia en cada ronda.
func get_spawn_position(id: int = 0) -> Vector2:
	var points := get_tree().get_nodes_in_group("spawn_points")
	if points.is_empty():
		return Vector2(randf_range(100, 1100), randf_range(100, 500))
	points.sort_custom(func(a, b): return String(a.name) < String(b.name))
	var order: Array = colors.keys()
	order.sort()
	var idx: int = order.find(id)
	if idx < 0:
		return (points.pick_random() as Node2D).global_position
	var rng := RandomNumberGenerator.new()
	rng.seed = RoundManager.round_number * 7919 + points.size()
	for i in range(points.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = points[i]
		points[i] = points[j]
		points[j] = tmp
	return (points[idx % points.size()] as Node2D).global_position
