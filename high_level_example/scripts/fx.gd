extends CanvasLayer
# Autoload "Fx". Efectos visuales de disparos, impactos y explosiones.
#
# Lo que BRILLA (fogonazo, chispas, fuego, estela del francotirador) se dibuja en
# esta capa, que sigue a la cámara pero NO la oscurece el CanvasModulate del mapa.
# Lo que NO brilla (humo, polvo, casquillos, agujeros de bala, quemaduras) va al
# mundo, así solo se ve donde hay luz.
#
# Todo es local y cosmético. El servidor avisa a todos con impact.rpc(...).

const SOFT: Texture2D = preload("res://high_level_example/assets/fx/punto_suave.png")
const LIGHT_TEX: Texture2D = preload("res://high_level_example/assets/lights/2d_lights_and_shadows_neutral_point_light.webp")
const MAX_DECALS: int = 80

enum Surface { WALL, FLESH, TOY }

var _decals: Array[Node2D] = []
var _add_mat := CanvasItemMaterial.new()


func _ready() -> void:
	layer = 0
	follow_viewport_enabled = true
	_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


func _world() -> Node:
	return get_tree().current_scene


# --- DISPARO ---

# Fogonazo en la boca del cañón. size 0 = arma con silenciador (solo un hilo de humo).
func muzzle(pos: Vector2, angle: float, size: float) -> void:
	if size > 0.0:
		var flash := Polygon2D.new()
		flash.material = _add_mat
		flash.color = Color(1.0, 0.85, 0.5, 0.95)
		var pts := PackedVector2Array()
		var spikes: int = 5
		for i in spikes * 2:
			var a: float = -PI * 0.5 + PI * float(i) / float(spikes * 2 - 1)
			var r: float = (randf_range(5.0, 9.0) if i % 2 == 0 else 2.0) * size
			# más largo hacia delante
			var stretch: float = 1.0 + maxf(0.0, cos(a)) * 1.6
			pts.append(Vector2(cos(a) * r * stretch, sin(a) * r))
		flash.polygon = pts
		flash.position = pos
		flash.rotation = angle
		add_child(flash)
		var core := _soft_sprite(pos, Color(1.0, 0.95, 0.8, 0.9), 0.45 * size)
		get_tree().create_timer(0.05).timeout.connect(func():
			flash.queue_free()
			core.queue_free())
	_smoke_puff(pos, angle, 3 if size <= 0.0 else 5, 0.6 + size * 0.2)


func casing(pos: Vector2, facing: int, color: Color = Color(0.85, 0.65, 0.3)) -> void:
	var c := Node2D.new()
	c.set_script(preload("res://high_level_example/scripts/casing.gd"))
	c.position = pos
	c.velocity = Vector2(-facing * randf_range(40.0, 90.0), randf_range(-160.0, -110.0))
	c.color = color
	_world().add_child(c)


# --- IMPACTOS (los manda el servidor) ---

@rpc("authority", "call_local", "unreliable")
func impact(pos: Vector2, normal: Vector2, surface: int, size: float, trail_from: Vector2) -> void:
	if trail_from != Vector2.ZERO:
		_trail(trail_from, pos)
	match surface:
		Surface.FLESH:
			_blood(pos, normal, size)
		Surface.TOY:
			_sparks(pos, normal, 4, Color(1.0, 0.5, 0.9), 0.6)
		_:
			_sparks(pos, normal, int(4 + size * 4), Color(1.0, 0.75, 0.35), size)
			_flash_light(pos, 0.5 * size, 0.06)
			_dust(pos, normal, size)
			_decal_hole(pos, size)


# Estela del francotirador: raya brillante que se apaga y deja humo
func _trail(a: Vector2, b: Vector2) -> void:
	var line := Line2D.new()
	line.material = _add_mat
	line.points = PackedVector2Array([a, b])
	line.width = 1.5
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.8, 0.4, 0.0))
	g.set_color(1, Color(1.0, 0.9, 0.6, 0.9))
	line.gradient = g
	add_child(line)
	var tw := line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(line.queue_free)
	# Humo (en el mundo: solo se ve si hay luz)
	var smoke := Line2D.new()
	smoke.points = PackedVector2Array([a, b])
	smoke.width = 3.0
	smoke.default_color = Color(0.8, 0.8, 0.8, 0.25)
	_world().add_child(smoke)
	var tw2 := smoke.create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(smoke, "modulate:a", 0.0, 1.6)
	tw2.tween_property(smoke, "width", 7.0, 1.6)
	tw2.chain().tween_callback(smoke.queue_free)


