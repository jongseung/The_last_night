class_name Enemy
extends Actor
## 백야회 행동대원 AI. 시야·청각으로 플레이어를 인지하고, 총기형은 거리 유지와 엄폐를,
## 근접형은 돌진과 예비 동작(텔레그래프)이 있는 휘두르기를 수행한다.
##
## 상태: IDLE → SUSPICIOUS(소음 조사) → COMBAT(교전) → SEARCH(놓침) → IDLE
## 인지하지 못한 상태(IDLE/PATROL/SUSPICIOUS)에서는 뒤에서 제압(takedown)당할 수 있다.

enum AIState { IDLE, PATROL, SUSPICIOUS, COMBAT, SEARCH }

const PISTOL: WeaponData = preload("res://Game/Combat/Weapons/Pistol.tres")
const PIPE: WeaponData = preload("res://Game/Combat/Weapons/Pipe.tres")
const TEX_GUNMAN: Texture2D = preload("res://assets/sprites/enemy_gunman.png")
const TEX_THUG: Texture2D = preload("res://assets/sprites/enemy_thug.png")

@export var archetype: StringName = &"gunman"   ## &"gunman" | &"thug"
@export var vision_range: float = 250.0
@export var vision_fov_deg: float = 110.0
@export var hearing_multiplier: float = 1.0
@export var patrol_points: Array[Vector2] = []
@export var spawn_alerted: bool = false
@export var accuracy_penalty_deg: float = 5.0

@onready var nav: NavigationAgent2D = $Nav
@onready var mark: Label = $Mark

var ai_state: AIState = AIState.IDLE
var target: Actor = null
var last_known: Vector2 = Vector2.ZERO
var has_los: bool = false
var darkness: float = 1.0     ## 레벨 조명 상태 (1 = 밝음, 0.5 = 정전)

var _perception_t := 0.0
var _think_t := 0.0
var _patrol_index := 0
var _wait_t := 0.0
var _search_t := 0.0
var _burst_shots := 0
var _burst_pause := 0.0
var _strafe_dir := 1.0
var _strafe_t := 0.0
var _cover: CoverPoint = null
var _cover_t := 0.0
var _peeking := false
var _melee_windup := 0.0
var _melee_cooldown := 0.0
var _move_dir := Vector2.ZERO
var _time_since_seen := 999.0


func _ready() -> void:
	team = &"enemy"
	super._ready()
	add_to_group("enemies")
	nav.path_desired_distance = 6.0
	nav.target_desired_distance = 8.0
	nav.radius = 9.0
	NoiseBus.noise_emitted.connect(_on_noise)
	if archetype == &"thug":
		health.max_health = 70.0
		walk_speed = 150.0
		inventory.add_weapon(WeaponSlot.create(PIPE, 0, 0), true)
	else:
		health.max_health = 60.0
		walk_speed = 110.0
		inventory.add_weapon(WeaponSlot.create(PISTOL, 12, 12), true)
	health.health = health.max_health
	mark.visible = false
	target = GameState.player as Actor
	if target == null:
		GameState.player_registered.connect(func(p: Node) -> void: target = p as Actor, CONNECT_ONE_SHOT)
	if spawn_alerted:
		call_deferred("alert_to", target.global_position if target else global_position)


func equip_slot(slot: WeaponSlot) -> void:
	super.equip_slot(slot)
	body.texture = TEX_THUG if archetype == &"thug" else TEX_GUNMAN


func is_unaware() -> bool:
	return ai_state != AIState.COMBAT and ai_state != AIState.SEARCH


# -- 메인 루프 ----------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if target == null or not is_instance_valid(target):
		move_actor(delta, Vector2.ZERO)
		return
	_perception_t -= delta
	if _perception_t <= 0.0:
		_perception_t = 0.1
		_perceive()
	_melee_cooldown = maxf(_melee_cooldown - delta, 0.0)
	_time_since_seen += delta
	var desired := Vector2.ZERO
	match ai_state:
		AIState.IDLE:
			desired = _idle(delta)
		AIState.PATROL:
			desired = _patrol(delta)
		AIState.SUSPICIOUS:
			desired = _suspicious(delta)
		AIState.COMBAT:
			desired = _combat(delta)
		AIState.SEARCH:
			desired = _search(delta)
	if is_staggered():
		_melee_windup = 0.0
		body.modulate = body.modulate.lerp(Color.WHITE, delta * 10.0)
	move_actor(delta, desired)


# -- 인지 ---------------------------------------------------------------------

func _perceive() -> void:
	has_los = _can_see(target)
	if has_los:
		last_known = target.global_position
		_time_since_seen = 0.0
		if ai_state != AIState.COMBAT:
			_enter_combat()


