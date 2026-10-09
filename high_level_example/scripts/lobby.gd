extends Node2D
# Sala de espera. Los jugadores se mueven con su bicho, disparan con una pistola de
# juguete (empuja, no mata), eligen color y pulsan "Listo". Cuando están todos listos,
# cuenta atrás y empieza la partida. El host elige el mapa de la primera ronda.

const MapLoader := preload("res://high_level_example/scripts/map_loader.gd")
const UiJuice := preload("res://high_level_example/scripts/ui_juice.gd")
const LOBBY_MAP: String = "res://high_level_example/lobby/lobby.json"
const MENU_SCENE: String = "res://high_level_example/scenes/Menu.tscn"
const COUNTDOWN_SECONDS: int = 3

# Mapas de escena antiguos (el selector se rellena por código)
@export var maps: Array[PackedScene]

@onready var map_container: Node2D = $MapContainer
@onready var players_box: VBoxContainer = %JugadoresLista
@onready var colors_box: HBoxContainer = %Colores
@onready var ready_button: Button = %ListoButton
@onready var countdown_label: Label = %CuentaAtras
@onready var host_panel: PanelContainer = %PanelHost
@onready var map_selector: OptionButton = %MapSelector
@onready var import_button: Button = %ImportButton
@onready var leave_button: Button = %SalirButton
@onready var hint_label: Label = %Pista
@onready var veil: ColorRect = %Velo

# Solo servidor: quién está listo
var _ready_state: Dictionary = {}
var _countdown: float = -1.0
var _last_shown: int = -1
# Copia en todos los peers (la manda el servidor)
var _ready_view: Dictionary = {}
var _entries: Array = []
var _import_dialog: FileDialog
var _refresh_left: float = 0.0
# Menú con mando/teclado (Start / Esc): bloquea al personaje y da foco a los botones
var _menu_open: bool = false


func _ready() -> void:
	GameManager.in_lobby = true
	RoundManager.enter_lobby()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var map := MapLoader.load_file(LOBBY_MAP)
	if map:
		map.with_darkness = false
		map_container.add_child(map)

	# Tema pequeño para que la interfaz case con la resolución del juego (640x360)
	var ui_theme := Theme.new()
	ui_theme.set_default_font_size(11)
	$UI/Raiz.theme = ui_theme

	_build_color_buttons()
	# Color único: lo pide al servidor (si el preferido está cogido, le da otro)
	GameManager.request_color.rpc_id(1, Settings.color_index)
	%BotMas.pressed.connect(_add_bot)
	%BotMenos.pressed.connect(_remove_bot)
	ready_button.pressed.connect(_toggle_ready)
	leave_button.pressed.connect(_leave)
	import_button.pressed.connect(_on_import_pressed)
	UiJuice.apply($UI)

	host_panel.visible = multiplayer.is_server()
	if multiplayer.is_server():
		_rebuild_map_list()
		multiplayer.peer_disconnected.connect(_on_peer_gone)
	countdown_label.text = ""
	_set_menu(false)


func _process(delta: float) -> void:
	if not is_inside_tree() or not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.is_server():
		_server_tick(delta)
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = 0.25
		_refresh_players()
		_refresh_color_buttons()
		_update_hint()
	if Input.is_action_just_pressed("menu"):
		_set_menu(not _menu_open)
	if _menu_open:
		return
	if Input.is_action_just_pressed("interact"):
		_toggle_ready()
	if Input.is_action_just_pressed("throw"):
		_set_color((Settings.color_index + 1) % Settings.PLAYER_COLORS.size())


func _input(event: InputEvent) -> void:
	if _menu_open:
		if UiJuice.pad_accept(get_viewport(), event):
			return
		if UiJuice.is_cancel(event) and not event.is_action_pressed("menu"):
			get_viewport().set_input_as_handled()
			_set_menu(false)


func _exit_tree() -> void:
	GameManager.input_blocked = false


func _menu_controls() -> Array:
	var out: Array = [ready_button]
	out.append_array(colors_box.get_children())
	if host_panel.visible:
		out.append(map_selector)
		out.append(%BotMas)
		out.append(%BotMenos)
	out.append(leave_button)
	return out


