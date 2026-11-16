import type { ProviderAdapter, ChatOptions, RuntimeConfig } from './types'
import { providerInfo as infoOf } from './registry'

// Anthropic uses its own API; implement native adapter.
const info = infoOf('anthropic')

function baseUrl(cfg: RuntimeConfig): string {
  return (cfg.baseUrl || info.defaultBaseUrl).replace(/\/$/, '')
}

function headers(cfg: RuntimeConfig): Record<string, string> {
  const h: Record<string, string> = { 'Content-Type': 'application/json', 'anthropic-version': '2023-06-01' }
  if (cfg.apiKey) h['x-api-key'] = cfg.apiKey
  return h
}

export const anthropicAdapter: ProviderAdapter = {
  info,
  async chat(cfg, opts) {
    if (cfg.mode === 'backend' && cfg.backendUrl) {
      return callAnthropicBackend(cfg, opts)
    }
    const url = `${baseUrl(cfg)}/messages`
    const messages = opts.messages
      .filter(m => m.role !== 'system')
      .map(m => ({ role: m.role === 'assistant' ? 'assistant' : 'user', content: m.content }))
    const system = opts.systemPrompt || opts.messages.find(m => m.role === 'system')?.content
    const body: any = {
      model: opts.model,
      max_tokens: opts.settings.maxTokens,
      temperature: opts.settings.temperature,
      top_p: opts.settings.topP,
      messages,
      stream: opts.settings.stream,
    }
    if (system) body.system = system

    if (!opts.settings.stream) {
      const res = await fetch(url, { method: 'POST', headers: headers(cfg), body: JSON.stringify(body), signal: opts.signal })
      if (!res.ok) throw new Error(await res.text())
      const data = await res.json()
      const text = (data?.content || []).map((c: any) => c.text || '').join('')
      opts.onChunk?.(text)
      return text
    }
    const res = await fetch(url, { method: 'POST', headers: headers(cfg), body: JSON.stringify(body), signal: opts.signal })
    if (!res.ok) throw new Error(await res.text())
    const reader = res.body!.getReader()
    const decoder = new TextDecoder()
    let full = ''
    let buf = ''
    while (true) {
      const { done, value } = await reader.read()
      if (done) break
      buf += decoder.decode(value, { stream: true })
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
            full += json.delta.text
            opts.onChunk?.(full)
          }
        } catch { /* ignore */ }
      }
    }
    return full
  },
  async listModels() {
    return info.defaultModels
  },
  async test(cfg) {
    if (cfg.mode === 'backend' && cfg.backendUrl) {
      return testAnthropicBackend(cfg)
    }
    // Anthropic has no models endpoint; do a tiny messages call
    try {
      const res = await fetch(`${baseUrl(cfg)}/messages`, {
        method: 'POST',
        headers: headers(cfg),
        body: JSON.stringify({ model: cfg.model || info.defaultModels[0], max_tokens: 8, messages: [{ role: 'user', content: 'ping' }] }),
      })
      if (res.ok) return { ok: true, message: 'Connection successful.' }
      const txt = await res.text()
      return { ok: false, message: `HTTP ${res.status}: ${txt}` }
    } catch (e: any) {
      return { ok: false, message: e?.message || 'Connection failed.' }
    }
  },
}

async function callAnthropicBackend(cfg: RuntimeConfig, opts: ChatOptions): Promise<string> {
  // Use generic backend /api/chat with provider=anthropic
  const url = `${cfg.backendUrl!.replace(/\/$/, '')}/api/chat`
  const body = {
    provider: 'anthropic',
    model: opts.model,
    messages: opts.messages,
    settings: opts.settings,
    systemPrompt: opts.systemPrompt,
    stream: opts.settings.stream,
  }
  if (!opts.settings.stream) {
    const res = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body), signal: opts.signal })
    if (!res.ok) throw new Error(await res.text())
    const data = await res.json()
    const text = data?.text ?? ''
    opts.onChunk?.(text)
    return text
  }
  const res = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body), signal: opts.signal })
  if (!res.ok) throw new Error(await res.text())
  const reader = res.body!.getReader()
  const decoder = new TextDecoder()
  let full = ''
  let buf = ''
  while (true) {
    const { done, value } = await reader.read()
    if (done) break
    buf += decoder.decode(value, { stream: true })
    const lines = buf.split('\n')
    buf = lines.pop() || ''
    for (const line of lines) {
      const t = line.trim()
      if (!t || !t.startsWith('data:')) continue
      const data = t.slice(5).trim()
      if (data === '[DONE]') continue
      try {
        const json = JSON.parse(data)
        if (json.error) throw new Error(json.error)
        if (typeof json.delta === 'string') { full += json.delta; opts.onChunk?.(full) }
        if (json.text) { full = json.text; opts.onChunk?.(full) }
      } catch (e) {
        if (e instanceof Error && e.message && !e.message.includes('JSON')) throw e
      }
    }
  }
  return full
}

async function testAnthropicBackend(cfg: RuntimeConfig): Promise<{ ok: boolean; message: string }> {
  try {
    const res = await fetch(`${cfg.backendUrl!.replace(/\/$/, '')}/api/test`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ provider: 'anthropic', baseUrl: cfg.baseUrl }),
    })
    const data = await res.json()
    return { ok: !!data?.ok, message: data?.message || (res.ok ? 'OK' : 'Failed') }
  } catch (e: any) {
    return { ok: false, message: e?.message || 'Backend unreachable.' }
  }
}