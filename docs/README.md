# Nova Tweaks storefront

Static marketing + download + checkout site for Nova Tweaks. No build step, no framework,
no external requests at runtime. Deployed from this `docs/` folder.

## Files

| File | Purpose |
| --- | --- |
| `index.html` | Single-page storefront: hero, features, catalog, pricing, giveaways, download, FAQ |
| `styles.css` | All styling (dark + red theme, responsive, reduced-motion aware) |
| `app.js` | Nav, reveal animations, checkout modal, payment link builders |
| `config.js` | **Edit this** — prices, download URLs, payment links, trust links |
| `assets/app-home.png`, `assets/app-tweaks.png` | Real app screenshots |
| `downloads/NovaTweaks-macOS.zip` | macOS app bundle |
| `favicon.svg` | Site icon |

The Windows download points at the latest GitHub release asset, so it always serves the
newest build without editing the site:

```
https://github.com/r00ster21714/fl3sh-optimizer/releases/latest/download/NovaTweaks.exe
```

## Enable GitHub Pages (one time)

1. Push this folder to `main`.
2. Repo → **Settings → Pages**.
3. Source: **Deploy from a branch** → Branch `main`, folder `/docs` → Save.
4. Wait ~1 minute. URL: `https://r00ster21714.github.io/fl3sh-optimizer/`

Or via API (needs a token with `repo` scope):

```bash
curl -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/r00ster21714/fl3sh-optimizer/pages \
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
`Nova_Tweaks_WebGUI.ps1` in sync.

After payment, issue a license key and send it to the buyer. The buyer pastes it into
**Settings → Account → License key** in the app.

## Issue license keys and gift codes

Run the key tool from the repo root:

```powershell
# $15 of in-app giveaway balance
pwsh ./tools/New-NovaKey.ps1 -Type Gift -Amount 15

# 30-day Pro key
pwsh ./tools/New-NovaKey.ps1 -Type Pro

# 30-day Ultimate key
pwsh ./tools/New-NovaKey.ps1 -Type Ultimate

# bulk
pwsh ./tools/New-NovaKey.ps1 -Type Pro -Count 10 > pro-keys.txt
```

Send gift codes to giveaway winners. They redeem under **Settings → Account → Redeem a gift code**, and the
balance can pay for Pro or Ultimate in the same panel. Send license keys to website buyers.

The secrets in `tools/New-NovaKey.ps1` must match `$Script:GiftSecret` and `$Script:LicenseSecret` in
`Nova_Tweaks_WebGUI.ps1`. Change both before a public launch. Validation is offline and client-side; it is not
a substitute for a real licensing backend.

## Attach a `.gg` domain

`.gg` domains are sold by Island Networks / 101domain (roughly $60–100/year). Once purchased:

1. Add a file named `CNAME` in this folder containing only the domain, e.g. `novatweaks.gg`.
2. At your DNS provider, point the apex at GitHub Pages:
   - `A` records → `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`
   - or `CNAME` for `www` → `r00ster21714.github.io`
3. Repo → Settings → Pages → Custom domain → enter the domain → Save → enable **Enforce HTTPS**.

## Updating the site

- **New Windows build:** publish a GitHub release; the download link follows `latest`.
- **New macOS build:** replace `docs/downloads/NovaTweaks-macOS.zip`.
- **New screenshots:** replace the two PNGs in `docs/assets/` (keep them around 1600px wide).
- **Version label:** `version` in `config.js`.

## Security messaging

The site is deliberately explicit that the Windows build is not code-signed yet, explains the
SmartScreen / Defender false-positive path, and links Microsoft's file-submission page and
VirusTotal. Set `virusTotal` in `config.js` once you have a report URL.
