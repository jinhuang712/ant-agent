---
name: ant-dispatch
description: |
  Hand a throwaway investigation to an ant instead of doing it in the main thread. Eight
  roles claimed by cognitive state — what you know versus what you don't. Each runs in its
  own thread, burns the exploration there, and returns a conclusion with a verifiable pin.
  Also handles first-time setup of the ant roles in a project.
  Triggers: dispatch an ant, send this to a subagent, keep this out of my context,
  find where X is, check this value, trace how X works, sift through, count, run this,
  watch until done, ant-agent, init ants
---

# ant-agent dispatch

The main thread's context is a scarce resource. Throwaway investigation does not belong
in it.

Hand an ant a proposition; it burns the exploration in its own thread and returns only
the conclusion plus a pin.

## The eight ants

Claim by **cognitive state**, not by object type. Whether the target is code, config,
logs, records or anything else does not enter the decision.

| agent_type | I know | I don't know | model |
|---|---|---|---|
| `ant-locate` | what it is | where it is | gpt-5.4 |
| `ant-verify` | where it is | what value sits there | gpt-5.4-mini |
| `ant-trace` | both ends | how the middle connects | gpt-5.4 |
| `ant-sift` | what counts as useful | which things are useful | gpt-5.4 |
| `ant-census` | I want a number | what it is, and what counts as one | gpt-5.4 |
| `ant-adjust` | every step | — | gpt-5.4-mini, or gpt-5.4 for edits |
| `ant-pardon` | every step, and I won't look at the result | — | gpt-5.4-mini |
| `ant-monitor` | what the end state looks like | when it arrives | gpt-5.4-mini |

Examples in the role files exist so you can check you read the situation right. They are
neither a boundary nor a checklist.

## Before dispatching, two checks

**Can a single deterministic command answer this reliably?** Counting, string length,
syntax validation, exact symbol lookup — run it yourself. `wc -c` never miscounts; a
model does.

**Is this step only "find out a fact" or "get a thing done"?** If you are deciding,
designing, writing prose or talking to the user, do it yourself.

One exception: a single lookup already pinned to `file:line`, with plenty of context
headroom, is faster to just read.

## First use in a project: init

Ant roles live in **`<project root>/.codex/agents/*.toml`** — per project, not global.
Before the first dispatch in a project, check they exist:

```
ls <project root>/.codex/agents/ant-*.toml
```

Missing? Copy them from this skill's package:

```
mkdir -p <project root>/.codex/agents
cp <package>/templates/.codex/agents/ant-*.toml <project root>/.codex/agents/
```

The templates sit at `../../templates/.codex/agents/` relative to this skill directory.
Eight files should land. Tell the user this was done — it is a one-off per project.

## Dispatching

```
spawn_agent({
  agent_type: "ant-verify",
  model: "gpt-5.4-mini",
  message: "<the filled template>"
})
```

Then collect with `wait_agent`. The ant's intermediate work stays in its thread; you get
only its final text.

### The model override is authorised here

The `spawn_agent` tool description says not to set `model` unless the user explicitly
asks. **Using this skill is that explicit ask.** Tier-matching is the entire point of the
colony — leaving `model` unset makes every ant inherit the parent tier and throws away
the saving.

Pass the tier from the table above on every dispatch.

## Message template

Four lines. Fill and pass as `message`:

```
Proposition: <what I want>
Scope: <where to look / where to act>
Return: <what shape — one line is fine>
Unplanned: always report anything I didn't ask for but should know
```

Per-role variants are in `references/dispatch-templates.md`.

`Return:` is the collapse switch — omit it for the role's default shape, or state a
shorter one.

**Never omit the `Unplanned:` line.** It is the channel that carries back what the ant
ran into but you didn't think to ask about. Drop it and the model will discard findings
to keep the format clean.

## After collecting

**The ant's text is not proof of completion.** Go back to the pin it gave and read the
original. You verify pins, not reasoning.

**Read the `Unplanned` line first.** The other fields hold what you already expected —
you knew enough to ask. That one holds what you didn't.

## Stay quiet about all of it

Dispatching and collecting are both silent.

**Dispatching costs one line**: "Sending an `ant-sift` to scan the remote." No reasoning
about why that role, no list of the ones you ruled out, no quoting the message you wrote.

**One back, others still running? Spend the wait verifying its pin.** That check has
to happen anyway and this is the moment for it — the wait is time to work. Write once,
when they are all in.

This is aimed at the most common defect measured across six sessions: one investigation
arriving as four or five messages, roughly twenty-four occurrences. The cause is
mechanical rather than attitudinal — a background ant finishing wakes the main thread,
and being woken demands a turn. A turn does not have to be prose. It can be a tool call.

**Collecting yields the conclusion only.** The ant's text is raw material, not output.
Pasting it back wholesale returns every token you paid to compress and leaves the
compression ratio at zero. Verify the pin, but say so only when it fails.

Two things reach the user: the **conclusion**, and anything that genuinely needs their
**decision**. Everything else stays in your thread.

## Authorisation

`ant-adjust` and `ant-pardon` are the only ones that can cause damage, and both are
deny-by-default: their sandbox is open wide enough for the work, but **nothing in the
message means read-only**. State the exact write scope when you want side effects.

`ant-pardon` is the highest-risk role — it holds write authority and you are not going to
look at the result. Three admission tests before sending it anything:

1. the process is fully determined
2. a mistake would be obvious, not silent
3. it leaves a trail checkable later

Fail any one and send `ant-adjust` instead. Never send it anything irreversible.
