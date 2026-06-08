# computer-control

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skill that **routes any screen-driving task to the right engine, then uses it**. It covers web automation, browser control, and native macOS app control — and decides between them rather than defaulting to one.

Two engines and one escape hatch:

| Engine | What it is | Drives | Best for |
|--------|-----------|--------|----------|
| **Claude in Chrome** | Claude drives a real Chrome browser directly via MCP | A Chrome browser (yours, via the extension) | Anything on the web — the default |
| **Codex bridge** *(Codex Computer Use)* | A bridge to [OpenAI Codex](https://github.com/openai/codex) via a wrapper script | `gui`: the whole macOS desktop · `web`: Codex's in-app browser | Native apps; Codex-coupled web QA |
| **AppleScript** (`osascript`) | Scripted Mac automation, no GUI loop | macOS apps that expose scripting | Deterministic, no-visual-judgement tasks |

The routing principle: **Claude in Chrome for the web, the Codex bridge for the desktop.** Delegating to Codex costs a model round-trip, latency, and — for `gui` — the physical screen, so the bar to delegate is that Codex offers something Claude in Chrome cannot: native-app reach, coding-loop integration, or a genuinely independent agent.

## The Codex bridge

Engine B is a bridge to OpenAI Codex. The wrapper at `scripts/codex-cu.sh` drives `codex exec` so Codex takes the task on through its bundled `browser` / `computer-use` plugins. "Codex Computer Use" is not a CLI subcommand — it's the `computer-use@openai-bundled` plugin (a macOS Computer-Using-Agent MCP server). The wrapper exposes:

- `check [--install]` — report which plugins/permissions are ready; install the computer-use plugin
- `gui "task"` — control native macOS apps on the **real** screen (explicit intent only)
- `web "task"` — drive Codex's in-app browser for localhost / dev pages
- `resume` — continue a prior Codex session

> ⚠️ `gui` is not headless. It moves the cursor, types, and screenshots your actual desktop. Run it only on explicit intent, in the background, and remember the on-screen overlay supports Esc-to-cancel.

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and configured
- **For Claude in Chrome**: the Claude for Chrome extension installed and connected in a Chromium browser (Chrome, Dia, Arc, Brave, or Edge — `scripts/browser-detect.sh` finds your primary one)
- **For the Codex bridge**: [OpenAI Codex CLI](https://github.com/openai/codex) installed and signed in; for `gui`, the `computer-use@openai-bundled` plugin installed and macOS **Accessibility + Screen Recording** granted to "Codex Computer Use" (see `references/setup.md`)

## Installation

```bash
git clone https://github.com/justinwilliames/claude-codex-computer-control ~/.claude/skills/computer-control
```

## Usage

The skill triggers automatically when you ask to control the screen, automate or test a web page, fill a form online, drive Chrome, or operate a native app. It picks the engine for you. Examples:

```text
"Fill out the signup form on this site and submit it"      → Claude in Chrome
"QA the checkout flow on localhost:3000"                   → Claude in Chrome (or Codex web)
"Open Keynote and build a title slide"                     → Codex gui
"Toggle dark mode in System Settings"                      → osascript
```

For the Codex bridge directly:

```bash
scripts/codex-cu.sh check
scripts/codex-cu.sh gui "Open Calculator, compute 1234*5678, read me the result"
scripts/codex-cu.sh web "Open localhost:3000, run checkout, screenshot any error" --dir /project
```

## Files

- `SKILL.md` — routing rules and engine usage (the intelligence)
- `scripts/codex-cu.sh` — the Codex-engine wrapper
- `scripts/browser-detect.sh` — finds the primary / running Chromium browser for Claude in Chrome
- `references/setup.md` — Codex plugin install, macOS permissions, the verified CLI gotchas

## License

MIT — see [LICENSE](LICENSE).
