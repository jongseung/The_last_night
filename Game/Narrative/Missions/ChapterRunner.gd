class_name ChapterRunner
extends Node
## 데이터 중심 챕터 시퀀서. 챕터 스크립트가 돌려준 스텝 배열을 순서대로 실행한다.
##
## 스텝 종류:
##   {"type":"title", "small":"CHAPTER 01", "big":"돌아온 망자"}
##   {"type":"objective", "text":"..."}
##   {"type":"hint", "text":"...", "seconds":4.0}
##   {"type":"dialogue", "lines":[["이름","대사"], ...]}
##   {"type":"wait", "seconds":1.0}
##   {"type":"wait_signal", "object":Node, "signal":"name"}
##   {"type":"wait_flag", "flag":"name"}
##   {"type":"wait_group_dead", "group":"wave1"}
##   {"type":"call", "callable":Callable}             즉시 실행
##   {"type":"await", "callable":Callable}            끝날 때까지 대기 (코루틴)
##   {"type":"lock_player", "locked":true}
##   {"type":"set_flag", "flag":"name", "value":true}
##   {"type":"end_chapter"}
## 플레이어가 사망하면 시퀀스는 중단된다 (레벨이 재시작을 처리).

signal step_started(index: int, step: Dictionary)
signal chapter_finished

var level: Level
var steps: Array = []
var step_index: int = -1
var running := false
var elapsed := 0.0
var damage_taken := 0.0
var _gunshots_at_start := 0


func run(level_: Level, steps_: Array) -> void:
	level = level_
	steps = steps_
	running = true
	_gunshots_at_start = NoiseBus.gunshots_fired
	level.player.health.damaged.connect(func(info: DamageInfo) -> void: damage_taken += info.amount)
	for i in steps.size():
		if not running or level.player.is_dead or not is_inside_tree():
			running = false
			return
		step_index = i
		var step: Dictionary = steps[i]
		step_started.emit(i, step)
		await _execute(step)
	running = false


func _process(delta: float) -> void:
	if running:
		elapsed += delta


func stats() -> Dictionary:
	return {
		"seconds": elapsed,
		"kills": level.player.kills if level and level.player else 0,
		"gunshots": NoiseBus.gunshots_fired - _gunshots_at_start,
		"damage_taken": int(damage_taken),
	}


func _execute(step: Dictionary) -> void:
	match step.get("type", ""):
		"title":
			await level.overlay.show_title(step.get("small", ""), step.get("big", ""), step.get("hold", 2.2))
		"objective":
			GameState.set_objective(step.get("text", ""))
		"hint":
			GameState.show_hint(step.get("text", ""), step.get("seconds", 4.0))
		"dialogue":
			level.player.set_input_enabled(false)
			await level.dialogue.show_lines(step.get("lines", []))
			if not step.get("keep_locked", false):
				level.player.set_input_enabled(true)
		"wait":
			await get_tree().create_timer(step.get("seconds", 1.0)).timeout
		"wait_signal":
			var obj: Object = step.get("object")
			if obj:
				await Signal(obj, step.get("signal", "")) 
		"wait_flag":
			var flag: String = step.get("flag", "")
			while not StoryFlags.has_flag(flag):
				if level.player.is_dead or not is_inside_tree():
					return
				await get_tree().process_frame
		"wait_group_dead":
			var group: StringName = step.get("group", &"")
			while level.living_enemies(group) > 0:
				if level.player.is_dead or not is_inside_tree():
					return
				await get_tree().process_frame
		"call":
			var c: Callable = step.get("callable")
			c.call()
		"await":
			var c: Callable = step.get("callable")
			await c.call()
		"lock_player":
			level.player.set_input_enabled(not step.get("locked", true))
		"set_flag":
			StoryFlags.set_flag(step.get("flag", ""), step.get("value", true))
		"end_chapter":
			running = false
			chapter_finished.emit()
		_:
			push_warning("ChapterRunner: unknown step %s" % str(step))
