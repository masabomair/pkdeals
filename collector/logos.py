#!/usr/bin/env python3
"""Fetch each brand's small icon (app icon or favicon) for the brand circles.

For every brand: read its homepage, pick the best icon link (an
apple-touch-icon first, as brands design those square for phones; otherwise
the largest favicon, asking Shopify's image CDN for a bigger copy), and save
a clean 128x128 PNG to docs/data/logos/<id>.png. Light logos get a dark
background so they stay visible. brands.json is marked with "logo": true for
brands that have one, so the app only asks for icons that exist. A brand
whose icon can't be fetched keeps last run's icon (restored by the workflow)
or falls back to its initials in the app.
"""
import html
import io
import json
import re
import sys
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent
OUT = ROOT.parent / "docs" / "data"
LOGOS = OUT / "logos"
UA = "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36"
SIZE = 128


def get(url, limit=3_000_000):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "*/*"})
    with urllib.request.urlopen(req, timeout=25) as r:
        return r.read(limit), r.geturl()


def candidates(page, base):
    out = []
    for tag in re.findall(r"<link[^>]+>", page, re.I):
        rel = re.search(r'rel=["\']([^"\']+)', tag, re.I)
        href = re.search(r'href=["\']([^"\']+)', tag, re.I)
        if not (rel and href) or "icon" not in rel.group(1).lower():
            continue
        size = re.search(r'sizes=["\'](\d+)x', tag, re.I)
        url = urllib.parse.urljoin(base, html.unescape(href.group(1)))
        score = (2 if "apple" in rel.group(1).lower() else 1, int(size.group(1)) if size else 0)
        out.append((score, url))
    out.sort(reverse=True)
    return [u for _, u in out]


def bigger(url):
    """Ask Shopify's CDN for a 256px copy instead of the 32px favicon."""
    if "/cdn/shop/" not in url and "cdn.shopify.com" not in url:
        return url
    p = urllib.parse.urlsplit(url)
    q = [(k, v) for k, v in urllib.parse.parse_qsl(p.query) if k not in ("width", "height", "crop")]
    q += [("width", "256"), ("height", "256")]
    return urllib.parse.urlunsplit((p.scheme, p.netloc, p.path, urllib.parse.urlencode(q), ""))


def to_png(data, url):
    if url.split("?")[0].lower().endswith(".svg") or data.lstrip()[:5] in (b"<svg ", b"<?xml"):
        import cairosvg  # only needed for SVG icons
        data = cairosvg.svg2png(bytestring=data, output_width=256)
    im = Image.open(io.BytesIO(data))
    if getattr(im, "n_frames", 1) > 1 or im.format == "ICO":  # .ico: take the largest frame
        try:
            im.size = max(im.info.get("sizes", [im.size]))
        except Exception:  # noqa: BLE001
            pass
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    transparent = sum(c[3] < 40 for c in corners) >= 2
    if transparent:
        bgc = None
    else:  # opaque icon: its corner colour is its background (white, red, black...)
        bgc = tuple(sum(c[i] for c in corners) // 4 for i in range(3))

    def is_content(p):
        if p[3] < 40:
            return False
        return bgc is None or sum(abs(p[i] - bgc[i]) for i in range(3)) > 60

    # trim empty margins (transparent or background-coloured) around the mark
    mask = Image.new("L", im.size, 0)
    mask.putdata([255 if is_content(p) else 0 for p in im.getdata()])
    box = mask.getbbox()
    if box:
        im = im.crop(box)
    if im.width < 8 or im.height < 8:
        raise ValueError("icon too small")

    if bgc is not None:
        bg = bgc + (255,)
    else:  # transparent icon: light marks get a dark circle, others white
        content = [p for p in im.resize((48, 48)).getdata() if p[3] > 128]
        lum = sum(0.299 * r + 0.587 * g + 0.114 * b for r, g, b, _ in content) / max(len(content), 1)
        bg = (31, 26, 61, 255) if lum > 200 else (255, 255, 255, 255)
    # fill most of the circle; wide wordmarks get a little less height
    inner = int(SIZE * (0.62 if im.width > 1.6 * im.height else 0.6))
    scale = inner / max(im.width, im.height)
    im = im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.LANCZOS)
    canvas = Image.new("RGBA", (SIZE, SIZE), bg)
    canvas.alpha_composite(im, ((SIZE - im.width) // 2, (SIZE - im.height) // 2))
    out = io.BytesIO()
    canvas.convert("RGB").save(out, "PNG", optimize=True)
    return out.getvalue()


def fetch_logo(brand):
    page, final = get(f"https://{brand['domain']}/", limit=600_000)
    for url in candidates(page.decode("utf-8", "ignore"), final):
        for u in (bigger(url), url):
            try:
                data, _ = get(u)
                return to_png(data, u), u
            except Exception:  # noqa: BLE001 - try the next candidate
                continue
    # last resort: /favicon.ico at the site root
    data, _ = get(f"https://{brand['domain']}/favicon.ico")
    return to_png(data, "favicon.ico"), "favicon.ico"


def main():
    brands = json.loads((ROOT / "brands.json").read_text())
    LOGOS.mkdir(parents=True, exist_ok=True)

    def one(b):
        try:
            png, src = fetch_logo(b)
            (LOGOS / f"{b['id']}.png").write_bytes(png)
            return b["id"], f"ok ({len(png) // 1024} KB) {src[:80]}"
        except Exception as e:  # noqa: BLE001
            kept = (LOGOS / f"{b['id']}.png").exists()
            return b["id"], ("kept last icon" if kept else "none") + f": {str(e)[:60]}"

    with ThreadPoolExecutor(max_workers=8) as pool:
        results = list(pool.map(one, brands))
    for bid, msg in results:
        print(f"{bid:15} {msg}")

    have = {p.stem for p in LOGOS.glob("*.png")}
    f = OUT / "brands.json"
    if f.exists():
        data = json.loads(f.read_text())
        for b in data["brands"]:
            b["logo"] = b["id"] in have
        f.write_text(json.dumps(data, ensure_ascii=False, indent=1))
    print(f"\n{len(have)}/{len(brands)} brands have an icon")
    return 0


if __name__ == "__main__":
    sys.exit(main())
