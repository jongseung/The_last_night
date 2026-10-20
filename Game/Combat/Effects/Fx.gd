class_name Fx
extends RefCounted
## 전투 연출 헬퍼. 총구 화염, 탄흔, 피격 혈흔, 유리 파편 등을 코드로 생성한다.
## 레벨의 "FX" / "Decals" 컨테이너가 있으면 그곳에, 없으면 지정 부모에 붙인다.
## 좌표: '화면 위치(screen)' 는 이미 높이만큼 올린 그림 위치, '바닥 위치(ground)' 는 ViewSpace 바닥 좌표.

static var _light_tex: GradientTexture2D


static func light_texture() -> GradientTexture2D:
	if _light_tex == null:
		_light_tex = GradientTexture2D.new()
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.55))
		_light_tex.gradient = g
		_light_tex.fill = GradientTexture2D.FILL_RADIAL
		_light_tex.fill_from = Vector2(0.5, 0.5)
		_light_tex.fill_to = Vector2(0.5, 0.0)
		_light_tex.width = 256
		_light_tex.height = 256
	return _light_tex


static func _container(from: Node, name: String) -> Node:
	var level: Node = from.get_tree().get_first_node_in_group("level")
	if level and level.has_node(name):
		return level.get_node(name)
	return level if level else from.get_tree().current_scene


static func make_light(parent: Node, pos: Vector2, color: Color, energy: float, scale: float) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = light_texture()
	light.color = color
	light.energy = energy
	light.texture_scale = scale
	light.shadow_enabled = true
	light.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
	light.shadow_item_cull_mask = 1
	light.position = pos
	parent.add_child(light)
	return light


## pos 는 바닥 좌표의 총구. 그림은 GUN_HEIGHT 만큼 올린다.
static func muzzle_flash(from: Node, ground_pos: Vector2, dir: Vector2) -> void:
	var fx := _container(from, "FX")
	var pos := ViewSpace.lift(ground_pos)
	var s := Sprite2D.new()
	s.texture = preload("res://assets/sprites/fx/muzzle_flash.png")
	s.global_position = pos + dir * 6.0
	s.rotation = dir.angle()
	s.offset = Vector2(6, 0)
	s.z_index = 5
	fx.add_child(s)
	var light := make_light(fx, pos, Color(1.0, 0.8, 0.5), 1.8, 1.1)
	light.shadow_enabled = false
	_free_after(from, [s, light], 0.05)


static func impact(from: Node, pos: Vector2, normal: Vector2, color: Color = Color(1.0, 0.85, 0.6)) -> void:
	var fx := _container(from, "FX")
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 8
	p.lifetime = 0.25
	p.explosiveness = 1.0
	p.direction = normal
	p.spread = 50.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 140.0
	p.gravity = Vector2(0, 200)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = color
	p.global_position = pos
	p.z_index = 4
	fx.add_child(p)
	_free_after(from, [p], 0.5)


static func bullet_hole(from: Node, pos: Vector2) -> void:
	var decals := _container(from, "Decals")
	var s := Sprite2D.new()
	s.texture = preload("res://assets/sprites/fx/bullet_hole.png")
	s.global_position = pos
	s.rotation = randf() * TAU
	decals.add_child(s)


## pos: 튀는 피가 시작되는 화면 위치(몸통 높이), ground: 혈흔이 남는 바닥 위치
static func blood(from: Node, pos: Vector2, ground: Vector2, dir: Vector2, big: bool = false) -> void:
	var fx := _container(from, "FX")
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 18 if big else 9
	p.lifetime = 0.35
	p.explosiveness = 1.0
	p.direction = dir
	p.spread = 35.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 160.0
	p.gravity = Vector2.ZERO
	p.damping_min = 200.0
	p.damping_max = 300.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.5
	p.color = Color(0.5, 0.06, 0.08)
	p.global_position = pos
	p.z_index = 4
	fx.add_child(p)
	_free_after(from, [p], 0.6)
	var decals := _container(from, "Decals")
	var s := Sprite2D.new()
	s.texture = preload("res://assets/sprites/fx/blood_splat.png")
	s.global_position = ground + dir * randf_range(8.0, 24.0)
	s.rotation = randf() * TAU
	s.scale = Vector2.ONE * (randf_range(1.2, 2.2) if big else randf_range(0.6, 1.2))
	s.modulate.a = 0.85
	decals.add_child(s)


static func glass_break(from: Node, pos: Vector2, dir: Vector2) -> void:
	var fx := _container(from, "FX")
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 24
	p.lifetime = 0.6
	p.explosiveness = 1.0
	p.direction = dir
	p.spread = 70.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 220.0
	p.gravity = Vector2(0, 160)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = Color(0.6, 0.85, 0.9)
	p.global_position = pos
	p.z_index = 6
	fx.add_child(p)
	_free_after(from, [p], 1.0)
	Sfx.play("glass", -4.0)


static func _free_after(from: Node, nodes: Array, seconds: float) -> void:
	var timer := from.get_tree().create_timer(seconds)
	timer.timeout.connect(func() -> void:
		for n in nodes:
			if is_instance_valid(n):
				n.queue_free())
