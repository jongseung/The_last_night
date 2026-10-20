#!/usr/bin/env bash
# art/*.aseprite → assets/ PNG 내보내기. 규칙은 docs/ART_PIPELINE.md 참고.
set -euo pipefail
cd "$(dirname "$0")/.."
ASE="${ASEPRITE:-aseprite}"
command -v "$ASE" >/dev/null 2>&1 || { echo "Aseprite 를 찾을 수 없습니다. ASEPRITE=/경로/aseprite 로 지정하세요." >&2; exit 1; }

sheet() {  # sheet <src> <dst> <columns>
  mkdir -p "$(dirname "$2")"
  "$ASE" -b "$1" --sheet "$2" --sheet-type rows --sheet-columns "$3" >/dev/null
  echo "  $1 -> $2"
}
single() {  # single <src> <dst>
  mkdir -p "$(dirname "$2")"
  "$ASE" -b "$1" --save-as "$2" >/dev/null
  echo "  $1 -> $2"
}

shopt -s nullglob
for f in art/chars/*.aseprite; do
  name="$(basename "$f" .aseprite)"
  case "$name" in
    *_legs)    sheet  "$f" "assets/sprites/chars/legs_${name%_legs}.png" 5 ;;
    *_torso_*) v="${name%%_torso_*}"; w="${name#*_torso_}"; sheet "$f" "assets/sprites/chars/torso_${v}_${w}.png" 2 ;;
    *_dead)    single "$f" "assets/sprites/chars/dead_${name%_dead}.png" ;;
    *)         echo "  건너뜀(규칙 없음): $f" ;;
  esac
done
for f in art/props/*.aseprite; do single "$f" "assets/sprites/props/$(basename "$f" .aseprite).png"; done
for f in art/ui/*.aseprite;    do single "$f" "assets/sprites/ui/$(basename "$f" .aseprite).png"; done
for f in art/fx/*.aseprite;    do single "$f" "assets/sprites/fx/$(basename "$f" .aseprite).png"; done
for f in art/tiles/*.aseprite; do single "$f" "assets/tiles/$(basename "$f" .aseprite).png"; done
echo "완료. Godot 에디터를 열면 자동으로 다시 임포트됩니다."
