extends Node2D
# Explosión: llama a Fx.explosion (fuego, chispas, onda, humo y quemadura) y sacude
# la cámara de todos los jugadores según la distancia.

# Sacudida: shake_near pegado a la explosión, baja con la distancia hasta shake_far,
# que la sienten todos los jugadores del mapa estén donde estén.
func play(max_radius: float, color: Color = Color(1.0, 0.55, 0.1), shake_near: float = 18.0, shake_far: float = 4.0) -> void:
	# Azul = PEM (eléctrica, sin fuego)
	var kind: int = 1 if color.b > color.r else 0
	Fx.explosion(global_position, max_radius, kind)
	# Cada peer sacude solo su cámara (la del jugador que controla)
	for n in get_tree().get_nodes_in_group("emp_affected"):
		if n.has_method("shake") and n.is_multiplayer_authority():
			var d: float = global_position.distance_to(n.global_position)
			var k: float = clampf(1.0 - d / (max_radius * 6.0), 0.0, 1.0)
			n.shake(lerpf(shake_far, shake_near, k * k))
