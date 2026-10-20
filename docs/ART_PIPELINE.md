# 아트 파이프라인 — Aseprite → Godot

엔진은 **Godot 4.3**, 최종 아트는 **Aseprite** 로 만든다.

지금 `assets/` 의 PNG 는 `tools/gen_placeholders.py` 가 그린 **자리표시(프로그래머 아트)** 다. 그림 품질이 아니라 **규격**을 확정하려고 만든 것이고, Aseprite 로 같은 규격의 PNG 를 내보내 같은 경로에 덮어쓰면 **코드 수정 없이** 게임에 반영된다.

```text
art/*.aseprite  ──(tools/export_aseprite.sh)──▶  assets/sprites/**/*.png  ──▶  Godot 가 자동 임포트
```

## 공통 규칙

| 항목 | 값 |
| --- | --- |
| 기본 해상도 | 960×540 (전체 화면 1920×1080 에서 정확히 2배) |
| 바닥 타일 | 48×48 px |
| 시점 | 3/4 탑다운. 바닥면은 위에서, 벽·소품은 남쪽 면(앞면)이 보인다 |
| 벽 높이 | 앞면 40 px (`ViewSpace.WALL_HEIGHT`) |
| 팔레트 | 먹색 · 콘크리트 회색 · 차가운 청록 · 가로등 주황 (GDD 1장) |
| 외곽선 | 어두운 1px 외곽선 권장 (어두운 배경에서 실루엣 확보) |
| 필터 | Nearest (프로젝트 기본값). 안티앨리어싱 금지 |

## 캐릭터 — 다리/상체 분리 8방향

상체는 **조준 방향**, 다리는 **이동 방향**을 따라가므로 두 시트로 나눈다 (`Game/Actors/CharacterVisual.gd`).

| 파일 | 셀 | 열 | 행 |
| --- | --- | --- | --- |
| `assets/sprites/chars/legs_<variant>.png` | 48×48 | 5 (0 정지, 1–4 걷기) | 8 방향 |
| `assets/sprites/chars/torso_<variant>_<weapon>.png` | 48×48 | 2 (0 기본, 1 동작: 반동·주먹·휘두르기) | 8 방향 |
| `assets/sprites/chars/dead_<variant>.png` | 48×48 | 1 | 1 |

- **방향 행 순서**: 0 E · 1 SE · 2 S · 3 SW · 4 W · 5 NW · 6 N · 7 NE (화면 기준 시계 방향)
- **발 기준선**: 셀 안 y = 44, x = 24. 두 시트의 발 위치가 반드시 같아야 한다.
- `variant`: `player`(강도윤) · `thug` · `gunman` · `visitor` · `civilian`
- `weapon`: `unarmed` · `pistol` · `pipe` (`WeaponData.visual_key`)
- 시트에 없는 무기 조합은 `unarmed` 상체로 대체된다.

### Aseprite 작업 방법

1. `art/chars/<variant>_legs.aseprite` — 40 프레임. 프레임 순서는 E 5장, SE 5장 … NE 5장.
2. `art/chars/<variant>_torso_<weapon>.aseprite` — 16 프레임. E 2장, SE 2장 … NE 2장.
3. 방향마다 태그(E, SE …)를 달아 두면 미리보기가 편하다 (내보내기에는 영향 없음).
4. `tools/export_aseprite.sh` 를 실행하면 열 수에 맞춰 시트로 내보낸다.

## 소품 — 바닥면 + 높이

`LevelBuilder.add_prop(바닥면, 텍스처, 종류)` 는 **스프라이트 아랫변을 바닥면 아랫변에 맞춰** 세운다.

- 캔버스 = 바닥면 너비 × (윗면 높이 + 앞면 높이)
- 위쪽에 윗면, 아래쪽에 앞면. 그림자·다리 등은 아랫변 안쪽에.
- 바닥면(충돌 사각형)은 레벨 스크립트가 정한다. 예: 세단 `Rect2(x, y, 144, 52)` 에 144×70 그림.

| 파일 | 바닥면 | 그림 |
| --- | --- | --- |
| `props/car_sedan.png` | 144×52 | 144×70 |
| `props/workbench.png`, `office_desk.png` | 120×36 | 120×62 |
| `props/tool_cart.png` | 44×30 | 44×52 |
| `props/oil_drum.png` | 24×22 | 26×48 |
| `props/shelf.png` | 40×22 | 40×86 |
| `props/tires.png` | 40×30 | 40×74 |
| `props/pillar.png` | 24×24 | 24×94 |
| `props/plant.png` | 22×16 | 22×52 |
| `props/shutter_closed.png` / `shutter_open.png` | 144×12 | 144×52 / 144×22 |
| `props/door_south.png`, `door_metal.png` | 40×12 | 40×52 |

## 벽 · 바닥

| 파일 | 크기 | 설명 |
| --- | --- | --- |
| `props/wall_top.png` | 48×12 | 벽 윗면. 가로·세로로 반복 타일링 |
| `props/wall_front.png` | 48×40 | 벽 앞면(콘크리트 블록). 가로 반복 |
| `props/wall_front_office.png` | 48×40 | 사무실·호텔 실내 벽 |
| `tiles/floor_atlas.png` | 384×48 | 바닥 8종: 콘크리트, 어두운 콘크리트, 금 간 콘크리트, 젖은 거리, 사무실 타일, 붉은 카펫, 카펫 테두리, 철망 |

바닥 타일셋은 `Game/World/Tiles/floor_tileset.tres` 이다. 타일을 추가하면 아틀라스를 가로로 늘리고 `.tres` 에 `8:0/0 = 0` 처럼 한 줄씩 추가한다. Godot 에디터의 TileMap 패널에서 레벨 바닥을 직접 칠할 수도 있다.

## UI

| 파일 | 크기 |
| --- | --- |
| `ui/portrait_player.png` | 40×40 |
| `ui/icon_pistol.png`, `icon_pipe.png`, `icon_fists.png` | 48×28 |
| `ui/mouse_left.png`, `mouse_right.png` | 12×16 |
| `ui/crosshair.png` | 32×32 |

## 내보내기

```bash
# Aseprite 가 PATH 에 있거나 ASEPRITE 변수로 지정
ASEPRITE=/Applications/Aseprite.app/Contents/MacOS/aseprite tools/export_aseprite.sh
```

규칙 (`art/` 아래 파일명으로 결정):

| 원본 | 결과 |
| --- | --- |
| `art/chars/<v>_legs.aseprite` | `assets/sprites/chars/legs_<v>.png` (5열) |
| `art/chars/<v>_torso_<w>.aseprite` | `assets/sprites/chars/torso_<v>_<w>.png` (2열) |
| `art/chars/<v>_dead.aseprite` | `assets/sprites/chars/dead_<v>.png` |
| `art/props/<name>.aseprite` | `assets/sprites/props/<name>.png` |
| `art/ui/<name>.aseprite` | `assets/sprites/ui/<name>.png` |
| `art/tiles/floor_atlas.aseprite` | `assets/tiles/floor_atlas.png` |

Aseprite 아트로 바꾼 파일은 `tools/gen_placeholders.py` 를 다시 돌리면 덮어써지므로, 실제 아트가 들어오기 시작하면 생성기는 더 이상 실행하지 않는다.
