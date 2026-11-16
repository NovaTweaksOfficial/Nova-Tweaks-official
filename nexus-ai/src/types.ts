export type ProviderId = 'openai' | 'anthropic' | 'gemini' | 'openrouter' | 'pollinations' | 'custom'

export type AIMode = 'general' | 'coding' | 'creative' | 'study' | 'research'

export type MessageRole = 'system' | 'user' | 'assistant'

export interface ChatMessage {
  id: string
  role: MessageRole
  content: string
  createdAt: number
}

export interface Conversation {
  id: string
  title: string
  mode: AIMode
  providerConfigId?: string
  model?: string
  messages: ChatMessage[]
  createdAt: number
  updatedAt: number
}

export interface ProviderConfig {
  id: string
  provider: ProviderId
  label: string
  baseUrl?: string
  model?: string
  // direct (insecure) mode only
  apiKey?: string
  mode: 'backend' | 'direct'
}

export interface GenerationSettings {
  temperature: number
  maxTokens: number
  topP: number
  stream: boolean
}

export interface AppSettings {
  backendUrl: string
  directMode: boolean
  providerConfigs: ProviderConfig[]
  selectedConfigId: string | null
  selectedModel: string | null
  generation: GenerationSettings
  theme: 'dark' | 'darker' | 'midnight'
  accent: 'purple' | 'blue' | 'cyan' | 'pink'
  fontSize: 'sm' | 'md' | 'lg'
  reducedMotion: boolean
  saveHistory: boolean
}

export type TabId = 'home' | 'chat' | 'toolbox' | 'history' | 'settings'

export interface ToolDef {
  id: string
  name: string
  description: string
  icon: string
  systemPrompt: string
  inputLabel: string
  inputPlaceholder: string
  outputLabel: string
}