func _sparks(pos: Vector2, normal: Vector2, amount: int, color: Color, size: float) -> void:
	var p := CPUParticles2D.new()
	p.material = _add_mat
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = maxi(amount, 1)
	p.lifetime = 0.35
	p.direction = normal
	p.spread = 55.0
	p.initial_velocity_min = 80.0 * size
	p.initial_velocity_max = 220.0 * size
	p.gravity = Vector2(0, 500)
	p.damping_min = 80.0
	p.damping_max = 160.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.5
	p.color = color
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 0.4, 0.1, 0))
	p.color_ramp = ramp
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func _dust(pos: Vector2, normal: Vector2, size: float) -> void:
	var p := CPUParticles2D.new()
	p.texture = SOFT
	p.position = pos
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 6
	p.lifetime = 0.7
	p.direction = normal
	p.spread = 35.0
	p.initial_velocity_min = 15.0
	p.initial_velocity_max = 45.0 * size
	p.damping_min = 40.0
	p.damping_max = 60.0
	p.scale_amount_min = 0.15 * size
	p.scale_amount_max = 0.3 * size
	p.color = Color(0.75, 0.72, 0.68, 0.5)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	_world().add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func _blood(pos: Vector2, normal: Vector2, size: float) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = int(8 + size * 6)
	p.lifetime = 0.6
	p.direction = normal
	p.spread = 70.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 160.0
	p.gravity = Vector2(0, 600)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = Color(0.55, 0.05, 0.05)
	_world().add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func _decal_hole(pos: Vector2, size: float) -> void:
	var d := Polygon2D.new()
	var r: float = clampf(0.8 + size * 0.5, 1.0, 2.2)
	var pts := PackedVector2Array()
	for i in 6:
		var a: float = TAU * i / 6.0
		pts.append(Vector2(cos(a), sin(a)) * r * randf_range(0.7, 1.2))
	d.polygon = pts
	d.color = Color(0.05, 0.04, 0.04, 0.85)
	d.position = pos
	d.z_index = 1
	_world().add_child(d)
	_decals.append(d)
	_trim_decals()
	var tw := d.create_tween()
	tw.tween_interval(10.0)
	tw.tween_property(d, "modulate:a", 0.0, 4.0)
	tw.tween_callback(d.queue_free)


func _trim_decals() -> void:
	_decals = _decals.filter(func(n): return is_instance_valid(n))
	while _decals.size() > MAX_DECALS:
		var old: Node2D = _decals.pop_front()
		old.queue_free()


# Luz real breve (ilumina las paredes de alrededor)
func _flash_light(pos: Vector2, energy: float, time: float, color: Color = Color(1.0, 0.8, 0.5), scale_: float = 0.25) -> void:
	var l := PointLight2D.new()
	l.texture = LIGHT_TEX
	l.texture_scale = scale_
	l.energy = energy
	l.color = color
	l.position = pos
	l.shadow_enabled = true
	_world().add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "energy", 0.0, time)
	tw.tween_callback(l.queue_free)


