"""Cut Noto Sans JP down to the characters the game actually shows.

The web build cannot borrow the system's Japanese font, so the game ships its
own. Run this again whenever new Japanese text is added:

    uv run --with fonttools tools/subset_font.py <path to NotoSansJP[wght].ttf>

The source font comes from https://github.com/google/fonts/tree/main/ofl/notosansjp
"""

import pathlib
import sys
import unicodedata

from fontTools import subset

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "fonts" / "NotoSansJP-Game.ttf"
SKIP = {"tests", "tools", "build", "verify-output", ".godot"}


def game_text() -> set[str]:
    chars = {chr(c) for c in range(0x20, 0x7F)}
    chars |= {chr(c) for c in range(0x3000, 0x3100)}  # punctuation, hiragana, katakana
    chars |= {chr(c) for c in range(0xFF01, 0xFF5F)}  # full-width forms
    chars |= set("ー・…‥「」『』【】〜～×÷±→←↑↓★☆♪●○◆◇■□▲△▼▽")
    for path in ROOT.rglob("*.gd"):
        if SKIP & set(path.relative_to(ROOT).parts):
            continue
        chars |= {ch for ch in path.read_text(encoding="utf-8") if ord(ch) > 0x7F}
    return {ch for ch in chars if unicodedata.category(ch) != "Cc"}


def main() -> None:
    source = sys.argv[1]
    chars = game_text()
    options = subset.Options()
    options.layout_features = ["*"]
    options.name_IDs = ["*"]
    options.notdef_outline = True
    font = subset.load_font(source, options)
    subsetter = subset.Subsetter(options)
    subsetter.populate(text="".join(sorted(chars)))
    subsetter.subset(font)
    OUT.parent.mkdir(exist_ok=True)
    subset.save_font(font, str(OUT), options)
    print(f"{len(chars)} characters -> {OUT.relative_to(ROOT)} ({OUT.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
