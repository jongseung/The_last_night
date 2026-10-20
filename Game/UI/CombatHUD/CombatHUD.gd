extends CanvasLayer
## 전투 HUD (960×540 기준).
##   좌상단 목표·알림 · 우상단 미니맵(M)·위협 · 우측 조작 안내(H)
##   좌하단 초상화·체력·스태미나·출혈 · 그 옆 무기 카드(아이콘·잔탄/예비탄·재장전) + 다음 무기(Q)
##   중앙 조준점 · 상호작용 대상 근처 E 안내
## 탐색 중에는 무기·체력 정보가 흐려지고, 교전·부상·무장 시 또렷해진다.

const COLOR_TEXT := Color(0.92, 0.92, 0.9)
const COLOR_DIM := Color(0.6, 0.62, 0.64)
const COLOR_ORANGE := Color(1.0, 0.77, 0.43)
const COLOR_RED := Color(0.85, 0.2, 0.22)
const COLOR_BLUE := Color(0.24, 0.55, 0.85)
const COLOR_TEAL := Color(0.32, 0.63, 0.66)
const PANEL_BG := Color(0.03, 0.035, 0.045, 0.82)
const PANEL_BORDER := Color(0.55, 0.57, 0.6, 0.9)
const UI := "res://assets/sprites/ui/"

const KEY_GUIDE := [
	["@mouse_left", "사격"],
	["@mouse_right", "정밀 조준"],
	["F", "근접 · 제압"],
	["Space", "회피 · 넘기"],
	["Shift", "달리기"],
	["Ctrl", "낮은 자세"],
	["R", "재장전"],
	["E", "무기 획득 · 상호작용"],
	["Q", "무기 전환"],
]

var objective_label: Label
var hint_label: Label
var threat_label: Label
var minimap: Minimap
var key_guide: VBoxContainer
var portrait: TextureRect
var health_bar: Control
var stamina_bar: Control
var bleed_label: Label
var status_group: Control
var weapon_card: Control
var weapon_icon: TextureRect
var weapon_name: Label
var ammo_label: Label
var reload_bar: Control
var next_card: Control
var next_icon: TextureRect
var crosshair: TextureRect
var prompt_label: Label
var hold_bar: Control
var _hint_t := 0.0
var _player: Player


