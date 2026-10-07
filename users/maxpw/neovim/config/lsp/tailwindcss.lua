return {
  cmd = { "tailwindcss-language-server", "--stdio" },
  filetypes = { "html", "css", "javascript", "typescript", "javascriptreact", "typescriptreact", "svelte", "vue" },
  root_markers = {
    "tailwind.config.js",
    "tailwind.config.ts",
    "tailwind.config.cjs",
    "tailwind.config.mjs",
    "package.json",
  },
}
