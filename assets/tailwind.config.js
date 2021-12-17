const colors = require('tailwindcss/colors');
const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  mode: 'jit',
  content: [
    './js/**/*.js',
    '../lib/*_web/**/*.html.heex',
    '../lib/*_web/live/**/*.ex'
  ],
  darkMode: 'media',
  theme: {
    screens: {
      'xs': '475px',
      ...defaultTheme.screens,
    },
    extend: {
      colors: {
        transparent: 'transparent',
        paw: {
          "50": "#32f5e8",
          "100": "#28ebde",
          "200": "#1ee1d4",
          "300": "#14d7ca",
          "400": "#0acdc0",
          "500": "#00c3b6",
          "600": "#00b9ac",
          "700": "#00afa2",
          "800": "#00a598",
          "900": "#009b8e"
        }
      },
      fontFamily: {
        sans: ['Inter', ...defaultTheme.fontFamily.sans]
      },
      fontSize: {
        '2xs': ['0.6rem', { lineHeight: '1rem' }],
      },
    },
  },
  variants: {
    extend: {},
  },
  plugins: [],
}
