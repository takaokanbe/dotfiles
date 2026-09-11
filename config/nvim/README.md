# Neovim Configuration

plugin manager には [lazy.nvim](https://github.com/folke/lazy.nvim) を使用。

## 前提

- **Neovim 0.12.0 以上**
- **[tree-sitter-cli](https://github.com/tree-sitter/tree-sitter) 0.26.1 以上**
  （`brew install tree-sitter-cli`）

nvim-treesitter は `main` ブランチを使う。`master` は上流で凍結済みで Neovim
0.11 までしかサポートされず、0.12 ではクエリのディレクティブが落ちる。

`main` はパーサを自前でビルドするため tree-sitter-cli を要求する。無い場合は
Neovim 同梱のパーサ（`c` `lua` `markdown` `markdown_inline` `query` `vim`
`vimdoc`）しか使えず、`lua/plugins/nvim-treesitter.lua` に列挙した残りの言語は
構文ハイライトが有効にならない。

## Plugin 一覧

| 機能 | Plugin | 説明 |
|------|--------|------|
| Filer | [nvim-tree.lua](https://github.com/nvim-tree/nvim-tree.lua) | ファイルツリー |
| Fuzzy Finder | [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) | ファイル・テキスト検索 |
| LSP | [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig) | LSP 設定 |
| LSP Manager | [mason.nvim](https://github.com/williamboman/mason.nvim) / [mason-lspconfig.nvim](https://github.com/williamboman/mason-lspconfig.nvim) | LSP サーバーのインストール・管理 |
| Formatter | [conform.nvim](https://github.com/stevearc/conform.nvim) | 保存時自動フォーマット |
| Linter | [nvim-lint](https://github.com/mfussenegger/nvim-lint) | 非同期リント |
| 補完 | [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) | 自動補完エンジン |
| Syntax Highlight | [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) | Tree-sitter ベースの構文ハイライト |
| Markdown | [render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim) | バッファ内での Markdown レンダリング |
| Colorscheme | [catppuccin](https://github.com/catppuccin/nvim) | カラースキーム (mocha) |
| Statusline | [lualine.nvim](https://github.com/nvim-lualine/lualine.nvim) | ステータスライン |
| Buffer Tab | [barbar.nvim](https://github.com/romgrk/barbar.nvim) | バッファをタブとして表示 |
| Git | [gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim) | Git 差分のガター表示 |
| Comment | [Comment.nvim](https://github.com/numToStr/Comment.nvim) | コメントのトグル |
| Auto Pairs | [nvim-autopairs](https://github.com/windwp/nvim-autopairs) | 括弧・クォートの自動補完 |
| Indent Guide | [indent-blankline.nvim](https://github.com/lukas-reineke/indent-blankline.nvim) | インデントガイドの表示 |
