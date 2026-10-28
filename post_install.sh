#!/usr/bin/bash

# Exit on any error
set -e

echo "🚀 Starting Fedora Post-Installation Setup..."

#######################
# Machine profile
#######################
# laptop or desktop, read from the firmware's chassis type (SMBIOS: 8/9/10/14/
# 30/31/32 are portables). Override with PROFILE=laptop|desktop. Most hardware
# steps below also check for their own device, so this only gates the ones
# that can't (ASUS laptop tooling).
if [ -z "${PROFILE:-}" ]; then
    case "$(cat /sys/class/dmi/id/chassis_type 2>/dev/null)" in
        8|9|10|11|14|30|31|32) PROFILE=laptop ;;
        *) PROFILE=desktop ;;
    esac
fi
IS_ASUS_LAPTOP=0
if [ "$PROFILE" = "laptop" ] && grep -qi "asus" /sys/class/dmi/id/sys_vendor 2>/dev/null; then
    IS_ASUS_LAPTOP=1
fi
echo "🖥️  Profile: $PROFILE (ASUS laptop: $IS_ASUS_LAPTOP)"

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
dnf group install -y multimedia
dnf swap -y 'ffmpeg-free' 'ffmpeg' --allowerasing
dnf upgrade -y @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin
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
# Fedora 44 folded mesa-va-drivers into mesa-dri-drivers, so swapping would
# remove the whole Mesa stack; there the freeworld package installs alongside.
if rpm -q mesa-va-drivers >/dev/null 2>&1; then
    dnf swap -y mesa-va-drivers mesa-va-drivers-freeworld --allowerasing
else
    dnf install -y mesa-va-drivers-freeworld
fi

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
    echo "🟩 NVIDIA GPU detected - Installing NVIDIA drivers and Flatpak runtime..."

    # Enable tainted repos for NVIDIA drivers
    dnf install -y rpmfusion-nonfree-release-tainted

    # Install NVIDIA drivers. Plain akmod-nvidia builds the open kernel module
    # automatically on Turing and newer GPUs (RTX 20xx+), so akmod-nvidia-open
    # isn't needed. xorg-x11-drv-nvidia-power provides the suspend/resume
    # services that save VRAM across sleep.
    dnf install -y \
        akmod-nvidia \
        xorg-x11-drv-nvidia \
        xorg-x11-drv-nvidia-cuda \
        xorg-x11-drv-nvidia-power \
        nvidia-settings
    systemctl enable nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service

    # Blacklist nouveau and nova_core (the newer in-kernel NVIDIA driver) and
    # enable NVIDIA DRM modeset
    grubby --update-kernel=ALL --args="rd.driver.blacklist=nouveau,nova_core modprobe.blacklist=nouveau,nova_core nvidia-drm.modeset=1"

    # Get NVIDIA driver version from installed package
    version=$(dnf repoquery --installed --qf '%{version}' akmod-nvidia | cut -d. -f1-2 | tr . -)
    echo "🧩 Installing Flatpak NVIDIA driver version: $version"
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak install -y flathub "org.freedesktop.Platform.GL.nvidia-$version"
    flatpak install -y flathub "org.freedesktop.Platform.GL32.nvidia-$version"

    # NVIDIA GPU hardware acceleration
    dnf install -y libva-nvidia-driver
fi

# Discrete AMD Radeon (RDNA "Navi", e.g. RX 9070). Mesa ships the driver
# (amdgpu + RADV), so nothing is needed to make it work; this adds tooling.
# AMD integrated graphics (Strix, Raphael, ...) don't match "Navi" and skip it.
if lspci | grep -iE 'VGA|Display|3D' | grep -i 'AMD/ATI' | grep -qi 'Navi'; then
    echo "🟥 Discrete AMD GPU detected - installing LACT and monitoring tools..."
    # LACT: GPU control panel (fan curve, power limit, clocks/undervolt, stats).
    # Not in Fedora's repos; upstream publishes it on COPR.
    dnf copr enable -y ilyaz/LACT
    dnf install -y lact nvtop
    systemctl enable --now lactd

    # Undervolting/overclocking in LACT needs the amdgpu overdrive bit on the
    # kernel cmdline (fan curve and power limit work without it). It marks the
    # kernel as tainted, so it's opt-in.
    if [ "${WITH_AMD_OVERDRIVE:-0}" = "1" ]; then
        grubby --update-kernel=ALL --args="amdgpu.ppfeaturemask=0xffffffff"
    fi
