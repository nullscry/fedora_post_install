#!/bin/bash

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root (with sudo)"
    exit 1
fi

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Copy etc configurations
echo "Installing configurations to /etc"
if [ -d "$SCRIPT_DIR/etc" ]; then
    cp -rf "$SCRIPT_DIR/etc/." "/etc/"
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
