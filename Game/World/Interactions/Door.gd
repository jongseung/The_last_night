class_name Door
extends Interactable
## 문. locked 상태에서는 "잠김" 안내만 보여주고 열리지 않는다.

signal opened(actor: Node)

var locked: bool = true
var locked_prompt: String = "뒷문 — 잠김"
var open_prompt: String = "뒷문으로 나간다"


func _ready() -> void:
	super._ready()
	one_shot = true
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(40, 30)
	shape.shape = box
	add_child(shape)


func get_prompt() -> String:
	return locked_prompt if locked else open_prompt


func can_interact(actor: Node) -> bool:
	return super.can_interact(actor)


func interact(actor: Node) -> void:
	if locked:
		Sfx.play("click", -4.0, 0.6)
		GameState.show_hint("잠겨 있다. 지금은 열 수 없다.", 2.0)
		return
	super.interact(actor)


func _on_interact(actor: Node) -> void:
	Sfx.play("door", -4.0)
	opened.emit(actor)
