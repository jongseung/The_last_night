extends Node
## 헤드리스 스모크 테스트. 1장 정비소 시퀀스를 입력 시뮬레이션으로 끝까지 진행한 뒤
## 아레나를 잠깐 돌리고 종료한다. 실행:  godot --headless --path . tools/SmokeTest.tscn

const MAIN: PackedScene = preload("res://Game/Main.tscn")

var main: Node
var frame := 0
var phase := 0
var failures: Array[String] = []
var _phase_frames := 0


func _ready() -> void:
	main = MAIN.instantiate()
	add_child(main)
	GameState.start_chapter("CH01")


func _level() -> Level:
	return get_tree().get_first_node_in_group("level") as Level


func _garage() -> Garage:
	return _level() as Garage


func _fail(msg: String) -> void:
	failures.append(msg)
	push_error("SMOKE FAIL: " + msg)


func _process(_delta: float) -> void:
	frame += 1
	_phase_frames += 1
	if phase == 7:
		_arena_phase()
		return
	var g := _garage()
	if g == null or g.player == null:
		if frame > 300:
			_fail("garage never loaded")
			_finish()
		return
	if _phase_frames > 1500:
		_fail("phase %d timed out at step %d" % [phase, g.runner.step_index])
		_finish()
		return
	# 대화는 항상 자동 진행
	if g.dialogue.is_active() and frame % 3 == 0:
		g.dialogue._advance()
	if frame == 40:
		_check_nav(g)
	match phase:
		0:
			# 정비 완료 대기 → 정비소 상호작용을 직접 완료
			if g.runner.step_index >= 8 and not StoryFlags.has_flag("ch01_repair_done"):
				g.repair_station.interact(g.player)
			if StoryFlags.has_flag("ch01_repair_done"):
				_next("repair done")
		1:
			if StoryFlags.has_flag("ch01_envelope_received"):
				if g.ambient_modulate.color.r > 0.2:
					_fail("blackout did not darken ambient")
				_next("blackout + envelope")
		2:
			# 1차 습격: 근접으로 제압 (경직 → 제압 판정 확인)
			var e := _first_enemy(&"wave1")
			if e:
				_melee_kill(g, e)
			if g.living_enemies(&"wave1") == 0 and g.runner.step_index >= 24:
				_next("wave1 cleared by melee")
		3:
			var pick := get_tree().get_first_node_in_group("pickups") as Interactable
			if pick and pick is WeaponPickup:
				pick.interact(g.player)
			if StoryFlags.has_flag("ch01_pistol_taken"):
				if not g.player.gunplay.has_gun():
					_fail("pistol not equipped after pickup")
				_next("pistol taken")
		4:
			var e := _first_enemy(&"wave2")
			if e and _phase_frames % 4 == 0:
				_shoot_at(g, e)
			if g.living_enemies(&"wave2") == 0 and g.runner.step_index >= 32:
				_next("wave2 cleared by gunfire")
		5:
			if not g.rear_door.locked:
				# 3차 습격은 무시하고 탈출 (플레이어 무적 처리 후 순간이동)
				g.player.health.invulnerable = true
				g.player.global_position = g.rear_door.global_position + Vector2(0, 20)
				g.rear_door.interact(g.player)
				_next("rear door opened")
		6:
			if StoryFlags.has_flag("ch01_complete"):
				if not SaveManager.has_save(0):
					_fail("save not written at chapter end")
				_next("chapter 01 complete")
				GameState.start_chapter("ARENA")


func _arena_phase() -> void:
	var a := _level() as Arena
	if a == null or a.player == null:
		if _phase_frames > 300:
			_fail("arena never loaded")
			_finish()
		return
	if _phase_frames > 90 and _phase_frames % 4 == 0:
		var e := _first_enemy(&"round")
		if e:
			_shoot_at(a, e)
	if _phase_frames > 420:
		if a.living_enemies() >= 3 and a.round_index == 1:
			_fail("arena enemies never died under fire")
		_next("arena ran %d frames, round %d, enemies left %d" % [_phase_frames, a.round_index, a.living_enemies()])
		_finish()


func _check_nav(g: Level) -> void:
	var map := g.get_world_2d().navigation_map
	var routes := {
		"side door → office": [Vector2(776, 500), Vector2(716, 110)],
		"street → bay": [Vector2(364, 500), Vector2(330, 340)],
		"bay → storage": [Vector2(200, 300), Vector2(700, 400)],
	}
	for name in routes:
		var path := NavigationServer2D.map_get_path(map, routes[name][0], routes[name][1], true)
		if path.is_empty() or path[path.size() - 1].distance_to(routes[name][1]) > 16.0:
			_fail("nav route unreachable: %s (%d points)" % [name, path.size()])
		else:
			print("SMOKE OK nav: %s (%d points)" % [name, path.size()])


func _first_enemy(group: StringName) -> Enemy:
	for e in get_tree().get_nodes_in_group(group):
		if e is Enemy and not e.is_dead:
			return e
	return null


func _melee_kill(g: Level, e: Enemy) -> void:
	# 적 바로 뒤로 이동해 F
	g.player.global_position = e.global_position - e.aim_dir * 18.0
	g.player.face(e.global_position - g.player.global_position)
	var result := g.player.melee.perform(g.player.global_position, g.player.aim_dir, g.player.current_weapon())
	if result.get("kind") == "whiff":
		_fail("melee whiffed at point-blank range")


func _shoot_at(l: Level, e: Enemy) -> void:
	var dir := (e.global_position - l.player.global_position).normalized()
	l.player.global_position = e.global_position - dir * 60.0
	l.player.face(dir)
	if l.player.gunplay.slot.ammo <= 0:
		l.player.gunplay.try_reload()
	l.player.gunplay.try_fire(l.player.muzzle_position(), dir, true, 0.0)


func _next(msg: String) -> void:
	print("SMOKE OK [%d] frame %d: %s" % [phase, frame, msg])
	phase += 1
	_phase_frames = 0


func _finish() -> void:
	if failures.is_empty():
		print("SMOKE TEST PASSED (%d frames)" % frame)
	else:
		print("SMOKE TEST FAILED: ", failures)
	get_tree().quit(0 if failures.is_empty() else 1)
