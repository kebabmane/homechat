const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html,slim}'
  ],
  // Safelist critical layout utilities
  safelist: [
    'flex', 'flex-1', 'flex-col',
    'items-center', 'justify-between',
    'h-screen', 'min-h-0', 'min-w-0',
    'overflow-hidden', 'overflow-y-auto', 'overflow-x-hidden',
    'w-64', 'absolute', 'inset-y-0', 'right-0',
    // Mobile Sidebar
    'fixed', 'inset-0', '-translate-x-full', 'translate-x-0', 'md:translate-x-0', 'bg-black/40', 'hidden', 'z-40', 'z-30',
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: [
          "'DM Sans'",
          'ui-sans-serif',
          'system-ui',
          '-apple-system',
          'BlinkMacSystemFont',
          'Segoe UI',
          'sans-serif',
          'Apple Color Emoji',
          'Segoe UI Emoji',
        ],
      },
      colors: {
        // Custom semantic colors if needed
      },
    },
  },
  plugins: [],
}
