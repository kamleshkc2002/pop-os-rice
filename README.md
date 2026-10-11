# Pop!_OS COSMIC Rice

Backup-first, reproducible COSMIC desktop profiles.

## Profiles

| Profile | Look |
|---|---|
| `sakura-night` (default) | Floating, rounded top panel and side dock in a Sakura Night palette, inspired by a GNOME setup |
| `neon-glass` | Transparent full-width top bar and bottom dock, neon green window border, frosted windows, stock COSMIC Dark terminal with a neofetch layout, inspired by the [r/pop_os "COSMIC rice" post](https://www.reddit.com/r/pop_os/comments/1x0htc7/cosmic_rice/) |

Both profiles change only file-backed settings (COSMIC, plus neofetch for
`neon-glass`), `gsettings` icon selection, and supported COSMIC Settings
imports. Neither profile modifies Warp or ships wallpaper, font, or cursor
assets.

See [`docs/SETUP.md`](docs/SETUP.md) for the complete installation,
verification, and rollback workflow.

## Repository layout

- `scripts/`: backup, restore, and profile application commands
- `profiles/<name>/theme/`: COSMIC desktop palette import (`<name>.ron`) and
  toolkit settings
- `profiles/<name>/panel/`: panel and dock settings
- `profiles/<name>/applets/`: panel applet settings
- `profiles/<name>/terminal/`: COSMIC Terminal settings and palettes
- `profiles/<name>/icons/`: icon theme selection
- `profiles/<name>/fetch/`: neofetch layout
- `assets/`: licensed visual assets and their provenance

A profile provides only the categories it needs.

## Safety checkpoints

Create a Timeshift snapshot and a user-configuration archive before applying
a profile; see [`docs/SETUP.md`](docs/SETUP.md#2-create-rollback-checkpoints).
Timeshift commonly excludes home directories, so restoring only a Timeshift
snapshot may not restore COSMIC settings. Use `scripts/restore.sh` for the
separate user configuration archive.

## What `sakura-night` changes

- A compact, floating top panel
- A floating right-side dock
- Panel and dock translucency, spacing, and rounded corners
- The Sakura Night desktop palette
- The preinstalled Pop icon theme for legacy applications
- COSMIC Terminal dark mode, font size, opacity, and header behavior

COSMIC Terminal still requires its graphical importer for the Sakura Night
terminal palette; see [Import the terminal palette](#import-the-terminal-palette).

## What `neon-glass` changes

- Top bar: fully transparent, edge to edge. Power and ASCII battery on the
  left, a `8 Oct, 2:47:37 pm` clock in the center, and the tray, media
  controls, volume, notifications, and network on the right.
- Bottom dock: fully transparent, edge to edge. Pinned apps on the left,
  weather in the center, and Minimon `MEM` / `TEMP` / `CPU` readouts on the
  right.
- Desktop theme: COSMIC Dark neutrals with a `#6EF26E` neon green accent, a
  4 px active-window border, and frosted windows and system interface.
- Fonts and icons: Open Sans interface font and the Cosmic icon theme.
- COSMIC Terminal: the built-in COSMIC Dark color scheme, Noto Sans Mono 14,
  85% opacity, and the header bar.
- neofetch: a pillar logo, cyan keys, CPU and disk usage bars, and two rows of
  color blocks.

`neon-glass` needs three COSMIC Store applets and neofetch; see
[`docs/SETUP.md`](docs/SETUP.md#neon-glass-prerequisites). The apply script
warns about any panel applet that is not installed.

## Preview automated changes

```bash
./scripts/apply.sh --dry-run --profile sakura-night --category all
./scripts/apply.sh --dry-run --profile neon-glass --category all
```

`--profile` defaults to `sakura-night`.

## Apply automated changes

```bash
./scripts/apply.sh --apply --profile neon-glass --category all
```

The apply script creates and verifies a new user-configuration archive before
copying any settings. Run categories separately if desired:

```bash
./scripts/apply.sh --apply --profile neon-glass --category theme
./scripts/apply.sh --apply --profile neon-glass --category panel
./scripts/apply.sh --apply --profile neon-glass --category applets
./scripts/apply.sh --apply --profile neon-glass --category terminal
./scripts/apply.sh --apply --profile neon-glass --category icons
./scripts/apply.sh --apply --profile neon-glass --category fetch
```

The `theme` category runs the supported `cosmic-settings appearance import`
command with `profiles/<name>/theme/<name>.ron`. The apply script restarts
`cosmic-panel` after theme, panel, or applet changes. Log out and back in if
the session supervisor does not restart it.

## Import the terminal palette

`sakura-night` only. Open COSMIC Terminal, go to **View → Color schemes**,
choose **Import**, and select
`profiles/sakura-night/terminal/sakura-night.ron`. Then select
**Sakura Night** as the dark color scheme.

`neon-glass` selects the built-in **COSMIC Dark** scheme automatically.

## Backups

Create a user-configuration checkpoint:

```bash
./scripts/backup.sh --label before-manual-change
```

List available checkpoints:

```bash
./scripts/restore.sh --list
```

Inspect a checkpoint without restoring it:

```bash
./scripts/restore.sh \
  --archive /var/backups/pop-os-rice/<checkpoint> \
  --dry-run
```

Restore a checkpoint explicitly:

```bash
./scripts/restore.sh \
  --archive /var/backups/pop-os-rice/<checkpoint> \
  --restore
```

The restore script takes another checkpoint before extracting the selected
archive. System-level restoration is intentionally left to Timeshift:

```bash
sudo timeshift --restore --snapshot <snapshot-name>
```

Review Timeshift's target and bootloader prompts carefully before restoring.

## Scope and limitations

The `sakura-night` reference screenshot uses GNOME Shell extensions and a
modified Jasper theme. COSMIC cannot reproduce its separated top-panel islands
exactly. The profile translates the visual direction using supported COSMIC
features instead of installing incompatible GNOME extensions or writing
derived internal theme files.

`neon-glass` leaves out the reference wallpaper and the album-art widget,
which appears to be a Spotify window rather than a COSMIC setting. A few
settings stay manual because they are hardware-specific or live outside COSMIC
configuration; see [`docs/SETUP.md`](docs/SETUP.md#neon-glass-manual-steps).
