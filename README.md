# minecraft-stuff

A grab-bag of **Minecraft Java** tooling and notes — world backups, a mining reference, and
AI-companion setup/troubleshooting. Started life as an AI-companion experiment and grew into a
general home for the scripts and docs collected along the way.

Two setups are referenced throughout, kept in separate game directories so their mods never mix:

| Profile | Version | Game dir | Purpose |
|---|---|---|---|
| **Maps + Waypoints** | 26.1.2 | `.minecraft` | Main world — Xaero's Minimap + World Map, coords, waypoints |
| **AI companion** | 1.21.1 | `.minecraft-ai` | AI NPC experiments (+ the same Xaero maps) |

## Setup on a new computer

**New here? See the [full Setup & Usage Guide](SETUP.md)** for step-by-step instructions.

`setup.ps1` installs all the backup/restore/sync scripts into `%APPDATA%\.minecraft\backups\`,
registers the 15-minute auto-backup Scheduled Task, and remembers a shared folder so moving
worlds between machines is one-click. Two ways to run it:

- **From a clone:** double-click `Setup-Minecraft-Utilities.bat` (or run `.\setup.ps1`).
- **On a fresh PC with no clone** — one line in PowerShell downloads everything from GitHub:
  ```powershell
  iwr https://raw.githubusercontent.com/ehalsey/minecraft-stuff/main/setup.ps1 -OutFile "$env:TEMP\mc-setup.ps1"; & "$env:TEMP\mc-setup.ps1"
  ```

Then on the machine you played on run `Sync-Minecraft-Backups.bat` → **Push**, and on the other
machine run it → **Pull** (it defaults to the folder setup remembered). Flags: `setup.ps1 -NoTask`
skips the scheduled task, `-SyncLocation <path>` presets the shared folder, `-NoPrompt` runs it
non-interactively.

## What's here

### `backups/` — world backup & restore (Windows / PowerShell)
Dual-world backup/restore covering both installs (main = 26.1.2, ai = 1.21.1).
- **`backup-world.ps1`** — timestamped `.zip` restore points; safe to run while playing
  (skips `session.lock`, robocopy staging, keeps the last 40). Only does work when Minecraft
  is running *or* a world changed since its last backup, so idle ticks create nothing and the
  final save written on quit is still captured. Driven by a 15-minute Scheduled Task.
- **`restore-world.ps1`** — interactive restore: pick a world set + restore point (each has a
  stable `#ID` you can type, e.g. `47`); snapshots the current state first as a safety net.
  **Close Minecraft before restoring.**
- **`sync-backups.ps1`** — carry restore points between computers so you can pick up where you
  left off on another PC. **Push** copies this machine's backups to a shared location (USB drive,
  network share, or a cloud-synced folder like OneDrive); **Pull** brings them onto the other
  machine (and can launch a restore). Copies are additive — nothing is deleted — and each world's
  ID counter is reconciled to the highest seen, so the stable `#IDs` stay monotonic across
  machines. Note: IDs are assigned per machine, so if two computers both create backups
  independently their `#IDs` can collide (the timestamp still disambiguates).
- **`*.bat`** — double-click launchers for the scripts.

### `docs/` — references & write-ups
- **[Minecraft-Ore-Levels-26.1.2.md](docs/Minecraft-Ore-Levels-26.1.2.md)** — best Y-levels
  for every ore (diamond Y -59, iron Y 16 / mountain peaks, ancient debris Y 15, …). Ore
  generation is unchanged since 1.18, so the chart holds through 26.1.x.
- **[AI-Player-Bug-Report.md](docs/AI-Player-Bug-Report.md)** — a thorough, reproducible
  write-up of why the **AI-Player** mod (`1.0.5.3+1.21.1`) cannot execute commands across
  *any* provider (Claude / OpenAI / custom / Ollama). Six distinct, logged failures, with
  root causes traced to decompiled classes. Headline blocker (Issue 5): the action/tool-calling
  layer (`FunctionCallerV2`) is hard-wired to Ollama, so cloud models can chat but never act.

### `bridge/` — experimental
- **`claude_bridge.py`** — a local OpenAI-compatible shim (port 8788) that tried to work around
  AI-Player's broken Anthropic path. Forwards chat to Anthropic, routes embeddings to local
  Ollama. **Unused in the end** (the mod's action layer is the real blocker). Reads its key from
  `anthropic.key` beside it; that file is **not** committed.

## AI companion: what works

- ❌ **AI-Player** is broken on 1.21.1 (see the bug report).
- ✅ **[Player2 AI NPC](https://modrinth.com/mod/player2npc)** (PlayerEngine framework) works:
  press `H` in-game, pick a companion, talk in natural language. Needs the free Player2 desktop
  app running as the local AI gateway.
  - **Gotcha:** with **call-by-name chat** enabled, a companion only responds when your message
    *starts with its name* (e.g. `Ellie hello`, `Ellie follow me`). Plain messages are routed to
    nobody and silently dropped. Either prefix the name or turn off call-by-name in the mod config.

## Maps & coordinates

[Xaero's Minimap + World Map](https://modrinth.com/mod/xaeros-minimap) on both versions give you
the minimap, X/Y/Z coordinates, and waypoints. Note: the map only marks **real players** and
**waypoints** — an AI companion is a custom NPC entity, so it won't show as a player marker. Use
the minimap's creature radar for a live dot, or drop a waypoint.

## Security note

No API keys are included. `.gitignore` blocks `*.key`, `settings.json5`, and
`launcher_profiles.json`. If you fork this, keep your keys out of commits.
