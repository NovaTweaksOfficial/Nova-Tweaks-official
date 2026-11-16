import type { ProviderId } from '@/types'
import type { ProviderInfo } from './types'

export const PROVIDER_INFO: Record<ProviderId, ProviderInfo> = {
  openai: {
    id: 'openai',
    name: 'NEXUS Core',
    description: 'NEXUS high-speed engine.',
    defaultBaseUrl: 'https://api.openai.com/v1',
    requiresKey: true,
    supportsStreaming: true,
    supportsModelList: true,
    defaultModels: ['gpt-4o-mini', 'gpt-4o', 'gpt-4.1', 'gpt-4.1-mini'],
  },
  anthropic: {
    id: 'anthropic',
    name: 'NEXUS Reason',
    description: 'NEXUS deep-reasoning engine.',
    defaultBaseUrl: 'https://api.anthropic.com/v1',
    requiresKey: true,
    supportsStreaming: true,
    supportsModelList: false,
    defaultModels: ['claude-3-5-sonnet-20241022', 'claude-3-5-haiku-20241022', 'claude-3-opus-20240229'],
  },
  gemini: {
    id: 'gemini',
    name: 'NEXUS Vision',
    description: 'NEXUS multimodal engine.',
    defaultBaseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    requiresKey: true,
    supportsStreaming: true,
    supportsModelList: true,
    defaultModels: ['gemini-2.0-flash', 'gemini-1.5-pro', 'gemini-1.5-flash'],
  },
  openrouter: {
    id: 'openrouter',
    name: 'NEXUS Multi',
    description: 'NEXUS multi-engine router.',
    defaultBaseUrl: 'https://openrouter.ai/api/v1',
    requiresKey: true,
    supportsStreaming: true,
    supportsModelList: true,
    defaultModels: ['openai/gpt-4o-mini', 'anthropic/claude-3.5-sonnet', 'google/gemini-2.0-flash-001'],
  },
  custom: {
    id: 'custom',
    name: 'NEXUS Custom',
    description: 'Custom NEXUS engine endpoint.',
    defaultBaseUrl: 'http://localhost:11434/v1',
    requiresKey: false,
    supportsStreaming: true,
    supportsModelList: false,
    defaultModels: [],
  },
  pollinations: {
    id: 'pollinations',
    name: 'NEXUS Core',
    description: 'NEXUS default engine. Zero configuration required.',
    defaultBaseUrl: 'https://text.pollinations.ai/openai',
    requiresKey: false,
    supportsStreaming: true,
    supportsModelList: false,
    defaultModels: ['openai-fast'],
  },
}

export function providerInfo(id: ProviderId) {
  return PROVIDER_INFO[id]
}