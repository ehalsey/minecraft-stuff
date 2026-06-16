# Minecraft AI Player Setup & Tooling

Setup notes, world-backup tooling, and a detailed bug report compiled while trying to
get an AI companion ("NPC you can give instructions to") working in **Minecraft Java**.

Two parallel setups were used, kept in separate game directories so their mods never mix:

| Profile | Version | Game dir | Purpose |
|---|---|---|---|
| **Maps + Waypoints** | 26.1.2 | `.minecraft` | Main world — Xaero's Minimap + World Map, coords, waypoints |
| **AI Player** | 1.21.1 | `.minecraft-ai` | AI companion experiments (+ the same Xaero maps) |

## What's here

### `docs/`
- **[AI-Player-Bug-Report.md](docs/AI-Player-Bug-Report.md)** — a thorough, reproducible
  write-up of why the **AI-Player** mod (`1.0.5.3+1.21.1`) cannot execute commands across
  *any* provider (Claude / OpenAI / custom / Ollama). Six distinct, logged failures, with
  root causes traced to decompiled classes. The headline blocker (Issue 5): the
  action/tool-calling layer (`FunctionCallerV2`) is hard-wired to Ollama, so cloud models
  can chat but never act.
- **[Minecraft-Ore-Levels-26.1.2.md](docs/Minecraft-Ore-Levels-26.1.2.md)** — best Y-levels
  for every ore (diamond Y -59, iron Y 16 / mountain peaks, ancient debris Y 15, …). Ore
  generation is unchanged since 1.18, so the chart holds through 26.1.x.

### `backups/`
Dual-world backup/restore for both installs (main = 26.1.2, ai = 1.21.1).
- **`backup-world.ps1`** — timestamped `.zip` restore points; safe to run while playing
  (skips `session.lock`, robocopy staging, only backs up on change, keeps the last 40).
  Driven by a 15-minute Scheduled Task.
- **`restore-world.ps1`** — interactive restore: pick a world set + restore point; snapshots
  the current state first as a safety net.
- **`*.bat`** — double-click launchers for the two scripts.

### `bridge/`
- **`claude_bridge.py`** — a local OpenAI-compatible shim (port 8788) that was an attempt to
  work around AI-Player's broken Anthropic path. Forwards chat to Anthropic and routes
  embeddings to local Ollama. **Unused in the end** (the mod's action layer is the real
  blocker — see the bug report). Reads its key from `anthropic.key` beside it; that file is
  **not** committed.

## Outcome

- ✅ Maps, coordinates, and waypoints (Xaero's) on both versions.
- ✅ Automatic + manual dual-world backups.
- ✅ Ore reference.
- ❌ **AI-Player** is broken on 1.21.1 (see bug report).
- 👉 Switched to **[Player2 AI NPC](https://modrinth.com/mod/player2npc)** (PlayerEngine
  framework) as the working alternative — press `H` in-game, pick a companion, talk in
  natural language. Needs the free Player2 desktop app running as the AI gateway.

## Security note

No API keys are included. `.gitignore` blocks `*.key`, `settings.json5`, and
`launcher_profiles.json`. If you fork this, keep your keys out of commits.
