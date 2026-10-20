class_name DamageInfo
extends RefCounted
## 한 번의 피해를 설명하는 값 객체. Bullet / Melee / 환경 피해가 모두 이 형태로 전달된다.

enum Kind { BULLET, MELEE, TAKEDOWN, ENVIRONMENT }

var amount: float = 0.0
var kind: Kind = Kind.BULLET
var source: Node = null          ## 피해를 준 액터 (없을 수 있음)
var direction: Vector2 = Vector2.RIGHT
var hit_position: Vector2 = Vector2.ZERO
var knockback: float = 0.0
var stagger: float = 0.0         ## 초 단위 경직 시간
var causes_bleed: bool = false


static func bullet(amount_: float, source_: Node, dir: Vector2, pos: Vector2) -> DamageInfo:
	var d := DamageInfo.new()
	d.amount = amount_
	d.kind = Kind.BULLET
	d.source = source_
	d.direction = dir
	d.hit_position = pos
	d.knockback = 40.0
	d.stagger = 0.12
	d.causes_bleed = true
	return d


static func melee(amount_: float, source_: Node, dir: Vector2, pos: Vector2, stagger_: float, knockback_: float) -> DamageInfo:
	var d := DamageInfo.new()
	d.amount = amount_
	d.kind = Kind.MELEE
	d.source = source_
	d.direction = dir
	d.hit_position = pos
	d.knockback = knockback_
	d.stagger = stagger_
	return d


static func takedown(source_: Node, dir: Vector2, pos: Vector2) -> DamageInfo:
	var d := DamageInfo.new()
	d.amount = 9999.0
	d.kind = Kind.TAKEDOWN
	d.source = source_
	d.direction = dir
	d.hit_position = pos
	return d
