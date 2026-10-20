class_name Garage
extends Level
## CHAPTER 01 무대 — 남천동 정비소. 비 내리는 밤, 정전과 함께 습격이 시작된다.
##
## 레이아웃 (픽셀, 좌상단 원점):
##   메인 정비 베이 x12..620 y12..440 · 사무실 x620..800 y12..240 · 창고 x620..800 y240..440
##   거리(비) y440..560 · 셔터 개구부 x300..428 · 측문 x760..792 · 뒷문(사무실 북쪽) x700..732

const TEX := {
	"car": preload("res://assets/sprites/car_sedan.png"),
	"workbench": preload("res://assets/sprites/workbench.png"),
	"cart": preload("res://assets/sprites/tool_cart.png"),
	"drum": preload("res://assets/sprites/oil_drum.png"),
	"shelf": preload("res://assets/sprites/shelf.png"),
	"tires": preload("res://assets/sprites/tires.png"),
	"shutter": preload("res://assets/sprites/shutter.png"),
	"door": preload("res://assets/sprites/door.png"),
	"fuse": preload("res://assets/sprites/fuse_box.png"),
	"window": preload("res://assets/sprites/window.png"),
	"window_broken": preload("res://assets/sprites/window_broken.png"),
	"oil": preload("res://assets/sprites/floor_oilstain.png"),
	"lamp": preload("res://assets/sprites/lamp.png"),
	"envelope": preload("res://assets/sprites/envelope.png"),
	"rain": preload("res://assets/sprites/rain_drop.png"),
	"pistol_pick": preload("res://assets/sprites/pickup_pistol.png"),
}
const PISTOL: WeaponData = preload("res://Game/Combat/Weapons/Pistol.tres")
const CHAPTER_END_SCRIPT := preload("res://Game/UI/ChapterEnd/ChapterEnd.gd")

const AMBIENT_LIT := Color(0.58, 0.6, 0.64)
const AMBIENT_DARK := Color(0.13, 0.14, 0.17)

const SHUTTER_RECT := Rect2(300, 428, 128, 24)
const SIDE_DOOR_RECT := Rect2(756, 428, 40, 24)
const REAR_DOOR_RECT := Rect2(698, 0, 36, 24)
const OFFICE_DOOR_RECT := Rect2(608, 114, 24, 44)

var repair_station: RepairStation
var rear_door: Door
var runner: ChapterRunner
var ceiling_lamps: Array[PointLight2D] = []
var emergency_lamp: PointLight2D
var street_light: PointLight2D
var windows: Array[Sprite2D] = []
var shutter_sprite: Sprite2D
var shutter_body: StaticBody2D
var rain: CPUParticles2D
var visitor: NPC
var envelope: Sprite2D
var _flicker_on := false
var _lights_out := false


func _init() -> void:
	bounds = Rect2(0, 0, 800, 560)
	player_spawn = Vector2(330, 340)
	ambient = AMBIENT_LIT


