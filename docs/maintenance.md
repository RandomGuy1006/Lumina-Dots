# Maintenance guide

## Daily commands

```bash
bash install.sh update --host=loq-15irx9
bash install.sh doctor --host=loq-15irx9
bash install.sh backup before-big-change
```

## What `update` does

- creates a named backup snapshot
- pulls repo updates if the remote exists
- updates official packages
- updates AUR packages
- skips volatile pinned desktop packages during routine updates: `ags-hyprpanel-git`, `hyprswitch`, `walker-bin`, `matugen-bin`
- strictly creates Snapper snapshots on Btrfs or Timeshift snapshots on ext4 before bulk package changes; if the snapshot cannot be made, package changes abort
- configures `grub-btrfs` automatically on GRUB systems so Snapper snapshots appear in the boot menu
- re-links config packages
- reapplies host tuning
- regenerates theme outputs
- runs the doctor checks

## Verified package baselines

Current manifests resolve to:

- **112 unique pacman packages**
- **11 default AUR entries**

## Safe maintenance rules

- Test desktop-facing changes first against `linux-lts`.
- Keep generated theme outputs ignored in git.
- Prefer host overlays or templates over one-off edits in live config files.
- Update pinned desktop packages intentionally, one at a time, after `bash install.sh backup "before-pinned-update"`.
- If a package update breaks Hyprland, use the fallback config first, then use the offline rollback flow from the recovery guide before debugging aggressively.

## When to rerun specific commands

- `bash install.sh link` after moving the repo or adding new config files
- `bash install.sh theme` after changing wallpapers or Matugen templates
- `bash install.sh doctor` after kernel, portal, or session changes

## Quality gates

```bash
python3 scripts/quality.py static
python3 scripts/quality.py unit
python3 scripts/quality.py integration
python3 scripts/quality.py recovery
python3 scripts/quality.py visual
python3 scripts/quality.py all --json
```

`release` additionally runs live runtime validation and is intended for an Arch + Hyprland test machine.
