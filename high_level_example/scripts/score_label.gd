extends Label
# Marcador pequeño de la partida (se actualiza cuando el servidor reparte puntos).


func _ready() -> void:
	text = ""
	GameManager.score_updated.connect(_update_text)


func _update_text(_id, _points) -> void:
	var lines: PackedStringArray = []
	for pid in GameManager.scores:
		lines.append("%s: %d" % [GameManager.display_name(pid), GameManager.scores[pid]])
	text = "\n".join(lines)
