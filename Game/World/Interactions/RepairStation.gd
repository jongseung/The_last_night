class_name RepairStation
extends Interactable
## 1장 도입부 정비 작업. E 를 길게 누르면 완료된다.


func _init() -> void:
	prompt = "정비 마무리 (E 길게)"
	hold_time = 2.5
	one_shot = true


func _ready() -> void:
	super._ready()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(60, 40)
	shape.shape = box
	add_child(shape)
	hold_progress.connect(func(r: float) -> void:
		if r > 0.0 and fmod(r * 10.0, 2.0) < 0.2:
			Sfx.play("impact", -18.0, 0.6))


func _on_interact(_actor: Node) -> void:
	Sfx.play("pickup", -10.0, 0.8)
