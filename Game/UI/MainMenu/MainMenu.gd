extends Control
## 메인 메뉴. 새 게임(1장) · 이어하기 · 전투 프로토타입 · 종료

var _box: VBoxContainer


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sfx.set_rain(-22.0)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.045, 0.055)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var stripe := ColorRect.new()
	stripe.color = Color(0.18, 0.43, 0.46, 0.25)
	stripe.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	stripe.offset_top = -60
	add_child(stripe)

	var title := Label.new()
	title.text = "마지막 밤"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.92, 0.92, 0.9))
	title.position = Vector2(60, 70)
	add_child(title)
	var sub := Label.new()
	sub.text = "THE LAST NIGHT  ·  A Korean Neo-Noir Action Thriller"
	sub.add_theme_color_override("font_color", Color(1.0, 0.77, 0.43))
	sub.position = Vector2(62, 110)
	add_child(sub)
	var quote := Label.new()
	quote.text = "\"돌아오지 말았어야 할 남자가, 마지막으로 도시의 밤을 걷는다.\""
	quote.add_theme_color_override("font_color", Color(0.6, 0.62, 0.64))
	quote.position = Vector2(62, 130)
	add_child(quote)

	_box = VBoxContainer.new()
	_box.position = Vector2(62, 180)
	_box.custom_minimum_size = Vector2(200, 0)
	_box.add_theme_constant_override("separation", 6)
	add_child(_box)
	_button("새 게임 — CHAPTER 01 돌아온 망자", func() -> void:
		StoryFlags.clear()
		GameState.start_chapter("CH01"))
	if SaveManager.has_save(0):
		_button("이어하기", func() -> void:
			var data := SaveManager.load_game(0)
			var next: String = data.get("chapter", "CH01")
			GameState.start_chapter(next if GameState.CHAPTERS.has(next) else "CH01"))
	_button("전투 프로토타입 (아레나)", func() -> void: GameState.start_chapter("ARENA"))
	_button("종료", func() -> void: get_tree().quit())

	var help := Label.new()
	help.text = "WASD 이동 · 마우스 조준 · 좌클릭 사격 · 우클릭 정밀조준 · F 근접 · Space 회피 · Shift 달리기 · R 재장전 · E 상호작용 · Q 무기전환 · Ctrl 낮은자세"
	help.add_theme_color_override("font_color", Color(0.5, 0.52, 0.54))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.position = Vector2(62, 300)
	help.size = Vector2(520, 40)
	add_child(help)
	var ver := Label.new()
	ver.text = "v%s · Godot 4.3 prototype" % ProjectSettings.get_setting("application/config/version", "0.0")
	ver.add_theme_color_override("font_color", Color(0.35, 0.36, 0.38))
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ver.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ver.position = Vector2(-160, -20)
	ver.size = Vector2(150, 14)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(ver)
	if _box.get_child_count() > 0:
		(_box.get_child(0) as Button).grab_focus()


func _button(text: String, on_pressed: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.pressed.connect(func() -> void:
		Sfx.play("ui", -10.0)
		on_pressed.call())
	_box.add_child(b)
