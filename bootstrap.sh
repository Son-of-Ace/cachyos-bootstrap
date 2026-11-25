#!/usr/bin/env bash
set -euo pipefail

if ! command -v gh &>/dev/null || ! command -v ssh-keygen &>/dev/null || ! command -v git &>/dev/null; then
    echo "Installing required packages (git, openssh, github-cli)..."
    sudo pacman -S --needed --noconfirm git openssh github-cli
fi

read -rp "Git user.name: " GIT_NAME < /dev/tty
read -rp "Git user.email: " GIT_EMAIL < /dev/tty

git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"
git config --global init.defaultBranch main

SSH_KEY="$HOME/.ssh/id_ed25519"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

if [[ ! -f "$SSH_KEY" ]]; then
    echo "Generating new SSH key..."
    ssh-keygen -t ed25519 -C "$GIT_EMAIL" -f "$SSH_KEY" -N ""
else
    echo "Existing SSH key found at $SSH_KEY, skipping generation."
fi

eval "$(ssh-agent -s)" > /dev/null
ssh-add "$SSH_KEY"

echo "Logging into GitHub to upload your SSH key..."
gh auth login -p ssh -h github.com -s admin:public_key -w < /dev/tty

KEY_TITLE="$(hostname)-$(date +%Y-%m-%d)"
gh ssh-key add "${SSH_KEY}.pub" --title "$KEY_TITLE"

ssh-keyscan -t ed25519 github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null
echo "Testing SSH authentication with GitHub..."
ssh -T git@github.com || true

echo "Done! Git is configured and your SSH key ($KEY_TITLE) is active on GitHub."

if ! command -v chezmoi &>/dev/null; then
    sudo pacman -S --needed --noconfirm chezmoi
fi

echo "Applying chezmoi dotfiles..."
chezmoi init --apply git@github.com:Son-of-Ace/dotfiles-cachyos-kde.git

SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null || true)"
if [[ -n "$SCRIPT_PATH" && -f "$SCRIPT_PATH" ]]; then
    SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
    DIR_NAME="$(basename "$SCRIPT_DIR")"

    if [[ "$DIR_NAME" == "cachyos-bootstrap" || "$DIR_NAME" == "bootstrap" ]]; then
        echo "Removing bootstrap repository ($SCRIPT_DIR)..."
        cd "$HOME"
        rm -rf "$SCRIPT_DIR"
    else
        echo "Removing standalone bootstrap script ($SCRIPT_PATH)..."
        rm -f "$SCRIPT_PATH"
    fi
fi
