extends Node
## 게임 루트. 메인 메뉴 ↔ 챕터 씬 전환만 담당한다.

const MAIN_MENU: PackedScene = preload("res://Game/UI/MainMenu/MainMenu.tscn")

var current: Node = null


func _ready() -> void:
	GameState.chapter_requested.connect(_load_chapter)
	GameState.main_menu_requested.connect(_show_menu)
	_show_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _show_menu() -> void:
	get_tree().paused = false
	GameState.in_combat = false
	GameState.set_objective("")
	_swap(MAIN_MENU.instantiate())


func _load_chapter(chapter_id: String) -> void:
	var info: Dictionary = GameState.CHAPTERS.get(chapter_id, {})
	if info.is_empty() or not GameState.chapter_playable(chapter_id):
		push_warning("Main: chapter %s is not playable yet" % chapter_id)
		_show_menu()
		return
	get_tree().paused = false
	GameState.set_objective("")
	var scene: PackedScene = load(info["scene"])
	_swap(scene.instantiate())


func _swap(node: Node) -> void:
	if current and is_instance_valid(current):
		current.queue_free()
		await current.tree_exited
	current = node
	add_child(node)
