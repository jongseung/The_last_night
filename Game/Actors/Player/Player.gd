class_name Player
extends Actor
## 강도윤 조작. WASD 이동 · 마우스 조준 · 좌클릭 사격 · 우클릭 정밀조준 · F 근접
## Space 회피/엄폐물 넘기 · Shift 달리기 · R 재장전 · E 상호작용 · Q 무기 전환 · Ctrl 낮은 자세
##
## 설계 원칙: 모든 동작은 0.5초 안에 끝나고, 플레이어는 언제든 다음 행동을 준비할 수 있다.
## 세계관 규칙 "주인공은 초인이 아니다": 달리기·회피·근접은 체력(스태미나)을 쓰고, 지치면 못 한다.

signal interact_target_changed(target: Interactable)
signal hold_progress_changed(ratio: float)
signal state_changed(state: State)
signal kill_registered(actor: Actor)
signal stamina_changed(current: float, maximum: float)

enum State { NORMAL, DODGE, MELEE, DEAD }

const WALK_SPEED := 165.0
const SPRINT_SPEED := 270.0
const CROUCH_SPEED := 85.0
const AIM_SPEED := 110.0
const DODGE_SPEED := 480.0
const DODGE_TIME := 0.18
const VAULT_TIME := 0.26
const DODGE_IFRAMES := 0.12
const FOOTSTEP_INTERVAL := 0.28
const SPRINT_NOISE := 170.0

const STAMINA_MAX := 100.0
const STAMINA_SPRINT_PER_SEC := 22.0
const STAMINA_DODGE := 28.0
const STAMINA_MELEE := 6.0
const STAMINA_REGEN_PER_SEC := 30.0
const STAMINA_REGEN_DELAY := 0.7
const STAMINA_WINDED_UNTIL := 25.0      ## 바닥난 뒤 이만큼 회복해야 다시 달릴 수 있다

@onready var interact_range: Area2D = $InteractRange
@onready var light: PointLight2D = $Light

var state: State = State.NORMAL
var input_enabled: bool = true
var precise_aim: bool = false
var sprinting: bool = false
var move_input: Vector2 = Vector2.ZERO
var kills: int = 0
var current_interactable: Interactable = null

var _action_left: float = 0.0
var _action_velocity: Vector2 = Vector2.ZERO
var _dodge_dir: Vector2 = Vector2.RIGHT
var _vaulting: bool = false
var _vault_clear_t: float = 0.0
var _footstep_t: float = 0.0
var _base_mask: int = 0
var _input_grace: float = 0.0
var stamina: float = STAMINA_MAX
var winded: bool = false
var _stamina_delay: float = 0.0


func _ready() -> void:
	team = &"player"
	super._ready()
	_base_mask = collision_mask
	add_to_group("player")
	GameState.register_player(self)
	gunplay.fired.connect(_on_fired)
	gunplay.dry_fired.connect(func() -> void: GameState.show_hint("탄약 없음 · R 재장전 / Q 무기 전환 / E 무기 획득", 2.5))


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_input_grace = maxf(_input_grace - delta, 0.0)
	_update_stamina(delta)
	if input_enabled:
		_update_aim()
	if not input_enabled:
		move_input = Vector2.ZERO
		precise_aim = false
		sprinting = false
		move_actor(delta, Vector2.ZERO)
		_update_interactable()
		return
	match state:
		State.NORMAL:
			_normal_state(delta)
		State.DODGE:
			_dodge_state(delta)
		State.MELEE:
			_melee_state(delta)
	_update_interactable()
	_handle_interact(delta)


# -- 입력 상태 ----------------------------------------------------------------

func _update_aim() -> void:
	# 마우스는 상체 높이를 가리킨다 → 바닥 좌표로 내려서 조준 방향을 구한다
	var target := ViewSpace.ground_from_aim(get_global_mouse_position())
	var dir := target - global_position
	if dir.length() > 2.0:
		face(dir)


