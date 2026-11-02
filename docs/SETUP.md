# Setup Guide

This guide installs a `pop-os-rice` profile on Pop!_OS with the COSMIC
desktop. The workflow separates system rollback from user-configuration
rollback because Timeshift commonly excludes home directories.

## Requirements

- Pop!_OS with a COSMIC Wayland session
- Bash
- Git
- `coreutils`, `findutils`, `tar`, `gzip`, `dconf`, `gsettings`, and
  `dpkg-query`
- `sudo` access
- Timeshift for system-level rollback

The scripts do not install packages or download third-party assets. The
cosmic-rices prerequisites below use upstream downloads and installers.

## neon-glass prerequisites

Skip this section for `sakura-night`.

Install the COSMIC Store applets used by the panel and dock, and neofetch:

```bash
flatpak install --user cosmic \
  com.github.pewmoe.cosmic-ext-ASCII-dot-battery \
  io.github.cosmic_utils.minimon-applet \
  io.github.cosmic_utils.weather-applet
sudo apt install neofetch
```

The applets are also available in **COSMIC Store → COSMIC Applets** as
Cosmic Ascii Battery, Minimon, and Weather. `apply.sh` prints
`warning: panel applet not installed: <id>` for any missing applet; COSMIC
leaves that slot empty until the applet is installed.

## cosmic-rices prerequisites

Skip this section for `sakura-night` and `neon-glass`.

Every cosmic-rices profile uses two Maple Mono families: **Maple Mono Normal**
for the interface and **Maple Mono Normal NFM** for monospace text and the
terminal. NFM is only published in the v8 releases, which are pre-releases at
the time of writing:

```bash
base=https://github.com/subframe7536/maple-font/releases
cd "$(mktemp -d)"
curl -fsSLO "$base/latest/download/MapleMonoNormal-TTF.zip"
echo "$(curl -fsSL "$base/latest/download/MapleMonoNormal-TTF.sha256")  MapleMonoNormal-TTF.zip" \
  | sha256sum -c -
curl -fsSLO "$base/download/v8.0-beta.3/MapleMonoNormal-NFMono-unhinted.zip"
mkdir -p ~/.local/share/fonts/maple-mono
unzip -qo MapleMonoNormal-TTF.zip '*.ttf' -d ~/.local/share/fonts/maple-mono
unzip -qo MapleMonoNormal-NFMono-unhinted.zip '*.ttf' -d ~/.local/share/fonts/maple-mono
fc-cache -f ~/.local/share/fonts
fc-match -f '%{family}\n' 'Maple Mono Normal NFM'
```

The last command prints `Maple Mono Normal NFM` when the install worked.

