class_name WeaponPickup
extends Interactable
## 바닥에 떨어진 무기. E 로 획득하면 인벤토리에 추가된다 (같은 무기면 탄약만 합산).

var slot: WeaponSlot
var _sprite: Sprite2D


static func create(parent: Node, pos: Vector2, data: WeaponData, ammo: int = -1, reserve: int = -1) -> WeaponPickup:
	var p := WeaponPickup.new()
	p.slot = WeaponSlot.create(data, ammo, reserve)
	p.global_position = pos
	p.rotation = randf_range(-0.6, 0.6)
	parent.add_child(p)
	return p


func _ready() -> void:
	super._ready()
	one_shot = true
	prompt = "%s 획득" % slot.data.display_name if slot else "획득"
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.position = Vector2(0, -4)
	_sprite.texture = slot.data.pickup_texture if slot and slot.data.pickup_texture else preload("res://assets/sprites/props/pickup_pistol.png")
	add_child(_sprite)
	z_index = -1
	add_to_group("pickups")


func get_prompt() -> String:
	if slot and slot.is_gun():
		return "%s 획득 (%d/%d)" % [slot.data.display_name, slot.ammo, slot.reserve]
	return prompt


func _on_interact(actor: Node) -> void:
	if actor.has_method("pick_up_weapon") and actor.pick_up_weapon(slot):
		Sfx.play("pickup", -6.0)
		queue_free()
	else:
		_used = false
