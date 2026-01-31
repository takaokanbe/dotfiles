return {
  "williamboman/mason-lspconfig.nvim",
  version = "*",
  lazy = false,
  config = function()
    require("mason-lspconfig").setup {}

    local server_configs = {
      gopls = {
        settings = {
          gopls = {
            analyses = { unusedparams = true },
            staticcheck = true,
          },
        },
        on_attach = function()
          -- https://github.com/golang/tools/blob/master/gopls/doc/vim.md#imports-and-formatting
          vim.api.nvim_create_autocmd("BufWritePre", {
            callback = function()
              local params = vim.lsp.util.make_range_params()
              params.context = { only = { "source.organizeImports" } }
              local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params)
              for cid, res in pairs(result or {}) do
                for _, r in pairs(res.result or {}) do
                  if r.edit then
                    local enc = (vim.lsp.get_client_by_id(cid) or {}).offset_encoding or "utf-16"
                    vim.lsp.util.apply_workspace_edit(r.edit, enc)
                  end
                end
              end
              vim.lsp.buf.format({ async = false })
            end
          })
        end,
      },
      lua_ls = {
        settings = {
          Lua = {
            diagnostics = {
              globals = { "vim" },
            },
          },
        },
      },
    }

    require("mason-lspconfig").setup_handlers {
      function (server_name)
        local opts = {
          capabilities = require("cmp_nvim_lsp").default_capabilities(),
        }
        if server_configs[server_name] then
          opts = vim.tbl_deep_extend("force", opts, server_configs[server_name])
        end
        require('lspconfig')[server_name].setup(opts)
      end,
    }
    vim.keymap.set('n', 'K', '<cmd>lua vim.lsp.buf.hover()<CR>')
    vim.keymap.set('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>')
    vim.keymap.set('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>')
    vim.keymap.set('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>')
  end,
}