Each profile also needs its icon pack, for example `Cosmic-Noir-Orange` for
`noir`; `profiles/<name>/icons/icon-theme` names it. `apply.sh` stops before
changing anything if the pack is missing. Install it with the rice's own
installer, which downloads the pack from
[cosmic-icon-themes](https://github.com/atraxsrc/cosmic-icon-themes) and
verifies its checksum; `--no-activate` leaves activation to `apply.sh`:

```bash
git submodule update --init vendor/cosmic-noir-theme
vendor/cosmic-noir-theme/icons/install.sh --no-activate
```

## 1. Clone the repository

```bash
git clone https://github.com/kamleshkc2002/pop-os-rice.git
cd pop-os-rice
```

Every profile works without the `vendor/` submodules. Check out only the
rices you need: all 28 take about 2.7 GB.

```bash
git submodule update --init vendor/cosmic-noir-theme vendor/cosmic-dossier-theme
```

## 2. Create rollback checkpoints

Create and verify a labeled Timeshift snapshot before changing system or
desktop configuration:

```bash
sudo timeshift --create \
  --comments "Before pop-os-rice COSMIC customization" \
  --scripted
sudo timeshift --list
```

Create the separate user-configuration checkpoint:

```bash
./scripts/backup.sh --label initial-baseline
```

The backup command captures available COSMIC, GTK, Qt (qt5ct/qt6ct), bat,
btop, font, icon, theme, neofetch, and wallpaper paths under the current
user's home directory. It writes a root-owned archive and manifests under
`/var/backups/pop-os-rice/`, then verifies the SHA-256 checksum, gzip stream,
and tar index. It also captures the legacy interface dconf state used for
icon-theme selection.

## 3. Preview the profile

Preview every file that would be installed:

```bash
./scripts/apply.sh --dry-run --profile neon-glass --category all
```

The dry run does not create a backup or modify COSMIC settings. `--profile`
defaults to `sakura-night`.

## 4. Apply automated settings

```bash
./scripts/apply.sh --apply --profile neon-glass --category all
```

Every real apply creates another verified checkpoint first. Configuration
files are replaced atomically so COSMIC file watchers do not observe partial
content.

Categories can be applied independently. `all` applies every category the
profile provides:

| Category | `sakura-night` | `neon-glass` | cosmic-rices profiles |
|---|---|---|---|
| `theme` | Desktop palette | Desktop palette, Open Sans interface font | Desktop palette, Maple Mono fonts, window buttons |
| `panel` | Floating panel and dock | Transparent full-width top bar and bottom dock with applet layout | — |
| `applets` | — | Clock format, top-bar media controls, Minimon readouts | — |
| `terminal` | Terminal settings | Terminal settings, COSMIC Dark scheme | Terminal settings, rice scheme selection, follows desktop mode |
| `icons` | Pop legacy icon theme | Cosmic icon theme | Rice icon pack |
| `fetch` | — | `~/.config/neofetch` layout | — |

```bash
./scripts/apply.sh --apply --profile neon-glass --category panel
```

The apply script restarts `cosmic-panel` after theme, panel, or applet
changes. Log out and back in if the panel is not restarted.

## 5. Apply the desktop palette

The `all` category imports the profile's palette through COSMIC Settings. It
can also be applied independently:

```bash
./scripts/apply.sh --apply --profile neon-glass --category theme
```

This runs the supported `cosmic-settings appearance import` command with
`profiles/<profile>/theme/<profile>.ron` rather than writing derived internal
theme files.

## 6. Import the terminal palette

`neon-glass` selects the built-in COSMIC Dark scheme and needs no import.

1. Open COSMIC Terminal.
2. Go to **View → Color schemes**.
3. Open the **Dark** tab for `sakura-night` and dark rices, or the **Light**
   tab for light rices (`profiles/<name>/SOURCE` lists the mode).
4. Select **Import**.
5. Choose `profiles/sakura-night/terminal/sakura-night.ron`, or the rice's
   main scheme, such as `profiles/noir/terminal/Noir-term.ron`.
6. For `sakura-night`, select **Sakura Night** as the dark color scheme.
   Rice profiles already select their scheme.

The profiles do not modify Warp.

## Pair a dark and a light rice

Importing a palette switches COSMIC to that palette's mode. Apply the dark
half, then the light half's `theme` and `terminal`, and the Dark/Light toggle
flips the desktop and COSMIC Terminal between them:

```bash
./scripts/apply.sh --apply --profile noir --category all
./scripts/apply.sh --apply --profile dossier --category theme
./scripts/apply.sh --apply --profile dossier --category terminal
```

Import both terminal schemes: the dark one on the **Dark** tab, the light one
on the **Light** tab. Settings shared by both modes, such as the interface font
weight and terminal opacity, come from the last profile applied with that
category.

## neon-glass manual steps

These settings are hardware-specific or live outside COSMIC configuration:

- **Minimon GPU readouts.** Minimon adds GPU charts for each detected GPU,
  keyed by device ID. Click the dock readout, open each GPU entry, and turn
  off its chart and value to leave only `MEM`, `TEMP`, and `CPU`. For an
  NVIDIA GPU the ID is the `GPU UUID` in
  `/proc/driver/nvidia/gpus/*/information`, so the same result can be written
  to `~/.config/cosmic/io.github.cosmic_utils.minimon-applet-dock/v1/gpus`:

  ```ron
  {
      "GPU-<uuid>": (
          usage: (chart_visible: false, value_visible: false),
          vram: (chart_visible: false, value_visible: false),
          temp: (chart_visible: false, value_visible: false),
          pause_on_battery: true,
          stack_values: true,
      ),
  }
  ```
- **Ascii Battery modules.** Open the applet's popup and keep only the battery
  module enabled to match the `100% [█████]` reference.
- **Weather.** Location defaults to IP lookup; set units and location in the
  applet's popup.
- **neofetch on new terminals.** Add this line to `~/.bashrc`:

  ```bash
  [[ $- == *i* ]] && command -v neofetch >/dev/null && neofetch
  ```

- **Wallpaper.** Pick one in **Settings → Desktop → Wallpaper**; the
  profile ships none.

The clock uses `"%-d %b, %-I:%M:%S %P"` in
`profiles/neon-glass/applets/config/com.system76.CosmicAppletTime/v1/format_strftime`.
Use `"%-d %b, %H:%M:%S"` for a 24-hour clock.

## cosmic-rices app themes and wallpapers

The profiles carry only the COSMIC layer. Each submodule under `vendor/` is
the complete upstream rice, with wallpapers in `backgrounds/`, cursors, and
themes for Firefox, Brave, terminals, shells, editors, and other apps. Follow
its `README.md` to install individual parts.

Their installers are not run by `apply.sh`, so take a checkpoint first:

```bash
./scripts/backup.sh --label before-rice-apps
```

The checkpoint covers the bat, btop, qt5ct/qt6ct, and GTK configuration those
installers change. Restoring it puts captured files back but does not delete
files created afterward; remove those by hand, such as `~/.config/bat/` when
it did not exist before. The installers' own `*.bak` copies hold only the
previous version and are overwritten on every rerun.

`vendor/cosmic-<name>-theme/scripts/switch.sh` installs all of them at once.
It also edits `~/.zshrc`, Neovim plugin specs, the Firefox profile, and
`~/update_system.sh`, which `backup.sh` does not capture.

## Verification

Confirm the scripts are syntactically valid and the profiles can be previewed:

```bash
bash -n scripts/*.sh
./scripts/apply.sh --dry-run --profile sakura-night --category all
./scripts/apply.sh --dry-run --profile neon-glass --category all
./scripts/apply.sh --dry-run --profile noir --category all
```

Confirm the generated profiles match the checked-out submodules; `git status`
shows no changes under `profiles/` afterward:

```bash
./scripts/import-rices.sh
git status --short profiles
```

List the available user checkpoints:

```bash
./scripts/restore.sh --list
```

Verify and inspect a checkpoint without extracting it:

```bash
./scripts/restore.sh \
  --archive /var/backups/pop-os-rice/<checkpoint> \
  --dry-run
```

## Rollback

Restore user appearance configuration independently of Timeshift:

```bash
./scripts/restore.sh \
  --archive /var/backups/pop-os-rice/<checkpoint> \
  --restore
```

The restore script verifies the selected archive and creates a fresh
`pre-restore` checkpoint before extraction.

For system-level rollback, select the snapshot created in step 2:

```bash
sudo timeshift --restore --snapshot <snapshot-name>
```

Review Timeshift's target device and bootloader selections before confirming.

## Asset policy

Only assets with known provenance and redistribution terms belong in
`assets/`. Record the author, source URL, license, and upstream checksum before
adding wallpapers, fonts, icon packs, or cursors.
