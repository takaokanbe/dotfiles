return {
  'nvim-telescope/telescope.nvim',
  tag = '0.1.8',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    local telescopeConfig = require('telescope.config')

    -- デフォルトの vimgrep_arguments をコピーして拡張
    local vimgrep_arguments = { unpack(telescopeConfig.values.vimgrep_arguments) }
    table.insert(vimgrep_arguments, '--hidden')
    table.insert(vimgrep_arguments, '--glob')
    table.insert(vimgrep_arguments, '!**/.git/*')
    table.insert(vimgrep_arguments, '--glob')
    table.insert(vimgrep_arguments, '!**/node_modules/*')

    require('telescope').setup({
      defaults = {
        vimgrep_arguments = vimgrep_arguments,
      },
      pickers = {
        find_files = {
          find_command = { 'rg', '--files', '--hidden', '--glob', '!**/.git/*', '--glob', '!**/node_modules/*' },
        },
      },
    })

    local builtin = require('telescope.builtin')
    vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Telescope find files' })
    vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Telescope live grep' })
  end,
}
