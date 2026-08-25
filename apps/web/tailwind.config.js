/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./src/**/*.{js,ts,jsx,tsx,mdx}'],
  theme: {
    extend: {
      colors: {
        // one dominant warm neutral, near-black text, ONE accent (brand blue)
        paper:   { DEFAULT: '#FBFAF7', deep: '#F3F0EA' },
        ink:     { DEFAULT: '#14181D', soft: '#59636E', faint: '#8B939C' },
        brand:   { DEFAULT: '#1565C0', light: '#1E88E5', wash: '#EAF2FB' },
        navy:    '#0E1B2B',
        line:    'rgba(20,24,29,0.10)',
      },
      fontFamily: {
        display: ['var(--font-display)', 'Georgia', 'serif'],
        sans:    ['var(--font-sans)', 'system-ui', 'sans-serif'],
      },
      fontSize: {
        // a real scale, not weight-only hierarchy
        'eyebrow': ['0.75rem',  { lineHeight: '1.4', letterSpacing: '0.12em' }],
        'display': ['clamp(2.75rem,6vw,5rem)', { lineHeight: '1.04', letterSpacing: '-0.028em' }],
        'title':   ['clamp(1.75rem,3.2vw,2.75rem)', { lineHeight: '1.12', letterSpacing: '-0.02em' }],
      },
      borderRadius: { xl: '14px', md: '8px' },
      boxShadow: { lift: '0 1px 2px rgba(20,24,29,.04), 0 10px 30px rgba(20,24,29,.07)' },
      maxWidth: { prose: '65ch' },
    },
  },
  plugins: [],
};
