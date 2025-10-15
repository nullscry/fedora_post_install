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

# Copy .local/bin scripts
if [ -d "$SCRIPT_DIR/.local/bin" ]; then
    echo "Installing user scripts..."
    mkdir -p "/home/$SUDO_USER/.local/bin"
    cp -r "$SCRIPT_DIR/.local/bin"/* "/home/$SUDO_USER/.local/bin/"
    chmod +x /home/$SUDO_USER/.local/bin/*
    chown -R "$SUDO_USER:$SUDO_USER" "/home/$SUDO_USER/.local"
    echo "User scripts installed successfully"
fi

# Make usr/bin files executable and copy them to /usr/bin
echo "Installing executables to /usr/bin..."
if [ -d "$SCRIPT_DIR/usr/bin" ]; then
    for file in "$SCRIPT_DIR/usr/bin"/*; do
        if [ -f "$file" ]; then
            chmod +x "$file"
            cp "$file" "/usr/bin/"
            echo "Installed: $(basename "$file")"
        fi
    done
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