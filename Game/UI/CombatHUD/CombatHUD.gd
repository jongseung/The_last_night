extends CanvasLayer
## 전투 HUD. 네 모서리에 필요한 정보만 두고, 탐색 중에는 대부분 숨긴다.
##   좌상단 목표/알림 · 우상단 위협 · 좌하단 체력/출혈 · 우하단 무기/탄약 · 중앙 조준점 · 대상 근처 E 안내

const COLOR_TEXT := Color(0.92, 0.92, 0.9)
const COLOR_DIM := Color(0.6, 0.62, 0.64)
const COLOR_ORANGE := Color(1.0, 0.77, 0.43)
const COLOR_RED := Color(0.85, 0.2, 0.22)
const COLOR_TEAL := Color(0.32, 0.63, 0.66)

var objective_label: Label
var hint_label: Label
var threat_label: Label
var health_bar: ProgressBar
var bleed_label: Label
var weapon_label: Label
var ammo_label: Label
var reload_bar: ProgressBar
var crosshair: TextureRect
var prompt_label: Label
var hold_bar: ProgressBar
var combat_group: Array[Control] = []
var _hint_t := 0.0
var _player: Player


func _ready() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	objective_label = _label(root, Vector2(12, 10), COLOR_TEXT, 11)
	hint_label = _label(root, Vector2(12, 26), COLOR_ORANGE, 11)
	threat_label = _label(root, Vector2(0, 10), COLOR_RED, 11)
	threat_label.anchor_left = 1.0
	threat_label.anchor_right = 1.0
	threat_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	threat_label.position = Vector2(-12, 10)
	threat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	health_bar = _bar(root, Rect2(12, 338, 110, 8), COLOR_RED)
	health_bar.anchor_top = 1.0
	health_bar.anchor_bottom = 1.0
	health_bar.position = Vector2(12, -22)
	bleed_label = _label(root, Vector2(12, -36), COLOR_RED, 11)
	bleed_label.anchor_top = 1.0
	bleed_label.anchor_bottom = 1.0
	bleed_label.text = "출혈"
	bleed_label.visible = false

	weapon_label = _label(root, Vector2(0, 0), COLOR_DIM, 11)
	weapon_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	weapon_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	weapon_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	weapon_label.position = Vector2(-12, -36)
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_label = _label(root, Vector2(0, 0), COLOR_TEXT, 11)
	ammo_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ammo_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ammo_label.position = Vector2(-12, -22)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reload_bar = _bar(root, Rect2(0, 0, 60, 4), COLOR_ORANGE)
	reload_bar.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	reload_bar.position = Vector2(-72, -8)
	reload_bar.visible = false

	crosshair = TextureRect.new()
	crosshair.texture = preload("res://assets/sprites/crosshair.png")
	crosshair.size = Vector2(32, 32)
	crosshair.scale = Vector2(0.25, 0.25)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.modulate = Color(1, 1, 1, 0.9)
	root.add_child(crosshair)

	prompt_label = _label(root, Vector2.ZERO, COLOR_TEXT, 11)
	prompt_label.visible = false
	hold_bar = _bar(root, Rect2(0, 0, 40, 3), COLOR_TEAL)
	hold_bar.visible = false

	combat_group = [health_bar, weapon_label, ammo_label]
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

	GameState.objective_changed.connect(func(t: String) -> void: objective_label.text = t)
	GameState.hint_requested.connect(_on_hint)
	objective_label.text = GameState.current_objective
	if GameState.player:
		_bind_player(GameState.player)
	GameState.player_registered.connect(_bind_player)


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _label(parent: Control, pos: Vector2, color: Color, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _bar(parent: Control, rect: Rect2, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.position = rect.position
	b.size = rect.size
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fill)
	parent.add_child(b)
	return b


func _bind_player(p: Node) -> void:
	_player = p as Player
	if _player == null:
		return
	_player.health.health_changed.connect(func(c: float, m: float) -> void:
		health_bar.max_value = m
		health_bar.value = c)
	_player.health.bleeding_changed.connect(func(b: bool) -> void: bleed_label.visible = b)
	_player.interact_target_changed.connect(_on_interact_target)
	_player.hold_progress_changed.connect(func(r: float) -> void:
		hold_bar.visible = r > 0.0
		hold_bar.value = r * 100.0)
	health_bar.max_value = _player.health.max_health
	health_bar.value = _player.health.health


func _on_hint(text: String, seconds: float) -> void:
	hint_label.text = text
	_hint_t = seconds


func _on_interact_target(target: Interactable) -> void:
	prompt_label.visible = target != null
	if target == null:
		hold_bar.visible = false


func _process(delta: float) -> void:
	crosshair.position = get_viewport().get_mouse_position() - Vector2(4, 4)
	if _hint_t > 0.0:
		_hint_t -= delta
		if _hint_t <= 0.0:
			hint_label.text = ""
	var show_combat := GameState.in_combat or (_player and _player.gunplay.has_gun()) or (_player and _player.health.ratio() < 0.999)
	for c in combat_group:
		c.modulate.a = move_toward(c.modulate.a, 1.0 if show_combat else 0.0, delta * 3.0)
	if _player == null or not is_instance_valid(_player):
		return
	var slot := _player.inventory.current()
	weapon_label.text = slot.data.display_name
	if slot.is_gun():
		ammo_label.text = "%d / %d" % [slot.ammo, slot.reserve]
		ammo_label.modulate = COLOR_RED if slot.ammo == 0 else COLOR_TEXT
	else:
		ammo_label.text = "F 근접"
		ammo_label.modulate = COLOR_DIM
	reload_bar.visible = _player.gunplay.reloading
	if reload_bar.visible:
		reload_bar.value = _player.gunplay.reload_progress() * 100.0
	var alerted := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and not e.is_dead and e.ai_state == Enemy.AIState.COMBAT:
			alerted += 1
	threat_label.text = "교전 중 · %d" % alerted if alerted > 0 else ""
	crosshair.scale = Vector2.ONE * (0.18 if _player.precise_aim else 0.25 + _player.gunplay.spread_deg * 0.01)
	var target := _player.current_interactable
	if target and is_instance_valid(target):
		var screen := get_viewport().get_canvas_transform() * target.global_position
		prompt_label.text = "[E] " + target.get_prompt()
		prompt_label.position = screen + Vector2(-prompt_label.size.x * 0.5, 12)
		hold_bar.position = screen + Vector2(-20, 28)


func set_visible_hud(v: bool) -> void:
	visible = v
