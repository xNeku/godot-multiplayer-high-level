extends RefCounted
# Construye un mapa del juego a partir del JSON de FlashMapMaker (formato versión 1).
# Todo va en bloques (1 bloque = grid.block_px px, 11 por defecto), con el origen
# arriba a la izquierda y la Y hacia abajo. El JSON solo lleva DATOS: nunca scripts
# ni rutas de recursos (los nombres de arma/objeto se resuelven contra una lista
# cerrada de los .tres del juego).
#
# Uso:
#   const MapLoader := preload("res://high_level_example/scripts/map_loader.gd")
#   var mapa: Node2D = MapLoader.build(texto_json)       # null si no vale
#   var mapa: Node2D = MapLoader.load_file("res://maps/ejemplo.json")
#   var lista := MapLoader.list_maps()                    # oficiales + custom

const SUPPORTED_VERSION: int = 1
const OFFICIAL_DIR: String = "res://maps"
const CUSTOM_DIR: String = "user://maps"

# Límites para mapas que vienen de fuera (comunidad, red)
const MAX_TEXT: int = 512 * 1024
const MAX_GRID: int = 512
const MAX_RECTS: int = 5000
const MAX_ENTITIES: int = 2000

const MAP_SETTINGS: Script = preload("res://high_level_example/scripts/map_settings.gd")
const TILE_SHADER: Shader = preload("res://high_level_example/shaders/tiles.gdshader")
const LIGHT_PULSE: Script = preload("res://high_level_example/scripts/light_pulse.gd")
const LIGHT_FLICKER: Script = preload("res://high_level_example/scripts/light_flicker.gd")
const DOOR_SCENE: PackedScene = preload("res://high_level_example/scenes/Puerta.tscn")
const HIDE_SCENE: PackedScene = preload("res://high_level_example/scenes/Escondite.tscn")
const SPAWNER_SCENE: PackedScene = preload("res://high_level_example/scenes/Spawner.tscn")
const SOFT_TEX: Texture2D = preload("res://high_level_example/assets/fx/punto_suave.png")
const GLOW_FOLLOW: Script = preload("res://high_level_example/scripts/glow_follow.gd")
const LIGHT_TEX: Texture2D = preload("res://high_level_example/assets/lights/2d_lights_and_shadows_neutral_point_light.webp")

# Estilos de tiles.gdshader
enum Style { BRICK, SLAB, PLATFORM, CRATE, BACKWALL, SKY }
const COL_BRICK := Color(0.46, 0.40, 0.40)
const COL_SLAB := Color(0.45, 0.46, 0.48)
const COL_BACKWALL := Color(0.16, 0.15, 0.17)
const COL_SKY := Color(0.07, 0.08, 0.13)
# Una casilla es "interior" si tiene muro/techo encima y suelo debajo a menos de esto
const INTERIOR_REACH: int = 8
const COL_BASE := Color(0.5, 0.85, 0.6, 0.55)

const TILE_SOLID: int = 1
const TILE_PLATFORM: int = 2
# Filas de abajo que no se rompen nunca (el suelo del mundo)
const UNBREAKABLE_BOTTOM: int = 2

const PLATFORM_LAYER_BIT: int = 8 # capa 4 "Plataformas"
const SOLID_LAYER_BIT: int = 1 # capa 1 "Suelo"

# Piezas fijas: tamaño en bloques (ancho, alto)
const BOX_BIG := Vector2i(2, 2)
const BOX_SMALL := Vector2i(2, 1)
const BASE_SIZE := Vector2i(2, 1)
const DOOR_DEFAULT := Vector2i(2, 5)
# Escondites (ancho, alto en bloques)
const HIDE_SIZES := {"armario": Vector2i(2, 4), "rejilla": Vector2i(2, 2), "arbusto": Vector2i(3, 2)}
const DOOR_PX := Vector2(30.0, 59.0) # tamaño de la escena Puerta.tscn sin escalar

static var _pool_cache: Dictionary = {}


# --- API PÚBLICA ---

