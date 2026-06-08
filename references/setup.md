# Codex Computer Use — setup & mechanism

Setup detail for **Engine B** of the `computer-control` skill. For *which* engine to use on a given
task, see `SKILL.md` (routing). For Engine A (Claude in Chrome), see the short note at the end.

Verified against `codex-cli 0.133.0` on macOS (Darwin), 2026-06-08.

## What "Codex Computer Use" actually is

There is **no** `codex computer-use` subcommand. On this machine the real GUI-control surface is a
bundled **plugin** whose embedded MCP server runs the Sky CUA client:

```
computer-use@openai-bundled
  └─ MCP server: "Codex Computer Use.app/.../SkyComputerUseClient" mcp
     (bundle id com.openai.sky.CUAService — "Sky"/CUA = Computer-Using Agent)
```

Three related, distinct plugins exist in the `openai-bundled` marketplace:

| Plugin | Controls | Default state here |
|--------|----------|--------------------|
| `browser@openai-bundled` | Codex's **in-app browser** (localhost / file:// / dev pages) | installed, enabled |
| `chrome@openai-bundled` | The user's **real Chrome** profile (needs the Codex Chrome extension) | not installed (optional) |
| `computer-use@openai-bundled` | **Any macOS app** — full desktop control | not installed |

The standalone `Codex Computer Use.app` already lives at `~/.codex/computer-use/` and is wired into
`~/.codex/config.toml` as a `notify` turn-ended hook — but **that is not the activation switch.**
Activation = installing the plugin.

Likewise `codex features list` shows `computer_use`, `browser_use`, `in_app_browser` as `stable true`.
**The feature flag is not the switch either** — the plugin must be installed.

## One-time setup for `gui` (full desktop control)

1. **Install the plugin** (triggers an `ON_INSTALL` consent flow — may open a dialog):
   ```bash
   /Applications/Codex.app/Contents/Resources/codex plugin add computer-use@openai-bundled
   # or: scripts/codex-cu.sh check --install
   ```
2. **Grant macOS permissions** to "Codex Computer Use" — System Settings → Privacy & Security:
   - **Accessibility** (control mouse/keyboard)
   - **Screen Recording** (see the screen)
3. **Clear first-run consent interactively.** Run one interactive `codex` session and let it perform a
   trivial computer-use action so any first-run approval is handled by a human. Background `codex exec`
   cannot answer OS permission prompts, so the first real use must be attended.

After that, background `gui` runs via `codex exec` are reliable.

## Optional: real Chrome profile (`chrome` plugin)

Not wired into this skill's modes (the bundled `browser` covers local dev). If a task needs the user's
authenticated Chrome session/profile:
```bash
/Applications/Codex.app/Contents/Resources/codex plugin add chrome@openai-bundled
```
Then connect the Codex Chrome extension. Add a `chrome` mode to `codex-cu.sh` mirroring `web` if this
becomes a recurring need (feature `browser_use_external`, prompt steered to the real browser).

## Invocation contract (how the wrapper drives Codex)

Non-interactive, via `codex exec` — same family as the sibling `codex` skill:

```bash
codex exec --skip-git-repo-check \
  [-C DIR] [-m MODEL] [-c 'model_reasoning_effort="LEVEL"'] \
  --enable computer_use \              # or browser_use for web mode
  -s danger-full-access \             # web mode: workspace-write
  -c 'approval_policy="never"' \      # NOT -a never — exec rejects -a (see gotcha)
  [-i IMAGE ...] \
  -o OUTPUT_FILE \
  "PROMPT"
```

- **Result**: final assistant message → `-o OUTPUT_FILE`; progress + `session id:` → stderr.
  The wrapper emits `SESSION: <id>\n---\n<final message>`.
- **Sentinels**: the prompt instructs Codex to reply exactly `COMPUTER_USE_UNAVAILABLE` /
  `BROWSER_UNAVAILABLE` if the tool isn't live, so the wrapper degrades loudly instead of silently
  improvising shell commands.
- `--json` is available for a JSONL event stream but is **not** the primary parser — there is no stable
  documented machine contract for computer-use action events. The `-o` final message is the contract.

## Auth & dependencies

- Auth: `~/.codex/auth.json` (`codex doctor` → `stored auth mode: chatgpt`). **No `OPENAI_API_KEY`
  required** for the local plugin path — that's only for hitting the OpenAI API directly.