func _ready() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# 좌상단: 목표 · 알림 -------------------------------------------------------
	objective_label = _label(root, COLOR_TEXT, 12)
	_place(objective_label, Control.PRESET_TOP_LEFT, 16, 12, 560, 30)
	hint_label = _label(root, COLOR_ORANGE, 11)
	_place(hint_label, Control.PRESET_TOP_LEFT, 16, 32, 660, 48)

	# 우상단: 미니맵 · 위협 -------------------------------------------------------
	minimap = Minimap.new()
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(minimap, Control.PRESET_TOP_RIGHT, -196, 12, -16, 124)
	root.add_child(minimap)
	threat_label = _label(root, COLOR_RED, 11)
	_place(threat_label, Control.PRESET_TOP_RIGHT, -316, 128, -16, 144)
	threat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# 우측: 조작 안내 ------------------------------------------------------------
	var guide_panel := _panel(root)
	_place(guide_panel, Control.PRESET_CENTER_RIGHT, -176, -92, -16, -92)   # 높이는 내용에 맞춰 자란다
	guide_panel.modulate.a = 0.85
	key_guide = VBoxContainer.new()
	key_guide.add_theme_constant_override("separation", 3)
	guide_panel.add_child(key_guide)
	for row in KEY_GUIDE:
		key_guide.add_child(_key_row(row[0], row[1]))
	key_guide.set_meta("panel", guide_panel)

	# 좌하단: 초상화 · 체력 · 스태미나 ----------------------------------------------
	status_group = Control.new()
	status_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(status_group, Control.PRESET_BOTTOM_LEFT, 16, -66, 196, -14)
	root.add_child(status_group)
	var frame := _panel(status_group)
	frame.position = Vector2.ZERO
	frame.size = Vector2(52, 52)
	portrait = TextureRect.new()
	portrait.texture = load(UI + "portrait_player.png")
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(40, 40)
	frame.add_child(portrait)
	health_bar = _bar(status_group, COLOR_RED)
	health_bar.position = Vector2(60, 12)
	health_bar.size = Vector2(118, 9)
	stamina_bar = _bar(status_group, COLOR_BLUE)
	stamina_bar.position = Vector2(60, 26)
	stamina_bar.size = Vector2(118, 6)
	bleed_label = _label(status_group, COLOR_RED, 11)
	bleed_label.position = Vector2(60, 34)
	bleed_label.text = "출혈"
	bleed_label.visible = false

	# 무기 카드 ---------------------------------------------------------------
	weapon_card = _panel(root)
	_place(weapon_card, Control.PRESET_BOTTOM_LEFT, 204, -66, 364, -14)
	var wbox := HBoxContainer.new()
	wbox.add_theme_constant_override("separation", 8)
	weapon_card.add_child(wbox)
	weapon_icon = TextureRect.new()
	weapon_icon.custom_minimum_size = Vector2(48, 28)
	weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	wbox.add_child(weapon_icon)
	var wtext := VBoxContainer.new()
	wtext.add_theme_constant_override("separation", 0)
	wbox.add_child(wtext)
	weapon_name = _label(wtext, COLOR_DIM, 11)
	ammo_label = _label(wtext, COLOR_TEXT, 12)
	reload_bar = _bar(root, COLOR_ORANGE)
	_place(reload_bar, Control.PRESET_BOTTOM_LEFT, 212, -20, 356, -17)
	reload_bar.visible = false
	next_card = _panel(root)
	_place(next_card, Control.PRESET_BOTTOM_LEFT, 370, -66, 422, -14)
	var nbox := VBoxContainer.new()
	nbox.add_theme_constant_override("separation", 0)
	next_card.add_child(nbox)
	var qlabel := _label(nbox, COLOR_DIM, 11)
	qlabel.text = "Q"
	next_icon = TextureRect.new()
	next_icon.custom_minimum_size = Vector2(36, 22)
	next_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	next_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	nbox.add_child(next_icon)

	# 조준점 · 상호작용 ---------------------------------------------------------
	crosshair = TextureRect.new()
	crosshair.texture = load(UI + "crosshair.png")
	crosshair.size = Vector2(32, 32)
	crosshair.pivot_offset = Vector2(16, 16)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.modulate = Color(1, 1, 1, 0.9)
	root.add_child(crosshair)
	prompt_label = _label(root, COLOR_TEXT, 11)
	prompt_label.visible = false
	hold_bar = _bar(root, COLOR_TEAL)
	hold_bar.size = Vector2(48, 3)
	hold_bar.visible = false

	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	GameState.objective_changed.connect(func(t: String) -> void: objective_label.text = t)
	GameState.hint_requested.connect(_on_hint)
	objective_label.text = GameState.current_objective
	if GameState.player:
		_bind_player(GameState.player)
	GameState.player_registered.connect(_bind_player)


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# -- 위젯 도우미 --------------------------------------------------------------

func _place(c: Control, preset: Control.LayoutPreset, left: float, top: float, right: float, bottom: float) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = left
	c.offset_top = top
	c.offset_right = right
	c.offset_bottom = bottom