# Lee un archivo (res:// o user://) y construye el mapa. null si falla.
static func load_file(path: String) -> Node2D:
	var text := read_text(path)
	if text == "":
		return null
	return build(text)


static func read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		push_warning("MapLoader: no existe %s" % path)
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	if f.get_length() > MAX_TEXT:
		push_warning("MapLoader: %s es demasiado grande" % path)
		return ""
	return f.get_as_text()


# Valida y devuelve el mapa como diccionario limpio ({} si no vale).
static func parse(text: String) -> Dictionary:
	if text.length() == 0 or text.length() > MAX_TEXT:
		push_warning("MapLoader: texto vacío o demasiado grande")
		return {}
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		push_warning("MapLoader: JSON no válido")
		return {}
	var d: Dictionary = json.data

	var version: int = _int(d.get("version", 1), 1)
	if version > SUPPORTED_VERSION:
		push_warning("MapLoader: versión %d mayor que la que entiendo (%d). Intento cargarlo igualmente." % [version, SUPPORTED_VERSION])

	var grid: Dictionary = d.get("grid", {}) if d.get("grid") is Dictionary else {}
	var gw: int = clampi(_int(grid.get("w", 96), 96), 1, MAX_GRID)
	var gh: int = clampi(_int(grid.get("h", 54), 54), 1, MAX_GRID)
	var bp: int = clampi(_int(grid.get("block_px", 11), 11), 4, 32)

	var tiles: Dictionary = d.get("tiles", {}) if d.get("tiles") is Dictionary else {}
	var out := {
		"name": str(d.get("name", "mapa")).substr(0, 48),
		"version": version,
		"w": gw, "h": gh, "bp": bp,
		"solid": _clean_rects(tiles.get("solid", []), gw, gh),
		"platform": _clean_rects(tiles.get("platform", []), gw, gh),
		"entities": [],
	}
	var ents = d.get("entities", [])
	if ents is Array:
		var n := 0
		for e in ents:
			if n >= MAX_ENTITIES:
				push_warning("MapLoader: demasiadas entidades, el resto se ignora")
				break
			if e is Dictionary:
				out["entities"].append(e)
				n += 1
	return out


