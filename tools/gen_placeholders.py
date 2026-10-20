#!/usr/bin/env python3
"""Generate placeholder pixel-art sprites for 《마지막 밤》.

These are deliberately simple, palette-limited top-down silhouettes so the
combat prototype is playable before Aseprite art lands.  Every sprite is
drawn with the GDD palette: 먹색, 콘크리트 회색, 차가운 청록, 가로등 주황.

Run from the repository root:  python3 tools/gen_placeholders.py
"""
from __future__ import annotations

import os
import random
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "sprites")

# GDD palette ---------------------------------------------------------------
INK = (16, 16, 20, 255)           # 먹색
INK2 = (28, 30, 36, 255)
CONCRETE = (84, 88, 92, 255)      # 콘크리트 회색
CONCRETE_D = (58, 61, 66, 255)
CONCRETE_L = (112, 116, 120, 255)
TEAL = (46, 110, 118, 255)        # 차가운 청록
TEAL_L = (82, 160, 168, 255)
ORANGE = (226, 140, 48, 255)      # 가로등 주황
ORANGE_L = (255, 196, 110, 255)
SKIN = (214, 170, 140, 255)
BLOOD = (120, 18, 24, 255)
STEEL = (150, 156, 160, 255)
WHITE = (236, 236, 230, 255)
CLEAR = (0, 0, 0, 0)


def new(w: int, h: int) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", (w, h), CLEAR)
    return img, ImageDraw.Draw(img)


def save(img: Image.Image, name: str) -> None:
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, name))


# Characters (top-down, facing +X) -----------------------------------------
def character(coat, shirt, hair, weapon=None, name="char.png"):
    """32x32 top-down figure facing right.  Weapon drawn along +X."""
    img, d = new(32, 32)
    # shadow
    d.ellipse((7, 9, 25, 25), fill=(0, 0, 0, 70))
    # shoulders / coat
    d.rounded_rectangle((9, 8, 23, 24), radius=5, fill=coat)
    d.rectangle((15, 9, 22, 23), fill=shirt)
    # arms
    d.rectangle((17, 6, 24, 9), fill=coat)   # left arm up (holding)
    d.rectangle((17, 23, 24, 26), fill=coat)
    d.rectangle((23, 7, 26, 9), fill=SKIN)
    d.rectangle((23, 23, 26, 25), fill=SKIN)
    # head
    d.ellipse((11, 11, 21, 21), fill=SKIN)
    d.ellipse((10, 10, 20, 20), fill=hair)
    d.ellipse((13, 12, 21, 20), fill=SKIN)
    d.rectangle((10, 11, 15, 19), fill=hair)
    if weapon == "pistol":
        d.rectangle((24, 14, 31, 16), fill=INK)
        d.rectangle((24, 16, 26, 19), fill=INK2)
    elif weapon == "pipe":
        d.rectangle((23, 15, 31, 16), fill=STEEL)
        d.rectangle((29, 14, 31, 17), fill=CONCRETE_L)
    save(img, name)


character((34, 36, 44, 255), (70, 74, 84, 255), (20, 18, 18, 255), "pistol", "player_pistol.png")
character((34, 36, 44, 255), (70, 74, 84, 255), (20, 18, 18, 255), None, "player_unarmed.png")
character((22, 22, 26, 255), (40, 40, 46, 255), (12, 12, 12, 255), "pipe", "enemy_thug.png")
character((30, 34, 40, 255), (56, 62, 70, 255), (12, 12, 12, 255), "pistol", "enemy_gunman.png")
character((60, 58, 70, 255), (120, 110, 100, 255), (40, 36, 36, 255), None, "npc_visitor.png")
character((90, 88, 100, 255), (160, 150, 150, 255), (90, 60, 40, 255), None, "npc_generic.png")

# Weapons / projectiles -----------------------------------------------------
img, d = new(6, 2)
d.rectangle((0, 0, 5, 1), fill=ORANGE_L)
d.rectangle((0, 0, 1, 1), fill=WHITE)
save(img, "bullet.png")

img, d = new(16, 10)
d.polygon([(0, 5), (6, 0), (16, 3), (16, 7), (6, 10)], fill=ORANGE_L)
d.polygon([(0, 5), (5, 2), (10, 4), (10, 6), (5, 8)], fill=WHITE)
save(img, "muzzle_flash.png")

