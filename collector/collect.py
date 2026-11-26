#!/usr/bin/env python3
"""Collect discounted products from Pakistani clothing brands.

Each brand runs on Shopify, which publishes a public product feed at
https://<domain>/products.json. A product is "on sale" when a variant's
compare_at_price (old price) is higher than its price.

Output (in ../docs/data, served by GitHub Pages):
  deals/<brand>.json - that brand's in-stock discounted products, best first
  top.json           - the 2000 best deals across all brands (home screen)
  brands.json        - per-brand summary (sale count, max % off, last checked)
"""
import html
import json
import re
import sys
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUT = ROOT.parent / "docs" / "data"
UA = "Mozilla/5.0 (Linux; Android 13) PKDealsBot/1.0"
PAGE_SIZE = 250
MAX_PAGES = 40          # up to 10,000 products per brand
DELAY = 1.0             # seconds between one brand's page requests, to be polite
WORKERS = 8             # brands read at the same time

KIDS = re.compile(r"\b(kids?|boys?|girls?|junior|infants?|baby|toddler|newborn)\b", re.I)
MEN = re.compile(r"\b(men|mens|men's|male|gents|man)\b", re.I)
WOMEN = re.compile(r"\b(women|womens|women's|ladies|female|woman)\b", re.I)
NON_CLOTHING = [
    ("Footwear", re.compile(r"shoe|footwear|sandal|slipper|sneaker|heels|loafer|chappal|khussa", re.I)),
    ("Bags & Accessories", re.compile(r"\bbags?\b|accessor|jewel|wallet|belt|cap\b|scarf|scarv|head ?wear|sock|watch|sunglass|stitching", re.I)),
    ("Fragrance & Beauty", re.compile(r"fragrance|perfume|scent|beauty|cosmetic|makeup|salt\b|body mist|nail|lipstick|lotion|deodorant", re.I)),
    ("Home", re.compile(r"\bhome\b|bed ?sheet|bedding|duvet|cushion|towel|curtain|quilt", re.I)),
]
KID_TAGS = {"kids", "kid", "boys", "girls", "boy", "girl", "junior", "juniors", "baby", "infant", "infants"}
UNSTITCHED = re.compile(r"un[\s-]?stitch|\bfabrics?\b|\brts\b|ready[\s-]?to[\s-]?stitch", re.I)
STITCHED = re.compile(r"(?<!un)(?<!un-)(?<!un )stitched|\bpret\b|\brtw\b|ready[\s-]?to[\s-]?wear|\bready[\s-]?made", re.I)
UNSTITCHED_TAGS = {"unstitched", "un-stitched", "unstitch", "ready to stitch", "rts", "fabric", "fabrics"}
SIZE_OPT = re.compile(r"size|\bage\b|waist", re.I)
NOT_SIZE_OPT = re.compile(r"colou?r|shade|fabric|material|title|style|piece", re.I)
DROP = {"Footwear", "Bags & Accessories", "Home"}   # not shown in the app

