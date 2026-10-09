extends MultiplayerSpawner

@export var network_player: PackedScene

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(remove_player)

	# Si soy el servidor, tengo que spawnear a los que YA están conectados (del Lobby)
	if multiplayer.is_server():
		# Margen para que los clientes terminen de cargar la escena (cambio de ronda)
		await get_tree().create_timer(0.8).timeout
		# 1. Spawneame a mí (Host)
		spawn_player(1)

		# 2. Spawnea a los clientes que ya estaban en el lobby
		for peer_id in multiplayer.get_peers():
			spawn_player(peer_id)
		# 3. Y a los bots
		for bot_id in GameManager.bots:
			spawn_player(bot_id)


# Margen para que el cliente que entra termine de cargar la escena antes de spawnearlo
func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	await get_tree().create_timer(0.8).timeout
	if multiplayer.get_peers().has(id):
		spawn_player(id)


func spawn_player(id: int) -> void:
	if !multiplayer.is_server(): return

	var player: Node = network_player.instantiate()

	# Node name is synchronized through MultiplayerSpawner, we can use this to set authority to the player.
	player.name = str(id)

	get_node(spawn_path).call_deferred("add_child", player)


func remove_player(id: int) -> void:
	if !multiplayer.is_server(): return
	# Quitar al jugador del que se fue (el spawner lo borra también en los clientes)
	var player := get_node(spawn_path).get_node_or_null(str(id))
	if player:
		player.queue_free()
