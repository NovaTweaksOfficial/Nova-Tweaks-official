import React from 'react'
import ReactDOM from 'react-dom/client'
import { SettingsProvider } from './state/settings'
import { ChatProvider } from './state/chat'
import { UiProvider } from './state/ui'
import App from './App'
import './styles/app.css'
import 'highlight.js/styles/github-dark.css'

if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('./sw.js').catch(() => { /* ignore */ })
  })
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <SettingsProvider>
      <ChatProvider>
        <UiProvider>
          <App />
        </UiProvider>
      </ChatProvider>
    </SettingsProvider>
  </React.StrictMode>
)