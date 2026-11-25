#!/usr/bin/env python3
"""Collect discounted products from Pakistani clothing brands.

Each brand runs on Shopify, which publishes a public product feed at
https://<domain>/products.json. A product is "on sale" when a variant's
compare_at_price (old price) is higher than its price.

Output (in ../docs/data, served by GitHub Pages):
  deals/<brand>.json - that brand's in-stock discounted products, best first
  top.json           - the 600 best deals across all brands (home screen)
  brands.json        - per-brand summary (sale count, max % off, last checked)
"""
import json
import re
import sys
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUT = ROOT.parent / "docs" / "data"
UA = "Mozilla/5.0 (Linux; Android 13) PKDealsBot/1.0"
PAGE_SIZE = 250
MAX_PAGES = 40          # up to 10,000 products per brand
DELAY = 1.0             # seconds between requests, to be polite

KIDS = re.compile(r"\b(kids?|boys?|girls?|junior|infants?|baby|toddler|newborn)\b", re.I)
MEN = re.compile(r"\b(men|mens|men's|male|gents|man)\b", re.I)
WOMEN = re.compile(r"\b(women|womens|women's|ladies|female|woman)\b", re.I)
NON_CLOTHING = [
    ("Footwear", re.compile(r"shoe|footwear|sandal|slipper|sneaker|heels|loafer|chappal|khussa", re.I)),
    ("Bags & Accessories", re.compile(r"\bbags?\b|accessor|jewel|wallet|belt|cap\b|scarf|head ?wear|sock|watch|sunglass", re.I)),
    ("Fragrance & Beauty", re.compile(r"fragrance|perfume|scent|beauty|cosmetic|makeup|salt\b", re.I)),
    ("Home", re.compile(r"\bhome\b|bed ?sheet|bedding|duvet|cushion|towel|curtain|quilt", re.I)),
]
KID_TAGS = {"kids", "kid", "boys", "girls", "boy", "girl", "junior", "juniors", "baby", "infant", "infants"}
UNSTITCHED = re.compile(r"un[\s-]?stitch|fabric", re.I)


def fetch_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def classify(p):
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
        gender = "Women"   # most of these brands' catalogue is womenswear

    for name, rx in NON_CLOTHING:
        if rx.search(main):
            return gender, name
    if UNSTITCHED.search(every):
        return gender, "Unstitched"
    return gender, "Ready to Wear"


def to_deal(brand, p):
    best = None
    sizes = []
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
            if v.get("title") and v["title"] != "Default Title":
                sizes.append(v["title"])
    if not best:
        return None
    price, was = best
    off = round((was - price) / was * 100)
    if off < 1:
        return None
    img = (p.get("images") or [{}])[0].get("src")
    if img:
        img += ("&" if "?" in img else "?") + "width=500"
    gender, category = classify(p)
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
    }


def collect_brand(brand):
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


def main():
    brands = json.loads((ROOT / "brands.json").read_text())
    OUT.mkdir(parents=True, exist_ok=True)
    prev = {}
    if (OUT / "brands.json").exists():
        prev = {b["id"]: b for b in json.loads((OUT / "brands.json").read_text())["brands"]}

    now = datetime.now(timezone.utc).isoformat(timespec="seconds")
    all_deals, summary, failures = [], [], 0
    for b in brands:
        old = prev.get(b["id"], {})
        try:
            deals, total = collect_brand(b)
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
        time.sleep(DELAY)

    deals_dir = OUT / "deals"
    deals_dir.mkdir(exist_ok=True)
    failed = {s["id"] for s in summary if s.get("error")}
    for b in brands:
        f = deals_dir / f"{b['id']}.json"
        if b["id"] in failed:   # keep the last good file, and use it for top.json
            if f.exists():
                all_deals += json.loads(f.read_text())["deals"]
            continue
        mine = sorted((d for d in all_deals if d["brand"] == b["id"]), key=lambda d: (-d["off"], d["price"]))
        f.write_text(json.dumps({"generated": now, "deals": mine}, ensure_ascii=False, separators=(",", ":")))

    # top deals: best discounts, at most 60 per brand so one brand can't fill the list
    per, top = {}, []
    for d in sorted(all_deals, key=lambda d: (-d["off"], d["price"])):
        if per.get(d["brand"], 0) < 60 and d["category"] in ("Ready to Wear", "Unstitched"):
            per[d["brand"]] = per.get(d["brand"], 0) + 1
            top.append(d)
        if len(top) >= 600:
            break
    (OUT / "top.json").write_text(json.dumps({"generated": now, "deals": top}, ensure_ascii=False, separators=(",", ":")))
    (OUT / "brands.json").write_text(json.dumps({"generated": now, "brands": summary}, ensure_ascii=False, indent=1))
    print(f"\n{len(all_deals)} deals from {len(brands) - failures}/{len(brands)} brands -> {OUT}")
    return 1 if failures == len(brands) else 0


if __name__ == "__main__":
    sys.exit(main())
