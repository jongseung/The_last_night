extends Control
## 챕터 종료 화면. 결과 요약과 다음 챕터 안내를 보여준다.

var chapter_id: String = "CH01"
var stats: Dictionary = {}


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var small := Label.new()
	small.text = "CHAPTER %s 완료" % chapter_id.trim_prefix("CH")
	small.add_theme_color_override("font_color", Color(0.6, 0.62, 0.64))
	small.position = Vector2(80, 80)
	add_child(small)
	var big := Label.new()
	big.text = GameState.chapter_title(chapter_id)
	big.add_theme_font_size_override("font_size", 22)
	big.position = Vector2(80, 98)
	add_child(big)
	var lines := []
	lines.append("소요 시간  %s" % _fmt_time(stats.get("seconds", 0.0)))
	lines.append("처치  %d" % stats.get("kills", 0))
	lines.append("발사한 총성  %d  — 남천동 전체가 들었다" % stats.get("gunshots", 0))
	lines.append("피해  %d" % stats.get("damage_taken", 0))
	var y := 140
	for l in lines:
		var lab := Label.new()
		lab.text = l
		lab.position = Vector2(80, y)
		add_child(lab)
		y += 16
	var next_id: String = GameState.CHAPTERS.get(chapter_id, {}).get("next", "")
	var nxt := Label.new()
	nxt.text = "다음 — CHAPTER %s %s (제작 예정)" % [next_id.trim_prefix("CH"), GameState.chapter_title(next_id)] if next_id != "" else ""
	nxt.add_theme_color_override("font_color", Color(1.0, 0.77, 0.43))
	nxt.position = Vector2(80, y + 16)
	add_child(nxt)
	var flags := Label.new()
	flags.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flags.text = "스토리 플래그: " + ", ".join(StoryFlags.to_dict().keys())
	flags.add_theme_color_override("font_color", Color(0.4, 0.42, 0.44))
	flags.position = Vector2(80, y + 36)
	flags.custom_minimum_size = Vector2(480, 0)
	flags.size = Vector2(480, 30)
	add_child(flags)
	var b := Button.new()
	b.text = "메인 메뉴로"
	b.position = Vector2(80, y + 80)
	b.pressed.connect(func() -> void: GameState.go_to_main_menu())
	add_child(b)
	b.grab_focus()


func _fmt_time(sec: float) -> String:
	var m := int(sec) / 60
	var s := int(sec) % 60
	return "%02d:%02d" % [m, s]
