extends Node
## 런타임 게임 상태 (autoload: GameState).
##
## 현재 플레이어 참조, 챕터 전환, 일시정지, 전투 상태 등 씬 사이에서 공유하는
## 정보를 보관한다. 씬 교체는 Main 이 담당하고 이 노드는 요청만 중계한다.

signal chapter_requested(chapter_id: String)
signal main_menu_requested
signal combat_state_changed(in_combat: bool)
signal objective_changed(text: String)
signal hint_requested(text: String, seconds: float)
signal player_registered(player: Node)

const CHAPTERS := {
	"CH01": {"title": "돌아온 망자", "scene": "res://Game/World/Interiors/Garage/Garage.tscn", "next": "CH02"},
	"CH02": {"title": "익숙한 골목", "scene": "", "next": "CH03"},   # 제작 예정
	"ARENA": {"title": "전투 프로토타입", "scene": "res://Game/World/Interiors/Arena/Arena.tscn", "next": ""},
}

var player: Node = null
var current_chapter: String = ""
var in_combat: bool = false:
	set(value):
		if in_combat == value:
			return
		in_combat = value
		combat_state_changed.emit(value)
var current_objective: String = "":
	set(value):
		current_objective = value
		objective_changed.emit(value)


func register_player(p: Node) -> void:
	player = p
	player_registered.emit(p)


func start_chapter(chapter_id: String) -> void:
	current_chapter = chapter_id
	chapter_requested.emit(chapter_id)


func go_to_main_menu() -> void:
	main_menu_requested.emit()


func set_objective(text: String) -> void:
	current_objective = text


func show_hint(text: String, seconds: float = 4.0) -> void:
	hint_requested.emit(text, seconds)


func chapter_title(chapter_id: String) -> String:
	return CHAPTERS.get(chapter_id, {}).get("title", chapter_id)


## 실제로 플레이 가능한(씬이 있는) 챕터인지
func chapter_playable(chapter_id: String) -> bool:
	return CHAPTERS.get(chapter_id, {}).get("scene", "") != ""
