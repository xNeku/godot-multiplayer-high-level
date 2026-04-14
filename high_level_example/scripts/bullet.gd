extends Area2D

# Configuración (se llena desde el Player al disparar)
var speed = 2000.0
var direction = Vector2.RIGHT
var damage = 1
var bounces = 0
var shooter_id = 0
var return_ammo_on_kill = false # Nuevo para Ninja

# Protección para no matarse a sí mismo instantáneamente
var spawn_protection_time = 0.1 

func _ready():
	var notifier = VisibleOnScreenNotifier2D.new()
	notifier.screen_exited.connect(queue_free)
	add_child(notifier)
	
	# Autodestrucción por seguridad tras 10 segs
	get_tree().create_timer(10.0).timeout.connect(queue_free)

func _physics_process(delta):
	# ROTACIÓN VISUAL: Si es un Tomahawk, que gire
	# (Asumimos que si devuelve munición es un hacha o similar)
	if return_ammo_on_kill:
		# Si tienes un nodo Sprite2D hijo, gíralo
		if has_node("Sprite2D"):
			$Sprite2D.rotate(25.0 * delta)

	# LÓGICA DE MOVIMIENTO (Solo Servidor)
	if !multiplayer.is_server(): return
	
	spawn_protection_time -= delta

	# Movimiento por Raycast (Anti-Tunneling)
	var motion = direction * speed * delta
	var current_pos = global_position
	var target_pos = current_pos + motion
	
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(current_pos, target_pos)
	query.collision_mask = 1 + 2 # Capa 1 (Suelo) + Capa 2 (Jugadores)
	
	if spawn_protection_time > 0:
		query.exclude = [self] 

	var result = space_state.intersect_ray(query)
	
	if result:
		# IMPACTO
		global_position = result.position
		var collider = result.collider
		
		# A. Ignorar al tirador al nacer
		if collider.name == str(shooter_id) and spawn_protection_time > 0:
			global_position = target_pos
			return

		# B. IMPACTO CON JUGADOR
		if collider is CharacterBody2D:
			print("¡Impacto en ", collider.name, "!")
			if collider.has_method("hit"):
				# Pasamos el shooter_id y si devuelve munición
				collider.hit(shooter_id, return_ammo_on_kill)
			queue_free()
			return
			
		# C. IMPACTO CON PARED (Rebote)
		else:
			if bounces > 0:
				handle_bounce(result.normal)
			else:
				queue_free()
	else:
		# Sin impacto, mover normal
		global_position = target_pos

func handle_bounce(normal: Vector2):
	direction = direction.bounce(normal)
	rotation = direction.angle()
	bounces -= 1
	# Empujar un poquito fuera de la pared para no atascarse
	global_position += normal * 2.0
