extends Control
## Pantalla de titulo "FlashRacs": ola de luz entre las letras + menu con foco verde vision nocturna.
## JUGAR abre el menu de red ya existente (Menu.tscn: host / unirse / lobby).

const DIR := "res://high_level_example/assets/ui/menu/"
const GAME_MENU := "res://high_level_example/scenes/Menu.tscn"
const TITLE := "FLASHRACS"
const STEP := 30            # separacion entre letras (px)
const TITLE_Y := 54
const BOB := 5.0            # cuanto sube cada letra al pasar la ola
const WAVE_DELAY := 0.38    # segundos entre una letra y la siguiente
const WAVE_PAUSE := 3.2     # pausa entre ola y ola

const GRAY := Color(0.60, 0.62, 0.61)
const GREEN := Color(0.35, 1.0, 0.50)

# Secuencia de la letra al "fundirse": [estado, segundos]
const BURN_SEQ := [
	["ember", 0.07], ["lit", 0.05], ["off", 0.06], ["lit", 0.04], ["ember", 0.08],
	["off", 0.95],
	["ember", 0.06], ["off", 0.08], ["ember", 0.07], ["off", 0.05], ["lit", 0.0],
]
const GLOW_ALPHA := {"lit": 0.42, "ember": 0.12, "off": 0.0}

var _tex := {}                       # "F_lit" -> Texture2D
var _letters: Array[Sprite2D] = []
var _glows: Array[Sprite2D] = []
var _state: Array[String] = []
var _font: Font
var _t := 0.0
var _buttons: Array[Button] = []

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_font = load(DIR + "font_menu.fnt")
	_build_title()
	_build_menu()
	_wave_loop()

func _process(delta: float) -> void:
	_t += delta
	# la luz de las letras encendidas "respira" muy poco
	for i in _glows.size():
		var a: float = GLOW_ALPHA[_state[i]]
		_glows[i].modulate.a = a * (0.88 + 0.12 * sin(_t * 2.0 + i * 0.7))

# ------------------------------------------------------------------ titulo
func _build_title() -> void:
	for ch in "FLASHRC":
		for tag in ["lit", "ember", "off"]:
			_tex["%s_%s" % [ch, tag]] = load("%stitle_%s_%s.png" % [DIR, ch, tag])
	var glow_tex: Texture2D = load(DIR + "glow.png")
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var w: Vector2 = _tex["F_lit"].get_size()
	var total := STEP * (TITLE.length() - 1) + w.x
	var x0 := (size.x - total) * 0.5
	for i in TITLE.length():
		var ch := TITLE[i]
		var g := Sprite2D.new()
		g.texture = glow_tex
		g.material = add
		g.scale = Vector2(1.5, 1.4)
		g.position = Vector2(x0 + i * STEP + w.x * 0.5, TITLE_Y + w.y * 0.5)
		$TitleRoot.add_child(g)
		var s := Sprite2D.new()
		s.centered = false
		s.texture = _tex[ch + "_lit"]
		s.position = Vector2(x0 + i * STEP, TITLE_Y)
		$TitleRoot.add_child(s)
		_letters.append(s)
		_glows.append(g)
		_state.append("lit")

func _set_state(i: int, st: String) -> void:
	_state[i] = st
	_letters[i].texture = _tex[TITLE[i] + "_" + st]

func _wave_loop() -> void:
	await get_tree().create_timer(1.2).timeout
	while is_inside_tree():
		for i in _letters.size():
			_hit(i)
			await get_tree().create_timer(WAVE_DELAY).timeout
		await get_tree().create_timer(WAVE_PAUSE).timeout

func _hit(i: int) -> void:
	var s := _letters[i]
	var g := _glows[i]
	var y0 := float(TITLE_Y)
	var gy0 := g.position.y
	var tw := create_tween().set_parallel(false)
	tw.tween_property(s, "position:y", y0 - BOB, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "position:y", y0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var tg := create_tween().set_parallel(false)
	tg.tween_property(g, "position:y", gy0 - BOB, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tg.tween_property(g, "position:y", gy0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for e in BURN_SEQ:
		_set_state(i, e[0])
		await get_tree().create_timer(e[1]).timeout

# ------------------------------------------------------------------ menu
func _build_menu() -> void:
	var box: VBoxContainer = $MenuBox
	var items := [
		["JUGAR", _on_play],
		["OPCIONES", _on_options],
		["SALIR", _on_quit],
	]
	for it in items:
		var b := Button.new()
		b.text = it[0]
		_style_button(b)
		b.pressed.connect(it[1])
		b.mouse_entered.connect(b.grab_focus)
		box.add_child(b)
		_buttons.append(b)
	_buttons[0].grab_focus()
	$Version.add_theme_font_override("font", _font)
	$Version.add_theme_font_size_override("font_size", 14)
	$Version.add_theme_color_override("font_color", Color(0.30, 0.32, 0.31))

func _style_button(b: Button) -> void:
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", GRAY)
	for c in ["font_hover_color", "font_focus_color", "font_hover_pressed_color", "font_pressed_color"]:
		b.add_theme_color_override(c, GREEN)
	for sb in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		b.add_theme_stylebox_override(sb, StyleBoxEmpty.new())

func _on_play() -> void:
	get_tree().change_scene_to_file(GAME_MENU)

func _on_options() -> void:
	print("OPCIONES: pendiente")

func _on_quit() -> void:
	get_tree().quit()
