extends CanvasLayer
## 화면 전체 오버레이: 페이드, 챕터 타이틀 카드, 사망 화면, 일시정지 메뉴, 튜토리얼 안내.

var fade_rect: ColorRect
var title_big: Label
var title_small: Label
var center_box: VBoxContainer
var _death_shown := false


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade_rect)
	title_small = Label.new()
	title_small.set_anchors_preset(Control.PRESET_CENTER)
	title_small.offset_left = -160
	title_small.offset_right = 160
	title_small.offset_top = -34
	title_small.offset_bottom = -18
	title_small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_small.add_theme_color_override("font_color", Color(0.6, 0.62, 0.64))
	title_small.modulate.a = 0.0
	root.add_child(title_small)
	title_big = Label.new()
	title_big.set_anchors_preset(Control.PRESET_CENTER)
	title_big.offset_left = -200
	title_big.offset_right = 200
	title_big.offset_top = -14
	title_big.offset_bottom = 16
	title_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_big.add_theme_font_size_override("font_size", 22)
	title_big.add_theme_color_override("font_color", Color(0.92, 0.92, 0.9))
	title_big.modulate.a = 0.0
	root.add_child(title_big)
	center_box = VBoxContainer.new()
	center_box.set_anchors_preset(Control.PRESET_CENTER)
	center_box.offset_left = -90
	center_box.offset_right = 90
	center_box.offset_top = 24
	center_box.offset_bottom = 100
	center_box.alignment = BoxContainer.ALIGNMENT_CENTER
	center_box.visible = false
	root.add_child(center_box)


func fade_to_black(duration: float = 0.8) -> void:
	var t := create_tween()
	t.tween_property(fade_rect, "color:a", 1.0, duration)
	await t.finished


func fade_from_black(duration: float = 0.8) -> void:
	var t := create_tween()
	t.tween_property(fade_rect, "color:a", 0.0, duration)
	await t.finished


func set_black(a: float) -> void:
	fade_rect.color.a = a


## "CHAPTER 01" / "돌아온 망자" 카드. hold 초 동안 보여준 뒤 사라진다.
func show_title(small: String, big: String, hold: float = 2.2) -> void:
	title_small.text = small
	title_big.text = big
	var t := create_tween().set_parallel(true)
	t.tween_property(title_small, "modulate:a", 1.0, 0.6)
	t.tween_property(title_big, "modulate:a", 1.0, 0.9)
	await t.finished
	await get_tree().create_timer(hold).timeout
	var t2 := create_tween().set_parallel(true)
	t2.tween_property(title_small, "modulate:a", 0.0, 0.6)
	t2.tween_property(title_big, "modulate:a", 0.0, 0.6)
	await t2.finished


func show_death() -> void:
	if _death_shown:
		return
	_death_shown = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.play("heartbeat", -4.0)
	var t := create_tween()
	t.tween_property(fade_rect, "color:a", 0.75, 1.2)
	await t.finished
	title_small.text = "강도윤은 초인이 아니다"
	title_big.text = "사망"
	title_small.modulate.a = 1.0
	title_big.modulate.a = 1.0
	_clear_box()
	_button("다시 시도 (R)", func() -> void: _restart())
	_button("메인 메뉴", func() -> void: GameState.go_to_main_menu())
	center_box.visible = true


func show_pause() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	fade_rect.color.a = 0.6
	title_small.text = ""
	title_big.text = "일시정지"
	title_big.modulate.a = 1.0
	_clear_box()
	_button("계속", func() -> void: _resume())
	_button("메인 메뉴", func() -> void:
		get_tree().paused = false
		GameState.go_to_main_menu())
	center_box.visible = true


func hide_all() -> void:
	if not _death_shown:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	fade_rect.color.a = 0.0
	title_big.modulate.a = 0.0
	title_small.modulate.a = 0.0
	center_box.visible = false
	_clear_box()


func _process(_delta: float) -> void:
	if _death_shown and Input.is_action_just_pressed("reload"):
		_restart()


func _restart() -> void:
	var level := get_tree().get_first_node_in_group("level")
	if level and level.has_method("restart"):
		level.restart()


func _resume() -> void:
	var level := get_tree().get_first_node_in_group("level")
	if level and level.has_method("resume_from_pause"):
		level.resume_from_pause()


func _clear_box() -> void:
	for c in center_box.get_children():
		c.queue_free()


func _button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on_pressed)
	center_box.add_child(b)
	return b
