import type { ProviderAdapter, ChatOptions, RuntimeConfig } from './types'
import type { ProviderId } from '@/types'
import { providerInfo as infoOf } from './registry'
import type { ProviderInfo } from './types'

function baseUrl(cfg: RuntimeConfig, info: ProviderInfo): string {
  return (cfg.baseUrl || info.defaultBaseUrl).replace(/\/$/, '')
}

function headers(cfg: RuntimeConfig): Record<string, string> {
  const h: Record<string, string> = { 'Content-Type': 'application/json' }
  if (cfg.apiKey) h['Authorization'] = `Bearer ${cfg.apiKey}`
  return h
}

export function makeOpenAICompat(id: ProviderId): ProviderAdapter {
  const info = infoOf(id)
  return {
    info,
    async chat(cfg, opts) {
      // backend mode: route through backend
      if (cfg.mode === 'backend' && cfg.backendUrl) {
        return chatViaBackend(cfg, opts)
      }
      const url = `${baseUrl(cfg, info)}/chat/completions`
      const messages = opts.systemPrompt
        ? [{ role: 'system', content: opts.systemPrompt }, ...opts.messages.map(m => ({ role: m.role, content: m.content }))]
        : opts.messages.map(m => ({ role: m.role, content: m.content }))
      const body = {
        model: opts.model,
        messages,
        temperature: opts.settings.temperature,
        max_tokens: opts.settings.maxTokens,
        top_p: opts.settings.topP,
        stream: opts.settings.stream,
      }
      if (!opts.settings.stream) {
        const res = await fetch(url, { method: 'POST', headers: headers(cfg), body: JSON.stringify(body), signal: opts.signal })
        if (!res.ok) throw new Error(await res.text())
        const data = await res.json()
        const text = data?.choices?.[0]?.message?.content ?? ''
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
          if (!t || !t.startsWith('data:')) continue
          const data = t.slice(5).trim()
          if (data === '[DONE]') continue
          try {
            const json = JSON.parse(data)
            const delta = json?.choices?.[0]?.delta?.content
            if (delta) { full += delta; opts.onChunk?.(full) }
          } catch { /* ignore */ }
        }
      }
      return full
    },
    async listModels(cfg) {
      if (cfg.mode === 'backend' && cfg.backendUrl) {
        return listModelsViaBackend(cfg)
      }
      try {
        const res = await fetch(`${baseUrl(cfg, info)}/models`, { headers: headers(cfg) })
        if (!res.ok) return info.defaultModels
        const data = await res.json()
        const ids = (data?.data || []).map((m: any) => m.id).filter(Boolean)
        return ids.length ? ids : info.defaultModels
      } catch {
        return info.defaultModels
      }
    },
    async test(cfg) {
      if (cfg.mode === 'backend' && cfg.backendUrl) {
        return testViaBackend(cfg)
      }
      try {
        // Keyless engines have no models endpoint; verify with a tiny request.
        if (!info.requiresKey) {
          const res = await fetch(`${baseUrl(cfg, info)}/chat/completions`, {
            method: 'POST',
            headers: headers(cfg),
            body: JSON.stringify({
              model: info.defaultModels[0],
              messages: [{ role: 'user', content: 'ping' }],
              max_tokens: 1,
            }),
          })
          if (res.ok) return { ok: true, message: 'Connection successful.' }
          return { ok: false, message: `HTTP ${res.status}: ${await res.text()}` }
        }
        const res = await fetch(`${baseUrl(cfg, info)}/models`, { headers: headers(cfg) })
        if (res.ok) return { ok: true, message: 'Connection successful.' }
        return { ok: false, message: `HTTP ${res.status}: ${await res.text()}` }
      } catch (e: any) {
        return { ok: false, message: e?.message || 'Connection failed.' }
      }
    },
  }
}

// ---- backend helpers ----
async function chatViaBackend(cfg: RuntimeConfig, opts: ChatOptions): Promise<string> {
  const url = `${cfg.backendUrl!.replace(/\/$/, '')}/api/chat`
  const body = {
    provider: cfg.provider,
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
        const delta = json?.delta
        if (typeof delta === 'string') { full += delta; opts.onChunk?.(full) }
        if (json?.text) { full = json.text; opts.onChunk?.(full) }
      } catch (e) {
        // rethrow non-parse errors? ignore parse errors
        if (e instanceof Error && e.message && !e.message.includes('JSON')) throw e
      }
    }
  }
  return full
}

async function listModelsViaBackend(cfg: RuntimeConfig): Promise<string[]> {
  try {
    const res = await fetch(`${cfg.backendUrl!.replace(/\/$/, '')}/api/models`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ provider: cfg.provider, baseUrl: cfg.baseUrl }),
    })
    if (!res.ok) return infoOf(cfg.provider).defaultModels
    const data = await res.json()
    return data?.models?.length ? data.models : infoOf(cfg.provider).defaultModels
  } catch {
    return infoOf(cfg.provider).defaultModels
  }
}

async function testViaBackend(cfg: RuntimeConfig): Promise<{ ok: boolean; message: string }> {
  try {
    const res = await fetch(`${cfg.backendUrl!.replace(/\/$/, '')}/api/test`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ provider: cfg.provider, baseUrl: cfg.baseUrl }),
    })
    const data = await res.json()
    return { ok: !!data?.ok, message: data?.message || (res.ok ? 'OK' : 'Failed') }
  } catch (e: any) {
    return { ok: false, message: e?.message || 'Backend unreachable.' }
  }
}