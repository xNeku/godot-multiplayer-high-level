extends CanvasLayer
# Panel de ajuste en vivo (F1, o el botón ⚙). Cambia los valores del jugador local y
# del arma que lleva mientras juegas. "Guardar" los deja en user://ajustes.cfg y se
# cargan solos la próxima vez. Solo afecta a TU copia: sirve para afinar el tacto.

const FILE := "user://ajustes.cfg"

# [propiedad, mínimo, máximo, paso]
const PLAYER_PROPS := [
	["walk_speed", 80, 500, 5],
	["run_speed", 150, 900, 10],
	["jump_velocity", -1400, -300, 10],
	["gravity", 800, 4000, 50],
	["fall_gravity_mult", 1.0, 2.5, 0.05],
	["apex_gravity_mult", 0.1, 1.0, 0.05],
	["apex_threshold", 0, 200, 5],
	["max_fall_speed", 150, 900, 10],
	["air_control", 0.1, 1.0, 0.05],
	["over_speed_decel", 100, 3000, 50],
	["jump_h_boost", 0, 150, 5],
	["acceleration", 300, 6000, 50],
	["friction", 300, 6000, 50],
	["coyote_time", 0.0, 0.3, 0.01],
	["jump_buffer_time", 0.0, 0.3, 0.01],
	["jump_cut", 0.0, 1.0, 0.05],
	["double_tap_time", 0.1, 0.6, 0.01],
	["pad_sprint_threshold", 0.5, 1.0, 0.01],
	["crouch_speed", 20, 200, 5],
	["slide_speed", 150, 700, 10],
	["slide_min_speed", 100, 300, 5],
	["slide_friction", 100, 2000, 25],
	["slide_exit_speed", 10, 150, 5],
	["backflip_window", 0.05, 0.5, 0.01],
	["backflip_height", 30, 160, 2],
	["backflip_speed", 0, 400, 10],
	["backflip_time", 0.2, 1.0, 0.02],
	["backflip_air_control", 0.0, 1.0, 0.05],
	["rope_range", 60, 400, 5],
	["rope_release_boost", 1.0, 1.5, 0.05],
	["self_knockback_ref", 0, 1200, 25],
	["rope_climb_speed", 20, 200, 5],
	["rope_swing_accel", 100, 1000, 10],
	["rope_max_speed", 150, 900, 10],
	["aim_rotation_speed_deg", 60, 1000, 10],
	["remote_smoothing", 5, 60, 1],
	["shake_per_shot", 0.0, 8.0, 0.1],
	["shake_on_death", 0.0, 40.0, 1.0],
	["hit_stop_time", 0.0, 0.3, 0.01],
	["step_distance", 15, 80, 1],
]
const WEAPON_PROPS := [
	["fire_rate", 0.03, 2.0, 0.01],
	["bullet_speed", 300, 5000, 50],
	["spread", 0.0, 20.0, 0.1],
	["recoil_per_shot_deg", 0.0, 20.0, 0.1],
	["recoil_max_deg", 0.0, 90.0, 1.0],
	["recoil_pause", 0.0, 1.5, 0.05],
	["recoil_recovery_deg_per_sec", 0.0, 300.0, 5.0],
	["hearing_range", 100, 5000, 50],
]

@onready var panel: PanelContainer = $Panel
@onready var rows: VBoxContainer = $Panel/Margen/Caja/Scroll/Filas
@onready var toggle: Button = $Boton

var _cfg := ConfigFile.new()
var _player: Node
var _weapon: WeaponData
var _defaults := {}
var _weapon_defaults := {}
var _player_applied := false


func _ready() -> void:
	panel.visible = false
	toggle.pressed.connect(_toggle)
	$Panel/Margen/Caja/Botones/Guardar.pressed.connect(_save)
	$Panel/Margen/Caja/Botones/Restablecer.pressed.connect(_reset)
	_cfg.load(FILE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		_toggle()


func _toggle() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		_rebuild()


func _process(_delta: float) -> void:
	var p := get_node_or_null("../PlayerSpawnContainer/" + str(multiplayer.get_unique_id()))
	if p == null:
		return
	if p != _player:
		_player = p
		_player_applied = false
	if not _player_applied:
		_apply_saved_player()
		_player_applied = true
	# Al cambiar de arma se aplican los valores guardados de esa arma
	if _player.current_weapon_data != _weapon:
		_weapon = _player.current_weapon_data
		if _weapon and not _weapon_defaults.has(_weapon.resource_path):
			var d := {}
			for def in WEAPON_PROPS:
				d[def[0]] = _weapon.get(def[0])
			_weapon_defaults[_weapon.resource_path] = d
		_apply_saved_weapon()
		if panel.visible:
			_rebuild()


func _apply_saved_player() -> void:
	for def in PLAYER_PROPS:
		_defaults[def[0]] = _player.get(def[0])
		if _cfg.has_section_key("jugador", def[0]):
			_player.set(def[0], _cfg.get_value("jugador", def[0]))


func _apply_saved_weapon() -> void:
	if _weapon == null:
		return
	var sec := "arma:" + _weapon.resource_path
	for def in WEAPON_PROPS:
		if _cfg.has_section_key(sec, def[0]):
			_weapon.set(def[0], _cfg.get_value(sec, def[0]))


func _rebuild() -> void:
	for c in rows.get_children():
		c.queue_free()
	if _player == null:
		return
	_header("JUGADOR")
	for def in PLAYER_PROPS:
		_row(_player, def)
	if _weapon:
		_header("ARMA: " + _weapon.role_name)
		for def in WEAPON_PROPS:
			_row(_weapon, def)


func _header(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	rows.add_child(l)


func _row(target: Object, def: Array) -> void:
	var box := HBoxContainer.new()
	var name_l := Label.new()
	name_l.text = def[0]
	name_l.custom_minimum_size.x = 130
	name_l.add_theme_font_size_override("font_size", 10)
	var s := HSlider.new()
	s.min_value = def[1]
	s.max_value = def[2]
	s.step = def[3]
	s.value = target.get(def[0])
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(110, 18)
	var val := Label.new()
	val.text = str(snapped(s.value, def[3]))
	val.custom_minimum_size.x = 44
	val.add_theme_font_size_override("font_size", 10)
	s.value_changed.connect(func(v: float):
		target.set(def[0], v)
		val.text = str(snapped(v, def[3])))
	box.add_child(name_l)
	box.add_child(s)
	box.add_child(val)
	rows.add_child(box)


func _save() -> void:
	_cfg.clear()
	if _player:
		for def in PLAYER_PROPS:
			_cfg.set_value("jugador", def[0], _player.get(def[0]))
	for path in _weapon_defaults:
		var w: WeaponData = load(path)
		for def in WEAPON_PROPS:
			if w.get(def[0]) != _weapon_defaults[path][def[0]]:
				_cfg.set_value("arma:" + path, def[0], w.get(def[0]))
	_cfg.save(FILE)
	print("[Ajustes] guardados en ", ProjectSettings.globalize_path(FILE))


func _reset() -> void:
	if _player:
		for k in _defaults:
			_player.set(k, _defaults[k])
	for path in _weapon_defaults:
		var w: WeaponData = load(path)
		for k in _weapon_defaults[path]:
			w.set(k, _weapon_defaults[path][k])
	_cfg.clear()
	DirAccess.remove_absolute(FILE)
	_rebuild()