- No separate Playwright install is needed for the local Codex path.
- `app-server` / `remote-control` are **not** required and **not** used here — `remote_control` is marked
  `removed` in the feature table and exposes no stable task/result contract. Stick to `codex exec`.

## Gotchas (hard-won)

- **`codex exec` rejects `-a` / `--ask-for-approval`** → `error: unexpected argument '-a' found`. Use
  `-c 'approval_policy="never"'`. (Verified — an earlier model-suggested command used `-a never` and
  would have failed on every run.)
- **Feature flag ≠ installed plugin.** `computer_use=true` with the plugin uninstalled does nothing.
- **Headless from Claude, not from macOS.** This uses the live desktop session, not a virtual display.
  A locked screen / no GUI session = no computer use.
- **First-run approvals break unattended runs.** Plugin install + OS permission grants need one attended
  pass before background use.
- **Sandbox vs computer-use permissions are separate layers.** `-s danger-full-access` governs Codex's
  shell/file actions; the CUA app's macOS permissions govern screen control. Both matter.

## Quick verification commands

```bash
/Applications/Codex.app/Contents/Resources/codex --version
/Applications/Codex.app/Contents/Resources/codex plugin list      # install/enabled status
/Applications/Codex.app/Contents/Resources/codex features list    # stable/under-dev flags
/Applications/Codex.app/Contents/Resources/codex doctor           # auth + runtime health
scripts/codex-cu.sh check                                         # one-shot readiness summary
```

## Official references

- Codex Computer Use: https://developers.openai.com/codex/app/computer-use
- Codex Chrome extension: https://developers.openai.com/codex/app/chrome-extension
- Codex CLI reference: https://developers.openai.com/codex/cli/reference
- OpenAI API computer tool: https://developers.openai.com/api/docs/guides/tools-computer-use

---

## Engine A — Claude in Chrome (the default web engine)

No Codex involved: Claude drives a real Chrome browser directly through the `Claude in Chrome` MCP
tools. This is the first choice for any web task — it's lower-latency, keeps Claude in the reasoning
loop, and can read the DOM / network / console directly.

**Requirements**
- The **Claude for Chrome extension** installed and signed in to the same account as this session, in a
  running Chromium browser — **Chrome, Dia, Arc, Brave, or Edge** (it is *not* Chrome-only).
- That browser **connected and selected** for the session.

**Availability check — primary browser + existing instances, actively pair before giving up**
```
scripts/browser-detect.sh                        # installed / running / default Chromium browsers
mcp__Claude_in_Chrome__list_connected_browsers   # shows ALREADY-paired browsers; [] = none yet
scripts/browser-detect.sh ensure                 # focus/launch the primary  (or: ensure "Dia")
mcp__Claude_in_Chrome__switch_browser            # ACTIVE: broadcast a pairing request, wait ~2m for Connect
mcp__Claude_in_Chrome__select_browser            # pick a deviceId once one appears
```
Never fold on the first empty result. `list_connected_browsers` only lists browsers that have *already*
paired — to solicit a new connection you must call **`switch_browser`**, which broadcasts to every browser
with the extension and waits ~2 min for the user to click **Connect**. Sequence: `browser-detect.sh` →
`ensure` the primary is frontmost → `switch_browser` (tell the user to click Connect, in the same turn) →
`list_connected_browsers` → `select_browser`. If `switch_browser` returns **"No other browsers available
to switch to"**, no extension instance is reachable: installed/enabled/signed-in is not enough — the
extension's browser-control connection must be live. Ask the user to open the extension and start/enable
it (the service worker can be asleep), then retry. Or fall back to Codex `web`.

> Diagnosed 2026-06-08: extension `fcoeoabgfenejglbffodgkkbkcdhcgfn` (name "Claude", v1.0.75) is installed
> and not disabled in BOTH Dia and Chrome, Dia is the default browser and was running/focused, and the
> account matched — yet `switch_browser` returned "No other browsers available" and `list_connected_browsers`
> stayed `[]`. So the gate is the live extension connection, not install / enable / account / browser-detection.

**Capabilities**: navigate, find, read_page / get_page_text, form_input, `computer` (click/type/scroll/
screenshot), tabs create/close/context, javascript_tool, read_console_messages, read_network_requests,
file_upload, browser_batch. Permission rules still apply — no submitting forms, accepting consent,
granting OAuth, or clicking irreversible controls without the user's explicit go-ahead.

**Use Codex instead when**: the target is a native macOS app (Codex `gui`), the web QA is tightly
coupled to a frontend change Codex just made (Codex `web`), or you want an independent second agent.
