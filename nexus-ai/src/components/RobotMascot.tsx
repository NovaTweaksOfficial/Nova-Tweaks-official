import { motion } from 'framer-motion'

export function RobotMascot({ size = 96, className = '' }: { size?: number; className?: string }) {
  return (
    <motion.div
      className={`float-anim ${className}`}
      style={{ width: size, height: size, position: 'relative' }}
      initial={{ opacity: 0, scale: 0.8 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{ duration: 0.6 }}
    >
      <svg viewBox="0 0 120 120" width={size} height={size} xmlns="http://www.w3.org/2000/svg">
        <defs>
          <linearGradient id="metal" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0%" stopColor="#2a2a4a" />
            <stop offset="50%" stopColor="#1a1a30" />
            <stop offset="100%" stopColor="#0f0f1e" />
          </linearGradient>
          <linearGradient id="metalHi" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#5a5a8a" />
            <stop offset="100%" stopColor="#1a1a30" />
          </linearGradient>
          <radialGradient id="eyeGlow" cx="50%" cy="50%" r="50%">
            <stop offset="0%" stopColor="#a78bfa" />
            <stop offset="60%" stopColor="#8b5cf6" />
            <stop offset="100%" stopColor="#3b82f6" />
          </radialGradient>
          <filter id="glow" x="-50%" y="-50%" width="200%" height="200%">
            <feGaussianBlur stdDeviation="3" result="b" />
            <feMerge><feMergeNode in="b" /><feMergeNode in="SourceGraphic" /></feMerge>
          </filter>
          <filter id="softGlow" x="-50%" y="-50%" width="200%" height="200%">
            <feGaussianBlur stdDeviation="1.5" result="b" />
            <feMerge><feMergeNode in="b" /><feMergeNode in="SourceGraphic" /></feMerge>
          </filter>
        </defs>

        {/* antenna */}
        <line x1="60" y1="14" x2="60" y2="26" stroke="#8b5cf6" strokeWidth="2" filter="url(#softGlow)" />
        <circle cx="60" cy="12" r="4" fill="url(#eyeGlow)" filter="url(#glow)">
          <animate attributeName="r" values="4;5;4" dur="2s" repeatCount="indefinite" />
        </circle>

        {/* head */}
        <rect x="24" y="26" width="72" height="68" rx="18" fill="url(#metal)" stroke="#8b5cf6" strokeWidth="1.5" />
        <rect x="24" y="26" width="72" height="68" rx="18" fill="none" stroke="rgba(139,92,246,0.4)" strokeWidth="1" />

        {/* top highlight */}
        <rect x="30" y="30" width="60" height="8" rx="4" fill="url(#metalHi)" opacity="0.5" />

        {/* face panel */}
        <rect x="32" y="40" width="56" height="40" rx="12" fill="#0a0a18" stroke="rgba(139,92,246,0.25)" />

        {/* eyes */}
        <g filter="url(#glow)">
          <rect x="38" y="50" width="16" height="12" rx="4" fill="url(#eyeGlow)">
            <animate attributeName="opacity" values="1;0.6;1" dur="3s" repeatCount="indefinite" />
          </rect>
          <rect x="66" y="50" width="16" height="12" rx="4" fill="url(#eyeGlow)">
            <animate attributeName="opacity" values="1;0.6;1" dur="3s" repeatCount="indefinite" />
          </rect>
        </g>
        {/* eye shine */}
        <rect x="40" y="52" width="6" height="3" rx="1.5" fill="#fff" opacity="0.7" />
        <rect x="68" y="52" width="6" height="3" rx="1.5" fill="#fff" opacity="0.7" />

        {/* mouth */}
        <rect x="46" y="70" width="28" height="4" rx="2" fill="#8b5cf6" opacity="0.8">
          <animate attributeName="width" values="28;20;28" dur="4s" repeatCount="indefinite" />
        </rect>

        {/* side bolts */}
        <circle cx="28" cy="60" r="3" fill="#3b82f6" filter="url(#softGlow)" />
        <circle cx="92" cy="60" r="3" fill="#3b82f6" filter="url(#softGlow)" />

        {/* jaw */}
        <path d="M 30 94 Q 60 104 90 94" stroke="#8b5cf6" strokeWidth="1.5" fill="none" opacity="0.6" />

        {/* neck */}
        <rect x="48" y="94" width="24" height="8" rx="3" fill="url(#metal)" stroke="rgba(139,92,246,0.3)" />
      </svg>
    </motion.div>
  )
}