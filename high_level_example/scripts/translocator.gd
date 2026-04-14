extends RigidBody2D

var shooter_id = 0

func _ready():
	if multiplayer.is_server():
		# Esperar 3 segundos y teletransportar
		get_tree().create_timer(3.0).timeout.connect(teleport_shooter)

func teleport_shooter():
	# Buscar al dueño de la baliza
	var player_node = get_parent().get_node_or_null(str(shooter_id))
	
	if player_node:
		print("Teletransportando a ", player_node.name)
		# Mover al jugador a mi posición actual
		player_node.global_position = global_position
		# Resetear su velocidad para que no salga disparado
		player_node.velocity = Vector2.ZERO
	
	# Desaparecer
	queue_free()
