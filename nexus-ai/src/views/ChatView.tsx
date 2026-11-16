import { useEffect, useRef, useState } from 'react'
import { useUi } from '@/state/ui'
import { useChat } from '@/state/chat'
import { useSettings } from '@/state/settings'
import { getAdapter } from '@/lib/providers'
import { NEXUS_IDENTITY } from '@/lib/identity'
import { uid } from '@/lib/storage'
import type { ChatMessage } from '@/types'
import { Send, Square, RotateCcw, Copy, Check, ChevronDown, MessageCircle, Code2, Sparkles, GraduationCap, Search } from 'lucide-react'
import ReactMarkdown from 'react-markdown'
import remarkGfm from 'remark-gfm'
import rehypeHighlight from 'rehype-highlight'

const MODES = [
  { id: 'general', label: 'General', desc: 'Everyday questions', icon: MessageCircle },
  { id: 'coding', label: 'Coding', desc: 'Programming & debugging', icon: Code2 },
  { id: 'creative', label: 'Creative', desc: 'Ideas & writing', icon: Sparkles },
  { id: 'study', label: 'Study', desc: 'Learning & tutoring', icon: GraduationCap },
  { id: 'research', label: 'Research', desc: 'Research assistance', icon: Search },
] as const

const MODE_PROMPTS: Record<string, string> = {
  general: `${NEXUS_IDENTITY} Be friendly and concise.`,
  coding: `${NEXUS_IDENTITY} You are in Coding mode. Provide correct, well-explained code. Use markdown code blocks with language tags. Debug carefully.`,
  creative: `${NEXUS_IDENTITY} You are in Creative mode. Be imaginative, vivid, and inspiring.`,
  study: `${NEXUS_IDENTITY} You are in Study mode. Teach clearly, step by step, with examples and checks for understanding.`,
  research: `${NEXUS_IDENTITY} You are in Research mode. Organize information, cite reasoning, and be thorough.`,
}

