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

The scripts do not install packages or download third-party assets.

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

## 1. Clone the repository

```bash
git clone https://github.com/kamleshkc2002/pop-os-rice.git
cd pop-os-rice
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

The backup command captures available COSMIC, GTK, font, icon, theme,
neofetch, and wallpaper paths under the current user's home directory. It
writes a root-owned archive and manifests under `/var/backups/pop-os-rice/`,
then verifies the SHA-256 checksum, gzip stream, and tar index. It also
captures the legacy interface dconf state used for icon-theme selection.

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

| Category | `sakura-night` | `neon-glass` |
|---|---|---|
| `theme` | Desktop palette | Desktop palette, Open Sans interface font |
| `panel` | Floating panel and dock | Transparent full-width top bar and bottom dock with applet layout |
| `applets` | — | Clock format, top-bar media controls, Minimon readouts |
| `terminal` | Terminal settings | Terminal settings, COSMIC Dark scheme |
| `icons` | Pop legacy icon theme | Cosmic icon theme |
| `fetch` | — | `~/.config/neofetch` layout |

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

`sakura-night` only; `neon-glass` selects the built-in COSMIC Dark scheme.

1. Open COSMIC Terminal.
2. Go to **View → Color schemes**.
3. Select **Import**.
4. Choose `profiles/sakura-night/terminal/sakura-night.ron`.
5. Select **Sakura Night** as the dark color scheme.

The profiles do not modify Warp.

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

## Verification

Confirm the scripts are syntactically valid and the profiles can be previewed:

```bash
bash -n scripts/*.sh
./scripts/apply.sh --dry-run --profile sakura-night --category all
./scripts/apply.sh --dry-run --profile neon-glass --category all
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
