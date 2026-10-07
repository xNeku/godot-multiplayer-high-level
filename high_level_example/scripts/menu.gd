extends Control

@onready var main_panel = $PanelPrincipal
@onready var lobby_panel = $LobbyPanel
@onready var ip_input = $PanelPrincipal/VBoxContainer/IpInput
@onready var player_list = $LobbyPanel/VBoxContainer/PlayerList
@onready var start_button = $LobbyPanel/VBoxContainer/StartButton
@onready var map_selector: OptionButton = $LobbyPanel/VBoxContainer/MapSelector

# Mismo orden que los elementos del MapSelector (se editan en Menu.tscn)
@export var maps: Array[PackedScene]

func _ready():
	# Estado inicial
	main_panel.visible = true
	lobby_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Conectar botones
	$PanelPrincipal/VBoxContainer/HostButton.pressed.connect(_on_host_pressed)
	$PanelPrincipal/VBoxContainer/JoinButton.pressed.connect(_on_join_pressed)
	start_button.pressed.connect(_on_start_pressed)

	# --- CONEXIONES DE RED ---
	# 1. Si el Handler nos dice "Ya estás dentro", mostramos el lobby
	HighLevelNetworkHandler.connected_to_server.connect(_on_connection_success)
	
	# 2. Si entra alguien nuevo (o si yo entro y veo a otros)
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	
	# 3. IMPORTANTE: Si se pierde la conexión con el server
	multiplayer.server_disconnected.connect(_on_server_disconnected)

# --- BOTONES ---
func _on_host_pressed():
	print("DEBUG: Botón Host presionado")
	HighLevelNetworkHandler.start_host()
	start_button.visible = true
	map_selector.visible = true

func _on_join_pressed():
	print("DEBUG: Botón Join presionado")
	var ip = ip_input.text
	HighLevelNetworkHandler.start_client(ip)
	start_button.visible = false
	map_selector.visible = false

func _on_start_pressed():
	# Iniciar juego para todos
	rpc("start_game_rpc", map_selector.selected)

# --- LOGICA LOBBY ---
func _on_connection_success():
	print("DEBUG: ¡Conexión establecida! Entrando al Lobby...")
	main_panel.visible = false
	lobby_panel.visible = true
	update_player_list()

func _on_player_connected(_id):
	print("DEBUG: Un jugador se ha conectado: ", _id)
	update_player_list()

func _on_player_disconnected(_id):
	print("DEBUG: Un jugador se ha desconectado: ", _id)
	update_player_list()

func _on_server_disconnected():
	print("DEBUG: Desconectado del servidor. Volviendo al menú.")
	main_panel.visible = true
	lobby_panel.visible = false
	player_list.clear()

func update_player_list():
	print("--- ACTUALIZANDO LISTA DE JUGADORES ---")
	player_list.clear()
	
	# 1. Añadirme a mí mismo
	var my_id = multiplayer.get_unique_id()
	print("  > Añadiéndome a mí: ", my_id)
	player_list.add_item("Yo (" + str(my_id) + ")")
	
	# 2. Añadir a los demás peers conectados
	var peers = multiplayer.get_peers()
	print("  > Otros peers encontrados: ", peers)
	
	for peer_id in peers:
		player_list.add_item("Jugador " + str(peer_id))

# --- CAMBIO DE ESCENA ---
@rpc("call_local", "reliable")
func start_game_rpc(map_index: int):
	GameManager.reset_scores()
	if map_index >= 0 and map_index < maps.size():
		GameManager.selected_map_path = maps[map_index].resource_path
	get_tree().change_scene_to_file("res://high_level_example/scenes/high_level_example.tscn")
