class_name Melee
extends Node
## 상황별 근접 공격 해석기. F 하나로 거리·방향·상대 상태에 따라 다른 동작을 고른다.
##
##  - 상대가 경직 중이거나 나를 인지하지 못했다 → 제압(takedown, 즉사)
##  - 그 외 → 타격(strike). 짧은 전진(lunge)과 경직·밀쳐내기를 동반한다.
##  - 0.8초 안에 이어지는 3번째 타격은 피니시(더 큰 피해·긴 경직)
## 자동으로 적에게 순간이동하지 않고, 동작 시간도 0.5초를 넘기지 않는다.

signal hit(target: Node, info: DamageInfo)
signal takedown_performed(target: Node)
signal whiffed

const COMBO_WINDOW := 0.8
const ARC_DEG := 110.0
const TAKEDOWN_TIME := 0.45
const LUNGE_DISTANCE := 18.0

@export var team: StringName = &"player"

var combo_count: int = 0
var _combo_timer: float = 0.0
var _actor: Node


func _ready() -> void:
	_actor = get_parent()


func _process(delta: float) -> void:
	if _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			combo_count = 0


## 공격을 실행하고 액터가 재생해야 할 동작 정보를 돌려준다.
## 반환: {"kind": "takedown"|"strike"|"whiff", "duration": float, "lunge": Vector2, "target": Node}
func perform(origin: Vector2, aim_dir: Vector2, weapon: WeaponData) -> Dictionary:
	var range_px := weapon.melee_range if weapon else 34.0
	var target := find_target(origin, aim_dir, range_px + LUNGE_DISTANCE)
	if target == null:
		combo_count = 0
		whiffed.emit()
		Sfx.play("dodge", -6.0, 0.8)
		return {"kind": "whiff", "duration": 0.2, "lunge": aim_dir * 6.0, "target": null}
	var to_target: Vector2 = (target.global_position - origin)
	var dir := to_target.normalized()
	var lunge := dir * clampf(to_target.length() - range_px * 0.6, 0.0, LUNGE_DISTANCE)
	var vulnerable: bool = target.has_method("is_takedown_vulnerable") and target.is_takedown_vulnerable(_actor)
	if vulnerable:
		var info := DamageInfo.takedown(_actor, dir, target.global_position)
		_apply(target, info)
		combo_count = 0
		Sfx.play("punch", 0.0, 0.7)
		takedown_performed.emit(target)
		return {"kind": "takedown", "duration": TAKEDOWN_TIME, "lunge": lunge, "target": target}
	combo_count += 1
	_combo_timer = COMBO_WINDOW
	var dmg := weapon.melee_damage if weapon else 20.0
	var stagger := weapon.melee_stagger if weapon else 0.5
	var knock := weapon.melee_knockback if weapon else 90.0
	var finisher := combo_count >= 3
	if finisher:
		dmg *= 1.8
		stagger *= 1.6
		knock *= 1.5
		combo_count = 0
	var info := DamageInfo.melee(dmg, _actor, dir, target.global_position, stagger, knock)
	_apply(target, info)
	Sfx.play("punch", -2.0, 1.2 if finisher else randf_range(0.95, 1.1))
	return {"kind": "strike", "duration": (weapon.melee_swing_time if weapon else 0.22) * (1.3 if finisher else 1.0), "lunge": lunge, "target": target, "finisher": finisher}


func _apply(target: Node, info: DamageInfo) -> void:
	if target.has_method("take_damage"):
		target.take_damage(info)
		hit.emit(target, info)


## 전방 부채꼴 안에서 가장 가까운 적 액터를 찾는다.
func find_target(origin: Vector2, aim_dir: Vector2, range_px: float) -> Node:
	var space: PhysicsDirectSpaceState2D = _actor.get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = range_px
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.transform = Transform2D(0.0, origin)
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.collision_mask = Layers.hurtbox_against_team(team)
	var best: Node = null
	var best_dist := INF
	for r in space.intersect_shape(q, 8):
		var hb: Object = r.get("collider")
		if not (hb is Hurtbox):
			continue
		var actor: Node = hb.get_actor()
		if actor == null or actor == _actor:
			continue
		if actor.has_method("is_alive") and not actor.is_alive():
			continue
		var offset: Vector2 = actor.global_position - origin
		var dist := offset.length()
		if dist > 1.0 and absf(rad_to_deg(aim_dir.angle_to(offset))) > ARC_DEG * 0.5:
			continue
		if dist < best_dist:
			best_dist = dist
			best = actor
	return best
