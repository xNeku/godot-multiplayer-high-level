extends Control
## Pantalla de titulo "FlashRacs": logo (title_logo.gd) + menu con foco verde vision nocturna.
## JUGAR y OPCIONES abren Menu.tscn, que tiene el mismo fondo y logo.

const DIR := "res://high_level_example/assets/ui/menu/"
const GAME_MENU := "res://high_level_example/scenes/Menu.tscn"
const UiJuice := preload("res://high_level_example/scripts/ui_juice.gd")

var _buttons: Array[Button] = []


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_build_menu()


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
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(it[1])
		b.mouse_entered.connect(b.grab_focus)
		box.add_child(b)
		_buttons.append(b)
	UiJuice.apply(box)
	_buttons[0].grab_focus()


func _input(event: InputEvent) -> void:
	UiJuice.pad_accept(get_viewport(), event)


func _on_play() -> void:
	get_tree().change_scene_to_file(GAME_MENU)


func _on_options() -> void:
	preload("res://high_level_example/scripts/menu.gd").open_options = true
	get_tree().change_scene_to_file(GAME_MENU)


func _on_quit() -> void:
	get_tree().quit()
