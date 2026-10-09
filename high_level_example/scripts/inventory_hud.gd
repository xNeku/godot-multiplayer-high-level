extends CanvasLayer
# Muestra el arma (con munición) y el objeto del jugador local.

@onready var label: Label = $Label
@onready var prompt: Label = $Aviso


func _process(_delta: float) -> void:
	if not is_inside_tree() or multiplayer == null or not multiplayer.has_multiplayer_peer():
		return
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
	prompt.text = _nearest_pickup_text(player)


# Aviso "E · Coger X" cuando hay algo al alcance
func _nearest_pickup_text(player: Node2D) -> String:
	var best: Node2D = null
	var best_d: float = player.interact_range
	for p in get_tree().get_nodes_in_group("pickups"):
		if p.has_method("is_available") and not p.is_available():
			continue
		var d: float = player.global_position.distance_to(p.global_position)
		if d <= best_d:
			best = p
			best_d = d
	if best == null:
		return ""
	var nm: String = ""
	if best.pickup_kind() == "item":
		var it = best.get_item()
		nm = it.item_name if it else ""
	else:
		var w = best.get_weapon()
		nm = w.role_name if w else ""
	return "%s · Coger %s" % [Settings.key_for("interact"), nm]
