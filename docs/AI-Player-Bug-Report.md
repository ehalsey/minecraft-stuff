# AI-Player (1.21.1) — bot connects and chats but cannot execute any command, across all provider modes

## Summary

On Minecraft Java **1.21.1** with **AI-Player 1.0.5.3-release+1.21.1**, a spawned bot connects to the configured LLM and responds conversationally ("Hello, I'm your friendly companion…"), **but it can never carry out a command.** Every provider configuration fails at a *different* stage, so the bot only ever idles ("Play Mode – Chosen action: STAY").

I tested all four provider paths (native Claude, custom OpenAI-compatible, native OpenAI, and native Ollama) and hit a distinct, reproducible failure in each. Details and exact log lines below.

---

## Environment

| Component | Version |
|---|---|
| Minecraft Java | 1.21.1 |
| Mod loader | Fabric Loader 0.19.3 |
| AI-Player | 1.0.5.3-release+1.21.1 (⚠️ in-game `/configMan` title shows **v1.0.5.2-release** — version-string mismatch) |
| Fabric API | 0.116.12+1.21.1 |
| Carpet | 1.21-1.4.147 |
| Ollama | 0.30.6 (`llama3.2:latest`, `nomic-embed-text:latest` installed, server reachable at 127.0.0.1:11434) |
| OS | Windows 11 |
| Other mods | Xaero's Minimap/World Map (unrelated) |

---

## Issue 1 — Native **Claude/Anthropic** mode: malformed request (HTTP 400)

With `aiplayer.llmMode=claude` and a valid Anthropic key, every bot action call fails:

```
[wolfbot] Error: 400 - {"type":"error","error":{"type":"invalid_request_error",
"message":"messages.0: use the top-level 'system' parameter for the initial system prompt"}, ...}
```

**Root cause:** `net.shasankp000.ServiceLLMClients.AnthropicClient` posts to `https://api.anthropic.com/v1/messages` with the system prompt placed as `messages[0]` (role `system`). The Anthropic Messages API requires the system prompt in the **top-level `system` parameter**, not in the `messages` array. (Verified: the same key + a top-level `system` field returns 200.)

**Fix:** move the system prompt to the top-level `system` field in the Anthropic request body.

---

## Issue 2 — **Custom / OpenAI-compatible** mode: `DecisionResolver` doesn't recognize `custom`

With `aiplayer.llmMode=custom` (custom base URL + key), the main chat client connects, but the decision step fails:

```
[Toast] Invalid LLM Client. Unsupported provider detected. Defaulting to Ollama client
[wolfbot] Reanalyzing…
[wolfbot] ⚠ I'm confused! Please report this.
```

**Root cause:** `net.shasankp000.ChatUtils.DecisionResolver.DecisionResolver` builds its client from a provider switch that handles `ollama / openai / claude / gemini / grok` but **not `custom`**. It falls back to Ollama, which has no chat model loaded → failure. (`LLMClientFactory` *does* handle `custom`, but `DecisionResolver` does not — inconsistent provider coverage between components.)

Also in custom mode the model field can be sent empty:
```
Error: 400 - {"error":{"code":"invalid_request_error","message":"model: Input should be a valid string", ...}}
```

**Fix:** add `custom` handling to `DecisionResolver` (and audit every component that branches on `aiplayer.llmMode`); ensure the selected model is included in custom-mode requests.

---

## Issue 3 — Native **OpenAI** mode: model list returns 0 despite a valid key

With `aiplayer.llmMode=openai` and a funded, valid key, **Refresh Models** repeatedly reports:

```
Models Reloaded — Found 0 models
```

But the same key against `GET https://api.openai.com/v1/models` returns **HTTP 200 with the full model list** (`gpt-4o`, `gpt-4o-mini`, `gpt-3.5-turbo`, …).

**Root cause:** `net.shasankp000.ServiceLLMClients.OpenAIModelFetcher` filters with `id.startsWith("gpt")` but returns 0 against the current API response — likely a parsing/filter mismatch with OpenAI's present `/v1/models` payload. **Workaround that proved the rest of the pipeline:** set `selectedLanguageModel` directly in `settings.json5` (the dropdown is cosmetic; the bot reads this field).

