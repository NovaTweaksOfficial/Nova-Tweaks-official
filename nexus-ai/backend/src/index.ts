import {
  ProviderId,
  ChatSettings,
  ChatMessage,
  DEFAULT_MODELS,
  defaultBaseUrl,
  apiKeyFor,
  isOpenAICompat,
} from './providers'

interface Env {
  OPENAI_API_KEY?: string
  ANTHROPIC_API_KEY?: string
  GEMINI_API_KEY?: string
  OPENROUTER_API_KEY?: string
  CUSTOM_API_KEY?: string
  ALLOWED_ORIGINS?: string
  DEFAULT_RATE_LIMIT?: string
}

const NEXUS_IDENTITY =
  'You are NEXUS, the AI assistant of NEXUS AI. Your name is NEXUS. ' +
  'Never mention or reveal underlying providers, vendors, model names, training sources, or third-party companies. ' +
  'If asked who you are, say you are NEXUS. If asked what model or engine powers you, say NEXUS Core, a proprietary AI engine by NEXUS AI. ' +
  'If asked who made you, say you were created by the NEXUS AI team.'

const rateBuckets = new Map<string, { count: number; reset: number }>()
const dailyBuckets = new Map<string, { count: number; day: string }>()

function rateLimit(ip: string, limit: number): boolean {
  const now = Date.now()
  const b = rateBuckets.get(ip)
  if (!b || now > b.reset) {
    rateBuckets.set(ip, { count: 1, reset: now + 60_000 })
    return true
  }
  if (b.count >= limit) return false
  b.count++
  return true
}

const DAILY_LIMIT = 200
function dailyLimit(ip: string): boolean {
  const day = new Date().toISOString().slice(0, 10)
  const b = dailyBuckets.get(ip)
  if (!b || b.day !== day) {
    dailyBuckets.set(ip, { count: 1, day })
    return true
  }
  if (b.count >= DAILY_LIMIT) return false
  b.count++
  return true
}

function corsHeaders(origin: string | null, env: Env): Record<string, string> {
  const allowed = env.ALLOWED_ORIGINS || '*'
  let allowOrigin = '*'
  if (allowed !== '*') {
    const list = allowed.split(',').map(s => s.trim())
    if (origin && list.includes(origin)) allowOrigin = origin
    else allowOrigin = list[0] || '*'
  } else if (origin) {
    allowOrigin = origin
  }
  return {
    'Access-Control-Allow-Origin': allowOrigin,
    'Access-Control-Allow-Methods': 'POST, OPTIONS, GET',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Max-Age': '86400',
    'Vary': 'Origin',
  }
}

async function upstreamError(res: Response, cors: Record<string, string>): Promise<Response> {
  const text = await res.text()
  let message = text
  if (res.status === 401 || res.status === 403) message = 'Provider authentication failed. Check server-side API key configuration.'
  else if (res.status === 429) message = 'Provider rate limit or quota exceeded. Please try again later.'
  else if (res.status >= 500) message = 'AI provider is temporarily unavailable. Please try again.'
  else if (text.length > 300) message = text.slice(0, 300)
  return json({ error: message }, res.status, cors)
}

function json(data: any, status = 200, cors: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json', ...cors },
  })
}

function sseHeaders(cors: Record<string, string>): Record<string, string> {
  return {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive',
    ...cors,
  }
}

async function parseBody(req: Request): Promise<any> {
  try { return await req.json() } catch { return null }
}

