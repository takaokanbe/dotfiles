return {
  "williamboman/mason-lspconfig.nvim",
  version = "*",
  lazy = false,
  dependencies = {
    "williamboman/mason.nvim",
    "neovim/nvim-lspconfig",
    "hrsh7th/cmp-nvim-lsp",
  },
  config = function()
    local capabilities = require("cmp_nvim_lsp").default_capabilities()

    -- diagnostics
    vim.diagnostic.config({
      underline = true,
      update_in_insert = false,
      virtual_text = {
        spacing = 4,
        source = "if_many",
        prefix = "●",
      },
      float = {
        border = "rounded",
        source = true,
      },
      severity_sort = true,
      signs = {
        text = {
          [vim.diagnostic.severity.ERROR] = " ",
          [vim.diagnostic.severity.WARN] = " ",
          [vim.diagnostic.severity.HINT] = " ",
          [vim.diagnostic.severity.INFO] = " ",
        },
      },
    })

    -- LSP keymaps (buffer-local on attach)
    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(event)
        local buf = event.buf
        local client = vim.lsp.get_client_by_id(event.data.client_id)
        local telescope = require("telescope.builtin")
        local map = function(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc })
        end

        map("n", "K", vim.lsp.buf.hover, "Hover")
        map("n", "gd", telescope.lsp_definitions, "Goto Definition")
        map("n", "gD", vim.lsp.buf.declaration, "Goto Declaration")
        map("n", "gi", telescope.lsp_implementations, "Goto Implementation")
        map("n", "gr", telescope.lsp_references, "References")
        map("n", "gy", telescope.lsp_type_definitions, "Goto Type Definition")
        map("n", "gK", vim.lsp.buf.signature_help, "Signature Help")
        map("i", "<C-k>", vim.lsp.buf.signature_help, "Signature Help")
        map("n", "<leader>cr", vim.lsp.buf.rename, "Rename")
        map({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, "Code Action")
        map("n", "<leader>cs", telescope.lsp_document_symbols, "Document Symbols")
        map("n", "<leader>cd", vim.diagnostic.open_float, "Line Diagnostics")
        map("n", "]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, "Next Diagnostic")
        map("n", "[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, "Prev Diagnostic")

        -- document highlight
        if client and client.supports_method("textDocument/documentHighlight") then
          vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
            buffer = buf,
            callback = vim.lsp.buf.document_highlight,
          })
          vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
            buffer = buf,
            callback = vim.lsp.buf.clear_references,
          })
        end
      end,
    })

    -- server configs
    local server_configs = {
      gopls = {
        settings = {
          gopls = {
            analyses = { unusedparams = true },
            staticcheck = true,
          },
        },
        on_attach = function()
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
            end,
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

    require("mason-lspconfig").setup({
      handlers = {
        function(server_name)
          local opts = { capabilities = capabilities }
          if server_configs[server_name] then
            opts = vim.tbl_deep_extend("force", opts, server_configs[server_name])
          end
          require("lspconfig")[server_name].setup(opts)
        end,
      },
    })
  end,
}
