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
# dnf4 used here: dnf5's group install for 'multimedia' was unreliable
# during the F42/F43 transition. Revisit once F44+ is the baseline.
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

# Swap Fedora's codec-stripped VAAPI driver for the RPM Fusion build.
# Stock mesa-va-drivers removes H.264/HEVC encode (only AV1 remains), which
# breaks VAAPI hardware encoding on AMD/Intel iGPUs — Sunshine then silently
# falls back to software x264. Requires RPM Fusion (enabled above).
dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld --allowerasing

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
    version=$(dnf repoquery --installed --qf '%{version}' akmod-nvidia-open | cut -d. -f1-2 | tr . -)
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
    ripgrep \
    tmux \
    stow \
    podman \
    steam \
    kitty \
    qbittorrent \
    vlc \
    libreoffice \
    focuswriter \
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
    asusctl \
    keepassxc

echo "📱 Installing Flatpak applications..."
# Ensure Flathub is available
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install Flatpak applications
flatpak install --or-update --assumeyes flathub \
    com.spotify.Client \
    com.rafaelmardojai.Blanket \
    it.mijorus.gearlever \
    com.bitwarden.desktop

#######################
# Spicetify (themes the Flatpak Spotify)
#######################

# Spotify is the official Flathub Flatpak installed above; Spicetify themes it
# (BurntSienna + ad-banner-hiding CSS). Install the CLI and Marketplace here as
# the target user. The theme/config lives in dotfiles (~/.config/spicetify) and
# is (re)applied by the `spicetify-reapply` script — required after every Spotify
# update, which rebuilds the read-only Flatpak deployment and wipes the patch.
# The installers' auto-apply may no-op on a fresh Flatpak (Spotify not launched
# yet); that's expected, so don't let it halt the script.
echo "🎵 Installing Spicetify (CLI + Marketplace)..."
sudo -Hu "$SUDO_USER" bash -c 'curl -fsSL https://raw.githubusercontent.com/spicetify/cli/main/install.sh | sh' || true
sudo -Hu "$SUDO_USER" bash -c 'curl -fsSL https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.sh | sh' || true

#######################
# Sunshine Installation
#######################
dnf copr enable lizardbyte/stable -y
dnf install -y Sunshine
setcap cap_sys_admin+p $(readlink -f $(which sunshine))

#######################
# Development Environment
#######################

echo "🛠️ Setting up development environment..."
USER_HOME="/home/$SUDO_USER"

# Install UV package manager (as the target user, into their home)
echo "📦 Installing UV package manager and Python tools..."
sudo -Hu "$SUDO_USER" bash -c 'curl -LsSf https://astral.sh/uv/install.sh | sh'
sudo -Hu "$SUDO_USER" "$USER_HOME/.local/bin/uv" tool install ruff pre-commit basedpyright nsz

# Install Rust (as the target user, into their home)
echo "🦀 Installing Rust and development tools..."
sudo -Hu "$SUDO_USER" bash -c "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"

# Add Cargo environment to bashrc if not already a symlink (dotfiles) and not present
if [ ! -L "$USER_HOME/.bashrc" ] && ! grep -q '\.cargo/env' "$USER_HOME/.bashrc"; then
    echo '# Load Cargo environment' >> "$USER_HOME/.bashrc"
    echo '. "$HOME/.cargo/env"' >> "$USER_HOME/.bashrc"
fi

# Install Rust components (as the target user)
sudo -Hu "$SUDO_USER" "$USER_HOME/.cargo/bin/rustup" component add rustfmt clippy rust-analyzer rust-src rust-docs

# Install Zed editor (into ~/.local/zed.app, symlinks ~/.local/bin/zed)
echo "✏️  Installing Zed editor..."
sudo -Hu "$SUDO_USER" bash -c 'curl -f https://zed.dev/install.sh | sh'

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

# Load ntsync module at boot (kernel side: exposes /dev/ntsync)
echo ntsync | tee /etc/modules-load.d/ntsync.conf
modprobe ntsync

