#!/bin/bash

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root (with sudo)"
    exit 1
fi

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Backup existing .bashrc if it exists
if [ -f "$HOME/.bashrc" ]; then
    echo "Backing up existing .bashrc..."
    mv "$HOME/.bashrc" "$HOME/.bashrc.backup"
fi

# Copy new .bashrc
echo "Installing new .bashrc..."
cp "$SCRIPT_DIR/.bashrc" "$HOME/.bashrc"
chown "$SUDO_USER:$SUDO_USER" "$HOME/.bashrc"

# Copy .config directory if it exists
if [ -d "$SCRIPT_DIR/.config" ]; then
    echo "Installing configuration files..."
    cp -r "$SCRIPT_DIR/.config" "/home/$SUDO_USER/"
    chown -R "$SUDO_USER:$SUDO_USER" "/home/$SUDO_USER/.config"
    echo "Configuration files installed successfully"
fi

# Copy entire .local directory
if [ -d "$SCRIPT_DIR/.local" ]; then
    echo "Installing user .local files..."
    mkdir -p "/home/$SUDO_USER/.local"
    # Copy all files and directories from repo .local into the user's .local
    # -a preserves attributes where possible; trailing "." ensures contents are copied
    cp -a "$SCRIPT_DIR/.local/." "/home/$SUDO_USER/.local/"

    # Make any files in .local/bin executable (if the directory exists)
    if [ -d "/home/$SUDO_USER/.local/bin" ]; then
        chmod +x "/home/$SUDO_USER/.local/bin"/* 2>/dev/null || true
    fi

    # Fix ownership recursively
    chown -R "$SUDO_USER:$SUDO_USER" "/home/$SUDO_USER/.local"
    echo "User .local files installed successfully"
fi

# Copy etc configurations
echo "Installing configurations to /etc"
if [ -d "$SCRIPT_DIR/etc" ]; then
    cp -rf "$SCRIPT_DIR/etc/" "/etc/"
fi

# Run post installation script
echo "Running post-installation script..."
if [ -f "$SCRIPT_DIR/post_install.sh" ]; then
    chmod +x "$SCRIPT_DIR/post_install.sh"
    "$SCRIPT_DIR/post_install.sh"
else
    echo "Warning: post_install.sh not found!"
fi

echo "Installation complete!"