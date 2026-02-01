#!/bin/bash
set -eu

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "Creating symbolic links..."

# Starship
ln -sf "$DOTFILES_DIR/config/starship/starship.toml" ~/.config/starship.toml

# Git
ln -sfn "$DOTFILES_DIR/config/git" ~/.config/git

# Ghostty
ln -sfn "$DOTFILES_DIR/config/ghostty" ~/.config/ghostty

# Neovim
ln -sfn "$DOTFILES_DIR/config/nvim" ~/.config/nvim

# IdeaVim
ln -sf "$DOTFILES_DIR/config/ideavim/.ideavimrc" ~/.ideavimrc

# Claude Code
mkdir -p ~/.claude
ln -sf "$DOTFILES_DIR/config/claude/settings.json" ~/.claude/settings.json
ln -sf "$DOTFILES_DIR/config/claude/statusline.sh" ~/.claude/statusline.sh
ln -sfn "$DOTFILES_DIR/config/claude/skills" ~/.claude/skills

echo "Done."
