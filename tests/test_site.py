from pathlib import Path
from urllib.parse import unquote, urlsplit

import pytest
from bs4 import BeautifulSoup

ROOT = Path(__file__).resolve().parent.parent

PAGES = [
    "index.html",
    "consulting.html",
    "research.html",
    "about.html",
    "resume.html",
    "documentation.html",
    "segmentation/index.html",
]


def resolve_target(source: Path, href: str) -> Path:
    path = unquote(urlsplit(href).path)
    if not path:
        return source
    target = (source.parent / path).resolve()
    if href.endswith("/") or target.is_dir():
        return target / "index.html"
    return target


def ids_for(path: Path) -> set[str]:
    soup = BeautifulSoup(path.read_text(encoding="utf-8"), "html.parser")
    return {element["id"] for element in soup.select("[id]")}


@pytest.mark.parametrize("page_name", PAGES)
def test_page_has_title_and_main(page, page_name):
    page.goto((ROOT / page_name).as_uri())
    assert page.title()
    assert page.locator("main").count() == 1


@pytest.mark.parametrize("page_name", PAGES)
def test_page_has_one_h1_and_site_chrome(page_name):
    soup = BeautifulSoup((ROOT / page_name).read_text(encoding="utf-8"), "html.parser")
    assert len(soup.select("h1")) == 1, f"{page_name}: expected exactly one h1"
    assert soup.select_one("header.masthead") is not None
    assert soup.select_one("footer.footer") is not None


@pytest.mark.parametrize("page_name", PAGES)
def test_links_and_images_resolve(page_name):
    source = ROOT / page_name
    soup = BeautifulSoup(source.read_text(encoding="utf-8"), "html.parser")

    for anchor in soup.select("a[href]"):
        href = anchor["href"].strip()
        if not href or href.startswith(("mailto:", "http://", "https://", "data:")):
            continue

        target = resolve_target(source, href)
        assert target.exists(), f"{page_name}: missing target for {href}"

        fragment = urlsplit(href).fragment
        if fragment and target.suffix == ".html":
            assert fragment in ids_for(target), (
                f"{page_name}: missing anchor #{fragment} in {target.name}"
            )

    for image in soup.select("img[src]"):
        src = image["src"].strip()
        if src.startswith(("data:", "http://", "https://")):
            continue
        assert (source.parent / unquote(src)).resolve().exists(), (
            f"{page_name}: missing image {src}"
        )


def test_home_offers_both_audiences():
    soup = BeautifulSoup((ROOT / "index.html").read_text(encoding="utf-8"), "html.parser")
    hrefs = {anchor.get("href") for anchor in soup.select("a[href]")}
    assert "consulting.html" in hrefs
    assert "research.html" in hrefs
    assert "about.html" in hrefs


@pytest.mark.parametrize("page_name", PAGES)
def test_mobile_layout_has_no_horizontal_scroll(page, page_name):
    page.set_viewport_size({"width": 390, "height": 844})
    page.goto((ROOT / page_name).as_uri())
    scroll_width = page.evaluate("document.documentElement.scrollWidth")
    client_width = page.evaluate("document.documentElement.clientWidth")
    assert scroll_width <= client_width, f"{page_name}: horizontal overflow"


def test_legacy_page_redirects_to_home():
    soup = BeautifulSoup((ROOT / "lucien.html").read_text(encoding="utf-8"), "html.parser")
    refresh = soup.find("meta", attrs={"http-equiv": "refresh"})
    assert refresh is not None
    assert "url=index.html" in refresh["content"].lower()


def test_resume_prints_to_pdf():
    assert (ROOT / "resume.pdf").stat().st_size > 10_000
