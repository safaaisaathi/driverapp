# Subagent routing

Delegation is a decision, not a default. Route by the work's dominant verb, and keep small work in-house.

## Decision steps

| Step | Question | Action |
|---|---|---|
| 1. Delegate at all | Big independent read, a well-scoped ticket slice, a second opinion, or the user asked for parallel work | Yes: go to step 2. No: do it yourself, a 1-line edit, a rename, or one test fix never leaves the house |
| 2. Break it down | Can this split into slices with disjoint files | Yes: one slice per agent, each with its own acceptance criteria. Shared files: run them in sequence or keep the work in-house |
| 3. Pick the profile | Dominant verb of the slice | See: `scout`, think: `thinker`, code or run: `builder` |
| 4. Parallel or not | 3 or more independent slices, disjoint files, no shared git index | Yes: max 3 concurrent, max 2 per endpoint, spread the models. Otherwise: sequential |
| 5. Model died | Timeout, usage limit, or DNS failure | Never retry the same model twice: next rung of the ladder (nemotron, minimax, glm), same brief, one-line report |

## Profiles

| Profile | Model | Use for | Rights |
|---|---|---|---|
| `scout` | `nvidia/nvidia/nemotron-3.5-super-vl-120b-a12b` | See: images, screenshots, wireframes, PDFs, large file reads | Read only |
| `thinker` | `nvidia/minimaxai/minimax-m3.1-flash#thinking` | Think: architecture, root-cause analysis, design, review | Read only |
| `builder` | `nvidia/z-ai/glm-5.3-flash#thinking` | Code and run: multi-file implementation, tests, builds, greps, mechanical sweeps | Full, but never commits |

Ties: see beats think, think beats code, code beats run. Correct reading beats fast writing.

## Rules

| Rule | Meaning |
|---|---|
| Name the profile when spawning | The profile carries its own `model:` and the server applies it, never rely on the default model |
| Profile not exposed by the harness | Spawn `general` and pass that profile's model id explicitly |
| Sub-agents never commit | The main agent reviews, verifies, and commits |
| One agent per file set | Two agents in the same files corrupt each other |
| Free models only | No paid tiers (bedrock, paid openrouter) |
| Report the routing in one line | "T7: builder (glm#thinking), 4 files, parallel with T8", then work silently |
