class_name ViewSpace
extends RefCounted
## 3/4 뷰 규약.
##
## 모든 게임 로직(충돌·탄도·시야·내비게이션)은 '바닥 평면' 좌표에서 계산한다.
## 액터의 원점은 발, 소품·벽의 원점은 바닥면의 아랫변이다. 그림만 높이만큼 위로 올려 그리고,
## 같은 z 의 노드끼리는 원점 y 로 정렬(y-sort)해 앞뒤가 맞는다.

const TILE := 48
const WALL_HEIGHT := 40      ## 벽 앞면 높이(px). wall_front.png 높이와 같다
const GUN_HEIGHT := 20       ## 총구·탄환·탄착이 그려지는 높이
const AIM_HEIGHT := 20       ## 마우스는 상체를 가리킨다고 보고 이만큼 내려 바닥 좌표로 바꾼다
const BODY_HEIGHT := 44      ## 캐릭터 그림 높이 (발 → 정수리)


## 바닥 좌표 p 를 높이 h 만큼 올린 화면 좌표
static func lift(p: Vector2, h: float = GUN_HEIGHT) -> Vector2:
	return p - Vector2(0.0, h)


## 화면에서 가리킨 지점(상체 높이)을 바닥 좌표로
static func ground_from_aim(screen_point: Vector2) -> Vector2:
	return screen_point + Vector2(0.0, AIM_HEIGHT)
