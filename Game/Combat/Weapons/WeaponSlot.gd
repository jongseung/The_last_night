class_name WeaponSlot
extends RefCounted
## 인벤토리 안의 무기 1개 인스턴스 (정의 + 현재 탄약 상태).

var data: WeaponData
var ammo: int = 0
var reserve: int = 0


static func create(weapon: WeaponData, ammo_in_mag: int = -1, reserve_ammo: int = -1) -> WeaponSlot:
	var s := WeaponSlot.new()
	s.data = weapon
	s.ammo = weapon.magazine_size if ammo_in_mag < 0 else ammo_in_mag
	s.reserve = weapon.default_reserve if reserve_ammo < 0 else reserve_ammo
	return s


func is_gun() -> bool:
	return data != null and data.is_gun()


func can_reload() -> bool:
	return is_gun() and reserve > 0 and ammo < data.magazine_size


func total_ammo() -> int:
	return ammo + reserve