export function ChatView() {
  const { mode, setMode } = useUi()
  const { current, newConversation, addMessage, updateMessage, removeMessage, rename } = useChat()
  const { settings, selectedConfig: cfg } = useSettings()
  const [input, setInput] = useState('')
  const [streaming, setStreaming] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const abortRef = useRef<AbortController | null>(null)
  const scrollRef = useRef<HTMLDivElement>(null)
  const [copiedId, setCopiedId] = useState<string | null>(null)
  const [showModeMenu, setShowModeMenu] = useState(false)

  // pending prompt from home
  const autoSendRef = useRef<string | null>(null)
  useEffect(() => {
    const p = sessionStorage.getItem('nexus.pendingPrompt')
    if (p) {
      sessionStorage.removeItem('nexus.pendingPrompt')
      setInput(p)
      autoSendRef.current = p
    }
  }, [])

  // Auto-send a suggested prompt once the conversation exists.
  useEffect(() => {
    if (current && autoSendRef.current) {
      const p = autoSendRef.current
      autoSendRef.current = null
      send(p)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [current])

  // ensure conversation
  useEffect(() => {
    if (!current) newConversation(mode)
  }, [current, newConversation, mode])

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: 'smooth' })
  }, [current?.messages, streaming])

  const conv = current

  const send = async (overrideText?: string) => {
    const text = (overrideText ?? input).trim()
    if (!text || streaming) return
    if (!conv) return
    setError(null)
    setInput('')
    const userMsg: ChatMessage = { id: uid(), role: 'user', content: text, createdAt: Date.now() }
    addMessage(conv.id, userMsg)

    const assistantMsg: ChatMessage = { id: uid(), role: 'assistant', content: '', createdAt: Date.now() }
    addMessage(conv.id, assistantMsg)

    if (conv.messages.length === 0) {
      rename(conv.id, text.slice(0, 40))
    }

    const config = cfg
    if (!config) {
      updateMessage(conv.id, assistantMsg.id, 'No AI provider configured. Go to Settings to configure a provider and model.')
      return
    }
    const adapter = getAdapter(config.provider)
    const runtimeCfg = {
      provider: config.provider,
      baseUrl: config.baseUrl,
      apiKey: config.apiKey,
      model: settings.selectedModel || config.model || '',
      mode: config.mode,
      backendUrl: settings.backendUrl,
    }
    const model = runtimeCfg.model || config.model || adapter.info.defaultModels[0] || (await adapter.listModels(runtimeCfg))[0]
    if (!model) {
      updateMessage(conv.id, assistantMsg.id, 'No model selected. Choose a model in Settings.')
      return
    }

    const msgs = [...conv.messages, userMsg].map(m => ({ id: m.id, role: m.role, content: m.content, createdAt: m.createdAt }))
    // remove the empty assistant we added from history sent to model
    const historyForModel = msgs.filter(m => m.id !== assistantMsg.id)

    setStreaming(true)
    const ac = new AbortController()
    abortRef.current = ac
    try {
      await adapter.chat(runtimeCfg, {
        messages: historyForModel,
        model,
        settings: settings.generation,
        systemPrompt: MODE_PROMPTS[mode],
        signal: ac.signal,
        onChunk: (full) => updateMessage(conv.id, assistantMsg.id, full),
      })
    } catch (e: any) {
      if (e?.name === 'AbortError') {
        // keep partial
      } else {
        const msg = e?.message || 'Request failed.'
        setError(msg)
        updateMessage(conv.id, assistantMsg.id, `⚠️ ${msg}`)
      }
    } finally {
      setStreaming(false)
      abortRef.current = null
    }
  }

  const stop = () => abortRef.current?.abort()

  const regenerate = async (assistantId: string) => {
    if (!conv || streaming) return
    const idx = conv.messages.findIndex(m => m.id === assistantId)
    if (idx < 0) return
    // remove the assistant message
    removeMessage(conv.id, assistantId)
    // find preceding user message
    let userIdx = idx - 1
    while (userIdx >= 0 && conv.messages[userIdx].role !== 'user') userIdx--
    const userMsg = userIdx >= 0 ? conv.messages[userIdx] : null
    if (!userMsg) return
    // remove original user message to avoid duplicate when re-sending
    removeMessage(conv.id, userMsg.id)
    await send(userMsg.content)
  }

  const copy = async (id: string, content: string) => {
    try { await navigator.clipboard.writeText(content); setCopiedId(id); setTimeout(() => setCopiedId(null), 1500) } catch { /* */ }
  }

  return (
    <div className="page" style={{ display: 'flex', flexDirection: 'column', height: 'calc(100dvh - 72px - var(--safe-top))', padding: 0 }}>
      {/* header */}
      <div className="glass" style={{ margin: 12, padding: 10, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ position: 'relative' }}>
          <button className="btn ghost" onClick={() => setShowModeMenu(v => !v)} style={{ padding: '6px 10px', gap: 6 }}>
            {(() => { const M = MODES.find(m => m.id === mode); const I = M?.icon; return I ? <I size={14} style={{ color: 'var(--purple-2)' }} /> : null })()}
            {MODES.find(m => m.id === mode)?.label} <ChevronDown size={14} />
          </button>
          {showModeMenu && (
            <div className="glass-strong" style={{ position: 'absolute', top: 40, left: 0, zIndex: 20, minWidth: 220, padding: 6 }}>
              {MODES.map(m => {
                const Icon = m.icon
                return (
                <button key={m.id} className="btn ghost" style={{ width: '100%', justifyContent: 'flex-start', padding: '8px 10px', gap: 10 }} 
                  onClick={() => { setMode(m.id as any); setShowModeMenu(false) }}>
                  <Icon size={16} style={{ color: 'var(--purple-2)' }} />
                  <div>
                    <div style={{ fontWeight: 600, fontSize: 13 }}>{m.label}</div>
                    <div style={{ fontSize: 11, color: 'var(--text-3)' }}>{m.desc}</div>
                  </div>
                </button>
                )
              })}
            </div>
          )}
        </div>
        <button className="btn ghost" onClick={() => newConversation(mode)} style={{ padding: '6px 10px' }}>New</button>
      </div>

      {/* messages */}
      <div ref={scrollRef} style={{ flex: 1, overflowY: 'auto', padding: '0 12px 12px' }}>
        {(!conv || conv.messages.length === 0) && (
          <div className="empty-state">
            <div style={{ fontSize: 18, marginBottom: 8 }}>Start a conversation</div>
            <div style={{ fontSize: 13 }}>Type a message below.</div>
          </div>
        )}
        {conv?.messages.map(m => (
          <div key={m.id} style={{ display: 'flex', marginBottom: 10, justifyContent: m.role === 'user' ? 'flex-end' : 'flex-start' }}>
            <div className={`msg-bubble ${m.role === 'user' ? 'msg-user' : 'msg-assistant'}`}>
              {m.role === 'assistant' ? (
                <div className="markdown">
                  <ReactMarkdown remarkPlugins={[remarkGfm]} rehypePlugins={[rehypeHighlight]}>
                    {m.content || (streaming ? '...' : '')}
                  </ReactMarkdown>
                </div>
              ) : (
                <div style={{ whiteSpace: 'pre-wrap' }}>{m.content}</div>
              )}
              {m.role === 'assistant' && m.content && (
                <div style={{ marginTop: 6, display: 'flex', gap: 6 }}>
                  <button className="btn ghost" style={{ padding: '2px 6px', fontSize: 11 }} onClick={() => copy(m.id, m.content)}>
                    {copiedId === m.id ? <Check size={12} /> : <Copy size={12} />} Copy
                  </button>
                  <button className="btn ghost" style={{ padding: '2px 6px', fontSize: 11 }} onClick={() => regenerate(m.id)} disabled={streaming}>
                    <RotateCcw size={12} /> Regenerate
                  </button>
                </div>
              )}
            </div>
          </div>
        ))}
        {streaming && (
          <div style={{ display: 'flex', gap: 4, padding: 8 }}>
            <span className="typing-dot" /><span className="typing-dot" /><span className="typing-dot" />
          </div>
        )}
        {error && <div style={{ color: 'var(--danger)', fontSize: 13, padding: 8 }}>{error}</div>}
      </div>

      {/* input */}
      <div style={{ padding: 12, borderTop: '1px solid var(--border)', background: 'rgba(8,8,16,0.85)', backdropFilter: 'blur(12px)' }}>
        <div style={{ display: 'flex', gap: 8, alignItems: 'flex-end' }}>
          <textarea
            className="textarea"
            rows={1}
            value={input}
            onChange={e => setInput(e.target.value)}
            onKeyDown={e => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send() } }}
            placeholder="Message NEXUS AI…"
            style={{ flex: 1, minHeight: 44, maxHeight: 120 }}
          />
          {streaming ? (
            <button className="btn danger" onClick={stop} style={{ height: 44 }}><Square size={16} /> Stop</button>
          ) : (
            <button className="btn primary" onClick={() => send()} style={{ height: 44 }}><Send size={16} /></button>
          )}
        </div>
      </div>
    </div>
  )
}

