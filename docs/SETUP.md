# Setup Guide

This guide installs the first `pop-os-rice` profile on Pop!_OS with the COSMIC
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

The backup command captures available COSMIC, GTK, font, icon, theme, and
wallpaper paths under the current user's home directory. It writes a
root-owned archive and manifests under `/var/backups/pop-os-rice/`, then
verifies the SHA-256 checksum, gzip stream, and tar index. It also captures
the legacy interface dconf state used for icon-theme selection.

## 3. Preview the profile

Preview every file that would be installed:

```bash
./scripts/apply.sh --dry-run --category all
```

The dry run does not create a backup or modify COSMIC settings.

## 4. Apply automated settings

Apply the panel, dock, Pop icon theme, and COSMIC Terminal settings:

```bash
./scripts/apply.sh --apply --category all
```

Every real apply creates another verified checkpoint first. Configuration
files are replaced atomically so COSMIC file watchers do not observe partial
content.

Categories can be applied independently:

```bash
./scripts/apply.sh --apply --category panel
./scripts/apply.sh --apply --category terminal
./scripts/apply.sh --apply --category icons
```

The apply script asks `cosmic-session` to restart the supervised panel after
panel changes. Log out and back in if the panel is not restarted.

## 5. Import the desktop palette

COSMIC does not currently expose a supported non-interactive theme importer.
Use the supported interface:

1. Open COSMIC Settings.
2. Go to **Desktop → Appearance**.
3. Select **Import**.
4. Choose `profiles/cosmic/theme/tokyo-night.ron`.

## 6. Import the terminal palette

1. Open COSMIC Terminal.
2. Go to **View → Color schemes**.
3. Select **Import**.
4. Choose `profiles/cosmic/terminal/tokyo-night.ron`.
5. Select **Tokyo Night Moon** as the dark color scheme.

The profile does not modify Warp.

## Verification

Confirm the scripts are syntactically valid and the profile can be previewed:

```bash
bash -n scripts/*.sh
./scripts/apply.sh --dry-run --category all
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
