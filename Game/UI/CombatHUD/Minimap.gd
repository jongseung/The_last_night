class_name Minimap
extends Control
## 우상단 미니맵. 레벨의 벽·엄폐물 바닥면을 축소해 그리고, 플레이어(주황 화살표)와
## '드러난' 적(교전·수색 중이거나 가까운 적, 붉은 점)만 표시한다. 숨어 있는 적은 보이지 않는다.

const BG := Color(0.03, 0.035, 0.045, 0.82)
const BORDER := Color(0.55, 0.57, 0.6, 0.9)
const WALL := Color(0.62, 0.64, 0.66, 1.0)
const PROP := Color(0.36, 0.38, 0.42, 1.0)
const PLAYER := Color(1.0, 0.77, 0.43)
const ENEMY := Color(0.9, 0.18, 0.2)
const REVEAL_DISTANCE := 260.0

## Level 타입을 직접 쓰지 않는다 (Level 이 HUD 씬을 preload 하므로 순환 로드가 된다)
var level: Node2D


func _process(_delta: float) -> void:
	if level == null or not is_instance_valid(level):
		level = get_tree().get_first_node_in_group("level") as Node2D
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	draw_rect(Rect2(Vector2.ZERO, size), BORDER, false, 1.0)
	if level == null or not ("builder" in level) or level.builder == null:
		return
	var world: Rect2 = level.bounds
	var pad := 6.0
	var s := minf((size.x - pad * 2.0) / world.size.x, (size.y - pad * 2.0) / world.size.y)
	var origin := Vector2(pad, pad) + ((size - Vector2(pad, pad) * 2.0) - world.size * s) * 0.5 - world.position * s
	for r: Rect2 in level.builder.minimap_rects:
		var rr := Rect2(origin + r.position * s, (r.size * s).max(Vector2(1, 1)))
		var is_wall: bool = r.size.x <= 14.0 or r.size.y <= 14.0
		draw_rect(rr, WALL if is_wall else PROP)
	var player: Node2D = level.player
	if player and is_instance_valid(player):
		for e in get_tree().get_nodes_in_group("enemies"):
			var en := e as Enemy
			if en == null or en.is_dead:
				continue
			var revealed := en.ai_state == Enemy.AIState.COMBAT or en.ai_state == Enemy.AIState.SEARCH \
				or en.global_position.distance_to(player.global_position) < REVEAL_DISTANCE
			if revealed:
				draw_circle(origin + en.global_position * s, 2.2, ENEMY)
		var p := origin + player.global_position * s
		var d: Vector2 = player.aim_dir
		var pts := PackedVector2Array([p + d * 6.0, p + d.rotated(2.5) * 4.0, p + d.rotated(-2.5) * 4.0])
		draw_colored_polygon(pts, PLAYER)
