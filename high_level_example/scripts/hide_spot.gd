extends Node2D
# Escondite: armario, rejilla de ventilación o arbusto. El jugador que entra deja
# de verse y no le dan las balas, pero las explosiones sí lo matan.
# El origen del nodo es el centro de la base (a ras de suelo).
# Quién está dentro lo decide el servidor (occupant); el resto es visual y local.

@export_enum("armario", "rejilla", "arbusto") var kind: String = "armario"

const SIZES := {
	"armario": Vector2(22, 44),
	"rejilla": Vector2(22, 22),
	"arbusto": Vector2(33, 22),
}

# Solo servidor: id del jugador escondido (0 = libre)
var occupant: int = 0

# El aviso va en una capa sin oscuridad (si no, la noche lo tapa)
@onready var prompt: Label = $CapaAviso/Aviso
var _prompt_on: bool = false


func _ready() -> void:
	add_to_group("hide_spots")
	prompt.modulate.a = 0.0
	_place_prompt()
	queue_redraw()


func get_size() -> Vector2:
	return SIZES.get(kind, Vector2(22, 22))


# ¿Está el punto (pies o centro del jugador) dentro del escondite (con algo de margen)?
func covers(p: Vector2) -> bool:
	var s := get_size()
	return Rect2(global_position + Vector2(-s.x * 0.5 - 3.0, -s.y - 4.0), s + Vector2(6.0, 8.0)).has_point(p)


func is_free() -> bool:
	if occupant == 0:
		return true
	# El que estaba se fue de la partida
	var players := get_tree().current_scene.get_node_or_null("PlayerSpawnContainer")
	if players and players.get_node_or_null(str(occupant)) == null:
		occupant = 0
		return true
	return false


# Aviso sutil encima ("Q · Esconderse"); solo lo pide el jugador local
func show_prompt(on: bool, text: String = "") -> void:
	if text != "":
		prompt.text = text
		_place_prompt()
	if on == _prompt_on:
		return
	_prompt_on = on
	var tw := create_tween()
	tw.tween_property(prompt, "modulate:a", 0.75 if on else 0.0, 0.15)


func _place_prompt() -> void:
	prompt.position = global_position + Vector2(-prompt.size.x * 0.5, -get_size().y - 14.0)


# Meneo al entrar o salir (lo ven todos: delata que alguien se ha metido)
func rustle() -> void:
	var tw := create_tween()
	var amp: float = 0.08 if kind == "arbusto" else 0.03
	for i in 4:
		tw.tween_property(self, "skew", amp * (1.0 if i % 2 == 0 else -1.0), 0.05)
	tw.tween_property(self, "skew", 0.0, 0.06)


# --- DIBUJO (provisional, pixel art hecho a código) ---

func _draw() -> void:
	match kind:
		"armario":
			_draw_wardrobe()
		"rejilla":
			_draw_vent()
		_:
			_draw_bush()


func _px(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(x, y, w, h), c)


func _draw_wardrobe() -> void:
	var s := get_size()
	var x0: float = -s.x * 0.5
	var y0: float = -s.y
	var wood := Color(0.36, 0.22, 0.13)
	var dark := Color(0.2, 0.12, 0.07)
	var light := Color(0.5, 0.33, 0.19)
	_px(x0, y0 + 2, s.x, s.y - 4, wood)                 # cuerpo
	_px(x0 - 1, y0, s.x + 2, 3, light)                   # cornisa
	_px(x0 - 1, y0 + 2, s.x + 2, 1, dark)
	_px(x0 + 2, y0 + 5, s.x * 0.5 - 3, s.y - 11, light.darkened(0.15))   # puerta izq.
	_px(x0 + s.x * 0.5 + 1, y0 + 5, s.x * 0.5 - 3, s.y - 11, light.darkened(0.15))
	_px(x0 + s.x * 0.5 - 0.5, y0 + 4, 1, s.y - 9, dark)  # junta
	for py in [y0 + 9, y0 + s.y - 12]:                   # molduras
		_px(x0 + 3, py, s.x * 0.5 - 5, 1, dark)
		_px(x0 + s.x * 0.5 + 2, py, s.x * 0.5 - 5, 1, dark)
	_px(x0 + s.x * 0.5 - 3, y0 + s.y * 0.5, 1, 2, Color(0.8, 0.7, 0.4))   # tiradores
	_px(x0 + s.x * 0.5 + 2, y0 + s.y * 0.5, 1, 2, Color(0.8, 0.7, 0.4))
	_px(x0 + 1, -3, 2, 3, dark)                          # patas
	_px(x0 + s.x - 3, -3, 2, 3, dark)
	_px(x0, -4, s.x, 1, dark)


func _draw_vent() -> void:
	var s := get_size()
	var x0: float = -s.x * 0.5
	var y0: float = -s.y
	var frame := Color(0.3, 0.32, 0.33)
	var hole := Color(0.04, 0.04, 0.05)
	_px(x0, y0, s.x, s.y, frame)
	_px(x0 + 2, y0 + 2, s.x - 4, s.y - 4, hole)
	var y: float = y0 + 4
	while y < -3.0:                                       # lamas
		_px(x0 + 2, y, s.x - 4, 1, Color(0.42, 0.44, 0.45))
		_px(x0 + 2, y + 1, s.x - 4, 1, Color(0.18, 0.19, 0.2))
		y += 4.0
	for c in [Vector2(x0 + 1, y0 + 1), Vector2(x0 + s.x - 2, y0 + 1), Vector2(x0 + 1, -2), Vector2(x0 + s.x - 2, -2)]:
		_px(c.x, c.y, 1, 1, Color(0.6, 0.6, 0.58))    # tornillos


func _draw_bush() -> void:
	var s := get_size()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(global_position.x * 7.0 + global_position.y * 13.0)
	var greens := [Color(0.12, 0.25, 0.12), Color(0.16, 0.33, 0.14), Color(0.22, 0.42, 0.17), Color(0.3, 0.5, 0.2)]
	# Bolas de hojas de atrás (oscuras) a delante (claras)
	for layer in 4:
		for i in 6:
			var cx: float = rng.randf_range(-s.x * 0.42, s.x * 0.42)
			var cy: float = rng.randf_range(-s.y * 0.75, -s.y * 0.25) + layer * 1.5
			var r: float = rng.randf_range(4.0, 7.5) - layer * 0.6
			draw_circle(Vector2(cx, cy), r, greens[layer])
	for i in 18:                                          # hojitas sueltas
		var p := Vector2(rng.randf_range(-s.x * 0.5, s.x * 0.5), rng.randf_range(-s.y, -2.0))
		_px(round(p.x), round(p.y), 1, 1, greens[3].lightened(0.15))
	_px(-s.x * 0.5 + 2, -2, s.x - 4, 2, Color(0.1, 0.08, 0.06))   # tierra
