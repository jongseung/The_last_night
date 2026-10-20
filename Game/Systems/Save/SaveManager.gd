extends Node
## 세이브/로드 (autoload: SaveManager).
##
## 챕터 단위 체크포인트 저장. 스토리 플래그와 현재 챕터, 인벤토리 요약을
## user://save_slot_N.json 에 기록한다.

const SAVE_PATH := "user://save_slot_%d.json"

signal saved(slot: int)
signal loaded(slot: int)


func save_game(slot: int = 0, extra: Dictionary = {}) -> bool:
	var data := {
		"version": 1,
		"chapter": GameState.current_chapter,
		"flags": StoryFlags.to_dict(),
		"extra": extra,
		"timestamp": Time.get_datetime_string_from_system(),
	}
	var file := FileAccess.open(SAVE_PATH % slot, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: cannot write slot %d" % slot)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	saved.emit(slot)
	return true


func has_save(slot: int = 0) -> bool:
	return FileAccess.file_exists(SAVE_PATH % slot)


func load_game(slot: int = 0) -> Dictionary:
	if not has_save(slot):
		return {}
	var file := FileAccess.open(SAVE_PATH % slot, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	StoryFlags.from_dict(parsed.get("flags", {}))
	loaded.emit(slot)
	return parsed
