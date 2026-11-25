# pkdeals — Sale Wala

Android app showing live discounts from 38 Pakistani clothing brands.

**[⬇ Download the APK](https://github.com/masabomair/pkdeals/releases/latest/download/SaleWala.apk)** · [Website](https://masabomair.github.io/pkdeals/) · [Open in browser](https://masabomair.github.io/pkdeals/app/)

- `collector/` – Python script that reads each brand's public Shopify product feed and writes sale items to `docs/data/` (runs every 4 hours on GitHub Actions, published on GitHub Pages).
- `app/` – Flutter Android app (also builds for web; the web build lives in `docs/app/`, live at https://masabomair.github.io/pkdeals/app/).
- `.github/workflows/collect.yml` – scheduled collector + Pages deploy.
- `.github/workflows/build-apk.yml` – builds the APK, manual run only.

Add a brand: append it to `collector/brands.json` (must be a Shopify store).
