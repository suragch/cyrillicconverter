/** @frontend/.svelte-kit/types/src/routes/$types.d.ts {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{html,js,svelte,ts}'],
  theme: {
    extend: {
      colors: {
        'near-black': '#1A1A1A',        // Text (Primary)
        'medium-gray': '#6B6B6B',       // Text (Secondary)
        'light-gray': '#E0E0E0',        // Borders/Dividers
        'off-white': '#F9F9F9',         // Surface
        'royal-blue': '#0052FF',        // Primary Action
        'bright-blue': '#0048E0',       // Primary Action (Hover)
        'success-green': '#28A745',     // Semantic Success
        'info-blue': '#007BFF',         // Semantic Information
        'warning-red': '#DC3545',       // Semantic Warning/Error
        'choice-blue': '#0052FF',       // Same as Royal Blue as per spec
      },
      fontFamily: {
        // Defines a custom font stack starting with 'Inter', falling back to generic sans-serif
        inter: ['Inter', 'sans-serif'],
      },
    },
  },
  plugins: [],
}