# Userspace side: make ntsync the default sync backend for ALL Proton games
# (Steam + Heroic). Proton's launch script reads these beneath each launcher's
# own esync/fsync toggles, so this wins without editing any per-game config.
# Without this, esync/fsync take precedence and /dev/ntsync sits unused.
ENVD_DIR="/home/$SUDO_USER/.config/environment.d"
mkdir -p "$ENVD_DIR"
cat > "$ENVD_DIR/ntsync.conf" <<'EOF'
# Make ntsync the default sync backend for all Proton games (Steam + Heroic).
PROTON_USE_NTSYNC=1
PROTON_NO_ESYNC=1
PROTON_NO_FSYNC=1
EOF
cat > "$ENVD_DIR/dlss.conf" <<'EOF'
# Auto-update DLSS DLLs to the latest version shipped with the NVIDIA driver,
# per game, at launch (Steam + Heroic). No-op for games that don't use DLSS;
# upgrades the bundled nvngx_dlss DLL for those that do. Still requires DLSS to
# be enabled in each game's own graphics menu.
PROTON_ENABLE_NGX_UPDATER=1
EOF
chown -R "$SUDO_USER:$SUDO_USER" "$ENVD_DIR"
echo "✅ ntsync set as default Proton sync backend (takes effect after re-login)"
echo "✅ DLSS auto-updater enabled for Proton games (takes effect after re-login)"

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
STEAM_DESKTOP="/home/$SUDO_USER/.local/share/applications/steam.desktop"
if [ -f "$STEAM_DESKTOP" ]; then
    # Create backup of original desktop file
    cp "$STEAM_DESKTOP" "$STEAM_DESKTOP.backup"

    # Update the Exec line to include steamos3 parameter
    sed -i 's|^Exec=/usr/bin/steam %U$|Exec=/usr/bin/steam -steamos3 %U|' "$STEAM_DESKTOP"
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
# Bluetooth controllers
#######################

# Disable Bluetooth ERTM (Enhanced Retransmission Mode). Third-party / counterfeit
# DualShock 4 controllers choke on the L2CAP ERTM negotiation and self-disconnect
# ~1.4s after connecting; disabling ERTM lets them stay connected on the full
# hid_playstation driver (gyro/touchpad/lightbar intact). ERTM is only used by
# HID/controllers, so disabling it is safe for other Bluetooth devices.
echo "🎮 Disabling Bluetooth ERTM for third-party DualShock 4 controllers..."
echo 'options bluetooth disable_ertm=1' | tee /etc/modprobe.d/bluetooth-disable-ertm.conf
echo 1 > /sys/module/bluetooth/parameters/disable_ertm 2>/dev/null || true

#######################
# Logitech MX Vertical — remap top "DPI" button (logiops)
#######################

# The MX Vertical's top "DPI Switch" button (HID++ CID 0xFD) is firmware-trapped and
# emits no evdev event, so it can't be bound directly. logiops remaps it via the kernel
# uinput device (see etc/logid.cfg: CID 0xFD -> KEY_F12), which — unlike Solaar's XTEST
# injection — reaches games that read raw input (WoW under Proton/XWayland). The config
# is deployed to /etc/logid.cfg by install.sh. A udev rule (etc/udev/rules.d/99-logid-rebind.rules,
# also deployed by install.sh) restarts logid when the mouse wakes from deep sleep, since
# logiops otherwise loses the DPI->F12 binding on reconnect. Only act if a Logitech
# receiver/device is present.
if lsusb 2>/dev/null | grep -qi "logitech"; then
    echo "🖱️  Installing logiops for Logitech MX Vertical button remap..."
    dnf install -y logiops
    systemctl enable --now logid
    # Load the rebind-on-wake udev rule without a reboot.
    udevadm control --reload-rules && udevadm trigger --subsystem-match=hid
else
    echo "🖱️  No Logitech device detected, skipping logiops setup."
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
sudo -Hu "$SUDO_USER" fc-cache -fv

# Install and configure Starship prompt
echo "🚀 Installing Starship prompt..."
curl -sS https://starship.rs/install.sh | sh
if [ ! -L "/home/$SUDO_USER/.bashrc" ] && ! grep -q 'starship init bash' "/home/$SUDO_USER/.bashrc"; then
    echo '# Starship Prompt' >> "/home/$SUDO_USER/.bashrc"
    echo 'eval "$(starship init bash)"' >> "/home/$SUDO_USER/.bashrc"
fi

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
echo "🔄 Updating system (DNF, Flatpak)..."
dnf upgrade -y --refresh
flatpak update -y

#######################
# Quad9 DNS Setup
#######################
echo "🌐 Setting up Quad9 DNS servers for enhanced privacy and security..."
# System-wide Quad9 DNS setup for Fedora (NetworkManager)

# 1. Create main config to ensure NetworkManager handles DNS itself
tee /etc/NetworkManager/conf.d/dns.conf > /dev/null <<'EOF'
[main]
dns=default
EOF

# 2. Create global DNS config file with Quad9 servers
tee /etc/NetworkManager/conf.d/90-dns-servers.conf > /dev/null <<'EOF'
[global-dns]
servers=9.9.9.9,149.112.112.112
EOF

# 3. Restart NetworkManager to apply changes
echo "Restarting NetworkManager..."
systemctl restart NetworkManager

#######################
# Final Instructions
#######################

echo "✅ Post-installation setup complete!"
echo "In LibreOffice Writer select Tools -> Options -> View and set the Icon Theme to Colibre (SVG+Dark)."
echo "🔄 Please reboot your system to complete the setup"
