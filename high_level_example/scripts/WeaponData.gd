extends Resource
class_name WeaponData
# Un arma = un recurso .tres. Se coloca en un ArmaSpawner y se recoge en partida.
# El archivo tiene que estar guardado en disco (la red se manda la ruta del .tres).

enum FireMode {
	AUTO,  # mantener el botón dispara en ráfaga
	SEMI,  # un disparo por pulsación
	BOLT,  # cerrojo: como SEMI, pensado para fire_rate largo
}

@export_group("Identidad")
@export var role_name: String = "Arma" # Nombre del arma (ej: "Tomahawk")
@export var texture: Texture2D # Sprite del arma

@export_group("Estadísticas Base")
@export var bullet_scene: PackedScene # La escena de la bala
@export var fire_mode: FireMode = FireMode.SEMI
@export var fire_rate: float = 0.5 # segundos entre disparos
@export var max_ammo: int = 10 # sin recarga: cuando se acaba, el arma queda vacía
@export var damage: int = 1 # (Opcional si usas one-hit-kill)

@export_group("Balística")
@export var bullet_speed: float = 2000.0
@export var spread: float = 0.0
@export var bullet_count: int = 1
# Rebotes base del arma
@export var bounces: int = 0

@export_group("Retroceso")
# Cada disparo sube el cañón estos grados, hasta recoil_max_deg.
@export var recoil_per_shot_deg: float = 0.0
@export var recoil_max_deg: float = 30.0
# Segundos sin disparar antes de que el cañón empiece a bajar
@export var recoil_pause: float = 0.4
# Velocidad a la que baja una vez pasada la pausa
@export var recoil_recovery_deg_per_sec: float = 60.0

@export_group("Luz y sonido")
# Las armas sin silenciador sueltan un fogonazo de luz que delata tu posición
@export var silenced: bool = false

@export_group("Especiales")
@export var return_ammo_on_kill: bool = false
