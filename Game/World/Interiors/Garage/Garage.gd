class_name Garage
extends Level
## CHAPTER 01 무대 — 남천동 정비소. 비 내리는 밤, 정전과 함께 습격이 시작된다.
##
## 레이아웃 (바닥 좌표, 48px 타일, 좌상단 원점, 경계 1056×768)
##   정비 베이   x0–768,    y0–576   리프트 위 세단, 작업대, 공구함, 드럼통, 선반, 타이어, 기둥
##   사무실      x780–1056, y0–288   책상, 화분, 북쪽 뒷문(탈출)
##   창고        x780–1056, y300–576 선반, 드럼통. 베이와 창고 문으로 이어진다
##   거리(비)    y576–768             가로등, 적 진입
##   개구부: 셔터 x336–480 · 측문 x960–1008 (남쪽 벽) · 사무실 문 y120–176 · 창고 문 y420–476 (내벽 x768)

const P := "res://assets/sprites/props/"
const TEX := {
	"car": preload(P + "car_sedan.png"),
	"workbench": preload(P + "workbench.png"),
	"desk": preload(P + "office_desk.png"),
	"cart": preload(P + "tool_cart.png"),
	"drum": preload(P + "oil_drum.png"),
	"shelf": preload(P + "shelf.png"),
	"tires": preload(P + "tires.png"),
	"pillar": preload(P + "pillar.png"),
	"plant": preload(P + "plant.png"),
	"shutter_closed": preload(P + "shutter_closed.png"),
	"shutter_open": preload(P + "shutter_open.png"),
	"door": preload(P + "door_south.png"),
	"door_metal": preload(P + "door_metal.png"),
	"fuse": preload(P + "fuse_box.png"),
	"window": preload(P + "window.png"),
	"window_broken": preload(P + "window_broken.png"),
	"work_lamp": preload(P + "work_lamp.png"),
	"street_light": preload(P + "street_light.png"),
	"envelope": preload(P + "envelope.png"),
	"wall_office": preload(P + "wall_front_office.png"),
	"oil": preload("res://assets/sprites/fx/oil_stain.png"),
	"rain": preload("res://assets/sprites/fx/rain_drop.png"),
}
const CHAPTER_END_SCRIPT := preload("res://Game/UI/ChapterEnd/ChapterEnd.gd")

const AMBIENT_LIT := Color(0.56, 0.58, 0.63)
const AMBIENT_DARK := Color(0.2, 0.21, 0.28)   ## 정전: 어둡되 실루엣과 조준 방향은 읽혀야 한다

const BUILDING := Rect2(0, 0, 1056, 576)
const WALL := 12.0
const SHUTTER_RECT := Rect2(336, 564, 144, 12)
const SIDE_DOOR_RECT := Rect2(960, 564, 48, 12)
const OFFICE_DOOR_RECT := Rect2(768, 120, 12, 56)
const STORAGE_DOOR_RECT := Rect2(768, 420, 12, 56)
const REAR_DOOR_X := 936.0

const STREET_SPAWN := Vector2(408, 720)
const SIDE_SPAWN := Vector2(984, 700)

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


func _init() -> void:
	bounds = Rect2(0, 0, 1056, 768)
	player_spawn = Vector2(380, 336)
	ambient = AMBIENT_LIT


