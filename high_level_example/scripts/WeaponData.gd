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
@export var sprite_scale: float = 1.0 # tamaño relativo del sprite en mano y en el suelo

@export_group("Estadísticas Base")
@export var bullet_scene: PackedScene # La escena de la bala
@export var fire_mode: FireMode = FireMode.SEMI
@export var fire_rate: float = 0.5 # segundos entre disparos
@export var max_ammo: int = 10 # sin recarga: cuando se acaba, el arma queda vacía

@export_group("Balística")
@export var bullet_speed: float = 2000.0
@export var spread: float = 0.0
@export var bullet_count: int = 1
# Mayor que 0 = el proyectil cae con esta gravedad y se muestra el arco al apuntar (Bazooka).
# La escena de bala tiene que ser un proyectil con trayectoria (ThrownProjectile).
@export var projectile_gravity: float = 0.0

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
@export var shot_sound: AudioStream
# A cuántos píxeles se oye el disparo (el volumen baja con la distancia)
@export var hearing_range: float = 1400.0

@export_group("Efectos")
# Tamaño del fogonazo (0 = sin fogonazo; con silenciador se fuerza a 0)
@export var muzzle_flash: float = 1.0
# Cada cuántas balas sale una trazadora (brilla en vuelo). 0 = nunca, 1 = todas
@export var tracer_every: int = 0
# Tamaño del impacto (chispas, polvo, agujero)
@export var impact_size: float = 1.0
# Estela brillante desde el cañón hasta el impacto (francotirador)
@export var impact_trail: bool = false
# Expulsa casquillo al disparar
@export var eject_casing: bool = true
@export var casing_color: Color = Color(0.85, 0.65, 0.3)
