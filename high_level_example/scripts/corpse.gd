extends RigidBody2D
# Cadáver del mapache: sale despedido, reproduce "die" y se queda en el suelo con
# "corpse" hasta la siguiente ronda. Local a cada peer (no se replica).


func setup(mapache: AnimatedSprite2D, impulse: Vector2) -> void:
	linear_velocity = impulse
	lock_rotation = true
	# Frames de 33x33: con el centro a 10 px del suelo (radio del círculo de colisión),
	# el cuerpo tumbado cae justo en el suelo
	var flip: bool = impulse.x > 0.0
	var body := _sprite(mapache.sprite_frames, flip)
	body.position = Vector2(0.5, -3.5)
	add_child(body)
	var tint_src := mapache.get_node_or_null("Tinte") as AnimatedSprite2D
	var tint: AnimatedSprite2D = null
	if tint_src:
		tint = _sprite(tint_src.sprite_frames, flip)
		tint.self_modulate = tint_src.self_modulate
		body.add_child(tint)
	body.play(&"die")
	if tint:
		tint.play(&"die")
	body.animation_finished.connect(func():
		body.play(&"corpse")
		if tint:
			tint.play(&"corpse"))


func _sprite(frames: SpriteFrames, flip: bool) -> AnimatedSprite2D:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = frames
	a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	a.flip_h = flip
	return a
