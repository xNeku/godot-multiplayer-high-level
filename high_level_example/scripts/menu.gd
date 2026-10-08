extends Control
# Menú principal: crear partida, unirse por IP, opciones y salir.
# Al conectar (o crear) se pasa al Lobby.

const UiJuice := preload("res://high_level_example/scripts/ui_juice.gd")
const LOBBY_SCENE: String = "res://high_level_example/scenes/Lobby.tscn"

@onready var main_panel: PanelContainer = %PanelPrincipal
@onready var options_panel: PanelContainer = %PanelOpciones
@onready var ip_input: LineEdit = %IpInput
@onready var message: Label = %Mensaje
@onready var volume: HSlider = %Volumen
@onready var fullscreen: CheckButton = %Pantalla
@onready var resolution: OptionButton = %Resolucion
@onready var controls_label: Label = %Controles

var _entering: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameManager.in_lobby = false

	# Tema pequeño para que la interfaz case con la resolución del juego (640x360)
	var theme := Theme.new()
	theme.set_default_font_size(11)

	self.theme = theme

	%HostButton.pressed.connect(_on_host_pressed)
	%JoinButton.pressed.connect(_on_join_pressed)
	%OpcionesButton.pressed.connect(_show_options.bind(true))
	%VolverButton.pressed.connect(_show_options.bind(false))
	%SalirButton.pressed.connect(func(): get_tree().quit())
	ip_input.text_submitted.connect(func(_t): _on_join_pressed())

	for s in Settings.WINDOW_SIZES:
		resolution.add_item("%d x %d" % [s.x, s.y])
	volume.value = Settings.master_volume
	fullscreen.button_pressed = Settings.fullscreen
	resolution.select(Settings.window_size_index)
	volume.value_changed.connect(func(v): Settings.master_volume = v; Settings.apply(); Settings.save())
	fullscreen.toggled.connect(func(on): Settings.fullscreen = on; Settings.apply(); Settings.save())
	resolution.item_selected.connect(func(i): Settings.window_size_index = i; Settings.apply(); Settings.save())
	controls_label.text = _controls_text()
	UiJuice.apply(self)

	HighLevelNetworkHandler.connected_to_server.connect(_go_to_lobby, CONNECT_ONE_SHOT)
	multiplayer.connection_failed.connect(_on_connection_failed)


func _show_options(on: bool) -> void:
	options_panel.visible = on
	main_panel.visible = not on


func _on_host_pressed() -> void:
	message.text = ""
	HighLevelNetworkHandler.start_host()


func _on_join_pressed() -> void:
	message.text = "Conectando..."
	HighLevelNetworkHandler.start_client(ip_input.text.strip_edges())


func _on_connection_failed() -> void:
	message.text = "No se pudo conectar. Revisa la IP."


func _go_to_lobby() -> void:
	if _entering:
		return
	_entering = true
	GameManager.in_lobby = true
	get_tree().change_scene_to_file(LOBBY_SCENE)


func _controls_text() -> String:
	return "\n".join([
		"Moverse: A / D  ·  stick izquierdo",
		"Saltar: W / Espacio  ·  A (mando)",
		"Agacharse / deslizar: Shift  ·  stick pulsado",
		"Apuntar y disparar: ratón  ·  stick derecho + gatillo",
		"Coger / usar: E  ·  RB (mando)",
		"Lanzar: G  ·  B (mando)",
	])
