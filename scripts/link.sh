#!/bin/bash
set -eu

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "Creating symbolic links..."

# Starship
ln -sf "$DOTFILES_DIR/config/starship/starship.toml" ~/.config/starship.toml

# Git
ln -sf "$DOTFILES_DIR/config/git" ~/.config/git

echo "Done."
