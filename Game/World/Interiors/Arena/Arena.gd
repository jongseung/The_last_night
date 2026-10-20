class_name Arena
extends Level
## 1단계 전투 프로토타입: 캐릭터 1명, 권총 1종, 적 3명, 엄폐물, 근접 제압.
## 검증 목표 — 이동·조준·사격·근접전이 하나의 조작으로 자연스럽게 이어지는가?

const PISTOL: WeaponData = preload("res://Game/Combat/Weapons/Pistol.tres")
const TEX_CART := preload("res://assets/sprites/tool_cart.png")
const TEX_DRUM := preload("res://assets/sprites/oil_drum.png")
const TEX_SHELF := preload("res://assets/sprites/shelf.png")
const TEX_CAR := preload("res://assets/sprites/car_sedan.png")

var round_index := 0


func _init() -> void:
	bounds = Rect2(0, 0, 640, 400)
	player_spawn = Vector2(80, 200)
	ambient = Color(0.42, 0.44, 0.5)


func _build() -> void:
	add_to_group("level")
	var b := builder
	b.add_floor(Rect2(0, 0, 640, 400))
	b.add_room_walls(Rect2(0, 0, 640, 400), 12)
	b.add_wall(Rect2(300, 12, 12, 110))
	b.add_wall(Rect2(300, 280, 12, 108))
	b.add_prop(Rect2(180, 180, 40, 28), TEX_CART, LevelBuilder.PropKind.LOW_COVER)
	b.add_prop(Rect2(400, 120, 96, 48), TEX_CAR, LevelBuilder.PropKind.LOW_COVER)
	b.add_prop(Rect2(420, 290, 24, 24), TEX_DRUM, LevelBuilder.PropKind.LOW_COVER)
	b.add_prop(Rect2(450, 300, 24, 24), TEX_DRUM, LevelBuilder.PropKind.LOW_COVER)
	b.add_prop(Rect2(540, 60, 32, 48), TEX_SHELF, LevelBuilder.PropKind.HIGH_COVER)
	b.add_prop(Rect2(120, 300, 32, 48), TEX_SHELF, LevelBuilder.PropKind.HIGH_COVER)
	b.add_light(Vector2(160, 120), Color(1.0, 0.82, 0.6), 1.0, 1.5)
	b.add_light(Vector2(480, 220), Color(0.7, 0.95, 1.0), 1.0, 1.5)
	b.add_light(Vector2(320, 340), Color(1.0, 0.62, 0.3), 0.8, 1.2)


func _after_build() -> void:
	Sfx.set_rain(-40.0)
	player.inventory.add_weapon(WeaponSlot.create(PISTOL, 15, 45), true)
	GameState.set_objective("전투 프로토타입 — 적 3명을 제압한다")
	GameState.show_hint("좌클릭 사격 · F 근접 · Space 회피 · Ctrl 낮은 자세 · 등 뒤에서 F = 제압", 8.0)
	all_enemies_dead.connect(_on_all_dead)
	_spawn_round()


func _spawn_round() -> void:
	round_index += 1
	var patrol: Array[Vector2] = [Vector2(500, 60), Vector2(560, 330)]
	spawn_enemy(Vector2(520, 200), &"gunman", &"round", false, patrol)
	spawn_enemy(Vector2(380, 60), &"gunman", &"round", false)
	spawn_enemy(Vector2(360, 340), &"thug", &"round", false)
	GameState.set_objective("라운드 %d — 적 %d명" % [round_index, living_enemies()])


func _on_all_dead(group: StringName) -> void:
	if group != &"round":
		return
	GameState.set_objective("클리어 — 3초 뒤 다음 라운드")
	AmmoPickup.create(builder.props, player.global_position + Vector2(30, 0), &"pistol", 15)
	await get_tree().create_timer(3.0).timeout
	if is_inside_tree() and not player.is_dead:
		_spawn_round()
