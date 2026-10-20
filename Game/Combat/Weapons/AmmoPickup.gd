class_name AmmoPickup
extends Interactable
## 탄창 픽업. 해당 무기의 예비 탄약을 늘린다.

var weapon_id: StringName = &"pistol"
var rounds: int = 15


static func create(parent: Node, pos: Vector2, id: StringName = &"pistol", rounds_: int = 15) -> AmmoPickup:
	var p := AmmoPickup.new()
	p.weapon_id = id
	p.rounds = rounds_
	p.global_position = pos
	parent.add_child(p)
	return p


func _ready() -> void:
	super._ready()
	one_shot = true
	prompt = "탄창 획득 (+%d)" % rounds
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	add_child(shape)
	var s := Sprite2D.new()
	s.texture = preload("res://assets/sprites/magazine.png")
	add_child(s)
	z_index = -1
	add_to_group("pickups")


func _on_interact(actor: Node) -> void:
	if actor.has_method("add_ammo") and actor.add_ammo(weapon_id, rounds):
		Sfx.play("pickup", -6.0)
		queue_free()
	else:
		_used = false
