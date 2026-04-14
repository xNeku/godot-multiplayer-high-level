extends RigidBody2D

var shooter_id = 0
var damage = 3 # Daño fuerte

func _ready():
	# Si toca a alguien en el área, explota
	$Area2D.body_entered.connect(_on_target_entered)
	
	# Destruir tras 20 segundos si nadie la pisa
	if multiplayer.is_server():
		get_tree().create_timer(20.0).timeout.connect(queue_free)

func _on_target_entered(body):
	if !multiplayer.is_server(): return
	
	# No explotar con el dueño (opcional, por si la pisas tú mismo)
	if body.name == str(shooter_id): return 
	
	if body is CharacterBody2D:
		explode(body)

func explode(victim):
	print("¡BOOM! Claymore explotó en ", victim.name)
	if victim.has_method("hit"):
		victim.hit(shooter_id)
	
	# Aquí instanciarías partículas de explosión
	queue_free()
