# dotfiles

@takaokanbe's dotfiles

## 構成

```
config/
  claude/      # Claude Code
  ghostty/     # Ghostty
  git/         # Git
  ideavim/     # IdeaVim
  nvim/        # Neovim
  sheldon/     # Sheldon
  starship/    # Starship
  tmux/        # tmux
  wezterm/     # WezTerm
scripts/
  link.sh        # シンボリックリンクを作成
  true-color.sh  # True Colorの表示テスト
```

## セットアップ

シンボリックリンクを作成する:

```bash
./scripts/link.sh
```

`link.sh` はリンクを張るだけで、ツール自体のインストールはしない。各ツールは
別途入れること。Neovim については以下が必要:

```bash
brew install neovim tree-sitter-cli
```

- **Neovim 0.12.0 以上** — nvim-treesitter の `main` ブランチの要件
- **tree-sitter-cli 0.26.1 以上** — パーサのビルドに使う。npm ではなく
  パッケージマネージャで入れること

tree-sitter-cli が無いと Neovim 同梱のパーサ（`c` `lua` `markdown`
`markdown_inline` `query` `vim` `vimdoc`）以外はビルドできず、Go や TypeScript
など他の言語の構文ハイライトが有効にならない。

ほかに C コンパイラ・`curl`・`tar` が PATH 上に必要だが、macOS では標準で揃う。

## リンク一覧

| リンク元 | リンク先 |
|----------|----------|
| `config/starship/starship.toml` | `~/.config/starship.toml` |
| `config/git/` | `~/.config/git` |
| `config/ghostty/` | `~/.config/ghostty` |
| `config/nvim/` | `~/.config/nvim` |
| `config/ideavim/.ideavimrc` | `~/.ideavimrc` |
| `config/tmux/` | `~/.config/tmux` |
| `config/wezterm/` | `~/.config/wezterm` |
| `config/sheldon/plugins.toml` | `~/.config/sheldon/plugins.toml` |
| `config/claude/settings.json` | `~/.claude/settings.json` |
| `config/claude/statusline.sh` | `~/.claude/statusline.sh` |
| `config/claude/skills/` | `~/.claude/skills` |
