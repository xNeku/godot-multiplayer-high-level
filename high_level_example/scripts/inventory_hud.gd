extends CanvasLayer
# Muestra el arma (con munición) y el objeto del jugador local.

@onready var label: Label = $Label


func _process(_delta: float) -> void:
	var player := get_node_or_null("../PlayerSpawnContainer/" + str(multiplayer.get_unique_id()))
	if player == null:
		label.text = ""
		return
	var weapon_text := "—"
	var wd: WeaponData = player.current_weapon_data
	if wd:
		var ammo: String = "∞" if player.current_ammo < 0 else str(player.current_ammo)
		weapon_text = "%s %s/%d" % [wd.role_name, ammo, wd.max_ammo] if player.current_ammo >= 0 else "%s ∞" % wd.role_name
	var item_text := "—"
	if player.current_item:
		item_text = player.current_item.item_name
	label.text = "Arma: %s\nObjeto: %s" % [weapon_text, item_text]
