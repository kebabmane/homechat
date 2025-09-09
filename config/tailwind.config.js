const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html,slim}'
  ],
  // Ensure critical layout utilities are present even if the scanner misses them
  safelist: [
    'flex', 'flex-1', 'flex-col',
    'items-center', 'justify-between',
    'h-screen', 'min-h-0', 'min-w-0',
    'overflow-hidden', 'overflow-y-auto', 'overflow-x-hidden',
    'w-64', 'absolute', 'inset-y-0', 'right-0',
    // Sidebar slide-in + overlay
    'fixed', 'inset-0', '-translate-x-full', 'translate-x-0', 'md:translate-x-0', 'bg-black/40', 'hidden', 'z-40', 'z-30',
    // Slack palette and hover accents
    'bg-slack-purple-dark', 'bg-slack-purple', 'bg-white/10', 'hover:bg-white/10', 'text-white', 'text-gray-200', 'text-gray-300', 'text-gray-400'
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Lato', ...defaultTheme.fontFamily.sans],
      },
      colors: {
        'slack-purple': '#4A154B',
        'slack-purple-dark': '#3F0E40',
        'slack-green': '#2EB67D',
        'slack-yellow': '#ECB22E',
        'slack-red': '#E01E5A',
      },
    },
  },
  plugins: [],
}
