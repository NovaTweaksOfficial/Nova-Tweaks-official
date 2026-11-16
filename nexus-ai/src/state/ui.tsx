import { createContext, useContext, useState, type ReactNode } from 'react'
import type { TabId, AIMode } from '@/types'

interface Ctx {
  tab: TabId
  setTab: (t: TabId) => void
  mode: AIMode
  setMode: (m: AIMode) => void
}

const UiCtx = createContext<Ctx | null>(null)

export function UiProvider({ children }: { children: ReactNode }) {
  const [tab, setTab] = useState<TabId>('home')
  const [mode, setMode] = useState<AIMode>('general')
  return <UiCtx.Provider value={{ tab, setTab, mode, setMode }}>{children}</UiCtx.Provider>
}

export function useUi() {
  const ctx = useContext(UiCtx)
  if (!ctx) throw new Error('useUi outside provider')
  return ctx
}