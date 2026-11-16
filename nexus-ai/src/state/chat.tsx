import { createContext, useContext, useEffect, useState, useCallback, type ReactNode } from 'react'
import { load, save, uid } from '@/lib/storage'
import type { Conversation, ChatMessage, AIMode } from '@/types'
import { useSettings } from './settings'

interface Ctx {
  conversations: Conversation[]
  currentId: string | null
  current: Conversation | null
  newConversation: (mode?: AIMode) => Conversation
  select: (id: string | null) => void
  addMessage: (convId: string, msg: ChatMessage) => void
  updateMessage: (convId: string, msgId: string, content: string) => void
  removeMessage: (convId: string, msgId: string) => void
  rename: (id: string, title: string) => void
  remove: (id: string) => void
  search: (q: string) => Conversation[]
  clearAll: () => void
}

const ChatCtx = createContext<Ctx | null>(null)

export function ChatProvider({ children }: { children: ReactNode }) {
  const { settings } = useSettings()
  const [conversations, setConversations] = useState<Conversation[]>(() => load('conversations', []))
  const [currentId, setCurrentId] = useState<string | null>(null)

  // Persist whenever the conversation list changes. Using an effect (rather
  // than side effects inside mutators) keeps every update based on the latest
  // state and avoids stale-closure overwrites.
  useEffect(() => {
    try {
      if (settings.saveHistory) save('conversations', conversations)
      else save('conversations', [])
    } catch { /* storage failures are non-fatal */ }
  }, [conversations, settings.saveHistory])

  const newConversation = useCallback((mode: AIMode = 'general') => {
    const conv: Conversation = {
      id: uid(),
      title: 'New conversation',
      mode,
      messages: [],
      createdAt: Date.now(),
      updatedAt: Date.now(),
    }
    setConversations(prev => [conv, ...prev])
    setCurrentId(conv.id)
    return conv
  }, [])

  const select = useCallback((id: string | null) => setCurrentId(id), [])

  const addMessage = useCallback((convId: string, msg: ChatMessage) => {
    setConversations(prev => prev.map(c => c.id === convId
      ? { ...c, messages: [...c.messages, msg], updatedAt: Date.now() }
      : c))
  }, [])

  const updateMessage = useCallback((convId: string, msgId: string, content: string) => {
    setConversations(prev => prev.map(c => c.id === convId
      ? { ...c, messages: c.messages.map(m => m.id === msgId ? { ...m, content } : m), updatedAt: Date.now() }
      : c))
  }, [])

  const removeMessage = useCallback((convId: string, msgId: string) => {
    setConversations(prev => prev.map(c => c.id === convId
      ? { ...c, messages: c.messages.filter(m => m.id !== msgId), updatedAt: Date.now() }
      : c))
  }, [])

  const rename = useCallback((id: string, title: string) => {
    setConversations(prev => prev.map(c => c.id === id ? { ...c, title, updatedAt: Date.now() } : c))
  }, [])

  const remove = useCallback((id: string) => {
    setConversations(prev => prev.filter(c => c.id !== id))
    setCurrentId(prev => prev === id ? null : prev)
  }, [])

  const search = useCallback((q: string) => {
    const low = q.toLowerCase()
    return conversations.filter(c =>
      c.title.toLowerCase().includes(low) ||
      c.messages.some(m => m.content.toLowerCase().includes(low))
    )
  }, [conversations])

  const clearAll = useCallback(() => {
    setConversations([])
    setCurrentId(null)
  }, [])

  const current = conversations.find(c => c.id === currentId) ?? null

  return (
    <ChatCtx.Provider value={{ conversations, currentId, current, newConversation, select, addMessage, updateMessage, removeMessage, rename, remove, search, clearAll }}>
      {children}
    </ChatCtx.Provider>
  )
}

export function useChat() {
  const ctx = useContext(ChatCtx)
  if (!ctx) throw new Error('useChat outside provider')
  return ctx
}
