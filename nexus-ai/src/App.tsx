import { useEffect } from 'react'
import { useUi } from './state/ui'
import { useSettings } from './state/settings'
import { HomeView } from './views/HomeView'
import { ChatView } from './views/ChatView'
import { ToolboxView } from './views/ToolboxView'
import { HistoryView } from './views/HistoryView'
import { SettingsView } from './views/SettingsView'
import { Home, MessageSquare, Wrench, Clock, Settings } from 'lucide-react'

const TABS = [
  { id: 'home', label: 'Home', icon: Home },
  { id: 'chat', label: 'Chat', icon: MessageSquare },
  { id: 'toolbox', label: 'Toolbox', icon: Wrench },
  { id: 'history', label: 'History', icon: Clock },
  { id: 'settings', label: 'Settings', icon: Settings },
] as const

export default function App() {
  const { tab, setTab } = useUi()
  const { settings } = useSettings()
  useEffect(() => {
    document.documentElement.setAttribute('data-theme', settings.theme)
    document.documentElement.setAttribute('data-accent', settings.accent)
  }, [settings.theme, settings.accent])
  return (
    <div className="app-shell">
      <main style={{ flex: 1, overflow: 'auto' }}>
        {tab === 'home' && <HomeView />}
        {tab === 'chat' && <ChatView />}
        {tab === 'toolbox' && <ToolboxView />}
        {tab === 'history' && <HistoryView />}
        {tab === 'settings' && <SettingsView />}
      </main>
      <nav className="bottom-nav">
        {TABS.map(t => {
          const Icon = t.icon
          return (
            <button
              key={t.id}
              className={`nav-item ${tab === t.id ? 'active' : ''}`}
              onClick={() => setTab(t.id as any)}
            >
              <Icon size={22} />
              <span>{t.label}</span>
            </button>
          )
        })}
      </nav>
    </div>
  )
}