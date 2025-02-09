#!/bin/bash
set -e

GITHUB_REPO="yuru7/HackGen"
ZIP_NAME="HackGen.zip"
ZIP_URL=$(curl -s "https://api.github.com/repos/$GITHUB_REPO/releases/latest" \
    | grep 'browser_download_url' \
    | grep 'HackGen_NF_.*\.zip' \
    | cut -d '"' -f 4)

curl -L -o "$ZIP_NAME" "$ZIP_URL"

unzip -o "$ZIP_NAME" -d font_files

mv font_files/*/*.ttf ~/Library/Fonts/

rm -rf "$ZIP_NAME" font_files

fc-list | grep HackGen

