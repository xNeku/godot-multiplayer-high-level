extends Resource
class_name ClassData

@export_group("Identidad")
@export var role_name: String = "Clase"
@export var icon: Texture2D

@export_group("Estadísticas Base")
@export var max_health: int = 3
@export var speed_modifier: float = 1.0

@export_group("Armamento")
@export var primary_weapon: WeaponData

@export_group("Habilidad Activa")
# Aquí definimos la lista de habilidades disponibles
@export_enum("NONE", "DASH", "UV_LIGHT", "NIGHT_VISION", "RICOCHET", "MELEE") var ability_type: String = "NONE"
@export var ability_cooldown: float = 3.0

@export_group("Pasivas (Linterna)")
@export var flashlight_scale: Vector2 = Vector2(1, 1) # (1,1) es normal
@export var flashlight_energy: float = 1.0

@export_group("Arrojadizo (Granada/Habilidad)")
@export var throwable_scene: PackedScene # La escena de la claymore/baliza
@export var throwable_cooldown: float = 5.0 # Tiempo entre lanzamientos
@export var throw_force: float = 800.0 # Fuerza del lanzamiento
