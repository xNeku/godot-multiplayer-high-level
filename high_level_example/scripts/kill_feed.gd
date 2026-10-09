extends CanvasLayer
# Lista de muertes arriba a la derecha. Cada entrada se desvanece sola.

@export var entry_time: float = 4.0
@export var max_entries: int = 5

@onready var box: VBoxContainer = $Lista


func add_entry(killer_id: int, victim_id: int) -> void:
	var l := Label.new()
	var k: String = GameManager.display_name(killer_id)
	var v: String = GameManager.display_name(victim_id)
	l.text = ("%s SE MATO" % v) if killer_id == victim_id else ("%s  X  %s" % [k, v])
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.theme_type_variation = &"LabelMini"
	var mine: int = multiplayer.get_unique_id()
	if killer_id == mine and victim_id != mine:
		l.add_theme_color_override("font_color", Color(0.35, 1.0, 0.5))
	elif victim_id == mine:
		l.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	box.add_child(l)
	while box.get_child_count() > max_entries:
		box.get_child(0).queue_free()
		box.remove_child(box.get_child(0))
	var tw := l.create_tween()
	tw.tween_interval(entry_time)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)

