# CHAPTER 01 · 프롤로그 「돌아온 망자」 — 이벤트 흐름

장소: 남천동 정비소 · 2028년 10월 · 밤 11시 40분 · 비

코드: `Game/Narrative/Chapters/CH01_Garage.gd` (스텝 데이터) · `Game/World/Interiors/Garage/Garage.gd` (무대·연출 함수)

```text
CH01_GARAGE

START (페이드 인, 타이틀 카드)
  ↓
Player repairs vehicle            E 길게 — 이동·상호작용 학습
  ↓
Unknown visitor arrives           셔터가 열리고 방문객이 들어온다
  ↓
Dialogue: "강도윤 씨?"            봉투(사진·녹음) · "이준혁 씨가 아직—"
  ↓
Power outage                      작업등 소등 → 어둠 → 유리 파손 → 비상등 깜빡임
  ↓
Visitor vanishes                  방문객은 어둠 속으로 사라진다
  ↓
Wave 1: thug ×1 (셔터)            F 근접 — 예비 동작을 끊고 제압
  ↓
Pistol revealed (작업대 서랍)      E 획득 · 사격 · 정밀 조준 · 재장전
  ↓
Wave 2: gunman ×2 (측문·셔터)     Ctrl 엄폐 · Space 회피/넘기 · 무기 회수
  ↓
Cars arrive                        "한 팀이 아니었어" · 탄창 1개 등장
  ↓
Wave 3: thug + gunman + gunman     뒷문 해금 — 싸우거나 빠져나가거나
  ↓
Escape through rear exit           사무실 동쪽 문 → 북쪽 뒷문
  ↓
StoryFlag: garage_destroyed = true · ch01_complete · ch02_unlocked
  ↓
Chapter end (통계) → Chapter 02 안내
```

## 설정되는 스토리 플래그

| 플래그 | 시점 |
| --- | --- |
| `ch01_repair_done` | 정비 완료 |
| `ch01_envelope_received` | 정전 뒤 (봉투는 작업대 위에 남는다) |
| `ch01_pistol_taken` | 서랍 권총 획득 |
| `garage_destroyed`, `ch01_complete`, `ch02_unlocked` | 탈출 |

## 레이아웃 (픽셀, 좌상단 원점, 경계 800×560)

| 구역 | 범위 | 비고 |
| --- | --- | --- |
| 정비 베이 | x12–608, y12–428 | 리프트 위 세단(낮은 엄폐), 작업대, 공구함, 드럼통, 선반, 타이어, 기둥 |
| 사무실 | x620–788, y12–234 | 책상(낮은 엄폐), 뒷문(북쪽 벽) |
| 창고 | x620–788, y246–428 | 선반, 드럼통 |
| 거리 | y440–548 | 비, 가로등, 적 진입 지점 |
| 셔터 | x300–428 | 방문객 등장 때 열림 |
| 측문 | x756–796 | 2·3차 습격 진입 |
| 사무실 문 | y114–158 (x608) | 탈출 동선 |

## 튜토리얼 원칙

- 안내는 HUD 좌상단 한 줄(`hint`)로만 하고 플레이를 멈추지 않는다.
- 각 습격이 하나의 조작을 가르친다: 근접(1차) → 사격(권총) → 엄폐·회피(2차) → 무기 회수·판단(3차).
- 3차 습격은 반드시 전멸시킬 필요가 없다. 뒷문이 열려 있고 적이 쫓아온다.
