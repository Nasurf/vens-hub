import { useMemo } from 'react'
import katex from 'katex'

interface LatexTextProps {
  text: string
  className?: string
}

export function hasLatexSyntax(text: string): boolean {
  return text.includes('$') || /\\[a-zA-Z]+/.test(text)
}

function renderLatex(text: string): string {
  // If there are no LaTeX markers ($, $$, or backslash commands), just return the original text
  if (!hasLatexSyntax(text)) {
    return text
  }

  let result = text

  // First, handle display math $$...$$
  result = result.replace(/\$\$([\s\S]*?)\$\$/g, (_, math) => {
    try {
      return katex.renderToString(math.trim(), {
        displayMode: true,
        throwOnError: false,
        trust: true,
        strict: false,
      })
    } catch {
      return math
    }
  })

  // Then handle inline math $...$ - but only if it looks like math
  result = result.replace(/\$([^$]+?)\$/g, (_, math) => {
    // Only process if it contains LaTeX-like content
    if (math.includes('\\') || /[a-zA-Z]+\s*[=+\-*/^_]/.test(math)) {
      try {
        return katex.renderToString(math.trim(), {
          displayMode: false,
          throwOnError: false,
          trust: true,
          strict: false,
        })
      } catch {
        return `$${math}$`
      }
    }
    // Otherwise just return it as-is without the $ signs
    return math
  })

  // Handle common LaTeX commands without $ delimiters only if they are actually present
  if (result.includes('\\frac')) {
    result = result.replace(/\\frac\{([^}]+)\}\{([^}]+)\}/g, (_, num, den) => {
      try {
        return katex.renderToString(`\\frac{${num}}{${den}}`, { displayMode: false, throwOnError: false, strict: false })
      } catch {
        return `${num}/${den}`
      }
    })
  }

  if (result.includes('\\sqrt')) {
    result = result.replace(/\\sqrt\{([^}]+)\}/g, (_, content) => {
      try {
        return katex.renderToString(`\\sqrt{${content}}`, { displayMode: false, throwOnError: false, strict: false })
      } catch {
        return `√${content}`
      }
    })
  }

  if (result.includes('\\text')) {
    result = result.replace(/\\text\{([^}]+)\}/g, (_, text) => text)
  }

  // Only replace common symbols if they are present as LaTeX commands
  const symbolMap: Record<string, string> = {
    '\\,': ' ',
    '\\;': ' ',
    '\\!': '',
    '\\cdot': '·',
    '\\times': '×',
    '\\div': '÷',
    '\\pm': '±',
    '\\mp': '∓',
    '\\leq': '≤',
    '\\geq': '≥',
    '\\neq': '≠',
    '\\approx': '≈',
    '\\infty': '∞',
    '\\pi': 'π',
    '\\theta': 'θ',
    '\\alpha': 'α',
    '\\beta': 'β',
    '\\gamma': 'γ',
    '\\delta': 'δ',
    '\\sigma': 'σ',
    '\\omega': 'ω',
    '\\Omega': 'Ω',
    '\\Sigma': 'Σ',
    '\\Delta': 'Δ',
    '\\nabla': '∇',
    '\\partial': '∂',
  }

  for (const [latex, symbol] of Object.entries(symbolMap)) {
    if (result.includes(latex)) {
      result = result.split(latex).join(symbol)
    }
  }

  // Clean up any leftover LaTeX artifacts carefully
  result = result.replace(/\\left|\\right/g, '')

  return result
}

export function LatexText({ text, className }: LatexTextProps) {
  const shouldRenderLatex = hasLatexSyntax(text)
  const rendered = useMemo(() => renderLatex(text), [text])

  if (!shouldRenderLatex) {
    if (className) {
      return <span className={className}>{text}</span>
    }

    return <>{text}</>
  }

  return (
    <span
      className={className}
      dangerouslySetInnerHTML={{ __html: rendered }}
    />
  )
}
