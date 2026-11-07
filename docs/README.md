# Nova Tweaks storefront

Static marketing + download + checkout site for Nova Tweaks. No build step, no framework,
no external requests at runtime. Deployed from this `docs/` folder.

## Products (separate apps)
- **Nova Tweaks (Fortnite) — Windows**: separate app for Fortnite.
- **Nova Tweaks (Minecraft) — Windows**: separate app with Minecraft-specific tweaks (options.txt, JVM/G1GC, GPU preference, fullscreen optimizations, process priority, Game Bar/capture; reversible/backups).
- **Nova Tweaks (Minecraft) — macOS**: native app (WKWebView + local engine, **no localhost**) with supported Minecraft file/JVM tweaks.

## Files

| File | Purpose |
| --- | --- |
| `index.html` | Single-page storefront: supported games, features, catalog, pricing, downloads, FAQ |
| `styles.css` | All styling (dark + red theme, responsive, reduced-motion aware) |
| `app.js` | Nav, reveal animations, checkout modal, per-product download/payment link handling |
| `config.js` | **Edit this** — prices, per-product download URLs, payment links, trust links |
| `assets/app-home.png`, `assets/app-tweaks.png` | App screenshots |
| `downloads/Nova-Tweaks-Minecraft-macOS.zip` | macOS Minecraft native app bundle |
| `favicon.svg` | Site icon |

Windows download URLs are configured in `config.js` (`windowsFortniteDownload`, `windowsMinecraftDownload`, with `windowsDownload` as fallback). Set them to real per-product release assets when separate CI builds are published. The macOS Minecraft download is served from `downloads/Nova-Tweaks-Minecraft-macOS.zip` (or the URL set in `config.js`).

## Enable GitHub Pages (one time)

1. Push this folder to `main`.
2. Repo → **Settings → Pages**.
3. Source: **Deploy from a branch** → Branch `main`, folder `/docs` → Save.
4. Wait ~1 minute. URL: `https://NovaTweaksOfficial.github.io/fl3sh-optimizer/`

Or via API (needs a token with `repo` scope):

```bash
curl -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/NovaTweaksOfficial/fl3sh-optimizer/pages \
  -d '{"source":{"branch":"main","path":"/docs"}}'
```

## Turn on payments

Open `docs/config.js` and fill in whichever links you have. Empty links stay disabled and the
site shows “checkout launching soon” instead of pretending to charge.

```js
pro: {
  label: "Pro",
  price: 5.99,
  stripe:  "https://buy.stripe.com/...",              // card
  paypal:  "https://www.paypal.com/paypalme/you/5.99", // or just "you"
  cashapp: "$YourCashtag"                              // or a full cash.app link
}
```

- **Stripe** — create a Payment Link for a $5.99/month recurring price, paste the URL.
- **PayPal** — paste a PayPal.me URL, or just your handle. The site appends the amount.
- **Cash App** — paste `$YourCashtag` or a full link. The site appends the exact amount.

Prices in the pricing cards and checkout modal are read from `config.js`, so change the price
in one place. Keep the app's plan prices in `Get-NovaPlanPriceCents` in
`shared/Nova_Tweaks_WebGUI.ps1` in sync.

After payment, issue a license key and send it to the buyer. The buyer pastes it into
**Settings → Account → License key** in the app. Checkout links remain disabled/"launching soon" until real Stripe/PayPal/Cash App links, cashtag/support email, and domain are configured.

## Issue license keys and gift codes

Run the key tool from the repo root:

```powershell
# $15 of in-app giveaway balance
pwsh ./shared/tools/New-NovaKey.ps1 -Type Gift -Amount 15

# 30-day Pro key
pwsh ./shared/tools/New-NovaKey.ps1 -Type Pro

# 30-day Ultimate key
pwsh ./shared/tools/New-NovaKey.ps1 -Type Ultimate
```

Send gift codes to giveaway winners. They redeem under **Settings → Account → Redeem a gift code**, and the
balance can pay for Pro or Ultimate in the same panel. Send license keys to website buyers.

The secrets in `shared/tools/New-NovaKey.ps1` must match `$Script:GiftSecret` and `$Script:LicenseSecret` in
`shared/Nova_Tweaks_WebGUI.ps1`. Change both before a public launch. Validation is offline and client-side; it is not
a substitute for a real licensing backend.

## Attach a `.gg` domain

`.gg` domains are sold by Island Networks / 101domain (roughly $60–100/year). Once purchased:

1. Add a file named `CNAME` in this folder containing only the domain, e.g. `novatweaks.gg`.
2. At your DNS provider, point the apex at GitHub Pages:
   - `A` records → `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`
   - or `CNAME` for `www` → `NovaTweaksOfficial.github.io`
3. Repo → Settings → Pages → Custom domain → enter the domain → Save → enable **Enforce HTTPS**.

## Updating the site

- **Windows builds:** publish GitHub release assets and set `windowsFortniteDownload` / `windowsMinecraftDownload` in `config.js` (or update `windowsDownload` fallback).
- **macOS Minecraft build:** replace `docs/downloads/Nova-Tweaks-Minecraft-macOS.zip` (native app bundle). Rebuild/resync from `macos/Minecraft/Nova Tweaks Minecraft.app` as needed.
- **Screenshots:** replace PNGs in `docs/assets/` (keep ~1600px wide).
- **Version label:** `version` in `config.js`.

## Security / status messaging

The site is explicit that Windows builds may be unsigned (SmartScreen/Defender false-positive guidance) and that the macOS Minecraft app is a native app (no localhost) but current builds may require PowerShell 7 (`pwsh`) and may be unsigned/unnotarized until distribution packaging is finalized. No telemetry. Set `virusTotal` in `config.js` when you have a report URL.