func _update_stamina(delta: float) -> void:
	var before := stamina
	if sprinting:
		stamina = maxf(stamina - STAMINA_SPRINT_PER_SEC * delta, 0.0)
		_stamina_delay = STAMINA_REGEN_DELAY
		if stamina <= 0.0:
			winded = true
	elif _stamina_delay > 0.0:
		_stamina_delay -= delta
	else:
		stamina = minf(stamina + STAMINA_REGEN_PER_SEC * delta, STAMINA_MAX)
	if winded and stamina >= STAMINA_WINDED_UNTIL:
		winded = false
	if stamina != before:
		stamina_changed.emit(stamina, STAMINA_MAX)


func _spend_stamina(amount: float) -> bool:
	if stamina < amount:
		return false
	stamina -= amount
	_stamina_delay = STAMINA_REGEN_DELAY
	stamina_changed.emit(stamina, STAMINA_MAX)
	return true


func _normal_state(delta: float) -> void:
	move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	precise_aim = Input.is_action_pressed("aim") and gunplay.has_gun()
	if Input.is_action_just_pressed("crouch"):
		crouching = not crouching
	sprinting = Input.is_action_pressed("sprint") and move_input != Vector2.ZERO and not precise_aim and not crouching and not winded and stamina > 0.0

	var speed := WALK_SPEED
	if crouching:
		speed = CROUCH_SPEED
	elif precise_aim:
		speed = AIM_SPEED
	elif sprinting:
		speed = SPRINT_SPEED
	move_actor(delta, move_input * speed)

	if sprinting:
		_footstep_t -= delta
		if _footstep_t <= 0.0:
			_footstep_t = FOOTSTEP_INTERVAL
			NoiseBus.emit_noise(global_position, SPRINT_NOISE, self, "footstep")

	if is_staggered() or _input_grace > 0.0:
		return

	if Input.is_action_just_pressed("dodge"):
		if _spend_stamina(STAMINA_DODGE):
			_start_dodge()
			return
		GameState.show_hint("숨이 차다", 1.0)
	if Input.is_action_just_pressed("melee"):
		_start_melee()
		return
	if Input.is_action_just_pressed("swap_weapon"):
		inventory.cycle()
		Sfx.play("ui", -12.0)
	if Input.is_action_just_pressed("reload"):
		gunplay.try_reload()

	var weapon := current_weapon()
	if gunplay.has_gun():
		var want_fire := Input.is_action_pressed("fire") if weapon.automatic else Input.is_action_just_pressed("fire")
		if want_fire:
			var penalty := 0.0
			if move_input != Vector2.ZERO:
				penalty += 2.0 if not sprinting else 6.0
			if crouching:
				penalty -= 1.0
			gunplay.try_fire(muzzle_position(), aim_dir, precise_aim, penalty)
	elif Input.is_action_just_pressed("fire"):
		_start_melee()


func _start_dodge() -> void:
	_dodge_dir = move_input.normalized() if move_input != Vector2.ZERO else aim_dir
	_vaulting = _low_cover_ahead(_dodge_dir, 28.0)
	_action_left = VAULT_TIME if _vaulting else DODGE_TIME
	if _vaulting:
		collision_mask = _base_mask & ~Layers.LOW_COVER
	crouching = false
	health.invulnerable = true
	get_tree().create_timer(DODGE_IFRAMES).timeout.connect(func() -> void: health.invulnerable = false)
	gunplay.cancel_reload()
	Sfx.play("dodge", -8.0)
	_set_state(State.DODGE)


func _dodge_state(delta: float) -> void:
	_action_left -= delta
	move_actor(delta, _dodge_dir * (DODGE_SPEED * 0.85 if _vaulting else DODGE_SPEED))
	if _action_left <= 0.0:
		if _vaulting and _overlapping_low_cover():
			# 아직 엄폐물 위에 있다 → 빠져나올 때까지 조금 더 전진
			_vault_clear_t += delta
			if _vault_clear_t < 0.35:
				_action_left = 0.02
				return
		collision_mask = _base_mask
		_vaulting = false
		_vault_clear_t = 0.0
		_set_state(State.NORMAL)


