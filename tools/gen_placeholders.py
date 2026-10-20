#!/usr/bin/env python3
"""《마지막 밤》 자리표시 픽셀아트 생성기 v2 — 3/4 뷰.

실제 Aseprite 아트가 들어오기 전까지 쓰는 '프로그래머 아트'다. 중요한 것은 그림의 품질이
아니라 **규격**이다. 여기서 정한 규격(시트 배치, 발 기준점, 소품의 바닥면/높이)을 실제 아트가
그대로 따르면 코드 수정 없이 교체된다.

규격
  - 기본 해상도 960×540, 바닥 타일 48px
  - 캐릭터 캔버스 48×48, 발 기준선 y=44, 중심 x=24
  - 다리 시트  legs_<variant>.png   : 8행(방향) × 5열(0 정지, 1~4 걷기)
  - 상체 시트  torso_<variant>_<weapon>.png : 8행(방향) × 2열(0 기본, 1 동작)
  - 쓰러진 모습 dead_<variant>.png  : 48×48 1장
  - 방향 행 순서: 0 E, 1 SE, 2 S, 3 SW, 4 W, 5 NW, 6 N, 7 NE (화면 좌표, 시계 방향)
  - 소품: 바닥면(footprint) 높이 + 입면(height) 을 세로로 이어 그린다. 스프라이트 아랫변 =
    바닥면 아랫변. 입면은 아래쪽, 윗면은 위쪽.
  - 벽: wall_top.png (48×12 윗면), wall_front.png (48×40 앞면) 타일. 앞면 높이 = ViewSpace.WALL_HEIGHT

실행:  python3 tools/gen_placeholders.py
"""
from __future__ import annotations

import math
import os
import random
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sprites")
CHARS = os.path.join(OUT, "chars")
PROPS = os.path.join(OUT, "props")
TILES = os.path.join(ROOT, "assets", "tiles")
UI = os.path.join(OUT, "ui")
FX = os.path.join(OUT, "fx")
for d in (OUT, CHARS, PROPS, TILES, UI, FX):
    os.makedirs(d, exist_ok=True)

random.seed(2028)

# 팔레트 — GDD: 먹색, 콘크리트 회색, 차가운 청록, 가로등 주황 ---------------------------
INK = (14, 14, 18, 255)
INK2 = (26, 28, 34, 255)
OUTLINE = (10, 10, 14, 255)
CONCRETE = (84, 88, 92, 255)
CONCRETE_D = (58, 61, 66, 255)
CONCRETE_L = (112, 116, 120, 255)
TEAL = (46, 110, 118, 255)
TEAL_L = (82, 160, 168, 255)
ORANGE = (226, 140, 48, 255)
ORANGE_L = (255, 196, 110, 255)
SKIN = (222, 182, 150, 255)
SKIN_D = (180, 140, 112, 255)
BLOOD = (120, 18, 24, 255)
STEEL = (150, 156, 160, 255)
STEEL_D = (96, 100, 106, 255)
WHITE = (236, 236, 230, 255)
WOOD = (104, 78, 52, 255)
WOOD_L = (138, 108, 74, 255)
WOOD_D = (70, 52, 36, 255)
CLEAR = (0, 0, 0, 0)


def new(w, h):
    img = Image.new("RGBA", (w, h), CLEAR)
    return img, ImageDraw.Draw(img)


def save(img, folder, name):
    img.save(os.path.join(folder, name))


def shade(c, k):
    return (max(0, min(255, int(c[0] * k))), max(0, min(255, int(c[1] * k))), max(0, min(255, int(c[2] * k))), c[3])


