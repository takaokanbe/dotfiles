return {
  'romgrk/barbar.nvim',
  dependencies = {
    'lewis6991/gitsigns.nvim', -- OPTIONAL: for git status
    'nvim-tree/nvim-web-devicons', -- OPTIONAL: for file icons
  },
  init = function() vim.g.barbar_auto_setup = false end,
  opts = {
    -- lazy.nvim will automatically call setup for you. put your options here, anything missing will use the default:
    -- animation = true,
    -- insert_at_start = true,
    -- …etc.
  },
  config = function(_, opts)
    require('barbar').setup(opts)
    vim.keymap.set('n', '<S-h>', '<Cmd>BufferPrevious<CR>', { silent = true, desc = "Prev Buffer" })
    vim.keymap.set('n', '<S-l>', '<Cmd>BufferNext<CR>', { silent = true, desc = "Next Buffer" })
    vim.keymap.set('n', '[b', '<Cmd>BufferPrevious<CR>', { silent = true, desc = "Prev Buffer" })
    vim.keymap.set('n', ']b', '<Cmd>BufferNext<CR>', { silent = true, desc = "Next Buffer" })
    vim.keymap.set('n', '<leader>bd', '<Cmd>BufferClose<CR>', { silent = true, desc = "Delete Buffer" })
  end,
}