# Construye el mapa. null si el JSON no vale.
static func build(text: String) -> Node2D:
	var m := parse(text)
	if m.is_empty():
		return null
	var bp: float = float(m["bp"])
	var gw: int = m["w"]
	var gh: int = m["h"]

	var root := Node2D.new()
	root.name = "Mapa_" + _safe_name(m["name"])
	root.set_script(MAP_SETTINGS)
	root.with_darkness = true
	root.show_city_background = false
	root.camera_limits = Rect2(0.0, 0.0, gw * bp, gh * bp)

	var mat_cache := {}
	# Fondo: cielo nocturno en todo el mapa y pared de ladrillo solo en los interiores
	var sky := ColorRect.new()
	sky.name = "Cielo"
	sky.z_index = -11
	sky.size = Vector2(gw * bp, gh * bp)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.material = _tile_mat(Style.SKY, sky.size, COL_SKY, mat_cache)
	root.add_child(sky)
	var walls := _node(root, "ParedFondo")
	walls.z_index = -10
	for r in _merge(_interior_cells(m["solid"], gw, gh), gw, gh, true):
		var wr := ColorRect.new()
		wr.position = Vector2(r.position) * bp
		wr.size = Vector2(r.size) * bp
		wr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wr.material = _tile_mat(Style.BACKWALL, wr.size, COL_BACKWALL, mat_cache)
		walls.add_child(wr)

	var occ_cache := {}

	# Rejilla de tiles en memoria (para poder romperla con explosiones)
	var grid := PackedByteArray()
	grid.resize(gw * gh)
	for r in m["solid"]:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				grid[y * gw + x] = TILE_SOLID
	for r in m["platform"]:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if grid[y * gw + x] == 0:
					grid[y * gw + x] = TILE_PLATFORM
	root.set_meta("tiles", {"grid": grid, "w": gw, "h": gh, "bp": bp, "mats": mat_cache, "occ": occ_cache})
	_node(root, "Estructura")
	_node(root, "Plataformas")
	_build_tiles(root)

	# Entidades
	var boxes := _node(root, "Cajas")
	var doors := _node(root, "Puertas")
	var lights := _node(root, "Bombillas")
	# Halos de las bombillas: capa que no oscurece el CanvasModulate
	var glows := CanvasLayer.new()
	glows.name = "Brillos"
	glows.follow_viewport_enabled = true
	root.add_child(glows)
	lights.set_meta("glows", glows)
	var bases := _node(root, "Armas")
	var spawns := _node(root, "SpawnPoints")
	var hides := _node(root, "Escondites")
	var pool := _item_pool()
	var idx := 0
	for e in m["entities"]:
		var type: String = str(e.get("type", ""))
		var ex: int = _int(e.get("x", 0), 0)
		var ey: int = _int(e.get("y", 0), 0)
		match type:
			"spawn":
				var mk := Marker2D.new()
				mk.name = "Spawn%d" % idx
				mk.add_to_group("spawn_points")
				# 1x2 bloques = el personaje; el origen del jugador es su centro
				mk.position = Vector2((ex + 0.5) * bp, (ey + 1.0) * bp)
				spawns.add_child(mk)
			"box_big", "box_small":
				var sz := BOX_BIG if type == "box_big" else BOX_SMALL
				var cmat := _tile_mat(Style.CRATE, Vector2(sz) * bp, Color.WHITE, mat_cache)
				_add_body(boxes, "Caja%d" % idx, Rect2i(ex, ey, sz.x, sz.y), bp, cmat, SOLID_LAYER_BIT, false, true, occ_cache)
			"light":
				_add_light(lights, "Bombilla%d" % idx, ex, ey, bp, bool(e.get("on", true)), e)
			"door":
				var dw: int = clampi(_int(e.get("w", DOOR_DEFAULT.x), DOOR_DEFAULT.x), 1, 8)
				var dh: int = clampi(_int(e.get("h", DOOR_DEFAULT.y), DOOR_DEFAULT.y), 1, 16)
				var door: Node2D = DOOR_SCENE.instantiate()
				door.name = "Puerta%d" % idx
				door.position = Vector2((ex + dw * 0.5) * bp, (ey + dh * 0.5) * bp)
				door.scale = Vector2(dw * bp / DOOR_PX.x, dh * bp / DOOR_PX.y)
				doors.add_child(door)
				if bool(e.get("open", false)):
					door.call_deferred("_set_open", true)
			"hide":
				var kind: String = str(e.get("kind", "armario"))
				if not HIDE_SIZES.has(kind):
					kind = "armario"
				var hs: Vector2i = HIDE_SIZES[kind]
				var spot: Node2D = HIDE_SCENE.instantiate()
				spot.name = "Escondite%d" % idx
				spot.kind = kind
				# Origen del escondite: centro de su base
				spot.position = Vector2((ex + hs.x * 0.5) * bp, (ey + hs.y) * bp)
				hides.add_child(spot)
			"weapon_base":
				_add_base(bases, "Base%d" % idx, ex, ey, bp, str(e.get("item", "")), pool, idx)
			_:
				push_warning("MapLoader: tipo desconocido '%s', ignorado" % type)
		idx += 1

	if spawns.get_child_count() == 0:
		# Sin spawns: centro del mapa
		var mk := Marker2D.new()
		mk.name = "SpawnCentro"
		mk.add_to_group("spawn_points")
		mk.position = Vector2(gw * bp * 0.5, gh * bp * 0.5)
		spawns.add_child(mk)
		push_warning("MapLoader: el mapa no tiene spawns, uso el centro")
	return root


