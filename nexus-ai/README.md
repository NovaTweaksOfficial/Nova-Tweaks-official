# NEXUS AI

A futuristic, model-agnostic AI assistant PWA. Mobile-first, installable on iPhone via Safari "Add to Home Screen".

## Stack

- React 18 + TypeScript
- Vite
- Tailwind-free modern CSS (tokens + app.css)
- Framer Motion, Lucide, react-markdown, highlight.js
- PWA: manifest + service worker

## Run locally

```bash
cd nexus-ai
npm install
npm run dev
```

## Build

```bash
npm run build
npm run preview
```

## Backend (secure AI proxy)

See `backend/README.md`. Requests go through the Cloudflare Worker when `VITE_BACKEND_URL` (repo variable `BACKEND_URL`) is set; no API keys are ever stored in the browser.

NEXUS works with **zero setup**: with no backend configured it talks to the keyless default engine directly, and with a backend configured it uses the Worker for rate limiting and server-side provider keys. The deployer can add premium provider secrets (OpenAI, Anthropic, Gemini, OpenRouter) server-side.

## Deploy to GitHub Pages

**Live app:** https://novatweaksofficial.github.io/Nova-Tweaks-official/nexus-ai/

The published build is committed to `docs/nexus-ai/`, which is served by the repo's existing
branch-based Pages site (`main` → `/docs`). This keeps the Nova Tweaks storefront live at
`/Nova-Tweaks-official/`.

To publish a new build:

```bash
cd nexus-ai
npm run build
cd ..
rm -rf docs/nexus-ai
cp -R nexus-ai/dist docs/nexus-ai
git add docs/nexus-ai && git commit -m "Publish NEXUS AI build" && git push
```

Vite uses a relative base (`./`) so assets, the manifest, and the service worker all resolve
under `/nexus-ai/`. The app is installable on iOS Safari (Share → Add to Home Screen),
Android Chrome, and Samsung Internet.

`.github/workflows/deploy-nexus-ai.yml` builds on every `nexus-ai` change and can deploy to the
Pages root manually (Actions → Run workflow). Only use that after switching Settings → Pages to
"GitHub Actions", since it replaces the storefront at the site root.
