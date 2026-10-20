class_name Layers
extends RefCounted
## project.godot 의 2D 물리 레이어 비트. 이름으로 참조해 매직 넘버를 피한다.

const WORLD := 1 << 0
const PLAYER := 1 << 1
const ENEMY := 1 << 2
const LOW_COVER := 1 << 3
const PLAYER_HURTBOX := 1 << 4
const ENEMY_HURTBOX := 1 << 5
const INTERACTABLE := 1 << 6
const NPC := 1 << 7
const VISION_BLOCKER := 1 << 8


static func hurtbox_for_team(team: StringName) -> int:
	return PLAYER_HURTBOX if team == &"player" else ENEMY_HURTBOX


static func hurtbox_against_team(team: StringName) -> int:
	## 내가 team 일 때 맞혀야 하는 상대 피격 레이어
	return ENEMY_HURTBOX if team == &"player" else PLAYER_HURTBOX