func _build() -> void:
	add_to_group("level")
	var b := builder
	# 바닥
	b.add_floor(Rect2(0, 0, 800, 440))
	b.add_floor(Rect2(0, 440, 800, 120), LevelBuilder.TEX_FLOOR, Color(0.55, 0.58, 0.66))   # 젖은 거리
	for pos in [Vector2(200, 300), Vector2(420, 120), Vector2(520, 380), Vector2(150, 200)]:
		b.add_decal(pos, TEX["oil"], randf() * TAU, randf_range(1.5, 2.5))
	# 외벽 — 정비 베이 + 사무실/창고 를 둘러싸는 큰 사각형, 셔터·측문·뒷문 개구부
	# 뒷문은 탈출 연출용이라 벽은 그대로 두고 문 스프라이트·상호작용만 놓는다
	b.add_room_walls(Rect2(0, 0, 800, 440), 12, [SHUTTER_RECT, SIDE_DOOR_RECT])
	# 내벽: 베이 | 사무실·창고 경계 (x=608..620), 사무실 문 개구부
	for piece in b.split_wall(Rect2(608, 0, 12, 440), [OFFICE_DOOR_RECT]):
		b.add_wall(piece)
	b.add_wall(Rect2(620, 234, 180, 12))     # 사무실 / 창고 경계
	b.add_wall(Rect2(620, 234, 12, 12))
	# 거리 경계 (화면 밖으로 못 나가게)
	b.add_wall(Rect2(0, 548, 800, 12))
	b.add_wall(Rect2(0, 440, 12, 120))
	b.add_wall(Rect2(788, 440, 12, 120))

	# 창문 (벽 위 장식, 정전 때 깨진다)
	for x in [200.0, 380.0]:
		var w := Sprite2D.new()
		w.texture = TEX["window"]
		w.position = Vector2(x + 16, 6)
		w.scale = Vector2(1, 0.4)
		w.z_index = 3
		b.walls.add_child(w)
		windows.append(w)

	# 소품 / 엄폐물
	b.add_prop(Rect2(250, 190, 96, 48), TEX["car"], LevelBuilder.PropKind.LOW_COVER, "Car")
	b.add_prop(Rect2(60, 14, 96, 32), TEX["workbench"], LevelBuilder.PropKind.LOW_COVER, "Workbench")
	b.add_prop(Rect2(420, 300, 40, 28), TEX["cart"], LevelBuilder.PropKind.LOW_COVER, "ToolCart")
	b.add_prop(Rect2(140, 356, 24, 24), TEX["drum"], LevelBuilder.PropKind.LOW_COVER, "Drum1")
	b.add_prop(Rect2(168, 368, 24, 24), TEX["drum"], LevelBuilder.PropKind.LOW_COVER, "Drum2")
	b.add_prop(Rect2(14, 120, 32, 48), TEX["shelf"], LevelBuilder.PropKind.HIGH_COVER, "Shelf1")
	b.add_prop(Rect2(14, 210, 32, 48), TEX["shelf"], LevelBuilder.PropKind.HIGH_COVER, "Shelf2")
	b.add_prop(Rect2(560, 40, 32, 64), TEX["tires"], LevelBuilder.PropKind.HIGH_COVER, "Tires")
	b.add_prop(Rect2(460, 150, 24, 24), LevelBuilder.TEX_WALL, LevelBuilder.PropKind.SOLID, "Pillar")
	b.add_prop(Rect2(640, 40, 96, 32), TEX["workbench"], LevelBuilder.PropKind.LOW_COVER, "OfficeDesk")
	b.add_prop(Rect2(700, 300, 32, 48), TEX["shelf"], LevelBuilder.PropKind.HIGH_COVER, "StorageShelf")
	b.add_prop(Rect2(660, 380, 24, 24), TEX["drum"], LevelBuilder.PropKind.LOW_COVER, "Drum3")
	b.add_prop(Rect2(596, 290, 24, 24), TEX["fuse"], LevelBuilder.PropKind.DECOR, "FuseBox")

	# 셔터 (닫힘 → 습격 때 열림). 닫힌 동안은 벽.
	shutter_body = b.add_wall(SHUTTER_RECT, LevelBuilder.TEX_WALL, "ShutterBody", false)
	shutter_body.get_child(0).visible = false
	shutter_sprite = Sprite2D.new()
	shutter_sprite.texture = TEX["shutter"]
	shutter_sprite.position = SHUTTER_RECT.get_center()
	shutter_sprite.scale = Vector2(1, 1.5)
	shutter_sprite.z_index = 3
	b.walls.add_child(shutter_sprite)
	# 측문·뒷문 스프라이트
	for rect in [SIDE_DOOR_RECT, REAR_DOOR_RECT, OFFICE_DOOR_RECT]:
		var d := Sprite2D.new()
		d.texture = TEX["door"]
		d.position = rect.get_center()
		d.rotation = PI * 0.5 if rect.size.y > rect.size.x else 0.0
		d.z_index = 3
		d.modulate = Color(0.8, 0.8, 0.8)
		b.walls.add_child(d)

	# 조명: 천장 작업등 3개 (따뜻한 주황), 사무실 형광등 (청록), 거리 가로등
	for pos in [Vector2(160, 150), Vector2(330, 110), Vector2(500, 260)]:
		var l := b.add_light(pos, Color(1.0, 0.82, 0.6), 1.1, 1.6)
		ceiling_lamps.append(l)
		var fixture := Sprite2D.new()
		fixture.texture = TEX["lamp"]
		fixture.position = pos
		fixture.z_index = 6
		b.lights.add_child(fixture)
	var office := b.add_light(Vector2(710, 120), Color(0.7, 0.95, 1.0), 0.9, 1.2)
	ceiling_lamps.append(office)
	street_light = b.add_light(Vector2(364, 520), Color(1.0, 0.62, 0.3), 1.4, 2.2, "StreetLight")
	emergency_lamp = b.add_light(Vector2(600, 290), Color(1.0, 0.35, 0.2), 0.0, 1.3, "EmergencyLamp")

	# 비 (거리 구역)
	rain = CPUParticles2D.new()
	rain.amount = 260
	rain.lifetime = 0.9
	rain.texture = TEX["rain"]
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(420, 10)
	rain.position = Vector2(400, 430)
	rain.direction = Vector2(0.15, 1)
	rain.spread = 3.0
	rain.gravity = Vector2.ZERO
	rain.initial_velocity_min = 260.0
	rain.initial_velocity_max = 340.0
	rain.color = Color(0.7, 0.8, 0.9, 0.55)
	rain.z_index = 8
	add_child(rain)

	# 상호작용
	repair_station = RepairStation.new()
	repair_station.position = Vector2(298, 250)
	add_child(repair_station)
	rear_door = Door.new()
	rear_door.position = Vector2(716, 22)
	add_child(rear_door)


func _after_build() -> void:
	Sfx.set_rain(-14.0)
	camera.snap_to_target()
	runner = ChapterRunner.new()
	runner.name = "ChapterRunner"
	add_child(runner)
	runner.chapter_finished.connect(_on_chapter_finished)
	runner.run(self, CH01_Garage.build(self))


