#!/usr/bin/env python3
"""按落地页实际用到的字符裁剪字体，输出到 assets/fonts/。

中文字体是两兆级的（NotoSansSC 完整版 2.5 MB / 字重），而这一页只用到 277 个汉字。
裁剪后中文字体降到几十 KB，英文字体也顺带去掉未用的字重字形。

**改了页面文案就要重跑这个脚本**，否则新出现的汉字没有字形，浏览器会显示成方框。

    python tools/subset-fonts.py

原件从 app/assets/fonts/ 读（同一个仓库，不重复存一份）；依赖 fontTools。
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

SITE = Path(__file__).resolve().parents[1]   # sonar-site/
SRC = SITE.parent / "app/assets/fonts"        # sonar-site -> repo/app/assets/fonts
OUT = SITE / "assets/fonts"

# 运行时会由 app.js 写进 DOM 的文案，页面源码里没有，必须先补进来
RUNTIME_TEXT = "复制已复制重新扫描打开仓库下载查看源码Sonar"

CJK_FONTS = ["NotoSansSC-Regular.ttf", "NotoSansSC-Bold.ttf"]
LATIN_FONTS = [
    "Archivo-Regular.ttf", "Archivo-Medium.ttf", "Archivo-SemiBold.ttf", "Archivo-Bold.ttf",
    "JetBrainsMono-Regular.ttf", "JetBrainsMono-Medium.ttf",
]

# 拉丁部分不按"用到哪些字"裁，而是保留整段 Basic Latin + Latin-1 和常用标点：
# 只差几 KB，但以后改文案不会突然缺字
LATIN_RANGES = "U+0020-007E,U+00A0-00FF,U+2010-2015,U+2018-201D,U+2022,U+2026,U+2190-2193,U+00B7"


def page_chars() -> str:
    text = ""
    for name in ("index.html", "app.js"):
        s = (SITE / name).read_text(encoding="utf-8")
        s = re.sub(r"<script.*?</script>", " ", s, flags=re.S)
        s = re.sub(r"<style.*?</style>", " ", s, flags=re.S)
        s = re.sub(r"<!--.*?-->", " ", s, flags=re.S)
        text += re.sub(r"<[^>]+>", " ", s)
    chars = {c for c in text + RUNTIME_TEXT if not c.isspace()}
    latin = {c for c in chars if ord(c) < 0x2E80}
    cjk = {c for c in chars if ord(c) >= 0x2E80}
    return "".join(sorted(latin | cjk)), len(cjk)


def subset(src: Path, dst: Path, unicodes: str | None, text_file: Path | None) -> int:
    cmd = [sys.executable, "-m", "fontTools.subset", str(src), f"--output-file={dst}",
           "--layout-features=*", "--flavor=", "--drop-tables+=DSIG"]
    if unicodes:
        cmd.append(f"--unicodes={unicodes}")
    if text_file:
        cmd.append(f"--text-file={text_file}")
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stdout[-800:], r.stderr[-800:])
        raise SystemExit(f"subset failed: {src.name}")
    return dst.stat().st_size


def main() -> None:
    text, n_cjk = page_chars()
    txt = SITE / "tools" / "_chars.txt"
    txt.write_text(text, encoding="utf-8")
    print(f"页面用到的汉字：{n_cjk} 个（另有拉丁字符，独立处理）\n")

    OUT.mkdir(parents=True, exist_ok=True)
    total_before = total_after = 0
    for name in CJK_FONTS + LATIN_FONTS:
        src = SRC / name
        if not src.exists():
            raise SystemExit(f"找不到原件：{src}")
        before = src.stat().st_size
        after = subset(src, OUT / name,
                       unicodes=LATIN_RANGES if name in LATIN_FONTS else None,
                       text_file=None if name in LATIN_FONTS else txt)
        total_before += before
        total_after += after
        print(f"{name:26s} {before/1024:8.1f} KB -> {after/1024:7.1f} KB")

    txt.unlink(missing_ok=True)
    print(f"\n合计 {total_before/1048576:.2f} MB -> {total_after/1024:.1f} KB")


if __name__ == "__main__":
    main()
