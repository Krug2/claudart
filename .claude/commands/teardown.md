---
description: Close session and update knowledge — claudart
---

You are running **SESSION TEARDOWN**.

> Preferred: use the Dart CLI — `claudart teardown`
> Only use this slash command if you want to drive teardown interactively.

---

## Step 1 — Confirm resolution

Ask: "Is the bug confirmed resolved?"

When you present something for the user to confirm before proceeding, after they reply, classify their reply into exactly one of: confirm, modify, clarify, reject. Emit it as <CONFIRMATION>one of: confirm, modify, clarify, reject</CONFIRMATION> before taking the corresponding action. Do not guess — if the reply does not clearly confirm, request a change, or reject, emit `clarify` and ask a follow-up question instead of acting.

- `confirm` → proceed to Step 2.
- `modify` or `reject` → "Come back when resolved. Use `/debug` or `/suggest` to continue." Do not proceed.
- `clarify` → ask a follow-up question. Do not proceed.

---

## Step 2 — Read session files

Read both:
- `/Users/aksana.buster/dev/dev_tools/claude/claudart/handoff.md`
- `/Users/aksana.buster/dev/dev_tools/claude/claudart/skills.md`

---

## Step 3 — Classify learnings

For each learning from this session, decide:
- **Generic** → applies to any Dart/Flutter project → update `/Users/aksana.buster/dev/dev_tools/claude/claudart/knowledge/generic/`
- **Project-specific** → update `/Users/aksana.buster/dev/dev_tools/claude/claudart/knowledge/projects/<project>.md`

Write only patterns — no session-specific narrative.

---

## Step 4 — Update knowledge files

Generic learnings go to the appropriate file in `/Users/aksana.buster/dev/dev_tools/claude/claudart/knowledge/generic/`.
Project learnings go to `/Users/aksana.buster/dev/dev_tools/claude/claudart/knowledge/projects/<project>.md`.

---

## Step 5 — Archive and reset

- Archive handoff to `/Users/aksana.buster/dev/dev_tools/claude/claudart/archive/`
- Reset `/Users/aksana.buster/dev/dev_tools/claude/claudart/handoff.md` to blank template
- Update `/Users/aksana.buster/dev/dev_tools/claude/claudart/skills.md` session index

---

## Rules

- Never push to remote
- Generic patterns only in knowledge/ — no session noise
- Do not delete the archive

$ARGUMENTS
