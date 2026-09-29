"""Chup anh THAT cua ban deploy — khong tao gia.

  python _shot_health.py
"""
from __future__ import annotations

import pathlib
import sys

from playwright.sync_api import sync_playwright

URL = "https://day12-agent-hbvb.onrender.com"
OUT = pathlib.Path(__file__).parent / "screenshots"


def main() -> int:
    OUT.mkdir(exist_ok=True)
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(viewport={"width": 1280, "height": 720})

        # 1. /health — JSON that tu service dang chay
        page.goto(f"{URL}/health", wait_until="domcontentloaded", timeout=90_000)
        page.wait_for_timeout(1500)
        page.screenshot(path=str(OUT / "health.png"))
        print("saved screenshots/health.png")
        print("  body:", page.inner_text("body")[:200])

        # 2. /ready — bang chung da noi duoc Redis tren cloud
        page.goto(f"{URL}/ready", wait_until="domcontentloaded", timeout=90_000)
        page.wait_for_timeout(1500)
        page.screenshot(path=str(OUT / "ready.png"))
        print("saved screenshots/ready.png")
        print("  body:", page.inner_text("body")[:200])

        browser.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
