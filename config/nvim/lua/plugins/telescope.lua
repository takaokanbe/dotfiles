return {
  "nvim-telescope/telescope.nvim",
  tag = "0.1.8",
  dependencies = {
    "nvim-lua/plenary.nvim",
    {
      "nvim-telescope/telescope-fzf-native.nvim",
      build = "make",
      cond = function()
        return vim.fn.executable("make") == 1
      end,
    },
  },
  config = function()
    local telescope = require("telescope")
    local builtin = require("telescope.builtin")

    telescope.setup({
      defaults = {
        sorting_strategy = "ascending",
        layout_config = {
          horizontal = {
            prompt_position = "top",
          },
        },
        path_display = { "truncate" },
        file_ignore_patterns = {
          -- dependencies
          "node_modules",
          "vendor",
          ".venv",
          "__pycache__",
          -- version control
          ".git/",
          -- build outputs
          "dist",
          "build",
          "%.lock",
          "package%-lock%.json",
          -- cache
          ".cache",
          ".next",
          -- infrastructure
          ".terraform",
          "%.tfstate",
          -- binary & media
          "%.png",
          "%.jpg",
          "%.jpeg",
          "%.gif",
          "%.ico",
          "%.pdf",
          "%.woff",
          "%.woff2",
          "%.ttf",
          -- minified & sourcemap
          "%.min%.js",
          "%.min%.css",
          "%.map",
          -- OS
          "%.DS_Store",
        },
      },
      pickers = {
        find_files = {
          hidden = true,
        },
        live_grep = {
          additional_args = { "--hidden" },
        },
        lsp_references = { show_line = false },
        lsp_definitions = { show_line = false },
        lsp_type_definitions = { show_line = false },
        lsp_implementations = { show_line = false },
      },
      extensions = {
        fzf = {
          fuzzy = true,
          override_generic_sorter = true,
          override_file_sorter = true,
          case_mode = "smart_case",
        },
      },
    })

    pcall(telescope.load_extension, "fzf")

    vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find Files" })
    vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Live Grep" })
    vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Find Buffers" })
    vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Help Tags" })
    vim.keymap.set("n", "<leader>fc", builtin.commands, { desc = "Commands" })
    vim.keymap.set("n", "<leader>fr", builtin.oldfiles, { desc = "Recent Files" })
    vim.keymap.set("n", "<leader>fd", builtin.diagnostics, { desc = "Errors & Warnings" })
  end,
}
