# NEXUS AI Backend (Cloudflare Worker)

Secure proxy that holds AI provider API keys server-side. Supports OpenAI, Anthropic, Google Gemini, OpenRouter, and custom OpenAI-compatible endpoints.

**Zero-config default:** the app uses the free Pollinations provider out of the box, so end users never need an API key. Add provider secrets only if you want premium/paid models.

## Develop

```bash
cd nexus-ai/backend
npm install
npm run dev   # http://127.0.0.1:8787
```

## Configure secrets

```bash
npx wrangler secret put OPENAI_API_KEY
npx wrangler secret put ANTHROPIC_API_KEY
npx wrangler secret put GEMINI_API_KEY
npx wrangler secret put OPENROUTER_API_KEY
# optional
npx wrangler secret put CUSTOM_API_KEY
```

## Deploy

```bash
npm run deploy
```

Copy the deployed URL into the app's Settings → Backend URL.

## Endpoints

- `GET /health`
- `POST /api/test` — `{ provider, baseUrl?, model? }`
- `POST /api/models` — `{ provider, baseUrl? }`
- `POST /api/chat` — `{ provider, model, messages, settings, systemPrompt?, stream? }`

CORS is configured for all origins by default (`ALLOWED_ORIGINS="*"`). Restrict via `wrangler.toml` vars.
