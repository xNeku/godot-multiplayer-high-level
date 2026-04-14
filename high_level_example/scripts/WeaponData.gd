extends Resource
class_name WeaponData

@export_group("Identidad")
@export var role_name: String = "Arma" # Nombre del arma (ej: "Tomahawk")
@export var texture: Texture2D # Sprite del arma

@export_group("Estadísticas Base")
@export var bullet_scene: PackedScene # La escena de la bala
@export var fire_rate: float = 0.5
@export var max_ammo: int = 10
@export var damage: int = 1 # (Opcional si usas one-hit-kill)

@export_group("Balística")
@export var bullet_speed: float = 2000.0
@export var spread: float = 0.0
@export var bullet_count: int = 1
# --- NUEVO: Rebotes base del arma ---
@export var bounces: int = 0

@export_group("Especiales")
# ESTA ES LA NUEVA VARIABLE PARA EL NINJA
@export var return_ammo_on_kill: bool = false