elif ! lspci | grep -qi nvidia; then
    echo "🖥️ Integrated AMD/Intel GPU only - no additional drivers needed"
fi

#######################
# Software Installation
#######################

echo "📦 Adding extra repositories..."
# asusctl / asusd (ASUS laptop profiles, fan curves, keyboard LEDs)
if [ "$IS_ASUS_LAPTOP" = "1" ]; then
    dnf copr enable -y lukenukem/asus-linux
    dnf install -y asusctl
fi
# FocusWriter comes from Fedora's own repo. The upstream OBS repo
# (home:gottcode) was dropped on 2026-10-24: Fedora had caught up (1.9.1) and
# the OBS build of 1.9.1-1.2 failed its signature check against the repo key.

echo "📦 Installing system applications..."
# System packages
dnf install -y \
    ksshaskpass \
    evtest \
    compsize \
    unrar \
    mtr \
    tcpdump \
    clamav \
    android-tools \
    golang \
    nodejs \
    mingw32-gcc \
    chromium \
    thunderbird \
    kio-gdrive \
    ardour8 \
    fluidsynth \
    beets \
    picard \
    kid3 \
    chromaprint-tools \
    python3-acoustid \
    easyrpg-player \
    liblcf-tools \
    openmw \
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
    kate \
    krita \
    syncthing \
    keepassxc

# EasyEffects only on the laptop: its presets are the laptop-speaker fix.
if [ "$PROFILE" = "laptop" ]; then
    dnf install -y easyeffects
fi

