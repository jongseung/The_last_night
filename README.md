# 마지막 밤 : THE LAST NIGHT

한국형 범죄 느와르 · 시네마틱 탑다운 액션 · 싱글플레이 스토리
**Godot 4.3** + Aseprite(예정)

> "돌아오지 말았어야 할 남자가, 마지막으로 도시의 밤을 걷는다."

전직 백야회 해결사 **강도윤**이 되어 서림시의 밤을 걷는다. 권총과 맨손 격투가 끊기지 않고 이어지는 **건푸 액션**, 그리고 5년 전 사건의 진실.

설계 문서는 [`docs/GDD.md`](docs/GDD.md), 1장 연출 흐름은 [`docs/CH01_GARAGE.md`](docs/CH01_GARAGE.md) 에 있다.

## 지금 플레이할 수 있는 것

| 메뉴 | 내용 | 제작 단계 |
| --- | --- | --- |
| 새 게임 — CHAPTER 01 돌아온 망자 | 비 내리는 남천동 정비소. 정비 → 방문객 → 정전 → 유리 파손 → 습격 → 뒷문 탈출. 전투 튜토리얼 포함 | 2단계 (프롤로그) |
| 전투 프로토타입 (아레나) | 권총 1종, 적 3명(총기 2·근접 1), 엄폐물, 라운드 반복 | 1단계 (전투 검증) |

그래픽은 전부 **코드로 생성한 자리표시 픽셀 스프라이트**이고(`tools/gen_placeholders.py`), 효과음은 **런타임 합성**(`Sfx` 오토로드)이다. 3단계(시각적 완성도)에서 Aseprite 8방향 애니메이션과 녹음 사운드로 교체한다.

## 실행