func _can_see(actor: Actor) -> bool:
	if actor == null or actor.is_dead:
		return false
	var offset := actor.global_position - global_position
	var range_px := vision_range * darkness
	if actor.crouching:
		range_px *= 0.7
	if ai_state == AIState.COMBAT or ai_state == AIState.SEARCH:
		range_px *= 1.4   # 교전 중에는 더 집중한다
	if offset.length() > range_px:
		return false
	var fov := vision_fov_deg if ai_state != AIState.COMBAT else 200.0
	if absf(rad_to_deg(aim_dir.angle_to(offset))) > fov * 0.5 and offset.length() > 24.0:
		return false
	return _line_of_sight(actor.global_position)


func _line_of_sight(pos: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, pos, Layers.WORLD | Layers.VISION_BLOCKER)
	q.collide_with_areas = false
	q.exclude = [get_rid()]
	return space.intersect_ray(q).is_empty()


func _on_noise(pos: Vector2, radius: float, source: Node, kind: String) -> void:
	if is_dead or source == self:
		return
	if source is Enemy:
		return
	var dist := global_position.distance_to(pos)
	if dist > radius * hearing_multiplier:
		return
	if ai_state == AIState.COMBAT:
		if source == target:
			last_known = pos
		return
	last_known = pos
	if kind == "gunshot" and dist < radius * 0.6:
		alert_to(pos)
	elif ai_state != AIState.SEARCH:
		_set_state(AIState.SUSPICIOUS)
		_wait_t = 0.0


## 외부에서 강제로 교전 상태로 만든다 (습격 스폰, 피격).
func alert_to(pos: Vector2) -> void:
	last_known = pos
	_time_since_seen = 0.0
	_enter_combat()


func _enter_combat() -> void:
	if ai_state == AIState.COMBAT:
		return
	_set_state(AIState.COMBAT)
	_burst_pause = randf_range(0.3, 0.7)   # 반응 시간
	_burst_shots = 0
	_release_cover()
	NoiseBus.emit_noise(global_position, 200.0, self, "shout")


func _set_state(s: AIState) -> void:
	if ai_state == s:
		return
	ai_state = s
	match s:
		AIState.SUSPICIOUS:
			_show_mark("?", Color(1.0, 0.85, 0.4))
		AIState.COMBAT:
			_show_mark("!", Color(1.0, 0.35, 0.3))
		AIState.SEARCH:
			_show_mark("?", Color(1.0, 0.85, 0.4))
		_:
			mark.visible = false


func _show_mark(text: String, color: Color) -> void:
	mark.text = text
	mark.modulate = color
	mark.visible = true
	var t := create_tween()
	t.tween_interval(1.2)
	t.tween_callback(func() -> void: mark.visible = false)


# -- 상태별 행동 --------------------------------------------------------------

func _idle(delta: float) -> Vector2:
	if not patrol_points.is_empty():
		_set_state(AIState.PATROL)
	_wait_t += delta
	if _wait_t > 3.0:
		_wait_t = 0.0
		face(aim_dir.rotated(randf_range(-0.8, 0.8)))
	return Vector2.ZERO


func _patrol(delta: float) -> Vector2:
	var goal := patrol_points[_patrol_index]
	if global_position.distance_to(goal) < 10.0:
		_wait_t += delta
		if _wait_t > 1.5:
			_wait_t = 0.0
			_patrol_index = (_patrol_index + 1) % patrol_points.size()
		return Vector2.ZERO
	var dir := _nav_dir(goal)
	face(dir)
	return dir * walk_speed * 0.6


func _suspicious(delta: float) -> Vector2:
	if global_position.distance_to(last_known) > 14.0:
		var dir := _nav_dir(last_known)
		face(dir)
		return dir * walk_speed * 0.8
	_wait_t += delta
	face(aim_dir.rotated(sin(_wait_t * 3.0) * 0.05))
	if _wait_t > 2.5:
		_wait_t = 0.0
		_set_state(AIState.PATROL if not patrol_points.is_empty() else AIState.IDLE)
	return Vector2.ZERO


func _search(delta: float) -> Vector2:
	_search_t += delta
	if global_position.distance_to(last_known) > 12.0:
		var dir := _nav_dir(last_known)
		face(dir)
		return dir * walk_speed
	face(aim_dir.rotated(delta * 1.5))
	if _search_t > 4.0:
		_search_t = 0.0
		_set_state(AIState.IDLE)
	return Vector2.ZERO


func _combat(delta: float) -> Vector2:
	if target.is_dead:
		_set_state(AIState.IDLE)
		return Vector2.ZERO
	if not has_los and _time_since_seen > 2.5:
		_search_t = 0.0
		_release_cover()
		_set_state(AIState.SEARCH)
		return Vector2.ZERO
	if archetype == &"thug":
		return _combat_thug(delta)
	return _combat_gunman(delta)


