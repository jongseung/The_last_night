class_name Actor
extends CharacterBody2D
## 플레이어와 적이 공유하는 액터 기반. 체력·피격·경직·넉백·무기 장착·사망 처리를 담당한다.
## 자식 노드 규약: Visual(CharacterVisual) · Health · Hurtbox(Area2D) · Gunplay(Node2D) · Melee(Node)
## 원점 = 발 (ViewSpace 규약).

signal died(actor: Actor, info: DamageInfo)
signal damaged(actor: Actor, info: DamageInfo)
signal weapon_changed(slot: WeaponSlot)

const COVER_RADIUS := 56.0   ## 이 거리 안의 낮은 엄폐물만 몸을 가려준다
const MUZZLE_DISTANCE := 16.0

@export var team: StringName = &"enemy"
@export var walk_speed: float = 150.0

@onready var health: Health = $Health
@onready var visual: CharacterVisual = $Visual
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var gunplay: Gunplay = $Gunplay
@onready var melee: Melee = $Melee

var inventory: Inventory = Inventory.new()
var aim_dir: Vector2 = Vector2.RIGHT
var crouching: bool = false
var stagger_left: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO
var is_dead: bool = false
var _flash_tween: Tween


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	visual.set_variant(visual_variant())
	gunplay.team = team
	melee.team = team
	hurtbox.collision_layer = Layers.hurtbox_for_team(team)
	hurtbox.collision_mask = 0
	health.died.connect(_on_health_died)
	gunplay.fired.connect(func(_s: WeaponSlot) -> void: visual.play_action(0.09))
	inventory.current_changed.connect(equip_slot)
	equip_slot(inventory.current())


## 그림 변형 이름 (assets/sprites/chars/*_<variant>*.png)
func visual_variant() -> String:
	return "player"


func _process(delta: float) -> void:
	if stagger_left > 0.0:
		stagger_left = maxf(stagger_left - delta, 0.0)


# -- 무기 -------------------------------------------------------------------

func equip_slot(slot: WeaponSlot) -> void:
	if slot and slot.data:
		visual.set_weapon(slot.data.visual_key)
	gunplay.set_slot(slot)
	weapon_changed.emit(slot)


func current_weapon() -> WeaponData:
	return inventory.current().data


## 바닥 좌표의 총구 위치. 그림은 ViewSpace.GUN_HEIGHT 만큼 올려 그린다.
func muzzle_position() -> Vector2:
	return global_position + aim_dir * MUZZLE_DISTANCE


func pick_up_weapon(slot: WeaponSlot) -> bool:
	return inventory.add_weapon(slot, true)


func add_ammo(id: StringName, rounds: int) -> bool:
	return inventory.add_ammo(id, rounds)


# -- 상태 -------------------------------------------------------------------

func is_alive() -> bool:
	return not is_dead


func is_staggered() -> bool:
	return stagger_left > 0.0


## 적이 나를 인지하지 못한 상태인지. Enemy 가 재정의한다.
func is_unaware() -> bool:
	return false


## 제압(takedown) 가능 여부: 살아 있고, 경직 중이거나 나를 인지하지 못한 상태
func is_takedown_vulnerable(_attacker: Node) -> bool:
	return is_alive() and (is_staggered() or is_unaware())


func face(dir: Vector2) -> void:
	if dir.length_squared() < 0.0001:
		return
	aim_dir = dir.normalized()
	visual.aim_dir = aim_dir


## 넉백을 합산해 이동한다. 경직 중에는 자발적 이동이 무시된다.
func move_actor(delta: float, desired_velocity: Vector2) -> void:
	velocity = (Vector2.ZERO if is_staggered() else desired_velocity) + knockback_velocity
	move_and_slide()
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, 900.0 * delta)
	visual.move_velocity = get_real_velocity()
	visual.crouching = crouching


# -- 피격 -------------------------------------------------------------------

func take_damage(info: DamageInfo) -> bool:
	if is_dead:
		return false
	if not health.take_damage(info):
		return false
	knockback_velocity += info.direction * info.knockback
	stagger_left = maxf(stagger_left, info.stagger)
	Fx.blood(self, ViewSpace.lift(global_position, 22.0), global_position, info.direction, info.kind != DamageInfo.Kind.BULLET)
	Sfx.play("hit_flesh", -6.0, randf_range(0.9, 1.1))
	_flash()
	damaged.emit(self, info)
	return true


## 몸을 낮춘 상태에서 origin 과 나 사이에 가까운 낮은 엄폐물이 있으면 총알을 막는다.
func is_covered_from(origin: Vector2) -> bool:
	if not crouching or is_dead:
		return false
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(origin, global_position, Layers.LOW_COVER)
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return false
	return (hit.get("position") as Vector2).distance_to(global_position) <= COVER_RADIUS


func _flash() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	visual.modulate = Color(2.0, 1.6, 1.6)
	_flash_tween = create_tween()
	_flash_tween.tween_property(visual, "modulate", Color.WHITE, 0.12)


func _on_health_died(info: DamageInfo) -> void:
	is_dead = true
	stagger_left = 0.0
	collision_layer = 0
	collision_mask = Layers.WORLD
	hurtbox.collision_layer = 0
	hurtbox.set_deferred("monitorable", false)
	z_index = -1
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	visual.modulate = Color.WHITE
	visual.die(info.direction)
	Fx.blood(self, ViewSpace.lift(global_position, 10.0), global_position, info.direction, true)
	_drop_weapons()
	died.emit(self, info)
	_on_died(info)


## 서브클래스 훅
func _on_died(_info: DamageInfo) -> void:
	pass


func _drop_weapons() -> void:
	var parent: Node = get_tree().get_first_node_in_group("level")
	if parent and parent.has_node("Props"):
		parent = parent.get_node("Props")
	if parent == null:
		return
	for slot in inventory.slots:
		if slot.data.kind == WeaponData.Kind.FISTS:
			continue
		if slot.is_gun() and slot.total_ammo() <= 0:
			continue
		var offset := Vector2.from_angle(randf() * TAU) * randf_range(8.0, 18.0)
		WeaponPickup.create(parent, global_position + offset, slot.data, slot.ammo, slot.reserve)
