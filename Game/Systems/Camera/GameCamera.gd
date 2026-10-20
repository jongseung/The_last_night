class_name GameCamera
extends Camera2D
## 근접 전투용 카메라. 플레이어를 따라가되 조준 방향으로 화면을 밀어 시야를 확보한다.
## 정밀 조준 시 더 멀리 밀리고, 총격·피격에 따라 짧은 흔들림(trauma)을 준다.

@export var target_path: NodePath
@export var follow_speed: float = 9.0
@export var aim_offset_max: float = 70.0
@export var aim_offset_max_precise: float = 130.0
@export var aim_offset_ratio: float = 0.45
@export var max_shake: float = 6.0
@export var bounds: Rect2 = Rect2()

var target: Node2D
var trauma: float = 0.0
var _desired := Vector2.ZERO
var _noise_t := 0.0


func _ready() -> void:
	if target_path != NodePath():
		target = get_node_or_null(target_path)
	if target == null and GameState.player:
		target = GameState.player
	GameState.player_registered.connect(func(p: Node) -> void: target = p)
	if target:
		global_position = target.global_position
		_desired = global_position
	make_current()
	_apply_bounds()


func _apply_bounds() -> void:
	if bounds.size == Vector2.ZERO:
		return
	limit_left = int(bounds.position.x)
	limit_top = int(bounds.position.y)
	limit_right = int(bounds.end.x)
	limit_bottom = int(bounds.end.y)


func set_bounds(rect: Rect2) -> void:
	bounds = rect
	_apply_bounds()


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var precise: bool = "precise_aim" in target and target.precise_aim
	var limit := aim_offset_max_precise if precise else aim_offset_max
	var mouse := target.get_global_mouse_position()
	var offset := (mouse - target.global_position) * aim_offset_ratio
	if offset.length() > limit:
		offset = offset.normalized() * limit
	_desired = target.global_position + offset
	global_position = global_position.lerp(_desired, 1.0 - exp(-follow_speed * delta))
	trauma = maxf(trauma - delta * 1.8, 0.0)
	if trauma > 0.0:
		_noise_t += delta * 40.0
		var shake := trauma * trauma * max_shake
		offset = Vector2(sin(_noise_t * 1.3) * shake, cos(_noise_t * 1.7) * shake)
		self.offset = offset
	else:
		self.offset = Vector2.ZERO


func add_trauma(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)


func snap_to_target() -> void:
	if target:
		global_position = target.global_position
		_desired = global_position