func _build() -> void:
	var b := builder
	# 바닥 ------------------------------------------------------------------
	var F := LevelBuilder.FloorTile
	b.paint_floor(Rect2i(0, 0, 16, 12), F.CONCRETE, F.CONCRETE_CRACKED, 0.12)
	b.paint_floor(Rect2i(6, 4, 4, 3), F.GRATING)                             # 리프트 아래 배수구
	b.paint_floor(Rect2i(16, 0, 6, 6), F.OFFICE_TILE)
	b.paint_floor(Rect2i(16, 6, 6, 6), F.CONCRETE_DARK, F.CONCRETE_CRACKED, 0.2)
	b.paint_floor(Rect2i(0, 12, 22, 4), F.WET_STREET)
	for pos in [Vector2(220, 320), Vector2(470, 160), Vector2(560, 470), Vector2(150, 230), Vector2(650, 300)]:
		b.add_decal(pos, TEX["oil"], randf() * TAU, randf_range(0.9, 1.4)).modulate.a = 0.7

	# 벽 ---------------------------------------------------------------------
	b.add_wall(Rect2(0, 0, 768, WALL))                                         # 베이 북쪽
	b.add_wall(Rect2(768, 0, 288, WALL), TEX["wall_office"])                  # 사무실 북쪽 (뒷문은 그림만)
	for piece in b.split_wall(Rect2(0, 564, 1056, WALL), [SHUTTER_RECT, SIDE_DOOR_RECT]):
		b.add_wall(piece)                                                      # 남쪽 (거리 쪽)
	b.add_wall(Rect2(0, WALL, WALL, 552))                                      # 서쪽
	b.add_wall(Rect2(1044, WALL, WALL, 552))                                   # 동쪽
	for piece in b.split_wall(Rect2(768, WALL, WALL, 552), [OFFICE_DOOR_RECT, STORAGE_DOOR_RECT]):
		b.add_wall(piece)                                                      # 내벽
	b.add_wall(Rect2(780, 288, 264, WALL), TEX["wall_office"])                # 사무실 | 창고
	# 거리 끝 보이지 않는 경계
	b.add_barrier(Rect2(0, 756, 1056, 12))
	b.add_barrier(Rect2(-12, 576, 12, 192))
	b.add_barrier(Rect2(1056, 576, 12, 192))

	# 벽 장식 (북쪽 벽 앞면) -------------------------------------------------
	for x in [250.0, 470.0]:
		windows.append(b.add_wall_decor(x, WALL, TEX["window"], 10))
	b.add_wall_decor(620, WALL, TEX["fuse"], 4)
	b.add_wall_decor(REAR_DOOR_X, WALL, TEX["door"], 0)                       # 뒷문 (탈출구)

	# 소품 / 엄폐물 ------------------------------------------------------------
	var K := LevelBuilder.PropKind
	b.add_prop(Rect2(300, 236, 144, 52), TEX["car"], K.LOW_COVER, "Car")
	b.add_prop(Rect2(72, 26, 120, 36), TEX["workbench"], K.LOW_COVER, "Workbench")
	b.add_prop(Rect2(540, 400, 44, 30), TEX["cart"], K.LOW_COVER, "ToolCart")
	b.add_prop(Rect2(170, 450, 24, 22), TEX["drum"], K.LOW_COVER, "Drum1")
	b.add_prop(Rect2(200, 468, 24, 22), TEX["drum"], K.LOW_COVER, "Drum2")
	b.add_prop(Rect2(16, 170, 40, 22), TEX["shelf"], K.HIGH_COVER, "Shelf1")
	b.add_prop(Rect2(16, 300, 40, 22), TEX["shelf"], K.HIGH_COVER, "Shelf2")
	b.add_prop(Rect2(690, 40, 40, 30), TEX["tires"], K.HIGH_COVER, "Tires")
	b.add_prop(Rect2(600, 200, 24, 24), TEX["pillar"], K.SOLID, "Pillar")
	b.add_prop(Rect2(840, 110, 120, 36), TEX["desk"], K.LOW_COVER, "OfficeDesk")
	b.add_prop(Rect2(1008, 30, 22, 16), TEX["plant"], K.LOW_COVER, "Plant")
	b.add_prop(Rect2(900, 370, 40, 22), TEX["shelf"], K.HIGH_COVER, "StorageShelf")
	b.add_prop(Rect2(820, 500, 24, 22), TEX["drum"], K.LOW_COVER, "Drum3")
	b.add_prop(Rect2(484, 716, 10, 8), TEX["street_light"], K.SOLID, "StreetPole")

	# 셔터: 닫힌 동안은 보이지 않는 벽 + 셔터 그림
	shutter_body = b.add_wall(SHUTTER_RECT, LevelBuilder.TEX_WALL_FRONT, "ShutterBody", false, false)
	var shutter_node := Node2D.new()
	shutter_node.position = Vector2(SHUTTER_RECT.get_center().x, SHUTTER_RECT.end.y + 0.5)
	shutter_sprite = Sprite2D.new()
	shutter_sprite.texture = TEX["shutter_closed"]
	shutter_sprite.centered = false
	shutter_sprite.offset = Vector2(-72, -52)
	shutter_node.add_child(shutter_sprite)
	b.props.add_child(shutter_node)

	# 조명 -------------------------------------------------------------------
	for pos in [Vector2(190, 170), Vector2(400, 150), Vector2(620, 340)]:
		ceiling_lamps.append(b.add_light(pos, Color(1.0, 0.8, 0.55), 1.15, 2.0))
		b.add_overhead(ViewSpace.lift(pos, 70.0), TEX["work_lamp"])
	ceiling_lamps.append(b.add_light(Vector2(900, 160), Color(0.7, 0.95, 1.0), 0.95, 1.6))
	street_light = b.add_light(Vector2(500, 690), Color(1.0, 0.62, 0.3), 1.5, 2.6, "StreetLight")
	emergency_lamp = b.add_light(Vector2(790, 448), Color(1.0, 0.3, 0.18), 0.0, 1.6, "EmergencyLamp")

	# 비 (거리 구역) ------------------------------------------------------------
	rain = CPUParticles2D.new()
	rain.amount = 320
	rain.lifetime = 0.7
	rain.texture = TEX["rain"]
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(540, 6)
	rain.position = Vector2(528, 548)
	rain.direction = Vector2(0.12, 1)
	rain.spread = 2.0
	rain.gravity = Vector2.ZERO
	rain.initial_velocity_min = 300.0
	rain.initial_velocity_max = 360.0
	rain.color = Color(0.7, 0.8, 0.92, 0.5)
	rain.z_index = 8
	add_child(rain)

	# 상호작용 ----------------------------------------------------------------
	repair_station = RepairStation.new()
	repair_station.position = Vector2(372, 312)
	add_child(repair_station)
	rear_door = Door.new()
	rear_door.position = Vector2(REAR_DOOR_X, 36)
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
		emergency_lamp.energy = 0.0 if randf() < 0.06 else randf_range(0.6, 1.0)
		if randf() < 0.01:
			Sfx.play("buzz", -20.0)


