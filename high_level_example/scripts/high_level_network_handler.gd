extends Node

# Se emite cuando el Host inicia su servidor (para spawnear su propio jugador)
signal host_started()

# NUEVA SEÑAL: Se emite cuando nos conectamos con éxito (sea como Host o Cliente)
# Esto le dirá al Menú que oculte los botones y muestre la lista de jugadores (Lobby)
signal connected_to_server()

const PORT: int = 42069 # Puerto (debe estar abierto en Radmin/Hamachi si usas eso)

var peer: ENetMultiplayerPeer

func start_server() -> void:
	peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer


# Función para el HOST (Tú)
func start_host() -> void:
	start_server()
	host_started.emit()
	# El Host técnicamente está "conectado" a su propia sala, así que emitimos
	# la señal para que la UI cambie al Lobby.
	connected_to_server.emit()


# Función para el CLIENTE (Tu amigo)
# MODIFICADO: Ahora acepta un argumento "ip_address"
func start_client(ip_address: String = "") -> void:
	if ip_address == "":
		ip_address = "127.0.0.1" # Si no escribe nada, usa Localhost (pruebas)
		
	peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip_address, PORT)
	
	if error != OK:
		print("Error al intentar crear cliente: ", error)
		return

	multiplayer.multiplayer_peer = peer
	
	# Conectamos las señales nativas de Godot a funciones nuestras
	# para saber si la conexión funcionó o falló.
	if not multiplayer.connected_to_server.is_connected(_on_connected_ok):
		multiplayer.connected_to_server.connect(_on_connected_ok)
		
	if not multiplayer.connection_failed.is_connected(_on_connected_fail):
		multiplayer.connection_failed.connect(_on_connected_fail)


# --- CALLBACKS INTERNOS ---

func _on_connected_ok() -> void:
	print("¡Conexión exitosa!")
	# Avisamos al Menú para que cambie de pantalla
	connected_to_server.emit()

func _on_connected_fail() -> void:
	print("Fallo al conectar al servidor. Revisa la IP.")
	multiplayer.multiplayer_peer = null
	
func _ready() -> void:
	# Si el servidor se desconecta (o cierra la partida), nos vamos al menú
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_server_disconnected() -> void:
	print("Desconectado del servidor. Volviendo al menú...")
	
	# Reiniciar la variable de red para limpiar
	multiplayer.multiplayer_peer = null
	
	# Cambiar la escena al Menú
	# ¡ASEGÚRATE QUE LA RUTA ES CORRECTA!
	get_tree().change_scene_to_file("res://high_level_example/scenes/Menu.tscn")
