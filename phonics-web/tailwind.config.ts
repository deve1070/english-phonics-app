import type { Config } from 'tailwindcss';

const config: Config = {
  content: ["./index.html", "./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      fontFamily: {
        handwriting: ['"Patrick Hand"', "cursive"],
        body: ['"Nunito"', "sans-serif"],
      },
      colors: {
        primary: "#60A5FA", // soft blue
        accent: "#FBBF24", // sunny yellow
        success: "#86EFAC", // light green
        background: "#EBF4FF", // very light blue
      },
    },
  },
  plugins: [],
};

export default config;
