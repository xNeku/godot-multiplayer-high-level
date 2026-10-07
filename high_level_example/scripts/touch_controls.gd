extends CanvasLayer
# Botones en pantalla para jugar con el dedo (pruebas en la tablet).
# Cada TouchScreenButton lanza una acción del Input Map. Se ven solo en
# dispositivos táctiles, salvo que actives "show_always".

@export var show_always: bool = false


func _ready() -> void:
	visible = show_always or DisplayServer.is_touchscreen_available()
