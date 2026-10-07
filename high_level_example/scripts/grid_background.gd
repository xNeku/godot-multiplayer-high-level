extends Node2D
# Fondo neutro de mapa de pruebas: color liso + cuadrícula + regla de distancias.

@export var area: Rect2 = Rect2(-600, -500, 3400, 1300)
@export var base_color: Color = Color(0.17, 0.18, 0.21)
@export var minor_step: float = 32.0
@export var major_step: float = 160.0
@export var ruler_y: float = 520.0


func _draw() -> void:
	draw_rect(area, base_color)
	var minor := Color(1, 1, 1, 0.04)
	var major := Color(1, 1, 1, 0.10)
	var x: float = ceil(area.position.x / minor_step) * minor_step
	while x <= area.end.x:
		draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), major if fmod(x, major_step) == 0.0 else minor)
		x += minor_step
	var y: float = ceil(area.position.y / minor_step) * minor_step
	while y <= area.end.y:
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), major if fmod(y, major_step) == 0.0 else minor)
		y += minor_step
	# Regla: una marca cada 160 px bajo el suelo
	var font := ThemeDB.fallback_font
	x = ceil(area.position.x / major_step) * major_step
	while x <= area.end.x:
		draw_string(font, Vector2(x + 3, ruler_y), str(int(x)), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.35))
		x += major_step
