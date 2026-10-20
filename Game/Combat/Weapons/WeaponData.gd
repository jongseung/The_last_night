class_name WeaponData
extends Resource
## 무기 정의 리소스. .tres 로 저장해 데이터만으로 새 무기를 추가한다.

enum Kind { FISTS, PISTOL, MELEE }

@export var id: StringName = &"pistol"
@export var display_name: String = "권총"
@export var kind: Kind = Kind.PISTOL

@export_group("Gunplay")
@export var damage: float = 34.0
@export var fire_rate: float = 4.5            ## 초당 발사 수 (반자동이면 최대 연사 한계)
@export var automatic: bool = false
@export var magazine_size: int = 15
@export var default_reserve: int = 30
@export var reload_time: float = 1.3
@export var spread_base_deg: float = 1.5
@export var spread_recoil_add_deg: float = 3.0
@export var spread_max_deg: float = 12.0
@export var spread_recover_per_sec: float = 14.0
@export var precise_aim_multiplier: float = 0.35
@export var bullet_speed: float = 1500.0
@export var bullet_range: float = 520.0
@export var noise_radius: float = 420.0
@export var camera_kick: float = 0.35

@export_group("Melee")
@export var melee_damage: float = 22.0
@export var melee_range: float = 30.0
@export var melee_stagger: float = 0.55
@export var melee_knockback: float = 110.0
@export var melee_swing_time: float = 0.24

@export_group("Visuals")
@export var actor_texture: Texture2D
@export var pickup_texture: Texture2D
@export var muzzle_offset: Vector2 = Vector2(16, -1)


func is_gun() -> bool:
	return kind == Kind.PISTOL
