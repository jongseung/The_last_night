extends "res://tools/SmokeTest.gd"
## 스크린샷 드라이버. SmokeTest 의 자동 진행을 그대로 쓰되 주요 장면마다 화면을 PNG 로 저장한다.
## 실행 (가상 화면 필요):
##   xvfb-run -s "-screen 0 1280x720x24" godot --path . tools/Screenshots.tscn --rendering-driver opengl3 -- --out=/절대/경로

var out_dir := "user://screenshots"
var _shot_index := 0
var _menu_done := false
var _dialogue_line_frames := 0
var _dialogue_shots := 0
var _fire_shot_pending := 0
var _fire_shots := 0
var _wanted := {}
var _hold := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = MAIN.instantiate()
	add_child(main)


func _process(delta: float) -> void:
	# 메인 메뉴를 먼저 찍고 챕터를 시작한다
	if not _menu_done:
		frame += 1
		if frame == 25:
			await _capture("00_main_menu")
			_menu_done = true
			frame = 0
			GameState.start_chapter("CH01")
		return
	# 챕터 종료 화면은 아레나로 넘어가기 전에 잠시 잡아 둔다
	if phase == 6 and StoryFlags.has_flag("ch01_complete"):
		_hold += 1
		if _hold == 30:
			_capture("chapter_end")
		if _hold < 40:
			return
	var g := _garage()
	if g and g.player:
		if g.dialogue.is_active():
			_dialogue_line_frames += 1
			if _dialogue_line_frames == 50 and _dialogue_shots < 3:
				_capture("dialogue_%d" % _dialogue_shots)
				_dialogue_shots += 1
			if _dialogue_line_frames >= 60:
				g.dialogue._advance()
				_dialogue_line_frames = 0
			frame += 1
			_phase_frames += 1
			return
		if not g.player.gunplay.fired.is_connected(_on_fired):
			g.player.gunplay.fired.connect(_on_fired)
		_once("garage_lit", frame > 60)
		_once("blackout_dark", StoryFlags.has_flag("ch01_envelope_received") and g.living_enemies() > 0 and phase == 2)
		_once("wave2_firefight", phase == 4 and _phase_frames > 90)
		_once("wave3_escape", phase == 5 and g.living_enemies(&"wave3") >= 2)
	var a := _level() as Arena
	if a and a.player:
		if not a.player.gunplay.fired.is_connected(_on_fired):
			a.player.gunplay.fired.connect(_on_fired)
		_once("arena", _phase_frames > 200)
	if _fire_shot_pending > 0:
		_fire_shot_pending -= 1
		if _fire_shot_pending == 0:
			_capture("muzzle_flash_%d" % _fire_shots)
			_fire_shots += 1
	super._process(delta)


func _on_fired(_slot: WeaponSlot) -> void:
	if _fire_shots < 2 and _fire_shot_pending == 0:
		_fire_shot_pending = 1


func _shoot_at(l: Level, e: Enemy) -> void:
	# 마우스를 적 쪽으로 옮겨 조준 방향이 스크린샷에 맞게 보이도록 한다
	var world := e.global_position
	var screen: Vector2 = get_viewport().get_screen_transform() * (get_viewport().get_canvas_transform() * world)
	Input.warp_mouse(screen)
	super._shoot_at(l, e)


func _once(name: String, condition: bool) -> void:
	if condition and not _wanted.has(name):
		_wanted[name] = true
		_capture(name)


func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%02d_%s.png" % [out_dir, _shot_index, name]
	_shot_index += 1
	var err := img.save_png(path)
	print("SHOT %s (%s)" % [path, error_string(err)])
