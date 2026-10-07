extends Node2D
# Hilo decapitador: colocado en una puerta, mata a quien lo cruce (menos su dueño).
# Un solo uso.

var shooter_id: int = 0

@onready var area: Area2D = $Zona


func _ready() -> void:
	add_to_group("hilos")
	if multiplayer.is_server():
		area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.has_method("hit") or body.name == str(shooter_id):
		return
	body.hit(shooter_id)
	_cut.rpc()
	await get_tree().create_timer(0.4).timeout
	queue_free()


@rpc("authority", "call_local", "reliable")
func _cut() -> void:
	$Hilo.visible = false
	$Chispa.emitting = true