# (Re)construye los cuerpos de muros y plataformas a partir de la rejilla.
# Los tiles se fusionan en rectángulos grandes (sin costuras entre piezas).
static func _build_tiles(root: Node2D) -> void:
	var t: Dictionary = root.get_meta("tiles")
	var grid: PackedByteArray = t["grid"]
	var gw: int = t["w"]
	var gh: int = t["h"]
	var bp: float = float(t["bp"])
	var solids: Node = root.get_node("Estructura")
	var plats: Node = root.get_node("Plataformas")
	for c in solids.get_children():
		solids.remove_child(c)
		c.queue_free()
	for c in plats.get_children():
		plats.remove_child(c)
		c.queue_free()
	var solid_cells: Array = []
	var plat_cells: Array = []
	for y in gh:
		for x in gw:
			var v: int = grid[y * gw + x]
			if v == TILE_SOLID:
				solid_cells.append(Rect2i(x, y, 1, 1))
			elif v == TILE_PLATFORM:
				plat_cells.append(Rect2i(x, y, 1, 1))
	var i := 0
	for r in _merge(solid_cells, gw, gh, true):
		# Piezas anchas = losas (suelos y techos); el resto, muros de ladrillo
		var slab: bool = r.size.x > r.size.y * 2
		var st: int = Style.SLAB if slab else Style.BRICK
		var mat := _tile_mat(st, Vector2(r.size) * bp, COL_SLAB if slab else COL_BRICK, t["mats"])
		_add_body(solids, "Suelo%d" % i, r, bp, mat, SOLID_LAYER_BIT, false, true, t["occ"])
		i += 1
	i = 0
	for r in _merge(plat_cells, gw, gh, false):
		var pmat := _tile_mat(Style.PLATFORM, Vector2(r.size) * bp, Color.WHITE, t["mats"])
		_add_body(plats, "Plataforma%d" % i, r, bp, pmat, PLATFORM_LAYER_BIT, true, false, t["occ"])
		i += 1


# Explosión que rompe el terreno: quita los tiles dentro del radio (menos el borde del
# mapa y el suelo del fondo) y las cajas. Lo hace cada peer con la misma posición,
# así el resultado es idéntico en todos. Devuelve los centros (px) de lo que se rompió.
static func carve(root: Node2D, center: Vector2, radius: float) -> PackedVector2Array:
	var broken := PackedVector2Array()
	if root == null or not root.has_meta("tiles"):
		return broken
	var t: Dictionary = root.get_meta("tiles")
	var grid: PackedByteArray = t["grid"]
	var gw: int = t["w"]
	var gh: int = t["h"]
	var bp: float = float(t["bp"])
	var c := center / bp
	var rb: float = radius / bp
	var tiles_changed: bool = false
	for y in range(maxi(1, int(c.y - rb) - 1), mini(gh - 1 - UNBREAKABLE_BOTTOM, int(c.y + rb) + 2)):
		for x in range(maxi(1, int(c.x - rb) - 1), mini(gw - 1, int(c.x + rb) + 2)):
			if grid[y * gw + x] == 0:
				continue
			if Vector2(x + 0.5, y + 0.5).distance_to(c) <= rb:
				grid[y * gw + x] = 0
				broken.append(Vector2(x + 0.5, y + 0.5) * bp)
				tiles_changed = true
	if tiles_changed:
		t["grid"] = grid
		t["ver"] = int(t.get("ver", 0)) + 1 # los bots rehacen su grafo de caminos
	# Cajas
	var boxes := root.get_node_or_null("Cajas")
	if boxes:
		for b in boxes.get_children():
			if (b as Node2D).global_position.distance_to(center) <= radius + bp:
				broken.append(b.global_position)
				b.queue_free()
	# Solo se rehacen los cuerpos de colisión si ha cambiado el terreno (no por las cajas)
	if tiles_changed:
		_build_tiles(root)
	return broken


