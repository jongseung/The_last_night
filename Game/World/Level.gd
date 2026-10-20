class_name Level
extends Node2D
## 모든 스테이지의 공통 뼈대. 플레이어·카메라·HUD·조명·컨테이너 노드를 준비하고
## 사망/일시정지/전투 상태 전환을 처리한다. 구체 레이아웃은 서브클래스의 _build() 가 만든다.
##
## 노드 구성 (코드로 생성):
##   Floor · Walls · Props · Decals · Actors(y-sort) · FX · Lights · NavRegion
##   CanvasModulate(ambient) · Camera · HUD(CanvasLayer)

const PLAYER_SCENE: PackedScene = preload("res://Game/Actors/Player/Player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://Game/Actors/Enemies/Enemy.tscn")
const NPC_SCENE: PackedScene = preload("res://Game/Actors/NPC/NPC.tscn")
const HUD_SCENE: PackedScene = preload("res://Game/UI/CombatHUD/CombatHUD.tscn")
const DIALOGUE_SCENE: PackedScene = preload("res://Game/UI/DialogueUI/DialogueUI.tscn")
const OVERLAY_SCENE: PackedScene = preload("res://Game/UI/Overlay/Overlay.tscn")

signal player_died
signal all_enemies_dead(group: StringName)

@export var bounds: Rect2 = Rect2(0, 0, 640, 360)
@export var player_spawn: Vector2 = Vector2(100, 100)
@export var ambient: Color = Color(0.5, 0.52, 0.56)

var builder: LevelBuilder
var player: Player
var camera: GameCamera
var hud: CanvasLayer
var dialogue: CanvasLayer
var overlay: CanvasLayer
var ambient_modulate: CanvasModulate
var actors: Node2D
var decals: Node2D
var fx: Node2D
var enemies_alive: int = 0
var _combat_cooldown := 0.0
var _paused := false


func _ready() -> void:
	y_sort_enabled = true
	builder = LevelBuilder.new(self)
	builder.set_bounds(bounds)
	decals = _make_container("Decals", -8)
	actors = _make_container("Actors", 0)
	actors.y_sort_enabled = true
	fx = _make_container("FX", 5)
	ambient_modulate = CanvasModulate.new()
	ambient_modulate.name = "Ambient"
	ambient_modulate.color = ambient
	add_child(ambient_modulate)

	_build()
	builder.build_navigation()

	player = PLAYER_SCENE.instantiate()
	player.position = player_spawn
	actors.add_child(player)
	player.health.died.connect(_on_player_died)

	camera = GameCamera.new()
	camera.name = "Camera"
	camera.target = player
	camera.set_bounds(bounds)
	add_child(camera)
	camera.snap_to_target()

	hud = HUD_SCENE.instantiate()
	add_child(hud)
	dialogue = DIALOGUE_SCENE.instantiate()
	add_child(dialogue)
	overlay = OVERLAY_SCENE.instantiate()
	add_child(overlay)

	NoiseBus.noise_emitted.connect(_on_noise)
	_after_build()


func _make_container(name: String, z: int) -> Node2D:
	var n := Node2D.new()
	n.name = name
	n.z_index = z
	add_child(n)
	return n


## 서브클래스: 지오메트리·조명·소품을 builder 로 생성한다.
func _build() -> void:
	pass


## 서브클래스: 플레이어/HUD 준비 후 호출 (챕터 스크립트 시작 등)
func _after_build() -> void:
	pass


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause") and player and not player.is_dead:
		_toggle_pause()
	_combat_cooldown = maxf(_combat_cooldown - delta, 0.0)
	var any_combat := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and not e.is_dead and e.ai_state == Enemy.AIState.COMBAT:
			any_combat = true
			break
	if any_combat:
		_combat_cooldown = 3.0
	GameState.in_combat = _combat_cooldown > 0.0


# -- 스폰 -------------------------------------------------------------------

func spawn_enemy(pos: Vector2, archetype: StringName, group: StringName = &"", alerted: bool = false, patrol: Array[Vector2] = []) -> Enemy:
	var e: Enemy = ENEMY_SCENE.instantiate()
	e.archetype = archetype
	e.position = pos
	e.spawn_alerted = alerted
	e.patrol_points = patrol
	e.darkness = _current_darkness()
	if group != &"":
		e.add_to_group(group)
	actors.add_child(e)
	e.face(Vector2.from_angle(randf() * TAU))
	enemies_alive += 1
	e.died.connect(_on_enemy_died.bind(group))
	return e


func spawn_npc(pos: Vector2, texture: Texture2D = null, display_name: String = "") -> NPC:
	var n: NPC = NPC_SCENE.instantiate()
	n.position = pos
	if display_name != "":
		n.display_name = display_name
	actors.add_child(n)
	if texture:
		n.body.texture = texture
	return n


func living_enemies(group: StringName = &"") -> int:
	var count := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and not e.is_dead and (group == &"" or e.is_in_group(group)):
			count += 1
	return count


func _on_enemy_died(_actor: Actor, _info: DamageInfo, group: StringName) -> void:
	enemies_alive = maxi(enemies_alive - 1, 0)
	if group != &"" and living_enemies(group) == 0:
		all_enemies_dead.emit(group)
	if living_enemies() == 0:
		all_enemies_dead.emit(&"")


func _current_darkness() -> float:
	var c := ambient_modulate.color
	return clampf((c.r + c.g + c.b) / 3.0 / 0.5, 0.35, 1.0)


## 환경 조명 전환. 적의 시야 거리도 함께 조정된다.
func set_ambient(color: Color, duration: float = 1.0) -> void:
	var t := create_tween()
	t.tween_property(ambient_modulate, "color", color, duration)
	await t.finished
	var d := _current_darkness()
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy:
			e.darkness = d


func _on_noise(_pos: Vector2, _radius: float, source: Node, kind: String) -> void:
	if kind == "gunshot" and source == player:
		_combat_cooldown = maxf(_combat_cooldown, 2.0)


# -- 사망 / 일시정지 ------------------------------------------------------------

func _on_player_died(_info: DamageInfo) -> void:
	player_died.emit()
	GameState.in_combat = false
	overlay.show_death()


func _toggle_pause() -> void:
	_paused = not _paused
	get_tree().paused = _paused
	if _paused:
		overlay.show_pause()
	else:
		overlay.hide_all()


func resume_from_pause() -> void:
	if _paused:
		_toggle_pause()


func restart() -> void:
	get_tree().paused = false
	GameState.in_combat = false
	GameState.start_chapter(GameState.current_chapter)
