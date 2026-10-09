extends Control
# Menú de JUGAR: crear partida, unirse por IP y opciones. Volver lleva al título.
# Al conectar (o crear) se pasa al Lobby. El estilo sale de assets/ui/tema_flash.tres.

const UiJuice := preload("res://high_level_example/scripts/ui_juice.gd")
const LOBBY_SCENE: String = "res://high_level_example/scenes/Lobby.tscn"
const TITLE_SCENE: String = "res://high_level_example/scenes/TitleMenu.tscn"

# El título lo pone a true para entrar directo a OPCIONES (y VOLVER regresa al título)
static var open_options: bool = false

@onready var main_panel: PanelContainer = %PanelPrincipal
@onready var options_panel: PanelContainer = %PanelOpciones
@onready var ip_input: LineEdit = %IpInput
@onready var message: Label = %Mensaje
@onready var volume: HSlider = %Volumen
@onready var fullscreen: CheckButton = %Pantalla
@onready var resolution: OptionButton = %Resolucion
@onready var controls_label: Label = %Controles

var _entering: bool = false
var _options_only: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameManager.in_lobby = false

	%HostButton.pressed.connect(_on_host_pressed)
	%JoinButton.pressed.connect(_on_join_pressed)
	%OpcionesButton.pressed.connect(_show_options.bind(true))
	%VolverButton.pressed.connect(_show_options.bind(false))
	%SalirButton.pressed.connect(_back_to_title)
	ip_input.text_submitted.connect(func(_t): _on_join_pressed())

	for s in Settings.WINDOW_SIZES:
		resolution.add_item("%d x %d" % [s.x, s.y])
	volume.value = Settings.master_volume
	fullscreen.button_pressed = Settings.fullscreen
	resolution.select(Settings.window_size_index)
	volume.value_changed.connect(func(v): Settings.master_volume = v; Settings.apply(); Settings.save())
	fullscreen.toggled.connect(func(on): Settings.fullscreen = on; Settings.apply(); Settings.save())
	%FiltroTV.button_pressed = Settings.tv_filter
	%FiltroTV.toggled.connect(func(on): Settings.tv_filter = on; PostFX.set_enabled(on); Settings.save())
	resolution.item_selected.connect(func(i): Settings.window_size_index = i; Settings.apply(); Settings.save())
	controls_label.text = _controls_text()
	UiJuice.apply(self)
	# Como en el título: pasar el ratón por encima = enfocar (se pone verde)
	for b in find_children("*", "BaseButton", true, false):
		b.mouse_entered.connect((b as Control).grab_focus)
	volume.mouse_entered.connect(volume.grab_focus)

	HighLevelNetworkHandler.connected_to_server.connect(_go_to_lobby, CONNECT_ONE_SHOT)
	multiplayer.connection_failed.connect(_on_connection_failed)

	# Mando: la última IP queda puesta (con mando no se puede escribir) y el foco
	# empieza en "Crear partida" si hay un mando conectado.
	ip_input.text = Settings.last_ip
	if open_options:
		open_options = false
		_options_only = true
		_show_options(true)
		volume.grab_focus()
	else:
		%HostButton.grab_focus()


func _input(event: InputEvent) -> void:
	if UiJuice.pad_accept(get_viewport(), event):
		return
	# Al tocar el mando sin nada enfocado, se enfoca el primer botón del panel visible
	var pad: bool = event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5)
	if pad and get_viewport().gui_get_focus_owner() == null:
		_focus_first()
		get_viewport().set_input_as_handled()
	elif UiJuice.is_cancel(event) and not ip_input.has_focus():
		get_viewport().set_input_as_handled()
		if options_panel.visible:
			_show_options(false)
		else:
			_back_to_title()


func _focus_first() -> void:
	if options_panel.visible:
		volume.grab_focus()
	else:
		%HostButton.grab_focus()


func _show_options(on: bool) -> void:
	if not on and _options_only:
		_back_to_title()
		return
	%Cabecera.text = "- OPCIONES -" if on else "- JUGAR -"
	options_panel.visible = on
	main_panel.visible = not on
	if get_viewport().gui_get_focus_owner() != null or Settings.using_pad:
		if on:
			volume.grab_focus()
		else:
			%OpcionesButton.grab_focus()


func _back_to_title() -> void:
	if _entering:
		return
	get_tree().change_scene_to_file(TITLE_SCENE)


func _on_host_pressed() -> void:
	message.text = ""
	if HighLevelNetworkHandler.start_host() != OK:
		message.text = "NO SE PUDO CREAR LA SALA. PUERTO OCUPADO?"


func _on_join_pressed() -> void:
	message.text = "CONECTANDO..."
	Settings.last_ip = ip_input.text.strip_edges()
	Settings.save()
	if HighLevelNetworkHandler.start_client(ip_input.text.strip_edges()) != OK:
		message.text = "IP NO VALIDA"


func _on_connection_failed() -> void:
	message.text = "NO SE PUDO CONECTAR. REVISA LA IP"


func _go_to_lobby() -> void:
	if _entering:
		return
	_entering = true
	GameManager.in_lobby = true
	get_tree().change_scene_to_file(LOBBY_SCENE)


func _controls_text() -> String:
	return "\n".join([
		"MOVERSE: A D / STICK IZQ",
		"SALTAR: W ESPACIO / A",
		"AGACHARSE: SHIFT / LB",
		"APUNTAR: RATON / STICK DER",
		"DISPARAR: J / X / RT",
		"COGER USAR: E / RB",
		"LANZAR: G / B",
		"ESCONDERSE: Q / Y",
		"SOGA: K / LT",
		"MENU: ESC / START",
	])
