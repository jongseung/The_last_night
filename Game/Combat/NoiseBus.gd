extends Node
## 소음 전파 버스 (autoload: NoiseBus).
##
## 총성, 달리기 발소리, 유리 파손 등은 위치와 반경을 가진 소음 이벤트로 방송되고
## 적 AI 는 이를 듣고 경계 상태로 전환한다. 세계관 규칙 "폭력에는 결과가 따른다"
## 의 첫 단계: 소리는 반드시 누군가에게 들린다.

signal noise_emitted(position: Vector2, radius: float, source: Node, kind: String)

var gunshots_fired: int = 0


func emit_noise(position: Vector2, radius: float, source: Node = null, kind: String = "generic") -> void:
	if kind == "gunshot":
		gunshots_fired += 1
	noise_emitted.emit(position, radius, source, kind)
