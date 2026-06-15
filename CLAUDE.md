# fedora_post_install

System-level bootstrap for a fresh **Fedora** install (the user's daily driver).
Sets up drivers, codecs, gaming + dev stacks, and QoL tweaks. Published as a
public repo (MIT). This handles **system** setup only — personal configs live in
the separate `~/dev/dotfiles` repo (GNU Stow; see its `dotfiles` skill).

## Layout
- `post_install.sh` — the real work (~12 KB). RPM Fusion, multimedia codecs, GPU
  drivers, gaming stack (Steam/Wine/GameMode/MangoHUD), dev tools (uv, rustup),
  Sunshine, fonts, Starship, Quad9 DNS, hardware fixes (MT7922 wifi, Logitech
  MX Vertical button remap via logiops), KDE cleanups. The dnf + flatpak
  package lists live under its "Software Installation" section.
- `install.sh` — thin wrapper: copies `etc/` into `/etc/`, then runs
  `post_install.sh`. Entry point: `sudo ./install.sh`.
- `etc/dnf/dnf.conf` — DNF defaults dropped into `/etc/`.
- `etc/logid.cfg` — logiops config: MX Vertical top DPI button (CID 0xFD) →
  `F12` via uinput (firmware-trapped, so Solaar/XTEST can't reach games).

## Working in this repo
- This is the canonical home for "how do I get from clean Fedora to my setup" —
  add system steps here, not to dotfiles.
- It mutates the system (installs packages, edits kernel cmdline, sets DNS).
  Per the user's standing rule, when touching kernel modules / drivers / the
  graphics stack, show the dnf transaction summary and let the user confirm
  rather than auto-`-y` (memory `feedback_destructive_dnf`).
- Hardware context lives in memory `user_hardware` (ASUS TUF, AMD iGPU + RTX
  4060 hybrid, akmod-nvidia, MT7922 wifi). Keep hardware-specific fixes in sync
  with that.
- Keep scripts POSIX-ish, idempotent where feasible, and commented — it's a
  public repo that takes contributions.
- No trailing `\` line-continuations when handing the user commands to paste
  (memory `feedback_command_formatting`).

## Related
- `~/dev/dotfiles` — user configs (Stow). post_install installs
  `mesa-va-drivers-freeworld` that the dotfiles `sunshine` package depends on.
- `~/dev/bazzite_homeserver` — the *server* equivalent (Bazzite, not Fedora);
  separate bootstrap, don't cross-pollinate package lists blindly.
