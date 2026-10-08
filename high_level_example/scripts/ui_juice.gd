extends RefCounted
# Un poco de vida para los botones: crecen al pasar el ratón y dan un golpecito al pulsar.

static func apply(root: Node) -> void:
	for n in root.find_children("*", "Button", true, false):
		attach(n as Button)


static func attach(b: Button) -> void:
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	b.pivot_offset = b.size * 0.5
	b.mouse_entered.connect(func(): _tween(b, 1.07, 0.08))
	b.mouse_exited.connect(func(): _tween(b, 1.0, 0.1))
	b.pressed.connect(func():
		b.scale = Vector2(0.94, 0.94)
		_tween(b, 1.07, 0.12))


static func _tween(b: Button, s: float, t: float) -> void:
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2(s, s), t).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
