# Shuddup&Work

A native macOS app that automatically sends "continue" messages to AI agents running in Terminal.app — because Grok kept stopping mid-task and waiting for a nudge.

Born out of frustration: you're running an AI agent in your terminal, it finishes a step, and just... stops. Waiting for you to say "keep going." Over and over. Shuddup&Work does it for you.

## What it does

- Types random human-sounding prompts ("Keep going.", "Continue.", "Yep.", "What's next?") directly into a target Terminal window
- Types letter-by-letter with randomized timing so it looks like a real person
- Configurable interval with +/-25% jitter so it doesn't feel robotic
- 35 built-in prompts, fully customizable

## Features

- **Countdown ring** — visual progress ring with pulsing glow
- **3 sizes** — Full, Compact, Mini (cycle with `[ ]` button)
- **Magnetic docking** — drag to screen edge, it snaps
- **Always-on-top** — stays floating above your work (toggle with `pin`)
- **Editable messages** — click `...` to customize prompts in a text file
- **History log** — see what was sent and when
- **About screen** — click the Profuctions logo

## Requirements

- macOS 12+
- Terminal.app (for targeting agent windows)
- Accessibility permission (for letter-by-letter typing; falls back to full-line injection without it)

## Build

```bash
swiftc -o Shuddup main.swift -framework Cocoa -framework QuartzCore
```

Or use the pre-built `.app` bundle.

## Install

1. Build or download `ContinueAt.app`
2. Move to `/Applications` or keep in `~/Coding/`
3. Double-click to launch
4. First run: macOS may ask for Accessibility access — grant it for the typing effect
5. Select your interval, pick the Terminal window with your agent, hit Start

## Custom Messages

Click the `...` button or edit `~/.continue-at-prompts.txt` directly. One message per line, lines starting with `#` are ignored.

## Why "Shuddup&Work"

Because that's what you're telling the AI. Shut up and keep working. Stop waiting for permission. You had instructions. Follow them.

---

**Shuddup&Work 1.8** | RWR.2026 | [Profuctions.com](https://profuctions.com)
