return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  config = function ()
    local configs = require("nvim-treesitter.configs")
    configs.setup({
      ensure_installed = { "go", "sql", "terraform", "lua", "vim", "vimdoc", "query", "javascript", "typescript", "markdown", "markdown_inline" },
      sync_install = false,
      highlight = { enable = true },
    })
  end,
 }
