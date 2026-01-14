#!/usr/bin/bash

# Exit on any error
set -e

echo "🚀 Starting Fedora Post-Installation Setup..."

#######################
# Repository Setup
#######################

echo "📦 Adding RPM Fusion repositories (free and non-free)..."
dnf install -y \
    https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

#######################
# Media Codecs Setup
#######################

echo "🎥 Setting up multimedia support..."
# Basic multimedia packages
dnf install -y fuse
dnf4 group install multimedia
dnf swap 'ffmpeg-free' 'ffmpeg' --allowerasing
dnf upgrade @multimedia --setopt="install_weak_deps=False"
dnf group install -y sound-and-video

# Install comprehensive codec support
echo "🎬 Installing video codecs and hardware acceleration support..."
dnf install -y \
    libva-utils \
    noopenh264 \
    mozilla-openh264 \
    gstreamer1-plugin-openh264 \
    gstreamer1-plugin-libav \
    gstreamer1-plugins-bad-free-extras \
    gstreamer1-plugins-bad-freeworld \
    gstreamer1-plugins-ugly \
    gstreamer1-vaapi

# Enable Cisco's OpenH264 repository
dnf config-manager setopt fedora-cisco-openh264.enabled=1

#######################
# System Optimization
#######################

echo "⚡ Optimizing system services..."
systemctl disable NetworkManager-wait-online.service

#######################
# Gaming Setup
#######################

echo "🎮 Installing gaming utilities (GameMode, MangoHUD, Vulkan)..."
dnf install -y \
    wine \
    wine-mono \
    winetricks \
    protontricks \
    gamemode \
    mangohud \
    vulkan-tools \
    steam-devices \
    gamescope \
    vkbasalt

#######################
# GPU Driver Setup
#######################

echo "🖥️ Detecting and installing GPU drivers..."

if lspci | grep -i nvidia &>/dev/null; then
    echo "� NVIDIA GPU detected - Installing NVIDIA drivers and Flatpak runtime..."
    
    # Enable tainted repos for NVIDIA drivers
    dnf install -y rpmfusion-nonfree-release-tainted

    # Install NVIDIA drivers (open kernel modules by default)
    dnf install -y \
        akmod-nvidia-open \
        xorg-x11-drv-nvidia \
        xorg-x11-drv-nvidia-cuda \
        nvidia-settings

    # Blacklist nouveau and enable NVIDIA DRM modeset
    grubby --update-kernel=ALL --args="rd.driver.blacklist=nouveau modprobe.blacklist=nouveau nvidia-drm.modeset=1"

    # Get NVIDIA driver version from installed package
    version=$(dnf list installed akmod-nvidia-open --quiet | grep akmod-nvidia-open | awk '{print $2}' | cut -d':' -f2 | cut -d'.' -f1-2 | tr '.' '-')
    echo "🧩 Installing Flatpak NVIDIA driver version: $version"
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub "org.freedesktop.Platform.GL.nvidia-$version"
    flatpak install -y flathub "org.freedesktop.Platform.GL32.nvidia-$version"

    # NVIDIA GPU hardware acceleration
    dnf install -y libva-nvidia-driver
else
    echo "🖥️ AMD/Intel GPU detected - No additional drivers needed"
fi

#######################
# Software Installation
#######################

echo "📦 Installing system applications..."
# System packages
dnf install -y \
    vim-enhanced \
    btop \
    lsd \
    steam \
    lutris \
    kitty \
    qbittorrent \
    vlc \
    libreoffice \
    clementine \
    torbrowser-launcher \
    calibre \
    pdfarranger \
    audacity \
    godot \
    inkscape \
    lmms \
    easyeffects \
    kate \
    krita \
    syncthing \
    discord \
    asusctl \
    keepassxc

echo "📱 Installing Flatpak applications..."
# Ensure Flathub is available
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install Flatpak applications
flatpak install --or-update --assumeyes flathub \
    com.spotify.Client \
    net.davidotek.pupgui2 \
    com.rafaelmardojai.Blanket \
    it.mijorus.gearlever \
    com.bitwarden.desktop

