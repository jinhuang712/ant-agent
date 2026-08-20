# Dispatch templates

Fill and pass as the `message` argument of `spawn_agent`. The `model` tier goes in the
call, not in the message.

The proposition content follows whatever language the user is working in; the scaffold
stays English.

## ant-locate — gpt-5.4

```
Proposition: <describe the thing itself, not the symbol name you guess it has>
Scope: <absolute path / dataset>
Leads: <entry URL, error string, UI text, related symbol — whatever you have>
Return: location list, each as `<relative path>:<line> — <symbol> — <one-line role>`;
        mark which one is the main implementation
Unplanned: report anything I didn't ask for but should know
```

## ant-verify — gpt-5.4-mini

```
Proposition: <state the answer shape inside the proposition itself>
Scope: <absolute path / dir / file / table — required>
Return: verdict + pin + verbatim excerpt
Unplanned: report anything I didn't ask for but should know
```

Collapse to a bare verdict when you don't intend to check it yourself:

```
Return: one line only — yes or no
```

Fanning out: one proposition per ant. Never pack a batch into one.

## ant-trace — gpt-5.4

```
Proposition: <how did X get from one end to the other / why did Y happen>
Scope: <absolute repo path; environment id if runtime is involved>
Window: <time window — required when logs or metrics are in play>
Leads: <entry symbol, request id, error string>
Return: one-line chain + per-hop pins + dead ends I should not re-walk
Unplanned: report anything I didn't ask for but should know
```

Collapse to the chain alone:

```
Return: just the chain, file → file → file
```

## ant-sift — gpt-5.4

```
Proposition: <the filter criterion — what counts as useful to me>
Scope: <absolute path / dataset — required>
Samples: <how many representative excerpts; default 3>
Return: findings list, each with a pin; end with a pin that recovers all hits
Unplanned: report anything I didn't ask for but should know
```

## ant-census — gpt-5.4

Check first: can the criterion be written as one command? Then run it yourself.

```
Proposition: <what to count>
Scope: <absolute path / dataset / time window — required>
Criterion: <if given, use it; if not, define one and state it back>
Group by: <dimension, when a table is wanted; omit for a single total>
Return: criterion + numbers + the exact reproducible command + borderline cases
Unplanned: report anything I didn't ask for but should know
```

## ant-adjust — gpt-5.4-mini, or gpt-5.4 for edits

The `Authorised:` line is deny-by-default. Omit it and the ant stays read-only.

Batch transform:

```
Task: <spec, verbatim; one worked example helps>
Items:
  <id-1> <payload>
  <id-2> <payload>
Authorised: nothing — pure transformation, no side effects
Return: `<item-id> -> <result>`, original ids, original order, no item omitted
Unplanned: report anything I didn't ask for but should know
```

Run a command:

```
Task: run <full command>
Cwd: <absolute path>
Authorised: executing that one command
Success: <what counts as pass; default is exit code 0>
Return: verdict + the failing lines only — do not paste passing cases
Unplanned: report anything I didn't ask for but should know
```

Edit files — propose first:

```
Task: <change spec, verbatim>
Items: <file list>
Authorised: PROPOSE ONLY — do not write anything to disk
Return: change list, each as `<file>:<line> — <old> → <new>`
Unplanned: report anything I didn't ask for but should know
```

Review the list, then dispatch again with `Authorised: writing the approved changes to
disk`.

## ant-pardon — gpt-5.4-mini

Three admission tests first: determined, hard to get wrong, checkable afterwards.

```
Task:
  1. <step — must be statable as "done looks like this">
  2. <step>
Authorised: <exact write scope; anything not listed is out of bounds>
On surprise: stop and report — do not decide for me
Return: verdict + a pin per step + irreversible actions listed separately
Unplanned: report anything I didn't ask for but should know
```

Ask before sending: **if this goes wrong and I only find out hours later, can it be
undone?** If not, don't send it here.

## ant-monitor — gpt-5.4-mini

```
Watch: <how to check state — command / endpoint / tool call>
Done when: <what counts as finished, and what counts as failed — required>
Interval: <poll interval; default 30s>
Budget: <max wait — required>
Notify: <whether to push when finished>
Return: verdict + elapsed + the scene at that moment + a clickable link
Unplanned: report anything I didn't ask for but should know
```

## Collapse cheatsheet

| You want | Write on the `Return:` line |
|---|---|
| a bare verdict | `one line only — yes or no` |
| a bare chain | `just the chain, file → file → file` |
| positions without explanation | `paths and line numbers only, no role descriptions` |
| the number alone | `the number and the criterion, no samples` |
| something you'll verify | `every claim needs a pin` |
| something you won't | `no pins needed` |

The last one has a cost: **no pin means giving up verification.**

`Unplanned:` is not in this table because it does not participate in collapsing. However
tight the `Return:` line, that one stays.