# Mapas disponibles: [{name, path, official}]
static func list_maps() -> Array:
	var out: Array = []
	for dir_info in [[OFFICIAL_DIR, true], [CUSTOM_DIR, false]]:
		var dir := DirAccess.open(dir_info[0])
		if dir == null:
			continue
		var files := Array(dir.get_files())
		files.sort()
		for fn in files:
			var f: String = fn
			if f.ends_with(".remap"):
				f = f.trim_suffix(".remap")
			if not f.to_lower().ends_with(".json"):
				continue
			var p: String = "%s/%s" % [dir_info[0], f]
			out.append({"name": f.get_basename(), "path": p, "official": dir_info[1]})
	return out


# Guarda un JSON importado en user://maps/ (nombre saneado). Devuelve la ruta o "".
static func save_custom(text: String, suggested_name: String) -> String:
	if parse(text).is_empty():
		return ""
	DirAccess.make_dir_recursive_absolute(CUSTOM_DIR)
	var base := _safe_name(suggested_name)
	var path := "%s/%s.json" % [CUSTOM_DIR, base]
	var n := 2
	while FileAccess.file_exists(path):
		path = "%s/%s_%d.json" % [CUSTOM_DIR, base, n]
		n += 1
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(text)
	return path


# --- INTERNO ---

static func _int(v, fallback: int) -> int:
	if v is int or v is float:
		return int(v)
	return fallback


static func _safe_name(s: String) -> String:
	var out := ""
	for c in s:
		out += c if (c.unicode_at(0) < 128 and (c.is_valid_identifier() or c == "-" or c.is_valid_int())) else "_"
	return out.substr(0, 40) if out != "" else "mapa"


static func _node(parent: Node, node_name: String) -> Node2D:
	var n := Node2D.new()
	n.name = node_name
	parent.add_child(n)
	return n


# Rectángulos válidos, recortados al grid
static func _clean_rects(arr, gw: int, gh: int) -> Array:
	var out: Array = []
	if not (arr is Array):
		return out
	for r in arr:
		if out.size() >= MAX_RECTS:
			push_warning("MapLoader: demasiados rectángulos, el resto se ignora")
			break
		if not (r is Dictionary):
			continue
		var x := _int(r.get("x", 0), 0)
		var y := _int(r.get("y", 0), 0)
		var w := _int(r.get("w", 1), 1)
		var h := _int(r.get("h", 1), 1)
		var x2 := mini(x + w, gw)
		var y2 := mini(y + h, gh)
		x = maxi(x, 0)
		y = maxi(y, 0)
		if x2 > x and y2 > y:
			out.append(Rect2i(x, y, x2 - x, y2 - y))
	return out


# Pasa los rectángulos a celdas y los vuelve a agrupar en el mínimo de rectángulos
# razonable. Solapes y rectángulos pegados quedan fundidos. Si "vertical" es false
# solo se juntan tramos horizontales (plataformas, siempre de 1 de alto).
static func _merge(rects: Array, gw: int, gh: int, vertical: bool) -> Array:
	if rects.is_empty():
		return []
	var cells := PackedByteArray()
	cells.resize(gw * gh)
	for r: Rect2i in rects:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				cells[y * gw + x] = 1
	var out: Array = []
	var open := {} # "x,w" -> Rect2i en construcción (se extiende hacia abajo)
	for y in gh:
		var seen := {}
		var x := 0
		while x < gw:
			if cells[y * gw + x] == 0:
				x += 1
				continue
			var x0 := x
			while x < gw and cells[y * gw + x] == 1:
				x += 1
			var key := Vector2i(x0, x - x0)
			seen[key] = true
			if vertical and open.has(key):
				var o: Rect2i = open[key]
				open[key] = Rect2i(o.position, Vector2i(o.size.x, o.size.y + 1))
			else:
				open[key] = Rect2i(x0, y, x - x0, 1)
		# Lo que no continúa en esta fila se cierra
		for key in open.keys():
			if not seen.has(key):
				out.append(open[key])
				open.erase(key)
		if not vertical:
			for key in open.keys():
				out.append(open[key])
				open.erase(key)
	for key in open.keys():
		out.append(open[key])
	return out