#######################
# Sunshine Installation
#######################
sudo dnf copr enable lizardbyte/stable -y
dnf install -y Sunshine
sudo setcap cap_sys_admin+p $(readlink -f $(which sunshine))

#######################
# Development Environment
#######################

echo "🛠️ Setting up development environment..."
# Install UV package manager
echo "📦 Installing UV package manager and Python tools..."
curl -LsSf https://astral.sh/uv/install.sh | sh
uv tool install ruff pre-commit twine

# Install Rust
echo "🦀 Installing Rust and development tools..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Add Cargo environment to bashrc if not present
if ! grep -q '. "$HOME/.cargo/env"' /home/$SUDO_USER/.bashrc; then
    echo "# Load Cargo environment" >> /home/$SUDO_USER/.bashrc
    echo '. "$HOME/.cargo/env"' >> /home/$SUDO_USER/.bashrc
fi

# Source Cargo environment
. "$HOME/.cargo/env"

# Install Rust components
rustup component add rustfmt clippy rust-analyzer rust-src rust-docs

# Install VS Code Insiders
echo "💻 Installing Visual Studio Code Insiders..."
rpm --import https://packages.microsoft.com/keys/microsoft.asc
echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo
dnf install -y code-insiders

#######################
# Gaming Optimizations
#######################

echo "🎮 Configuring GameMode settings..."
# Add user to gamemode group
usermod -aG gamemode $SUDO_USER

# Configure GameMode
GAMEMODE_INI="/etc/gamemode.ini"
EXAMPLE_INI_URL="https://raw.githubusercontent.com/FeralInteractive/gamemode/master/example/gamemode.ini"

# Download example config if needed
if [ ! -f "$GAMEMODE_INI" ]; then
    echo "📥 Downloading GameMode configuration template..."
    curl -fsSL "$EXAMPLE_INI_URL" > "$GAMEMODE_INI"
fi

# Helper function for GameMode configuration
set_gamemode_ini_general() {
    local key="$1"
    local value="$2"
    local file="$GAMEMODE_INI"

    # Ensure [general] section exists
    if ! grep -q "^\[general\]" "$file"; then
        echo -e "\n[general]" >> "$file"
    fi

    # Update or add setting
    if grep -q "^$key=" "$file"; then
        sed -i "s/^$key=.*/$key=$value/" "$file"
    else
        sed -i "/\[general\]/a $key=$value" "$file"
    fi
}

# Configure GameMode settings
set_gamemode_ini_general renice 10
set_gamemode_ini_general softrealtime on

# Load ntsync module at boot
echo ntsync | tee /etc/modules-load.d/ntsync.conf
modprobe ntsync

#######################
# RPG-Maker for linux wrapper
#######################
echo "🎲 Installing RPG-Maker for Linux wrapper..."
wget -qO- "https://raw.githubusercontent.com/bakustarver/rpgmakermlinux-cicpoffs/main/installgithub.sh" | bash

#######################
# Configure Steam, Steam Input and Gamescope
#######################

echo "🎮 Setting up Steam Input device support..."
curl -fsSL https://raw.githubusercontent.com/ValveSoftware/steam-devices/master/60-steam-input.rules > /etc/udev/rules.d/60-steam-input.rules
usermod -aG input $SUDO_USER

# Configure Steam's desktop entry for better compatibility
echo "🎮 Configuring Steam desktop entry with -steamos3 flag..."
echo "Adding the -steamos3 parameter to the Steam desktop entry fixes Steam input controller issues when running games with gamescope"
STEAM_DESKTOP="~/.local/share/applications/steam.desktop"
if [ -f "$STEAM_DESKTOP" ]; then
    # Create backup of original desktop file
    cp "$STEAM_DESKTOP" "$STEAM_DESKTOP.backup"
    
    # Update the Exec line to include steamos3 parameter
    sed -i 's/^Exec=/usr/bin/steam %U$/Exec=/usr/bin/steam -steamos3 %U/' "$STEAM_DESKTOP"
    echo "✅ Steam desktop entry updated with SteamOS 3 compatibility flag"
