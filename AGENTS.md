# AGENTS.md

## Communication rules

Apply these to every response: code, explanation, and discussion.

### Base rules

| Rule | Meaning |
|---|---|
| No over-explain | Get to the point. Skip extra background. |
| Simple words | Use easy words. Avoid heavy jargon. |
| Hinglish in chat | Chat replies use a Hindi + English mix. |
| English in the repo | Every file in the repo stays in English. |
| No long paragraphs | Break the answer into short pieces. |
| Points and tables | Use bullets or tables. |
| Proper spacing | Leave space between lines. Do not pack text together. |
| Crisp | Say only what is needed. |
| No em-dashes | Do not use an em-dash. Use a comma or a period. |

### First-read rules

The user reads fast and does not want to decode. Write so the answer is clear on the first read.

| Rule | Meaning |
|---|---|
| Answer first | The first line is the answer or the decision needed. |
| Problem in one line | Say what is wrong in plain words, no jargon. |
| Plan in 3 or 4 steps | One short line per step. Each step says what it does and why. |
| Say what changes | For every step say: does it only read, or does it change data. |
| Explain a term once | If a term is needed (index, duplicate, breaker), give its plain meaning in the same line. |
| One decision at a time | Ask one clear question. Do not stack options. |
| No command dumps | Do not hand over a list of commands without saying what each one does. |
| Confused user | If the user says they do not understand, restart from the problem in plain words. Do not add more detail. |
| Say who acts | Mark each step as "I do" or "you do". |

## Repo write scope

Write code only in this repo. Every other repo, platform, userapp, adminpanel, and any other, is read only.

The platform repo is remote only. Treat it as if it does not exist on this machine. Do not read, cd into, run tools from, or edit its local checkout. Read platform files, issues, and pull requests with the `gh` CLI.

When a change is needed outside this repo, create a GitHub issue with four parts: the problem, the proposed change, the acceptance cases, and the files. Do not edit, commit, or push in those repos.

The global rule lives in `~/.config/opencode/AGENTS.md`. The only override is an explicit instruction from the user in the current conversation. A past approval never carries over.

See `GLOSSARY.md` standing protocol item 8.

## Agent skills

### Issue tracker

Issues live in the repo's GitHub Issues via the gh CLI. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context: root `GLOSSARY.md` + `docs/adr/`. See `docs/agents/domain.md`.

## Subagent routing

Read `docs/agents/subagent-routing.md` before delegating work. Small work stays in-house.

## Verification ladder

Run this ladder after every delegated slice, before the commit. Mechanical checks first, model review only by risk, re-run only for infra failures.

### Tiers

| Tier | What | When | Cost |
|---|---|---|---|
| 1. Mechanical | Diff scope (only the assigned files changed), the focused test run, the analyzer, and the agent's claimed counts against the actual output | After every delegated slice | Free, seconds |
| 2. Adversarial review | The `thinker` profile reads the diff against the ticket's acceptance criteria | Risky slices only: contract change, deletion, security, money | One extra call |
| 3. Re-run | The same brief plus the failure note | Infra death or an unfinished slice only | One agent call |

### Re-run rules

| Situation | Action |
|---|---|
| The agent died (timeout, usage limit, DNS) | Re-run with the same brief and the failure note |
| The slice is half done | Re-run with the same brief and the exact remaining work |
| The design is wrong | Do not re-run. Fix it in-house, the brief was the problem |
| A test fails | Read why first. My change: fix it. The agent's change: re-run with that error |
| The second attempt also fails | Stop. Take it over in-house. No third attempt, no duplicate edits |

### Brief checklist

Every spawn brief carries these lines, so the agent self-checks and the mechanical tier has less to catch:

| Line | Why |
|---|---|
| Run the named tests and report the exact counts | A report without numbers is a guess |
| List every file touched | Scope drift shows up here |
| State what was not finished | Partial work must not hide behind a green summary |
| Do not commit or stage | The main agent owns the git index |

## Watching CI

Watch a run with `gh run watch <id> --exit-status`. Do not sleep-poll.

Merge with `gh pr merge <n> --auto --merge` when the PR is ready, so the merge waits for the required checks. Auto-merge is enabled on both repos.
