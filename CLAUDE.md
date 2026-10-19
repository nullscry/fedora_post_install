# fedora_post_install

System-level bootstrap for a fresh **Fedora** install (the user's daily driver).
Sets up drivers, codecs, gaming + dev stacks, and QoL tweaks. Published as a
public repo (MIT). This handles **system** setup only — personal configs live in
the separate `~/dev/dotfiles` repo (GNU Stow; see its `dotfiles` skill).

## Layout
- `post_install.sh` — the real work (~12 KB). RPM Fusion, multimedia codecs, GPU
  drivers, gaming stack (Steam/Wine/GameMode/MangoHUD), dev tools (uv, rustup),
  Sunshine, fonts, Starship, Quad9 DNS-over-TLS, hardware fixes (MT7922 wifi,
  Logitech MX Vertical button remap via logiops, ASUS Performance fan curve),
  KDE cleanups. The dnf + flatpak package lists live under its "Software
  Installation" section. Opt-in extras via env vars: `WITH_OLLAMA=1`,
  `WITH_ZAPRET=1`, `WITH_AMD_OVERDRIVE=1`.
- Two machines run it: the ASUS TUF laptop (`nullscry-tuf`) and the desktop
  (`nullscry-desktop`, 7800X3D + RX 9070, ordered 2026-10-19). `PROFILE` is
  auto-detected from `/sys/class/dmi/id/chassis_type` (override
  `PROFILE=laptop|desktop`); only ASUS tooling is gated on it, every other
  hardware step checks for its own device. Don't add a desktop/laptop branch
  for something that can be detected.
- `install.sh` — thin wrapper: copies `etc/` into `/etc/`, then runs
  `post_install.sh`. Entry point: `sudo ./install.sh`. Anything under `etc/`
  is copied blindly, so files that only belong on some machines go in
  `extras/` and get installed by an opt-in section instead.
- `etc/dnf/dnf.conf` — DNF defaults dropped into `/etc/`.
- `etc/logid.cfg` — logiops config: MX Vertical top DPI button (CID 0xFD) →
  `F12` via uinput (firmware-trapped, so Solaar/XTEST can't reach games).
- `etc/udev/rules.d/` — logid rebind-on-wake, stable GPU names for the
  dotfiles `kwin-gpu` script, AX88179 dongle autosuspend off.
- `etc/systemd/resolved.conf.d/` — Quad9 DoT (replaced the old NetworkManager
  global-dns setup).
- `extras/zapret/` — zapret config + Discord hostlist (memory
  `project_discord_zapret_dot`).
- Kept elsewhere on purpose: the OctoWoW TTL nftables rule is managed by the
  dotfiles `octowow ttl on`; MangoHud is opt-in per game (the script writes a
  commented-out `MANGOHUD=1`).

## Keeping it in sync
Last full sweep vs the live system: 2026-10-18. To re-check, compare
`dnf repoquery --userinstalled`, `flatpak list --app`, `/etc/udev/rules.d`,
`/etc/modprobe.d`, `~/.config/environment.d` and enabled services against the
script.

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
