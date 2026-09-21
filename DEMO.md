# Walkthrough

Everything below happened on this repository, on real pull requests. Nothing is
illustrative.

## The legacy state

Three commits before any automation existed:

| Commit | What happened |
|---|---|
| `3531ec9` | both packs created at 1.0.0 |
| `15b8e62` | `skill-1` changed — **no version bump** |
| `9264ff4` | somebody noticed and bumped `plugin-a` to 1.0.1 by hand |

Between the second and third commits, master had a newer `skill-1` than anyone
who installed the pack. The version is the key Claude Code compares to decide
whether to update, so a change that does not move it reaches nobody.

## 1. Introducing the automation — [#1](../../pull/1)

One commit: workflows, shared release config, per-pack wiring, house-rule
scripts, reconstructed changelogs.

Three tags were backfilled first — `plugin-a-v1.0.0`, `plugin-a-v1.0.1`,
`plugin-b-v1.0.0`. semantic-release is stateless and reads the current version
from the newest matching tag, so without them the first release would have
restarted at 1.0.0 and regressed below what had already shipped.

Merging released **nothing**, which is correct: `chore(ci):` is not a releasing
type.

## 2. A single-pack change — [#2](../../pull/2)

`fix(plugin-a): Correct skill-1 wording`, touching only `skill-1`.

```
plugin-a  1.0.1 -> 1.0.2      released
plugin-b  1.0.0               untouched
```

A change to one pack never releases the other.

## 3. A stack of two — [#3](../../pull/3) and [#4](../../pull/4)

`refactor(plugin-a)` at the bottom, `feat(plugin-b)` on top, merged together
with `gh stack merge`.

```
plugin-a  1.0.2 -> 1.0.3      refactor is a patch
plugin-b  1.0.0 -> 1.1.0      feat is a minor
```

Both packs released, each by the size its own commit earned — and **one release
run**, not one per pull request. The stack lands as a single merge, and the
workflow's concurrency group serialises anything that does overlap.

## 4. What the gate rejects

Four pull requests are left open on purpose. One is healthy; three are each
broken in a different way, so a reviewer can see which job catches what.

| PR | Conventional Title | Validate Packs | Why |
|---|---|---|---|
| valid change | pass | pass | the shape every PR should have |
| malformed pack | pass | **fail** | a new pack with no `package.json` and no marketplace entry |
| malformed title | **fail** | pass | `docs:` on a `SKILL.md` would merge and ship nothing |
| malformed skill | pass | **fail** | `SKILL.md` with no frontmatter |

The title failure is the subtle one. `docs:` releases nothing, so without that
check the change merges, CI stays green, and the pack silently keeps its old
content — the exact failure the legacy state above shows.

## Relationship to the real proposal

The two scripts and both workflows are byte-for-byte the files proposed for the
real marketplace. Only the npm scope and the release bot's name and email are
anonymised here.

In the real repository an org ruleset restricts `.github/workflows/**`, so the
workflow YAML is staged under `.proposed/` for devops to install. Here it sits at
the real path so it actually runs.
