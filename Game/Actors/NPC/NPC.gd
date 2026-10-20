class_name NPC
extends CharacterBody2D
## 연출용 비전투 인물. 직선 이동·바라보기·퇴장을 코루틴으로 제공한다.

signal arrived

@export var speed: float = 90.0
@export var display_name: String = "방문객"
@export var variant: String = "visitor"

@onready var visual: CharacterVisual = $Visual

var _goal: Vector2
var _moving := false


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("npcs")
	visual.set_variant(variant)
	visual.aim_dir = Vector2.DOWN


func _physics_process(_delta: float) -> void:
	if not _moving:
		velocity = Vector2.ZERO
		visual.move_velocity = Vector2.ZERO
		return
	var offset := _goal - global_position
	if offset.length() < 3.0:
		_moving = false
		velocity = Vector2.ZERO
		visual.move_velocity = Vector2.ZERO
		arrived.emit()
		return
	velocity = offset.normalized() * speed
	visual.aim_dir = velocity.normalized()
	move_and_slide()
	visual.move_velocity = get_real_velocity()


func walk_to(pos: Vector2) -> void:
	_goal = pos
	_moving = true
	await arrived


func face_toward(pos: Vector2) -> void:
	var dir := pos - global_position
	if dir.length() > 0.5:
		visual.aim_dir = dir.normalized()


func vanish(duration: float = 0.4) -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, duration)
	await t.finished
	queue_free()
