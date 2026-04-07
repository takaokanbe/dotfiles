return {
  "mfussenegger/nvim-lint",
  event = { "BufReadPost", "BufWritePost", "InsertLeave" },
  config = function()
    local lint = require("lint")

    lint.linters_by_ft = {
      go = { "golangcilint" },
      terraform = { "tflint" },
    }

    vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost", "InsertLeave" }, {
      group = vim.api.nvim_create_augroup("Linting", { clear = true }),
      callback = function()
        local ft = vim.bo.filetype
        local linters = lint.linters_by_ft[ft] or {}
        local available = vim.tbl_filter(function(name)
          return vim.fn.executable(lint.linters[name] and lint.linters[name].cmd or name) == 1
        end, linters)
        if #available > 0 then
          lint.try_lint(available)
        end
      end,
    })
  end,
}
