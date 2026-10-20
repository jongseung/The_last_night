class_name Arena
extends Level
## 1단계 전투 프로토타입: 캐릭터 1명, 권총 1종, 적 3명, 엄폐물, 근접 제압.
## 검증 목표 — 이동·조준·사격·근접전이 하나의 조작으로 자연스럽게 이어지는가?
## 호텔 복도 느낌의 카펫 동선을 깔아 4장 「검은 장부」 의 실내 전투 감각을 미리 본다.

const P := "res://assets/sprites/props/"
const TEX_CART := preload(P + "tool_cart.png")
const TEX_DRUM := preload(P + "oil_drum.png")
const TEX_SHELF := preload(P + "shelf.png")
const TEX_CAR := preload(P + "car_sedan.png")
const TEX_DESK := preload(P + "office_desk.png")
const TEX_PLANT := preload(P + "plant.png")
const TEX_PILLAR := preload(P + "pillar.png")
const TEX_LAMP := preload(P + "work_lamp.png")
const TEX_WALL_OFFICE := preload(P + "wall_front_office.png")

var round_index := 0


func _init() -> void:
	bounds = Rect2(0, 0, 960, 576)
	player_spawn = Vector2(100, 300)
	ambient = Color(0.4, 0.42, 0.48)


func _build() -> void:
	var b := builder
	var F := LevelBuilder.FloorTile
	var K := LevelBuilder.PropKind
	b.paint_floor(Rect2i(0, 0, 20, 12), F.OFFICE_TILE)
	b.paint_floor(Rect2i(1, 5, 18, 2), F.CARPET)
	b.paint_floor(Rect2i(1, 4, 18, 1), F.CARPET_EDGE)
	b.paint_floor(Rect2i(11, 1, 8, 3), F.CONCRETE, F.CONCRETE_CRACKED, 0.2)
	b.add_room_walls(Rect2(0, 0, 960, 576), 12, [], TEX_WALL_OFFICE)
	b.add_wall(Rect2(468, 12, 12, 156), TEX_WALL_OFFICE)
	b.add_wall(Rect2(468, 408, 12, 156), TEX_WALL_OFFICE)
	b.add_wall(Rect2(180, 400, 180, 12), TEX_WALL_OFFICE)
	b.add_prop(Rect2(240, 250, 44, 30), TEX_CART, K.LOW_COVER)
	b.add_prop(Rect2(600, 150, 144, 52), TEX_CAR, K.LOW_COVER)
	b.add_prop(Rect2(620, 430, 24, 22), TEX_DRUM, K.LOW_COVER)
	b.add_prop(Rect2(650, 446, 24, 22), TEX_DRUM, K.LOW_COVER)
	b.add_prop(Rect2(860, 70, 40, 22), TEX_SHELF, K.HIGH_COVER)
	b.add_prop(Rect2(200, 470, 120, 36), TEX_DESK, K.LOW_COVER)
	b.add_prop(Rect2(560, 330, 24, 24), TEX_PILLAR, K.SOLID)
	b.add_prop(Rect2(30, 30, 22, 16), TEX_PLANT, K.LOW_COVER)
	b.add_prop(Rect2(900, 520, 22, 16), TEX_PLANT, K.LOW_COVER)
	for pos in [Vector2(200, 160), Vector2(700, 300), Vector2(300, 520), Vector2(820, 500)]:
		b.add_light(pos, Color(1.0, 0.8, 0.55), 1.05, 1.9)
		b.add_overhead(ViewSpace.lift(pos, 70.0), TEX_LAMP)
	b.add_light(Vector2(760, 90), Color(0.7, 0.95, 1.0), 0.8, 1.6)


func _after_build() -> void:
	Sfx.set_rain(-40.0)
	player.inventory.add_weapon(WeaponSlot.create(Weapons.pistol(), 15, 45), true)
	GameState.set_objective("전투 프로토타입 — 적 3명을 제압한다")
	GameState.show_hint("좌클릭 사격 · F 근접 · Space 회피 · Ctrl 낮은 자세 · 등 뒤에서 F = 제압", 8.0)
	all_enemies_dead.connect(_on_all_dead)
	_spawn_round()


func _spawn_round() -> void:
	round_index += 1
	var patrol: Array[Vector2] = [Vector2(760, 90), Vector2(860, 480)]
	spawn_enemy(Vector2(780, 300), &"gunman", &"round", false, patrol)
	spawn_enemy(Vector2(560, 80), &"gunman", &"round", false)
	spawn_enemy(Vector2(560, 500), &"thug", &"round", false)
	GameState.set_objective("라운드 %d — 적 %d명" % [round_index, living_enemies()])


func _on_all_dead(group: StringName) -> void:
	if group != &"round":
		return
	GameState.set_objective("클리어 — 3초 뒤 다음 라운드")
	AmmoPickup.create(builder.props, player.global_position + Vector2(36, 0), &"pistol", 15)
	await get_tree().create_timer(3.0).timeout
	if is_inside_tree() and not player.is_dead:
		_spawn_round()
