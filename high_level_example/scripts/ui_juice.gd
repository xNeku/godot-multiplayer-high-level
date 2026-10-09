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
	# Con mando/teclado el botón enfocado también crece
	b.focus_entered.connect(func(): _tween(b, 1.07, 0.08))
	b.focus_exited.connect(func(): _tween(b, 1.0, 0.1))
	b.pressed.connect(func():
		b.scale = Vector2(0.94, 0.94)
		_tween(b, 1.07, 0.12))


static func _tween(b: Button, s: float, t: float) -> void:
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2(s, s), t).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# El botón A del mando también es "ui_up" (saltar), así que la navegación de Godot
# lo tomaría como "subir". Esto lo convierte en "pulsar" sobre el control enfocado.
# Llamar desde _input; devuelve true si lo ha gestionado.
static func pad_accept(vp: Viewport, event: InputEvent) -> bool:
	if not (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A):
		return false
	var f := vp.gui_get_focus_owner()
	if f == null:
		return false
	vp.set_input_as_handled()
	if not event.pressed:
		return true
	if f is OptionButton:
		(f as OptionButton).show_popup()
	elif f is BaseButton:
		var b := f as BaseButton
		if b.toggle_mode:
			b.button_pressed = not b.button_pressed
		else:
			b.pressed.emit()
	return true


# Volver/cancelar: Esc o B del mando
static func is_cancel(event: InputEvent) -> bool:
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B and event.pressed:
		return true
	return event.is_action_pressed("ui_cancel")
