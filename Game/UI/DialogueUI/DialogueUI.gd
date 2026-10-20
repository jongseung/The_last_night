extends CanvasLayer
## 대화 UI. 게임 카메라를 유지한 채 화면 하단에 인물 이름과 짧은 대사를 표시한다.
## 레터박스 바가 내려오며 시네마틱 모드임을 알린다. lines: [[이름, 대사], ...]

signal finished
signal line_shown(speaker: String, text: String)

const CHARS_PER_SEC := 38.0

var bar_top: ColorRect
var bar_bottom: ColorRect
var panel: PanelContainer
var name_label: Label
var text_label: Label
var cue_label: Label
var _lines: Array = []
var _index := 0
var _visible_chars := 0.0
var _active := false
var _typing := false


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	bar_top = ColorRect.new()
	bar_top.color = Color.BLACK
	bar_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar_top.offset_bottom = 0.0
	root.add_child(bar_top)
	bar_bottom = ColorRect.new()
	bar_bottom.color = Color.BLACK
	bar_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar_bottom.offset_top = 0.0
	root.add_child(bar_bottom)

	panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.03, 0.04, 0.82)
	style.border_color = Color(0.18, 0.43, 0.46, 0.8)
	style.border_width_top = 1
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = 60
	panel.offset_right = -60
	panel.offset_top = -64
	panel.offset_bottom = -14
	panel.visible = false
	root.add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	name_label = Label.new()
	name_label.add_theme_color_override("font_color", Color(1.0, 0.77, 0.43))
	vbox.add_child(name_label)
	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(0, 26)
	vbox.add_child(text_label)
	cue_label = Label.new()
	cue_label.text = "▼"
	cue_label.add_theme_color_override("font_color", Color(0.6, 0.62, 0.64))
	cue_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	cue_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	cue_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	cue_label.position = Vector2(-70, -26)
	cue_label.visible = false
	root.add_child(cue_label)


func is_active() -> bool:
	return _active


## 대사 묶음을 재생하고 끝날 때까지 기다린다.
func show_lines(lines: Array) -> void:
	_lines = lines
	_index = 0
	_active = true
	_set_letterbox(true)
	panel.visible = true
	_show_current()
	await finished


func _show_current() -> void:
	var line: Array = _lines[_index]
	name_label.text = str(line[0])
	text_label.text = str(line[1])
	text_label.visible_characters = 0
	_visible_chars = 0.0
	_typing = true
	cue_label.visible = false
	line_shown.emit(name_label.text, text_label.text)


func _process(delta: float) -> void:
	if not _active:
		return
	if _typing:
		_visible_chars += CHARS_PER_SEC * delta
		text_label.visible_characters = int(_visible_chars)
		if text_label.visible_characters >= text_label.text.length():
			text_label.visible_characters = -1
			_typing = false
			cue_label.visible = true
	if Input.is_action_just_pressed("dialogue_advance"):
		if _typing:
			text_label.visible_characters = -1
			_typing = false
			cue_label.visible = true
		else:
			_advance()


func _advance() -> void:
	_index += 1
	Sfx.play("ui", -16.0)
	if _index >= _lines.size():
		_close()
	else:
		_show_current()


func _close() -> void:
	_active = false
	panel.visible = false
	cue_label.visible = false
	_set_letterbox(false)
	finished.emit()


func _set_letterbox(on: bool) -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(bar_top, "offset_bottom", 22.0 if on else 0.0, 0.3)
	t.tween_property(bar_bottom, "offset_top", -22.0 if on else 0.0, 0.3)