# OpenTabletDriver isn't packaged for Fedora; install the upstream RPM.
# The user service still has to be enabled as the user after login:
#   systemctl --user enable --now opentabletdriver.service
echo "✏️  Installing OpenTabletDriver..."
OTD_RPM=$(curl -fsSL https://api.github.com/repos/OpenTabletDriver/OpenTabletDriver/releases/latest | grep -o 'https://[^"]*x86_64\.rpm' | head -1)
if [ -n "$OTD_RPM" ]; then
    dnf install -y "$OTD_RPM"
else
    echo "⚠️  Couldn't find the OpenTabletDriver RPM, skipping."
fi

echo "📱 Installing Flatpak applications..."
# Ensure Flathub is available
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install Flatpak applications
flatpak install --or-update --assumeyes flathub \
    com.spotify.Client \
    com.discordapp.Discord \
    org.jellyfin.JellyfinDesktop \
    com.snes9x.Snes9x \
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
# The CLI lands in ~/.spicetify, not yet on PATH here; the Marketplace installer calls it.
sudo -Hu "$SUDO_USER" bash -c 'export PATH="$HOME/.spicetify:$PATH"; curl -fsSL https://raw.githubusercontent.com/spicetify/marketplace/main/resources/install.sh | sh' || true

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
# One package per call: newer uv rejects several in one "tool install".
for tool in ruff pre-commit basedpyright nsz; do
    sudo -Hu "$SUDO_USER" "$USER_HOME/.local/bin/uv" tool install "$tool"
done

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
# Desktop (RX 9070, RDNA4): GE-Proton extras for all Proton games (what the
# laptop's pge wrapper flags did, minus the NVIDIA parts).
if [ "$PROFILE" = "desktop" ]; then
cat > "$ENVD_DIR/proton-amd.conf" <<'EOF'
# GE-Proton extras for all Proton games (Steam + Heroic), desktop only.
# Wine's native Wayland driver; open games on the G27Q2.
PROTON_ENABLE_WAYLAND=1
PROTON_WAYLAND_MONITOR=DP-3
# Let games offer HDR (only does anything while HDR is on in KDE).
PROTON_ENABLE_HDR=1
# Swap FSR 3.1 in games for FSR 4 (RDNA4 runs it on its AI cores).
PROTON_FSR4_UPGRADE=1
# Hide the CPU's built-in Radeon 610M so games can't pick it over the 9070.
PROTON_HIDE_APU=1
# Per-game shader cache in the prefix (10 GB cap) instead of Mesa's shared 1 GB.
PROTON_LOCAL_SHADER_CACHE=1
EOF
fi
# MangoHud: session-wide on the desktop, opt-in on the laptop. On the hybrid
# AMD+NVIDIA laptop the session-wide Vulkan layer crashed non-game apps
# (Heroic's Electron NVML double-free, Clementine's gstvulkan deadlock, GLX
# games under NVIDIA offload). The AMD-only desktop has none of that; the
# overlay starts hidden (no_display=1) and MangoHud.conf's blacklist keeps it
# out of Steam/Heroic/editors. MANGOHUD_CONFIG adds this machine's GPU on top
# of the shared MangoHud.conf (read_cfg), whose pci_dev is the laptop's.
if [ "$PROFILE" = "desktop" ]; then
DGPU=$(lspci -D -d 1002: | grep -iE 'vga|display' | grep -i navi | head -1 | cut -d' ' -f1)
cat > "$ENVD_DIR/mangohud.conf" <<EOF
# MangoHud in every Vulkan game (Steam + Heroic), overlay hidden until toggled:
# Shift_R+Home, or Create + R3 on a controller (mangohud-pad user service).
# The colons in pci_dev must stay escaped: MangoHud splits options on ':' too.
MANGOHUD=1
MANGOHUD_CONFIG='read_cfg,pci_dev=${DGPU//:/\\:}'
EOF
else
cat > "$ENVD_DIR/mangohud.conf" <<'EOF'
# Global MangoHud injection is DISABLED: the session-wide Vulkan layer crashed
# too many non-game apps on this hybrid GPU. Set MANGOHUD=1 per game (Steam
# launch options or Heroic per-game env) when you want the overlay / FPS cap.
# To restore session-wide injection, uncomment the line below and re-login.
# Overlay starts hidden (no_display=1 in MangoHud.conf, dotfiles repo).
# Toggle overlay Shift_R+Home, cycle FPS cap Shift_L+F1.
#MANGOHUD=1
EOF
fi
chown -R "$SUDO_USER:$SUDO_USER" "$ENVD_DIR"
echo "✅ ntsync set as default Proton sync backend (takes effect after re-login)"
echo "✅ DLSS auto-updater enabled for Proton games (takes effect after re-login)"
echo "✅ MangoHud: session-wide on the desktop, opt-in on the laptop (takes effect after re-login)"

#######################
# Steam ⇄ Heroic ProtonGE unification
#######################

# Make every GE-Proton that Heroic downloads appear in Steam automatically, with
# zero per-version maintenance, by making Steam's custom-tools dir BE a symlink to
# Heroic's proton dir:
#   ~/.local/share/Steam/compatibilitytools.d  ->  ~/.config/heroic/tools/proton
# Each GE version subdir ships its own compatibilitytool.vdf, so Heroic's proton
# dir is already a valid compatibilitytools.d layout. Steam only scans the
# *immediate* children of compatibilitytools.d (it won't recurse), so a single
# nested symlink to the proton parent would NOT work — the whole dir must be the
# symlink. Official Valve Proton lives in steamapps/common/ and is unaffected.
echo "🔗 Linking Steam's compatibilitytools.d to Heroic's ProtonGE dir..."
USER_HOME="/home/$SUDO_USER"
HEROIC_PROTON="$USER_HOME/.config/heroic/tools/proton"
STEAM_COMPAT="$USER_HOME/.local/share/Steam/compatibilitytools.d"
sudo -Hu "$SUDO_USER" mkdir -p "$HEROIC_PROTON" "$(dirname "$STEAM_COMPAT")"
if [ -e "$STEAM_COMPAT" ] && [ ! -L "$STEAM_COMPAT" ]; then
    # A real dir already exists (e.g. Steam recreated it, or a prior custom tool
    # was installed into it). Move any real tools into Heroic's dir so nothing is
    # lost, then remove the now-redundant dir before symlinking.
    find "$STEAM_COMPAT" -mindepth 1 -maxdepth 1 -exec mv -t "$HEROIC_PROTON" {} +
    rmdir "$STEAM_COMPAT" 2>/dev/null || rm -rf "$STEAM_COMPAT"
fi
sudo -Hu "$SUDO_USER" ln -sfn "$HEROIC_PROTON" "$STEAM_COMPAT"

#######################
# RPG-Maker for linux wrapper
#######################
# Installs into Steam's compatibilitytools.d — which is now the symlink above, so
# the wrapper lands in Heroic's proton dir alongside the GE versions (unified).
echo "🎲 Installing RPG-Maker for Linux wrapper..."
# Run from / : wget2 2.3.0 (Fedora 44) drops the leading slash of the installer's
# "wget -P /tmp/", saving into the current directory; from / that is /tmp anyway.
(cd / && wget -qO- "https://raw.githubusercontent.com/bakustarver/rpgmakermlinux-cicpoffs/main/installgithub.sh" | bash)

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
    # Overwrite, not append, so re-running the script doesn't stack copies.
    printf '[connection]\nwifi.powersave = 2\n' | tee /etc/NetworkManager/conf.d/wifi-powersave.conf

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
# Other udev rules
#######################
# install.sh deploys etc/udev/rules.d/: 50-usb-ethernet-autosuspend.rules (keeps
# the AX88179 USB Ethernet dongle from dropping the link) and 61-drm-gpu-names.rules
# (stable /dev/dri/nvidia-dgpu and /dev/dri/amd-igpu names, used by the dotfiles
# `kwin-gpu` script to pick which GPU KWin runs on). Both are no-ops without that hardware.
udevadm control --reload-rules && udevadm trigger --subsystem-match=usb --subsystem-match=drm

#######################
# ASUS fan curves
#######################
# The TUF chassis is cooling-limited: on the stock curves the RTX 4060 sits at
# its 87°C throttle point in UE5 games, and sustained LLM inference once hit the
# thermal cutoff. Give the Performance profile a steep curve (fans at 100% from
# 80°C). Balanced/Quiet keep the firmware defaults. Values are 0-255 PWM.
if [ "$IS_ASUS_LAPTOP" = "1" ] && command -v asusctl &>/dev/null; then
    echo "🌀 Setting a steep fan curve on the ASUS Performance profile..."
    systemctl enable --now asusd || true
    FAN_CURVE="30c:64,50c:115,60c:153,70c:191,75c:230,80c:255,85c:255,99c:255"
    asusctl fan-curve -m performance -f cpu -D "$FAN_CURVE" || true
    asusctl fan-curve -m performance -f gpu -D "$FAN_CURVE" || true
    asusctl fan-curve -m performance -e true || true
else
    echo "🌀 Not an ASUS laptop (or no asusctl), skipping fan curves."
fi

#######################
# Optional extras (off by default)
#######################
# Turn these on with env vars, e.g.  sudo WITH_OLLAMA=1 WITH_ZAPRET=1 ./install.sh

# Ollama: local LLM server (installs to /usr/local/bin + ollama.service).
# The installer detects an AMD Radeon and pulls its ROCm build itself.
# On a cooling-limited laptop, cap the GPU before long runs or it can overheat
# and shut down:  sudo nvidia-smi -pl 45  (resets at reboot), and use the
# Performance profile so the fan curve above applies.
if [ "${WITH_OLLAMA:-0}" = "1" ]; then
    echo "🦙 Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
    # Flash attention + 8-bit context cache: about half the VRAM per token of
    # chat history, so a 24B model at IQ4_XS still gets ~16K context in 16 GB.
    mkdir -p /etc/systemd/system/ollama.service.d
    cat > /etc/systemd/system/ollama.service.d/10-vram.conf <<'EOF'
[Service]
Environment="OLLAMA_FLASH_ATTENTION=1"
Environment="OLLAMA_KV_CACHE_TYPE=q8_0"
EOF
    systemctl daemon-reload
    systemctl restart ollama
fi

# zapret: gets around SNI-based DPI blocking of Discord (Turkey). Uses the
# config + Discord-only hostlist in extras/zapret/ (see its README for what to do
# when the ISP changes the block).
if [ "${WITH_ZAPRET:-0}" = "1" ]; then
    echo "🛡️  Installing zapret (Discord unblock)..."
    REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ZAPRET_URL=$(curl -fsSL https://api.github.com/repos/bol-van/zapret/releases/latest | grep -o 'https://[^"]*/zapret-v[0-9.]*\.tar\.gz' | head -1)
    ZTMP=$(mktemp -d)
    curl -fsSL "$ZAPRET_URL" | tar -xz -C "$ZTMP"
    rm -rf /opt/zapret
    mv "$ZTMP"/zapret-v* /opt/zapret
    rm -rf "$ZTMP"
    /opt/zapret/install_bin.sh
    install -m 644 "$REPO_DIR/extras/zapret/config" /opt/zapret/config
    install -m 644 "$REPO_DIR/extras/zapret/zapret-hosts-user.txt" /opt/zapret/ipset/zapret-hosts-user.txt
    install -m 644 /opt/zapret/init.d/systemd/zapret.service /etc/systemd/system/zapret.service
    # Files moved in from /tmp keep the wrong SELinux label and the service
    # fails to start until they're relabelled.
    restorecon -R /opt/zapret /etc/systemd/system/zapret.service
    systemctl daemon-reload
    systemctl enable --now zapret.service
fi

# OctoWoW (private WoW server) players: its network filter drops Linux's default
# TTL of 64. That fix lives in the dotfiles `octowow` script: run `octowow ttl on`.

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
# --yes: the installer otherwise asks on /dev/tty and fails without a terminal (SSH).
curl -sS https://starship.rs/install.sh | sh -s -- --yes
if [ ! -L "/home/$SUDO_USER/.bashrc" ] && ! grep -q 'starship init bash' "/home/$SUDO_USER/.bashrc"; then
    echo '# Starship Prompt' >> "/home/$SUDO_USER/.bashrc"
    echo 'eval "$(starship init bash)"' >> "/home/$SUDO_USER/.bashrc"
fi

# Cleanup temporary directory
rm -rf "$TEMP_DIR"

#######################
# Set Default Applications
#######################
# As the user: the script runs as root, so a bare kwriteconfig6 would write
# root's kdeglobals and the desktop would keep opening Konsole.
sudo -Hu "$SUDO_USER" kwriteconfig6 --file kdeglobals --group General --key TerminalApplication kitty
sudo -Hu "$SUDO_USER" kwriteconfig6 --file kdeglobals --group General --key TerminalService kitty.desktop

#######################
# Remove Unwanted Packages
#######################

echo "🧹 Removing unwanted KDE packages..."
# Only names that are installed: dnf5 can fail the whole removal on a name it
# can't find, and the KDE spin's package set shifts between releases.
UNWANTED=(
    kmail kontact korganizer kaddressbook kalendarac kdepim-addons
    plasma-discover plasma-discover-notifier
    kwrite elisa-player dragon kmahjongg kmines kpat
)
mapfile -t TO_REMOVE < <(rpm -qa --qf '%{NAME}\n' 'akonadi*'; for p in "${UNWANTED[@]}"; do rpm -q "$p" >/dev/null 2>&1 && echo "$p"; done)
if [ "${#TO_REMOVE[@]}" -gt 0 ]; then
    dnf remove -y "${TO_REMOVE[@]}"
fi

dnf autoremove -y

#######################
# Update System
#######################
echo "🔄 Updating system (DNF, Flatpak)..."
dnf upgrade -y --refresh
flatpak update -y

#######################
# Quad9 DNS-over-TLS
#######################
# All DNS goes to Quad9 over TLS (port 853, certificate-checked) through
# systemd-resolved. The drop-in is etc/systemd/resolved.conf.d/10-dns-over-tls.conf,
# deployed by install.sh; `Domains=~.` makes it win over the DHCP/ISP servers.
# Captive portals (hotel/airport wifi) can't be reached with this on: move the
# drop-in aside and restart systemd-resolved to log in, then put it back.
echo "🌐 Enabling Quad9 DNS-over-TLS via systemd-resolved..."
systemctl restart systemd-resolved

#######################
# Final Instructions
#######################

echo "✅ Post-installation setup complete!"
echo "In LibreOffice Writer select Tools -> Options -> View and set the Icon Theme to Colibre (SVG+Dark)."
echo "🔄 Please reboot your system to complete the setup"