func _process(delta: float) -> void:
	super._process(delta)
	if _flicker_on and emergency_lamp:
		emergency_lamp.energy = 0.0 if randf() < 0.06 else randf_range(0.5, 0.9)
		if randf() < 0.01:
			Sfx.play("buzz", -20.0)


# -- 연출 함수 (CH01_Garage 스텝에서 호출) ---------------------------------------

func visitor_arrives() -> void:
	open_shutter(true)
	visitor = spawn_npc(Vector2(364, 520), null, "방문객")
	Sfx.play("door", -8.0)
	await visitor.walk_to(Vector2(364, 400))
	await visitor.walk_to(Vector2(330, 290))
	visitor.face_toward(player.global_position)
	player.face(visitor.global_position - player.global_position)
	await get_tree().create_timer(0.4).timeout
	envelope = Sprite2D.new()
	envelope.texture = TEX["envelope"]
	envelope.position = Vector2(345, 268)
	envelope.z_index = 1
	decals.add_child(envelope)


func blackout() -> void:
	_lights_out = true
	Sfx.play("power_down", -2.0)
	var t := create_tween().set_parallel(true)
	for l in ceiling_lamps:
		t.tween_property(l, "energy", 0.0, 0.25)
	t.tween_property(ambient_modulate, "color", AMBIENT_DARK, 0.4)
	await t.finished
	camera.add_trauma(0.4)
	await get_tree().create_timer(0.7).timeout
	break_windows()
	await get_tree().create_timer(0.5).timeout
	_flicker_on = true
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy:
			e.darkness = _current_darkness()


func break_windows() -> void:
	for w in windows:
		w.texture = TEX["window_broken"]
		Fx.glass_break(self, w.global_position + Vector2(0, 12), Vector2(0, 1))
	NoiseBus.emit_noise(Vector2(300, 20), 300.0, null, "glass")
	camera.add_trauma(0.5)


func visitor_vanishes() -> void:
	if visitor and is_instance_valid(visitor):
		visitor.speed = 160.0
		visitor.walk_to(Vector2(364, 470))
		await get_tree().create_timer(0.6).timeout
		await visitor.vanish(0.3)
		visitor = null


func open_shutter(silent: bool = false) -> void:
	if shutter_body:
		shutter_body.queue_free()
		shutter_body = null
	if shutter_sprite:
		var t := create_tween()
		t.tween_property(shutter_sprite, "scale:y", 0.25, 0.8)
		t.tween_property(shutter_sprite, "position:y", SHUTTER_RECT.position.y + 2.0, 0.0)
	if not silent:
		Sfx.play("door", -2.0, 0.6)
	# 셔터가 열리면 거리 가로등 빛이 안으로 든다
	if street_light:
		street_light.texture_scale = 2.8
		street_light.energy = 1.6


func spawn_wave_1() -> void:
	open_shutter()
	spawn_enemy(Vector2(364, 500), &"thug", &"wave1", true)


func reveal_pistol() -> void:
	var pickup := WeaponPickup.create(builder.props, Vector2(110, 62), PISTOL, 15, 30)
	pickup.prompt = "서랍 속 권총 획득"
	pickup.interacted.connect(func(_a: Node) -> void: StoryFlags.set_flag("ch01_pistol_taken", true))
	await get_tree().create_timer(0.2).timeout


func spawn_wave_2() -> void:
	spawn_enemy(Vector2(776, 500), &"gunman", &"wave2", true)
	get_tree().create_timer(1.8).timeout.connect(func() -> void:
		spawn_enemy(Vector2(330, 510), &"gunman", &"wave2", true))


func cars_arrive() -> void:
	Sfx.play("car_engine", -6.0)
	camera.add_trauma(0.2)
	await get_tree().create_timer(1.2).timeout
	AmmoPickup.create(builder.props, Vector2(440, 250), &"pistol", 15)


func spawn_wave_3() -> void:
	spawn_enemy(Vector2(380, 520), &"thug", &"wave3", true)
	spawn_enemy(Vector2(340, 520), &"gunman", &"wave3", true)
	get_tree().create_timer(4.0).timeout.connect(func() -> void:
		if not player.is_dead:
			spawn_enemy(Vector2(776, 500), &"gunman", &"wave3", true))


func unlock_rear_door() -> void:
	rear_door.locked = false
	GameState.show_hint("사무실 문(동쪽)을 지나 북쪽 뒷문으로", 5.0)


func escape_sequence() -> void:
	Sfx.play("door", -2.0)
	await overlay.fade_to_black(1.4)
	Sfx.set_rain(-30.0)
	await get_tree().create_timer(0.6).timeout


func _on_chapter_finished() -> void:
	SaveManager.save_game(0, {"from": "CH01"})
	GameState.in_combat = false
	var end_screen := Control.new()
	end_screen.set_script(CHAPTER_END_SCRIPT)
	end_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_screen.chapter_id = "CH01"
	end_screen.stats = runner.stats()
	var layer := CanvasLayer.new()
	layer.layer = 40
	layer.add_child(end_screen)
	add_child(layer)
	overlay.set_black(0.0)