# Shade names -> 14 simple colours. Order matters: first match wins
# ("rani pink" -> Pink, "khaki olive" -> Green, "off white" -> White).
COLOURS = [
    ("Multi", r"multi"),
    ("Pink", r"pink|peach|magenta|fuch?sia|gulabi|rose|blush|salmon"),
    ("Purple", r"purple|lilac|lavender|mauve|grape|plum|violet|aubergine"),
    ("Maroon", r"maroon|burgundy|wine|oxblood"),
    ("Red", r"\bred\b|cherry|crimson|scarlet"),
    ("Orange", r"orange|rust|coral|tangerine|apricot"),
    ("Yellow", r"yellow|mustard|lemon|\bgold"),
    ("Green", r"green|olive|mehndi|mint|emerald|pistachio|\bsage|\blime"),
    ("Blue", r"blue|navy|teal|\bsky|indigo|denim|aqua|turquoise|ferozi|cyan"),
    ("Brown", r"brown|coffee|chocolate|\btan\b|copper|mocha|camel|cinnamon"),
    ("Grey", r"gr[ae]y|charcoal|silver|ash\b|slate"),
    ("White", r"white|ivory|coconut milk|\bchalk"),
    ("Beige", r"beige|cream|\bsand|fawn|khaki|stone|nude|\bskin|ecru|champagne|oat|biscuit|off-white"),
    ("Black", r"black|\bjet\b"),
]
COLOURS = [(n, re.compile(rx, re.I)) for n, rx in COLOURS]
WORDS = {"one": 1, "two": 2, "three": 3, "four": 4}
PIECES = re.compile(r"\b(\d|one|two|three|four)\s*-?\s*(?:pc|pcs|piece|pieces)\b", re.I)
CODE_PIECES = re.compile(r"[A-Z]\d{2,}P([1-4])T?\b")   # article codes like SS26FOR430P3
JUNK = re.compile(r"free delivery|gift ?card|threshold|shipping|insurance", re.I)
KINDS = [
    ("Outerwear", re.compile(r"jacket|shacket|coat\b|\bcape\b|sweater|sweatshirt|hoodie|cardigan|blazer|shrug|puffer|gilet|jumper|pullover|waistcoat|poncho|sherwani", re.I)),
    ("Bottoms", re.compile(r"trouser|\bpants?\b|jeans|shalwar|salwar|culotte|palazzo|skirt|tights|shorts|jogger|cargo|chino|legging|sharara|gharara|pajama|pyjama|bottoms?\b|capri|dhoti", re.I)),
    ("Dupattas & Shawls", re.compile(r"dupatta|shawl|stole\b", re.I)),
    ("Shirts & Tops", re.compile(r"shirt|kurta|kurti|kameez|\btops?\b|\btee|polo|tunic|blouse|frock|kaftan|peplum|henley|vest\b|camisole|tank\b|angrakha|dress|jalabiya|jubba|abaya|gown|maxi", re.I)),
]
FABRICS = [
    ("Lawn", r"lawn"),
    ("Cambric", r"cambric"),
    ("Khaddar", r"khaddar|khadar|khaddi|khadder"),
    ("Karandi", r"karandi"),
    ("Linen", r"linen"),
    ("Cotton", r"cotton"),
    ("Chiffon", r"chiffon"),
    ("Silk", r"silk"),
    ("Velvet", r"velvet"),
    ("Organza", r"organza"),
    ("Net", r"\bnet\b"),
    ("Jacquard", r"jacquard|jaquard"),
    ("Marina", r"marina"),
    ("Wool", r"wool|pashmina|cashmere|tweed"),
    ("Denim", r"denim|jeans"),
    ("Jersey", r"jersey"),
    ("Viscose", r"viscose|rayon|modal"),
    ("Dobby", r"dobby"),
    ("Slub", r"slub"),
    ("Poplin", r"poplin"),
    ("Georgette", r"georgette"),
    ("Crepe", r"crepe|crêpe"),
    ("Fleece", r"fleece"),
    ("Corduroy", r"corduroy|cord\b"),
    ("Satin", r"satin"),
    ("Twill", r"twill"),
    ("Muslin", r"muslin|voile"),
    ("Wash & Wear", r"wash\s*(?:n|&|and|'n')\s*wear"),
    ("Cross Hatch", r"cross\s*-?hatch"),
    ("Blended", r"blended|polyester|\bpoly\b"),
    ("Interlock", r"interlock"),
]
FABRICS = [(n, re.compile(rx, re.I)) for n, rx in FABRICS]
SUIT = re.compile(r"\bsuits?\b|co-?ord|\bsets?\b|ensemble", re.I)


def base_colour(name):
    for base, rx in COLOURS:
        if rx.search(name):
            return base
    return None


def colours(p):
    """Simple colours of the product's in-stock variants (or from its text)."""
    idx = next((i for i, o in enumerate(p.get("options") or [])
                if re.search(r"colou?r|shade", o.get("name", ""), re.I)), None)
    found = []
    if idx is not None:
        for v in p.get("variants", []):
            if v.get("available", True):
                c = base_colour(v.get(f"option{idx + 1}") or "")
                if c and c not in found:
                    found.append(c)
    if not found:   # brands without a colour option: description "Color:" line
        m = re.search(r"colou?r\s*:\s*([A-Za-z][A-Za-z \-]{1,25})", description(p), re.I)
        if not m:   # e.g. "in a warm rust shade"
            m = re.search(r"((?:[a-z]+ ){0,2}[a-z]+) (?:shade|colou?r|tone|hue)\b", description(p), re.I)
        c = base_colour(m.group(1)) if m else None
        if c:
            found.append(c)
    if not found:   # else the title and tags
        text = " ".join([p.get("title") or ""] + list(p.get("tags") or []))
        hits = [(m.start(), base) for base, rx in COLOURS for m in [rx.search(text)] if m]
        if hits:
            found.append(min(hits)[1])
    return found


