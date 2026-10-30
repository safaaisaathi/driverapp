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

## Agent skills

### Issue tracker

Issues live in the repo's GitHub Issues via the gh CLI. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context: root `GLOSSARY.md` + `docs/adr/`. See `docs/agents/domain.md`.

## Subagent routing

Delegation is a decision, not a default. Route by the work's dominant verb, and keep small work in-house.

### Decision steps

| Step | Question | Action |
|---|---|---|
| 1. Delegate at all | Big independent read, a well-scoped ticket slice, a second opinion, or the user asked for parallel work | Yes: go to step 2. No: do it yourself, a 1-line edit, a rename, or one test fix never leaves the house |
| 2. Break it down | Can this split into slices with disjoint files | Yes: one slice per agent, each with its own acceptance criteria. Shared files: run them in sequence or keep the work in-house |
| 3. Pick the profile | Dominant verb of the slice | See: `scout`, think: `thinker`, code or run: `builder` |
| 4. Parallel or not | 3 or more independent slices, disjoint files, no shared git index | Yes: max 3 concurrent, max 2 per endpoint, spread the models. Otherwise: sequential |
| 5. Model died | Timeout, usage limit, or DNS failure | Never retry the same model twice: next rung of the ladder (nemotron, minimax, glm), same brief, one-line report |

### Profiles

| Profile | Model | Use for | Rights |
|---|---|---|---|
| `scout` | `nvidia/nvidia/nemotron-3.5-super-vl-120b-a12b` | See: images, screenshots, wireframes, PDFs, large file reads | Read only |
| `thinker` | `nvidia/minimaxai/minimax-m3.1-flash#thinking` | Think: architecture, root-cause analysis, design, review | Read only |
| `builder` | `nvidia/z-ai/glm-5.3-flash#thinking` | Code and run: multi-file implementation, tests, builds, greps, mechanical sweeps | Full, but never commits |

Ties: see beats think, think beats code, code beats run. Correct reading beats fast writing.

### Rules

| Rule | Meaning |
|---|---|
| Name the profile and the model when spawning | Never rely on the default model |
| Profile not exposed by the harness | Spawn `general` with that profile's model id |
| Sub-agents never commit | The main agent reviews, verifies, and commits |
| One agent per file set | Two agents in the same files corrupt each other |
| Free models only | No paid tiers (bedrock, paid openrouter) |
| Report the routing in one line | "T7: builder (glm#thinking), 4 files, parallel with T8", then work silently |

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