def outline(img, color=OUTLINE):
    """불투명 픽셀 주변 1px 을 어두운 윤곽선으로 채운다 (가독성)."""
    w, h = img.size
    src = img.load()
    out = img.copy()
    dst = out.load()
    for y in range(h):
        for x in range(w):
            if src[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and src[nx, ny][3] > 40:
                    dst[x, y] = color
                    break
    return out


# ============================================================================
# 캐릭터
# ============================================================================
DIR_ANGLES = [0, 45, 90, 135, 180, 225, 270, 315]   # E SE S SW W NW N NE
C = 48
CX, FEET = 24, 44

VARIANTS = {
    "player":  {"coat": (38, 42, 56, 255),  "shirt": (92, 98, 112, 255),  "pants": (30, 32, 40, 255), "hair": (22, 20, 20, 255), "skin": SKIN},
    "thug":    {"coat": (20, 20, 24, 255),  "shirt": (48, 48, 54, 255),   "pants": (22, 22, 26, 255), "hair": (14, 12, 12, 255), "skin": (206, 168, 136, 255)},
    "gunman":  {"coat": (44, 48, 58, 255),  "shirt": (160, 160, 168, 255), "pants": (34, 36, 44, 255), "hair": (30, 24, 20, 255), "skin": SKIN},
    "visitor": {"coat": (92, 80, 72, 255),  "shirt": (150, 140, 124, 255), "pants": (50, 44, 40, 255), "hair": (60, 44, 34, 255), "skin": SKIN},
    "civilian": {"coat": (120, 110, 130, 255), "shirt": (190, 180, 190, 255), "pants": (60, 60, 70, 255), "hair": (90, 60, 40, 255), "skin": SKIN},
}
WEAPONS = ["unarmed", "pistol", "pipe"]


def facing(deg):
    r = math.radians(deg)
    return math.cos(r), math.sin(r)


def draw_legs(d, pal, deg, frame):
    fx, fy = facing(deg)
    px, py = -fy, fx                       # 수직 벡터
    spread_x = px * 3.2
    spread_y = py * 1.4                    # 깊이 방향은 축소
    # 걷기: 두 다리가 앞뒤로 번갈아
    k = [0, 2, 0, -2, 0][frame] if frame < 5 else 0
    bob = [0, -1, 0, -1, 0][frame]
    for side in (-1, 1):
        step = k * side
        lx = CX + spread_x * side + fx * step * 1.0
        ly = FEET + spread_y * side + fy * step * 0.5 + bob
        x0, y0 = int(round(lx - 2)), int(round(ly - 11))
        d.rectangle((x0, y0, x0 + 3, y0 + 9), fill=pal["pants"])
        d.rectangle((x0, y0 + 9, x0 + 3, y0 + 11), fill=INK)   # 신발


def draw_torso(d, pal, deg, weapon, frame):
    fx, fy = facing(deg)
    px, py = -fy, fx
    front = fy                              # +1 이면 정면(남쪽), -1 이면 등(북쪽)
    coat = pal["coat"]
    # 어깨/코트 (약간 앞으로 기운 상체)
    tx, ty = CX, 26
    d.rounded_rectangle((tx - 7, ty - 8, tx + 7, ty + 7), radius=4, fill=coat)
    # 셔츠(정면일 때만 보이는 V)
    if front > 0.2:
        d.rectangle((tx - 2 + int(fx * 2), ty - 6, tx + 1 + int(fx * 2), ty + 4), fill=pal["shirt"])
    else:
        d.line((tx - 6, ty - 4, tx + 6, ty - 4), fill=shade(coat, 0.8))
    # 팔
    sh_l = (tx + px * 6 * -1, ty - 5 + py * 2 * -1)
    sh_r = (tx + px * 6, ty - 5 + py * 2)
    if weapon == "pistol":
        reach = 11 if frame == 0 else 9     # 반동 프레임은 팔을 당긴다
        hx, hy = tx + fx * reach, ty - 4 + fy * reach * 0.55
        for sx, sy in (sh_l, sh_r):
            d.line((sx, sy, hx, hy), fill=coat, width=3)
        d.ellipse((hx - 2, hy - 2, hx + 2, hy + 2), fill=pal["skin"])
        gx, gy = hx + fx * 6, hy + fy * 3
        d.line((hx, hy, gx, gy), fill=INK, width=2)
        d.point((int(gx), int(gy)), fill=STEEL)
    elif weapon == "pipe":
        # 한 팔로 파이프를 어깨에 걸침 / 동작 프레임은 앞으로 휘두름
        if frame == 0:
            hx, hy = sh_r[0] + fx * 4, sh_r[1] - 6
            d.line((sh_r[0], sh_r[1], hx, hy), fill=coat, width=3)
            d.line((hx, hy, hx - px * 6, hy - 10), fill=STEEL, width=2)
        else:
            hx, hy = tx + fx * 12, ty - 2 + fy * 6
            d.line((sh_r[0], sh_r[1], hx, hy), fill=coat, width=3)
            d.line((hx, hy, hx + fx * 9, hy + fy * 5), fill=STEEL, width=2)
        d.line((sh_l[0], sh_l[1], sh_l[0] - fx * 1, sh_l[1] + 9), fill=coat, width=3)
    else:
        for sx, sy in (sh_l, sh_r):
            ex, ey = sx - fx * 1, sy + 9
            if frame == 1:   # 주먹 지르기
                ex, ey = tx + fx * 12, ty - 2 + fy * 5
            d.line((sx, sy, ex, ey), fill=coat, width=3)
            d.ellipse((ex - 2, ey - 2, ex + 2, ey + 2), fill=pal["skin"])
    # 머리
    hx0, hy0 = CX + fx * 1.0, 13 + fy * 0.5
    d.ellipse((hx0 - 5, hy0 - 6, hx0 + 5, hy0 + 5), fill=pal["skin"])
    # 머리카락: 뒤쪽과 윗부분
    bx, by = hx0 - fx * 2.0, hy0 - fy * 1.0
    d.ellipse((bx - 5, by - 6, bx + 5, by + 3), fill=pal["hair"])
    d.rectangle((hx0 - 5, hy0 - 6, hx0 + 5, hy0 - 3), fill=pal["hair"])
    if front > 0.2:
        ex = hx0 + fx * 1
        d.point((int(ex - 2), int(hy0)), fill=INK)
        d.point((int(ex + 2), int(hy0)), fill=INK)
    # 목 그림자
    d.line((CX - 2, 19, CX + 2, 19), fill=pal["skin"] if front > 0 else pal["hair"])


def char_sheets():
    for vname, pal in VARIANTS.items():
        # 다리
        sheet, _ = new(C * 5, C * 8)
        for row, deg in enumerate(DIR_ANGLES):
            for frame in range(5):
                cell, d = new(C, C)
                d.ellipse((CX - 8, FEET - 3, CX + 8, FEET + 3), fill=(0, 0, 0, 70))
                draw_legs(d, pal, deg, frame)
                cell = outline(cell)
                sheet.paste(cell, (frame * C, row * C))
        save(sheet, CHARS, f"legs_{vname}.png")
        # 상체 (무기별)
        for weapon in WEAPONS:
            sheet, _ = new(C * 2, C * 8)
            for row, deg in enumerate(DIR_ANGLES):
                for frame in range(2):
                    cell, d = new(C, C)
                    draw_torso(d, pal, deg, weapon, frame)
                    cell = outline(cell)
                    sheet.paste(cell, (frame * C, row * C))
            save(sheet, CHARS, f"torso_{vname}_{weapon}.png")
        # 쓰러진 모습: 남향 정지 포즈를 눕힌다
        legs, d1 = new(C, C)
        draw_legs(d1, pal, 90, 0)
        torso, d2 = new(C, C)
        draw_torso(d2, pal, 90, "unarmed", 0)
        comp = Image.alpha_composite(legs, torso)
        comp = outline(comp).rotate(90, expand=False, resample=Image.NEAREST)
        px = comp.load()
        for y in range(C):
            for x in range(C):
                r, g, b, a = px[x, y]
                if a:
                    px[x, y] = (int(r * 0.7), int(g * 0.66), int(b * 0.66), a)
        save(comp, CHARS, f"dead_{vname}.png")


def portrait(vname, name):
    pal = VARIANTS[vname]
    img, d = new(40, 40)
    d.rectangle((0, 0, 39, 39), fill=(22, 24, 30, 255))
    d.rounded_rectangle((8, 30, 31, 40), radius=4, fill=pal["coat"])
    d.rectangle((17, 28, 22, 34), fill=pal["skin"])
    d.ellipse((11, 6, 28, 28), fill=pal["skin"])
    d.ellipse((10, 4, 29, 18), fill=pal["hair"])
    d.rectangle((10, 12, 13, 20), fill=pal["hair"])
    d.point((16, 17), fill=INK); d.point((23, 17), fill=INK)
    d.line((15, 23, 24, 23), fill=SKIN_D)
    d.line((14, 16, 17, 15), fill=INK); d.line((22, 15, 25, 16), fill=INK)
    d.rectangle((12, 22, 27, 27), fill=(0, 0, 0, 30))
    save(img, UI, name)


# ============================================================================
# 바닥 타일 아틀라스 (48px)  0 콘크리트 1 어두운 콘크리트 2 금 간 콘크리트 3 젖은 거리
#                            4 흰 타일(사무실) 5 붉은 카펫 6 카펫 테두리 7 철망
# ============================================================================
def floor_atlas():
    T = 48
    atlas, _ = new(T * 8, T)

    def tile(i, base, speckle=40, speck_colors=None, lines=True):
        img, d = new(T, T)
        d.rectangle((0, 0, T - 1, T - 1), fill=base)
        for _ in range(speckle):
            x, y = random.randrange(T), random.randrange(T)
            d.point((x, y), fill=random.choice(speck_colors or [shade(base, 1.12), shade(base, 0.88)]))
        if lines:
            d.line((0, T - 1, T - 1, T - 1), fill=shade(base, 0.8))
            d.line((T - 1, 0, T - 1, T - 1), fill=shade(base, 0.8))
        atlas.paste(img, (i * T, 0))
        return img, d

    tile(0, CONCRETE_D, 70)
    tile(1, shade(CONCRETE_D, 0.8), 50)
    img, d = tile(2, CONCRETE_D, 60)
    d.line((6, 40, 20, 24, 28, 22, 44, 6), fill=shade(CONCRETE_D, 0.6))
    atlas.paste(img, (2 * T, 0))
    img, d = tile(3, (44, 52, 66, 255), 90, [(70, 84, 104, 255), (30, 36, 48, 255)])
    for _ in range(6):
        x, y = random.randrange(T), random.randrange(T)
        d.ellipse((x - 5, y - 2, x + 5, y + 2), fill=(90, 110, 130, 90))
    atlas.paste(img, (3 * T, 0))
    img, d = tile(4, (150, 150, 146, 255), 20, lines=False)
    for gx in (0, 24):
        for gy in (0, 24):
            d.rectangle((gx, gy, gx + 23, gy + 23), outline=(118, 118, 116, 255))
    atlas.paste(img, (4 * T, 0))
    img, d = tile(5, (112, 30, 34, 255), 80, [(130, 40, 44, 255), (90, 22, 26, 255)], lines=False)
    for gx in range(0, T, 12):
        for gy in range(0, T, 12):
            d.rectangle((gx + 4, gy + 4, gx + 7, gy + 7), fill=(130, 46, 48, 255))
    atlas.paste(img, (5 * T, 0))
    img, d = tile(6, (112, 30, 34, 255), 40, lines=False)
    d.rectangle((0, 0, T - 1, 7), fill=(178, 140, 70, 255))
    d.rectangle((0, 2, T - 1, 2), fill=(120, 90, 40, 255))
    atlas.paste(img, (6 * T, 0))
    img, d = tile(7, (50, 54, 58, 255), 0, lines=False)
    for gx in range(0, T, 6):
        d.line((gx, 0, gx, T - 1), fill=(30, 32, 36, 255))
    for gy in range(0, T, 6):
        d.line((0, gy, T - 1, gy), fill=(30, 32, 36, 255))
    atlas.paste(img, (7 * T, 0))
    save(atlas, TILES, "floor_atlas.png")


# ============================================================================
# 벽 (윗면 48×12, 앞면 48×28)
# ============================================================================
def walls():
    img, d = new(48, 12)
    d.rectangle((0, 0, 47, 11), fill=(40, 42, 48, 255))
    d.line((0, 0, 47, 0), fill=(58, 60, 68, 255))
    for _ in range(14):
        d.point((random.randrange(48), random.randrange(1, 12)), fill=(50, 52, 60, 255))
    save(img, PROPS, "wall_top.png")
    WH = 40
    img, d = new(48, WH)
    d.rectangle((0, 0, 47, WH - 1), fill=(74, 70, 66, 255))
    d.rectangle((0, 0, 47, 2), fill=(92, 88, 84, 255))
    row = 0
    for gy in range(3, WH - 4, 9):          # 블록 줄눈 (엇갈림)
        d.line((0, gy, 47, gy), fill=(62, 58, 54, 255))
        for gx in ((0, 24) if row % 2 == 0 else (12, 36)):
            d.line((gx, gy, gx, min(gy + 9, WH - 5)), fill=(62, 58, 54, 255))
        row += 1
    for _ in range(30):
        d.point((random.randrange(48), random.randrange(3, WH - 4)), fill=(84, 80, 76, 255))
    d.rectangle((0, WH - 4, 47, WH - 1), fill=(46, 44, 42, 255))   # 걸레받이
    save(img, PROPS, "wall_front.png")
    # 사무실용 밝은 벽 (페인트 + 몰딩)
    img, d = new(48, WH)
    d.rectangle((0, 0, 47, WH - 1), fill=(116, 112, 102, 255))
    d.rectangle((0, 0, 47, 2), fill=(146, 142, 132, 255))
    d.rectangle((0, 22, 47, 23), fill=(96, 92, 84, 255))
    d.rectangle((0, 24, 47, WH - 5), fill=(92, 80, 64, 255))
    d.rectangle((0, WH - 4, 47, WH - 1), fill=(64, 54, 42, 255))
    save(img, PROPS, "wall_front_office.png")


# ============================================================================
# 소품: 바닥면(fw×fh) + 입면 높이 h → 캔버스 fw × (fh + h)
# ============================================================================
def box_prop(name, fw, fh, h, top, side, detail=None, radius=0):
    img, d = new(fw, fh + h)
    if radius:
        d.rounded_rectangle((0, fh, fw - 1, fh + h - 1), radius=radius, fill=side)
        d.rounded_rectangle((0, 0, fw - 1, fh - 1 + 2), radius=radius, fill=top)
    else:
        d.rectangle((0, fh, fw - 1, fh + h - 1), fill=side)
        d.rectangle((0, 0, fw - 1, fh - 1), fill=top)
    d.line((0, fh - 1, fw - 1, fh - 1), fill=shade(top, 0.75))
    d.line((0, fh + h - 1, fw - 1, fh + h - 1), fill=shade(side, 0.6))
    if detail:
        detail(d, fw, fh, h)
    img = outline(img)
    save(img, PROPS, name)


def props():
    # 세단 (바닥 144×52, 높이 18)
    def car_detail(d, fw, fh, h):
        d.rounded_rectangle((28, 8, 116, fh - 8), radius=6, fill=(30, 46, 54, 255))     # 지붕
        d.rectangle((24, 10, 30, fh - 10), fill=(80, 118, 128, 255))                  # 앞유리
        d.rectangle((114, 10, 120, fh - 10), fill=(60, 86, 96, 255))
        d.rectangle((fw - 5, 10, fw - 2, 16), fill=ORANGE_L); d.rectangle((fw - 5, fh - 16, fw - 2, fh - 10), fill=ORANGE_L)
        d.rectangle((2, 10, 5, 16), fill=BLOOD); d.rectangle((2, fh - 16, 5, fh - 10), fill=BLOOD)
        d.rectangle((10, fh + 2, 134, fh + 8), fill=(40, 60, 70, 255))               # 옆 유리
        d.ellipse((18, fh + h - 10, 34, fh + h + 2), fill=INK); d.ellipse((110, fh + h - 10, 126, fh + h + 2), fill=INK)
    box_prop("car_sedan.png", 144, 52, 18, (44, 48, 56, 255), (30, 32, 38, 255), car_detail, radius=10)

    def bench_detail(d, fw, fh, h):
        d.rectangle((8, 6, 40, 16), fill=STEEL); d.rectangle((52, 8, 66, 28), fill=WOOD_D); d.rectangle((80, 6, 110, 10), fill=INK)
        for gx in (14, 60, 100):
            d.rectangle((gx, fh + 4, gx + 18, fh + 12), fill=WOOD_D); d.point((gx + 9, fh + 8), fill=STEEL)
    box_prop("workbench.png", 120, 36, 26, WOOD_L, WOOD, bench_detail)
    box_prop("office_desk.png", 120, 36, 26, (160, 140, 110, 255), (120, 100, 76, 255),
             lambda d, fw, fh, h: (d.rectangle((70, 6, 108, 28), fill=(30, 34, 40, 255)), d.rectangle((74, 10, 104, 24), fill=TEAL_L), d.rectangle((14, 12, 50, 26), fill=WHITE)))

    def cart_detail(d, fw, fh, h):
        for gy in range(fh + 3, fh + h - 2, 7):
            d.rectangle((4, gy, fw - 5, gy + 4), fill=(110, 30, 28, 255)); d.point((fw // 2, gy + 2), fill=STEEL)
        d.rectangle((6, 6, fw - 7, fh - 6), fill=(150, 44, 40, 255))
    box_prop("tool_cart.png", 44, 30, 22, (190, 56, 48, 255), (150, 40, 36, 255), cart_detail)

    img, d = new(26, 22 + 26)
    d.rectangle((0, 11, 25, 47), fill=(60, 68, 80, 255))
    d.rounded_rectangle((0, 11, 25, 47), radius=8, fill=(60, 68, 80, 255))
    for gy in (24, 36):
        d.line((0, gy, 25, gy), fill=(44, 50, 60, 255))
    d.ellipse((0, 0, 25, 21), fill=(80, 90, 104, 255)); d.ellipse((5, 4, 20, 17), fill=(60, 68, 80, 255))
    save(outline(img), PROPS, "oil_drum.png")

    def shelf_detail(d, fw, fh, h):
        for gy in range(fh + 4, fh + h - 6, 14):
            d.rectangle((2, gy, fw - 3, gy + 2), fill=(90, 94, 102, 255))
            d.rectangle((5, gy + 3, 13, gy + 10), fill=TEAL); d.rectangle((17, gy + 3, 27, gy + 10), fill=ORANGE); d.rectangle((30, gy + 4, 35, gy + 10), fill=WHITE)
    box_prop("shelf.png", 40, 22, 64, (60, 62, 70, 255), (48, 50, 58, 255), shelf_detail)

    def tires_detail(d, fw, fh, h):
        for gy in range(fh - 6, fh + h - 6, 10):
            d.ellipse((2, gy, fw - 3, gy + 12), fill=(36, 36, 40, 255)); d.ellipse((12, gy + 4, fw - 13, gy + 8), fill=(18, 18, 20, 255))
    box_prop("tires.png", 40, 30, 44, (24, 24, 28, 255), (24, 24, 28, 255), tires_detail)

    box_prop("pillar.png", 24, 24, 70, (62, 64, 72, 255), (46, 48, 56, 255),
             lambda d, fw, fh, h: [d.line((0, gy, fw - 1, gy), fill=(38, 40, 46, 255)) for gy in range(fh + 10, fh + h, 16)])

    def plant_detail(d, fw, fh, h):
        d.ellipse((2, 0, fw - 3, fh - 1), fill=(60, 44, 36, 255))
        for ang in range(0, 360, 45):
            r = math.radians(ang); lx, ly = fw / 2 + math.cos(r) * 9, 10 + math.sin(r) * 5
            d.ellipse((lx - 4, ly - 4, lx + 4, ly + 4), fill=(46, 110, 70, 255))
        d.ellipse((fw / 2 - 5, 4, fw / 2 + 5, 14), fill=(70, 150, 90, 255))
    box_prop("plant.png", 22, 16, 36, (60, 44, 36, 255), (90, 70, 56, 255), plant_detail)

    # 셔터 (닫힘: 144×12 윗면 + 40 앞면 / 열림: 위에 말려 올라간 통만 남음)
    img, d = new(144, 52)
    d.rectangle((0, 0, 143, 11), fill=(40, 42, 48, 255))
    d.rectangle((0, 12, 143, 51), fill=(84, 88, 96, 255))
    for gy in range(14, 52, 4):
        d.line((0, gy, 143, gy), fill=(58, 60, 66, 255))
    d.rectangle((64, 44, 79, 47), fill=(50, 52, 58, 255))      # 손잡이
    save(outline(img), PROPS, "shutter_closed.png")
    img, d = new(144, 22)
    d.rectangle((0, 0, 143, 11), fill=(40, 42, 48, 255))
    d.rounded_rectangle((0, 8, 143, 21), radius=5, fill=(84, 88, 96, 255))
    for gy in (12, 16):
        d.line((2, gy, 141, gy), fill=(58, 60, 66, 255))
    save(outline(img), PROPS, "shutter_open.png")

    # 남향 벽의 문 (윗면 12 + 앞면 40) / 동서 벽의 문(윗면 12×44)
    img, d = new(40, 52)
    d.rectangle((0, 0, 39, 11), fill=(40, 42, 48, 255))
    d.rectangle((0, 12, 39, 51), fill=(70, 56, 40, 255))
    d.rectangle((4, 15, 35, 51), fill=(100, 80, 56, 255))
    d.rectangle((8, 19, 31, 31), fill=(84, 66, 46, 255))
    d.rectangle((28, 36, 31, 39), fill=ORANGE_L)
    save(outline(img), PROPS, "door_south.png")
    # 철문 (방화문, 측문용)
    img, d = new(40, 52)
    d.rectangle((0, 0, 39, 11), fill=(40, 42, 48, 255))
    d.rectangle((0, 12, 39, 51), fill=(56, 66, 72, 255))
    d.rectangle((4, 15, 35, 51), fill=(76, 88, 96, 255))
    d.rectangle((26, 32, 33, 35), fill=STEEL)
    d.rectangle((8, 18, 22, 24), fill=(46, 110, 118, 255))
    save(outline(img), PROPS, "door_metal.png")
    img, d = new(14, 44)
    d.rectangle((0, 0, 13, 43), fill=(100, 80, 56, 255))
    d.rectangle((4, 2, 9, 41), fill=(84, 66, 46, 255))
    d.rectangle((2, 20, 4, 23), fill=ORANGE_L)
    save(outline(img), PROPS, "door_side.png")

    # 벽에 붙는 장식 (앞면 위에 그린다)
    img, d = new(40, 24)
    d.rectangle((0, 0, 39, 23), fill=(36, 60, 66, 255)); d.rectangle((3, 3, 36, 20), fill=(70, 110, 124, 255))
    d.line((3, 3, 36, 20), fill=(120, 170, 180, 140)); d.line((19, 3, 19, 20), fill=(36, 60, 66, 255))
    save(img, PROPS, "window.png")
    img, d = new(40, 24)
    d.rectangle((0, 0, 39, 23), fill=(36, 60, 66, 255)); d.rectangle((3, 3, 36, 20), fill=(20, 26, 30, 255))
    for _ in range(16):
        x0, y0 = random.randrange(4, 35), random.randrange(4, 19)
        d.line((x0, y0, x0 + random.randrange(-8, 8), y0 + random.randrange(-6, 6)), fill=(120, 170, 180, 220))
    save(img, PROPS, "window_broken.png")
    img, d = new(24, 30)
    d.rectangle((0, 0, 23, 29), fill=(70, 74, 80, 255)); d.rectangle((3, 3, 20, 26), fill=(96, 100, 108, 255))
    d.rectangle((6, 6, 9, 22), fill=ORANGE); d.rectangle((14, 6, 17, 22), fill=TEAL_L)
    save(outline(img), PROPS, "fuse_box.png")
    img, d = new(28, 18)
    d.rectangle((2, 0, 25, 3), fill=(60, 64, 70, 255)); d.polygon([(0, 4), (27, 4), (22, 14), (5, 14)], fill=(110, 112, 118, 255))
    d.ellipse((8, 10, 19, 17), fill=ORANGE_L)
    save(img, PROPS, "lamp.png")
    img, d = new(24, 16)
    d.rectangle((0, 0, 23, 15), fill=(222, 208, 170, 255)); d.polygon([(0, 0), (12, 9), (23, 0)], outline=(150, 130, 90, 255))
    save(outline(img), PROPS, "envelope.png")

    # 가로등 (바닥 10×8, 높이 90)
    img, d = new(30, 98)
    d.rectangle((12, 10, 17, 97), fill=(50, 54, 60, 255))
    d.rectangle((12, 4, 29, 9), fill=(50, 54, 60, 255))
    d.rectangle((20, 8, 29, 12), fill=ORANGE_L)
    d.ellipse((9, 90, 20, 97), fill=(40, 44, 50, 255))
    save(outline(img), PROPS, "street_light.png")
    # 작업등 (천장 매달림, 위에서 본 갓)
    img, d = new(30, 20)
    d.line((15, 0, 15, 6), fill=(40, 40, 44, 255))
    d.polygon([(2, 8), (28, 8), (24, 16), (6, 16)], fill=(70, 74, 80, 255))
    d.ellipse((9, 12, 21, 19), fill=ORANGE_L)
    save(outline(img), PROPS, "work_lamp.png")

    # 무기 픽업 / 탄창
    img, d = new(22, 12)
    d.rectangle((2, 3, 21, 6), fill=INK); d.rectangle((4, 6, 9, 11), fill=INK2); d.rectangle((6, 2, 20, 3), fill=CONCRETE_D)
    save(outline(img), PROPS, "pickup_pistol.png")
    img, d = new(26, 6)
    d.rectangle((0, 2, 25, 3), fill=STEEL); d.rectangle((22, 1, 25, 4), fill=CONCRETE_L)
    save(outline(img), PROPS, "pickup_pipe.png")
    img, d = new(10, 12)
    d.rectangle((0, 0, 9, 11), fill=(70, 62, 40, 255)); d.rectangle((2, 2, 7, 9), fill=(120, 108, 72, 255)); d.rectangle((3, 0, 6, 1), fill=STEEL)
    save(outline(img), PROPS, "magazine.png")


# ============================================================================
# FX / UI
# ============================================================================
def fx_and_ui():
    img, d = new(8, 2); d.rectangle((0, 0, 7, 1), fill=ORANGE_L); d.rectangle((0, 0, 2, 1), fill=WHITE)
    save(img, FX, "bullet.png")
    img, d = new(22, 14)
    d.polygon([(0, 7), (8, 0), (22, 4), (22, 10), (8, 14)], fill=ORANGE_L); d.polygon([(0, 7), (7, 3), (14, 6), (14, 8), (7, 11)], fill=WHITE)
    save(img, FX, "muzzle_flash.png")
    img, d = new(24, 24)
    for _ in range(18):
        x, y = random.randrange(3, 21), random.randrange(3, 21); r = random.randrange(1, 5)
        d.ellipse((x - r, y - r, x + r, y + r), fill=(110, 14, 20, 210))
    save(img, FX, "blood_splat.png")
    img, d = new(4, 4); d.ellipse((0, 0, 3, 3), fill=(20, 20, 20, 220)); save(img, FX, "bullet_hole.png")
    img, d = new(6, 6); d.polygon([(0, 2), (3, 0), (5, 3), (2, 5)], fill=(150, 200, 210, 200)); save(img, FX, "glass_shard.png")
    img, d = new(2, 10); d.line((0, 0, 1, 9), fill=(150, 180, 190, 150)); save(img, FX, "rain_drop.png")
    img, d = new(32, 32)
    d.ellipse((2, 2, 29, 29), fill=WHITE); d.ellipse((12, 12, 19, 19), fill=INK)
    save(img, UI, "crosshair.png")
    img, d = new(32, 32)   # 기름 얼룩
    for _ in range(9):
        cx, cy = random.randrange(8, 24), random.randrange(8, 24); r = random.randrange(3, 9)
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(12, 12, 16, 110))
    d.ellipse((10, 10, 22, 22), fill=(8, 8, 12, 150))
    save(img, FX, "oil_stain.png")
    # 마우스 아이콘 (좌/우 버튼 강조)
    for name, left in (("mouse_left.png", True), ("mouse_right.png", False)):
        img, d = new(12, 16)
        d.rounded_rectangle((0, 0, 11, 15), radius=4, fill=(40, 42, 50, 255), outline=(150, 152, 160, 255))
        d.line((6, 1, 6, 7), fill=(150, 152, 160, 255)); d.line((1, 7, 10, 7), fill=(150, 152, 160, 255))
        if left:
            d.rectangle((1, 1, 5, 6), fill=ORANGE_L)
        else:
            d.rectangle((7, 1, 10, 6), fill=ORANGE_L)
        save(img, UI, name)
    # 무기 아이콘 (카드용, 큰 권총)
    img, d = new(48, 28)
    d.rectangle((4, 8, 44, 14), fill=(200, 200, 205, 255)); d.rectangle((10, 14, 20, 26), fill=(150, 150, 156, 255))
    d.rectangle((22, 14, 28, 18), fill=(150, 150, 156, 255)); d.rectangle((6, 6, 44, 8), fill=(120, 120, 126, 255)); d.rectangle((40, 7, 43, 9), fill=WHITE)
    save(outline(img), UI, "icon_pistol.png")
    img, d = new(48, 28)
    d.rectangle((4, 12, 44, 16), fill=STEEL); d.rectangle((38, 10, 44, 18), fill=CONCRETE_L)
    save(outline(img), UI, "icon_pipe.png")
    img, d = new(48, 28)
    d.ellipse((12, 4, 36, 24), fill=SKIN); d.rectangle((10, 12, 38, 22), fill=SKIN_D)
    save(outline(img), UI, "icon_fists.png")
    img, d = new(48, 28)
    d.rectangle((18, 6, 30, 24), fill=(70, 62, 40, 255)); d.rectangle((20, 8, 28, 22), fill=(120, 108, 72, 255))
    save(outline(img), UI, "icon_magazine.png")


if __name__ == "__main__":
    # 구 버전 스프라이트 정리
    for f in os.listdir(OUT):
        p = os.path.join(OUT, f)
        if os.path.isfile(p) and f.endswith((".png", ".import")):
            os.remove(p)
    char_sheets()
    portrait("player", "portrait_player.png")
    floor_atlas()
    walls()
    props()
    fx_and_ui()
    print("placeholders written to", OUT)
