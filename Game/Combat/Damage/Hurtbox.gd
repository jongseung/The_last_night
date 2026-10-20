class_name Hurtbox
extends Area2D
## 피격 판정 영역. Bullet 의 레이캐스트와 Melee 의 범위 판정이 이 Area2D 를 찾는다.
## 실제 피해 처리는 소유 액터(Actor)의 take_damage() 로 위임한다.

@export var actor_path: NodePath = ^".."

var actor: Node


func _ready() -> void:
	actor = get_node_or_null(actor_path)
	monitoring = false   # 이 영역은 조회 대상일 뿐 스스로 감지하지 않는다
	monitorable = true


func take_hit(info: DamageInfo) -> bool:
	if actor and actor.has_method("take_damage"):
		return actor.take_damage(info)
	return false


func get_actor() -> Node:
	return actor