func _smoke_puff(pos: Vector2, angle: float, amount: int, size: float) -> void:
	var p := CPUParticles2D.new()
	p.texture = SOFT
	p.position = pos
	p.one_shot = true
	p.explosiveness = 0.8
	p.amount = amount
	p.lifetime = 0.9
	p.direction = Vector2.RIGHT.rotated(angle)
	p.spread = 25.0
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 40.0
	p.gravity = Vector2(0, -25)
	p.damping_min = 30.0
	p.damping_max = 50.0
	p.scale_amount_min = 0.12 * size
	p.scale_amount_max = 0.3 * size
	p.color = Color(0.85, 0.85, 0.85, 0.35)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	_world().add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func _soft_sprite(pos: Vector2, color: Color, scale_: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = SOFT
	s.material = _add_mat
	s.modulate = color
	s.scale = Vector2.ONE * scale_
	s.position = pos
	add_child(s)
	return s


# --- EXPLOSIONES ---

# kind: 0 explosión normal, 1 PEM (eléctrica, sin fuego)
func explosion(pos: Vector2, radius: float, kind: int = 0) -> void:
	if kind == 1:
		_emp(pos, radius)
		return
	# 1. Destello
	var flash := _soft_sprite(pos, Color(1.0, 0.9, 0.7, 0.9), radius / 22.0)
	var tw := flash.create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.12)
	tw.tween_callback(flash.queue_free)
	# 2. Bola de fuego
	var fire := CPUParticles2D.new()
	fire.texture = SOFT
	fire.material = _add_mat
	fire.position = pos
	fire.one_shot = true
	fire.explosiveness = 0.95
	fire.amount = 36
	fire.lifetime = 0.65
	fire.lifetime_randomness = 0.4
	fire.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = radius * 0.2
	fire.direction = Vector2.UP
	fire.spread = 180.0
	fire.initial_velocity_min = radius * 0.6
	fire.initial_velocity_max = radius * 2.2
	fire.damping_min = radius * 2.0
	fire.damping_max = radius * 3.5
	fire.gravity = Vector2(0, -60)
	fire.scale_amount_min = radius / 70.0
	fire.scale_amount_max = radius / 35.0
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.6))
	curve.add_point(Vector2(0.25, 1.0))
	curve.add_point(Vector2(1.0, 0.3))
	fire.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.55, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 0.85, 1), Color(1, 0.72, 0.25, 1), Color(0.85, 0.28, 0.06, 0.8), Color(0.25, 0.08, 0.02, 0)])
	fire.color_ramp = ramp
	add_child(fire)
	fire.emitting = true
	fire.finished.connect(fire.queue_free)
	# 3. Chispas y metralla
	var deb := CPUParticles2D.new()
	deb.material = _add_mat
	deb.position = pos
	deb.one_shot = true
	deb.explosiveness = 1.0
	deb.amount = 28
	deb.lifetime = 0.9
	deb.lifetime_randomness = 0.5
	deb.direction = Vector2.UP
	deb.spread = 180.0
	deb.initial_velocity_min = radius * 2.0
	deb.initial_velocity_max = radius * 6.0
	deb.gravity = Vector2(0, 700)
	deb.damping_min = 20.0
	deb.damping_max = 60.0
	deb.scale_amount_min = 1.0
	deb.scale_amount_max = 2.0
	var dr := Gradient.new()
	dr.set_color(0, Color(1, 0.95, 0.7, 1))
	dr.set_color(1, Color(1, 0.35, 0.05, 0))
	deb.color_ramp = dr
	add_child(deb)
	deb.emitting = true
	deb.finished.connect(deb.queue_free)
	# 4. Onda expansiva
	_ring(pos, radius * 1.7, Color(1.0, 0.85, 0.6, 0.55), 0.2, 3.0)
	# 5. Humo (mundo: se ve mientras lo ilumina el fuego o alguna luz)
	var smoke := CPUParticles2D.new()
	smoke.texture = SOFT
	smoke.position = pos
	smoke.one_shot = true
	smoke.explosiveness = 0.7
	smoke.amount = 22
	smoke.lifetime = 2.4
	smoke.lifetime_randomness = 0.3
	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = radius * 0.3
	smoke.direction = Vector2.UP
	smoke.spread = 180.0
	smoke.initial_velocity_min = radius * 0.3
	smoke.initial_velocity_max = radius * 1.2
	smoke.damping_min = radius * 0.8
	smoke.damping_max = radius * 1.4
	smoke.gravity = Vector2(0, -18)
	smoke.scale_amount_min = radius / 40.0
	smoke.scale_amount_max = radius / 22.0
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.5))
	sc.add_point(Vector2(1.0, 1.0))
	smoke.scale_amount_curve = sc
	var sr := Gradient.new()
	sr.set_color(0, Color(0.35, 0.33, 0.32, 0.7))
	sr.set_color(1, Color(0.2, 0.2, 0.2, 0))
	smoke.color_ramp = sr
	_world().add_child(smoke)
	smoke.emitting = true
	smoke.finished.connect(smoke.queue_free)
	# 6. Quemadura en el suelo
	var scorch := Sprite2D.new()
	scorch.texture = SOFT
	scorch.modulate = Color(0.03, 0.02, 0.02, 0.75)
	scorch.scale = Vector2(radius / 12.0, radius / 22.0)
	scorch.position = pos
	scorch.z_index = 1
	_world().add_child(scorch)
	_decals.append(scorch)
	_trim_decals()
	var st := scorch.create_tween()
	st.tween_interval(18.0)
	st.tween_property(scorch, "modulate:a", 0.0, 5.0)
	st.tween_callback(scorch.queue_free)


func _emp(pos: Vector2, radius: float) -> void:
	_ring(pos, radius, Color(0.45, 0.8, 1.0, 0.8), 0.3, 2.0)
	_ring(pos, radius * 0.6, Color(0.7, 0.9, 1.0, 0.6), 0.2, 1.5)
	var flash := _soft_sprite(pos, Color(0.5, 0.8, 1.0, 0.8), radius / 26.0)
	var tw := flash.create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.25)
	tw.tween_callback(flash.queue_free)
	# Rayos eléctricos
	for i in 6:
		var bolt := Line2D.new()
		bolt.material = _add_mat
		bolt.width = 1.0
		bolt.default_color = Color(0.7, 0.9, 1.0, 0.9)
		var a: float = randf() * TAU
		var pts := PackedVector2Array([pos])
		var p := pos
		var steps: int = 5
		for k in steps:
			p += Vector2.RIGHT.rotated(a + randf_range(-0.6, 0.6)) * radius / steps
			pts.append(p)
		bolt.points = pts
		add_child(bolt)
		var bt := bolt.create_tween()
		bt.tween_interval(randf_range(0.03, 0.12))
		bt.tween_property(bolt, "modulate:a", 0.0, 0.12)
		bt.tween_callback(bolt.queue_free)
	_sparks(pos, Vector2.UP, 16, Color(0.6, 0.85, 1.0), 1.5)


func _ring(pos: Vector2, radius: float, color: Color, time: float, width: float) -> void:
	var ring := Line2D.new()
	ring.material = _add_mat
	ring.width = width
	ring.default_color = color
	ring.position = pos
	add_child(ring)
	var set_r := func(r: float):
		var pts := PackedVector2Array()
		for i in 33:
			var a: float = TAU * i / 32.0
			pts.append(Vector2(cos(a), sin(a)) * r)
		ring.points = pts
	set_r.call(radius * 0.2)
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_method(set_r, radius * 0.2, radius, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(ring, "modulate:a", 0.0, time)
	tw.tween_property(ring, "width", width * 0.3, time)
	tw.chain().tween_callback(ring.queue_free)
