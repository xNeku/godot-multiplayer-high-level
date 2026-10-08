extends Node
# Autoload. Crea el servidor o el cliente ENet y avisa al menú cuando hay conexión.

# Se emite al estar dentro (el host al crear la sala, el cliente al conectar)
signal connected_to_server()

const PORT: int = 42069 # Puerto (hay que abrirlo en la VPN / router)
const MENU_SCENE: String = "res://high_level_example/scenes/Menu.tscn"


func _ready() -> void:
	# Si el servidor se cae, volvemos al menú
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.connected_to_server.connect(func(): connected_to_server.emit())
	multiplayer.connection_failed.connect(func(): multiplayer.multiplayer_peer = null)


# Devuelve OK o el error de ENet (p. ej. puerto ocupado)
func start_host() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	connected_to_server.emit()
	return OK


# Sin IP usa localhost (pruebas)
func start_client(ip_address: String = "") -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip_address if ip_address != "" else "127.0.0.1", PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = null
	GameManager.in_lobby = false
	get_tree().change_scene_to_file(MENU_SCENE)