**Fix:** repair the model-list parsing/filtering for the current OpenAI `/v1/models` schema.

---

## Issue 4 — Chat command routing never resolves a bot name (`Mentioned bot name: null`)

Addressing the bot in normal chat **never works**, regardless of the name used:

```
Outgoing message: Steve build a house here
Mentioned bot name: null
```

This happens for short names (`wb`), normal names (`Steve`), with/without the name first, and **persists after a world reload**. The bot is correctly registered in `settings.json5 → botGameProfile`, yet `net.shasankp000.AIPlayerClient.getBotNameIfMentioned` returns null. The class contains the log string **"continuing with no bots registered."**, suggesting the **client-side bot registry is empty** when the matcher runs (server/client sync, or it isn't reading `botGameProfile`).

**Workaround:** `/bot send_message_to <bot> <message>` *does* route to the bot (bypasses this matcher).

**Fix:** populate/sync the client-side bot registry so `getBotNameIfMentioned` can match registered bots; or document that `send_message_to` is the intended command path.

---

## Issue 5 — **Action executor is hard-wired to Ollama** (breaks all cloud providers)

This is the core blocker. Even after routing a command via `send_message_to` and correctly classifying intent, the action layer fails. In **OpenAI** mode:

```
📨 Received intent: REQUEST_ACTION
🧵 Started FunctionCallerV2 worker thread
📝 Standard model 'gpt-4o' - using regular chat
❌ Ollama API error: HTTP 404
Error in Function Caller: Ollama API returned status: 404
✅ Finished FunctionCallerV2 worker thread
```

**Root cause:** `net.shasankp000.FunctionCaller.FunctionCallerV2` uses the **ollama4j `OllamaAPI` against `http://localhost:11434/` unconditionally**, and passes `selectedLanguageModel` ("gpt-4o") as the Ollama model name → Ollama returns 404 (no such model). Consequently **cloud providers (Claude/OpenAI/Gemini/Grok) can chat but can never execute actions** — the tool/function-calling layer only ever talks to Ollama.

**Fix:** route function/tool calling through the same provider abstraction as chat (so cloud models do tool-calling via their own APIs), instead of hard-coding ollama4j.

---

## Issue 6 — Even **native Ollama** mode (the documented config) fails at NLP

Switching to the mod's intended setup (`aiplayer.llmMode=ollama`, `selectedLanguageModel=llama3.2`, Ollama running), `send_message_to` is received and intent processing begins, but commands like `collect dirt` and `come here` return:

```
[Steve] ⚠ NLP issue. Report to developer.
```

So the bot does not execute commands even in the fully-local, documented configuration.

**Ask:** what is the known-good combination (mod version + MC version + model) where `send_message_to … come here` reliably produces movement? If 1.21.1 is a less-tested port, please note which branch is stable.

---

## Reproduction (OpenAI path, but each issue repros on its mode)

1. Fabric 1.21.1 + Fabric API + Carpet + AI-Player 1.0.5.3.
2. Launch with `-Daiplayer.llmMode=openai`; enter a valid funded OpenAI key via `/configMan → API Keys`.
3. `Refresh Models` → **0 models** (Issue 3). Set `selectedLanguageModel="gpt-4o"` in `settings.json5` to proceed.
4. `/bot spawn Steve play` → Steve connects ("Using gpt-4o") and greets.
5. Plain chat `Steve come here` → `Mentioned bot name: null`, no action (Issue 4).
6. `/bot send_message_to Steve come here` → intent `REQUEST_ACTION` classified, then `FunctionCallerV2` → **Ollama 404** (Issue 5). Bot never moves.

## Net effect

Across **every** provider configuration, the bot connects and talks but **cannot perform a single in-world action** on Minecraft 1.21.1. The most impactful fix is **Issue 5** (decouple the action/tool-calling layer from hard-coded Ollama), followed by **Issue 4** (bot-name routing) and the per-provider request bugs (1–3).

*Report compiled from live logs (`.minecraft/logs/latest.log`) and decompiled class inspection of `ai-player-1.0.5.3+1.21.1.jar`.*