function validateProvider(p: any): p is ProviderId {
  return ['openai', 'anthropic', 'gemini', 'openrouter', 'pollinations', 'custom'].includes(p)
}

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url)
    const origin = req.headers.get('Origin')
    const cors = corsHeaders(origin, env)
    const limit = parseInt(env.DEFAULT_RATE_LIMIT || '30', 10)

    if (req.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: cors })
    }

    const ip = req.headers.get('CF-Connecting-IP') || 'unknown'
    if (!rateLimit(ip, limit)) {
      return json({ error: 'Rate limit exceeded. Try again later.' }, 429, cors)
    }
    if (!dailyLimit(ip)) {
      return json({ error: 'Daily usage limit reached. Try again tomorrow.' }, 429, cors)
    }
    const contentLength = parseInt(req.headers.get('Content-Length') || '0', 10)
    if (contentLength > 64 * 1024) {
      return json({ error: 'Request too large.' }, 413, cors)
    }

    if (url.pathname === '/' || url.pathname === '/health') {
      return json({ ok: true, service: 'nexus-ai-backend' }, 200, cors)
    }

    if (url.pathname === '/api/test' && req.method === 'POST') {
      const body = await parseBody(req)
      if (!body || !validateProvider(body.provider)) {
        return json({ ok: false, message: 'Invalid provider.' }, 400, cors)
      }
      const p = body.provider as ProviderId
      const base = (body.baseUrl || defaultBaseUrl(p)).replace(/\/$/, '')
      const key = apiKeyFor(env, p)
      if (p === 'custom' && !base) {
        return json({ ok: false, message: 'Custom provider requires a Base URL.' }, 400, cors)
      }
      if (!['custom', 'pollinations'].includes(p) && !key) {
        return json({ ok: false, message: 'NEXUS Core is not configured on the server.' }, 400, cors)
      }
      try {
        if (p === 'anthropic') {
          const model = DEFAULT_MODELS.anthropic[0]
          let res: Response
          try {
            res = await fetch(`${base}/messages`, {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                'x-api-key': key || '',
                'anthropic-version': '2023-06-01',
              },
              body: JSON.stringify({ model, max_tokens: 8, messages: [{ role: 'user', content: 'ping' }] }),
            })
          } catch (e: any) {
            return json({ ok: false, message: e?.message || 'Connection failed.' }, 200, cors)
          }
          if (res.ok) return json({ ok: true, message: 'Connection successful.' }, 200, cors)
          return json({ ok: false, message: `HTTP ${res.status}: ${await res.text()}` }, 200, cors)
        }
        // openai-compat
        let res: Response
        try {
          res = await fetch(`${base}/models`, {
            headers: key ? { Authorization: `Bearer ${key}` } : {},
          })
        } catch (e: any) {
          return json({ ok: false, message: e?.message || 'Connection failed.' }, 200, cors)
        }
        if (res.ok) return json({ ok: true, message: 'Connection successful.' }, 200, cors)
        // fallback: tiny chat
        let chatRes: Response
        try {
          chatRes = await fetch(`${base}/chat/completions`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', ...(key ? { Authorization: `Bearer ${key}` } : {}) },
            body: JSON.stringify({ model: (body.model || DEFAULT_MODELS[p][0] || ''), messages: [{ role: 'user', content: 'ping' }], max_tokens: 8 }),
          })
        } catch (e: any) {
          return json({ ok: false, message: e?.message || 'Connection failed.' }, 200, cors)
        }
        if (chatRes.ok) return json({ ok: true, message: 'Connection successful.' }, 200, cors)
        return json({ ok: false, message: `HTTP ${chatRes.status}: ${await chatRes.text()}` }, 200, cors)
      } catch (e: any) {
        return json({ ok: false, message: e?.message || 'Connection failed.' }, 200, cors)
      }
    }

    if (url.pathname === '/api/models' && req.method === 'POST') {
      const body = await parseBody(req)
      if (!body || !validateProvider(body.provider)) {
        return json({ models: [], message: 'Invalid provider.' }, 400, cors)
      }
      const p = body.provider as ProviderId
      const base = (body.baseUrl || defaultBaseUrl(p)).replace(/\/$/, '')
      const key = apiKeyFor(env, p)
      if (p === 'anthropic') {
        return json({ models: DEFAULT_MODELS.anthropic }, 200, cors)
      }
      try {
        const res = await fetch(`${base}/models`, {
          headers: key ? { Authorization: `Bearer ${key}` } : {},
        })
        if (!res.ok) return json({ models: DEFAULT_MODELS[p] }, 200, cors)
        const data: any = await res.json()
        const ids = (data?.data || []).map((m: any) => m.id).filter(Boolean)
        return json({ models: ids.length ? ids : DEFAULT_MODELS[p] }, 200, cors)
      } catch {
        return json({ models: DEFAULT_MODELS[p] }, 200, cors)
      }
    }

    if (url.pathname === '/api/chat' && req.method === 'POST') {
      const body = await parseBody(req)
      if (!body || !validateProvider(body.provider)) {
        return json({ error: 'Invalid provider.' }, 400, cors)
      }
      const p = body.provider as ProviderId
      const base = (body.baseUrl || defaultBaseUrl(p)).replace(/\/$/, '')
      const key = apiKeyFor(env, p)
      if (p === 'custom' && !base) {
        return json({ error: 'Custom provider requires a Base URL.' }, 400, cors)
      }
      if (!['custom', 'pollinations'].includes(p) && !key) {
        return json({ error: 'NEXUS Core is not configured on the server.' }, 400, cors)
      }
      if (!Array.isArray(body.messages) || body.messages.length === 0) {
        return json({ error: 'Messages are required.' }, 400, cors)
      }
      if (body.messages.length > 50) {
        return json({ error: 'Too many messages in one request.' }, 400, cors)
      }
      for (const m of body.messages) {
        if (!m || typeof m !== 'object') return json({ error: 'Invalid message format.' }, 400, cors)
        if (!['system', 'user', 'assistant'].includes(m.role)) return json({ error: 'Invalid message role.' }, 400, cors)
        if (typeof m.content !== 'string' || m.content.length === 0) return json({ error: 'Message content is required.' }, 400, cors)
        if (m.content.length > 8000) return json({ error: 'Message too long.' }, 400, cors)
      }
      const model = body.model || DEFAULT_MODELS[p][0]
      if (!model) return json({ error: 'No model selected.' }, 400, cors)
      const settings: ChatSettings = body.settings || { temperature: 0.7, maxTokens: 1024, topP: 1, stream: true }
      // clamp settings
      settings.temperature = Math.min(2, Math.max(0, Number(settings.temperature) || 0.7))
      settings.maxTokens = Math.min(4096, Math.max(1, Math.floor(Number(settings.maxTokens) || 1024)))
      settings.topP = Math.min(1, Math.max(0, Number(settings.topP) || 1))
      const messages: ChatMessage[] = body.messages
      const clientSystemPrompt: string | undefined = typeof body.systemPrompt === 'string' ? body.systemPrompt.slice(0, 4000) : undefined
      const systemPrompt = `${NEXUS_IDENTITY} ${clientSystemPrompt || ''}`

      const chatMessages = [
        { role: 'system', content: systemPrompt },
        ...messages.filter(m => m.role !== 'system').map(m => ({ role: m.role, content: m.content })),
      ]

      const stream = settings.stream !== false && body.stream !== false

      // Anthropic
      if (p === 'anthropic') {
        const msgs = messages.filter(m => m.role !== 'system').map(m => ({ role: m.role === 'assistant' ? 'assistant' : 'user', content: m.content }))
        const sys = systemPrompt || messages.find(m => m.role === 'system')?.content
        const anthropicBody: any = {
          model,
          max_tokens: settings.maxTokens,
          temperature: settings.temperature,
          top_p: settings.topP,
          messages: msgs,
          stream,
        }
        if (sys) anthropicBody.system = sys
        if (!stream) {
          let res: Response
          try {
            res = await fetch(`${base}/messages`, {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                'x-api-key': key || '',
                'anthropic-version': '2023-06-01',
              },
              body: JSON.stringify(anthropicBody),
            })
          } catch (e: any) {
            return json({ error: e?.message || 'Network error.' }, 502, cors)
          }
          if (!res.ok) return await upstreamError(res, cors)
          const data: any = await res.json()
          const text = (data?.content || []).map((c: any) => c.text || '').join('')
          return json({ text }, 200, cors)
        }
        // streaming
        let res: Response
        try {
          res = await fetch(`${base}/messages`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': key || '',
              'anthropic-version': '2023-06-01',
            },
            body: JSON.stringify(anthropicBody),
          })
        } catch (e: any) {
          return json({ error: e?.message || 'Network error.' }, 502, cors)
        }
        if (!res.ok) return await upstreamError(res, cors)
        const { readable, writable } = new TransformStream()
        const writer = writable.getWriter()
        const enc = new TextEncoder()
        ;(async () => {
          const reader = res.body!.getReader()
          const dec = new TextDecoder()
          let buf = ''
          try {
            while (true) {
              const { done, value } = await reader.read()
              if (done) break
              buf += dec.decode(value, { stream: true })
              const lines = buf.split('\n')
              buf = lines.pop() || ''
              for (const line of lines) {
                const t = line.trim()
                if (!t.startsWith('data:')) continue
                const data = t.slice(5).trim()
                if (data === '[DONE]') continue
                try {
                  const json = JSON.parse(data)
                  if (json.type === 'content_block_delta' && json.delta?.text) {
                    await writer.write(enc.encode(`data: ${JSON.stringify({ delta: json.delta.text })}\n\n`))
                  }
                } catch { /* ignore */ }
              }
            }
            await writer.write(enc.encode('data: [DONE]\n\n'))
          } catch (e: any) {
            await writer.write(enc.encode(`data: ${JSON.stringify({ error: e?.message || 'stream error' })}\n\n`))
          } finally {
            await writer.close()
          }
        })()
        return new Response(readable, { status: 200, headers: sseHeaders(cors) })
      }

      // OpenAI-compatible
      const oaiBody: any = {
        model,
        messages: chatMessages,
        temperature: settings.temperature,
        max_tokens: settings.maxTokens,
        top_p: settings.topP,
        stream,
      }
      if (!stream) {
        let res: Response
        try {
          res = await fetch(`${base}/chat/completions`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json', ...(key ? { Authorization: `Bearer ${key}` } : {}) },
            body: JSON.stringify(oaiBody),
          })
        } catch (e: any) {
          return json({ error: e?.message || 'Network error.' }, 502, cors)
        }
        if (!res.ok) return await upstreamError(res, cors)
        const data: any = await res.json()
        const text = data?.choices?.[0]?.message?.content ?? ''
        return json({ text }, 200, cors)
      }
      let res: Response
      try {
        res = await fetch(`${base}/chat/completions`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', ...(key ? { Authorization: `Bearer ${key}` } : {}) },
          body: JSON.stringify(oaiBody),
        })
      } catch (e: any) {
        return json({ error: e?.message || 'Network error.' }, 502, cors)
      }
      if (!res.ok) return json({ error: await res.text() }, res.status, cors)
      const { readable, writable } = new TransformStream()
      const writer = writable.getWriter()
      const enc = new TextEncoder()
      ;(async () => {
        const reader = res.body!.getReader()
        const dec = new TextDecoder()
        let buf = ''
        try {
          while (true) {
            const { done, value } = await reader.read()
            if (done) break
            buf += dec.decode(value, { stream: true })
            const lines = buf.split('\n')
            buf = lines.pop() || ''
            for (const line of lines) {
              const t = line.trim()
              if (!t || !t.startsWith('data:')) continue
              const data = t.slice(5).trim()
              if (data === '[DONE]') continue
              try {
                const j = JSON.parse(data)
                const delta = j?.choices?.[0]?.delta?.content
                if (delta) await writer.write(enc.encode(`data: ${JSON.stringify({ delta })}\n\n`))
              } catch { /* ignore */ }
            }
          }
          await writer.write(enc.encode('data: [DONE]\n\n'))
        } catch (e: any) {
          await writer.write(enc.encode(`data: ${JSON.stringify({ error: e?.message || 'stream error' })}\n\n`))
        } finally {
          await writer.close()
        }
      })()
      return new Response(readable, { status: 200, headers: sseHeaders(cors) })
    }

    return json({ error: 'Not found' }, 404, cors)
  },
}