func _label(parent: Control, color: Color, font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _panel(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(1)
	style.set_content_margin_all(6)
	p.add_theme_stylebox_override("panel", style)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


func _key_row(key: String, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var cap: Control
	if key.begins_with("@"):
		var icon := TextureRect.new()
		icon.texture = load(UI + key.substr(1) + ".png")
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		icon.custom_minimum_size = Vector2(40, 16)
		cap = icon
	else:
		var key_panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.11, 0.13, 1.0)
		style.border_color = Color(0.7, 0.72, 0.75)
		style.set_border_width_all(1)
		style.content_margin_left = 4
		style.content_margin_right = 4
		key_panel.add_theme_stylebox_override("panel", style)
		key_panel.custom_minimum_size = Vector2(40, 0)
		var kl := Label.new()
		kl.text = key
		kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kl.add_theme_font_size_override("font_size", 11)
		key_panel.add_child(kl)
		cap = key_panel
	row.add_child(cap)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", COLOR_TEXT)
	row.add_child(l)
	return row


## 얇은 막대 게이지. 메타 "fill" 이 채움 영역이며 set_bar() 로 비율을 바꾼다.
func _bar(parent: Control, color: Color) -> Control:
	var b := ColorRect.new()
	b.color = Color(0, 0, 0, 0.6)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	fill.color = color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(fill)
	b.set_meta("fill", fill)
	parent.add_child(b)
	return b


func set_bar(bar: Control, ratio: float) -> void:
	var fill: Control = bar.get_meta("fill")
	fill.anchor_right = clampf(ratio, 0.0, 1.0)
	fill.offset_right = 0.0


# -- 바인딩 -------------------------------------------------------------------

func _bind_player(p: Node) -> void:
	_player = p as Player
	if _player == null:
		return
	_player.health.health_changed.connect(func(c: float, m: float) -> void: set_bar(health_bar, c / m))
	_player.health.bleeding_changed.connect(func(b: bool) -> void: bleed_label.visible = b)
	_player.stamina_changed.connect(func(c: float, m: float) -> void: set_bar(stamina_bar, c / m))
	_player.interact_target_changed.connect(_on_interact_target)
	_player.hold_progress_changed.connect(func(r: float) -> void:
		hold_bar.visible = r > 0.0
		set_bar(hold_bar, r))
	set_bar(health_bar, _player.health.ratio())
	set_bar(stamina_bar, _player.stamina / Player.STAMINA_MAX)


func _on_hint(text: String, seconds: float) -> void:
	hint_label.text = text
	_hint_t = seconds


func _on_interact_target(target: Interactable) -> void:
	prompt_label.visible = target != null
	if target == null:
		hold_bar.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_minimap"):
		minimap.visible = not minimap.visible
	elif event.is_action_pressed("toggle_help"):
		var panel: Control = key_guide.get_meta("panel")
		panel.visible = not panel.visible


func _process(delta: float) -> void:
	crosshair.position = get_viewport().get_mouse_position() - Vector2(16, 16)
	if _hint_t > 0.0:
		_hint_t -= delta
		if _hint_t <= 0.0:
			hint_label.text = ""
	if _player == null or not is_instance_valid(_player):
		return
	var engaged := GameState.in_combat or _player.gunplay.has_gun() or _player.health.ratio() < 0.999 or _player.stamina < Player.STAMINA_MAX
	for c in [status_group, weapon_card, next_card]:
		c.modulate.a = move_toward(c.modulate.a, 1.0 if engaged else 0.45, delta * 3.0)
	var slot := _player.inventory.current()
	weapon_icon.texture = slot.data.hud_icon
	weapon_name.text = slot.data.display_name
	if slot.is_gun():
		ammo_label.text = "%d / %d" % [slot.ammo, slot.reserve]
		ammo_label.modulate = COLOR_RED if slot.ammo == 0 else COLOR_TEXT
	else:
		ammo_label.text = "F 근접"
		ammo_label.modulate = COLOR_DIM
	var inv := _player.inventory
	next_card.visible = inv.slots.size() > 1
	if next_card.visible:
		next_icon.texture = inv.slots[posmod(inv.current_index + 1, inv.slots.size())].data.hud_icon
	reload_bar.visible = _player.gunplay.reloading
	if reload_bar.visible:
		set_bar(reload_bar, _player.gunplay.reload_progress())
	var alerted := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and not e.is_dead and e.ai_state == Enemy.AIState.COMBAT:
			alerted += 1
	threat_label.text = "교전 중 · %d" % alerted if alerted > 0 else ""
	var spread := 0.0 if _player.precise_aim else 0.35 + _player.gunplay.spread_deg * 0.02
	crosshair.scale = Vector2.ONE * (0.22 if _player.precise_aim else spread)
	var target := _player.current_interactable
	if target and is_instance_valid(target):
		var screen := get_viewport().get_canvas_transform() * target.global_position
		prompt_label.text = "[E] " + target.get_prompt()
		prompt_label.position = screen + Vector2(-prompt_label.size.x * 0.5, 14)
		hold_bar.position = screen + Vector2(-24, 32)


func set_visible_hud(v: bool) -> void:
	visible = v
