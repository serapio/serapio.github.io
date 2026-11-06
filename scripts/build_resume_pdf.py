"""Render resume.html to resume.pdf using Playwright's Chromium."""

from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "resume.html"
OUTPUT = ROOT / "resume.pdf"


def main() -> None:
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch()
        page = browser.new_page()
        page.goto(SOURCE.as_uri(), wait_until="networkidle")
        page.emulate_media(media="print")
        page.pdf(
            path=OUTPUT,
            format="Letter",
            print_background=True,
            prefer_css_page_size=True,
        )
        browser.close()
    print(f"Wrote {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