img, d = new(16, 10)
d.rectangle((2, 3, 15, 5), fill=INK)
d.rectangle((3, 5, 6, 9), fill=INK2)
d.rectangle((4, 2, 14, 3), fill=CONCRETE_D)
save(img, "pickup_pistol.png")

img, d = new(16, 4)
d.rectangle((0, 1, 15, 2), fill=STEEL)
d.rectangle((13, 0, 15, 3), fill=CONCRETE_L)
save(img, "pickup_pipe.png")

img, d = new(8, 8)
d.rectangle((0, 0, 7, 7), fill=(70, 62, 40, 255))
d.rectangle((1, 1, 6, 6), fill=(120, 108, 72, 255))
save(img, "magazine.png")

# Tiles ---------------------------------------------------------------------
random.seed(7)
img, d = new(32, 32)
d.rectangle((0, 0, 31, 31), fill=CONCRETE_D)
for _ in range(60):
    x, y = random.randrange(32), random.randrange(32)
    d.point((x, y), fill=random.choice([CONCRETE, (62, 66, 70, 255), (50, 52, 56, 255)]))
d.line((0, 31, 31, 31), fill=(48, 50, 54, 255))
d.line((31, 0, 31, 31), fill=(48, 50, 54, 255))
save(img, "floor_concrete.png")

img, d = new(32, 32)   # 기름 얼룩: 반투명 얼룩 (바닥 위에 덧그림)
for _ in range(9):
    cx, cy = random.randrange(8, 24), random.randrange(8, 24)
    r = random.randrange(3, 9)
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(12, 12, 16, 110))
d.ellipse((10, 10, 22, 22), fill=(8, 8, 12, 150))
save(img, "floor_oilstain.png")

img, d = new(32, 32)
d.rectangle((0, 0, 31, 31), fill=(40, 42, 48, 255))
for yy in (0, 16):
    d.line((0, yy, 31, yy), fill=(24, 24, 28, 255))
for xx in (0, 16):
    d.line((xx, 0, xx, 31), fill=(24, 24, 28, 255))
save(img, "wall_block.png")

img, d = new(32, 32)
d.rectangle((0, 0, 31, 31), fill=(36, 60, 66, 255))
d.rectangle((2, 2, 29, 29), fill=(58, 96, 104, 255))
d.line((2, 2, 29, 29), fill=(90, 150, 160, 160))
save(img, "window.png")

img, d = new(32, 32)
d.rectangle((0, 0, 31, 31), fill=(36, 60, 66, 255))
d.rectangle((2, 2, 29, 29), fill=(24, 30, 34, 255))
for _ in range(14):
    x0, y0 = random.randrange(3, 28), random.randrange(3, 28)
    d.line((x0, y0, x0 + random.randrange(-8, 8), y0 + random.randrange(-8, 8)), fill=(90, 150, 160, 200))
save(img, "window_broken.png")

# Props ---------------------------------------------------------------------
img, d = new(96, 48)   # sedan, top-down, facing +X
d.rounded_rectangle((2, 4, 93, 43), radius=10, fill=(24, 26, 30, 255))
d.rounded_rectangle((6, 8, 89, 39), radius=8, fill=(44, 48, 56, 255))
d.rounded_rectangle((28, 10, 66, 37), radius=4, fill=(30, 46, 52, 255))   # roof/glass
d.rectangle((24, 10, 28, 37), fill=(70, 100, 110, 255))                   # windshield
d.rectangle((66, 10, 70, 37), fill=(60, 80, 90, 255))
d.rectangle((88, 12, 92, 16), fill=ORANGE_L)
d.rectangle((88, 31, 92, 35), fill=ORANGE_L)
d.rectangle((3, 12, 6, 16), fill=BLOOD)
d.rectangle((3, 31, 6, 35), fill=BLOOD)
save(img, "car_sedan.png")

img, d = new(96, 32)   # workbench
d.rectangle((0, 0, 95, 31), fill=(60, 48, 36, 255))
d.rectangle((2, 2, 93, 29), fill=(92, 74, 54, 255))
d.rectangle((6, 6, 30, 14), fill=STEEL)
d.rectangle((40, 8, 52, 24), fill=(50, 40, 32, 255))
d.rectangle((60, 6, 84, 10), fill=INK)
save(img, "workbench.png")