func _set_menu(on: bool) -> void:
	_menu_open = on
	GameManager.input_blocked = on
	veil.visible = on
	for c in _menu_controls():
		(c as Control).focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE
	if on:
		ready_button.grab_focus()
	else:
		get_viewport().gui_release_focus()
	_update_hint()


func _update_hint() -> void:
	if _menu_open:
		hint_label.text = "%s: volver" % ("B" if Settings.using_pad else "Esc")
	else:
		hint_label.text = "%s: Listo   ·   %s: color   ·   %s: menú" % [Settings.key_for("interact"), Settings.key_for("throw"), "Start" if Settings.using_pad else "Esc"]


# --- LISTO Y CUENTA ATRÁS ---

func _toggle_ready() -> void:
	var mine: bool = _ready_view.get(multiplayer.get_unique_id(), false)
	_request_ready.rpc_id(1, not mine)


@rpc("any_peer", "call_local", "reliable")
func _request_ready(value: bool) -> void:
	if not multiplayer.is_server():
		return
	var id: int = multiplayer.get_remote_sender_id()
	if id == 0:
		id = 1
	_ready_state[id] = value
	if not value:
		_cancel_countdown()
	_sync_ready.rpc(_ready_state)


@rpc("authority", "call_local", "reliable")
func _sync_ready(state: Dictionary) -> void:
	_ready_view = state
	var mine: bool = state.get(multiplayer.get_unique_id(), false)
	ready_button.text = "Listo ✓ (cancelar)" if mine else "Listo"
	_refresh_players()


func _on_peer_gone(id: int) -> void:
	_ready_state.erase(id)
	_sync_ready.rpc(_ready_state)


func _server_tick(delta: float) -> void:
	var ids: Array = [1]
	ids.append_array(multiplayer.get_peers())
	var all_ready := true
	for id in ids:
		if not _ready_state.get(id, false):
			all_ready = false
	# Todos listos y todos con su jugador ya spawneado
	var players: int = $PlayerSpawnContainer.get_children().filter(func(n): return "color_index" in n).size()
	var spawned: bool = players >= ids.size() + GameManager.bots.size()
	if all_ready and spawned and _countdown < 0.0:
		_countdown = float(COUNTDOWN_SECONDS)
	elif not all_ready and _countdown >= 0.0:
		_cancel_countdown()
	if _countdown >= 0.0:
		_countdown -= delta
		var shown: int = int(ceil(_countdown))
		if shown != _last_shown:
			_last_shown = shown
			_show_countdown.rpc(maxi(shown, 0))
		if _countdown <= 0.0:
			_countdown = -1.0
			_launch()


func _cancel_countdown() -> void:
	if _countdown >= 0.0:
		_countdown = -1.0
		_last_shown = -1
		_show_countdown.rpc(-1)


@rpc("authority", "call_local", "reliable")
func _show_countdown(n: int) -> void:
	countdown_label.text = "" if n < 0 else str(n)
	if n >= 0:
		countdown_label.pivot_offset = countdown_label.size * 0.5
		countdown_label.scale = Vector2(1.6, 1.6)
		create_tween().tween_property(countdown_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# El servidor lanza la partida con el mapa elegido
func _launch() -> void:
	var i := map_selector.selected
	if i >= 0 and i < _entries.size() and _entries[i].has("scene"):
		RoundManager.start_match(_entries[i]["scene"].resource_path, "")
		return
	var text := ""
	if i >= 0 and i < _entries.size() and _entries[i].has("json"):
		text = RoundManager.pick_first_map(_entries[i]["json"])
	else:
		text = RoundManager.pick_first_map("") # aleatorio
	if text == "" or MapLoader.parse(text).is_empty():
		push_warning("No hay un mapa válido para empezar")
		_ready_state.clear()
		_sync_ready.rpc(_ready_state)
		_show_countdown.rpc(-1)
		return
	RoundManager.start_match("", text)


# --- JUGADORES Y COLORES ---

func _build_color_buttons() -> void:
	for i in Settings.PLAYER_COLORS.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(22, 22)
		b.focus_mode = Control.FOCUS_NONE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Settings.PLAYER_COLORS[i]
		sb.set_corner_radius_all(4)
		sb.set_border_width_all(2)
		sb.border_color = Color(0, 0, 0, 0.6)
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, sb)
		var sf: StyleBoxFlat = sb.duplicate()
		sf.border_color = Color(1, 1, 1, 0.95)
		b.add_theme_stylebox_override("focus", sf)
		b.pressed.connect(_set_color.bind(i))
		colors_box.add_child(b)
		UiJuice.attach(b)


