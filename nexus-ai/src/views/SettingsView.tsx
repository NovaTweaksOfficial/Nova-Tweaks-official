import { useState } from 'react'
import { useSettings } from '@/state/settings'
import { useChat } from '@/state/chat'
import { getAdapter } from '@/lib/providers'
import { Wifi, Check, X } from 'lucide-react'

export function SettingsView() {
  const { settings, update, selectedConfig } = useSettings()
  const { clearAll } = useChat()
  const [testResult, setTestResult] = useState<{ ok: boolean; message: string } | null>(null)
  const [testing, setTesting] = useState(false)

  const testConn = async () => {
    if (!selectedConfig) {
      setTestResult({ ok: false, message: 'NEXUS Core is not configured. Set the NEXUS Cloud Endpoint below.' })
      return
    }
    setTesting(true); setTestResult(null)
    const adapter = getAdapter(selectedConfig.provider)
    const runtimeCfg = {
      provider: selectedConfig.provider,
      baseUrl: selectedConfig.baseUrl,
      apiKey: selectedConfig.apiKey,
      model: settings.selectedModel || selectedConfig.model || '',
      mode: selectedConfig.mode,
      backendUrl: settings.backendUrl,
    }
    const r = await adapter.test(runtimeCfg)
    setTestResult(r)
    setTesting(false)
  }

  return (
    <div className="page">
      <h2 style={{ margin: '0 0 12px', fontSize: 22, fontWeight: 700 }}>Settings</h2>

      {/* AI Engine */}
      <div className="glass" style={{ padding: 14, marginBottom: 12 }}>
        <div className="row" style={{ justifyContent: 'space-between', marginBottom: 6 }}>
          <div style={{ fontWeight: 600 }}>NEXUS Core</div>
          <span style={{ fontSize: 11, color: 'var(--success)', display: 'flex', alignItems: 'center', gap: 4 }}>
            <span style={{ width: 6, height: 6, borderRadius: '50%', background: 'var(--success)', display: 'inline-block' }} />
            Ready
          </span>
        </div>
        <p style={{ fontSize: 12, color: 'var(--text-3)', margin: '0 0 10px' }}>
          NEXUS Core is included and ready to use. No account, setup, or API key required.
        </p>
        <button className="btn" onClick={testConn} disabled={testing}>
          <Wifi size={14} /> {testing ? 'Checking…' : 'Check connection'}
        </button>
        {testResult && (
          <div style={{ marginTop: 8, fontSize: 13, color: testResult.ok ? 'var(--success)' : 'var(--danger)', display: 'flex', alignItems: 'center', gap: 6 }}>
            {testResult.ok ? <Check size={14} /> : <X size={14} />}
            {testResult.ok ? 'NEXUS Core is online.' : 'NEXUS Core is temporarily unavailable.'}
          </div>
        )}
      </div>

      {/* Cloud endpoint (advanced) */}
      <div className="glass" style={{ padding: 14, marginBottom: 12 }}>
        <div style={{ fontWeight: 600, marginBottom: 6 }}>NEXUS Cloud Endpoint</div>
        <p style={{ fontSize: 12, color: 'var(--text-3)', marginBottom: 8 }}>
          Advanced. The secure endpoint that powers NEXUS Core. Leave the default unless you run your own deployment.
        </p>
        <input className="input" value={settings.backendUrl} onChange={e => update({ backendUrl: e.target.value })} placeholder="https://your-nexus-endpoint.workers.dev" />
      </div>

      {/* Generation settings */}
      <div className="glass" style={{ padding: 14, marginBottom: 12 }}>
        <div style={{ fontWeight: 600, marginBottom: 8 }}>Generation</div>
        <label style={{ fontSize: 12, color: 'var(--text-2)' }}>Temperature: {settings.generation.temperature}</label>
        <input type="range" min="0" max="2" step="0.1" value={settings.generation.temperature} onChange={e => update({ generation: { ...settings.generation, temperature: parseFloat(e.target.value) } })} style={{ width: '100%' }} />
        <label style={{ fontSize: 12, color: 'var(--text-2)', marginTop: 8, display: 'block' }}>Max tokens: {settings.generation.maxTokens}</label>
        <input type="range" min="64" max="4096" step="64" value={settings.generation.maxTokens} onChange={e => update({ generation: { ...settings.generation, maxTokens: parseInt(e.target.value) } })} style={{ width: '100%' }} />
        <div className="row" style={{ marginTop: 8, gap: 8 }}>
          <label style={{ fontSize: 12, color: 'var(--text-2)' }}>Streaming</label>
          <input type="checkbox" checked={settings.generation.stream} onChange={e => update({ generation: { ...settings.generation, stream: e.target.checked } })} />
        </div>
      </div>

      {/* Theme & accent */}
      <div className="glass" style={{ padding: 14, marginBottom: 12 }}>
        <div style={{ fontWeight: 600, marginBottom: 8 }}>Appearance</div>
        <div style={{ fontSize: 12, color: 'var(--text-2)', marginBottom: 4 }}>Theme</div>
        <div style={{ display: 'flex', gap: 6, marginBottom: 8 }}>
          {(['dark', 'darker', 'midnight'] as const).map(t => (
            <button key={t} className={`btn ${settings.theme === t ? 'primary' : 'ghost'}`} style={{ padding: '4px 10px', fontSize: 12 }} onClick={() => update({ theme: t })}>{t}</button>
          ))}
        </div>
        <div style={{ fontSize: 12, color: 'var(--text-2)', marginBottom: 4 }}>Accent</div>
        <div style={{ display: 'flex', gap: 6 }}>
          {(['purple', 'blue', 'cyan', 'pink'] as const).map(a => (
            <button key={a} className={`btn ${settings.accent === a ? 'primary' : 'ghost'}`} style={{ padding: '4px 10px', fontSize: 12 }} onClick={() => update({ accent: a })}>{a}</button>
          ))}
        </div>
      </div>

      {/* Privacy */}
      <div className="glass" style={{ padding: 14, marginBottom: 12 }}>
        <div style={{ fontWeight: 600, marginBottom: 8 }}>Privacy & Data</div>
        <div className="row" style={{ gap: 8 }}>
          <label style={{ fontSize: 12, color: 'var(--text-2)' }}>Save chat history locally</label>
          <input type="checkbox" checked={settings.saveHistory} onChange={e => update({ saveHistory: e.target.checked })} />
        </div>
        <button className="btn danger" style={{ marginTop: 10 }} onClick={() => { if (confirm('Clear all conversations?')) clearAll() }}>Clear all history</button>
      </div>

      <div className="glass" style={{ padding: 14, marginBottom: 12 }}>
        <div style={{ fontWeight: 600, marginBottom: 6 }}>Install as App (iPhone)</div>
        <ol style={{ fontSize: 12, color: 'var(--text-2)', paddingLeft: 18, margin: 0, lineHeight: 1.7 }}>
          <li>Open this site in Safari.</li>
          <li>Tap the Share button.</li>
          <li>Choose "Add to Home Screen".</li>
          <li>Launch NEXUS AI from your Home Screen.</li>
        </ol>
      </div>

      <div className="glass" style={{ padding: 14 }}>
        <div style={{ fontWeight: 600, marginBottom: 4 }}>About NEXUS AI</div>
        <div style={{ fontSize: 12, color: 'var(--text-3)' }}>Version 1.0.0 · NEXUS Core engine.</div>
      </div>
    </div>
  )
}
