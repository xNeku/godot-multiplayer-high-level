extends CanvasLayer
# Muestra el arma (con munición) y el objeto del jugador local, y el aviso de coger.
# Se refresca 15 veces por segundo (no hace falta más para texto).

const REFRESH: float = 1.0 / 15.0

@onready var label: Label = $Label
@onready var prompt: Label = $Aviso

var _player: Node2D
var _left: float = 0.0


func _process(delta: float) -> void:
	_left -= delta
	if _left > 0.0:
		return
	_left = REFRESH
	if multiplayer == null or not multiplayer.has_multiplayer_peer():
		return
	if not is_instance_valid(_player):
		_player = GameManager.player_node(multiplayer.get_unique_id())
		if _player == null:
			label.text = ""
			prompt.text = ""
			return
	var weapon_text := "-"
	var wd: WeaponData = _player.current_weapon_data
	if wd:
		weapon_text = "%s %d/%d" % [wd.role_name, _player.current_ammo, wd.max_ammo] if _player.current_ammo >= 0 else wd.role_name
	var item_text: String = _player.current_item.item_name if _player.current_item else "-"
	label.text = "ARMA: %s\nOBJETO: %s" % [weapon_text, item_text]
	prompt.text = _pickup_text()


# Aviso "E: COGER X" cuando hay algo al alcance (lo mismo que cogería el botón)
func _pickup_text() -> String:
	var best: Node2D = _player.nearest_pickup(_player.interact_range)
	if best == null:
		return ""
	var thing = best.get_item() if best.pickup_kind() == "item" else best.get_weapon()
	var nm: String = ""
	if thing:
		nm = thing.item_name if best.pickup_kind() == "item" else thing.role_name
	return "%s: COGER %s" % [Settings.key_for("interact"), nm]
