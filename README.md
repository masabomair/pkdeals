# pkdeals — Sale Wala

Android app showing live discounts from 15 Pakistani clothing brands.

- `collector/` – Python script that reads each brand's public Shopify product feed and writes sale items to `docs/data/` (runs every 4 hours on GitHub Actions, published on GitHub Pages).
- `app/` – Flutter Android app (also builds for web; the web build lives in `docs/app/`, live at https://masabomair.github.io/pkdeals/app/).
- `.github/workflows/collect.yml` – scheduled collector + Pages deploy.
- `.github/workflows/build-apk.yml` – builds the APK, manual run only.

Add a brand: append it to `collector/brands.json` (must be a Shopify store).
