extends Node
## 전역 스토리 플래그 저장소 (autoload: StoryFlags).
##
## 챕터 진행, 확보한 증거, 보호한 인물 등 엔딩 분기에 영향을 주는 상태를
## 문자열 키로 관리한다. 모든 값은 SaveManager 가 그대로 직렬화한다.

signal flag_changed(flag: String, value: Variant)

var _flags: Dictionary = {}


func set_flag(flag: String, value: Variant = true) -> void:
	_flags[flag] = value
	flag_changed.emit(flag, value)


func get_flag(flag: String, default: Variant = false) -> Variant:
	return _flags.get(flag, default)


func has_flag(flag: String) -> bool:
	return _flags.has(flag) and bool(_flags[flag])


func clear() -> void:
	_flags.clear()


func to_dict() -> Dictionary:
	return _flags.duplicate(true)


func from_dict(data: Dictionary) -> void:
	_flags = data.duplicate(true)
	for key in _flags:
		flag_changed.emit(key, _flags[key])
