class_name CharacterVisual
extends Node2D
## 3/4 뷰 캐릭터 그림. 다리(이동 방향)와 상체(조준 방향)를 분리한 8방향 시트를 재생한다.
##
## 시트 규격 (tools/gen_placeholders.py 머리말과 동일, 실제 Aseprite 아트도 이 규격을 따른다)
##   assets/sprites/chars/legs_<variant>.png            48×48 셀, 5열(0 정지, 1~4 걷기) × 8행(방향)
##   assets/sprites/chars/torso_<variant>_<weapon>.png  48×48 셀, 2열(0 기본, 1 동작) × 8행(방향)
##   assets/sprites/chars/dead_<variant>.png            48×48 1장
##   방향 행: 0 E · 1 SE · 2 S · 3 SW · 4 W · 5 NW · 6 N · 7 NE,  발 기준선 y = 44
## 이 노드의 원점이 발이다.

const FRAME := 48
const FEET_Y := 44
const DIRS := 8
const LEG_FRAMES := 5
const TORSO_FRAMES := 2
const WALK_FRAMES_PER_PX := 0.075     ## 이동 1px 당 걷기 프레임 진행량
const CHAR_DIR := "res://assets/sprites/chars/"

static var _tex_cache: Dictionary = {}

var variant: String = "player"
var weapon_key: String = "unarmed"
var aim_dir: Vector2 = Vector2.RIGHT
var move_velocity: Vector2 = Vector2.ZERO
var crouching: bool = false

var legs: Sprite2D
var torso: Sprite2D
var corpse: Sprite2D
var _walk_phase := 0.0
var _action_left := 0.0
var _is_dead := false


func _init() -> void:
	legs = _sheet_sprite(LEG_FRAMES)
	torso = _sheet_sprite(TORSO_FRAMES)
	corpse = Sprite2D.new()
	corpse.offset = Vector2(0, -6)
	corpse.visible = false
	add_child(legs)
	add_child(torso)
	add_child(corpse)


func _sheet_sprite(hframes: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.hframes = hframes
	s.vframes = DIRS
	s.offset = Vector2(0, -(FEET_Y - FRAME / 2))
	return s


static func _tex(file: String) -> Texture2D:
	var path := CHAR_DIR + file
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex_cache[path]


func set_variant(v: String) -> void:
	variant = v
	legs.texture = _tex("legs_%s.png" % v)
	corpse.texture = _tex("dead_%s.png" % v)
	_refresh_torso()


func set_weapon(key: String) -> void:
	weapon_key = key if key != "" else "unarmed"
	_refresh_torso()


func _refresh_torso() -> void:
	var t := _tex("torso_%s_%s.png" % [variant, weapon_key])
	if t == null:
		t = _tex("torso_%s_unarmed.png" % variant)
	torso.texture = t


## 0=E 부터 시계 방향 8방향 인덱스
static func dir_index(v: Vector2) -> int:
	return posmod(int(round(v.angle() / (PI / 4.0))), DIRS)


## 사격 반동·주먹·휘두르기 등 상체 동작 프레임을 잠깐 보여준다
func play_action(seconds: float = 0.12) -> void:
	_action_left = maxf(_action_left, seconds)


func _process(delta: float) -> void:
	if _is_dead:
		return
	_action_left = maxf(_action_left - delta, 0.0)
	var aim_i := dir_index(aim_dir)
	torso.frame = aim_i * TORSO_FRAMES + (1 if _action_left > 0.0 else 0)
	var speed := move_velocity.length()
	if speed > 10.0:
		# 뒷걸음질·옆걸음에서 다리가 상체와 반대로 꺾이지 않도록, 조준과 크게 어긋나면 조준 방향을 쓴다
		var leg_i := dir_index(move_velocity) if move_velocity.dot(aim_dir) > -0.3 * speed else aim_i
		_walk_phase = fmod(_walk_phase + delta * speed * WALK_FRAMES_PER_PX, 4.0)
		legs.frame = leg_i * LEG_FRAMES + 1 + int(_walk_phase)
	else:
		_walk_phase = 0.0
		legs.frame = aim_i * LEG_FRAMES
	scale.y = lerpf(scale.y, 0.82 if crouching else 1.0, minf(delta * 14.0, 1.0))


func die(direction: Vector2) -> void:
	_is_dead = true
	legs.visible = false
	torso.visible = false
	corpse.visible = true
	corpse.flip_h = direction.x < 0.0
	scale = Vector2.ONE
