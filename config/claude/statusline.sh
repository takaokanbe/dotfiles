#!/bin/bash
input=$(cat)

BOLD=$'\033[1m'
CYAN=$'\033[36m'
PURPLE=$'\033[35m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[31m'
RESET=$'\033[0m'

MODEL=$(echo "$input" | jq -r '.model.display_name')
CURRENT_DIR=$(echo "$input" | jq -r '.workspace.current_dir')
CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size')
USAGE=$(echo "$input" | jq '.context_window.current_usage')

# Repo name (cyan, falls back to basename of current dir) + Git branch (purple)
REPO_NAME="${CURRENT_DIR##*/}"
GIT_BRANCH=""
if git rev-parse --git-dir > /dev/null 2>&1; then
    # --git-common-dir resolves to the main repo's .git even inside a worktree
    GIT_COMMON_DIR=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
    if [ -n "$GIT_COMMON_DIR" ]; then
        REPO_NAME=$(basename "$(dirname "$GIT_COMMON_DIR")")
    fi
    BRANCH=$(git branch --show-current 2>/dev/null)
    if [ -n "$BRANCH" ]; then
        GIT_BRANCH=" ${PURPLE} ${BRANCH}${RESET}"
    fi
fi

# Context usage (green: ~49%, yellow: 50~79%, red: 80%~)
CONTEXT=""
if [ "$USAGE" != "null" ]; then
    CURRENT_TOKENS=$(echo "$USAGE" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
    PERCENT=$((CURRENT_TOKENS * 100 / CONTEXT_SIZE))
    if [ "$PERCENT" -ge 80 ]; then
        CONTEXT=" ${RED}${PERCENT}%${RESET}"
    elif [ "$PERCENT" -ge 50 ]; then
        CONTEXT=" ${YELLOW}${PERCENT}%${RESET}"
    else
        CONTEXT=" ${GREEN}${PERCENT}%${RESET}"
    fi
else
    CONTEXT=" ${GREEN}0%${RESET}"
fi

# Model (bold), Repo (cyan), Git branch (purple), Context usage
echo "${BOLD}${MODEL}${RESET} ${CYAN}${REPO_NAME}${RESET}${GIT_BRANCH}${CONTEXT}"
