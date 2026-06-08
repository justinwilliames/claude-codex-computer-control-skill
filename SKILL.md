---
name: computer-control
description: Route any screen-driving task to the right engine, and use it — Claude in Chrome OR a built-in bridge to OpenAI Codex. Covers web automation, browser control, and native macOS app control. The default web engine is Claude in Chrome (Claude drives a real Chrome browser directly). The skill ALSO bridges to Codex (Codex Computer Use) via a wrapper script, delegating native-Mac-app control and Codex's in-app browser to Codex. Trigger when the user wants to control the computer/screen, automate or test a web page, fill a form online, click through or scrape a site, drive Chrome, operate a native app (Keynote, Xcode, Finder, Music, Mail), "use my computer", "bridge to Codex", or have Codex drive the screen. This skill decides which tool is right — it does not default to one engine.
---

# Computer Control

> Paths below use `{base}` as shorthand for this skill's base directory, provided automatically at the top of the prompt when the skill loads.

The single entry point for **driving a screen** — a web page, a browser, or a native macOS app. Its one job is to **pick the right engine for the task and use it**, never to reach for a favourite. Two engines — Claude's own browser control, and a **bridge to OpenAI Codex** — plus one escape hatch:

| Engine | What it is | Drives | Best for |
|--------|-----------|--------|----------|
| **Claude in Chrome** | *You* drive a real Chromium browser directly via the `Claude in Chrome` MCP tools | Chrome, Dia, Arc, Brave or Edge (via the extension) | Anything on the web — the default |
| **Codex bridge** *(Codex Computer Use)* | A **bridge to OpenAI Codex** — delegates via the `{base}/scripts/codex-cu.sh` wrapper | `gui`: the whole macOS desktop · `web`: Codex's in-app browser | Native apps; Codex-coupled web QA |
| **AppleScript** (`osascript`) | Scripted Mac automation, no GUI loop | macOS apps that expose scripting | Deterministic, no-visual-judgement tasks |

## Route first — the decision

Walk this top to bottom and **stop at the first match**:

1. **Scriptable with no visual judgement?** (toggle a setting, open an app, read a value AppleScript exposes, a one-liner) → **`osascript`** via the `Control your Mac` tool. Cheapest and most reliable. Don't drive a GUI for what a script does deterministically.

2. **A native macOS app — not a browser?** (Keynote, Xcode, Finder, Music, Mail.app, Preview, a menu-bar app, a copy-between-apps flow) → **Codex `gui`**. It is the *only* engine that can touch non-browser apps. It seizes the real screen → **explicit user intent only**, run in background, Esc cancels.

3. **A web / browser task?** → **Claude in Chrome** by default. You drive Chrome directly: navigate, read the rendered DOM, fill forms, click, inspect network/console, manage tabs — lower latency, full control, you stay in the reasoning loop and can interleave it with the rest of the work.
   Route to **Codex `web`** *instead* only when one of these holds:
   - it's local-dev QA you're verifying immediately after **Codex** changed that frontend in a coding session, or
   - you deliberately want Codex's **independent** eyes on a web flow (adversarial / second opinion), or
   - Claude in Chrome has **no connected browser** and one can't be connected right now.

4. **Trivial, and you already have the tool to hand?** → just do it in Claude in Chrome. Don't delegate a one-liner to a second model.

**The default bias:** Claude in Chrome for the web, Codex `gui` for the desktop. Delegating to Codex costs a model round-trip, latency, and — for `gui` — the physical screen. So delegate only when Codex offers something Claude in Chrome cannot: **native-app reach, coding-loop integration, or a genuinely independent agent.** When both engines could do it, pick Claude in Chrome.

| Task | Engine |
|------|--------|
| Fill a form, scrape, or click through a website | Claude in Chrome |
| Read a rendered page; inspect its network/console | Claude in Chrome |
| Drive an authenticated web session in the user's Chrome | Claude in Chrome |
| QA a localhost page after a frontend change | Claude in Chrome — *or* Codex `web` if Codex made the change |
| Operate Keynote / Xcode / Finder / any `.app` | Codex `gui` |
| Multi-app desktop flow (copy from app A into app B) | Codex `gui` |
| Open an app, toggle a macOS setting, read a scriptable value | `osascript` |
| Independent second agent on a UI flow, in parallel | Codex |

---

## Engine A — Claude in Chrome (default for web)

You drive the browser yourself through the `Claude in Chrome` MCP tools — no script, no delegation. The extension works in **any Chromium browser** (Chrome, Dia, Arc, Brave, Edge), so never assume it's Chrome. Tools: `navigate`, `find`, `read_page`, `get_page_text`, `form_input`, `computer` (click / type / scroll / screenshot), `tabs_create_mcp` / `tabs_close_mcp` / `tabs_context_mcp`, `javascript_tool`, `read_console_messages`, `read_network_requests`, `file_upload`, `browser_batch`.

