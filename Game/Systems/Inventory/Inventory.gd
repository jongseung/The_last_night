class_name Inventory
extends RefCounted
## 액터 인벤토리. 슬롯 0 은 항상 맨손(Fists). Q 로 순환한다.

signal changed
signal current_changed(slot: WeaponSlot)

var slots: Array[WeaponSlot] = []
var current_index: int = 0


func _init() -> void:
	slots.append(WeaponSlot.create(Weapons.fists(), 0, 0))


func current() -> WeaponSlot:
	return slots[current_index]


func has_weapon(id: StringName) -> bool:
	for s in slots:
		if s.data.id == id:
			return true
	return false


func find(id: StringName) -> WeaponSlot:
	for s in slots:
		if s.data.id == id:
			return s
	return null


## 무기 추가. 같은 종류면 탄약을 예비탄으로 합산하고 true 를 돌려준다.
func add_weapon(slot: WeaponSlot, equip: bool = true) -> bool:
	var existing := find(slot.data.id)
	if existing:
		if not slot.is_gun():
			return false
		existing.reserve += slot.total_ammo()
		changed.emit()
		return true
	slots.append(slot)
	if equip:
		current_index = slots.size() - 1
		current_changed.emit(current())
	changed.emit()
	return true


func add_ammo(id: StringName, rounds: int) -> bool:
	var s := find(id)
	if s == null:
		return false
	s.reserve += rounds
	changed.emit()
	return true


func cycle(step: int = 1) -> WeaponSlot:
	if slots.size() <= 1:
		return current()
	current_index = posmod(current_index + step, slots.size())
	current_changed.emit(current())
	return current()


func best_gun() -> WeaponSlot:
	var best: WeaponSlot = null
	for s in slots:
		if s.is_gun() and s.total_ammo() > 0 and (best == null or s.total_ammo() > best.total_ammo()):
			best = s
	return best


func equip_index(i: int) -> void:
	if i >= 0 and i < slots.size():
		current_index = i
		current_changed.emit(current())