# -- 연출 함수 (CH01_Garage 스텝에서 호출) ---------------------------------------

func visitor_arrives() -> void:
	open_shutter(true)
	visitor = spawn_npc(Vector2(408, 740), "visitor", "방문객")
	Sfx.play("door", -8.0)
	await visitor.walk_to(Vector2(408, 600))
	await visitor.walk_to(Vector2(432, 392))
	visitor.face_toward(player.global_position)
	player.face(visitor.global_position - player.global_position)
	await get_tree().create_timer(0.4).timeout
	var holder := Node2D.new()
	holder.position = Vector2(330, 289)                 # 세단 보닛 위 (세단 바닥면 아랫변 기준)
	envelope = Sprite2D.new()
	envelope.texture = TEX["envelope"]
	envelope.offset = Vector2(0, -42)
	holder.add_child(envelope)
	builder.props.add_child(holder)


func blackout() -> void:
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
		var pos: Vector2 = w.get_parent().global_position + w.offset + Vector2(20, 12)
		Fx.glass_break(self, pos, Vector2(0, 1))
	NoiseBus.emit_noise(Vector2(360, 30), 400.0, null, "glass")
	camera.add_trauma(0.5)


func visitor_vanishes() -> void:
	if visitor and is_instance_valid(visitor):
		visitor.speed = 200.0
		visitor.walk_to(Vector2(408, 640))
		await get_tree().create_timer(0.6).timeout
		await visitor.vanish(0.3)
		visitor = null


func open_shutter(silent: bool = false) -> void:
	if shutter_body:
		shutter_body.queue_free()
		shutter_body = null
		shutter_sprite.texture = TEX["shutter_open"]
	if not silent:
		Sfx.play("door", -2.0, 0.6)
	if street_light:
		street_light.texture_scale = 3.2
		street_light.energy = 1.7


func spawn_wave_1() -> void:
	open_shutter()
	spawn_enemy(STREET_SPAWN, &"thug", &"wave1", true)


func reveal_pistol() -> void:
	var pickup := WeaponPickup.create(builder.props, Vector2(132, 84), Weapons.pistol(), 15, 30)
	pickup.prompt = "서랍 속 권총 획득"
	pickup.interacted.connect(func(_a: Node) -> void: StoryFlags.set_flag("ch01_pistol_taken", true))
	await get_tree().create_timer(0.2).timeout


func spawn_wave_2() -> void:
	spawn_enemy(SIDE_SPAWN, &"gunman", &"wave2", true)
	get_tree().create_timer(1.8).timeout.connect(func() -> void:
		spawn_enemy(STREET_SPAWN + Vector2(-30, 10), &"gunman", &"wave2", true))


func cars_arrive() -> void:
	Sfx.play("car_engine", -6.0)
	camera.add_trauma(0.2)
	await get_tree().create_timer(1.2).timeout
	AmmoPickup.create(builder.props, Vector2(500, 330), &"pistol", 15)


func spawn_wave_3() -> void:
	spawn_enemy(STREET_SPAWN + Vector2(20, 20), &"thug", &"wave3", true)
	spawn_enemy(STREET_SPAWN + Vector2(-30, 20), &"gunman", &"wave3", true)
	get_tree().create_timer(4.0).timeout.connect(func() -> void:
		if not player.is_dead:
			spawn_enemy(SIDE_SPAWN, &"gunman", &"wave3", true))


func unlock_rear_door() -> void:
	rear_door.locked = false
	GameState.show_hint("동쪽 사무실 문을 지나 북쪽 뒷문으로", 5.0)


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
