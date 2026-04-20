/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          light: '#7983F5',
          DEFAULT: '#5865F2', 
          dark: '#4752C4',
        },
        secondary: {
          light: '#33DAFF',
          DEFAULT: '#00D1FF', 
          dark: '#00A3C7',
        },
        accent: {
          DEFAULT: '#FF4757', 
          dark: '#E03D4B',
        },
        danger: '#FF4757',
        background: '#f8fafc',
      },
    },
  },
  plugins: [],
}
