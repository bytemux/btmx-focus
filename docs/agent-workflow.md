# Agent workflow

btmx-focus is built end to end by coding agents using the
[mattpocock-skills](https://github.com/mattpocock/skills) skill set (v1.3.1). The app is
small on purpose: it's a real project for putting the whole workflow through its paces,
from the first interview to a merged PR.

These are my notes from working with the set: how the skills chain together, how to
change course at each stage, and where it falls short.

## Quick sequence

```bash
# 0. Once per repo
/setup-matt-pocock-skills

# 1–3. ONE unbroken context window: no /clear or /compact until tickets are published
/grill-with-docs            # interview; updates GLOSSARY.md and ADRs as it goes
#   (optional detour: /handoff → /prototype in a fresh session → /handoff back)
/to-spec                    # conversation → Spec issue
/to-tickets <spec_id>       # Spec issue → ticket issues with blocking edges
/retro                      # optional, before clearing

# 4. Build: pick one
/implement <ticket_id>      # per ticket, /clear between tickets
/implement-spec <spec_id>   # whole spec, parallel subagents, one integration branch

# 5. Ship
open a PR                   # /pr is model-invoked for the body
# ⚪ correctness review in a FRESH chat ("review this PR" or /code-review); fix in the implementing chat
# ⚪ merge

# 6. Optional. Analyze coding session. Lookback over the session and suggest changes to the agent's setup, not the code.
/retro
/ask-matt # Navigate skill set
```

Artifact chain: **chat (+ GLOSSARY.md / ADRs) → Spec issue → Ticket issues → commits on a branch → PR**.

GLOSSARY.md and ADRs are long-lived and read by every later step; spec and tickets are per feature; the chat is
temporary, which is why it must stay alive until `/to-tickets` has run.

## Main flow

| # | Skill / step | What it does | What it produces | Calls under the hood |
|---|---|---|---|---|
| 0 | `/setup-matt-pocock-skills` | One-time repo config: issue tracker, triage labels, domain-doc layout. Explores, asks one section at a time, then writes. | `docs/agents/issue-tracker.md`, `triage-labels.md`, `domain.md`; `## Agent skills` block in AGENTS.md/CLAUDE.md; missing labels on GitHub | – |
| 1 | `/grill-with-docs` | Interviews you in rounds (numbered questions, recommended answer for each) until every decision is settled; challenges fuzzy terms and checks claims against the code. Use `/grill-me` instead only when there's no repo. | Shared understanding **in the chat**; `GLOSSARY.md` updated inline; `docs/adr/NNNN-*.md` only when a decision is hard to reverse, surprising and a real trade-off | `grilling`, `domain-modeling` |
| 1a | 🟡 `/handoff` → `/prototype` → `/handoff` *(optional)* | Detour for a question chat can't settle (state model, UI look/feel): throwaway code in a fresh session. | Handoff `.md` in `$TMPDIR`; prototype on a `prototype/<name>` branch; verdict referenced from the issue | – |
| 2 | `/to-spec` | Synthesises the conversation into a spec. **No new interview**, so it needs the grilling still in context. Confirms the test seams with you. | GitHub issue "Spec" (Problem, Solution, User Stories, Implementation & Testing Decisions, Out of Scope), labelled `ready-for-agent` | – (reads GLOSSARY.md and ADRs) |
| 3 | `/to-tickets <spec_id>` | Slices the spec (body **and comments**) into tracer-bullet vertical slices, each with blocking edges; quizzes you on granularity and edges until you approve. | N GitHub issues as sub-issues of the spec, with native "blocked by" links, labelled `ready-for-agent`. Parent spec is not modified. | – (reads GLOSSARY.md and ADRs) |
| 4a | `/implement <ticket_id>` | Builds one ticket test-first at pre-agreed seams, runs tests, reviews, commits. `/clear` before the next ticket. | Commits on the current branch; review report in chat | `tdd` (→ `codebase-design` if the interface shape is in question), `code-review` |
| 4b | `/implement-spec <spec_id>` | Reads the tickets as a task graph and runs implementer subagents across the ready frontier in parallel, each in its own worktree; merges into one integration branch. | Integration branch; draft PR that closes the spec and tickets; tickets resolved. ⚠️ Check that worktrees are cleaned up (step 9). | implementer subagents → `tdd`; merger subagents; `code-review` once on the integration branch; one fix-up subagent |
| – | `code-review` *(runs inside 4a/4b)* | Answers two questions: **did we follow the rules, and did we build what the ticket says?** Reviews `git diff <fixed-point>...HEAD` in two parallel fresh subagents: **Standards** (repo docs + Fowler smell baseline) and **Spec** (missing / scope creep / wrong). **It doesn't look for bugs** (see below). | Report with separate `## Standards` and `## Spec` sections | 2 subagents |
| 5 | `/pr` (or "open a PR") | Model-invoked whenever the agent writes a PR body. | PR body: Summary visual, Before/After evidence, Merge Danger (one-way/two-way door, blast radius) | – |
| 5.1 | Correctness review + merge | Review from fresh PR. Answers: Is it broken? Looks for bugs, edge cases, races, error handling | Bug fixes; merged PR | Claude Code `/code-review` |
| 6 | `/retro` | Looks back over a session and suggests changes to the **agent's environment**, not the code. Mechanical mistakes become automated checks; judgement calls become coding standards. | Prioritised suggestions: AGENTS.md pointers, lint/CI checks, `CODING_STANDARDS.md` rules, docs, tooling | `writing-for-agents` |

## Making changes at each stage

**No skill syncs automatically.** Each writes its artifact once. Rule of thumb: **fix the earliest artifact that's wrong,
then update everything after it by hand.** Record hard-to-reverse decisions in an ADR so later steps respect them.

| Stage | How to change it | What updates |
|---|---|---|
| Grilling | Just answer differently; the next round adapts to your answers. | GLOSSARY.md updates inline. Ask explicitly for an ADR to be added or changed. |
| Spec (after `/to-spec`) | In the same chat: "update the spec issue with X", or edit it on GitHub. Re-running `/to-spec` creates a **new** issue. | Only the spec. Tickets already published don't change. |
| Ticket breakdown (before publishing) | `/to-tickets` stops for your approval; push back on granularity, edges, merges/splits there. **Cheapest point to change things.** | The proposed list, until you approve. |
| Tickets (after publishing) | Edit the ticket issue on GitHub, or add a comment, since `/implement` reads the issue. A correction left as a comment on the spec is picked up if you re-run `/to-tickets`. | Manual only. |
| During `/implement` | Interrupt and say so. **Update the ticket (or add a comment) first**, otherwise `code-review`'s Spec check flags your change as scope creep. | Code changes; the ticket doesn't. |
| During `/implement-spec` | Harder to steer: subagents work from the tickets. Fix the tickets before running it, or let it finish and adjust in a follow-up. | Code via the fix-up subagent; tickets only if you edit them. |
| After the PR | Leave review comments, then "address the review" in the main chat. | Code only. |
| Process itself | `/retro` at the end of the session. | Its suggestions for AGENTS.md, checks and coding standards. |

## Field notes

- **btmx-focus repo gap:** there's no `CODING_STANDARDS.md` and no CI, so the Standards axis of `code-review` relies only on AGENTS.md
and the code-smell baseline. `/retro` will flag this.

## Skills missing from the flow

| Skill | When to use | What it does | What it produces | Calls under the hood |
|---|---|---|---|---|
| `/prototype` | A question that can't be answered in conversation: does this state model/logic feel right, or what should this UI look like | Throwaway code, trivial to run, with no persistence or polish; shows the full state after every action | Logic: one HTML file with walkthroughs. UI: several switchable variants. Kept on a `prototype/<name>` branch, with a pointer from the implementation issue. | – |
| `/handoff` | Moving to a **new directory, harness or colleague**, or forking a side task mid-phase (e.g. the prototype detour). Otherwise `/compact` or just continue. | Compacts the conversation into a portable doc; references existing artifacts instead of copying them | Markdown file in `$TMPDIR` with a "suggested skills" section | – |
| `/diagnosing-bugs` | Hard bugs: ones that resist a first look, intermittent flakes, regressions | Builds a tight feedback loop that goes red on *this* bug before theorising, then bisects/tests hypotheses and fixes it | Fix + regression test. Follow with `/retro` ("what would have prevented this?") | – |
| `/triage` | Issues **you didn't create** (bug reports, incoming requests). Never on `/to-tickets` output. | Moves issues through the triage roles (`needs-triage` → `needs-info` / `ready-for-agent` / `ready-for-human` / `wontfix`); grills if needed | Labelled issues with agent-ready briefs, which `/implement` picks up | `grilling`, `domain-modeling` |
| `/improve-codebase-architecture` | Spare time; keeping the codebase easy for agents to work in | Surveys for deepening opportunities (deep modules, clean seams) | Candidate refactors; picking one becomes an idea for `/grill-with-docs` | `codebase-design`, `grilling`, `domain-modeling` |
| `/research` | A question that needs reading primary sources (API docs, platform behaviour) | Background agent investigates while you keep working | Cited Markdown file in the repo, which you then bring into `/grill-with-docs` | background agent |
| `/wayfinder` | A huge, foggy effort (greenfield, a feature too big for one session). Never for a well-scoped feature. | Builds a map of decision tickets on the tracker and resolves them one by one | Decisions, not code; then hands off to `/to-spec` | `grilling`, `domain-modeling`, `prototype`, `research` subagents |
| `/wait-what` | The agent's last message didn't make sense | Re-explains it with context, in plain English and glossary terms | Clearer explanation in chat | – |
