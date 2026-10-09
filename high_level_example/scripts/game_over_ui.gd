extends CanvasLayer
# Pantalla de fin de partida: ganador y puntuaciones. La enseña end_game_sequence
# hasta que el servidor devuelve a todos al lobby.

@onready var panel: Control = $Panel
@onready var winner_label: Label = %WinnerLabel
@onready var score_label: Label = %ScoreLabel


func _ready() -> void:
	panel.visible = false


func display_results(winner_id: int) -> void:
	visible = true
	panel.visible = true
	winner_label.text = "GANA %s!" % GameManager.public_name(winner_id)
	var ids: Array = GameManager.scores.keys()
	ids.sort_custom(func(a, b): return GameManager.scores[a] > GameManager.scores[b])
	var lines: PackedStringArray = []
	for pid in ids:
		lines.append("%s   %d" % [GameManager.display_name(pid), GameManager.scores[pid]])
	score_label.text = "\n".join(lines)
	panel.modulate.a = 0.0
	create_tween().tween_property(panel, "modulate:a", 1.0, 0.4)