**Check availability — primary browser + existing instances, and retry before giving up.** Never fold on a single empty result:

1. **Existing instances first** — `list_connected_browsers`.
   - Non-empty → `select_browser` (prefer one on this computer; if several, the system default — `browser-detect.sh` flags which). Then act.
2. **Empty on the first try → do NOT stop:**
   - a. `{base}/scripts/browser-detect.sh` — shows which Chromium browsers are installed, **running**, and the system **default** (the extension may live in Dia / Arc / Brave / Edge, not Chrome).
   - b. Bring the primary frontmost — `{base}/scripts/browser-detect.sh ensure` (the default Chromium), or `ensure "Dia"` for a specific running browser the extension may be in.
   - c. **Re-run `list_connected_browsers`, retrying up to ~3 times** — the extension can take a moment to register after its browser is focused or launched.
3. **Still empty after retries** → only now ask the user to click the **Claude for Chrome** extension in the relevant browser and **Connect** it to this session (and confirm it's signed into this session's account), or fall back to Codex `web`.

Then act directly. Prefer `read_page` / `get_page_text` for reading, `form_input` or `computer` for acting, `browser_batch` to chain steps efficiently. **Permission rules still apply**: don't submit forms, accept terms/consent, grant OAuth, or click irreversible controls (send / publish / delete / purchase) without Sir's explicit go-ahead.

---

## Engine B — the Codex bridge (Codex Computer Use)

This engine is a **bridge to OpenAI Codex**: the `{base}/scripts/codex-cu.sh` wrapper drives `codex exec` so Codex takes the task on. Codex brings a separate reasoning manifold and — through its `browser` / `computer-use` plugins — reaches the whole macOS desktop, which Claude in Chrome cannot.

```bash
# Readiness / one-time install (gui only)
{base}/scripts/codex-cu.sh check
{base}/scripts/codex-cu.sh check --install

# Native desktop control — REAL screen, explicit intent only, run in background
{base}/scripts/codex-cu.sh gui "Open Keynote, new blank deck, add a title slide reading 'Q3 Review'"
{base}/scripts/codex-cu.sh gui "task" --dir /project --image ref.png --dry-run

# Codex's in-app browser — local/dev pages, esp. right after Codex changed the code
{base}/scripts/codex-cu.sh web "Open localhost:3000, run checkout, screenshot any error" --dir /project

# Resume a prior Codex session
{base}/scripts/codex-cu.sh resume --last "Now export it as PDF"
```

**Flags (gui/web/resume):** `--dir`, `--model`, `--effort`, `--image`, `--dry-run`. `--dry-run` prints the exact `codex exec` command without running it — use it to preview a `gui` run before it touches the screen.

### ⚠️ `gui` controls the real screen
Not headless — it moves the cursor, types, and screenshots **Sir's actual desktop** (a "Codex is using your computer / Esc to cancel" overlay shows). Therefore: only on explicit intent, never speculatively; always `run_in_background=True` so Sir keeps control; prefer Claude in Chrome or Codex `web` for anything that's just a web page.

### One-time setup for `gui`
`computer_use` being on as a *feature flag* is not enough — the **plugin** must be installed. Run `{base}/scripts/codex-cu.sh check`; if `computer-use` shows `not-installed`, run `check --install`, then grant **Accessibility + Screen Recording** to "Codex Computer Use" and clear first-run consent in one interactive `codex` session. Full detail and gotchas in `references/setup.md`.

### Invoking Codex
1. **Always background it** (`run_in_background=True`), then collect with `TaskOutput(task_id=..., block=True, timeout=600000)` — GUI loops are slow.
2. Hand Codex the intent plainly; it sees the screen and works out the steps.
3. **Watch for sentinels** — a result of exactly `COMPUTER_USE_UNAVAILABLE` / `BROWSER_UNAVAILABLE` means the tool wasn't live → run `check`, finish setup, retry. Don't paper over it.

```python
Bash(command='{base}/scripts/codex-cu.sh gui "Open Calculator, compute 1234*5678, read me the result"',
     run_in_background=True)        # → task_id
TaskOutput(task_id="...", block=True, timeout=600000)
# → SESSION: <uuid>\n---\n<final message>
```

---

## Self-healing

If anything breaks, fix the skill files directly — you may edit anything under `{base}/`:
- `SKILL.md` — this file (routing rules + engine usage)
- `scripts/codex-cu.sh` — the Codex-engine wrapper
- `references/setup.md` — Codex plugin install, macOS permissions, troubleshooting

Verify any Codex CLI change against the installed binary before trusting it — Codex's own advice on its flags has been wrong (`codex exec` rejects `-a`; the correct control is `-c approval_policy="never"`). For the Claude-in-Chrome side, confirm a browser is connected with `list_connected_browsers` before assuming the engine is available.