def description(p):
    text = re.sub(r"<[^>]+>", " ", html.unescape(p.get("body_html") or ""))
    return re.sub(r"\s+", " ", text)


def fabric(p, brand_name=""):
    """Main fabric: named first in the title, else the description's
    "Fabric:" line, else product type, tags, or anywhere in the description."""
    brand_rx = re.compile(re.escape(brand_name), re.I) if brand_name else None
    desc = description(p)
    field = re.search(r"(?:fabric|material|composition)\s*(?:&\s*care)?\s*:?\s*([^:]{0,60})", desc, re.I)
    sources = [p.get("title") or "", field.group(1) if field else "",
               p.get("product_type") or "", " ".join(p.get("tags") or []), desc]
    for text in sources:
        if brand_rx:
            text = brand_rx.sub(" ", text)   # "Nishat Linen" is a brand, not a fabric
        hits = [(m.start(), name) for name, rx in FABRICS for m in [rx.search(text)] if m]
        if hits:
            return min(hits)[1]
    return None


def pieces_and_kind(p, category):
    text = f"{p.get('product_type') or ''} {p.get('title') or ''}"
    every = f"{text} {' '.join(p.get('tags') or [])}"
    m = PIECES.search(text) or PIECES.search(every) or CODE_PIECES.search(p.get("title") or "")
    n = None
    if m:
        g = m.group(1).lower()
        n = int(g) if g.isdigit() else WORDS[g]
        n = min(n, 3)
    if category not in ("Ready to Wear", "Unstitched"):
        return n, None
    if (n and n >= 2) or SUIT.search(text):
        return n, "Suits & Sets"
    if category == "Unstitched":
        # single unstitched pieces are fabric, not ready-made shirts/bottoms
        if KINDS[2][1].search(text):
            return n, "Dupattas & Shawls"
        return n, None
    for kind, rx in KINDS:
        if rx.search(text):
            return n, kind
    return n, "Other"


def fetch_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def classify(p, default_gender="Women"):
    """Return (gender, category) from title, product_type and tags."""
    title = p.get("title") or ""
    ptype = p.get("product_type") or ""
    tag_list = [t.strip().lower() for t in (p.get("tags") or [])]
    tags = " ".join(tag_list)
    main = f"{ptype} {title}"
    every = f"{main} {tags}"

    if KIDS.search(main):
        gender = "Kids"
    elif MEN.search(main) and not WOMEN.search(main):
        gender = "Men"
    elif WOMEN.search(main):
        gender = "Women"
    elif any(t in KID_TAGS for t in tag_list):   # exact tags only: "all-girls" means women
        gender = "Kids"
    elif MEN.search(tags) and not WOMEN.search(tags):
        gender = "Men"
    else:
        gender = default_gender   # most brands are womenswear; menswear brands set "gender"

    for name, rx in NON_CLOTHING:
        if rx.search(main):
            return gender, name
    # the product's own title decides first, then its type, then exact tags
    # (tags like "hide-fabric" on ready-made items must not count)
    for text in (title, ptype):
        if UNSTITCHED.search(text):
            return gender, "Unstitched"
        if STITCHED.search(text):
            return gender, "Ready to Wear"
    if any(t in UNSTITCHED_TAGS for t in tag_list):
        return gender, "Unstitched"
    return gender, "Ready to Wear"


def to_deal(brand, p):
    if JUNK.search(p.get("title") or ""):
        return None
    best = None
    sizes = []
    opts = p.get("options") or []
    size_idx = next((i for i, o in enumerate(opts) if SIZE_OPT.search(o.get("name", ""))), None)
    if size_idx is None and len(opts) == 1 and not NOT_SIZE_OPT.search(opts[0].get("name", "")):
        size_idx = 0
    for v in p.get("variants", []):
        try:
            price = float(v.get("price") or 0)
            was = float(v.get("compare_at_price") or 0)
        except ValueError:
            continue
        if not v.get("available", True):
            continue
        if price > 0 and was > price:
            if best is None or (was - price) / was > (best[1] - best[0]) / best[1]:
                best = (price, was)
            if size_idx is not None:
                sz = (v.get(f"option{size_idx + 1}") or "").strip()
                if sz and sz != "Default Title" and sz not in sizes:
                    sizes.append(sz)
    if not best:
        return None
    price, was = best
    off = round((was - price) / was * 100)
    if off < 1:
        return None
    img = (p.get("images") or [{}])[0].get("src")
    if img:
        img += ("&" if "?" in img else "?") + "width=500"
    gender, category = classify(p, brand.get("gender", "Women"))
    if category in DROP:
        return None
    pieces, kind = pieces_and_kind(p, category)
    return {
        "id": f"{brand['id']}-{p['id']}",
        "brand": brand["id"],
        "title": p.get("title", "").strip(),
        "url": f"https://{brand['domain']}/products/{p['handle']}",
        "image": img,
        "price": round(price),
        "was": round(was),
        "off": off,
        "gender": gender,
        "category": category,
        "sizes": sizes[:12],
        "colors": colours(p),
        "pieces": pieces,
        "kind": kind,
        "fabric": fabric(p, brand["name"]) if category in ("Ready to Wear", "Unstitched") else None,
    }