# Casillas libres cubiertas (techo encima y suelo debajo cerca): ahí va la pared del fondo.
# Devuelve rectángulos de 1x1 en el mismo formato que el JSON, para fusionarlos con _merge.
static func _interior_cells(solid_rects: Array, gw: int, gh: int) -> Array:
	var grid := PackedByteArray()
	grid.resize(gw * gh)
	for r in solid_rects:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				grid[y * gw + x] = 1
	var out: Array = []
	for x in gw:
		for y in gh:
			if grid[y * gw + x] == 1:
				continue
			var up := false
			for k in range(1, INTERIOR_REACH + 1):
				if y - k >= 0 and grid[(y - k) * gw + x] == 1:
					up = true
					break
			if not up:
				continue
			for k in range(1, INTERIOR_REACH + 1):
				if y + k < gh and grid[(y + k) * gw + x] == 1:
					out.append(Rect2i(x, y, 1, 1))
					break
	return out


# Un material por estilo y tamaño (se comparte entre piezas iguales)
static func _tile_mat(style: int, size: Vector2, color: Color, cache: Dictionary) -> ShaderMaterial:
	var key := "%d:%d,%d" % [style, int(size.x), int(size.y)]
	if not cache.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = TILE_SHADER
		mat.set_shader_parameter("style", style)
		mat.set_shader_parameter("rect_size", size)
		mat.set_shader_parameter("base_color", color)
		mat.set_shader_parameter("seed", float(cache.size()) * 3.7)
		cache[key] = mat
	return cache[key]


static func _add_body(parent: Node, node_name: String, r: Rect2i, bp: float, mat: ShaderMaterial,
		layer: int, one_way: bool, occluder: bool, occ_cache: Dictionary) -> void:
	var size := Vector2(r.size.x * bp, r.size.y * bp)
	var body := StaticBody2D.new()
	body.name = node_name
	body.position = Vector2(r.position.x * bp, r.position.y * bp) + size * 0.5
	body.collision_layer = layer
	body.collision_mask = 0
	var vis := ColorRect.new()
	vis.name = "ColorRect"
	vis.position = -size * 0.5
	vis.size = size
	vis.material = mat
	vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(vis)
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	cs.shape = shape
	cs.one_way_collision = one_way
	body.add_child(cs)
	if occluder:
		var key := r.size
		if not occ_cache.has(key):
			var poly := OccluderPolygon2D.new()
			var h := size * 0.5
			poly.polygon = PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)])
			occ_cache[key] = poly
		var lo := LightOccluder2D.new()
		lo.occluder = occ_cache[key]
		body.add_child(lo)
	parent.add_child(body)