func _combat_thug(delta: float) -> Vector2:
	var to_target := target.global_position - global_position
	var dist := to_target.length()
	var weapon := current_weapon()
	if _melee_windup > 0.0:
		_melee_windup -= delta
		face(to_target)
		body.modulate = Color(1.3, 0.9, 0.7)
		if _melee_windup <= 0.0:
			body.modulate = Color.WHITE
			var result := melee.perform(global_position, aim_dir, weapon)
			_melee_cooldown = 1.0
			knockback_velocity += aim_dir * 60.0   # 휘두르며 한 발 전진
			if result.get("kind") == "whiff":
				_melee_cooldown = 0.6
		return Vector2.ZERO
	if dist <= weapon.melee_range + 4.0 and _melee_cooldown <= 0.0 and has_los:
		_melee_windup = 0.38
		NoiseBus.emit_noise(global_position, 80.0, self, "swing")
		return Vector2.ZERO
	var goal := last_known if not has_los else target.global_position
	var dir := _nav_dir(goal)
	face(to_target if has_los else dir)
	if dist <= weapon.melee_range + 2.0:
		return Vector2.ZERO
	return dir * walk_speed


func _combat_gunman(delta: float) -> Vector2:
	var to_target := target.global_position - global_position
	var dist := to_target.length()
	face(to_target if has_los else (last_known - global_position))

	# 체력이 낮거나 재장전 중이면 엄폐를 찾는다
	var wants_cover := health.ratio() < 0.55 or gunplay.reloading
	if wants_cover and _cover == null:
		_cover = _find_cover()
	if not wants_cover and _cover and _cover_t > 2.5:
		_release_cover()

	var desired := Vector2.ZERO
	if _cover:
		_cover_t += delta
		var d := global_position.distance_to(_cover.global_position)
		if d > 6.0:
			desired = _nav_dir(_cover.global_position) * walk_speed
			crouching = false
		else:
			# 엄폐 도착: 웅크렸다가 주기적으로 고개를 내밀고 사격
			_peeking = fmod(_cover_t, 2.2) > 1.3
			crouching = not _peeking
			if gunplay.slot.ammo <= 0 and not gunplay.reloading:
				gunplay.try_reload()
	else:
		crouching = false
		if has_los:
			if dist < 90.0:
				desired = -to_target.normalized() * walk_speed * 0.8
			elif dist > 230.0:
				desired = _nav_dir(target.global_position) * walk_speed
			else:
				_strafe_t -= delta
				if _strafe_t <= 0.0:
					_strafe_t = randf_range(0.6, 1.4)
					_strafe_dir = -_strafe_dir if randf() < 0.6 else _strafe_dir
				desired = to_target.normalized().orthogonal() * _strafe_dir * walk_speed * 0.5
		else:
			desired = _nav_dir(last_known) * walk_speed

	_shoot_logic(delta, dist, desired != Vector2.ZERO)
	return desired


func _shoot_logic(delta: float, dist: float, moving: bool) -> void:
	if not has_los or (_cover and not _peeking):
		_burst_pause = maxf(_burst_pause, 0.2)
		return
	if gunplay.slot.ammo <= 0:
		if not gunplay.reloading:
			gunplay.try_reload()
		return
	if _burst_pause > 0.0:
		_burst_pause -= delta
		return
	if not _line_of_sight(target.global_position):
		return
	var penalty := accuracy_penalty_deg + (4.0 if moving else 0.0) + clampf((dist - 120.0) / 40.0, 0.0, 4.0)
	if gunplay.try_fire(muzzle_position(), aim_dir, false, penalty):
		_burst_shots += 1
		if _burst_shots >= randi_range(2, 3):
			_burst_shots = 0
			_burst_pause = randf_range(0.8, 1.5)


func _find_cover() -> CoverPoint:
	var best: CoverPoint = null
	var best_d := 200.0
	for cp in get_tree().get_nodes_in_group("cover_points"):
		var point := cp as CoverPoint
		if point == null or not point.is_free(self):
			continue
		var d := global_position.distance_to(point.global_position)
		if d < best_d and point.protects_from(target.global_position):
			best_d = d
			best = point
	if best:
		best.occupant = self
		_cover_t = 0.0
	return best


func _release_cover() -> void:
	if _cover and is_instance_valid(_cover) and _cover.occupant == self:
		_cover.occupant = null
	_cover = null
	_peeking = false
	crouching = false


func _nav_dir(goal: Vector2) -> Vector2:
	nav.target_position = goal
	if nav.is_navigation_finished():
		return Vector2.ZERO
	var next := nav.get_next_path_position()
	var dir := next - global_position
	if dir.length() < 1.0:
		dir = goal - global_position
	return dir.normalized()


# -- 피격 -------------------------------------------------------------------

func take_damage(info: DamageInfo) -> bool:
	var applied := super.take_damage(info)
	if applied and not is_dead:
		var from: Vector2 = info.source.global_position if info.source is Node2D else global_position - info.direction * 50.0
		alert_to(from)
		if info.kind == DamageInfo.Kind.MELEE:
			face(-info.direction)
	return applied


func _on_died(_info: DamageInfo) -> void:
	_release_cover()
	mark.visible = false
	body.modulate = Color(0.55, 0.5, 0.52)
	if target and target.has_method("register_kill"):
		target.register_kill(self)
