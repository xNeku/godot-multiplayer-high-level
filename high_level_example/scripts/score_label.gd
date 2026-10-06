extends Label


func _ready() -> void:
	text = ""
	GameManager.score_updated.connect(_update_text)


func _update_text(_id, _points) -> void:
	var lines: PackedStringArray = []
	for pid in GameManager.scores:
		lines.append("P%s: %d" % [pid, GameManager.scores[pid]])
	text = "\n".join(lines)
