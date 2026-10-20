class_name Gunplay
extends Node2D
## 사격 컴포넌트. 액터의 자식으로 두고 현재 WeaponSlot 을 받아 발사·재장전·탄퍼짐을 처리한다.
## 액터가 조준 방향과 총구 위치를 제공하면 Bullet 을 생성하고 소음·연출을 방송한다.

signal fired(slot: WeaponSlot)
signal reload_started(slot: WeaponSlot)
signal reload_finished(slot: WeaponSlot)
signal ammo_changed(slot: WeaponSlot)
signal dry_fired

@export var team: StringName = &"player"

var slot: WeaponSlot = null
var spread_deg: float = 0.0
var reloading: bool = false
var _cooldown: float = 0.0
var _reload_left: float = 0.0
var _actor: Node


func _ready() -> void:
	_actor = get_parent()


func set_slot(new_slot: WeaponSlot) -> void:
	if reloading:
		cancel_reload()
	slot = new_slot
	spread_deg = 0.0
	ammo_changed.emit(slot)


func has_gun() -> bool:
	return slot != null and slot.is_gun()


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if slot and slot.data:
		spread_deg = maxf(spread_deg - slot.data.spread_recover_per_sec * delta, 0.0)
	if reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_finish_reload()


func can_fire() -> bool:
	return has_gun() and not reloading and _cooldown <= 0.0


## 발사 시도. precise 가 true 면 정밀 조준 (탄퍼짐 감소).
func try_fire(muzzle_pos: Vector2, aim_dir: Vector2, precise: bool = false, accuracy_penalty_deg: float = 0.0) -> bool:
	if not has_gun():
		return false
	if reloading or _cooldown > 0.0:
		return false
	var data := slot.data
	if slot.ammo <= 0:
		_cooldown = 0.25
		dry_fired.emit()
		Sfx.play("click", -6.0)
		return false
	slot.ammo -= 1
	_cooldown = 1.0 / data.fire_rate
	var total_spread := data.spread_base_deg + spread_deg + accuracy_penalty_deg
	if precise:
		total_spread *= data.precise_aim_multiplier
	var angle := aim_dir.angle() + deg_to_rad(randf_range(-total_spread, total_spread))
	var dir := Vector2.from_angle(angle)
	var level: Node = get_tree().get_first_node_in_group("level")
	Bullet.spawn(level if level else get_tree().current_scene, muzzle_pos, dir, data, team, _actor)
	spread_deg = minf(spread_deg + data.spread_recoil_add_deg, data.spread_max_deg)
	Fx.muzzle_flash(self, muzzle_pos, dir)
	Sfx.play("gunshot", 0.0 if team == &"player" else -5.0, randf_range(0.92, 1.08))
	NoiseBus.emit_noise(muzzle_pos, data.noise_radius, _actor, "gunshot")
	fired.emit(slot)
	ammo_changed.emit(slot)
	return true


func try_reload() -> bool:
	if not has_gun() or reloading or not slot.can_reload():
		return false
	reloading = true
	_reload_left = slot.data.reload_time
	Sfx.play("reload", -8.0)
	reload_started.emit(slot)
	return true


func cancel_reload() -> void:
	reloading = false
	_reload_left = 0.0


func _finish_reload() -> void:
	reloading = false
	var need := slot.data.magazine_size - slot.ammo
	var take := mini(need, slot.reserve)
	slot.ammo += take
	slot.reserve -= take
	reload_finished.emit(slot)
	ammo_changed.emit(slot)


func reload_progress() -> float:
	if not reloading or slot == null:
		return 0.0
	return 1.0 - _reload_left / slot.data.reload_time
