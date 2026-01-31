# dotfiles

@takaokanbe's dotfiles

## 構成

```
config/
  ghostty/     # Ghostty
  git/         # Git
  ideavim/     # IdeaVim
  nvim/        # Neovim
  starship/    # Starship
scripts/
  link.sh        # シンボリックリンクを作成
  true-color.sh  # True Colorの表示テスト
```

## セットアップ

シンボリックリンクを作成する:

```bash
./scripts/link.sh
```

## リンク一覧

| リンク元 | リンク先 |
|----------|----------|
| `config/starship/starship.toml` | `~/.config/starship.toml` |
| `config/git/` | `~/.config/git` |
| `config/ghostty/` | `~/.config/ghostty` |
| `config/nvim/` | `~/.config/nvim` |
| `config/ideavim/.ideavimrc` | `~/.ideavimrc` |
