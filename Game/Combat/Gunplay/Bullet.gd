class_name Bullet
extends Node2D
## 레이캐스트 기반 고속 탄환. 매 물리 프레임 이전 위치→다음 위치 구간을 검사한다.
##
## 낮은 엄폐물(LOW_COVER)은 탄환을 물리적으로 막지 않는다. 대신 피격 대상이 낮은
## 자세로 엄폐물 뒤에 있을 때(Actor.is_covered_from) 그 엄폐물에 탄흔이 남는다.
## 덕분에 "엄폐물 뒤에서 몸을 낮추면 안전, 일어서면 노출" 이라는 규칙이 성립한다.

var velocity: Vector2 = Vector2.ZERO
var damage: float = 30.0
var team: StringName = &"enemy"
var source: Node = null
var max_distance: float = 500.0
var origin: Vector2

var _travelled: float = 0.0
var _sprite: Sprite2D


static func spawn(parent: Node, pos: Vector2, dir: Vector2, data: WeaponData, team_: StringName, source_: Node) -> Bullet:
	var b := Bullet.new()
	b.global_position = pos
	b.origin = pos
	b.velocity = dir.normalized() * data.bullet_speed
	b.damage = data.damage
	b.team = team_
	b.source = source_
	b.max_distance = data.bullet_range
	b.rotation = dir.angle()
	parent.add_child(b)
	return b


func _ready() -> void:
	z_index = 5
	_sprite = Sprite2D.new()
	_sprite.texture = preload("res://assets/sprites/bullet.png")
	_sprite.offset = Vector2(-3, 0)
	add_child(_sprite)
	# 발사 즉시 첫 구간을 검사해 총구 바로 앞의 적도 놓치지 않는다
	_step(get_physics_process_delta_time())


func _physics_process(delta: float) -> void:
	_step(delta)


func _step(delta: float) -> void:
	if not is_inside_tree():
		return
	var from := global_position
	var to := from + velocity * delta
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, to, Layers.WORLD | Layers.hurtbox_against_team(team))
	query.collide_with_areas = true
	query.collide_with_bodies = true
	if source:
		query.exclude = [source.get_rid()] if source is CollisionObject2D else []
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		_travelled += velocity.length() * delta
		if _travelled >= max_distance:
			queue_free()
		return
	var collider: Object = hit.get("collider")
	var hit_pos: Vector2 = hit.get("position")
	var normal: Vector2 = hit.get("normal", -velocity.normalized())
	if collider is Hurtbox:
		var actor: Node = collider.get_actor()
		if actor and actor.has_method("is_covered_from") and actor.is_covered_from(origin):
			# 몸을 낮춘 대상: 엄폐물이 대신 맞는다
			var cover_hit := _cover_hit_between(space, from, hit_pos)
			var spark_pos: Vector2 = cover_hit.get("position", hit_pos)
			Fx.impact(self, spark_pos, cover_hit.get("normal", normal))
			Fx.bullet_hole(self, spark_pos)
			Sfx.play("impact", -10.0, randf_range(0.9, 1.1))
		else:
			var info := DamageInfo.bullet(damage, source, velocity.normalized(), hit_pos)
			collider.take_hit(info)
	else:
		Fx.impact(self, hit_pos, normal)
		Fx.bullet_hole(self, hit_pos)
		Sfx.play("impact", -12.0, randf_range(0.85, 1.15))
		if collider and collider.has_method("on_bullet_hit"):
			collider.on_bullet_hit(hit_pos, velocity.normalized())
	queue_free()


func _cover_hit_between(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2) -> Dictionary:
	var q := PhysicsRayQueryParameters2D.create(from, to, Layers.LOW_COVER)
	q.collide_with_areas = false
	return space.intersect_ray(q)