img, d = new(40, 28)   # tool cart (low cover)
d.rectangle((0, 0, 39, 27), fill=(150, 40, 36, 255))
d.rectangle((2, 2, 37, 25), fill=(190, 56, 48, 255))
d.rectangle((4, 4, 35, 8), fill=(110, 30, 28, 255))
d.rectangle((4, 12, 35, 16), fill=(110, 30, 28, 255))
d.rectangle((4, 20, 35, 24), fill=(110, 30, 28, 255))
save(img, "tool_cart.png")

img, d = new(24, 24)   # oil drum (low cover)
d.ellipse((0, 0, 23, 23), fill=(44, 50, 60, 255))
d.ellipse((3, 3, 20, 20), fill=(70, 80, 94, 255))
d.ellipse((7, 7, 16, 16), fill=(52, 60, 70, 255))
save(img, "oil_drum.png")

img, d = new(32, 48)   # shelving (high cover)
d.rectangle((0, 0, 31, 47), fill=(50, 52, 58, 255))
for yy in range(4, 48, 11):
    d.rectangle((2, yy, 29, yy + 6), fill=(84, 88, 96, 255))
    d.rectangle((4, yy + 1, 10, yy + 5), fill=TEAL)
    d.rectangle((14, yy + 1, 22, yy + 5), fill=ORANGE)
save(img, "shelf.png")

img, d = new(32, 64)   # tire stack
d.rectangle((0, 0, 31, 63), fill=(20, 20, 22, 255))
for yy in range(0, 64, 16):
    d.ellipse((2, yy + 2, 29, yy + 14), fill=(38, 38, 42, 255))
    d.ellipse((10, yy + 6, 21, yy + 10), fill=(20, 20, 22, 255))
save(img, "tires.png")

img, d = new(128, 16)   # shutter door (closed)
d.rectangle((0, 0, 127, 15), fill=(70, 74, 80, 255))
for yy in range(0, 16, 4):
    d.line((0, yy, 127, yy), fill=(44, 46, 50, 255))
save(img, "shutter.png")

img, d = new(32, 12)   # door
d.rectangle((0, 0, 31, 11), fill=(70, 56, 40, 255))
d.rectangle((2, 2, 29, 9), fill=(100, 80, 56, 255))
d.rectangle((24, 5, 27, 7), fill=ORANGE_L)
save(img, "door.png")

img, d = new(24, 24)   # fuse box / breaker
d.rectangle((0, 0, 23, 23), fill=(60, 64, 70, 255))
d.rectangle((3, 3, 20, 20), fill=(90, 96, 104, 255))
d.rectangle((6, 6, 9, 17), fill=ORANGE)
d.rectangle((14, 6, 17, 17), fill=TEAL_L)
save(img, "fuse_box.png")

img, d = new(20, 14)   # envelope
d.rectangle((0, 0, 19, 13), fill=(220, 206, 170, 255))
d.polygon([(0, 0), (10, 8), (19, 0)], outline=(150, 130, 90, 255))
save(img, "envelope.png")

img, d = new(16, 16)   # lamp fixture
d.ellipse((2, 2, 13, 13), fill=(90, 94, 100, 255))
d.ellipse((5, 5, 10, 10), fill=ORANGE_L)
save(img, "lamp.png")

# FX ------------------------------------------------------------------------
img, d = new(16, 16)
for _ in range(14):
    x, y = random.randrange(2, 14), random.randrange(2, 14)
    r = random.randrange(1, 4)
    d.ellipse((x - r, y - r, x + r, y + r), fill=(110, 14, 20, 210))
save(img, "blood_splat.png")

img, d = new(4, 4)
d.ellipse((0, 0, 3, 3), fill=(20, 20, 20, 220))
save(img, "bullet_hole.png")

img, d = new(6, 6)
d.polygon([(0, 2), (3, 0), (5, 3), (2, 5)], fill=(150, 200, 210, 200))
save(img, "glass_shard.png")

img, d = new(2, 6)
d.line((0, 0, 1, 5), fill=(150, 180, 190, 150))
save(img, "rain_drop.png")

img, d = new(32, 32)
d.ellipse((2, 2, 29, 29), fill=WHITE)
d.ellipse((12, 12, 19, 19), fill=INK)
save(img, "crosshair.png")

print("placeholders written to", OUT)
