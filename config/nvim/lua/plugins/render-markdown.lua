return {
  "MeanderingProgrammer/render-markdown.nvim",
  version = "v8.13.0",
  ft = { "markdown" },
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons",
  },
  opts = {
    completions = { lsp = { enabled = true } },
    -- LaTeX rendering needs the external utftex/latex2text binaries
    latex = { enabled = false },
  },
  keys = {
    { "<leader>um", "<cmd>RenderMarkdown toggle<cr>", ft = "markdown", desc = "Toggle Markdown Render" },
  },
}
