class_name Health
extends Node
## 체력·출혈 컴포넌트. 액터의 자식으로 두고 take_damage() 로 피해를 적용한다.
##
## 세계관 규칙 "주인공은 초인이 아니다": 체력은 자동 회복되지 않고, 총상은 출혈을
## 남겨 시간이 지날수록 체력을 깎는다. 출혈은 일정 시간 뒤 스스로 멎는다.

signal health_changed(current: float, maximum: float)
signal damaged(info: DamageInfo)
signal died(info: DamageInfo)
signal bleeding_changed(is_bleeding: bool)

@export var max_health: float = 100.0
@export var bleed_rate: float = 1.0          ## 초당 출혈 피해
@export var bleed_duration: float = 6.0      ## 총상 1회당 출혈 지속 시간
@export var invulnerable: bool = false

var health: float
var bleed_time_left: float = 0.0
var is_dead: bool = false

var is_bleeding: bool:
	get:
		return bleed_time_left > 0.0


func _ready() -> void:
	health = max_health
	health_changed.emit(health, max_health)


func _process(delta: float) -> void:
	if is_dead or bleed_time_left <= 0.0:
		return
	bleed_time_left -= delta
	health = maxf(health - bleed_rate * delta, 1.0)   # 출혈만으로는 죽지 않는다
	health_changed.emit(health, max_health)
	if bleed_time_left <= 0.0:
		bleeding_changed.emit(false)


func take_damage(info: DamageInfo) -> bool:
	if is_dead or invulnerable:
		return false
	health = maxf(health - info.amount, 0.0)
	damaged.emit(info)
	if info.causes_bleed and health > 0.0:
		var was_bleeding := is_bleeding
		bleed_time_left = bleed_duration
		if not was_bleeding:
			bleeding_changed.emit(true)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		is_dead = true
		bleed_time_left = 0.0
		died.emit(info)
	return true


func heal(amount: float, stop_bleeding: bool = true) -> void:
	if is_dead:
		return
	health = minf(health + amount, max_health)
	if stop_bleeding and bleed_time_left > 0.0:
		bleed_time_left = 0.0
		bleeding_changed.emit(false)
	health_changed.emit(health, max_health)


func ratio() -> float:
	return health / max_health if max_health > 0.0 else 0.0
