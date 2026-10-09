extends Node2D
## Logo FLASHRACS con la ola de luz entre letras. Lo usan el título y el menú de JUGAR,
## así las dos pantallas son la misma "sala" y solo cambia lo de abajo.

const DIR := "res://high_level_example/assets/ui/menu/"
const TITLE := "FLASHRACS"
@export var step: int = 50            # separacion entre letras (px)
@export var title_y: int = 16
@export var bob: float = 5.0          # cuanto sube cada letra al pasar la ola
@export var wave_delay: float = 0.38  # segundos entre una letra y la siguiente
@export var wave_pause: float = 3.2   # pausa entre ola y ola

# Secuencia de la letra al "fundirse": [estado, segundos]
const BURN_SEQ := [
	["ember", 0.07], ["lit", 0.05], ["off", 0.06], ["lit", 0.04], ["ember", 0.08],
	["off", 0.95],
	["ember", 0.06], ["off", 0.08], ["ember", 0.07], ["off", 0.05], ["lit", 0.0],
]
const GLOW_ALPHA := {"lit": 0.42, "ember": 0.12, "off": 0.0}
const TILT := [-2.0, 1.5, -1.0, 2.0, -1.5, 1.0, -2.0, 1.5, -1.0]
const JITTER := [0.0, 3.0, -2.0, 2.0, -1.0, 3.0, -2.0, 1.0, -3.0]

var _tex := {}                       # "F_lit" -> Texture2D
var _letters: Array[Sprite2D] = []
var _glows: Array[Sprite2D] = []
var _state: Array[String] = []
var _t := 0.0


func _ready() -> void:
	_build()
	_wave_loop()


func _process(delta: float) -> void:
	_t += delta
	# la luz de las letras encendidas "respira" muy poco
	for i in _glows.size():
		var a: float = GLOW_ALPHA[_state[i]]
		_glows[i].modulate.a = a * (0.88 + 0.12 * sin(_t * 2.0 + i * 0.7))


func _build() -> void:
	for ch in "FLASHRC":
		for tag in ["lit", "ember", "off"]:
			_tex["%s_%s" % [ch, tag]] = load("%stitle_%s_%s.png" % [DIR, ch, tag])
	var glow_tex: Texture2D = load(DIR + "glow.png")
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var w: Vector2 = _tex["F_lit"].get_size()
	var total := step * (TITLE.length() - 1) + w.x
	var x0 := (get_viewport_rect().size.x - total) * 0.5
	for i in TITLE.length():
		var g := Sprite2D.new()
		g.texture = glow_tex
		g.material = add
		g.scale = Vector2(2.3, 2.3)
		g.position = Vector2(x0 + i * step + w.x * 0.5, title_y + w.y * 0.5)
		add_child(g)
		var s := Sprite2D.new()
		s.centered = false
		s.texture = _tex[TITLE[i] + "_lit"]
		s.position = Vector2(x0 + i * step, title_y + _jitter_y(i))
		# Cada letra un pelín torcida: como pegatinas puestas a mano
		s.rotation = deg_to_rad(TILT[i % 9])
		add_child(s)
		_letters.append(s)
		_glows.append(g)
		_state.append("lit")


# Alturas desiguales a propósito (no todas en la misma línea)
func _jitter_y(i: int) -> float:
	return JITTER[i % 9]


func _set_state(i: int, st: String) -> void:
	_state[i] = st
	_letters[i].texture = _tex[TITLE[i] + "_" + st]


func _wave_loop() -> void:
	await get_tree().create_timer(1.2).timeout
	while is_inside_tree():
		for i in _letters.size():
			if not is_inside_tree():
				return
			_hit(i)
			await get_tree().create_timer(wave_delay).timeout
		await get_tree().create_timer(wave_pause).timeout


func _hit(i: int) -> void:
	var s := _letters[i]
	var g := _glows[i]
	var y0 := float(title_y) + _jitter_y(i)
	var gy0 := g.position.y
	var tw := create_tween().set_parallel(false)
	tw.tween_property(s, "position:y", y0 - bob, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "position:y", y0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var tg := create_tween().set_parallel(false)
	tg.tween_property(g, "position:y", gy0 - bob, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tg.tween_property(g, "position:y", gy0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for e in BURN_SEQ:
		if not is_inside_tree():
			return
		_set_state(i, e[0])
		await get_tree().create_timer(e[1]).timeout
