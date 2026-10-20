class_name CH01_Garage
extends RefCounted
## CHAPTER 01 · 프롤로그 「돌아온 망자」 — 남천동 정비소 습격 시퀀스.
##
##   START → 차량 정비 → 낯선 방문객 → "강도윤 씨?" → 정전 → 유리 파손 → 습격 → 전투 튜토리얼
##   → 뒷문 탈출 → StoryFlag garage_destroyed → Chapter 02 해금
##
## 레벨(Garage) 은 연출 함수만 제공하고, 순서와 대사는 모두 여기 데이터로 둔다.

const VISITOR := "방문객"
const DOYUN := "강도윤"


static func build(g: Garage) -> Array:
	return [
		{"type": "lock_player", "locked": true},
		{"type": "call", "callable": func() -> void: g.overlay.set_black(1.0)},
		{"type": "title", "small": "CHAPTER 01 · 프롤로그", "big": "돌아온 망자", "hold": 2.0},
		{"type": "await", "callable": func() -> void: await g.overlay.fade_from_black(1.6)},
		{"type": "dialogue", "lines": [
			["", "서림시 남천동. 2028년 10월, 밤 11시 40분."],
			[DOYUN, "……비가 그칠 생각을 안 하네."],
		]},
		{"type": "lock_player", "locked": false},
		{"type": "objective", "text": "리프트 위의 차량 정비를 마무리한다"},
		{"type": "hint", "text": "WASD 이동 · 차량 옆에서 E 를 길게 눌러 정비", "seconds": 8.0},
		{"type": "wait_signal", "object": g.repair_station, "signal": "interacted"},
		{"type": "set_flag", "flag": "ch01_repair_done"},
		{"type": "objective", "text": ""},
		{"type": "lock_player", "locked": true},
		{"type": "await", "callable": g.visitor_arrives},
		{"type": "dialogue", "lines": [
			[VISITOR, "강도윤 씨?"],
			[DOYUN, "영업 끝났습니다. 내일 오세요."],
			[VISITOR, "차 얘기를 하러 온 게 아닙니다. 오래 안 걸려요."],
			[DOYUN, "……."],
			[VISITOR, "5년 전, 서원구. 그날 밤 작전이요."],
			[VISITOR, "(봉투를 작업대에 올려놓는다) 사진 몇 장, 녹음 파일 하나. 보시면 압니다."],
			[DOYUN, "누가 보냈습니까."],
			[VISITOR, "그걸 알려드리려고 온 게 아니라서요. 이준혁 씨가 아직—"],
		]},
		{"type": "await", "callable": g.blackout},
		{"type": "dialogue", "lines": [
			[DOYUN, "……누구야."],
		]},
		{"type": "await", "callable": g.visitor_vanishes},
		{"type": "lock_player", "locked": false},
		{"type": "set_flag", "flag": "ch01_envelope_received"},
		{"type": "objective", "text": "살아남는다"},
		{"type": "hint", "text": "F 근접 공격 · 어둠 속에서 다가오는 적의 공격을 끊어라", "seconds": 6.0},
		{"type": "call", "callable": g.spawn_wave_1},
		{"type": "wait_group_dead", "group": &"wave1"},
		{"type": "await", "callable": g.reveal_pistol},
		{"type": "objective", "text": "작업대 서랍의 권총을 챙긴다"},
		{"type": "hint", "text": "E 권총 획득 · 좌클릭 사격 · 우클릭 정밀 조준 · R 재장전", "seconds": 8.0},
		{"type": "wait_flag", "flag": "ch01_pistol_taken"},
		{"type": "objective", "text": "습격을 막아낸다"},
		{"type": "call", "callable": g.spawn_wave_2},
		{"type": "wait", "seconds": 2.5},
		{"type": "hint", "text": "Ctrl 낮은 자세로 공구함·차량 뒤에 엄폐 · Space 회피 / 엄폐물 넘기", "seconds": 7.0},
		{"type": "wait_group_dead", "group": &"wave2"},
		{"type": "hint", "text": "E 쓰러진 적의 무기 회수 · Q 무기 전환", "seconds": 6.0},
		{"type": "wait", "seconds": 1.5},
		{"type": "await", "callable": g.cars_arrive},
		{"type": "dialogue", "lines": [
			[DOYUN, "(차 소리……. 한 팀이 아니었어.)"],
		]},
		{"type": "call", "callable": g.spawn_wave_3},
		{"type": "objective", "text": "뒷문으로 탈출한다 — 사무실을 지나 북쪽 문"},
		{"type": "call", "callable": g.unlock_rear_door},
		{"type": "wait_signal", "object": g.rear_door, "signal": "interacted"},
		{"type": "lock_player", "locked": true},
		{"type": "await", "callable": g.escape_sequence},
		{"type": "set_flag", "flag": "garage_destroyed"},
		{"type": "set_flag", "flag": "ch01_complete"},
		{"type": "set_flag", "flag": "ch02_unlocked"},
		{"type": "end_chapter"},
	]
