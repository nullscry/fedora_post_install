# Fedora Post-Install Setup

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Fedora Version](https://img.shields.io/badge/Fedora-42+-blue.svg)](https://getfedora.org/)
[![Bash](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)

I have been trying different linux distros in the past years and found myself coming back to Fedora a few times until I finally settled with it for my daily driver. I wanted to automate things I did after the initial installation, so here it is:

A post-installation setup script for Fedora Linux, focusing on gaming, development, and multimedia support. Sets up drivers, codecs, gaming tools, development environments, and a few quality-of-life tweaks.

This repo only handles the **system-level** bootstrap. Personal dotfiles (shell, terminal, KDE config, etc.) live in a separate repo and are managed with [GNU Stow](https://www.gnu.org/software/stow/).

## What this does

- `post_install.sh` — installs RPM Fusion, multimedia codecs, GPU drivers, gaming stack (Steam / Wine / GameMode / MangoHUD), development tools (uv, rustup), Sunshine, fonts, Starship, sets Quad9 DNS, applies hardware-specific fixes (MT7922 wifi, Logitech MX Vertical button remap via logiops), and a few KDE cleanups.
- `etc/dnf/dnf.conf` — sane DNF defaults copied to `/etc/dnf/`.
- `etc/logid.cfg` — logiops config; remaps the MX Vertical's firmware-trapped top DPI button to `F12` via uinput.
- `etc/udev/rules.d/99-logid-rebind.rules` — restarts `logid` when the MX Vertical wakes from deep sleep, so the DPI→F12 remap survives reconnects (logiops drops the binding otherwise).
- `install.sh` — thin wrapper that copies `etc/` and runs `post_install.sh`.

The dnf and flatpak package lists live in `post_install.sh` under the `Software Installation` section.

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/fedora_post_install.git
   cd fedora_post_install
   ```

2. Run the installer with sudo:
   ```bash
   sudo ./install.sh
   ```

The installer will:
1. Copy `etc/` configurations into `/etc/`
2. Run `post_install.sh`

## Note

Please review the scripts before running them. In particular check `post_install.sh` for the package list, kernel cmdline args, and DNS settings.

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