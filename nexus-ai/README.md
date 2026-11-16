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

See `backend/README.md`. The frontend always talks to the Cloudflare Worker; no API keys are ever stored in the browser.

By default the Worker routes to the free Pollinations provider, so **users need zero setup and no API keys**. The deployer can optionally add provider secrets (OpenAI, Anthropic, Gemini, OpenRouter) server-side for premium models.

## Deploy to GitHub Pages

The workflow `.github/workflows/deploy-nexus-ai.yml` builds and deploys `nexus-ai/dist`.

1. Push to `main`.
2. In repo Settings → Pages, set source to "GitHub Actions".
3. The site will be available at `https://<user>.github.io/<repo>/`.

Vite uses a relative base (`./`) so assets resolve under any path.
