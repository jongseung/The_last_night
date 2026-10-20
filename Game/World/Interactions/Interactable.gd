class_name Interactable
extends Area2D
## E 키 상호작용 기본 클래스. 플레이어의 InteractRange 가 겹치는 것 중 가장 가까운 대상을 고른다.
## hold_time > 0 이면 E 를 누르고 있어야 완료된다 (정비, 문 따기 등).

signal interacted(actor: Node)
signal hold_progress(ratio: float)

@export var prompt: String = "상호작용"
@export var enabled: bool = true
@export var hold_time: float = 0.0
@export var one_shot: bool = false

var _hold := 0.0
var _used := false


func _ready() -> void:
	collision_layer = Layers.INTERACTABLE
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("interactables")


func get_prompt() -> String:
	return prompt


func can_interact(_actor: Node) -> bool:
	return enabled and not (_used and one_shot)


## 즉시 상호작용 (hold_time == 0) 또는 홀드 완료 시 호출
func interact(actor: Node) -> void:
	if not can_interact(actor):
		return
	_used = true
	_on_interact(actor)
	interacted.emit(actor)


## 홀드형: 매 프레임 delta 를 넘기면 완료 여부를 돌려준다
func hold(actor: Node, delta: float) -> bool:
	if not can_interact(actor):
		return false
	_hold += delta
	hold_progress.emit(clampf(_hold / hold_time, 0.0, 1.0))
	if _hold >= hold_time:
		_hold = 0.0
		interact(actor)
		return true
	return false


func release_hold() -> void:
	_hold = 0.0
	hold_progress.emit(0.0)


func hold_ratio() -> float:
	return 0.0 if hold_time <= 0.0 else clampf(_hold / hold_time, 0.0, 1.0)


func _on_interact(_actor: Node) -> void:
	pass