def fetch_text(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode("utf-8", "ignore")


def collect_sfcc(brand):
    """Salesforce Commerce Cloud stores (e.g. Sapphire): read the sale
    category's product grid page by page and parse each product tile."""
    deals, total, size = [], 0, 48
    base = f"https://{brand['domain']}/on/demandware.store/Sites-{brand['site']}/default/Search-UpdateGrid"
    for page in range(MAX_PAGES):
        page_html = fetch_text(f"{base}?cgid={brand['cgid']}&start={page * size}&sz={size}")
        tiles = page_html.split('<div class="product" data-pid="')[1:]
        total += len(tiles)
        for t in tiles:
            pid = t.split('"', 1)[0]
            link = re.search(r'<div class="pdp-link">\s*<a[^>]*href="([^"]+)"[^>]*>\s*([^<]+?)\s*</a>', t)
            sub = re.search(r'<div class="subtitle">\s*([^<]+?)\s*</div>', t)
            img = re.search(r'data-src="([^"]+)"', t)
            was = re.search(r'strike-through list">\s*<span class="value[^"]*" content="([\d.]+)"', t)
            now = re.search(r'class="sales[^"]*">\s*<span class="value[^"]*" content="([\d.]+)"', t)
            if not (link and was and now):
                continue
            price, old = float(now.group(1)), float(was.group(1))
            if not (0 < price < old):
                continue
            title = html.unescape(link.group(2))
            p = {"title": title, "product_type": sub.group(1) if sub else "", "tags": [], "body_html": ""}
            gender, category = classify(p, brand.get("gender", "Women"))
            if category in DROP or JUNK.search(title):
                continue
            pieces, kind = pieces_and_kind(p, category)
            image = html.unescape(img.group(1)).replace("sw=1000&sh=1200", "sw=500&sh=600") if img else None
            deals.append({
                "id": f"{brand['id']}-{pid}",
                "brand": brand["id"],
                "title": title,
                "url": f"https://{brand['domain']}{html.unescape(link.group(1))}",
                "image": image,
                "price": round(price),
                "was": round(old),
                "off": round((old - price) / old * 100),
                "gender": gender,
                "category": category,
                "sizes": [],
                "colors": colours(p),
                "pieces": pieces,
                "kind": kind,
                "fabric": fabric(p, brand["name"]) if category in ("Ready to Wear", "Unstitched") else None,
            })
        if len(tiles) < size:
            break
        time.sleep(DELAY)
    return deals, total


def collect_brand(brand):
    if brand.get("type") == "sfcc":
        return collect_sfcc(brand)
    deals, total = [], 0
    for page in range(1, MAX_PAGES + 1):
        url = f"https://{brand['domain']}/products.json?limit={PAGE_SIZE}&page={page}"
        products = fetch_json(url).get("products", [])
        total += len(products)
        for p in products:
            d = to_deal(brand, p)
            if d:
                deals.append(d)
        if len(products) < PAGE_SIZE:
            break
        time.sleep(DELAY)
    return deals, total


ALL_COLS = ["id", "brand", "title", "path", "image", "price", "was", "off", "gender",
            "category", "kind", "pieces", "fabric", "colors", "sizes", "first_seen"]


def write_all(deals, brands, now):
    """One compact file with every deal, for app-wide search and filters.
    Rows are arrays in ALL_COLS order; the url is stored without the brand's
    domain and the id without the brand prefix to keep the download small."""
    domains = {b["id"]: b["domain"] for b in brands}
    rows = []
    for d in sorted(deals, key=lambda d: (-d["off"], d["price"])):
        prefix = f"https://{domains.get(d['brand'], '')}"
        path = d["url"][len(prefix):] if d["url"].startswith(prefix) else d["url"]
        rows.append([d["id"].split("-", 1)[-1], d["brand"], d["title"], path, d.get("image"),
                     d["price"], d["was"], d["off"], d["gender"][0], d["category"], d.get("kind"),
                     d.get("pieces"), d.get("fabric"), d.get("colors") or [], d.get("sizes") or [],
                     d.get("first_seen")])
    (OUT / "all.json").write_text(json.dumps({"generated": now, "cols": ALL_COLS, "rows": rows},
                                             ensure_ascii=False, separators=(",", ":")))


def main():
    brands = json.loads((ROOT / "brands.json").read_text())
    OUT.mkdir(parents=True, exist_ok=True)
    prev = {}
    if (OUT / "brands.json").exists():
        prev = {b["id"]: b for b in json.loads((OUT / "brands.json").read_text())["brands"]}

    now = datetime.now(timezone.utc).isoformat(timespec="seconds")
    all_deals, summary, failures = [], [], 0
    # Read up to WORKERS brands at the same time. Each brand's own pages are
    # still fetched one by one with a pause, so no single site is hammered.
    def run(b):
        try:
            return collect_brand(b)
        except Exception as e:  # noqa: BLE001 - reported below
            return e

    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        results = dict(zip((b["id"] for b in brands), pool.map(run, brands)))

    for b in brands:
        old = prev.get(b["id"], {})
        try:
            res = results[b["id"]]
            if isinstance(res, Exception):
                raise res
            deals, total = res
        except Exception as e:  # keep the last good data for this brand
            failures += 1
            print(f"  ! {b['name']}: {e}", file=sys.stderr)
            summary.append({**old, **b, "error": str(e)[:200]} if old else {**b, "error": str(e)[:200]})
            continue
        all_deals += deals
        info = {
            **b,
            "products": total,
            "on_sale": len(deals),
            "max_off": max((d["off"] for d in deals), default=0),
            "checked": now,
            # when this brand's sale started (first run with deals after a run without)
            "sale_since": (old.get("sale_since") or now) if deals else None,
        }
        summary.append(info)
        print(f"{b['name']:22} {total:5} products  {len(deals):5} on sale  up to {info['max_off']}% off")

    deals_dir = OUT / "deals"
    deals_dir.mkdir(exist_ok=True)
    failed = {s["id"] for s in summary if s.get("error")}

    # "New today": remember when each deal was first seen. A brand seen for the
    # first time has no history, so its deals get no date (not shown as new).
    hour = int(time.time() // 3600)
    for b in brands:
        f = deals_dir / f"{b['id']}.json"
        if b["id"] in failed:
            continue
        seen = None
        if f.exists():
            try:
                seen = {d["id"]: d.get("first_seen") for d in json.loads(f.read_text())["deals"]}
            except (ValueError, KeyError):
                seen = None
        for d in all_deals:
            if d["brand"] == b["id"]:
                d["first_seen"] = (seen.get(d["id"], hour) if seen is not None else None)
    for b in brands:
        f = deals_dir / f"{b['id']}.json"
        if b["id"] in failed:   # keep the last good file, and use it for top.json
            if f.exists():
                all_deals += json.loads(f.read_text())["deals"]
            continue
        mine = sorted((d for d in all_deals if d["brand"] == b["id"]), key=lambda d: (-d["off"], d["price"]))
        f.write_text(json.dumps({"generated": now, "deals": mine}, ensure_ascii=False, separators=(",", ":")))

    # top deals: best discounts, at most 200 per brand so one brand can't fill the list
    per, top = {}, []
    for d in sorted(all_deals, key=lambda d: (-d["off"], d["price"])):
        if per.get(d["brand"], 0) < 200 and d["category"] in ("Ready to Wear", "Unstitched"):
            per[d["brand"]] = per.get(d["brand"], 0) + 1
            top.append(d)
        if len(top) >= 2000:
            break
    write_all(all_deals, brands, now)
    (OUT / "top.json").write_text(json.dumps({"generated": now, "deals": top}, ensure_ascii=False, separators=(",", ":")))
    (OUT / "brands.json").write_text(json.dumps({"generated": now, "brands": summary}, ensure_ascii=False, indent=1))
    print(f"\n{len(all_deals)} deals from {len(brands) - failures}/{len(brands)} brands -> {OUT}")
    return 1 if failures == len(brands) else 0


if __name__ == "__main__":
    sys.exit(main())