func _start_melee() -> void:
	_spend_stamina(minf(STAMINA_MELEE, stamina))
	var result := melee.perform(global_position, aim_dir, current_weapon())
	_action_left = result.get("duration", 0.2)
	var lunge: Vector2 = result.get("lunge", Vector2.ZERO)
	_action_velocity = lunge / maxf(_action_left, 0.01)
	gunplay.cancel_reload()
	_set_state(State.MELEE)
	var kind: String = result.get("kind", "whiff")
	if kind == "takedown":
		_play_swing(1.0)
	elif kind == "strike":
		_play_swing(0.5 if not result.get("finisher", false) else 0.8)


func _melee_state(delta: float) -> void:
	_action_left -= delta
	move_actor(delta, _action_velocity)
	_action_velocity = _action_velocity.move_toward(Vector2.ZERO, 900.0 * delta)
	if _action_left <= 0.0:
		_set_state(State.NORMAL)


func _play_swing(strength: float) -> void:
	visual.play_action(0.12 + 0.12 * strength)


func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(state)


# -- 엄폐물 넘기 --------------------------------------------------------------

func _low_cover_ahead(dir: Vector2, distance: float) -> bool:
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + dir * distance, Layers.LOW_COVER)
	q.collide_with_areas = false
	return not space.intersect_ray(q).is_empty()


func _overlapping_low_cover() -> bool:
	var space := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = 8.0
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.transform = Transform2D(0.0, global_position)
	q.collision_mask = Layers.LOW_COVER
	q.collide_with_areas = false
	return not space.intersect_shape(q, 1).is_empty()


# -- 상호작용 -----------------------------------------------------------------

func _update_interactable() -> void:
	var best: Interactable = null
	var best_d := INF
	for area in interact_range.get_overlapping_areas():
		if area is Interactable and area.can_interact(self):
			var d := global_position.distance_squared_to(area.global_position)
			if d < best_d:
				best_d = d
				best = area
	if best != current_interactable:
		if current_interactable and is_instance_valid(current_interactable):
			current_interactable.release_hold()
		current_interactable = best
		interact_target_changed.emit(best)


func _handle_interact(delta: float) -> void:
	if current_interactable == null or not is_instance_valid(current_interactable):
		return
	if state != State.NORMAL:
		return
	if current_interactable.hold_time > 0.0:
		if Input.is_action_pressed("interact"):
			var target := current_interactable
			var done := target.hold(self, delta)
			hold_progress_changed.emit(0.0 if done else target.hold_ratio())
		elif Input.is_action_just_released("interact"):
			current_interactable.release_hold()
			hold_progress_changed.emit(0.0)
	elif Input.is_action_just_pressed("interact"):
		current_interactable.interact(self)


# -- 이벤트 -------------------------------------------------------------------

func _on_fired(slot: WeaponSlot) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("add_trauma"):
		cam.add_trauma(slot.data.camera_kick)


func register_kill(actor: Actor) -> void:
	kills += 1
	kill_registered.emit(actor)


func take_damage(info: DamageInfo) -> bool:
	var applied := super.take_damage(info)
	if applied:
		var cam := get_viewport().get_camera_2d()
		if cam and cam.has_method("add_trauma"):
			cam.add_trauma(0.3)
	return applied


## 플레이어는 제압(즉사)당하지 않는다 — 세계관 규칙상 죽을 수는 있지만 한 방은 아니다.
func is_takedown_vulnerable(_attacker: Node) -> bool:
	return false


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if enabled:
		_input_grace = 0.2
	if not enabled:
		move_input = Vector2.ZERO
		precise_aim = false
		sprinting = false
		if current_interactable and is_instance_valid(current_interactable):
			current_interactable.release_hold()


func _on_died(_info: DamageInfo) -> void:
	_set_state(State.DEAD)
	set_input_enabled(false)
	light.energy = 0.0
