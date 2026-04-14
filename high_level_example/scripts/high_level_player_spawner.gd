extends MultiplayerSpawner

@export var network_player: PackedScene

func _ready() -> void:
	multiplayer.peer_connected.connect(spawn_player)
	#multiplayer.peer_disconnected.connect(remove_player) # (Opcional: crear esta func)
	
	# Si soy el servidor, tengo que spawnear a los que YA están conectados (del Lobby)
	if multiplayer.is_server():
		# 1. Spawneame a mí (Host)
		spawn_player(1)
		
		# 2. Spawnea a los clientes que ya estaban en el lobby
		for peer_id in multiplayer.get_peers():
			spawn_player(peer_id)


func spawn_player(id: int) -> void:
	if !multiplayer.is_server(): return

	var player: Node = network_player.instantiate()

	# Node name is synchronized through MultiplayerSpawner, we can use this to set authority to the player.
	player.name = str(id)

	get_node(spawn_path).call_deferred("add_child", player)


# In this function, which is connected to the "host_started" signal in the high_level_network_handler
# class, we spawn the server player. Easy right?
func spawn_host_player() -> void:
	if !multiplayer.is_server(): return
	spawn_player(multiplayer.get_unique_id())
