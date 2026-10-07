extends Resource
class_name ItemData
# Un objeto = un recurso .tres. Se coloca en un ObjetoSpawner y se lleva en el hueco de objeto.
# El archivo tiene que estar guardado en disco (la red se manda la ruta del .tres).

@export_group("Identidad")
@export var item_name: String = "Objeto"
@export var texture: Texture2D
@export var sprite_scale: float = 1.0

@export_group("Lanzamiento")
# Escena que aparece al lanzarlo. Si tiene un método launch(velocity, shooter_id, gravity)
# se llama; si es un RigidBody2D se le da la velocidad directamente.
@export var scene: PackedScene
# Velocidad mínima (toque rápido) y máxima (carga completa), en px/s
@export var min_speed: float = 300.0
@export var max_speed: float = 800.0
# Segundos manteniendo el botón hasta la carga completa
@export var charge_time: float = 0.8
# Grados extra hacia arriba respecto a donde apuntas (lanzas en arco)
@export var lob_deg: float = 12.0
# Gravedad usada en el arco de previsualización y en los proyectiles de trayectoria.
# (Los RigidBody2D usan la gravedad del proyecto: 980.)
@export var gravity: float = 1400.0
