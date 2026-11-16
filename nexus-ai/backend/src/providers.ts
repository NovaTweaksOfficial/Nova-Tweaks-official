export type ProviderId = 'openai' | 'anthropic' | 'gemini' | 'openrouter' | 'pollinations' | 'custom'

export interface ChatSettings {
  temperature: number
  maxTokens: number
  topP: number
  stream: boolean
}

export interface ChatMessage {
  id?: string
  role: 'system' | 'user' | 'assistant'
  content: string
  createdAt?: number
}

export const DEFAULT_MODELS: Record<ProviderId, string[]> = {
  openai: ['gpt-4o-mini', 'gpt-4o', 'gpt-4.1', 'gpt-4.1-mini'],
  anthropic: ['claude-3-5-sonnet-20241022', 'claude-3-5-haiku-20241022', 'claude-3-opus-20240229'],
  gemini: ['gemini-2.0-flash', 'gemini-1.5-pro', 'gemini-1.5-flash'],
  openrouter: ['openai/gpt-4o-mini', 'anthropic/claude-3.5-sonnet', 'google/gemini-2.0-flash-001'],
  pollinations: ['openai-fast'],
  custom: [],
}

export function defaultBaseUrl(p: ProviderId): string {
  switch (p) {
    case 'openai': return 'https://api.openai.com/v1'
    case 'anthropic': return 'https://api.anthropic.com/v1'
    case 'gemini': return 'https://generativelanguage.googleapis.com/v1beta/openai'
    case 'openrouter': return 'https://openrouter.ai/api/v1'
    case 'pollinations': return 'https://text.pollinations.ai/openai'
    case 'custom': return ''
  }
}

export function apiKeyFor(env: any, p: ProviderId): string | undefined {
  switch (p) {
    case 'openai': return env.OPENAI_API_KEY
    case 'anthropic': return env.ANTHROPIC_API_KEY
    case 'gemini': return env.GEMINI_API_KEY
    case 'openrouter': return env.OPENROUTER_API_KEY
    case 'custom': return env.CUSTOM_API_KEY
    case 'pollinations': return undefined
  }
}

export function isOpenAICompat(p: ProviderId): boolean {
  return p !== 'anthropic'
}