func _set_color(i: int) -> void:
	if GameManager._color_taken(i, multiplayer.get_unique_id()):
		return
	Settings.color_index = i
	Settings.save()
	GameManager.request_color.rpc_id(1, i)


# Colores cogidos por otros: botón apagado
func _refresh_color_buttons() -> void:
	var me: int = multiplayer.get_unique_id()
	var buttons := colors_box.get_children()
	for i in buttons.size():
		var taken: bool = GameManager._color_taken(i, me)
		var b := buttons[i] as Button
		b.disabled = taken
		b.modulate.a = 0.25 if taken else 1.0
		b.text = "×" if taken else ""


# --- BOTS (solo host) ---

func _add_bot() -> void:
	var id: int = GameManager.add_bot()
	if id > 0:
		$MultiplayerSpawner.spawn_player(id)


func _remove_bot() -> void:
	var id: int = GameManager.remove_bot()
	if id > 0:
		$MultiplayerSpawner.remove_player(id)


func _refresh_players() -> void:
	for c in players_box.get_children():
		c.queue_free()
	var nodes: Array = $PlayerSpawnContainer.get_children().filter(func(n): return "color_index" in n)
	nodes.sort_custom(func(a, b): return a.name.to_int() < b.name.to_int())
	for p in nodes:
		var id: int = p.name.to_int()
		var row := HBoxContainer.new()
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(10, 10)
		sw.color = Settings.PLAYER_COLORS[clampi(p.color_index, 0, Settings.PLAYER_COLORS.size() - 1)]
		row.add_child(sw)
		var l := Label.new()
		var ok: bool = _ready_view.get(id, false)
		if GameManager.is_bot_id(id):
			ok = true
		l.text = " %s   %s" % [GameManager.display_name(id), "LISTO" if ok else "..."]
		l.modulate = Color(0.6, 1.0, 0.6) if ok else Color(1, 1, 1, 0.75)
		row.add_child(l)
		players_box.add_child(row)


# --- MAPAS (solo host) ---

func _rebuild_map_list(select_path: String = "") -> void:
	map_selector.clear()
	_entries.clear()
	map_selector.add_item("Aleatorio (todos los mapas)")
	_entries.append({"random": true})
	for m in MapLoader.list_maps():
		map_selector.add_item(("" if m["official"] else "(custom) ") + m["name"])
		_entries.append({"json": m["path"]})
		if m["path"] == select_path:
			map_selector.select(_entries.size() - 1)
	for scene in maps:
		map_selector.add_item("(antiguo) " + scene.resource_path.get_file().get_basename())
		_entries.append({"scene": scene})


func _on_import_pressed() -> void:
	if _import_dialog == null:
		_import_dialog = FileDialog.new()
		_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_import_dialog.use_native_dialog = true
		_import_dialog.filters = PackedStringArray(["*.json ; Mapa de FlashMapMaker"])
		_import_dialog.file_selected.connect(_on_import_file)
		add_child(_import_dialog)
	_import_dialog.popup_centered_ratio(0.6)


func _on_import_file(path: String) -> void:
	var text := MapLoader.read_text(path)
	var saved := MapLoader.save_custom(text, path.get_file().get_basename()) if text != "" else ""
	if saved == "":
		push_warning("No se pudo importar " + path + " (JSON no válido o demasiado grande)")
		import_button.text = "JSON no válido"
		return
	import_button.text = "Importar JSON..."
	_rebuild_map_list(saved)


# --- SALIR ---

func _leave() -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	GameManager.in_lobby = false
	GameManager.colors.clear()
	GameManager.bots.clear()
	get_tree().change_scene_to_file(MENU_SCENE)
