-- nvim-treesitter `main` branch: a full rewrite, incompatible with the old
-- `master` API. `master` is frozen and only supports Neovim <= 0.11, where its
-- query directives crash on 0.12 (`match[id]` is a node list there, not a node).
-- `main` has no tags, so it is pinned by commit.
return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  commit = "5cb0114e6242625db56dd6440e945ed1ece10bc7",
  lazy = false, -- main does not support lazy-loading
  build = ":TSUpdate",
  config = function()
    local parsers = {
      "go", "sql", "terraform", "hcl", "lua", "vim", "vimdoc", "query",
      "javascript", "typescript", "markdown", "markdown_inline", "html",
      "json", "yaml",
    }

    require("nvim-treesitter").install(parsers)

    -- main provides queries only; Neovim owns highlighting and it is opt-in.
    vim.api.nvim_create_autocmd("FileType", {
      callback = function(ev)
        local lang = vim.treesitter.language.get_lang(ev.match)
        if not lang then
          return
        end
        -- Parsers install asynchronously, and filetypes outside `parsers`
        -- have none at all, so a missing parser here is expected.
        local ok, loaded = pcall(vim.treesitter.language.add, lang)
        if ok and loaded then
          vim.treesitter.start(ev.buf, lang)
        end
      end,
    })
  end,
}
