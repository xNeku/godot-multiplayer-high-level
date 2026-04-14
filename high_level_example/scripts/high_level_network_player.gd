extends CharacterBody2D

# --- CONFIGURACIÓN DE MOVIMIENTO ---
const WALK_SPEED: float = 220.0
const RUN_SPEED: float = 450.0
const JUMP_VELOCITY: float = -750.0
const FRICTION: float = 1500.0
const ACCELERATION: float = 1800.0

@export var gravity: float = 2000.0 

# --- SISTEMA DE ARMAS Y CLASES ---
@export var current_weapon_data: WeaponData 
var current_role: String = "None" # Aquí guardaremos "Ninja", "Rusher", etc.
# Variables internas del arma
var current_ammo: int = 0
var can_shoot: bool = true
var can_throw: bool = true
# --- VARIABLES DE HABILIDAD ---
var current_ability: String = "NONE"
var can_use_ability: bool = true
var ability_cooldown_time: float = 3.0
var next_shot_bounces: bool = false # ¿El próximo disparo rebota?
var is_aiming_laser: bool = false
var is_ninja_clinging: bool = false
var speed_multiplier: float = 1.0 # Para la pasiva de velocidad

# --- REFERENCIAS ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hand_pivot: Node2D = $HandPivot
@onready var muzzle: Marker2D = $HandPivot/Muzzle
@onready var crosshair: Sprite2D = $Crosshair
@onready var flashlight: PointLight2D = $HandPivot/PointLight2D 
@onready var camera: Camera2D = $Camera2D
@onready var weapon_sprite: Sprite2D = $HandPivot/Sprite2D
@onready var laser_sight: Line2D = $HandPivot/LaserSight

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	if is_multiplayer_authority():
		crosshair.visible = true
		if flashlight: flashlight.enabled = true
		camera.enabled = true
		camera.make_current()
	else:
		crosshair.visible = false
		if flashlight: flashlight.enabled = false
		camera.enabled = false

	# SISTEMA DE CLASES: Cargar la clase seleccionada en el menú
	if is_multiplayer_authority():
		var my_class_path = GameManager.selected_class_path
		if my_class_path != "":
			apply_class_from_path(my_class_path)
			sync_class_rpc.rpc(my_class_path)

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		if Input.is_action_pressed("ui_left") or Input.is_action_pressed("ui_right"): # Solo al movernos
			print("Rol: ", current_role, " | Es Ninja: ", current_role == "Ninja", " | Toca pared: ", is_on_wall(), " | Toca techo: ", is_on_ceiling())

	# --- LÓGICA NINJA: AGARRE A PAREDES ---
	# Comprobamos si el arma actual pertenece al rol "Ninja"
	var is_ninja = (current_role == "Ninja") # ¡Ahora sí!
	if current_weapon_data and "role_name" in current_weapon_data:
		is_ninja = (current_weapon_data.role_name == "Ninja")
	
	# Detectar si estamos tocando pared o techo
	var on_wall = is_on_wall() or is_on_ceiling()
	
	# Si somos Ninja y tocamos pared, activamos modo escalada
	if is_ninja and on_wall:
		is_ninja_clinging = true
		velocity.y = 0 # Anular gravedad
		
		# Movimiento vertical libre en pared (escalar)
		var vertical_input = Input.get_axis("ui_up", "ui_down")
		velocity.y = vertical_input * WALK_SPEED * speed_multiplier
		
		# Movimiento horizontal (moverse por el techo o pegarse)
		var horizontal_input = Input.get_axis("ui_left", "ui_right")
		velocity.x = horizontal_input * WALK_SPEED * speed_multiplier
		
	else:
		is_ninja_clinging = false
		
		# --- FÍSICA NORMAL ---
		# 1. Gravedad
		if not is_on_floor():
			velocity.y += gravity * delta

		# 2. Salto
		if Input.is_action_just_pressed("ui_up") and is_on_floor():
			velocity.y = JUMP_VELOCITY

		# 3. Movimiento Horizontal (Con multiplicador de velocidad)
		var is_running: bool = Input.is_action_pressed("ui_run")
		var base_speed = RUN_SPEED if is_running else WALK_SPEED
		# Aplicamos la pasiva de velocidad (speed_multiplier será 1.0 en otros, 1.3 en Ninja)
		var final_speed = base_speed * speed_multiplier 
		
		var direction: float = Input.get_axis("ui_left", "ui_right")
		
		if direction:
			velocity.x = move_toward(velocity.x, direction * final_speed, ACCELERATION * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

	move_and_slide()

	# ACTUALIZAR LÁSER SI ESTÁ ACTIVO (Sniper)
	if is_aiming_laser:
		update_laser_trajectory()

	# 4. Combate
	update_aiming()
	# Pasamos is_running para la animación, aunque en modo Ninja la animación podría variar
	update_animation(Input.is_action_pressed("ui_run"))
	
	# 5. DISPARAR
	if Input.is_action_pressed("shoot") and can_shoot:
		shoot()

	# 6. HABILIDAD
	if Input.is_action_just_pressed("ability") and can_use_ability:
		use_ability()
		
	# 7. LANZAR OBJETO (G)
	if Input.is_action_just_pressed("throw") and can_throw:
		throw_object()

func update_aiming() -> void:
	var mouse_pos = get_global_mouse_position()
	crosshair.global_position = mouse_pos
	hand_pivot.look_at(mouse_pos)
	
	if mouse_pos.x < global_position.x:
		animated_sprite.flip_h = true
		hand_pivot.scale.y = -1 
	else:
		animated_sprite.flip_h = false
		hand_pivot.scale.y = 1

func update_animation(running: bool) -> void:
	if not is_on_floor():
		animated_sprite.play("jump")
	else:
		if abs(velocity.x) > 10:
			if running: animated_sprite.play("run")
			else: animated_sprite.play("walk")
		else:
			animated_sprite.play("idle")

# --- GESTIÓN DE CLASES ---

func apply_class_from_path(path: String):
	var class_data = load(path) as ClassData
	
	if class_data:
		# --- NUEVO: GUARDAR EL ROL ---
		current_role = class_data.role_name
		print("Rol aplicado: ", current_role) # Chivato para consola
		speed_multiplier = class_data.speed_modifier
		# 1. Equipar Arma
		if class_data.primary_weapon:
			equip_weapon(class_data.primary_weapon)
		
		# 2. Aplicar Pasivas (Linterna) - ¡AÑADIDO!
		if flashlight:
			flashlight.scale = class_data.flashlight_scale
			flashlight.energy = class_data.flashlight_energy
		
		# 3. Guardar Habilidad - ¡AÑADIDO!
		current_ability = class_data.ability_type
		ability_cooldown_time = class_data.ability_cooldown
	else:
		print("ERROR: No se pudo cargar la clase en la ruta: ", path)

@rpc("call_remote", "reliable")
func sync_class_rpc(path: String):
	apply_class_from_path(path)

func equip_weapon(new_weapon: WeaponData):
	current_weapon_data = new_weapon
	current_ammo = new_weapon.max_ammo
	
	if weapon_sprite and new_weapon.texture:
		weapon_sprite.texture = new_weapon.texture
	else:
		print("ERROR: Falta el Sprite o la Textura del arma.")

# --- HABILIDADES ---

func use_ability():
	if current_ability == "NONE": return
	
	# Activar Cooldown
	can_use_ability = false
	get_tree().create_timer(ability_cooldown_time).timeout.connect(func(): can_use_ability = true)
	
	print("Usando habilidad: ", current_ability)
	
	match current_ability:
		"DASH":
			# --- MODIFICADO: DASH HACIA EL RATÓN ---
			
			# 1. Calcular dirección hacia el ratón
			var mouse_pos = get_global_mouse_position()
			# Restamos la posición del ratón menos la nuestra para obtener el vector de dirección
			var dash_dir = (mouse_pos - global_position).normalized()
			
			# 2. Aplicar impulso (Velocidad reducida)
			# Hemos bajado de 1500 a 900 para que sea más corto.
			# ¡Ajusta este 900 si lo quieres más largo o más corto!
			velocity = dash_dir * 900
			
		"RICOCHET":
			print("¡Cargando munición de rebote!")
			next_shot_bounces = true
			
			# --- NUEVO: ACTIVAR LÁSER ---
			is_aiming_laser = true
			laser_sight.visible = true
			
		"MELEE":
			print("¡Cuchillazo!")
			# Animación rápida de golpe (podrías mover el HandPivot bruscamente)
			var tween = create_tween()
			tween.tween_property(hand_pivot, "position", Vector2(30, 0).rotated(hand_pivot.rotation), 0.1)
			tween.tween_property(hand_pivot, "position", Vector2.ZERO, 0.1)
			
			# Lógica de daño (Raycast de corto alcance)
			# Reutilizamos el código del Láser pero con rango corto (50px)
			var space_state = get_world_2d().direct_space_state
			var start = muzzle.global_position
			var end = start + Vector2.RIGHT.rotated(hand_pivot.rotation) * 60 # 60px de alcance
			var query = PhysicsRayQueryParameters2D.create(start, end)
			query.collision_mask = 2 # Solo jugadores
			
			var result = space_state.intersect_ray(query)
			if result and result.collider is CharacterBody2D:
				# Ejecución instantánea (Daño 10)
				result.collider.hit(name.to_int(), false, 10)
# --- DISPARO ---

func shoot() -> void:
	if not current_weapon_data: return
	if current_ammo <= 0: return

	can_shoot = false
	get_tree().create_timer(current_weapon_data.fire_rate).timeout.connect(func(): can_shoot = true)
	current_ammo -= 1
	
	# Calcular rebotes totales (Base del arma + Habilidad Sniper si está activa)
	# (Asumimos que la variable next_shot_bounces existe si implementaste al Sniper, si no, es 0)
	var total_bounces = current_weapon_data.bounces
	if "next_shot_bounces" in self and get("next_shot_bounces"):
		total_bounces += 1
		set("next_shot_bounces", false)

	# Llamada RPC con todos los datos
	request_shoot.rpc_id(1, 
		muzzle.global_position, 
		hand_pivot.rotation, 
		current_weapon_data.bullet_speed, 
		current_weapon_data.spread, 
		current_weapon_data.bullet_count,
		current_weapon_data.return_ammo_on_kill,
		total_bounces # <--- NUEVO ARGUMENTO
	)

func update_laser_trajectory():
	# Limpiamos la línea anterior
	laser_sight.clear_points()
	
	# Punto de inicio (Local al HandPivot, que es (0,0) si el láser está ahí, 
	# o la posición local del Muzzle)
	var start_pos_global = muzzle.global_position
	laser_sight.add_point(laser_sight.to_local(start_pos_global))
	
	# Dirección actual del disparo
	var direction = Vector2.RIGHT.rotated(hand_pivot.rotation)
	var max_distance = 2000.0 # Qué tan lejos llega el láser
	
	# --- RAYCAST 1: Del arma a la primera pared ---
	var space_state = get_world_2d().direct_space_state
	
	# Creamos la consulta física
	var query = PhysicsRayQueryParameters2D.create(start_pos_global, start_pos_global + direction * max_distance)
	# IMPORTANTE: Que solo choque con el SUELO (Capa 1). 
	# Si quieres que choque con jugadores, suma la Capa 2 (1 + 2 = 3).
	query.collision_mask = 1 
	
	var result = space_state.intersect_ray(query)
	
	if result:
		# ¡CHOQUE 1!
		var hit_pos = result.position
		var normal = result.normal
		
		# Dibujamos hasta el choque
		laser_sight.add_point(laser_sight.to_local(hit_pos))
		
		# --- RAYCAST 2: El Rebote ---
		# Calculamos el vector de rebote matemático
		var bounce_dir = direction.bounce(normal)
		
		# Lanzamos segundo rayo desde el punto de impacto (un pelín separado para no chocar con la misma pared)
		var bounce_start = hit_pos + (normal * 1.0)
		var query2 = PhysicsRayQueryParameters2D.create(bounce_start, bounce_start + bounce_dir * max_distance)
		query2.collision_mask = 1
		
		var result2 = space_state.intersect_ray(query2)
		
		if result2:
			# Dibujamos hasta el segundo choque
			laser_sight.add_point(laser_sight.to_local(result2.position))
		else:
			# Si no choca con nada más, dibujamos al infinito
			laser_sight.add_point(laser_sight.to_local(bounce_start + bounce_dir * max_distance))
			
	else:
		# Si no choca con nada al principio, línea recta infinita
		laser_sight.add_point(laser_sight.to_local(start_pos_global + direction * max_distance))
		
		
		
@rpc("any_peer", "call_local", "reliable")
func request_shoot(pos: Vector2, rot: float, speed: float, spread: float, count: int, return_ammo: bool, bounces_amount: int) -> void:
	if !multiplayer.is_server(): return
	if not current_weapon_data or not current_weapon_data.bullet_scene: return
	
	for i in range(count):
		var bullet = current_weapon_data.bullet_scene.instantiate()
		get_parent().add_child(bullet, true)
		bullet.global_position = pos
		
		var spread_angle = deg_to_rad(randf_range(-spread, spread))
		var final_angle = rot + spread_angle
		bullet.rotation = final_angle
		
		# ASIGNAR TODOS LOS DATOS A LA BALA
		if "speed" in bullet: bullet.speed = speed
		if "direction" in bullet: bullet.direction = Vector2.RIGHT.rotated(final_angle)
		if "shooter_id" in bullet: bullet.shooter_id = multiplayer.get_remote_sender_id()
		if "return_ammo_on_kill" in bullet: bullet.return_ammo_on_kill = return_ammo
		if "bounces" in bullet: bullet.bounces = bounces_amount # <--- APLICAR REBOTES

# --- DAÑO Y VICTORIA ---

func hit(shooter_id: int, ammo_back: bool = false, damage_amount: int = 1) -> void:
	if !multiplayer.is_server(): return
	
	print("HIT! Jugador ", name, " muerto por ", shooter_id)
	var current_points = GameManager.add_point(shooter_id)
	
	# Lógica de devolver munición al ninja
	if ammo_back:
		# Buscamos al jugador asesino y le recargamos
		var shooter_node = get_parent().get_node_or_null(str(shooter_id))
		if shooter_node:
			shooter_node.regain_ammo.rpc() # Llamamos a una función nueva en el asesino
			
	if current_points >= 10:
		game_over_rpc.rpc(shooter_id)
	else:
		respawn_rpc.rpc()

@rpc("any_peer", "call_local", "reliable")
func respawn_rpc() -> void:
	print("RESPAWN: ", name)
	if is_multiplayer_authority():
		var random_x = randf_range(100, 1100) 
		var random_y = randf_range(100, 500)
		global_position = Vector2(random_x, random_y)
		velocity = Vector2.ZERO

@rpc("any_peer", "call_local", "reliable")
func game_over_rpc(winner_id: int) -> void:
	print("!!! FIN DE LA PARTIDA !!! Ganador: ", winner_id)
	
	var level = get_tree().current_scene
	if level.has_method("end_game_sequence"):
		level.end_game_sequence(winner_id)
	
	if multiplayer.is_server():
		get_tree().create_timer(5.0).timeout.connect(func():
			multiplayer.multiplayer_peer.close()
		)
		
@rpc("call_local", "reliable")
func regain_ammo():
	current_ammo += 1
	print("¡Munición recuperada por matar!")
	# Opcional: Sonido de "clink" satisfactorio
	
func throw_object():
	var class_data = load(GameManager.selected_class_path) as ClassData
	if not class_data or not class_data.throwable_scene: return
	
	can_throw = false
	get_tree().create_timer(class_data.throwable_cooldown).timeout.connect(func(): can_throw = true)
	
	var mouse_pos = get_global_mouse_position()
	var throw_dir = (mouse_pos - global_position).normalized()
	throw_dir.y -= 0.2 # Arco ligero
	
	# Enviamos la RUTA de la escena del objeto
	request_throw.rpc_id(1, class_data.throwable_scene.resource_path, hand_pivot.global_position, throw_dir, class_data.throw_force)

@rpc("any_peer", "call_local", "reliable")
func request_throw(scene_path: String, pos: Vector2, dir: Vector2, force: float):
	if !multiplayer.is_server(): return
	
	var scene = load(scene_path)
	if scene:
		var projectile = scene.instantiate()
		get_parent().add_child(projectile, true)
		projectile.global_position = pos
		
		# Aplicar fuerza física
		if projectile is RigidBody2D:
			projectile.linear_velocity = dir * force
			# Añadir rotación aleatoria para que quede chulo
			projectile.angular_velocity = randf_range(-10, 10)
		
		# Asignar ID
		if "shooter_id" in projectile:
			projectile.shooter_id = multiplayer.get_remote_sender_id()
