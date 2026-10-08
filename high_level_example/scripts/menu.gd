extends Control

@onready var main_panel = $PanelPrincipal
@onready var lobby_panel = $LobbyPanel
@onready var ip_input = $PanelPrincipal/VBoxContainer/IpInput
@onready var player_list = $LobbyPanel/VBoxContainer/PlayerList
@onready var start_button = $LobbyPanel/VBoxContainer/StartButton
@onready var map_selector: OptionButton = $LobbyPanel/VBoxContainer/MapSelector
@onready var import_button: Button = $LobbyPanel/VBoxContainer/ImportButton

const MapLoader := preload("res://high_level_example/scripts/map_loader.gd")

# Mapas de escena antiguos (el selector se rellena por código: estos + los JSON
# de res://maps y user://maps)
@export var maps: Array[PackedScene]

# Una entrada por elemento del selector: {scene: PackedScene} o {json: ruta}
var _entries: Array = []
var _import_dialog: FileDialog

func _ready():
	# Estado inicial
	main_panel.visible = true
	lobby_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Conectar botones
	$PanelPrincipal/VBoxContainer/HostButton.pressed.connect(_on_host_pressed)
	$PanelPrincipal/VBoxContainer/JoinButton.pressed.connect(_on_join_pressed)
	start_button.pressed.connect(_on_start_pressed)
	import_button.pressed.connect(_on_import_pressed)
	_rebuild_map_list()

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
	import_button.visible = true

func _on_join_pressed():
	print("DEBUG: Botón Join presionado")
	var ip = ip_input.text
	HighLevelNetworkHandler.start_client(ip)
	start_button.visible = false
	map_selector.visible = false
	import_button.visible = false

func _on_start_pressed():
	# Iniciar juego para todos. Los mapas JSON viajan por la red (el cliente no
	# tiene por qué tener el archivo).
	var i := map_selector.selected
	if i >= 0 and i < _entries.size() and _entries[i].has("json"):
		var text := MapLoader.read_text(_entries[i]["json"])
		if text == "" or MapLoader.parse(text).is_empty():
			push_warning("Mapa JSON no válido: " + str(_entries[i]["json"]))
			return
		rpc("start_game_rpc", "", text)
	else:
		var scene_path := ""
		if i >= 0 and i < _entries.size() and _entries[i].has("scene"):
			scene_path = _entries[i]["scene"].resource_path
		rpc("start_game_rpc", scene_path, "")


# --- LISTA DE MAPAS E IMPORTACIÓN ---
func _rebuild_map_list(select_path: String = "") -> void:
	map_selector.clear()
	_entries.clear()
	for m in MapLoader.list_maps():
		var tag := "" if m["official"] else "(custom) "
		map_selector.add_item(tag + m["name"])
		_entries.append({"json": m["path"]})
		if m["path"] == select_path:
			map_selector.select(_entries.size() - 1)
	for scene in maps:
		map_selector.add_item("(antiguo) " + scene.resource_path.get_file().get_basename())
		_entries.append({"scene": scene})


func _on_import_pressed() -> void:
	if _import_dialog == null:
		_import_dialog = FileDialog.new()
		_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_import_dialog.use_native_dialog = true
		_import_dialog.filters = PackedStringArray(["*.json ; Mapa de FlashMapMaker"])
		_import_dialog.file_selected.connect(_on_import_file)
		add_child(_import_dialog)
	_import_dialog.popup_centered_ratio(0.6)


func _on_import_file(path: String) -> void:
	var text := MapLoader.read_text(path)
	var saved := MapLoader.save_custom(text, path.get_file().get_basename()) if text != "" else ""
	if saved == "":
		push_warning("No se pudo importar " + path + " (JSON no válido o demasiado grande)")
		import_button.text = "JSON no válido"
		return
	import_button.text = "Importar JSON..."
	_rebuild_map_list(saved)

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
func start_game_rpc(scene_path: String, map_json: String = ""):
	GameManager.reset_scores()
	GameManager.selected_map_json = map_json
	# Mapa de escena antiguo (solo si es uno de los del menú) o JSON recibido por red
	GameManager.selected_map_path = ""
	for scene in maps:
		if scene.resource_path == scene_path:
			GameManager.selected_map_path = scene_path
	get_tree().change_scene_to_file("res://high_level_example/scenes/high_level_example.tscn")