else
    echo "⚠️  Steam desktop entry not found - please install Steam first"
fi

# Set gamescope capabilities
echo "🎮 Setting capabilities for gamescope..."
setcap 'CAP_SYS_NICE=eip' "$(which gamescope)"

#######################
# Wifi Fixes for Mediatek MT7922 chip using the mt7921e driver
#######################

# Check if the hardware is present
if lspci -v 2>/dev/null | grep -A 10 Network | grep -q "Kernel modules: mt7921e"; then
    echo "📡 Applying Wifi fixes for Mediatek MT7922 chip..."

    # Permanent fix - add this line to NetworkManager config
    echo -e '\n[connection]\nwifi.powersave = 2' | tee -a /etc/NetworkManager/conf.d/wifi-powersave.conf

    # Create a config file for the driver
    echo 'options mt7921e disable_aspm=1' | tee /etc/modprobe.d/mt7921e.conf

    # Reload the driver
    modprobe -r mt7921e
    modprobe mt7921e
else
    echo "📡 Mediatek MT7922 chip not detected, skipping Wifi fixes."
fi

#######################
# Visual Customization
#######################

echo "🎨 Installing Nerd Fonts..."
# Create temporary directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

# Download and install Cousine Nerd Font
wget https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/Cousine.zip
unzip Cousine.zip
mkdir -p /home/$SUDO_USER/.local/share/fonts/
cp *.ttf /home/$SUDO_USER/.local/share/fonts/
cp *.otf /home/$SUDO_USER/.local/share/fonts/ 2>/dev/null || true
chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.local/share/fonts
fc-cache -fv

# Install and configure Starship prompt
echo "🚀 Installing Starship prompt..."
curl -sS https://starship.rs/install.sh | sh
echo '# Starship Prompt' >> /home/$SUDO_USER/.bashrc
echo 'eval "$(starship init bash)"' >> /home/$SUDO_USER/.bashrc

# Cleanup temporary directory
rm -rf "$TEMP_DIR"

#######################
# Set Default Applications
#######################
kwriteconfig6 --file kdeglobals --group General --key TerminalService kitty.desktop

#######################
# Remove Unwanted Packages
#######################

echo "🧹 Removing unwanted KDE packages..."
dnf remove -y \
    akonadi\* \
    kmail \
    kontact \
    korganizer \
    kaddressbook \
    kalendarac \
    kdepim-addons \
    plasma-discover \
    plasma-discover-notifier \
    kwrite \
    elisa-player \
    dragon \
    kmahjongg \
    kmines \
    kpat

dnf autoremove -y

#######################
# Update System
#######################
echo "🔄 Updating system (DNF, Flatpak, Firmware)..."
update_all

#######################
# Quad9 DNS Setup
#######################
echo "🌐 Setting up Quad9 DNS servers for enhanced privacy and security..."
# System-wide Quad9 DNS setup for Fedora (NetworkManager)

# 1. Create main config to ensure NetworkManager handles DNS itself
sudo tee /etc/NetworkManager/conf.d/dns.conf > /dev/null <<'EOF'
[main]
dns=default
EOF

# 2. Create global DNS config file with Quad9 servers
sudo tee /etc/NetworkManager/conf.d/90-dns-servers.conf > /dev/null <<'EOF'
[global-dns]
servers=9.9.9.9,149.112.112.112
EOF

# 3. Restart NetworkManager to apply changes
echo "Restarting NetworkManager..."
sudo systemctl restart NetworkManager

#######################
# Final Instructions
#######################

echo "✅ Post-installation setup complete!"
echo "In LibreOffice Writer select Tools -> Options -> View and set the Icon Theme to Colibre (SVG+Dark)."
echo "🔄 Please reboot your system to complete the setup"