# Opcional en el JSON: "pulse": true -> intermitente (apagada; se enciende "on_time" s
# cada "period" s, con desfase "phase"). Sin "pulse" parpadea al azar como siempre.
static func _add_light(parent: Node, node_name: String, ex: int, ey: int, bp: float, on: bool, e: Dictionary = {}) -> void:
	var n := Node2D.new()
	n.name = node_name
	# 1x1 bloque: cuelga del centro de la parte de arriba de la casilla
	n.position = Vector2((ex + 0.5) * bp, ey * bp)
	var cable := ColorRect.new()
	cable.name = "Cable"
	cable.offset_left = -1.0
	cable.offset_right = 1.0
	cable.offset_bottom = 8.0
	cable.color = Color(0.05, 0.05, 0.05)
	n.add_child(cable)
	# Pantalla de la lámpara (metal oscuro) y bombilla
	var shade := Polygon2D.new()
	shade.name = "Pantalla"
	shade.z_index = 3
	shade.polygon = PackedVector2Array([Vector2(-2, 7), Vector2(2, 7), Vector2(5, 11), Vector2(-5, 11)])
	shade.color = Color(0.22, 0.24, 0.22)
	n.add_child(shade)
	var foco := ColorRect.new()
	foco.name = "Foco"
	foco.z_index = 2
	foco.offset_left = -2.0
	foco.offset_top = 10.0
	foco.offset_right = 2.0
	foco.offset_bottom = 13.0
	foco.color = Color(1.0, 0.92, 0.7) if on else Color(0.3, 0.28, 0.22)
	n.add_child(foco)
	var luz := PointLight2D.new()
	luz.name = "Luz"
	luz.position = Vector2(0, 11)
	luz.color = Color(1.0, 0.82, 0.5)
	luz.energy = 1.25
	luz.shadow_enabled = true
	luz.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	luz.shadow_filter_smooth = 2.0
	luz.texture = LIGHT_TEX
	luz.texture_scale = 1.9
	if on and bool(e.get("pulse", false)):
		luz.set_script(LIGHT_PULSE)
		luz.set("period", clampf(float(e.get("period", 40.0)), 2.0, 600.0))
		luz.set("on_time", clampf(float(e.get("on_time", 2.0)), 0.2, 60.0))
		luz.set("phase", float(e.get("phase", 0.0)))
		foco.color = Color(0.55, 0.5, 0.4)
	elif on:
		luz.set_script(LIGHT_FLICKER)
	else:
		luz.enabled = false
	n.add_child(luz)
	parent.add_child(n)
	var glows: CanvasLayer = parent.get_meta("glows") if parent.has_meta("glows") else null
	if glows:
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		for spec in [[0.9, 0.35], [0.22, 0.8]]: # halo grande suave + núcleo
			var g := Sprite2D.new()
			g.texture = SOFT_TEX
			g.material = add
			g.self_modulate = Color(1.0, 0.85, 0.55)
			g.scale = Vector2.ONE * spec[0]
			g.position = n.position + Vector2(0, 12)
			g.set_script(GLOW_FOLLOW)
			g.light = luz
			g.base_alpha = spec[1]
			glows.add_child(g)


static func _add_base(parent: Node, node_name: String, ex: int, ey: int, bp: float,
		item: String, pool: Array, idx: int) -> void:
	var sp: Node2D = SPAWNER_SCENE.instantiate()
	sp.name = node_name
	# Base 2x1: el spawner va en el centro de la casilla
	sp.position = Vector2((ex + BASE_SIZE.x * 0.5) * bp, (ey + 0.5) * bp)
	var res: Resource = null
	item = item.strip_edges()
	if item != "":
		res = _find_item(item, pool)
		if res == null:
			push_warning("MapLoader: item '%s' desconocido, la base queda vacía" % item)
	elif not pool.is_empty():
		# Sin item: reparto determinista (todos los peers deben ver lo mismo)
		res = pool[(ex * 7 + ey * 13 + idx * 31) % pool.size()][1]
	if res is WeaponData:
		sp.weapon = res
	elif res is ItemData:
		sp.item = res
	# Pastilla verde para ver dónde está la base
	var pad := ColorRect.new()
	pad.name = "Base"
	pad.z_index = -1
	pad.position = Vector2(-BASE_SIZE.x * bp * 0.5, -bp * 0.5 + 2.0)
	pad.size = Vector2(BASE_SIZE.x * bp, bp)
	pad.color = COL_BASE
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sp.add_child(pad)
	parent.add_child(sp)


# Lista cerrada de armas y objetos del juego: [[nombre_en_minúsculas, Resource], ...]
static func _item_pool() -> Array:
	if not _pool_cache.is_empty():
		return _pool_cache["pool"]
	var pool: Array = []
	for dir_path in ["res://high_level_example/Weapons", "res://high_level_example/Objetos"]:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		var files := Array(dir.get_files())
		files.sort()
		for fn in files:
			var f: String = str(fn).trim_suffix(".remap")
			if not f.ends_with(".tres"):
				continue
			var base := f.get_basename().to_lower()
			if base == "pistolajuguete":
				continue # solo para el lobby
			var res := load("%s/%s" % [dir_path, f])
			if res is WeaponData or res is ItemData:
				pool.append([base, res])
	_pool_cache["pool"] = pool
	return pool


static func _find_item(item: String, pool: Array) -> Resource:
	var key := item.to_lower()
	for p in pool:
		if p[0] == key:
			return p[1]
	return null
