class_name Weapons
extends RefCounted
## 무기 리소스 조회. WeaponData .tres 는 const preload 하지 않고 여기서 실행 시점에 load 한다.
##
## 이유: 스크립트 컴파일 도중 const preload 로 읽힌 .tres 는 아직 컴파일 중인 WeaponData 스크립트에
## 묶일 수 있고, 그러면 `weapon: WeaponData` 타입 인자 검사에서 실패한다 (Godot 4.3).
## 런타임 load() 는 캐시된 동일 리소스를 돌려주므로 비용은 없다.

const DIR := "res://Game/Combat/Weapons/"


static func get_data(id: StringName) -> WeaponData:
	match id:
		&"pistol":
			return load(DIR + "Pistol.tres") as WeaponData
		&"pipe":
			return load(DIR + "Pipe.tres") as WeaponData
		_:
			return load(DIR + "Fists.tres") as WeaponData


static func pistol() -> WeaponData:
	return get_data(&"pistol")


static func pipe() -> WeaponData:
	return get_data(&"pipe")


static func fists() -> WeaponData:
	return get_data(&"fists")
