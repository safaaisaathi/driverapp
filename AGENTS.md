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
