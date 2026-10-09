extends RigidBody2D
# Cadáver cosmético: sale despedido. Local a cada peer (no se replica).
# Con el mapache: reproduce "die" y se queda en el suelo con "corpse" hasta la
# siguiente ronda. Con el muñeco por piezas: copia del cuerpo que se desvanece.

@export var life_time: float = 4.0


func setup(source_visual: Node2D, impulse: Vector2, mapache: AnimatedSprite2D = null) -> void:
	linear_velocity = impulse
	if mapache and mapache.get("usar_mapache"):
		_setup_raccoon(mapache, impulse)
		return
	var body: Node2D = source_visual.duplicate()
	body.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(body)
	body.position = Vector2.ZERO
	angular_velocity = clampf(impulse.x * 0.02, -12.0, 12.0)
	var tw := create_tween()
	tw.tween_interval(life_time * 0.6)
	tw.tween_property(self, "modulate:a", 0.0, life_time * 0.4)
	tw.tween_callback(queue_free)


func _setup_raccoon(src: AnimatedSprite2D, impulse: Vector2) -> void:
	lock_rotation = true
	# Frames de 33x33: con el centro a 10 px del suelo (radio del círculo de colisión),
	# los pies/cuerpo tumbado caen en el suelo
	var pos := Vector2(0.5, -3.5)
	# Cae hacia atrás respecto al disparo: si sale despedido a la izquierda, mira a la derecha
	var flip: bool = impulse.x > 0.0
	var body := _sprite(src.sprite_frames, pos, flip)
	var tint_src := src.get_node_or_null("Tinte") as AnimatedSprite2D
	var tint: AnimatedSprite2D = null
	if tint_src:
		tint = _sprite(tint_src.sprite_frames, Vector2.ZERO, flip)
		tint.self_modulate = tint_src.self_modulate
		body.add_child(tint)
	body.play(&"die")
	if tint:
		tint.play(&"die")
	body.animation_finished.connect(func():
		body.play(&"corpse")
		if tint:
			tint.play(&"corpse"))


func _sprite(frames: SpriteFrames, pos: Vector2, flip: bool) -> AnimatedSprite2D:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = frames
	a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	a.position = pos
	a.flip_h = flip
	if pos != Vector2.ZERO:
		add_child(a)
	return a
