const colors = require('tailwindcss/colors');
const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  mode: 'jit',
  purge: [
    './js/**/*.js',
    '../lib/*_web/**/*.html.heex',
    '../lib/*_web/live/**/*.ex'
  ],
  darkMode: false, // or 'media' or 'class'
  theme: {
    colors: colors,
    extend: {
      fontFamily: {
        sans: ['Inter', ...defaultTheme.fontFamily.sans]
      },
      fontSize: {
        '2xs': ['0.6rem', { lineHeight: '1rem' }],
      },
      colors: {
        twitch: '#9147ff',
        transparent: 'transparent'
      }
    },
  },
  variants: {
    extend: {},
  },
  plugins: [],
}
