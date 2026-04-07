return {
  "sindrets/diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
  keys = {
    { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diffview Open" },
    { "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "File History (current)" },
    { "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "File History (all)" },
  },
  config = function()
    -- diffviewバッファへのLSPアタッチを防止
    local orig_lsp_start = vim.lsp.start
    vim.lsp.start = function(config, opts)
      opts = opts or {}
      local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name:match("^diffview://") then
        return nil
      end
      return orig_lsp_start(config, opts)
    end

    local actions = require("diffview.actions")
    require("diffview").setup({
      keymaps = {
        view = {
          { "n", "q", actions.close, { desc = "Close diffview" } },
        },
        file_panel = {
          { "n", "q", actions.close, { desc = "Close diffview" } },
        },
        file_history_panel = {
          { "n", "q", actions.close, { desc = "Close diffview" } },
        },
      },
    })
  end,
}