1. [Godot 4.3](https://godotengine.org/download) 을 설치한다.
2. 프로젝트 매니저에서 이 폴더의 `project.godot` 을 열고 ▶ 로 실행한다.

헤드리스 스모크 테스트(1장 전체 흐름 + 아레나를 입력 시뮬레이션으로 완주):

```bash
godot --headless --path . tools/SmokeTest.tscn
```

자리표시 스프라이트 재생성:

```bash
python3 tools/gen_placeholders.py   # Pillow 필요
```

## 조작

| 입력 | 기능 |
| --- | --- |
| WASD | 8방향 이동 |
| 마우스 | 자유 조준 · 상체 회전 |
| 좌클릭 | 사격 (맨손이면 근접 공격) |
| 우클릭 | 정밀 조준 (탄퍼짐 감소, 이동 느려짐, 카메라가 더 앞을 본다) |
| F | 근접 공격 / 상황별 제압 — 경직 중이거나 나를 못 본 적은 즉시 제압 |
| Space | 짧은 회피 스텝 · 낮은 엄폐물 앞에서는 넘기 |
| Shift | 달리기 (발소리가 적에게 들린다) |
| R | 재장전 |
| E | 무기 획득 / 상호작용 (정비처럼 길게 누르는 것도 있다) |
| Q | 무기 전환 |
| Ctrl | 낮은 자세 — 낮은 엄폐물 뒤에서는 총알을 막아준다 |
| Esc | 일시정지 |

## 전투 규칙 요약

- **체력은 회복되지 않고 총상은 출혈을 남긴다.** 출혈은 몇 초 뒤 스스로 멎지만 그 사이 체력이 깎인다.
- **낮은 엄폐물은 총알을 막지 않는다.** 대신 몸을 낮춘(Ctrl) 사람이 가까운 낮은 엄폐물 뒤에 있으면 엄폐물이 대신 맞는다. 서 있으면 노출된다.
- **적은 보고 듣는다.** 총성·달리기·유리 파손은 `NoiseBus` 로 방송되고 반경 안의 적이 경계한다. 정전이 되면 적의 시야도 짧아진다.
- **근접은 F 하나.** 거리·방향·상대 상태에 따라 타격 / 3연타 피니시 / 제압으로 바뀐다. 모든 동작은 0.5초 안에 끝나고 순간이동하지 않는다.
- **총기 적은 체력이 낮거나 재장전 중이면 엄폐 지점을 찾아 웅크렸다가 고개를 내민다.** 근접 적은 예비 동작(0.38초)이 있어 F 로 끊을 수 있다.

## 프로젝트 구조

```text
Game/
├── Main.tscn / Main.gd          메인 메뉴 ↔ 챕터 전환
├── Actors/
│   ├── Actor.gd                 체력·피격·경직·무기 장착·사망 (플레이어/적 공통)
│   ├── Player/                  강도윤 조작 (상태: NORMAL · DODGE · MELEE · DEAD)
│   ├── Enemies/                 AI (IDLE → SUSPICIOUS → COMBAT → SEARCH), gunman / thug
│   └── NPC/                     연출용 인물
├── Combat/
│   ├── Weapons/                 WeaponData 리소스 (Pistol · Pipe · Fists), 픽업
│   ├── Gunplay/                 Gunplay 컴포넌트, 레이캐스트 Bullet
│   ├── Melee/                   상황별 근접 해석기
│   ├── Damage/                  DamageInfo · Health · Hurtbox
│   ├── Cover/                   CoverPoint (엄폐물 각 면에 자동 생성)
│   ├── Effects/                 Fx — 총구 화염, 탄흔, 혈흔, 유리 파편, 조명
│   ├── Layers.gd                물리 레이어 상수
│   └── NoiseBus.gd              소음 전파 (autoload)
├── World/
│   ├── Level.gd                 스테이지 공통 뼈대 (플레이어·카메라·HUD·사망·일시정지)
│   ├── LevelBuilder.gd          사각형 데이터 → 벽·소품·엄폐 지점·조명·내비게이션
│   ├── Interactions/            Interactable · Door · RepairStation
│   └── Interiors/               Garage (CH01) · Arena (프로토타입)
├── Narrative/
│   ├── StoryFlags/              전역 플래그 (autoload)
│   ├── Missions/ChapterRunner   데이터 중심 시퀀서 (dialogue · wait_signal · spawn …)
│   ├── Chapters/CH01_Garage.gd  1장 스텝·대사 데이터
│   └── Dialogue/ Cutscenes/     (예약)
├── Systems/
│   ├── GameState.gd             런타임 상태·시그널 (autoload)
│   ├── Camera/GameCamera.gd     조준 방향 오프셋 + 흔들림
│   ├── Audio/Sfx.gd             런타임 합성 효과음 (autoload)
│   ├── Inventory/Inventory.gd   무기 슬롯
│   └── Save/SaveManager.gd      user://save_slot_N.json
└── UI/
    ├── CombatHUD/               네 모서리 HUD · 조준점 · E 안내 · 홀드 게이지
    ├── DialogueUI/              레터박스 + 이름/대사 타자 효과
    ├── Overlay/                 페이드 · 챕터 타이틀 · 사망 · 일시정지
    ├── MainMenu/  ChapterEnd/
    └── theme.tres               Galmuri 픽셀 폰트 테마
assets/
├── sprites/                     자리표시 PNG (tools/gen_placeholders.py 산출물)
└── fonts/                       Galmuri11 · Galmuri9 (SIL OFL 1.1)
tools/
├── gen_placeholders.py          스프라이트 생성기
└── SmokeTest.tscn/.gd           헤드리스 통합 테스트
docs/
├── GDD.md                       스토리 & 세계관 설계 문서 v1.0
└── CH01_GARAGE.md               1장 이벤트 흐름 · 튜토리얼 설계
```

### 새 챕터를 추가하려면

1. `Game/World/Interiors/<이름>/` 에 `Level` 을 상속한 스크립트를 만들고 `_build()` 에서 `builder` 로 지오메트리를 놓는다.
2. `Game/Narrative/Chapters/CHxx_*.gd` 에 `static func build(level) -> Array` 로 스텝 배열을 쓴다.
3. `GameState.CHAPTERS` 에 항목을 추가한다.

### 다음 단계

- [ ] 3단계: Aseprite 8방향 이동·조준·사격·근접 애니메이션 (`Body` Sprite2D 를 AnimatedSprite2D 로 교체)
- [ ] 정비소 타일셋·조명 정교화, 녹음 효과음, BGM
- [ ] 소품 원점을 바닥 기준으로 바꿔 y-sort 정밀화
- [ ] 2장 「익숙한 골목」 — 민간인 NPC, 소음 판단, 상점 실내
- [ ] 엔딩 분기용 증거·보호 인물 플래그 설계 (`StoryFlags`)
