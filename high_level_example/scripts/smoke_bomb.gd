extends RigidBody2D

var shooter_id = 0

func _ready():
	# LÓGICA DEL SERVIDOR
	if multiplayer.is_server():
		# 1. Mecha de 1.5 segundos
		await get_tree().create_timer(1.5).timeout
		
		# 2. ORDENAR EXPLOSIÓN A TODOS (RPC)
		explode_rpc.rpc()
		
		# 3. Esperar a que el humo se disipe antes de borrar el objeto
		await get_tree().create_timer(5.0).timeout
		queue_free()

# Esta función se ejecuta en TODOS (Server y Clientes) al mismo tiempo
@rpc("call_local", "reliable")
func explode_rpc():
	# Congelar física
	freeze = true 
	linear_velocity = Vector2.ZERO
	
	# Ocultar la granada
	$Sprite2D.visible = false
	
	# Activar partículas
	$CPUParticles2D.emitting = true
