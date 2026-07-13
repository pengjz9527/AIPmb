#!/usr/bin/env python3
"""AIPmb 技术方案 PPT 生成入口"""

import sys
import os

# 确保项目根目录在 sys.path 中
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from pptx import Presentation
from pptx.util import Emu
from pmb.pptx_gen.theme import SLIDE_W_EMU, SLIDE_H_EMU
from pmb.pptx_gen.generate import build_all_slides

OUTPUT_DIR = "output"
OUTPUT_FILE = "AIPmb_技术方案.pptx"


def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    prs = Presentation()
    prs.slide_width = Emu(SLIDE_W_EMU)
    prs.slide_height = Emu(SLIDE_H_EMU)

    # 使用空白布局（index 6 通常是 blank）
    blank_layout = prs.slide_layouts[6]

    build_all_slides(prs, blank_layout)

    output_path = os.path.join(OUTPUT_DIR, OUTPUT_FILE)
    prs.save(output_path)
    print(f"✅ 生成完成: {output_path}")
    print(f"   共 {len(prs.slides)} 页")
    print(f"   尺寸: {SLIDE_W_EMU // 9525}x{SLIDE_H_EMU // 9525} px")


if __name__ == "__main__":
    main()
