extends RefCounted
class_name BotNav
# Grafo de navegación para los bots sobre la rejilla de un mapa JSON.
# Nodo = casilla donde el personaje puede estar de pie (pies sobre suelo o plataforma,
# 2 casillas libres encima). Aristas: andar (cayendo si hace falta), saltar (hasta
# 4 arriba y 4 de lado) y bajar por plataforma. Se construye una vez por mapa y se
# rehace si el terreno cambia (explosiones).

const JUMP_UP: int = 4
const JUMP_SIDE: int = 4

enum Edge { WALK, JUMP, DROP }

var w: int
var h: int
var bp: float
var grid: PackedByteArray
var version: int = -1
# key (y * w + x) -> Array de [key_destino, tipo]
var adj: Dictionary = {}


static func for_map(map: Node) -> BotNav:
	if map == null or not map.has_meta("tiles"):
		return null
	var t: Dictionary = map.get_meta("tiles")
	var nav: BotNav = map.get_meta("bot_nav", null)
	if nav == null or nav.version != int(t.get("ver", 0)):
		nav = BotNav.new()
		nav._build(t)
		map.set_meta("bot_nav", nav)
	return nav


func _build(t: Dictionary) -> void:
	w = t["w"]
	h = t["h"]
	bp = float(t["bp"])
	grid = t["grid"]
	version = int(t.get("ver", 0))
	adj.clear()
	for y in h:
		for x in w:
			if _stand(x, y):
				adj[y * w + x] = _edges(x, y)


func _cell(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= w or y >= h:
		return 1
	return grid[y * w + x]


func _free(x: int, y: int) -> bool:
	return _cell(x, y) != 1


func _support(x: int, y: int) -> bool:
	return y + 1 < h and _cell(x, y + 1) != 0


func _stand(x: int, y: int) -> bool:
	return _free(x, y) and _free(x, y - 1) and _support(x, y)


func _fall(x: int, y: int) -> int:
	while y + 1 < h and not _support(x, y):
		y += 1
		if not _free(x, y):
			return -1
	return y if _stand(x, y) else -1


# Saliente por encima de la cabeza en la columna de al lado (libre a la altura del
# cuerpo pero sólido más arriba): al subir recto, el personaje se daría con él.
# Una pared continua no cuenta (el cuerpo ya está apartado de ella).
func _lip(cx: int, y: int, r: int) -> bool:
	return not _free(cx, r) and _free(cx, y)


func _edges(x: int, y: int) -> Array:
	var out: Array = []
	for dx in [-1, 1]:
		if _free(x + dx, y) and _free(x + dx, y - 1):
			var fy: int = _fall(x + dx, y)
			if fy >= 0:
				out.append([fy * w + x + dx, Edge.WALK])
	if _cell(x, y + 1) == 2:
		var dy: int = _fall(x, y + 1)
		if dy >= 0:
			out.append([dy * w + x, Edge.DROP])
	# Subida: el personaje mide algo más de 1 casilla de ancho, así que por encima de
	# su cabeza también tienen que estar libres las columnas de al lado (si no, se da
	# con el borde de la trampilla)
	var top: int = y
	for k in range(1, JUMP_UP + 1):
		var r: int = y - 1 - k
		if _free(x, r) and not _lip(x - 1, y, r) and not _lip(x + 1, y, r):
			top = y - k
		else:
			break
	for ty in range(top, y):
		# Cuanto más alto, menos alcance lateral (el salto no da para todo a la vez)
		var up: int = y - ty
		var side: int = JUMP_SIDE if up <= 2 else (3 if up == 3 else 2)
		for dx in range(-side, side + 1):
			var tx: int = x + dx
			if not _stand(tx, ty):
				continue
			var clear := true
			for xx in range(mini(x, tx), maxi(x, tx) + 1):
				if not (_free(xx, ty) and _free(xx, ty - 1)):
					clear = false
					break
			if clear:
				out.append([ty * w + tx, Edge.JUMP])
	return out


# Casilla (x, y) de los pies de alguien en posición global (el origen del jugador es su centro)
func cell_of(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / bp)), int(floor((pos.y + 10.0) / bp)))


# Nodo más cercano a una posición (busca hacia abajo y a los lados)
func nearest_key(pos: Vector2) -> int:
	var c := cell_of(pos)
	for r in 6:
		for dy in range(0, 8):
			for dx in [0, -r, r]:
				var k: int = (c.y + dy) * w + c.x + dx
				if adj.has(k):
					return k
	return -1


func key_pos(k: int) -> Vector2:
	var x: int = k % w
	var y: int = k / w
	return Vector2((x + 0.5) * bp, (y + 1) * bp - 11.0)


# Camino (lista de [key, tipo de arista para llegar]) con BFS. Vacío si no hay.
func path(from_key: int, to_key: int, avoid: Dictionary = {}, max_nodes: int = 6000) -> Array:
	if from_key < 0 or to_key < 0 or not adj.has(from_key):
		return []
	if from_key == to_key:
		return []
	var prev := {from_key: [-1, Edge.WALK]}
	var queue: Array = [from_key]
	var i := 0
	while i < queue.size() and i < max_nodes:
		var k: int = queue[i]
		i += 1
		if k == to_key:
			break
		for e in adj.get(k, []):
			if not avoid.is_empty() and int(avoid.get("%d>%d" % [k, e[0]], 0)) > Time.get_ticks_msec():
				continue
			if not prev.has(e[0]):
				prev[e[0]] = [k, e[1]]
				queue.append(e[0])
	if not prev.has(to_key):
		return []
	var out: Array = []
	var cur: int = to_key
	while cur != from_key:
		out.push_front([cur, prev[cur][1]])
		cur = prev[cur][0]
	return out


# Un nodo al azar alcanzable (para patrullar)
func random_key() -> int:
	var keys := adj.keys()
	return keys[randi() % keys.size()] if not keys.is_empty() else -1
