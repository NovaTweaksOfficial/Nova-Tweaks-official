import { makeOpenAICompat } from './openaiCompat'
import { anthropicAdapter } from './anthropic'
import type { ProviderAdapter } from './types'
import type { ProviderId } from '@/types'

const cache = new Map<ProviderId, ProviderAdapter>()

export function getAdapter(id: ProviderId): ProviderAdapter {
  if (cache.has(id)) return cache.get(id)!
  let adapter: ProviderAdapter
  if (id === 'anthropic') adapter = anthropicAdapter
  else adapter = makeOpenAICompat(id)
  cache.set(id, adapter)
  return adapter
}