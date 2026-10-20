class_name CoverPoint
extends Node2D
## 엄폐 지점. LevelBuilder 가 엄폐물 각 면 바깥에 자동으로 생성한다.
## 적 AI 는 위협 위치로부터 보호되는 가장 가까운 지점을 고른다.

var prop_body: PhysicsBody2D
var is_low: bool = true
var occupant: Node = null


func _ready() -> void:
	add_to_group("cover_points")


func is_free(for_actor: Node) -> bool:
	return occupant == null or occupant == for_actor or not is_instance_valid(occupant)


## threat_pos 에서 이 지점으로 그은 선이 소유 엄폐물에 가로막히면 보호된다.
func protects_from(threat_pos: Vector2) -> bool:
	if prop_body == null or not is_inside_tree():
		return false
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(threat_pos, global_position, Layers.WORLD | Layers.LOW_COVER)
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	return not hit.is_empty() and hit.get("collider") == prop_body
