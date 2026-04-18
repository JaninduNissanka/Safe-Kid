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
          DEFAULT: '#6366f1', // Indigo/Purple matching the app
          dark: '#4f46e5',
        },
        secondary: {
          DEFAULT: '#3b82f6', // Blue
          dark: '#2563eb',
        },
        danger: {
          DEFAULT: '#ef4444', // Red
          dark: '#dc2626',
        },
        background: '#f8fafc', // Slate-50
      },
    },
  },
  plugins: [],
}
