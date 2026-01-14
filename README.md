# Fedora Post-Install Setup

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Fedora Version](https://img.shields.io/badge/Fedora-42+-blue.svg)](https://getfedora.org/)
[![Bash](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)

I have been trying different linux distros in the past years and found myself coming back to Fedora a few times until I finally settled with it for my daily driver. I wanted to automate things I did after the initial installation, so here it is:

A comprehensive post-installation setup script collection for Fedora Linux, focusing on gaming, development, and multimedia support. Features automated setup of drivers, codecs, gaming tools, development environments, and quality-of-life improvements.

- Custom `.bashrc` configuration with useful aliases and functions
- Custom executable scripts in `usr/bin/`
- Preconfigured dotfiles in `.config/` for various applications
- A post-installation script (`post_install.sh`) that sets up various system configurations

## Features

### Packages To Install

The dnf and flatpak packages to be installed to the system can be found and modified in `post_install.sh` under `Software Installation` section.

### Custom Tools

### Custom Bash Functions
- `download_playlist`: A YouTube playlist downloader that extracts audio in MP3 format
- `reverse_video`: A sophisticated video reversal tool with quality and memory management options
- `update_all`: A comprehensive system update function that handles:
  - System packages (DNF)
  - Flatpak applications

### Custom Aliases
- `py` for Python 3
- `venv` for activating Python virtual environments
- `code` for VS Code Insiders
- `ls` and `ll` using `lsd` for enhanced directory listings
- Colored `grep` output

### Application Configurations
The `.config/` directory contains preconfigured settings for various applications:

#### Starship
Modern, minimal, and customizable prompt for any shell
- Location: `.config/starship.toml`

#### EasyEffects
Audio effects for PipeWire applications
- Location: `.config/easyeffects/`
- Included presets:
  - **Output Profiles**:
    - Laptop Booster (For Speakers)
    - Empty (For HDMI and Headset)
  - **Device Configurations**:
    - HDMI output
    - Analog speakers
    - Bluetooth headset

#### Kitty
A fast, feature-rich, GPU based terminal emulator
- Location: `.config/kitty/`
- Features:
  - Custom theme configuration with Monokai Pro
  - Configured to use Cousine Nerd Font

#### KGlobalShortcuts
KDE Plasma global keyboard shortcuts configuration
- Location: `.config/kglobalshortcutsrc`

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/post_install.git
   cd post_install
   ```

2. Run the installer script with sudo privileges:
   ```bash
   sudo ./install.sh
   ```

The installer will:
1. Back up your existing `.bashrc` (if any) to `.bashrc.backup`
2. Install the new `.bashrc` configuration
3. Copy application configurations from `.config/` to your home directory
4. Copy and make executable all custom scripts to `/usr/bin/`
5. Run the post-installation script (`post_install.sh`)

## Note

Please review the scripts before running them to ensure they align with your needs. You may want to check:
- `.bashrc` for the custom aliases and functions
- `usr/bin/` for the custom executables
- `post_install.sh` for the post-installation configurations

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. Here's how you can contribute:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Guidelines
- Keep scripts POSIX-compliant where possible
- Add comments explaining complex operations
- Update documentation when adding new features
- Test your changes before submitting
- Follow the existing code style

## Security

The scripts in this repository modify system settings and install packages. Please review the code before running it on your system. While we strive to maintain security, use at your own risk.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [RPM Fusion](https://rpmfusion.org/) for additional package repositories
- [Starship](https://starship.rs/) for the cross-shell prompt