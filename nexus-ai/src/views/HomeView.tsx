import { useUi } from '@/state/ui'
import { useChat } from '@/state/chat'
import { RobotMascot } from '@/components/RobotMascot'
import { Sparkles, Code2, PenTool, Search, Lightbulb } from 'lucide-react'

const SUGGESTED = [
  { text: 'Explain something complicated.', icon: Lightbulb },
  { text: 'Help me build an application.', icon: Code2 },
  { text: 'Write something for me.', icon: PenTool },
  { text: 'Generate creative ideas.', icon: Sparkles },
  { text: 'Help me understand code.', icon: Code2 },
  { text: 'Analyze a problem.', icon: Search },
]

export function HomeView() {
  const { setTab } = useUi()
  const { newConversation } = useChat()

  const startPrompt = (text: string) => {
    newConversation('general')
    setTab('chat')
    // store pending prompt
    sessionStorage.setItem('nexus.pendingPrompt', text)
  }

  return (
    <div className="page">
      <header className="row" style={{ justifyContent: 'space-between', marginBottom: 16 }}>
        <div>
          <h1 className="title-gradient" style={{ fontSize: 26, margin: 0, fontWeight: 800 }}>NEXUS AI</h1>
          <p style={{ color: 'var(--text-2)', fontSize: 13, margin: '4px 0 0' }}>Your futuristic personal AI.</p>
        </div>
        <RobotMascot size={72} />
      </header>

      <div className="glass" style={{ padding: 16, marginBottom: 16 }}>
        <p style={{ margin: 0, color: 'var(--text-2)', fontSize: 14 }}>
          Welcome back. NEXUS Core is ready.
        </p>
      </div>

      <div className="card" style={{ marginBottom: 16, cursor: 'pointer' }} onClick={() => setTab('chat')}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, color: 'var(--text-3)' }}>
          <Sparkles size={18} />
          <span>Ask NEXUS anything…</span>
        </div>
      </div>

      <div className="section-title">Suggested prompts</div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
        {SUGGESTED.map((s, i) => {
          const Icon = s.icon
          return (
            <button key={i} className="glass" style={{ padding: 12, textAlign: 'left', cursor: 'pointer', border: '1px solid var(--border)', background: 'var(--panel)', color: 'var(--text)' }} onClick={() => startPrompt(s.text)}>
              <Icon size={16} style={{ color: 'var(--purple-2)', marginBottom: 6 }} />
              <div style={{ fontSize: 13, fontWeight: 500 }}>{s.text}</div>
            </button>
          )
        })}
      </div>

      <div className="section-title">Quick tools</div>
      <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
        {['Summarize', 'Rewrite', 'Code help', 'Brainstorm'].map(t => (
          <button key={t} className="btn ghost" onClick={() => setTab('toolbox')}>{t}</button>
        ))}
      </div>

      <div className="section-title">AI Engine</div>
      <div className="glass" style={{ padding: 12, fontSize: 13, color: 'var(--text-2)', display: 'flex', alignItems: 'center', gap: 8 }}>
        <span style={{ width: 6, height: 6, borderRadius: '50%', background: 'var(--success)', display: 'inline-block' }} />
        NEXUS Core · Ready
      </div>
    </div>
  )
}