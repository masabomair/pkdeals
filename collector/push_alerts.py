#!/usr/bin/env python3
"""Send push notifications when a brand starts a sale or deepens it.

Two modes:
  --quick         every 15 minutes: read only the first page of each brand's
                  catalogue (enough to see a sale start, gentle on their sites)
  --full FILE     after the hourly full collection: use its brands.json, which
                  can also tell when a sale has ended

What was last seen is kept in Firestore (meta/alerts), so runs remember each
other. Phones subscribe to one Firebase Cloud Messaging topic per brand they
follow ("brand_<id>"), so a single message reaches all of them.

Needs the FIREBASE_SERVICE_ACCOUNT secret (the service account JSON). Without
it the script explains and exits without error, so the rest keeps working.
"""
import argparse
import json
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent
COOLDOWN_HOURS = 6      # at most one alert per brand in this window
BIGGER_BY = 10          # discount must rise this many points to alert again


def detect(state, fresh, mode, now=None):
    """Pure rules. state: {id: {on, max, last}}; fresh: {id: {name, on_sale, max_off}}.
    Returns (alerts, new_state). Quick mode never ends a sale or lowers a
    discount, because page 1 alone can miss sale items further back."""
    now = now if now is not None else time.time()
    new_state = {k: dict(v) for k, v in state.items()}
    alerts = []
    for bid, f in fresh.items():
        on_sale, max_off = f["on_sale"], f["max_off"]
        st = new_state.get(bid)
        if st is None:  # first time we see this brand: remember, don't alert
            new_state[bid] = {"on": on_sale > 0, "max": max_off, "last": 0}
            continue
        cooled = now - st.get("last", 0) >= COOLDOWN_HOURS * 3600
        alert = None
        if on_sale > 0 and not st["on"]:
            alert = (f"{f['name']} sale is live!",
                     f"{on_sale:,} items on sale, up to {max_off}% off. Tap to see the deals."
                     if mode == "full" else
                     f"Up to {max_off}% off. Tap to see the deals.")
            st["on"], st["max"] = True, max_off
        elif on_sale > 0 and max_off >= st["max"] + BIGGER_BY:
            alert = (f"{f['name']}: bigger discounts",
                     f"Now up to {max_off}% off (was {st['max']}%). Tap to see the deals.")
            st["max"] = max_off
        elif mode == "full":
            if on_sale == 0:
                st["on"], st["max"] = False, 0      # sale over: next start alerts again
            else:
                st["max"] = max_off                 # true current maximum
        if alert and cooled:
            st["last"] = now
            alerts.append({"brand": bid, "title": alert[0], "body": alert[1]})
    return alerts, new_state


def quick_scan(brands):
    """First page of every brand, 8 at a time."""
    sys.path.insert(0, str(ROOT))
    import collect
    collect.MAX_PAGES = 1

    def one(b):
        try:
            deals, _ = collect.collect_brand(b)
            return b["id"], {"name": b["name"], "on_sale": len(deals),
                             "max_off": max((d["off"] for d in deals), default=0)}
        except Exception as e:  # noqa: BLE001
            print(f"  ! {b['name']}: {e}", file=sys.stderr)
            return b["id"], None

    with ThreadPoolExecutor(max_workers=8) as pool:
        return {k: v for k, v in pool.map(one, brands) if v is not None}


def full_scan(path):
    data = json.loads(Path(path).read_text())
    return {b["id"]: {"name": b["name"], "on_sale": b.get("on_sale", 0), "max_off": b.get("max_off", 0)}
            for b in data["brands"] if not b.get("error")}


def main():
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--quick", action="store_true")
    g.add_argument("--full", metavar="BRANDS_JSON")
    ap.add_argument("--dry-run", action="store_true", help="print alerts, send nothing, save nothing")
    args = ap.parse_args()

    creds = os.environ.get("FIREBASE_SERVICE_ACCOUNT", "").strip()
    if not creds and not args.dry_run:
        print("FIREBASE_SERVICE_ACCOUNT is not set: push alerts are off. "
              "Add the secret in GitHub to turn them on.")
        return 0

    brands = json.loads((ROOT / "brands.json").read_text())
    fresh = quick_scan(brands) if args.quick else full_scan(args.full)
    mode = "quick" if args.quick else "full"

    db = None
    state = {}
    if creds:
        import firebase_admin
        from firebase_admin import credentials, firestore
        firebase_admin.initialize_app(credentials.Certificate(json.loads(creds)))
        db = firestore.client()
        snap = db.collection("meta").document("alerts").get()
        state = (snap.to_dict() or {}).get("brands", {}) if snap.exists else {}

    alerts, new_state = detect(state, fresh, mode)
    print(f"{mode}: {len(fresh)} brands checked, {len(alerts)} alert(s)")
    for a in alerts:
        print(f"  -> {a['title']} | {a['body']}")
    if args.dry_run or db is None:
        return 0

    from firebase_admin import messaging
    for a in alerts:
        msg = messaging.Message(
            topic=f"brand_{a['brand']}",
            notification=messaging.Notification(title=a["title"], body=a["body"]),
            data={"brand": a["brand"]},
            android=messaging.AndroidConfig(
                priority="high",
                collapse_key=a["brand"],
                notification=messaging.AndroidNotification(
                    channel_id="sales", icon="ic_notification", color="#D4246B", tag=a["brand"]),
            ),
        )
        print("     sent", messaging.send(msg))
    db.collection("meta").document("alerts").set({"brands": new_state, "updated": firestore.SERVER_TIMESTAMP})
    return 0


if __name__ == "__main__":
    sys.exit(main())
