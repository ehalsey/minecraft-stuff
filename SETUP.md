# Minecraft World Backups — Setup & Usage Guide

Automatic world backups, easy restores, and syncing your worlds between computers so you
can pick up where you left off on another PC.

## What you get

- **Automatic backups** every 15 minutes while you play — timestamped `.zip` "restore
  points," each with a stable ID like `#47`.
- **Restore** any point interactively (a safety snapshot of your current world is taken first).
- **Sync** your worlds between computers through a shared folder.

Covers both installs: **main** (`.minecraft`, 26.1.2) and **ai** (`.minecraft-ai`, 1.21.1).

## 1. Set up a computer (once per PC)

**Option A — brand-new PC, nothing installed yet.** Open PowerShell and paste one line:

```powershell
iwr https://raw.githubusercontent.com/ehalsey/minecraft-stuff/main/setup.ps1 -OutFile "$env:TEMP\mc-setup.ps1"; & "$env:TEMP\mc-setup.ps1"
```

**Option B — you already have the repo cloned.** Double-click **`Setup-Minecraft-Utilities.bat`**
(or run `.\setup.ps1`).

The setup will:

1. Install all scripts to `%APPDATA%\.minecraft\backups\`.
2. Ask to register the **15-minute auto-backup task** — say **Y**.
3. Ask for a **shared folder** to remember for syncing — enter a path both computers can
   reach: a USB drive `E:\`, a network share `\\NAS\minecraft`, or your OneDrive folder.
   (Press Enter to skip; you can add it later by re-running setup.)

Do this on **each** computer you play on, pointing them all at the **same** shared folder.

> Flags for advanced use: `setup.ps1 -NoTask` (skip the scheduled task),
> `-SyncLocation <path>` (preset the shared folder), `-NoPrompt` (non-interactive).

## 2. Everyday use

- **Backups just happen** every 15 minutes while Minecraft is running. Nothing is created
  when the game is closed and idle, and the final save written when you quit is still
  captured. To force a backup now: double-click **`Backup-Minecraft-World.bat`**.
- **Restore a world:** close Minecraft, double-click **`Restore-Minecraft-World.bat`**, pick
  the world (main/ai), then type the restore point's **ID** (e.g. `47`). It snapshots your
  current world first, then rolls back.

## 3. Move to another computer

On the PC you **played on**:

1. Double-click **`Sync-Minecraft-Backups.bat`** → choose **1 (Push)**. Copies your restore
   points to the shared folder.

On the **other** PC:

2. Double-click **`Sync-Minecraft-Backups.bat`** → choose **2 (Pull)** → it offers to
   **restore** right away (close Minecraft first).
3. Launch that profile — your world is exactly where you left it.

Sync is **additive** (never deletes anything on either side) and keeps the `#IDs` consistent
across machines.

## Good to know

- **Keep the repo public** — the one-line fresh-PC installer downloads over anonymous
  `raw.githubusercontent.com`. If you make the repo private it stops working; a clone +
  `setup.ps1` still works either way.
- **Cloud folder = easiest sync:** if your shared folder is OneDrive/Dropbox, Push/Pull is
  effectively automatic since the cloud already mirrors it between machines.
- **Same world on two PCs at once?** Back up on each independently and their IDs can collide
  (the timestamp still tells them apart) — fine for "play here, then there," just don't treat
  it as live two-way sync.

## Files (installed to `%APPDATA%\.minecraft\backups\`)

| File | What it does |
|---|---|
| `backup-world.ps1` | Creates restore points; driven by the 15-minute Scheduled Task |
| `restore-world.ps1` | Interactive restore by stable `#ID` |
| `sync-backups.ps1` | Push/Pull restore points to/from the shared folder |
| `*.bat` | Double-click launchers for the above |
| `setup.ps1` | Installer (repo root) — run once per computer |
