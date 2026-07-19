# Pop!_OS COSMIC Rice

A backup-first, reproducible COSMIC desktop configuration inspired by a
Tokyo Night GNOME setup.

## Project status

The first COSMIC profile is complete and validated:

- Backup, restore, dry-run, and atomic apply tooling is available.
- Panel, dock, and COSMIC Terminal settings are reproducible.
- The preinstalled Pop icon theme is selected reproducibly.
- Tokyo Night desktop and terminal palettes are ready for supported UI import.
- Warp is intentionally outside the profile.
- Unlicensed wallpaper, font, and cursor assets are intentionally absent.

See [`docs/SETUP.md`](docs/SETUP.md) for the complete installation,
verification, and rollback workflow.

## Repository layout

- `scripts/`: backup, restore, and profile application commands
- `profiles/cosmic/panel/`: automated panel and dock settings
- `profiles/cosmic/icons/`: automated legacy application icon selection
- `profiles/cosmic/terminal/`: automated terminal settings and palette import
- `profiles/cosmic/theme/`: COSMIC desktop palette import
- `assets/`: licensed visual assets and their provenance
- `state/`: non-secret checkpoint metadata

## Safety checkpoint

The initial checkpoint was verified before this repository was created:

- Timeshift snapshot: `2026-07-18_22-05-54`
- User configuration archive:
  `/var/backups/pop-os-rice/20260718-220721`
- Archive SHA-256:
  `575758ba0433a15d515abfcf4c100db05841d16c2d3e697d7d5cdbc091fdbdfc`

Timeshift excludes `/home/kamlesh/**`, so restoring only the Timeshift
snapshot will not restore COSMIC settings. Use `scripts/restore.sh` for the
separate user configuration archive.

## What the first profile changes

The automated profile changes only stable, file-backed COSMIC settings:

- A compact, floating top panel
- A floating left-side dock
- Panel and dock translucency, spacing, and rounded corners
- The preinstalled Pop icon theme for legacy applications
- COSMIC Terminal dark mode, font size, opacity, and header behavior

It does not modify Warp.

COSMIC does not currently expose a supported command-line theme importer.
The desktop and terminal Tokyo Night palettes are therefore supplied as RON
files for import through their supported interfaces:

- Desktop: `profiles/cosmic/theme/tokyo-night.ron`
- Terminal: `profiles/cosmic/terminal/tokyo-night.ron`

## Preview automated changes

```bash
./scripts/apply.sh --dry-run --category all
```

## Apply automated changes

```bash
./scripts/apply.sh --apply --category all
```

The apply script creates and verifies a new user-configuration archive before
copying any settings. Run categories separately if desired:

```bash
./scripts/apply.sh --apply --category panel
./scripts/apply.sh --apply --category terminal
./scripts/apply.sh --apply --category icons
```

The apply script restarts `cosmic-panel` after panel changes. Log out and back
in if the session supervisor does not restart it.

## Import the desktop palette

Open COSMIC Settings, go to **Desktop → Appearance**, choose **Import**, and
select `profiles/cosmic/theme/tokyo-night.ron`.

## Import the terminal palette

Open COSMIC Terminal, go to **View → Color schemes**, choose **Import**, and
select `profiles/cosmic/terminal/tokyo-night.ron`. Then select **Tokyo Night
Moon** as the dark color scheme.

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
  --archive /var/backups/pop-os-rice/20260718-220721 \
  --dry-run
```

Restore a checkpoint explicitly:

```bash
./scripts/restore.sh \
  --archive /var/backups/pop-os-rice/20260718-220721 \
  --restore
```

The restore script takes another checkpoint before extracting the selected
archive. System-level restoration is intentionally left to Timeshift:

```bash
sudo timeshift --restore --snapshot 2026-07-18_22-05-54
```

Review Timeshift's target and bootloader prompts carefully before restoring.

## Scope and limitations

The reference screenshot uses GNOME Shell extensions and a modified Jasper
theme. COSMIC cannot reproduce its separated top-panel islands exactly. This
profile translates the visual direction using supported COSMIC features
instead of installing incompatible GNOME extensions or writing derived
internal theme files.

The checkpoint identifiers above document the original development machine.
New installations must create their own Timeshift snapshot and user
configuration archive before applying the profile.
